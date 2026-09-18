# Implementation Mandate: Automatic Session Recorder & Deterministic Replay Engine

## 1. High-Level Goals

Implement an **Automatic Session Recorder & Replay Engine** that captures gameplay sessions in real time and reproduces past runs with 100% deterministic fidelity.

### Core Objectives:
1. **Zero-Overhead Real-Time Recording:** Every run writes a machine-readable stream (`.mcr`) and human-readable narrative log (`.log`) in real time, flushed on every action so no data is lost on a crash.
2. **Post-Loadout Playback Initialization:** Replay playback begins directly from the post-loadout run state (Hero, Deck, Master Seed, and initial inventory configured at Floor 1 entrance), while the recording captures the complete action history for telemetry and statistics.
3. **State-Gated Playback (Zero-Desync):** Replay playback does not advance on a free-running continuous timer; it waits for the engine to reach the required **Ready for Input** state before dispatching each recorded `GameAction`.
4. **Variable Playback Speed:** The spectator or developer can watch replays at variable speeds (1x to 8x, pause) while maintaining 100% mathematical and visual synchronization.
5. **Spectator Isolation:** During replay, all local player gameplay inputs are blocked so spectator clicks cannot interfere with playback.
6. **Unified Session Continuity:** Runs continued from save files append to the run's existing recording file, allowing playback to reproduce the entire run from start to finish as a single uninterrupted session.

---

## 2. Core Architectural Principles

### 1. The VCR Philosophy (Universal Action Pipeline)
The replay engine relies on the game's deterministic command pipeline established in `Refactor Plan.md`:
- A run is completely defined by its **Master Seed** + **The Sequence of Player `GameAction`s**.
- Replay playback and live gameplay execute through the **exact same code paths**: the replay engine does not simulate mouse clicks, physics, or UI states. It simply loads the initial run state and feeds the recorded `GameAction`s back into `ActionQueue.request(action)`.
- Gating dialogs and modals (such as "Got It!" card introductions, blocking tutorial popups, and battle results) are state machine gates driven by explicit `GameAction`s in the recording (`AcknowledgeFlashcardIntroAction`, `DismissTutorialAction`, `AcknowledgeBattleResultsAction`). Passive, non-gating presentation (mouse hovers, inspection panels that do not block game flow) are bypassed during replay.

### 2. State-Gated Intent Queuing (Input Gates)
Replays must **never** fire actions on a continuous wall-clock timer (`playback_time += delta`), because animation runtimes, frame rates, and scene loading vary across machines:
- The `ReplayController` observes `ActionQueue.is_busy()`.
- It only counts down the recorded think time when `ActionQueue.is_busy() == false` and the current scene has signaled readiness.
- It dispatches the action to `ActionQueue.request(action)` and waits until the action and its cascaded visual events fully conclude (`ActionQueue.is_busy() == false` or `queue_idle`) before considering the next action.

### 3. Absolute Timeline Grounding (Global Run Timer)
To prevent small frame-rate variations, garbage collection pauses, or micro-processing lags from accumulating into severe desynchronizations over long runs:
- All actions and narrative log entries are grounded by the authoritative **Global Run Timer** in `ActionQueue` (elapsed simulation time since run start, tracked in `RunState.elapsed_simulation_time`).
- Each recorded action captures:
  - `timestamp`: absolute seconds elapsed on the Global Run Timer since run start.
  - `idle_time`: relative seconds spent waiting for player input before submitting the action.
- This provides an unshakeable ground-truth timeline for replay playback, narrative logs, and telemetry.

### 4. Real-Time Storage & Crash Resilience
- When a run begins, `GameplayRecorder` opens file handles in `user://replays/run_<run_id>.mcr` and `user://replays/run_<run_id>.log`.
- Every executed `GameAction` is formatted and immediately flushed to disk (`file.flush()`).
- If the game crashes, the recording file is already intact up to the exact action that triggered the crash, pinpointing the bug immediately.

### 5. Unified Save & Continue Continuity (Zero Checkpoint Desync)
- Because PRNG streams (`map`, `combat`, `shop`, `reward`, `gacha`, `cosmetic`) in `RNGManager` advance deterministically from the Master Seed across the sequence of actions, **replay playback does not need to simulate saves or quits**.
- When a player saves and quits, file handles are closed.
- When a player clicks "Continue", `GameplayRecorder` opens the existing `run_<run_id>.mcr` in append mode (`FileAccess.READ_WRITE`, seek to end) and resumes logging.
- Replaying the `.mcr` file simply runs through all recorded actions from start to finish as one continuous playthrough.

---

## 3. Strict Precautions & Guardrails

The implementing programmer agent must follow these architectural guardrails:

