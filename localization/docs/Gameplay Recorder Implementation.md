# Implementation Mandate: Automatic Session Recorder & Deterministic Replay Engine

## 1. High-Level Goals

Implement an **Automatic Session Recorder & Replay Engine** that captures gameplay sessions in real time and reproduces past runs with 100% deterministic fidelity.

### Core Objectives:
1. **Zero-Overhead Real-Time Recording:** Every run writes a machine-readable stream (`.mcr`) and narrative log (`.log`) in real time, flushed on every action so no data is lost on a crash.
2. **Post-Loadout Playback Initialization:** Replay playback begins directly from the post-loadout run state (Hero, Deck, Master Seed, and initial inventory configured at Floor 1 entrance), while the recording captures the complete action history for telemetry and statistics.
3. **State-Gated Playback (Zero-Desync):** Replay playback does not advance on a free-running continuous timer; it waits for the engine to reach the required **Ready for Input** state before dispatching each recorded `GameAction`.
4. **Variable Playback Speed:** The developer or player can watch replays at variable speeds (1x to 9x, pause) while maintaining 100% mathematical and visual synchronization.
5. **Spectator Isolation:** During replay, all local player gameplay inputs are blocked so spectator clicks cannot interfere with playback.

---

## 2. Core Architectural Principles

### 1. The VCR Philosophy (Universal Action Pipeline)
The replay engine relies on the game's deterministic command pipeline:
- A run is completely defined by its **Master Seed** + **The Sequence of Player `GameAction`s**.
- Replay playback and live gameplay execute through the **exact same code paths**: the replay engine does not simulate mouse clicks, physics, or UI states. It simply loads the initial run state and feeds the recorded `GameAction`s back into `ActionQueue.request(action)`.
- All non-mutating UI elements (tooltips, inspection popups, tutorial dialogs) are bypassed or ignored during replay.

### 2. State-Gated Intent Queuing (Input Gates)
Replays must **never** fire actions on a continuous wall-clock timer (`playback_time += delta`), because animation runtimes, frame rates, and scene loading vary across machines:
- The Replay Controller observes the game state.
- It only counts down the recorded think time when the engine has reached the required state and is **idle and waiting for player input**.
- It dispatches the action to `ActionQueue.request(action)` and waits until the action and its cascaded visual events fully conclude (`ActionQueue.is_busy() == false`) before considering the next action.

### 3. Absolute Timeline Grounding (Global Run Timer)
To prevent small frame-rate variations, garbage collection pauses, or micro-processing lags from accumulating into severe desynchronizations over long runs:
- All actions and narrative log entries are grounded by an authoritative **Global Run Timer** (elapsed simulation time since run start, tracked in the core run state).
- In addition to pacing delays, each recorded action captures an absolute `timestamp` (`float` seconds since run start), providing an unshakeable ground-truth timeline for replay playback, narrative logs, and telemetry.

### 4. Real-Time Storage & Crash Resilience
- When a run begins, the recorder opens file handles in `user://replays/`.
- Every executed `GameAction` is formatted and immediately flushed to disk (`file.flush()`).
- If the game crashes, the recording file is already intact up to the exact action that triggered the crash.

---

## 3. Strict Precautions & Guardrails

The implementing programmer agent must follow these architectural guardrails:

### Precaution 1: Strict Data Purity (No Presentation in Replay Files)
* Replay files (`.mcr`) must contain **only logical game data primitives** (`int`, `float`, `String`, `StringName`, `bool`, `Dictionary`, `Array`).
* **NEVER record or deserialize screen pixel coordinates (`Vector2`), mouse positions, Viewport offsets, UI Control paths, or runtime memory pointers.**
* If an action needs to reconstruct a location (such as an inventory slot), it must use serializable identifiers (`LocationIdentifier.to_dict()` and `LocationIdentifier.from_dict()`).

### Precaution 2: Zero Codebase Assumptions (Investigate First)
* **No assumptions on how the codebase is set up should be made.** The agent implementing the recorder and replay viewer must inspect the active codebase to verify:
  - How each room signals that it is loaded and ready for player input.
  - The exact parameters required by each `GameAction` subclass constructor.
  - How `RNGManager` serializes and restores its PRNG stream states.
  - How `SaveManager` saves and resumes runs.
* Do not invent or assume helper singletons or scene tree structures—always verify against active scripts.

### Precaution 3: Speed Scaling Rules
* Playback speed scaling must be applied globally via `Engine.time_scale` and `AnimationConstants.speed_factor`.
* **NEVER multiply `delta * speed` inside `_process(delta)`**: In Godot, `delta` is already scaled by `Engine.time_scale`. Multiplying by `speed` manually will square the speed multiplier and cause catastrophic timing desyncs.

### Precaution 4: Continued Runs (Save & Resume Continuity)
* When a player saves and quits, then later clicks "Continue", the recording must preserve continuity:
  - The recorder must append a `Checkpoint` marker containing the serialized RNG state from `RNGManager`.
  - Replaying a continued run must correctly load and apply the checkpoint state without RNG drift.

---

## 4. File Specifications & Data Contracts

### 1. The Replay Driver File (`.mcr` - JSON Lines)
The `.mcr` file is a line-delimited JSON file:

- **Line 1: Header Payload**
  Contains the run metadata required to initialize the run deterministically:
  - `seed: int`
  - `hero_def_id: StringName`
  - `deck_id: StringName`
  - `deck_order: String`
  - `deck_size: String`
  - `rng_state: Dictionary or null` (present if resuming from save)

- **Lines 2+: GameAction Payloads**
  Each line represents a single discrete player action executed during the run:
  - `event_class: "GameAction"`
  - `action_type: String` (e.g. `BuyShopAction`, `SelectPathAction`, `MoveInventoryAction`)
  - `timestamp: float` (absolute seconds elapsed on the Global Run Timer since run start)
  - `idle_time: float` (relative seconds spent waiting for player input before submitting)
  - Action-specific logical parameters (e.g. `slot_index`, `cost`, `source_loc`, `target_loc`)

- **Optional Checkpoint Payloads**
  Inserted when a run is resumed from save data, storing the serialized `RNGManager` state.

### 2. Human-Readable Narrative Log (`.log`)
A companion text file output alongside the `.mcr` file, recording human-readable timestamps and event descriptions (e.g. `[00:14.2] Player bought Iron Sword for 5 gold`) to make debugging and run analysis easy.

---

## 5. ActionFactory Contract (Deserialization)

The replay system requires an `ActionFactory` utility to reconstruct typed `GameAction` instances from `.mcr` JSON lines:
- It maps `action_type` strings to the corresponding `GameAction` classes.
- It parses primitive dictionary payloads into action constructor arguments.
- Any unmapped or corrupt action data must fail fast with a descriptive error so bugs can be identified immediately.

---

## 6. Definition of Done

1. **Automatic Real-Time Recording:** Every run automatically produces a flushed pair of `.mcr` and `.log` files in `user://replays/`.
2. **Deterministic Playback:** Loading an `.mcr` file reproduces the entire run with 100% identical game states, combat events, rewards, and rolls at 1x, 3x, or accelerated speeds.
3. **Spectator Input Gating:** All player gameplay inputs are blocked during replay, while developer speed controls (1–9, pause, exit) function cleanly.
4. **Continued Run Support:** Resuming a saved run maintains replay fidelity across save checkpoints.
5. **Zero Presentation Pollution:** Replay files contain zero screen pixel coordinates or UI node references.
