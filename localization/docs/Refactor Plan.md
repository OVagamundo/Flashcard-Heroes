# Architectural Mandate: Game Action Pipeline & Deterministic Command Engine

## 1. Prime Directive

Transform the game's player interaction layer into a **unified, input-gated command pipeline** modeled after the core architecture of *Slay the Spire*:

> **Every player input that generates a game state change MUST create a `GameAction` and pass through `ActionQueue.request()`. Nothing that alters game state may bypass this pipeline.**

This refactor establishes the architectural prerequisite for upcoming systems (**Deterministic Session Replays** and **Headless QA Bot Testing**). It does **not** implement the replay recorder or the QA bot directly; rather, it guarantees that all runtime state mutations are driven exclusively by discrete `GameAction`s.

---

## 2. Core Architectural Principles

### 1. The Single Pipeline Rule (Zero-Bypass)
- Any player input—whether it originates from a mouse interaction (click, hover, drag and drop, etc.), keyboard key presses, touch tap, or any other input that alters game state—**must instantiate a `GameAction` and submit it to `ActionQueue.request()`**.
- If an input does not change game state (e.g. raw mouse cursor movement across empty space), it is just client-side rendering. But the moment **any input triggers a game state change**, it MUST enter the pipeline as a `GameAction`.
- UI controllers, room scenes, and `GlobalInteractionRouter` have zero authority to mutate `RunState`, deduct gold, grant items, or alter game state directly. Their sole role upon input is to construct and request a `GameAction`.

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
* In headless mode (`ActionQueue.is_headless_mode() == true`), animations are bypassed and actions resolve immediately.
* **Actions MUST still execute genuine state mutations in headless mode** (deducting gold/tokens, transferring items, updating stats, advancing rooms).
* **NEVER leave mutations as no-ops (`pass`)**. If an action skips visual tweens, the backend state change must still execute deterministically.

### Precaution 4: Room Generation and State Must Live in the Data Layer (Not UI `_ready()`)
* Because the headless QA bot must generate `.mcr` replays that can be reproduced identically in the normal visual client, **room state and procedural generation (shop stock, rewards, rest capsules, Dojo choices) must NEVER be tied to UI scene `_ready()` callbacks**.
* If generation logic lives inside a UI node, headless runs will fail to generate data or will roll RNG out of order compared to visual mode, causing immediate replay desynchronization. Generation and data state belong strictly to the data/engine layer (`RunState`, pool directors).

### Precaution 5: Scene Transition Actions Must Not Signal Completion Prematurely
* Actions that transition between scenes or rooms (`SelectPathAction`, `LeaveShopAction`, etc.) must **never** invoke `finish_visuals()` before the destination room has fully loaded, entered the scene tree, and signaled it is ready for player input.
* Signaling `finish_visuals()` while an asynchronous scene load is still pending causes `ActionQueue` to declare itself idle prematurely, causing replays and bots to dispatch subsequent actions against an uninitialized scene.

### Precaution 6: Post-Loadout Playback Initialization Boundary
* Replay playback initializes directly from the **post-loadout run state** (Hero selected, Deck selected, Master Seed initialized, initial run inventory configured at Floor 1 entrance), rather than playing through Title screen menu clicks.
* However, all player actions and configuration choices are still captured in the recording for telemetry, statistics, and run auditing.

### Precaution 7: Input & Drag-and-Drop Lifecycles Must Cleanly Reset
* If an action is rejected by `is_valid()` or dropped by the queue, the UI interaction lifecycle must be cleanly terminated.
* Specifically, drag-and-drop systems (like `GlobalInteractionRouter`) must ensure `end_drag(false)` is invoked on invalid actions so dragged items cleanly snap back and never get stuck floating in screen limbo.

### Precaution 8: Zero Codebase Assumptions (Investigate First)
* **No assumptions on how the codebase is set up should be made.** The active agent programmer must investigate the actual files, scenes, and scripts until there are zero assumptions, since the complete codebase is available to read and verify.
* Never assume how a room manages its state, how signals are wired, or where data resides (e.g. assuming a separate manager exists when logic might live inside a UI controller). Always inspect the active implementation before designing or writing any code.

---

## 4. Player Actions Across Game Rooms