### Precaution 1: Strict Data Purity (No Presentation in Replay Files)
* Replay files (`.mcr`) must contain **only logical game data primitives** (`int`, `float`, `String`, `StringName`, `bool`, `Dictionary`, `Array`).
* **NEVER record or deserialize screen pixel coordinates (`Vector2`), mouse positions, Viewport offsets, UI Control paths, or runtime memory pointers.**
* Location-dependent payloads must strictly use `LocationIdentifier.to_dict()` and `LocationIdentifier.create_from_dict()`.

### Precaution 2: Speed Scaling & Multiplicative Compounding
* Playback speed scaling must be applied globally via `Engine.time_scale` and `AnimationConstants.speed_factor`.
* **NEVER multiply `delta * speed` inside `_process(delta)`**: In Godot, `delta` is already scaled by `Engine.time_scale`. Multiplying by `speed` manually will square the speed multiplier and cause catastrophic timing desyncs.
* **Compounding Formula:** Recorded in-game speed settings (such as combat speed buttons) compound multiplicatively with spectator playback speed controls:
  $$\text{Effective Speed} = \text{Base Gameplay Speed} \times \text{Replay Playback Multiplier}$$
  A 2x combat speed viewed at 2x replay speed resolves at 4x speed, while a 1x room speed views at 2x. All animations, tweens, and simulation clock increments scale together without desync.

### Precaution 3: Pause Reproduction Fidelity
* When a player pauses during gameplay, `PauseRunAction` is recorded and **faithfully reproduced during replay playback**.
* Spectators can use the replay viewer's speed controls (e.g. 4x or 8x) to fast-forward through pauses.

### Precaution 4: Spectator Isolation Overlay
* During replay playback, an invisible, full-screen input blocker Control (`mouse_filter = Control.MOUSE_FILTER_STOP`) must be placed over the game viewport.
* This prevents any accidental spectator clicks from triggering `GlobalInteractionRouter` or clicking room buttons, while allowing the Replay Viewer UI hotkeys (Space for pause, 1–8 for speed, Esc for exit) to function cleanly.

### Precaution 5: Fail-Fast Desync Detection
* If `ActionQueue.request(action)` rejects a replayed action (`VALIDATION_FAILED` or `QUEUE_BUSY`), the replay must **not** silently swallow the error or skip the action.
* It must pause playback immediately, push an error log with the offending line number, action type, and state snapshot, and alert the user.

---

## 4. File Specifications & Data Contracts

### 1. The Replay Driver File (`.mcr` - JSON Lines)
Located at: `user://replays/run_<run_id>.mcr`
A line-delimited JSON file:

#### Line 1: Header Payload (`RunHeader`)
Contains the run metadata required to initialize the run deterministically:
```json
{
  "event_class": "RunHeader",
  "run_id": "run_1789592069_18_82048",
  "run_seed": 88888,
  "hero_id": "hero_ironclad",
  "deck_id": "starter_deck",
  "deck_order": "ALPHABETICAL",
  "deck_size": "ALL",
  "timestamp": 0.0
}
```
*(For backwards compatibility, `seed` maps to `run_seed` and `hero_def_id` maps to `hero_id`).*

#### Lines 2+: GameAction Payloads
Each line represents a discrete player action or modal lifecycle transition:
```json
{
  "event_class": "GameAction",
  "action_type": "BuyShopAction",
  "timestamp": 14.52,
  "idle_time": 1.25,
  "slot_index": 0,
  "cost": 5
}
```

### 2. The 37 Authoritative Action Payloads
The following 37 actions are mapped in `ActionFactory.gd` and must be supported:

