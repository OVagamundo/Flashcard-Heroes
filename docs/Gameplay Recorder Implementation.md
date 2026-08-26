# Implementation Mandate: Automatic Session Recorder & Deterministic Replay Engine

## 1. Commander's Intent & Context
We are implementing an **Automatic Session Recorder & Replay Engine** that captures every gameplay session in real-time and allows replaying any past run from the Title Menu.

**CRITICAL CONTEXT:** The game has recently undergone a major architectural refactor to make it fully deterministic. The `ActionQueue` (see `scripts/engine/ActionQueue.gd`) processes `GameAction` commands which already expose a `serialize() -> Dictionary` method for capturing executed actions. The `RNGManager` maintains isolated, seeded PRNG streams with full `serialize()`/`deserialize()` support.

### The "Slay the Spire 2" VCR Philosophy: What, How, and Why

#### What it is
The game architecture strictly separates Player Intent (UI interactions) from State Mutation (Backend Logic). The UI never changes the game state directly; it acts purely as a "remote control" dispatching commands.

#### How it works
1. **The Remote Control (UI Phase):** A player interacts with the game. The UI calculates what they are trying to do, constructs a specific `GameAction`, and pushes it to the `ActionQueue`.
2. **The Blinder (Execution Phase):** As soon as an action hits the queue, the game blocks all player input. The `GameAction` executes instantly and blindly on the backend and emits a global signal, without knowing or caring about the UI.
3. **The Puppet Show (Presentation Phase):** The UI elements act as puppets listening to the `SignalBus`. When they hear a signal, they asynchronously animate the result.
4. **The Unblock:** When the visual animations finish, the `ActionQueue` unlocks player input for the next action.

#### Why it's designed this way
This architecture is built specifically to enable a **Deterministic VCR Replay System**.
* **Blind Reproduction:** By recording the exact sequence of `GameAction`s and the RNG Seed, the engine perfectly reconstructs the run.
* **Input Immunity during Playback:** If the backend waited for UI callbacks or permitted inputs during replay, it would break the deterministic chain. By making the backend execute instantly and treating the UI as a puppet, replays just push the recorded commands into the queue and the game flawlessly plays itself.
* **Decoupled Telemetry:** The mechanical replay is strictly for game state. Pure UI interactions (speed toggles, inspection windows, hesitations) are recorded as separate telemetry events for analytical pacing but are completely bypassed from the mechanical action queue to prevent contaminating the core determinism.

#### THE PRIME DIRECTIVE: DO NOT TOUCH THE GAME
**The Record and Replay systems are completely decoupled, isolated observers. They MUST NEVER modify, patch, or alter the core game's logic or behavior.**
Because the game follows a strict, deterministic `GameAction` pipeline, implementing the replay system requires **zero** changes to the game's actual rules, scenes, or state mutations. 
* **Recording** is simply listening to the `ActionQueue` and saving the output to a file alongside its timestamp.
* **Replaying** is simply reading that file and feeding those exact actions back into the `ActionQueue` in the right order. 
The game plays itself exactly as it originally did. If a bug occurs during playback, the solution is **never** to have the Replay Engine "fix" or spoof the game state. The bug means the game itself is bypassing the Action Queue somewhere (e.g., a UI button progressing state directly), and the fix is to refactor that specific game feature into a `GameAction`, strictly preserving the decoupled nature of the replay engine.

#### THE GOLDEN RULE OF THE VCR PATTERN (Zero-Bypass Architecture)
**Absolutely nothing that progresses the game can bypass the `GameAction` pipeline.**
If a UI button (like "Start Minigame", "Close Tutorial", or "Review Next Flashcard") directly calls a function that advances the game state instead of pushing a `GameAction` to the `ActionQueue`, **the replay will permanently halt at that screen.**
*Why?* Because during replay playback, all player inputs are physically blocked. The replay engine does not simulate mouse clicks on UI elements; it *only* reads recorded `GameAction`s from the `.mcr` file and pushes them to the queue. If an event wasn't a `GameAction`, it wasn't recorded, and the replay engine will never trigger it. 
**If it advances the game, it MUST be a GameAction.**

