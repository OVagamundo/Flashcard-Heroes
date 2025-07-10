Flashcard Heroes - Core Mechanics MVP TDD (Definitive Edition)
Part 1: Project Blueprint
1.1 Architectural Principles
Data is the Source of Truth: Game state is stored in data structures (Arrays, Dictionaries). The UI is a disposable reflection of this data.
The Intent-Action Model: User input is translated into a clear "intent" signal before being processed by logic controllers.
Hierarchical Input Handling: User input is processed in a strict order of priority. An input event is "consumed" at the first level that can handle it, preventing it from propagating further. The order is: 1) Window Blockers, 2) Individual UI Components (Buttons, Views), 3) Inspection Window Panels, 4) The Global _unhandled_input handler in WindowManager as a final fallback for "background" clicks.
Visually Consistent Components: UI components representing similar data (e.g., inventory slots, whether full or empty) should maintain a consistent size within their container to ensure a clean, grid-like appearance.
Centralized, Context-Aware Managers: Singleton managers (e.g., InventoryManager) are the sole authorities for their specific logic domains. InteractionManager is a state machine for UI selection, not a direct input handler.
Reactive UI: The UI redraws itself in response to global "state changed" signals, ensuring it is always synchronized with the data.
1.2 Directory Structure
Generated code
res://
├── assets/
│   ├── sprites/
│   │   ├── units/
│   │   └── items/
├── resources/
│   ├── units/
│   ├── items/
│   ├── abilities/
│   ├── recipes/
│   └── decks/
├── scenes/
└── scripts/
├── localization.csv
Use code with caution.
Part 2: Data Schemas & Structures
2.1 Data Resource Schemas

**LocationIdentifier.gd**: Resource, class_name LocationIdentifier. The type-safe object for identifying any slot.
- Properties: 
  - `@export var container: StringName`
  - `@export var index: int`
  - `@export var tier: int = -1` (-1 indicates no tier)

**DataContainer.gd**: Object, class_name DataContainer. The abstract base class for all data collections.
- Methods:
  - `get_uuid(index: int) -> String`
  - `set_uuid(index: int, uuid: String)`
  - `find_first_empty_slot() -> int`
  - `get_all_uuids() -> Array[String]`

**FixedArrayContainer.gd**: extends DataContainer, class_name FixedArrayContainer. For fixed-size collections like lineups and benches.

**GridContainer.gd**: extends DataContainer, class_name GridContainer. For growable collections like inventories. Contains its own internal growth logic.

**RunState.gd**: Resource, class_name RunState. The persistent state for an entire run.
- Properties:
  - `gold: int`
  - `hero_instance: GachaBallInstance`
  - `run_instances: Dictionary[String, GachaBallInstance]`
  - `run_inventory_containers: Dictionary[StringName, GridContainer]`