The following player decisions represent the interactions across the game that alter game state and must be routed through `GameAction`s:

| Room / Context | Typical Action | Player Intent |
| :--- | :--- | :--- |
| **Map Navigation** | `SelectPathAction` | Choose a node on the path map to transition rooms. |
| **Battle Management** | `MoveInventoryAction` | Move, equip, or use units/items between bench, board, and inventory. |
| **Battle Management** | `ConfirmMergeAction` | Confirm a merge recipe between two units. |
| **Battle Management** | `ConfirmSwapAction` | Swap positions of two units or items. |
| **Battle Management** | `DrawGachaAction` | Pull a unit/item from combat gacha machines using battle tokens. |
| **Battle Management** | `EndTurnAction` | Finish management phase and transition to combat execution. |
| **Flashcard Minigame**| `SubmitFlashcardAnswerAction` | Submit an answer to the current flashcard question. |
| **Flashcard Minigame**| `SkipFlashcardAction` | Skip the current flashcard question. |
| **Shop** | `BuyShopAction` | Purchase an item/unit from a specific shop slot. |
| **Shop** | `RerollShopAction` | Pay gold to reroll shop stock. |
| **Shop** | `LeaveShopAction` | Leave the shop and return to map navigation. |
| **Reward Room** | `DrawRewardAction` | Spend reward tokens to draw a capsule. |
| **Reward Room** | `CollectRewardAction` | Claim a drawn reward into inventory/trinkets. |
| **Reward Room** | `SellRewardAction` | Sell a drawn reward for gold. |
| **Reward Room** | `StudyRewardAction` | Initiate flashcard minigame to earn reward tokens. |
| **Reward Room** | `LeaveRewardAction` | Finalize remaining rewards and exit room. |
| **Rest Site** | `DrawRestSiteAction` | Spend tokens to draw a stat capsule. |
| **Rest Site** | `UpgradeRestSiteAction` | Apply a stat capsule to the Hero. |
| **Rest Site** | `StudyRestSiteAction` | Initiate flashcard minigame to earn rest site tokens. |
| **Rest Site** | `LeaveRestSiteAction` | Auto-apply remaining capsules and exit rest site. |
| **Dojo / Training** | `StartTrainingAction` | Spend gold/tokens to train a specific unit stat. |
| **Dojo / Training** | `LeaveTrainingAction` | Exit the training ground. |
| **Black Market** | `RemoveBlackMarketAction` | Pay gold to purge a unit/item from the run. |
| **Black Market** | `TransformBlackMarketAction` | Pay gold to reroll a unit/item into a new instance. |
| **Black Market** | `LeaveBlackMarketAction` | Exit the black market. |

*(Note: The active programmer agent should inspect the active codebase to verify exact parameters and room state implementations.)*

---

## 5. Input Gating & Visual Settling Contract

1. **Submission (`request`)**: UI interactions submit a `GameAction` to `ActionQueue.request(action)`.
2. **Gating**: If the queue is currently busy (`is_busy() == true`), the request is dropped or blocked to prevent race conditions and concurrent input execution.
3. **Execution & Visuals**:
   - In UI mode: the action and view coordinate playback. `ActionQueue` remains busy while visual feedback runs.
   - In headless mode: the action executes state changes instantly without waiting for tweens or visual timers.
4. **Settling**: When animations and cascaded events conclude, the action signals completion (`finish_visuals()`), resetting `is_busy() = false` and emitting `queue_idle` so the next player input can be accepted.

---

## 6. Definition of Done

1. **100% Action Routing:** All player inputs that alter game state or progress the run are routed through `GameAction` and `ActionQueue`.
2. **Zero Bypass:** No UI button callback, scene script, or untracked signal directly mutates run state or inventory.
3. **Zero Presentation Leakage:** No `GameAction` requires or stores screen coordinates, pixel offsets, or UI nodes.
4. **Visual & Behavioral Parity:** The game looks, feels, and plays identically to the pre-refactor state. Animations and visual pacing are fully preserved.
5. **Clean Drag-and-Drop Lifecycle:** Dropping items on invalid targets cleanly cancels the interaction without freezing UI state.
6. **Headless Integrity:** In headless mode, all actions mutate state deterministically without crashing or relying on UI elements.