**Do not reinvent a recording or action-tracking system.** The core determinism is already in place. Your objective is to build the infrastructure around it:

1. **File I/O:** Write actions to disk in real-time as they are executed by the `ActionQueue`.
2. **Readability:** Generate a human-readable debug log alongside the machine-readable recording.
3. **Playback Engine:** Read saved recordings, deserialize actions via an `ActionFactory`, and feed them back into the `ActionQueue` to reproduce a run.
4. **Continued Runs:** When a player loads a saved run and continues playing, the recording must resume from the checkpoint.

---

## 2. File Formats & Real-Time Storage

Every recorded session generates a pair of files in `user://replays/`. Files are named with the date and time of the recording start (e.g., `replay_2026-07-26_23-30-00.mcr` and `replay_2026-07-26_23-30-00.log`).

### A. The Replay Driver File (`.mcr`)
A machine-readable line-delimited JSON (JSON Lines) file capturing BOTH deterministic actions and non-deterministic UI telemetry.

* **Header (Line 1):** Must store the run seed, game version, and RNG state snapshot. When a run is continued from a save, the header must store the **full serialized RNG state** (not just the master seed) so that all streams resume from the exact point they were at when the save was made.
  ```json
  {"header": true, "seed": 1337420, "version": "1.0.0", "timestamp": "2026-07-26_23-30-00", "rng_state": null}
  ```
  For fresh runs, `rng_state` is `null` (streams are derived from the master seed). For continued runs, `rng_state` contains the full `RNGManager.serialize()` output.

* **Payload (Lines 2+):** Each recorded event must strictly be a core state mutation logic (GameAction). The replay system is "dumb and blind"—it strictly reproduces the deterministic GameActions mapped from player inputs. It does NOT record or inject pure UI telemetry, ghost mouse movements, or hovering hesitations.
  * **GameActions:** Strict state mutations executed by the ActionQueue. Must include `time_delta` (real-world seconds elapsed since the previous action). **Serialization Rule:** Actions must only store primitive data types (Strings, Ints, Floats) or `UUID` strings. They must NEVER store direct Node or Object references, as these will crash JSON parsing.
    ```json
    {"event_class": "GameAction", "action_id": "BuyShopAction", "time_delta": 4.25, "instance_uuid": "item_t3_g", "cost": 5}
    ```
  * Note: Spectator controls (pausing, changing playback speed, exiting to title) are native interactions performed by the spectator during playback and are NOT recorded or executed from the replay file.

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
```

### C. Real-Time Instant Flushing
Do NOT buffer the log until the end of a run. Open the `FileAccess` handles at the start of a session. Whenever `ActionQueue` completes a `GameAction`, immediately call `file.store_line(...)` followed by `file.flush()`. Because actions occur periodically, instant flushing carries negligible performance overhead while ensuring 100% crash resilience.

### D. File Management
**Rolling 5 Storage:** The `user://replays/` folder must enforce a cap of **5** recording pairs. When a new session starts, automatically delete the oldest `.mcr`/`.log` pair based on the timestamp in the filename.

**Crash Dump Preservation:** If the game detects an improper shutdown (e.g., a run was active but never fired a "Run Ended" or "Game Quit" action), copy the last active `.mcr`/`.log` pair into a dedicated `user://crash_dumps/` folder before cleaning up the rolling storage.

---

## 3. Continued Runs (Save & Resume Recording)

When a player quits and later loads a saved run via the "Continue" button on the Title screen, the recording system must handle this seamlessly:

1. **On Save:** When `SaveManager.save_run()` is called, the recorder must store the **current filename** of the active recording in the save data. The RNG state is already serialized by `RunState.to_save_dict()`.