GachaBallDefinition.gd: Resource, class_name GachaBallDefinition. The template for a GachaBall.
Properties: @export var id: StringName, @export var display_name_key: String, @export var description_key: String, @export var icon: Texture2D, @export var tier: int, @export var category: StringName, @export var item_slot_count: int, @export var base_hp: int = 0, @export var base_pwr: int = 0, @export var bonus_hp: int = 0, @export var bonus_pwr: int = 0, @export var ability_definitions: Array[AbilityDefinition]
GachaBallInstance.gd: Resource, class_name GachaBallInstance. A unique instance of a GachaBall.
Properties: definition_id: StringName, ball_uuid: String, origin_uuid: String, equipped_item_uuids: Array[String], current_hp: int, current_pwr: int
Method: initialize(def: GachaBallDefinition): Sets definition_id, generates ball_uuid, resizes equipped_item_uuids, and initializes current_hp and current_pwr from the definition's base_hp and base_pwr.
Method: create_battle_copy() -> GachaBallInstance: Creates a new deep copy, assigning a new ball_uuid and setting origin_uuid to the original's ball_uuid.
Method: recalculate_stats(all_instances_db: Dictionary): Calculates current_hp and current_pwr by starting with base stats from the definition and adding all bonus_hp and bonus_pwr from equipped items.
MergeRecipe.gd: Resource, class_name MergeRecipe. Defines a valid merge.
Properties: @export var id: StringName, @export var ingredient_a_id: StringName, @export var ingredient_b_id: StringName, @export var result_id: StringName, @export var is_self_merge: bool, @export var merge_type: StringName
ConditionDefinition.gd: Resource, class_name ConditionDefinition. Defines ability conditions. For MVP, its evaluate() method is a placeholder that always returns true.
FlashcardDeckDefinition.gd: Resource, class_name FlashcardDeckDefinition.
Properties: @export var id: StringName, @export var display_name_key: String, @export var card_list: Array[Dictionary]
AbilityDefinition.gd: Resource, class_name AbilityDefinition. Defines an ability.
Properties: @export var id: StringName, @export var name_key: String, @export var description_key: String, @export var effect: EffectDefinition.
EffectDefinition.gd: Resource, class_name EffectDefinition. A base class for all ability effects.
Method: execute(source: GachaBallInstance, targets: Array[GachaBallInstance], battle_manager: BattleManager).
2.2 Inventory Data Structures

This table defines the owner, container type, and behavior of every data container in the game.

