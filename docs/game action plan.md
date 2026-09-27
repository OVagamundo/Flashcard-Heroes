# Architectural Mandate: Game Action Pipeline & Deterministic Command Engine

## 1. Prime Directive

Transform the game's player interaction layer into a **unified, input-gated command pipeline** modeled after the core architecture of *Slay the Spire*:

> **Every player input that generates a game state change MUST create a `GameAction` and pass through `ActionQueue.request()`. Nothing that alters game state may bypass this pipeline.**

This refactor establishes the architectural prerequisite for upcoming systems (**Deterministic Session Replays** and **Headless QA Bot Testing**). It does **not** implement the replay recorder or the QA bot directly; rather, it guarantees that all runtime state mutations and state machine transitions are driven exclusively by discrete `GameAction`s.

---

## 2. Core Architectural Principles

### 1. The Single Pipeline Rule (Zero-Bypass)
- **Comprehensive Definition of Game State:** Game state is the complete state machine of the entire game. It includes not only core numerical data (`RunState` gold, health, tokens, items, deck sizes), but also **room states, phase transitions, and modal lifecycles**.
- Any player input that **alters game data, advances game flow, dismisses a gating modal/popup (e.g. "Got It!" flashcard introduction, tutorial dialogs, battle results), or unlocks subsequent interactions MUST instantiate a `GameAction` and pass through `ActionQueue.request()`**.
- If an input does not change game state or gate progress (e.g. raw mouse cursor movement across empty space, hover highlights, passive tooltips, non-blocking entity inspections), it is client-side presentation. But the moment **any input moves the game state machine forward**, it MUST enter the pipeline as a `GameAction`.
- UI controllers, room scenes, and `GlobalInteractionRouter` have zero authority to mutate state, deduct currencies, grant items, advance phases, or close gating windows directly. Their sole role upon receiving user input is to construct and request a `GameAction`.

### 2. Input Gating (The Slay the Spire Model)
- While `ActionQueue` is busy processing an action and its visual consequences (`is_busy() == true`), **player inputs are blocked**.
- No new player input can fire, corrupt state, or cause race conditions while animations or events are resolving.
- When the action and its cascaded visual events finish, the action signals completion (`finish_visuals()`), resetting `is_busy() = false` and enabling player input for the next decision.

### 3. 100% Behavioral & Visual Preservation
- The game must look, feel, sound, and play **identically** to the pre-refactor baseline (`Code/AllProjectFiles.md`).
- Visual timing, pacing (e.g. coins flying before transactions commit), button disabling, sound effects, and animations must be preserved completely. The refactor wraps player decisions into `GameAction`s; it does not change how the game plays or feels.

### 4. Absolute Execution Equivalence (The Universal Action Path)
- Real gameplay, replay playback, and headless bot execution must follow the **100% identical command execution path**.
- The core engine, `ActionQueue`, and `GameAction`s have zero knowledge of who submitted an action. The only difference across all three modes is the input source:
  - **Real Gameplay:** Mouse, keyboard, or touch inputs generate a `GameAction` -> `ActionQueue.request(action)`.
  - **Replay Playback:** Replay file deserializer reads an action -> `ActionQueue.request(action)`.
  - **Headless Bot:** Automated decision agent selects an action -> `ActionQueue.request(action)`.
- Never branch or alter gameplay logic based on whether the game is replaying or being played live.

### 5. Grounded Timeline via Authoritative Global Run Timer
- All timed events and recorded action timestamps must be grounded in an authoritative **Global Run Timer** (elapsed simulation time since run start, tracked in the core run state).
- Relying exclusively on relative think times or local delays causes small processing lags and frame variations to accumulate into severe desynchronizations over long runs. A global run clock guarantees absolute time grounding across recording, narrative logging, telemetry, and playback.

### 6. Pause Fidelity & Speed Compounding
- **Pause Reproduction:** Pausing during gameplay is a state change that is recorded and **faithfully reproduced in replay playback** so that the replay unfolds 100% identically to the real playthrough. Spectators can use the replay viewer's speed controls to fast-forward through pauses if desired.
- **Multiplicative Speed Compounding:** In-game speed settings (such as combat speed toggles: 1x, 2x, 4x) compound multiplicatively with global replay playback speed controls:
  $$\text{Effective Speed} = \text{Base Gameplay Speed} \times \text{Replay Playback Multiplier}$$
  For example, a combat recorded at 2x base speed, watched at 2x replay playback speed, plays back at 4x effective speed. Outside of combat (at 1x base speed), it plays back at 2x speed. Because Godot's `Engine.time_scale` universally scales deltas, tweens, and timers, synchronization is preserved perfectly across all compounding factors.

---

## 3. Strict Precautions & Guardrails

The implementing programmer agent must adhere to the following firm guardrails:

### Precaution 1: Strict Data Purity in Actions (NO UI Coordinates or Object Pointers)
* `GameAction` payloads must contain **ONLY logical game state data** (`int`, `StringName`, `String`, `bool`, `LocationIdentifier`).
* **NEVER pass screen pixel coordinates (`Vector2`), mouse positions, Viewport transforms, UI Control references, or engine Resource object pointers into a `GameAction`.**
* **Presentation Responsibility:** The UI View (e.g. `Shop.gd`, `BlackMarket.gd`, `RestSite.gd`) owns its own visual elements and layout. If an animation requires screen coordinates (such as spawning coin VFX at a button or flying a gachaball from a slot), the UI View must determine those coordinates locally from its own node hierarchy and slot indices. The Action payload must remain purely logical data.

### Precaution 2: Respect Existing Visual Pacing and Timing
* In several rooms (e.g., Shop purchases, Rest Site draws), the original game's visual design plays an animation (e.g. coins flying to the button/slot) *before* the transaction commits, followed by an animation of the resulting gachaball flying to the machine.
* The refactor must **preserve this visual flow and feel**. Do not prematurely snap state changes if it breaks the visual choreography, and do not shove UI animation tweens directly into action classes to bypass proper view handling.

### Precaution 3: Headless Mode Must Perform Real State Mutations
* In headless mode (`ActionQueue.is_headless_mode() == true`), animations are bypassed and actions resolve immediately on frame 0.
* **Actions MUST still execute genuine state mutations in headless mode** (deducting gold/tokens, transferring items, updating stats, advancing rooms, transitioning modal states).
* **NEVER leave mutations as no-ops (`pass`)**. If an action skips visual tweens, the backend state change must still execute deterministically.

### Precaution 4: Room Generation and State Must Live in the Data Layer (Not UI `_ready()`)
* Because the headless QA bot must generate `.mcr` replays that can be reproduced identically in the normal visual client, **room state, procedural generation (shop stock, rewards, rest capsules, Dojo choices), and room tokens must NEVER be tied to UI scene `_ready()` callbacks or UI-local variables**.
* If generation logic lives inside a UI node, headless runs will fail to generate data or will roll RNG out of order compared to visual mode, causing immediate replay desynchronization. Generation, room stock, and room tokens belong strictly to the data/engine layer (`RunState`, pool directors).

### Precaution 5: Scene Transition Actions Must Not Signal Completion Prematurely
* Actions that transition between scenes or rooms (`SelectPathAction`, `LeaveShopAction`, etc.) must **never** invoke `finish_visuals()` before the destination room has fully loaded, entered the scene tree, and signaled it is ready for player input.
* Signaling `finish_visuals()` while an asynchronous scene load is still pending causes `ActionQueue` to declare itself idle prematurely, causing replays and bots to dispatch subsequent actions against an uninitialized scene.

### Precaution 6: Post-Loadout Playback Initialization Boundary
* Replay playback initializes directly from the **post-loadout run state** (Hero selected, Deck selected, Master Seed initialized, initial run inventory configured at Floor 1 entrance), rather than playing through Title screen menu clicks.
* However, all player configuration choices (Hero, Deck, Seed, Options) are captured in the `.mcr` header metadata for telemetry, statistics, and run auditing.

### Precaution 7: Input & Drag-and-Drop Lifecycles Must Cleanly Reset
* If an action is rejected by `validate()` or dropped by the queue, the UI interaction lifecycle must be cleanly terminated.
* Specifically, drag-and-drop systems (like `GlobalInteractionRouter`) must ensure `end_drag(false)` is invoked on invalid actions so dragged items cleanly snap back and never get stuck floating in screen limbo.

### Precaution 8: Zero Codebase Assumptions (Investigate First)
* **No assumptions on how the codebase is set up should be made.** The active agent programmer must investigate the actual files, scenes, and scripts until there are zero assumptions, since the complete codebase is available to read and verify.
* Never assume how a room manages its state, how signals are wired, or where data resides. Always inspect the active implementation before designing or writing any code.

---

## 4. Player Actions Across Game Rooms

The following player decisions represent the interactions across the game that alter game state or gate progress, and must be routed through `GameAction`s:

| Room / Context | Typical Action | Player Intent & State Mutation |
| :--- | :--- | :--- |
| **Map Navigation** | `SelectPathAction` | Choose a node index on the path map to transition rooms. |
| **Battle Management** | `MoveInventoryAction` | Move, equip, or use units/items between bench, board, and inventory. |
| **Battle Management** | `ConfirmMergeAction` | Confirm a merge recipe between two units from `ChoiceWindow`. |
| **Battle Management** | `ConfirmSwapAction` | Swap positions of two units or items from `ChoiceWindow` or direct drag. |
| **Battle Management** | `DrawGachaAction` | Pull a unit/item from combat gacha machines using combat tokens. |
| **Battle Management** | `EndTurnAction` | Finish management phase and transition to combat execution. |
| **Battle Flow** | `AcknowledgeBattleResultsAction` | Acknowledge end-of-battle victory/defeat modal to open rewards or map. |
| **Battle Settings** | `SetCombatSpeedAction` | Toggle combat playback speed multiplier (1x, 2x, 4x). |
| **Flashcard Minigame**| `AcknowledgeFlashcardIntroAction` | Dismiss "Got It!" card introduction, transition to `SPRINT_ACTIVE`, and start countdown timer. |
| **Flashcard Minigame**| `SubmitFlashcardAnswerAction` | Submit an answer choice, update streak, award tokens, load next question. |
| **Flashcard Minigame**| `SkipFlashcardAction` | Skip current flashcard, reset streak, load next question. |
| **Tutorial System** | `DismissTutorialAction` | Dismiss a blocking tutorial dialog and resume game progression. |
| **Run Lifecycle** | `PauseRunAction` | Toggle pause state on/off, preserving simulation timeline integrity. |
| **Shop** | `BuyShopAction` | Purchase an item/unit from a specific shop slot index. |
| **Shop** | `RerollShopAction` | Pay gold to reroll shop stock. |
| **Shop** | `LeaveShopAction` | Leave the shop and return to map navigation. |
| **Reward Room** | `DrawRewardAction` | Spend reward tokens to draw a capsule. |
| **Reward Room** | `CollectRewardAction` | Claim a drawn reward capsule into inventory/trinkets. |
| **Reward Room** | `SellRewardAction` | Sell a drawn reward capsule for gold. |
| **Reward Room** | `StudyRewardAction` | Initiate flashcard minigame to earn reward tokens. |
| **Reward Room** | `LeaveRewardAction` | Finalize/discard remaining rewards and exit room. |
| **Rest Site** | `DrawRestSiteAction` | Spend tokens to draw a stat capsule. |
| **Rest Site** | `UpgradeRestSiteAction` | Apply a drawn stat capsule to the Hero. |
| **Rest Site** | `StudyRestSiteAction` | Initiate flashcard minigame to earn rest site tokens. |
| **Rest Site** | `LeaveRestSiteAction` | Auto-apply remaining capsules and exit rest site. |
| **Dojo / Training** | `StartTrainingAction` | Commit gold, select target unit & stat (`hp`/`pwr`), and initiate minigame. |
| **Dojo / Training** | `TrainUnitStatAction` | Spend 1, 2, or 3 tokens inside training popup to roll and apply stat buffs. |
| **Dojo / Training** | `CloseTrainingPopupAction` | Close training popup after training, returning to dojo room view. |
| **Dojo / Training** | `LeaveTrainingAction` | Exit the training ground and return to map navigation. |
| **Black Market** | `RemoveBlackMarketAction` | Pay gold to purge a unit/item from the run. |
| **Black Market** | `TransformBlackMarketAction` | Pay gold to reroll a unit/item into a new instance. |
| **Black Market** | `LeaveBlackMarketAction` | Exit the black market and return to map navigation. |

---

## 5. Input Gating & Visual Settling Contract

1. **Submission (`request`)**: UI interactions instantiate and submit a `GameAction` to `ActionQueue.request(action)`.
2. **Gating**: If the queue is currently busy (`is_busy() == true`), incoming requests are dropped or rejected to prevent race conditions and concurrent input execution.
3. **Execution & Visuals**:
   - In UI mode: the action and view coordinate playback. `ActionQueue` remains busy while visual feedback runs.
   - In headless mode: the action executes state changes instantly without waiting for tweens or visual timers.
4. **Settling**: When animations and cascaded events conclude, the action signals completion (`finish_visuals()`), resetting `is_busy() = false` and emitting `queue_idle` so the next player input can be accepted.

---

## 6. Definition of Done

1. **100% Action Routing:** All player inputs that alter game state, advance progression, or dismiss gating modals are routed through `GameAction` and `ActionQueue`.
2. **Zero Bypass:** No UI button callback, scene script, or untracked signal directly mutates run state, inventory, or modal states.
3. **Zero Presentation Leakage:** No `GameAction` requires or stores screen coordinates, pixel offsets, or UI node references.
4. **Visual & Behavioral Parity:** The game looks, feels, and plays identically to the pre-refactor state. Animations and visual pacing are fully preserved.
5. **Clean Drag-and-Drop Lifecycle:** Dropping items on invalid targets cleanly cancels the interaction without freezing UI state.
6. **Headless Integrity:** In headless mode, all actions mutate state deterministically without crashing or relying on UI elements.
7. **Pause & Speed Parity:** Pauses are faithfully reproduced in replay playback, and replay playback speeds compound multiplicatively with base in-game speeds.