2. **On Load & Continue:** When the player presses "Continue" and `SaveManager.load_run()` restores the `RunState`:
   * The recorder must re-open the **same `.mcr` and `.log` files** that were being used when the save was made.
   * A `CHECKPOINT` marker line must be appended to both files indicating the session was resumed:
     ```json
     {"event_class": "Checkpoint", "type": "session_resumed", "timestamp": "2026-07-27_10-15-00", "rng_state": {...}}
     ```
   * All subsequent actions are appended after this marker. The replay engine uses the checkpoint to re-inject the correct RNG state at that point.

3. **Multiple Continuations:** If the player saves and continues multiple times within the same run, each continuation appends another checkpoint marker to the same file. The file grows linearly but the rolling 5-file cap is based on **run starts**, not continuations.

---

## 4. The Playback Engine & Deserialization

To replay a game, the engine must rebuild the exact state sequence.

### A. ActionFactory (Deserialization)
`GameAction.serialize()` already exists on every action subclass. You must implement an `ActionFactory` singleton or static class that maps `action_id` strings back to instantiated `GameAction` objects. The factory must handle all current action types:

| Category | Action Classes |
|---|---|
| **Map** | `SelectPathAction`, `StartBattleAction` |
| **Shop** | `BuyShopAction`, `RerollShopAction`, `LeaveShopAction` |
| **Reward** | `DrawRewardAction`, `CollectRewardAction`, `SellRewardAction`, `StudyRewardAction`, `LeaveRewardAction` |
| **Rest Site** | `DrawRestSiteAction`, `StudyRestSiteAction`, `UpgradeRestSiteAction`, `LeaveRestSiteAction` |
| **Black Market** | `RemoveBlackMarketAction`, `TransformBlackMarketAction`, `LeaveBlackMarketAction` |
| **Inventory** | `MoveInventoryAction` |

**Critical Routing Rule:** The Replay Engine MUST parse the `event_class` field. It only instantiates and pushes `GameAction` events to the `ActionQueue`. `TelemetryEvent`s and `Checkpoint`s must be routed to a separate analytics parser or skipped entirely; pushing telemetry to the ActionQueue will cause a fatal execution crash.

### B. Seed Injection & Pacing
Before a replay begins, the engine must:
1. Parse the `.mcr` header.
2. If `rng_state` is `null` (fresh run): call `RNGManager.initialize(seed)` to derive all streams from the master seed.
3. If `rng_state` is present (continued run): call `RNGManager.deserialize(rng_state)` to restore the exact advanced state of every stream.
4. When a `Checkpoint` line is encountered during playback, call `RNGManager.deserialize(checkpoint.rng_state)` to re-sync the streams.

**Pacing:** The replay engine must read the `time_delta` from each action payload and simulate that delay before pushing the action:
```gdscript
await get_tree().create_timer(time_delta / AnimationConstants.speed_factor).timeout
```
This ensures organic pacing is preserved at 1x speed but scales correctly with the replay speed controls.

---

## 5. Playback Controls (Developer Tool — Keyboard Only)

This is a **developer-only tool**. There is no visual overlay or floating UI panel. All replay controls are keyboard-driven:

### Speed Controls (Number Keys 1–0)
| Key | Speed |
|-----|-------|
| `1` | 1x (normal speed) |
| `2` | 2x |
| `3` | 3x |
| `4` | 4x |
| `5` | 5x |
| `6` | 6x |
| `7` | 7x |
| `8` | 8x |
| `9` | 9x |
| `0` | Pause (freeze playback) |

Speed is applied by setting `AnimationConstants.speed_factor` which automatically propagates to `Engine.time_scale`. Do NOT manually modify `Engine.time_scale` directly.

### Exit Controls
* **`Escape` key OR `0` (Pause):** When playback is paused (speed = 0), show a simple confirmation popup: **"Exit to Title Screen?"** with Yes/No options.
  * **Yes:** Terminate playback, clean up all active states, restore `AnimationConstants.speed_factor = 1.0`, and return to the Title screen.
  * **No:** Dismiss the popup. Playback remains paused (player must press 1–9 to resume).
