# Architectural Mandate: Game Action Pipeline & Deterministic Event-Driven Machine

## 1. Prime Directive: The Pure Event-Driven Machine (The Slay the Spire 2 Model)

The game's runtime architecture is fundamentally a **pure deterministic event-driven state machine**, modeled after the core engine design of *Slay the Spire 2*:

> **The game does not possess a free-running continuous gameplay loop that mutates state or presentation behind the scenes. The game advances strictly and exclusively through an ordered sequence of discrete Actions.**
> 
> **ANY player input or system trigger that produces ANY visual or gamestate consequence—including UI window opening/closing, card/entity inspections, tutorial page progression, valid gameplay transactions, and even failed/rejected attempts (such as an invalid drag drop that snaps back with rejection VFX)—MUST enter the pipeline as an ordered `GameAction`.**

When this architectural rule is strictly honored with **zero bypasses**, recording and deterministic playback become fundamentally trivial:
* **Recording is trivial:** Every action that enters the pipeline is serialized to the `.mcr` stream upon acceptance.
* **Playback is trivial:** Replay reads the serialized actions and feeds them directly back into `ActionQueue.request()`. Because every visual and state consequence in the game is driven by an Action, replaying the action stream reproduces the identical game session—both visually and logically—without ad-hoc playback shims or desync workarounds.

---

## 2. Core Architectural Principles

### 1. The Zero-Bypass Universal Pipeline
- **No Background Mutations:** No scene script, UI node, signal listener, or free-running `_process` timer may independently alter game data or change visible UI state outside an active `GameAction` transaction.
- **Universal Scope:** Every player decision with an observable effect enters the pipeline:
  - **State Mutations:** Spending gold, moving inventory, merging, drafting, rolling stats, answering flashcards, choosing paths.
  - **Interface & Visibility Changes:** Opening/closing the inventory drawer, opening/closing the discard pile, opening/closing inspection windows, advancing tutorial pages.
  - **Failed / Rejected Attempts:** Dropping an item in an illegal slot or attempting an action without sufficient resources (which produces visual snap-back or error feedback) is an action transaction that resolves with the appropriate presentation feedback.
- **Universal Execution Path:** Live play, automated QA bots, and replay playback use the exact same validation and execution path through `ActionQueue`. The core engine has zero knowledge of the input source.

### 2. Input Gating & Visual Choreography
- When an action is resolving or playing its visual presentation, incoming conflicting player input is gated.
- Once the action's visual choreography concludes, the action signals completion, resetting queue state and enabling player input for the next decision.
- In headless mode, visual animations are skipped while state mutations resolve synchronously on frame 0.

### 3. Absolute Causality & Presentation Decoupling
- **Decoupled Architecture:** The data model (`RunState`, `GameManager`, subsystem rules) is strictly decoupled from presentation views (`WindowManager`, room views, visual tweens).
- `GameAction.execute()` owns the logical transaction and drives the presentation. Views react to resolved action results to play animations, sound effects, and UI movements. No view may independently repeat the transaction or trigger side-effect mutations.

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
| **Inventory / Drawer** | `OpenInventoryAction` | Open and populate the Run or Battle inventory drawer (`kind`: `"RUN"` or `"BATTLE"`). |
| **Inventory / Drawer** | `CloseInventoryAction` | Close the open inventory drawer and dismiss inventory drop zones. |
| **Inspection UI** | `InspectEntityAction` | Open contextual inspection window for an entity (`entity_uuid`, `definition_id`, `window_kind`). |
| **Inspection UI** | `CloseInspectionAction` | Dismiss one or all active inspection windows (`window_id`, `close_all: bool`). |
| **Battle Views** | `OpenDiscardPileAction` | Open the battle discard pile inspection drawer. |
| **Battle Views** | `CloseDiscardPileAction` | Close the battle discard pile inspection drawer. |
| **Entity Selection** | `SelectEntityAction` | Select an entity at a given location, displaying selection highlights, merge indicators, and drop targets (`location: LocationIdentifier`, `entity_uuid: String`). |
| **Entity Selection** | `DeselectAction` | Clear current entity selection, dismiss confirm drop zones, and clear selection highlights. |
| **Tutorial System** | `AdvanceTutorialPageAction` | Advance to the next page of an active multi-page tutorial popup (`tutorial_id`, `target_page: int`). |
| **Drag & Drop** | `CancelDragAction` | Handle drag cancellation or failed drop attempt (empty drop, invalid target, ESC key), playing landing bounce, deselect audio, and resetting drag state. |

