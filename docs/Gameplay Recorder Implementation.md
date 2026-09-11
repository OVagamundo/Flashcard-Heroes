# Implementation Mandate: Automatic Session Recorder & Deterministic Replay Engine

## 1. Commander's Intent & Context
We are implementing an **Automatic Session Recorder & Replay Engine** that captures every gameplay session in real-time and allows replaying any past run from the Title Menu with full VCR playback controls.

**CRITICAL CONTEXT:** The game has recently undergone a major architectural refactor to make it fully deterministic. If you inspect `scripts/actions/ActionQueue.gd`, you will see it processes `GameAction` commands and already captures executed actions into the `_history` array via `action.to_dict()`. **Do not reinvent a recording or action-tracking system.** The core determinism is already in place.

Your objective is to build the infrastructure around this existing architecture:
1. **File I/O:** Write the `_history` to the hard drive in real-time.
2. **Readability:** Generate a human-readable debug log alongside the machine log.
3. **Playback Engine:** Read saved logs, deserialize the actions, and feed them back into the `ActionQueue` to reproduce a run.
4. **Playback UI:** Build the UI overlay to control the replay speed and stepping.

You have the freedom and authority to structure helper classes, adjust file-saving hooks, or introduce UI overlay nodes as you see fit to ensure performance and visual stability. If you encounter edge cases not covered here, use your best judgment to solve them while maintaining the core goal of perfect determinism.

---

## 2. File Formats & Real-Time Storage

Every recorded session generates a pair of files in `user://replays/`. Files are named by timestamp (e.g., `replay_2026-07-26_23-30-00.mcr` and `replay_2026-07-26_23-30-00.log`).

### A. The Replay Driver File (`.mcr`)
A machine-readable line-delimited JSON (JSON Lines) file capturing BOTH deterministic actions and non-deterministic UI telemetry.
* **Header (Line 1):** Must store the run seed and game version.
  `{"header": true, "seed": 1337420, "version": "1.0.0", "timestamp": "2026-07-26_23-30-00"}`
* **Payload (Lines 2+):** Each recorded event must include an `event_class` to distinguish core game logic from UI telemetry:
  * **GameActions:** Strict state mutations executed by the ActionQueue. Must include `time_delta` (real-world seconds elapsed since the previous action). **Serialization Rule:** Actions must only store primitive data types (Strings, Ints, Floats) or `UUID` strings. They must NEVER store direct Node or Object references, as these will crash JSON parsing.
    `{"event_class": "GameAction", "action_id": "shop_purchase_action", "time_delta": 4.25, "instance_uuid": "item_t3_g", "cost": 5}`
  * **Telemetry Events (UI):** Non-mutating player interactions (e.g., pausing, changing combat speed, opening an inspection window). These are recorded purely for statistical analysis and developer review. During a replay, the engine logs that they happened, but **does not execute them** (so a recorded speed change doesn't override the spectator's replay UI controls).
    `{"event_class": "TelemetryEvent", "action_id": "changed_combat_speed", "new_speed": 2.0, "time_delta": 1.2}`