* **`Escape` during active playback:** Pauses the playback first (equivalent to pressing `0`), then shows the exit popup.

### Input Blocking
During replay playback, **ALL normal player input is blocked** (dragging, clicking nodes, shop buttons, etc.). The only inputs the game responds to are the number keys for speed control and Escape for the exit popup. This is enforced via the same global input blocker used by the `ActionQueue` during normal gameplay, except it remains permanently active for the entire replay duration.

---

## 6. Title Screen Integration

### Replay Button
Add a **"Replays"** button to `Title.tscn`, positioned alongside the existing buttons (Play, Continue, Options, Exit). The button is always visible even if no replays exist (it will show an empty list).

### Replay Selection List
When the Replays button is pressed, display a simple scrollable list of stored recordings from `user://replays/`. Each entry displays:
* **Name:** The date and time of the run start (parsed from the filename), formatted for readability (e.g., `"Jul 26, 2026 — 11:30 PM"`).

Selecting a replay entry begins playback:
1. Parse the `.mcr` header and inject the seed/RNG state.
2. Start the game as if it were a fresh run (load the Main scene).
3. Begin feeding deserialized actions from the `.mcr` file into the `ActionQueue` with time-delta pacing.
4. Enable the keyboard-only replay controls (keys 1–0, Escape).

---

## 7. Codebase Integration Hotspots & Warnings

### Recording Hook in ActionQueue
The recording system must hook into `ActionQueue._resolve_current_action()`. After a `GameAction` resolves, the recorder captures `_current_action.serialize()` enriched with the computed `time_delta` and writes it to disk. The recorder must NOT interfere with the queue's processing flow — it is a passive observer.

### Asynchronous Pacing & Input Blocking (`ActionQueue.gd`)
`ActionQueue._process_queue()` must remain fully asynchronous. When an action is enqueued, it MUST instantly enable a global input blocker to prevent ANY further player interaction. The queue must execute the action and respect `yields_for_visuals()`. It MUST NOT pop the next item or unblock inputs until ALL visual animations are 100% finished. Do not write logic to manually skip or bypass awaits during fast-forward. Because the game handles speed globally via `AnimationConstants.speed_factor → Engine.time_scale`, the engine natively compresses tween durations.

### Native `randi()` Leaks
**(COMPLETED in RNG Standardization Pass).** The codebase has been fully audited and sterilized of native GDScript randomness. All systems correctly route through `RNGManager` streams. The `WeightedPoolDirector` now explicitly receives the correct RNG stream from its callers (`PathChoice.gd`, `EncounterGenerator.gd`).

### SignalBus.gd Reliance
Do not hook the recorder directly into visual nodes. Listen to the `ActionQueue` and `SignalBus` to append context entries into the readable `.log` file during combat resolution.

---

## 8. Definition of Done

1. **Automatic Recording:** Every gameplay session automatically creates a paired `.mcr` and `.log` file in `user://replays/`, instantly flushed to disk. The recording starts when a run begins and stops when the run ends (victory, defeat, or quit).

2. **Continued Runs:** Loading a saved run and continuing it correctly resumes recording into the same file pair with a checkpoint marker. RNG state is fully preserved across save/load cycles.

3. **Rolling Storage:** The folder cleanly enforces the rolling 5-file cap. Crash dumps are successfully isolated in `user://crash_dumps/`.

4. **Serialization Roundtrip:** All `GameAction` subclasses can be seamlessly serialized to and deserialized from JSON via the `ActionFactory`.

5. **Deterministic Replay:** Loading a replay from the Title Menu replays the game with identical RNG outcomes. The same seed + same action sequence = identical game state at every point.

6. **Keyboard Controls:** The developer can fully control playback via keyboard (keys 1–9 for speed, 0 for pause, Escape for exit popup) without any visual overlay or floating UI.

7. **Input Isolation:** During replay, all normal gameplay inputs are blocked. Only speed and exit controls respond.