---

## 4.1 First-Class Interface Action Contract & Implementation Specifications

In accordance with the Prime Directive and Single Pipeline Rule, interface actions that change the visible interaction context, expose legal drop targets, or alter what the player can inspect or choose next are **first-class `GameAction`s**. They are not optional presentation shims:

1. **`OpenInventoryAction`**:
   - **Payload**: `kind: String` (`"RUN"` or `"BATTLE"`).
   - **Validation**:
     - Cannot open if queue is busy with a conflicting transaction.
     - Battle inventory drawer cannot open during `COMBAT` phase animations.
     - Cannot open if the requested inventory is already open and interactive.
   - **Execution**:
     - Tells `WindowManager` to open and populate the respective inventory container (`win.populate()`), instantiating slot views and updating interaction drop zones.
   - **Settling**: Yields for visual drawer slide animation to complete before subsequent drag or selection inputs are accepted.

2. **`CloseInventoryAction`**:
   - **Payload**: `kind: String` (`"RUN"` or `"BATTLE"`).
   - **Validation**: Cannot close if the inventory is already closed or in the middle of closing.
   - **Execution**: Tells `WindowManager` to close the inventory window, clearing drop zones in `Main` and resetting interaction states cleanly.

3. **`SelectEntityAction` & `DeselectAction`**:
   - **`SelectEntityAction` Payload**: `location: LocationIdentifier`, `entity_uuid: String`.
     - **Validation**: Target location is valid or entity UUID is non-empty.
     - **Execution**: Authoritatively sets entity selection in `GlobalInteractionRouter.apply_select_entity(loc, uuid)`. This triggers selection visual highlights, displays contextual confirmation drop zones (e.g. Reward Collect/Sell zones, Black Market Transform/Remove zones), and computes merge recipe indicators.
   - **`DeselectAction` Payload**: none.
     - **Validation**: Always valid.
     - **Execution**: Authoritatively clears entity selection in `GlobalInteractionRouter.apply_deselect_entity()`, unhighlighting views and dismissing confirmation drop zones.

4. **`InspectEntityAction` & `CloseInspectionAction`**:
   - **Payload**: `entity_uuid: String`, `definition_id: String`, `context: String`.
   - **Validation**: Entity exists or is inspectable from current room state.
   - **Execution**: Opens or closes contextual inspection cards through `WindowManager`, guaranteeing that locked inspection state is identical across live and replay sessions.

5. **`AdvanceTutorialPageAction` & `DismissTutorialAction`**:
   - **`AdvanceTutorialPageAction` Payload**: `tutorial_id: String`, `page_index: int`. Advances tutorial pages.
   - **`DismissTutorialAction` Payload**: `tutorial_id: String`. Authoritatively completes and dismisses tutorial modals.

6. **`AcknowledgeBattleResultsAction` & `AcknowledgeRunCompleteAction`**:
   - **`AcknowledgeBattleResultsAction` Payload**: `is_victory: bool`. Dismisses the end battle popup (`EndBattlePopup`) and settles when the destination scene (Reward or Title) finishes transitioning and loading.
   - **`AcknowledgeRunCompleteAction` Payload**: none. Dismisses `RunCompletePopup` and transitions to the title screen.