| Action Class | Payload Fields | Description |
| :--- | :--- | :--- |
| `SelectPathAction` | `node_index: int` | Selects path choice map node |
| `MoveInventoryAction` | `source_loc: Dict`, `target_loc: Dict` | Moves/equips/swaps inventory or units |
| `ConfirmMergeAction` | `source_loc: Dict`, `target_loc: Dict`, `recipe_id: String` | Confirms free unit merge |
| `ConfirmSwapAction` | `source_loc: Dict`, `target_loc: Dict` | Confirms unit swap from choice window |
| `MergeEncounterAction` | `source_loc: Dict`, `target_loc: Dict`, `recipe_id: String` | Confirms paid merge in Merge Encounter |
| `DrawGachaAction` | `tier: int` | Draws unit/item from gacha machine |
| `EndTurnAction` | *(None)* | Commits turn and triggers combat |
| `AcknowledgeBattleResultsAction` | `is_victory: bool` | Dismisses battle results popup |
| `AcknowledgeRunCompleteAction` | *(None)* | Dismisses run victory screen |
| `SetCombatSpeedAction` | `speed: float` | Adjusts combat animation speed (1x, 2x, 4x) |
| `PauseRunAction` | `is_paused: bool` | Pauses/resumes combat and run timer |
| `AcknowledgeFlashcardIntroAction` | *(None)* | Dismisses "Got It!" intro, begins sprint |
| `SelectFlashcardIntroCardAction` | `card_id: String` | Switches active card in intro screen |
| `SubmitFlashcardAnswerAction` | `question_id: String`, `selected_answer_id: String`, `think_time: float` | Submits flashcard answer |
| `SkipFlashcardAction` | `question_id: String`, `think_time: float` | Skips current flashcard |
| `DismissTutorialAction` | `tutorial_id: String` | Dismisses modal tutorial dialog |
| `BuyShopAction` | `slot_index: int`, `cost: int` | Buys item from shop slot |
| `RerollShopAction` | *(None)* | Pays gold to reroll shop stock |
| `LeaveShopAction` | *(None)* | Exits shop to map |
| `DrawRewardAction` | `tier: int` | Draws reward capsule |
| `CollectRewardAction` | `instance_uuid: String` | Claims reward capsule into inventory |
| `SellRewardAction` | `instance_uuid: String` | Sells reward capsule for gold |
| `StudyRewardAction` | *(None)* | Starts minigame in reward room |
| `LeaveRewardAction` | *(None)* | Discards remaining rewards and exits |
| `DrawRestSiteAction` | `tier: int` | Draws stat capsule at rest site |
| `UpgradeRestSiteAction` | `slot_index: int` | Applies stat capsule to hero |
| `ClaimRestSiteGoldAction` | `prize_index: int` | Claims gold prize at gambling den |
| `StudyRestSiteAction` | *(None)* | Starts minigame at rest site |
| `LeaveRestSiteAction` | *(None)* | Applies remaining capsules and exits |
| `StartTrainingAction` | `target_unit_uuid: String`, `stat_type: String` | Commits gold to start unit training |
| `TrainUnitStatAction` | `token_cost: int` | Spends 1-3 tokens to roll stat upgrade |
| `CloseTrainingPopupAction` | *(None)* | Closes training ground popup |
| `LeaveTrainingAction` | *(None)* | Exits training ground to map |
| `RemoveBlackMarketAction` | `target_uuid: String`, `cost: int` | Purges unit/item from run |
| `TransformBlackMarketAction` | `target_uuid: String`, `cost: int` | Rerolls unit/item in black market |
| `LeaveBlackMarketAction` | *(None)* | Exits black market to map |
| `LeaveMergeEncounterAction` | *(None)* | Exits merge encounter to map |

### 3. Human-Readable Narrative Log (`.log`)
Located at: `user://replays/run_<run_id>.log`
A companion text file output alongside the `.mcr` file. Every entry is formatted with `[MM:SS.s]` simulation timestamp and room context:
```
[00:00.0] Run started. ID: run_1789592069_18_82048 | Hero: Ironclad | Seed: 88888 | Deck: Starter (ALL, ALPHABETICAL)
[00:04.2] (Map) Selected Day 1 node: SHOP
[00:11.5] (Shop) Purchased Iron Sword (UUID: ball_123) for 5 gold
[00:15.0] (Shop) Left Shop -> returned to Path Map
[00:19.8] (Map) Selected Day 2 node: BATTLE
[00:27.4] (Battle) Moved Knight from Lineup [0] to Lineup [1]
[00:34.2] (Battle) Drew Tier 1 Gacha Ball (Cost: 1 Token)
[00:41.0] (Battle) Ended turn 1 -> combat resolved (VICTORY)
[00:43.2] (Battle) Acknowledged victory modal -> transitioning to Rewards
```

---

## 5. Replay State Machine & Gating Contract

The `ReplayController` playback loop executes via a strict state machine:

```
                  ┌──────────────────────┐
                  │    STATE_LOAD_RUN    │
                  └──────────┬───────────┘
                             │ (Init Master Seed & RunState)
                             ▼
                  ┌──────────────────────┐
        ┌────────►│   STATE_IDLE_WAIT    │◄────────┐
        │         └──────────┬───────────┘         │
        │                    │ ActionQueue.is_busy == false
        │                    ▼
        │         ┌──────────────────────┐         │
        │         │   STATE_COUNTDOWN    │         │
        │         └──────────┬───────────┘         │
        │                    │ think_time <= 0     │
        │                    ▼                     │
        │         ┌──────────────────────┐         │
        │         │    STATE_DISPATCH    │         │
        │         └──────────┬───────────┘         │
        │                    │ ActionQueue.request(action)
        │                    ▼                     │
        │         ┌──────────────────────┐         │
        └─────────┤  STATE_AWAIT_SETTLE  ├─────────┘
        (Instant) └──────────────────────┘ (Yields visuals)
```