| Container Name | Identifier (StringName) | Owner | DataContainer Class | Notes |
|----------------|-------------------------|-------|---------------------|-------|
| **Persistent Run Containers** | | | | Data persists for the entire run. |
| Run Inventory (Tier 1) | RunInventoryT1 | RunState | GridContainer | Initial size 16x1. |
| Run Inventory (Tier 2) | RunInventoryT2 | RunState | GridContainer | Initial size 16x1. |
| Run Inventory (Tier 3) | RunInventoryT3 | RunState | GridContainer | Initial size 16x1. |
| **Temporary Battle Containers** | | | | Data is created at battle start and destroyed at battle end. |
| Battle Inventory (Tier 1) | BattleInventoryT1 | BattleManager | GridContainer | Initial size 16x1, grows when full. |
| Battle Inventory (Tier 2) | BattleInventoryT2 | BattleManager | GridContainer | Initial size 16x1, grows when full. |
| Battle Inventory (Tier 3) | BattleInventoryT3 | BattleManager | GridContainer | Initial size 16x1, grows when full. |
| Discard Pile | DiscardPile | BattleManager | GridContainer | Initial size 16x1, grows when full. |
| Player Lineup | PlayerLineup | BattleManager | FixedArrayContainer | Fixed size: 6 slots. |
| Player Bench | PlayerBench | BattleManager | FixedArrayContainer | Fixed size: 3 slots. |
| Item Inventory | ItemInventory | BattleManager | FixedArrayContainer | Fixed size: 3 slots. |
| Enemy Lineup | EnemyLineup | BattleManager | FixedArrayContainer | Fixed size: 6 slots. |
2.3 MVP Data File Manifest
The following .tres files must be created in their respective res://resources/ subdirectories.
Units & Hero (res://resources/units/)
| Filename | id | tier | category | item_slot_count | base_hp | base_pwr | icon (Path) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Hero.tres | hero | 0 | "UNIT" | 5 | 10 | 2 | res://assets/sprites/units/Hero.png |
| EnemyHero.tres | enemy_hero | 0 | "UNIT" | 5 | 10 | 2 | res://assets/sprites/units/Hero.png |
| UnitTier1A.tres | unit_t1_a | 1 | "UNIT" | 1 | 1 | 2 | res://assets/sprites/units/UnitTier1A.png|
| UnitTier1B.tres | unit_t1_b | 1 | "UNIT" | 1 | 2 | 1 | res://assets/sprites/units/UnitTier1B.png|
| UnitTier2C.tres | unit_t2_c | 2 | "UNIT" | 2 | 3 | 3 | res://assets/sprites/units/UnitTier2C.png|
| UnitTier3D.tres | unit_t3_d | 3 | "UNIT" | 4 | 6 | 6 | res://assets/sprites/units/UnitTier3D.png|

**Items (res://resources/items/)**

| Filename | id | tier | category | bonus_hp | bonus_pwr | icon (Path) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| ItemTier1A.tres | item_t1_a | 1 | "ITEM" | 1 | 0 | res://assets/sprites/items/ItemTier1A.png|
| ItemTier1B.tres | item_t1_b | 1 | "ITEM" | 0 | 1 | res://assets/sprites/items/ItemTier1B.png|
| ItemTier2C.tres | item_t2_c | 2 | "ITEM" | 1 | 1 | res://assets/sprites/items/ItemTier2C.png|
| ItemTier3D.tres | item_t3_d | 3 | "ITEM" | 2 | 2 | res://assets/sprites/items/ItemTier3D.png|

**Recipes (res://resources/recipes/)**
*(No changes to this section)*

**Abilities (res://resources/abilities/)**

| Filename | id | name_key | description_key | effect (Resource) |
| :--- | :--- | :--- | :--- | :--- |
| BasicAttack.tres | basic_attack | "ability.basic_attack.name" | "ability.basic_attack.desc" | An instance of `BasicAttackEffect.gd`. |

*Note on Enemy Equipping: For the initial battle setup, the enemy lineup will be populated with one of each unit type, including an `EnemyHero`. All available item slots on these enemy units will be filled with a diverse set of appropriate items.*

## Part 3: Logic Layer & Managers
*   **Run/Scene Signals:** `start_run_requested, loadout_scene_requested, main_scene_requested, battle_start_requested`
*   **Window/Modal Signals:** `inspect_inventory_requested, display_discard_pile_requested, close_modal_requested`
*   **Action Signals:** `draw_gacha_requested(tier: int), inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier), choice_made(choice_id: String), inspection_requested(source_view: Control)`
*   **Selection Signals:** `view_selected(view: Control, location: LocationIdentifier), view_deselected(view: Control), invalid_action_triggered(view: Control), selection_changed(new_location: LocationIdentifier)`
*   **State Change Signals:** `run_state_changed, battle_inventory_changed, battle_state_changed(is_in_battle: bool), battle_phase_changed(phase_name: StringName), gacha_tokens_changed(new_amount: int), unit_stats_changed(unit_uuid: String), unit_inventory_changed(unit_uuid: String)`

### 3.2 Singleton Managers

*   **`GameManager.gd`**: Holds the master `run_state: RunState` resource for the current run and the global `is_in_battle: bool` flag. It is the central access point for all persistent run data.
*   **`InventoryManager.gd`**: A stateless logic controller. It listens for `inventory_action_requested` and uses `GameManager.is_in_battle` to determine the correct data owner. It then communicates with either `GameManager.run_state` (for permanent changes) or `BattleManager` (for temporary changes) to manipulate data in their respective `DataContainers`. After a successful Equip action, it emits `unit_inventory_changed`.
*   **`InteractionManager.gd`**: A state machine that holds the current `LocationIdentifier`. Manages drag-and-drop state and selection state.
*   **`MergeManager.gd`**: A stateless helper used by `InventoryManager` for merge calculations.
*   **`Database.gd`**: Loads all `.tres` resources on startup for fast access.
*   **`SceneManager.gd`**: Handles scene transitions.
*   **`AbilityResolver.gd`**: Manages ability queue and resolution. For the MVP, it will directly execute the `BasicAttackEffect`.
*   **`UUIDUtils.gd`**: Provides a `generate_uuid()` utility function.
*   **`WindowManager.gd`**: The sole authority for the lifecycle of all modal and inspection windows.
*   **`BattleManager.gd`**: The sole authority for the state of a single battle. It is created when a battle begins and destroyed when it ends.
    *   **State Properties**:
        *   `_battle_instances: Dictionary[String, GachaBallInstance]` (The master registry for temporary battle copies)
        *   `_data_containers: Dictionary[StringName, DataContainer]` (The registry for all temporary battle containers like lineups, benches, and battle inventories)
        *   `_gacha_tokens: int`
        *   `_current_battle_phase: StringName`
    *   **Responsibility**: Listens for `unit_inventory_changed`. On receiving the signal, it retrieves the relevant unit instance from its `_battle_instances` registry, calls its `recalculate_stats()` method (passing its own `_battle_instances` registry), and then emits `unit_stats_changed` for the UI.
    *   **Battle State Machine**: Operates as a state machine with the following phases: `START_OF_TURN`, `MANAGEMENT`, `COMBAT`, `END_OF_TURN`.
        *   `_enter_start_of_turn_phase()`: Grants the player 5 Gacha Tokens, emits `gacha_tokens_changed`.
        *   `_enter_management_phase()`: Enables player controls like the "End Turn" button.
        *   `_enter_combat_phase()`: Disables player controls and calls `_execute_combat_resolution()`.
        *   `_execute_combat_resolution()`: Iterates through all active units (player then enemy, back-to-front). For each unit, it identifies the frontmost opposing unit and instructs the `AbilityResolver` to execute a basic attack.
        *   `_enter_end_of_turn_phase()`: Checks for victory/defeat conditions. If none are met, transitions back to `START_OF_TURN`.
    *   **Updated `_setup_battle()`**: Now also responsible for creating battle copy instances for the enemy lineup, equipping them with items, and populating `_enemy_lineup_data`.
    *   **Updated `draw_gacha_requested(tier)`**: Now checks if `_gacha_tokens` are sufficient for the draw cost (`cost = tier`). If the `_draw_pools[tier]` is empty, it first automatically reshuffles all items of that tier from the `_discard_pile` back into the pool before drawing.



### 3.3 Inventory Action Logic
*(No changes to this section)*

## Part 4: Presentation Layer (UI)

### 4.1 UI Component Blueprints

*   **`GachaBallView.tscn`**:
    *   **Metadata Requirement**: Each instance must have a `LocationIdentifier` resource stored in its metadata. This is set by the parent container that populates it and is essential for all interactions.
*   **`SlotView.tscn`**:
    *   **Metadata Requirement**: Same as `GachaBallView.tscn`.

### 4.2 Window & UI Scene Blueprints

*   **`InventoryWindow.tscn`**: No changes.
*   **`DiscardPileWindow.tscn`**: No changes.
*   **`GachaBallInspectionWindow.tscn`**: No changes.
*   **`ItemInspectionWindow.tscn`**: No changes.
*   **`ChoiceWindow.tscn`**:
    *   Its root `PanelContainer` must handle `_gui_input` to detect background clicks and close the window.
    *   The `RichTextLabel` for the prompt must have `mouse_filter = MOUSE_FILTER_PASS`.
*   **`Battle.tscn` UI Elements**:
    *   An `%EndTurnButton` `Button` will be added.
    *   A `%GachaTokenLabel` `Label` will be added to display the player's current tokens.

<!-- START OF NEW UI/WINDOW LOGIC -->
4.3 The Definitive Guide to MVP Player Interactions
This section provides the exhaustive and authoritative rules for all player interactions within the MVP, replacing all previous interaction logic. It is built on the core principle of context-aware systems.
4.3.1 The Universal Laws of Interaction
These five laws are the foundational principles governing every player action. All game logic must adhere to them.
The Law of Action Intent: An action is initiated in one of two ways:
Drag and Drop: Dragging a selected GachaBallView and dropping it onto a valid target.
Select-then-Click: Having one GachaBallView selected, and then Single Clicking on a second valid target (GachaBallView or empty SlotView).
Both methods must trigger the exact same validation logic and resulting action.
The Law of Contextual Validity: Every action's possibility is dictated by context. The system must always validate an action based on:
Game State: Is the game in-battle or out-of-battle? (e.g., Equipping is battle-only, Permanent Merging is out-of-battle only).
Container Compatibility: Can the target container accept the source GachaBall? (e.g., PlayerBench accepts Units, not Items; ItemInventory accepts Items, not Units).
Tier Compatibility: Can the target container accept the source GachaBall's tier? (e.g., a Tier 1 GachaBall cannot be moved into a Tier 2 Run Inventory container).
An action that fails any validity check is an Invalid Action.
The Law of Action Completion: A successful action (Move, Swap, Equip, Merge) or the opening of an Inspection Window immediately clears the player's current selection. The InteractionManager's selection is set to null.
The Law of Emptiness: Empty SlotViews are non-interactive for selection. They serve only as potential drop/click targets for an action initiated from a filled GachaBallView.
The Law of Indirect Deployment: GachaBalls drawn from a Gacha Machine are placed in their respective holding areas (PlayerBench or ItemInventory). They cannot be moved directly from the Gacha Machine's content view to the player's lineup.
4.3.2 Detailed Interaction Scenarios
The outcome of every input is determined by the current game state and context.
Scenario A: In-Battle Interactions (GameManager.is_in_battle == true)
Single Click Logic:
On a GachaBallView in a Drag-and-Drop container*: Selects the GachaBall. If another was already selected, this click initiates an Action Intent.
On a GachaBallView in a Read-Only container**: Opens Inspection Window and clears any current selection.
On a selected GachaBallView: Deselects it.
On a UI Button: Executes the button's action and clears selection.
Double Click Logic:
On a GachaBallView in a Drag-and-Drop container*: The first click selects it. A rapid second click Opens the Inspection Window and clears the selection.
On a GachaBallView in a Read-Only container**: The first click opens the inspection window. The second click, now landing on the window's blocker, will close the window, creating a "flicker" effect.
This scenario is governed by the context of the containers involved.

**Table A.1: Battle Board Interactions**
*These rules apply when the source and/or target are on the `PlayerLineup`, `PlayerBench`, or `ItemInventory`.*

| Source GachaBall | Target | Conditions for Validity | Resulting Action |
| :--- | :--- | :--- | :--- |
| Unit (from Bench/Lineup) | Unit (on Bench/Lineup) | Merge recipe exists. | Show ChoiceWindow ("Merge" or "Swap"). |
| Unit (from Bench/Lineup) | Unit (on Bench/Lineup) | No merge recipe. | Swap positions. |
| Unit (from Bench) | Empty SlotView (in Lineup) | Slot is empty. | Move Unit to Lineup. |
| Unit (from Lineup) | Empty SlotView (in Bench) | Slot is empty. | Move Unit to Bench. |
| **Item (from Item Inventory)** | **Unit (on Bench/Lineup)** | **Unit has an empty item slot.** | **Equip Item onto Unit.** |
| Unit/Item (from Battle Inventory Grid) | Empty SlotView (on Bench/Item Inventory) | Slot is empty and compatible. | Move to Battle Board. |

**Table A.2: Battle Inventory Grid Interactions**
*These rules apply when both the source and target are within the `BattleInventoryT*` grids. This logic is identical to the out-of-battle Run Inventory.*

| Source GachaBall | Target | Conditions for Validity | Resulting Action |
| :--- | :--- | :--- | :--- |
| GachaBallView | GachaBallView | Merge recipe exists. | Show ChoiceWindow ("Merge" or "Swap"). |
| GachaBallView | GachaBallView | No merge recipe. Target is in the same container. | Swap positions. |
| GachaBallView | Empty SlotView | Target slot is in the same container. | Move to empty slot. |
| Any other combination | Any other target | Fails Contextual Validity checks. | Invalid Action. |
Scenario B: Out-of-Battle Interactions (GameManager.is_in_battle == false)
Action Intent Table (Drag-and-Drop or Select-then-Click):
| Source GachaBall | Target | Conditions for Validity | Resulting Action |
| :--- | :--- | :--- | :--- |
| GachaBallView | GachaBallView | Merge recipe exists. | Show ChoiceWindow ("Merge" or "Swap"). |
| GachaBallView | GachaBallView | No merge recipe. Target is in the same container. | Swap positions. |
| GachaBallView | Empty SlotView | Target slot is in the same container. | Move to empty slot. |
| Any other combination | Any other target | Fails Contextual Validity checks. | Invalid Action: Source GachaBall's selection is cleared, and it remains in its original position. |
*Drag-and-Drop Containers: PlayerLineup, PlayerBench, ItemInventory, RunInventoryWindow.
**Read-Only Containers: EnemyLineup, DiscardPileWindow, GachaMachineWindow content view.
4.4 Definitive Window Management & UI Patterns
This section defines the strict rules for how windows are opened, closed, and layered.
Window Types & Groups:
Modal Windows: The root of an interaction tree (e.g., RunInventoryWindow). They take focus and are accompanied by a BackgroundBlocker.
Inspection Windows: Child windows that display detailed information (GachaBallInspectionWindow). They can stack on top of Modals and other Inspection Windows.
Inspection Groups (Branches): An action that opens the first Inspection Window in a chain creates a new Inspection Group. Opening a new root inspection closes all other existing Inspection Groups.
Hierarchical Closure (Pruning):
Clicking on the empty background of a window closes all windows stacked on top of it within its group, but leaves the clicked window open.
Example: RunInventory (Modal) -> Unit_Inspect (Inspect) -> Item_Inspect (Inspect).
A click on Unit_Inspect's background closes Item_Inspect.
A click on RunInventory's background closes both Unit_Inspect and Item_Inspect.
Click-Through on Closure (CRITICAL UX RULE):
The click that closes a window is not consumed. After the window is closed, that same click's screen position is immediately re-evaluated against the now-exposed UI elements.
Behavior: A single click on the BackgroundBlocker will close the Modal window, and if a GachaBallView was underneath that click position, that GachaBall will be instantly selected or inspected as per the rules above. This creates a seamless, responsive feel where no click is "wasted". The WindowManager is responsible for this two-step process: close window, then re-process input.
The "Dynamic Mouse Filter" Pattern for Clickable Links: This pattern is required for any RichTextLabel that must contain clickable links while allowing its background to be non-interactive.
The RichTextLabel must have bbcode_enabled = true.
By default, its mouse_filter property must be set to MOUSE_FILTER_PASS.
The meta_hover_started signal must be connected to a handler that sets mouse_filter = MOUSE_FILTER_STOP.
The meta_hover_ended signal must be connected to a handler that resets mouse_filter = MOUSE_FILTER_PASS.
This ensures only the links themselves are interactive, while clicks on the label's empty space "pass through" to the panel behind it.
Hierarchical Input Consumption: The UI will rely on Godot's input propagation system. A _gui_input handler that processes an event must call get_viewport().set_input_as_handled() to consume the event and prevent it from propagating to controls lower in the visual hierarchy.

## Part 5: Game Flows

### 5.1 Battle Setup Flow (`BattleManager._setup_battle`)
1. BattleManager is instantiated.
2. It accesses `GameManager.run_state` to get the player's permanent collection.
3. It iterates through the UUIDs in the `run_inventory_containers` of the RunState.
4. For each permanent instance, it creates a `battle_copy()`, adds the copy to its own `_battle_instances` registry, and places the new UUID into the appropriate temporary BattleInventory DataContainer.
5. It creates a battle copy of the `hero_instance`, adds it to `_battle_instances`, and places its UUID into the PlayerLineup container.
6. It sets up the enemy lineup, creating new instances, adding them to `_battle_instances`, and placing their UUIDs into the EnemyLineup container.
7. Emits `battle_inventory_changed` to trigger the initial board draw.

### 5.2 Gacha Draw Flow (`BattleManager.gd`)
*   Receives `draw_gacha_requested(tier)`.
*   **NEW**: Checks for sufficient `_gacha_tokens` (`cost = tier`).
*   **NEW**: If the `_draw_pools[tier]` is empty, automatically reshuffles from the discard pile for that tier.
*   Picks a random instance from `_draw_pools[tier]`, removes it, and places it on the bench/item inventory or in the discard pile if full.
*   Emits `battle_inventory_changed`.

### 5.3 Reshuffle Flow
*   The manual `_on_reshuffle_requested` flow is **REMOVED**. Reshuffling is now an automatic process triggered by an attempt to draw from an empty pool.

### 5.4 Battle Turn Flow (New Section)
This describes the flow for a single turn, managed by the `BattleManager`'s state machine.
1.  **Transition to `START_OF_TURN`**:
    *   `BattleManager` grants the player 5 `_gacha_tokens`.
    *   `gacha_tokens_changed` signal is emitted.
2.  **Transition to `MANAGEMENT`**:
    *   The `%EndTurnButton` is enabled.
    *   Player can spend tokens, deploy units, equip items, and arrange their lineup.
3.  **Player Action: End Turn**:
    *   Player clicks the `%EndTurnButton`. The button is disabled.
4.  **Transition to `COMBAT`**:
    *   `BattleManager` calls `_execute_combat_resolution`.
    *   Combat resolves automatically: units act in order (player then enemy, back-to-front).
    *   Each unit performs a basic attack on the frontmost enemy.
    *   HP is updated on views. Defeated player units' data is moved to the discard pile; defeated enemy units' data is removed from play.
    *   The `battle_inventory_changed` signal is emitted after any unit is defeated.
5.  **Transition to `END_OF_TURN`**:
    *   `BattleManager` checks for victory (all enemies defeated) or defeat (player hero HP <= 0).
    *   If the battle is not over, loop back to Step 1 for the next turn.

### 5.5 Equip & Stat Recalculation Flow (Reactive)
This flow describes how equipping an item correctly triggers a reactive stat update.

1.  **Intent**: Player initiates an Equip action during a battle.
2.  **UI Layer**: Emits `inventory_action_requested` with the `LocationIdentifier` for the source item and target unit.
3.  **`InventoryManager`**:
    *   Receives the signal. Confirms `GameManager.is_in_battle` is true.
    *   Uses `BattleManager`'s API to get the unit and item instances from the `_battle_instances` registry.
    *   Adds the item's UUID to the unit instance's `equipped_item_uuids` array.
    *   Updates the source `DataContainer`, setting the item's original location to `null`.
    *   Emits `EventBus.unit_inventory_changed(target_unit.ball_uuid)`.
4.  **`BattleManager`**:
    *   Receives `unit_inventory_changed`.
    *   Calls `get_instance(unit_uuid).recalculate_stats(get_all_instances())`.
    *   Emits `EventBus.unit_stats_changed(unit_uuid)`.
5.  **UI Layer**: The `GachaBallView` for the unit receives `unit_stats_changed` and updates its HP/PWR labels.

### 5.6 Permanent Merge Flow (Out of Battle)
This flow describes how merging instances outside of battle correctly modifies the persistent `RunState`.

1.  **Context**: Player is in a non-battle scene (e.g., Shop). `GameManager.is_in_battle` is `false`.
2.  **Intent**: Player merges two instances from their Run Inventory.
3.  **UI Layer**: Emits `inventory_action_requested` with `LocationIdentifier`s for both instances.
4.  **`InventoryManager`**:
    *   Receives the signal. Confirms `is_in_battle` is `false`.
    *   Communicates with `GameManager.run_state` to perform data operations.
    *   Calls `MergeManager.calculate_merge_result` to get the `merged_instance`.
    *   Reads the `tier` from the `merged_instance`'s definition.
    *   Dynamically determines the target container name (e.g., `StringName("RunInventoryT%d" % result_tier)`).
    *   Removes the ingredient UUIDs from their source `DataContainer`s in `RunState`.
    *   Adds the new instance to `RunState.run_instances` and its UUID to the correct target `DataContainer` in `RunState`.
    *   Emits `run_state_changed`.
5.  **UI Layer**: The Run Inventory window (or relevant UI) listens for `run_state_changed` and redraws itself.

## Part 6: Architectural Notes & Implementation Guidelines

### 6.1 Guideline: Prefer `load()` over `preload()` for Dynamic UI Instantiation

This guideline improves performance and memory management. Use `load()` for large, infrequently used scenes like modal windows (InventoryWindow, DiscardPileWindow). This prevents them from being loaded into memory at game startup. Use `preload()` for small, frequently instantiated scenes like `GachaBallView` or `SlotView` to ensure they are available instantly without a loading stutter.

### 6.2 Localization System (New Section)
*   **Key-Based System**: All user-facing text must be stored as keys in resource files (e.g., `display_name_key` in `GachaBallDefinition`).
*   **Central File**: A central `localization.csv` file will be used to store the key-value pairs for each supported language.
*   **Implementation**: Text will be set in UI scripts using the `tr()` function (e.g., `my_label.text = tr("my.localization.key")`).
*   **Dynamic Text**: For text that includes variable data (like damage numbers), use formatted strings. The key in the CSV will look like `"ability.basic_attack.desc"`, and the value will be `"Attacks the frontmost enemy for {pwr} damage."`. The code will be `description_label.text = tr("ability.basic_attack.desc").format({"pwr": unit.current_pwr})`

### 6.3 Guideline: The Core Data Contracts

These are the inviolable rules of the Contextual Data Ownership architecture. All new features and logic must adhere to them.

1.  **Contextual Data Ownership is Law**: All game logic must respect the strict separation of data owners. For permanent data that persists across a run, `GameManager.run_state` is the sole authority. For temporary data that exists only within a single battle, `BattleManager` is the sole authority. The `InventoryManager` must always check the context (`GameManager.is_in_battle`) before routing an action to the correct owner.

2.  **`LocationIdentifier` is the Universal Contract**: All spatial and inventory-based actions **must** be communicated using a `LocationIdentifier` resource. This is the universal, type-safe language for referring to any slot in any container. Logic layers should never need a direct reference to a UI `Control` node.

3.  **Containers Manage Their Own Data**: All access to inventory or lineup data **must** go through the `get_container(name)` API on the appropriate data owner (`RunState` or `BattleManager`). Logic layers cannot and should not know about the underlying array structures; they may only interact with the public `DataContainer` interface (`get_uuid`, `set_uuid`, etc.).

4.  **Instances are Data, Views are Reflections**: A `GachaBallInstance` is a data-only resource. A `GachaBallView` is a scene that reflects the state of an instance. The view reads data; it does not store it. The `LocationIdentifier` in a view's metadata is its only link to the data world.

5.  **Managers are Stateless Gatekeepers**: With the exception of `BattleManager` (which is a state machine for battle flow), all singleton managers (`InventoryManager`, `MergeManager`, `WindowManager`) must be stateless. They act as controllers or gatekeepers that process intent signals and call the appropriate methods on the true data owners.

6.  **UI Emits Intent, Managers Act**: The UI's only job is to present state and emit intent signals. A button click emits `action_requested`. It does not know what will happen next. The responsible manager listens for this signal and executes the logic. The UI then updates itself automatically in response to the resulting `state_changed` signal. The UI is reactive, not proactive.