### B. The Human-Readable Debug Log (`.log`)
Written alongside the `.mcr` file to provide a clear, chronological narrative of state modifications and combat resolution. It should capture the **Input (Cause)** and the **CombatEvents (Effects)**.
```text
=== SESSION START: 2026-07-26_23-30-00 | SEED: 1337420 ===
 ACTION: ShopPurchaseAction (item_t3_g, cost: 5)
  ├── STATE: Gold 15 -> 10
  └── STATE: Added item_t3_g to PlayerBench[0]
 ACTION: StartCombatAction
  ├── COMBAT: Turn 1 Started
  ├── EVENT: DAMAGE | Attacker: Burny -> Target: Slime_A | Dmg: 5 (HP 12 -> 7)
  └── TRIGGER: on_hurt fired for Slime_A
C. Real-Time Instant Flushing
Do NOT buffer the log until the end of a run. Open the FileAccess handles at the start of a session. Whenever ActionQueue completes a GameAction, immediately call file.store_line(...) followed by file.flush(). Because actions occur periodically, instant flushing carries 0% performance overhead while ensuring 100% crash resilience.

D. File Management
Rolling 5 Storage: The user://replays/ folder must enforce a cap of 5 recording pairs. When a new session starts, automatically delete the oldest .mcr/.log pair based on the timestamp.

Crash Dump Preservation: If the game detects an improper shutdown (e.g., a run was active but never fired a "Run Ended" or "Game Quit" action), copy the last active .mcr/.log pair into a dedicated user://crash_dumps/ folder before cleaning up the rolling storage.

3. The Playback Engine & Deserialization
To replay a game, the engine must rebuild the exact state sequence.

Deserialization Factory & Telemetry Filtering: `GameAction.from_dict()` currently returns null. You must implement an ActionFactory to re-instantiate JSON payloads into executable `GameAction` objects. **Critical Routing Rule:** The Replay Engine MUST parse the `event_class`. It only instantiates and pushes `GameAction` events to the `ActionQueue`. `TelemetryEvent`s must be routed to a separate analytics parser or ignored entirely; pushing telemetry to the ActionQueue will cause a fatal execution crash.

Seed Injection & Pacing: Before a replay begins, the engine must parse the `.mcr` header and initialize `RNGManager.gd` with the recorded master seed so all subsequent logic resolves identically. Furthermore, the replay engine must read the `time_delta` from each action payload and perfectly simulate that delay (`await get_tree().create_timer(time_delta / AnimationConstants.speed_factor)`) before pushing it to the ActionQueue, ensuring organic pacing is exactly preserved.


4. Playback UI & Engine Control
Title Menu Integration
Add a "Replays" button to Title.tscn or OptionsWindow.tscn that displays a list of stored recordings in user://replays/. Selecting one initializes a playback session.

Floating Playback Controls Overlay
Implement a sleek, minimal CanvasLayer UI overlay visible only during replay sessions:

Play / Pause: Freezes or resumes the ActionQueue execution and visual animations.

Step-by-Step: When paused, executes exactly ONE GameAction from the recording and immediately pauses again.

Speed Controls: Adjusts playback speed (1x, 2x, 5x, 10x) by assigning AnimationConstants.speed_factor or calling AnimationConstants.set_speed(). Do not manually modify Engine.time_scale, as the existing setter in AnimationConstants.gd automatically handles this linkage.

Exit to Menu: Terminates playback, cleans up active states, restores default speed via AnimationConstants.speed_factor = 1.0, and returns to the Title screen.

5. Codebase Integration Hotspots & Warnings
Asynchronous Pacing & Input Blocking (`ActionQueue.gd`): `ActionQueue._process_queue()` must be fully asynchronous. When an action is enqueued, it MUST instantly enable a global input blocker (e.g. `GlobalInputBlocker.set_blocking(true)`) to prevent ANY further player interaction. The queue must execute the action and `await AnimationCompletionTracker.wait_for_animations()`. It MUST NOT pop the next item or unblock inputs until ALL visual animations are 100% finished. Do not write logic to manually skip or bypass awaits during fast-forward. Because the game handles speed globally via `AnimationConstants.speed_factor -> Engine.time_scale`, the engine natively compresses tween durations. Trust the engine scale to make the awaits instant during sped-up simulations.

Native randi() Leaks: (COMPLETED in RNG Standardization Pass). The codebase has already been fully audited and sterilized of native GDScript randomness (`randi()`, `.pick_random()`). All systems correctly route through `RNGManager` streams.

SignalBus.gd Reliance: Do not hook the recorder directly into visual nodes. Listen to the ActionQueue and SignalBus to append context entries into the readable .log file during combat resolution.

6. Definition of Done
Every gameplay session automatically creates a paired .mcr and .log file in user://replays/, instantly flushed to disk.

The folder cleanly enforces the rolling 5-file cap. Crash dumps are successfully isolated.

GameAction subclasses can be seamlessly serialized to and deserialized from JSON.

Loading a replay from the Title Menu replays the game with identical RNG outcomes.

The player can fully control playback via the floating overlay (Play, Pause, Speed, Step, Exit) without visual overlapping or engine crashes.