### State Definitions:
1. **`STATE_LOAD_RUN`**:
   - Reads Line 1 `RunHeader`.
   - Initializes `GameManager.start_run_with_seed(header.hero_id, header.deck_id, header.deck_order, header.deck_size, header.run_seed)`.
   - Sets `ActionQueue.set_headless_mode(false)` (or `true` if headless playback test).
   - Resets and starts `ActionQueue.reset_global_run_timer(0.0)`.
   - Transitions to `STATE_IDLE_WAIT`.

2. **`STATE_IDLE_WAIT`**:
   - Polls `ActionQueue.is_busy()`.
   - If `true`: wait.
   - If `false`: check if there is an active scene transition pending. If waiting for `Main._notify_scene_transition_complete()`, await `ActionQueue.queue_idle`.
   - Once fully idle: load next action from `.mcr`, set `remaining_think_time = next_action.idle_time`, and transition to `STATE_COUNTDOWN`.

3. **`STATE_COUNTDOWN`**:
   - Deducts think time: `remaining_think_time -= delta`.
   - If spectator accelerates playback speed (e.g. 2x, 4x), delta is already scaled by `Engine.time_scale`.
   - When `remaining_think_time <= 0.0`: transition to `STATE_DISPATCH`.

4. **`STATE_DISPATCH`**:
   - Calls `var accepted = ActionQueue.request(next_action)`.
   - If `accepted == false`: trigger desync breakpoint! Pause playback and emit `playback_desync_error`.
   - If `accepted == true`:
     - If `next_action.yields_for_visuals()`: transition to `STATE_AWAIT_SETTLE`.
     - Otherwise: transition immediately back to `STATE_IDLE_WAIT`.

5. **`STATE_AWAIT_SETTLE`**:
   - Waits for `ActionQueue.action_completed` or `ActionQueue.queue_idle`.
   - Transitions to `STATE_IDLE_WAIT`.

6. **`STATE_COMPLETED`**:
   - Reached EOF. Emits `playback_finished`. Displays playback complete summary.

---

## 6. Architecture & File Blueprint

```
scripts/
└── engine/
    ├── recorder/
    │   ├── GameplayRecorder.gd        # Real-time recorder singleton/node
    │   └── NarrativeLogWriter.gd      # Formatter for human-readable .log
    └── replay/
        ├── ReplayController.gd        # Playback engine & state machine
        └── ReplayReader.gd            # File deserializer (.mcr streaming)
scenes/
└── ui/
    ├── ReplayViewer.tscn              # Overlay UI scene with controls
    └── ReplayViewer.gd                # Speed buttons, scrubber, spectator blocker
```

### Component Responsibilities:

#### 1. `GameplayRecorder.gd`
- Autoload or child of `GameManager`.
- Listens to `ActionQueue.action_started(action: GameAction)`.
- When action starts, writes JSON line to `.mcr` and narrative entry to `.log`, then calls `file.flush()`.
- On run completion or defeat, writes final summary line and closes files.

#### 2. `ReplayController.gd`
- Core playback driver.
- Controls playback state machine, speed multiplier, pause/resume, and EOF handling.
- Exposes signals: `playback_started`, `playback_paused`, `playback_speed_changed(speed)`, `action_dispatched(action)`, `playback_finished`, `playback_desync_error(reason)`.

#### 3. `ReplayViewer.tscn` / `ReplayViewer.gd`
- Top-level canvas layer overlay.
- Contains:
  - Full-screen `SpectatorBlocker` (`mouse_filter = STOP`).
  - Top bar: Run ID, Seed, Elapsed Time, Current Room.
  - Bottom bar: Play/Pause button, Speed buttons (1x, 2x, 4x, 8x), Scrubber bar (showing progress through total actions), Exit button.
  - Hotkey bindings: Space (Play/Pause), 1-4 (Speed), Esc (Exit).

---

## 7. Definition of Done

1. **Automatic Flushed Recording:** Every run automatically creates and flushes `run_<run_id>.mcr` and `run_<run_id>.log` in `user://replays/` on every action.
2. **Deterministic Playback:** Loading any `.mcr` file reproduces the entire run with 100% identical state transitions, PRNG rolls, combat results, and room outcomes.
3. **Save & Continue Continuity:** Continued runs resume appending to the existing `.mcr` file, and replay playback reproduces the combined run as a single seamless session.
4. **Variable Speed Parity:** Replay playback at 1x, 2x, 4x, or 8x resolves identically without animation drops or state drift.
5. **Spectator Isolation:** Spectator mouse clicks and keypresses are completely blocked from interacting with the underlying game while replay controls function cleanly.
6. **Zero Presentation Pollution:** Replay files contain zero screen pixel coordinates, mouse offsets, or UI node references.