7. **`CancelDragAction`**:
   - **Payload**: `source_location: LocationIdentifier`, `target_location: LocationIdentifier`, `reason: String`.
   - **Validation**: Drag cancellation or failed attempt is always valid to process.
   - **Execution**: Restores visibility of the source view at `source_location`, plays landing bounce animation, triggers deselect audio, and terminates drag state in `GlobalInteractionRouter`. Replay playback faithfully reproduces the failed drag attempt and snap-back visual.

### Modal & Contextual Choice Lifecycle Contract
* **Prompt Windows (`ChoiceWindow`)**: When a player drops an item or unit onto another compatible entity, `ChoiceWindow` opens to present options (e.g. Merge vs. Swap). Choosing an option dispatches `ConfirmMergeAction`, `MergeEncounterAction`, or `ConfirmSwapAction`. **The action execution itself authoritatively closes the prompt window (`WindowManager.close_choice_window()`)** so that live play and replay playback maintain identical window states.
* **Deterministic State Digest Serialization**: State digests must never contain raw Godot `Object` or `Resource` memory pointer strings (`():<Resource#-922337... >`), as heap addresses fluctuate between runs. All game state snapshots and `_turn_metadata` entries must serialize `LocationIdentifier` and entity references to dictionaries (`.to_dict()`) before hashing.

### Distinction: Transient Presentation vs. Discrete Player Actions
* **Continuous Mouse Movement & Transient Hover**: Moving the mouse cursor and hovering briefly over a unit or item to see a transient tooltip or inspection card is a continuous presentation effect. It does NOT mutate gamestate or lock interface context. Transient hover windows open and close locally in `WindowManager` and are suppressed during replay playback (`is_vcr_playing() == true`).
* **Discrete Actions**: In contrast, **clicking to select an entity (`SelectEntityAction`)**, **clicking away to deselect (`DeselectAction`)**, **clicking to lock an inspection window (`InspectEntityAction`)**, and **closing an inspection window (`CloseInspectionAction`)** are discrete player decisions that alter visual interaction context and must enter the pipeline as `GameAction`s.

### Elimination of UI Bypasses
All UI buttons (such as `%OpenInventoryButton`, machine clicks in `Main.gd`, and room leave buttons) and global background dismiss clicks **MUST NOT** directly emit mutation signals or call `WindowManager` methods directly. They must instantiate the corresponding `GameAction` and submit it to `ActionQueue.request()`. Replay and live play both execute through this identical sequence.

## 5. Input Gating & Resolution Boundary

1. **Submission:** Gameplay and replay-relevant interface actions enter through one ordered action boundary.
2. **Contextual gating:** Reject conflicting gameplay actions while their transaction is active. Explicit meta-actions such as pause/speed and supported inspection controls follow their own validated rules and ordering; queue busy alone does not define all legal input.
3. **Resolution:** An action owns one authoritative result. The view presents that result; headless execution skips presentation while resolving the same state.
4. **Settling:** Wait for every causal consequence that can affect state or next input availability. Decorative animation completion is not a gameplay checkpoint unless the game deliberately gates the next choice on it. The action finishes only its own transaction, not whichever action happens to be active.

---

## 6. Definition of Done

1. **Complete Action Coverage:** Gameplay choices and explicit replay-relevant interface choices are listed by context and use the shared ordered action boundary.
2. **Zero Bypass:** No UI callback, scene script, timer, or legacy signal commits an authoritative mutation outside its owning action transaction or typed system-origin consequence.
3. **Stable Payloads:** Actions use logical IDs and values, never screen coordinates, pixel offsets, or UI node references.
4. **Outcome Parity:** Live and replay execution of the same action from the same state produces the same authoritative result. Pixel, audio, and decorative-animation identity are not required.
5. **Clean Drag-and-Drop Lifecycle:** Invalid drops cancel cleanly and do not mutate state.
6. **Headless Integrity:** Headless mode resolves the same gameplay transactions without requiring UI nodes.
7. **Time/RNG Integrity:** Automatic timeouts, gameplay RNG, pause, and speed controls preserve the same results and legal action order in every supported playback speed.
