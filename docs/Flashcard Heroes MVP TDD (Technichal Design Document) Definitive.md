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
This table defines the size, structure, and behavior of every data container in the game.
Container Name	Data Path	Structure	Initial Size	Growth Logic
Run Inventory (per Tier)	RunState.run_inventory[tier] | Data Grid (Array) | 4x4 (16 slots) | Fixed size (with plan to add growth logic later). *Implementation: A 1D Array where null represents an empty slot.*
Battle Inventory (per Tier) | BattleManager._battle_inventory[tier] | Data Grid (Array) | 4x4 (16 slots) | Grows vertically by 4 slots when full. *Implementation: A 1D Array where null represents an empty slot.*
Discard Pile	BattleManager.discard_pile | Data Grid (Array) | 4x4 (16 slots) | Grows vertically by 4 slots when full | Stores units and items of all tiers discarded (by death or other means) during the battle. *Implementation: A 1D Array where null represents an empty slot.*
Player Lineup	BattleManager.lineup_data	Fixed-Size Array	6 slots	None. Fixed size.
Player Bench	BattleManager.bench_data	Fixed-Size Array	3 slots	None. Fixed size.
Item Inventory	BattleManager.item_data	Fixed-Size Array	3 slots	None. Fixed size.
Enemy Lineup | BattleManager._enemy_lineup_data | Fixed-Size Array | 6 slots | None. Fixed size.
Enemy Lineup	BattleManager._enemy_lineup_data	Fixed-Size Array	6 slots	None. Fixed size.
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
*   **Action Signals:** `draw_gacha_requested(tier: int), inventory_action_requested(source_view: Control, target_view: Control), choice_made(choice_id: String), inspection_requested(source_view: Control)`
*   **Selection Signals:** `view_selected(view: Control), view_deselected(view: Control), invalid_action_triggered(view: Control), selection_context_changed(view: Control)`
*   **State Change Signals:** `run_inventory_changed, battle_inventory_changed, battle_state_changed(is_in_battle: bool), battle_phase_changed(phase_name: StringName), gacha_tokens_changed(new_amount: int), unit_stats_changed(unit_uuid: String)`

### 3.2 Singleton Managers

*   **`GameManager.gd`**: Holds the `RunState` resource and the global `is_in_battle: bool` flag.
*   **`InventoryManager.gd`**: Sole listener for `inventory_action_requested`. It uses the Action Decision Tree and Compatibility Rules Table below to process all inventory logic. When handling an Equip action, it must call the unit's `recalculate_stats()` method and emit `unit_stats_changed`.
*   **`InteractionManager.gd`**: A state machine that holds the `_selected_view`. Manages drag-and-drop state.
*   **`MergeManager.gd`**: A stateless helper used by `InventoryManager` for merge calculations.
*   **`Database.gd`**: Loads all `.tres` resources on startup for fast access.
*   **`SceneManager.gd`**: Handles scene transitions.
*   **`AbilityResolver.gd`**: Manages ability queue and resolution. For the MVP, it will directly execute the `BasicAttackEffect`.
*   **`UUIDUtils.gd`**: Provides a `generate_uuid()` utility function.
*   **`WindowManager.gd`**: The sole authority for the lifecycle of all modal and inspection windows.
*   **`BattleManager.gd`**: Manages the entire state of a battle.
    *   **New State Properties**:
        *   `_enemy_lineup_data: Array[GachaBallInstance]` (6 slots, null-filled)
        *   `_gacha_tokens: int`
        *   `_current_battle_phase: StringName`
    *   **Battle State Machine**: Operates as a state machine with the following phases: `START_OF_TURN`, `MANAGEMENT`, `COMBAT`, `END_OF_TURN`.
        *   `_enter_start_of_turn_phase()`: Grants the player 5 Gacha Tokens, emits `gacha_tokens_changed`.
        *   `_enter_management_phase()`: Enables player controls like the "End Turn" button.
        *   `_enter_combat_phase()`: Disables player controls and calls `_execute_combat_resolution()`.
        *   `_execute_combat_resolution()`: Iterates through all active units (player then enemy, back-to-front). For each unit, it identifies the frontmost opposing unit and instructs the `AbilityResolver` to execute a basic attack.
        *   `_enter_end_of_turn_phase()`: Checks for victory/defeat conditions. If none are met, transitions back to `START_OF_TURN`.
    *   **Updated `_setup_battle()`**: Now also responsible for creating battle copy instances for the enemy lineup, equipping them with items, and populating `_enemy_lineup_data`.
    *   **Updated `draw_gacha_requested(tier)`**: Now checks if `_gacha_tokens` are sufficient for the draw cost (`cost = tier`). If the `_draw_pools[tier]` is empty, it first automatically reshuffles all items of that tier from the `_discard_pile` back into the pool before drawing.

### 3.2.1 Unified Interaction & Window Management Model

**WindowManager.gd** is the sole authority for the lifecycle of all modal and inspection windows. No other script creates, destroys, or positions these UI elements directly. This centralized control prevents race conditions and ensures a predictable UI state.

*   **Centralized Window Management**: All modals and inspection windows are children of the main `CanvasLayer` in `Main.tscn`. `WindowManager.gd` manages their `z_index` to ensure the correct window is always on top.
*   **Dynamic Instantiation**: Windows are loaded and instantiated dynamically using `load()` (not `preload()`) to avoid unnecessary memory consumption and engine loading errors.
*   **Modal Stack**: `WindowManager.gd` maintains a stack of active modal windows. When a new modal is opened, it's pushed onto the stack. Closing a modal pops it from the stack.
*   **Background Interaction**: A `BackgroundBlocker.tscn` (a full-screen `ColorRect` that consumes input) is instantiated and added under the `CanvasLayer` whenever a modal is active. This blocker prevents interaction with UI elements behind the modal. Clicking the blocker closes the top-most modal.

### 3.3 Inventory Action Logic
*(No changes to this section)*

## Part 4: Presentation Layer (UI)

### 4.1 UI Component Blueprints

*   **`GachaBallView.tscn`**:
    *   **Scene Tree**: The `VBoxContainer` will be updated to include `%HPLabel` and `%PWRLabel` `Label` nodes to display unit stats.
    *   **Script (`GachaBallView.gd`)**: Will be updated to listen for the `unit_stats_changed` signal to keep its HP/PWR labels synchronized with the instance data.

*   **`SlotView.tscn`**: No changes.

### 4.2 Window & UI Scene Blueprints

*   **`UnitInspectionWindow.tscn`**: The `DescriptionLabel` will be a `RichTextLabel` to support formatted strings for ability descriptions (e.g., `tr(key).format({"pwr": value})`).
*   **`ItemInspectionWindow.tscn`**: No changes.
*   **`ChoiceWindow.tscn`**: No changes.
*   **`Battle.tscn` UI Elements**:
    *   An `%EndTurnButton` `Button` will be added.
    *   A `%GachaTokenLabel` `Label` will be added to display the player's current tokens.
    *   An `%EnemyLineupContainer` `HBoxContainer` will be added to the scene to hold the enemy's `GachaBallView`s.
    *   The `%ReshuffleButton` will be **removed**, as its functionality is now automatic.

### 4.3 & 4.4 Window Interaction Rules & UI Patterns
*(No changes to these sections)*

## Part 5: Game Flows

### 5.1 Battle Setup Flow (`BattleManager._setup_battle`)
*   Retrieves hero_instance, creates a battle copy, and places it in `lineup_data[0]`.
*   **NEW**: Creates battle copies for a predefined enemy lineup (1 of each unit type + enemy hero), equips them with items, and places them in `_enemy_lineup_data`.
*   Iterates through `run_inventory`, creates battle copies, and adds them to `_battle_inventory` and `_draw_pools`.
*   Emits `battle_inventory_changed` to trigger the initial board draw.

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

## Part 6: Architectural Notes & Implementation Guidelines

### 6.1 Guideline: Prefer `load()` over `preload()` for Dynamic UI Instantiation
*(No changes to this section)*

### 6.2 Localization System (New Section)
*   **Key-Based System**: All user-facing text must be stored as keys in resource files (e.g., `display_name_key` in `GachaBallDefinition`).
*   **Central File**: A central `localization.csv` file will be used to store the key-value pairs for each supported language.
*   **Implementation**: Text will be set in UI scripts using the `tr()` function (e.g., `my_label.text = tr("my.localization.key")`).
*   **Dynamic Text**: For text that includes variable data (like damage numbers), use formatted strings. The key in the CSV will look like `"ability.basic_attack.desc"`, and the value will be `"Attacks the frontmost enemy for {pwr} damage."`. The code will be `description_label.text = tr("ability.basic_attack.desc").format({"pwr": unit.current_pwr})`

Scripting Note: Its root PanelContainer must have its `mouse_filter` property set to `STOP` to enable parent-click pruning.
**ChoiceWindow.tscn:**
Purpose: Prompts user for Merge/Swap choice.
Scene Tree: PanelContainer -> VBoxContainer -> Label ("What would you like to do?"), HBoxContainer -> %MergeButton (Button), %SwapButton (Button).
Battle.tscn UI Elements:
* An %EndTurnButton Button will be added.
* A %GachaTokenLabel Label will be added to display the player's current tokens.
* An %EnemyLineupContainer HBoxContainer will be added to the scene to hold the enemy's GachaBallViews.
* The %ReshuffleButton will be **removed**, as its functionality is now automatic.

### 4.3 Window Interaction Rules

*   **Modal Exclusivity**: Only one modal window can be open at a time. Opening a new modal automatically closes any currently open modal.
*   **Inspection Window Stacking**: Multiple inspection windows can be open simultaneously. They stack on top of each other, with the most recently opened window having the highest `z_index`.
*   **Background Blocker**: A `BackgroundBlocker.tscn` (a full-screen `ColorRect` that consumes input) is instantiated and added under the `CanvasLayer` whenever a modal is active. This blocker prevents interaction with UI elements behind the modal. Clicking the blocker closes the top-most modal.
*   **Inspection Window Closure**: Inspection windows can be closed individually by clicking their close button, or all inspection windows can be closed at once by clicking the `BackgroundBlocker` (if a modal is not active) or by a `close_all_inspection_windows()` call from `WindowManager.gd`.
*   **Dynamic Instantiation**: All windows are loaded and instantiated dynamically using `load()` (not `preload()`) to avoid unnecessary memory consumption and engine loading errors.

### 4.4 Definitive UI Interaction Patterns

To ensure a fluid and intuitive user experience, all modal windows that occupy a portion of the screen must adhere to the following architectural rules:

1.  **Composition:** A modal consists of two primary nodes: a `BackgroundBlocker` scene instance that covers the full screen, and a primary `PanelContainer` (or similar `Control` node) that contains the modal's actual content and sits visually on top of the blocker.
2.  **Background Closing:** A click on the `BackgroundBlocker` must close the modal. This is the blocker's primary function.
3.  **"Pass-Through" Panel Behavior (Designer Mandate):** The modal's primary content `PanelContainer` must have its `mouse_filter` property set to `PASS`. This is a critical rule to ensure that clicks on the panel's empty background area (i.e., not on an interactive child like a button or item grid) are not stopped by the panel. Instead, they "pass through" to the `BackgroundBlocker` behind it, which then correctly interprets the click as an intent to close the modal.

#### 4.4 Definitive UI Interaction Patterns

1.  **Requirement for `RichTextLabel`**: Any `Label` that needs to contain clickable links (e.g., for "EFFECTS") **must** be a `RichTextLabel` with its `bbcode_enabled` property set to `true`.

2.  **The "Clickable Background" Dynamic Mouse Filter Pattern**: For any control that needs to differentiate between clicks on a clickable link and clicks on its own background, the following pattern is mandatory to avoid input conflicts:
    *   The root `PanelContainer` of the window handles `_gui_input` to catch clicks on its empty borders/padding. This serves as the final backstop for closing the window.
    *   Purely decorative, non-interactive labels inside the window (e.g., `NameLabel`, `ItemGridLabel`) **must** have their `mouse_filter` set to `PASS` (`2` in the `.tscn` file) so they do not block clicks.
    *   The interactive `RichTextLabel` must have its `mouse_filter` set to `PASS` by default in its `_ready()` function. This allows clicks on its empty areas to pass through to the parent `PanelContainer`.
    *   The `RichTextLabel` connects its `meta_hover_started` and `meta_hover_ended` signals to handlers in its script.
    *   The `_on_meta_hover_started` handler sets the label's `mouse_filter` to `STOP`. This makes the link underneath the mouse cursor interactive.
    *   The `_on_meta_hover_ended` handler resets the label's `mouse_filter` back to `PASS`. This makes the background of the label transparent to clicks again once the mouse moves away from the link.
    *   This dynamic switching ensures that only the meta links themselves capture mouse events, while the rest of the label's area correctly allows clicks to pass through.

3.  **Window Background Interaction**: All primary windows (`InventoryWindow`, `DiscardPileWindow`) must implement `gui_input` handling on their main content panel. A click on this panel's empty background must trigger `WindowManager.close_all_inspection_windows()` without closing the window itself.


## Part 5: Game Flows

### 5.1 Battle Setup Flow (`BattleManager._setup_battle`)
*   Retrieves hero_instance, creates a battle copy, and places it in `lineup_data[0]`.
*   **NEW**: Creates battle copies for a predefined enemy lineup (1 of each unit type + enemy hero), equips them with items, and places them in `_enemy_lineup_data`.
*   Iterates through `run_inventory`, creates battle copies, and adds them to `_battle_inventory` and `_draw_pools`.
*   Emits `battle_inventory_changed` to trigger the initial board draw.

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

## Part 6: Architectural Notes & Implementation Guidelines

### 6.1 Guideline: Prefer `load()` over `preload()` for Dynamic UI Instantiation
*(No changes to this section)*

### 6.2 Localization System (New Section)
*   **Key-Based System**: All user-facing text must be stored as keys in resource files (e.g., `display_name_key` in `GachaBallDefinition`).
*   **Central File**: A central `localization.csv` file will be used to store the key-value pairs for each supported language.
*   **Implementation**: Text will be set in UI scripts using the `tr()` function (e.g., `my_label.text = tr("my.localization.key")`).
*   **Dynamic Text**: For text that includes variable data (like damage numbers), use formatted strings. The key in the CSV will look like `"ability.basic_attack.desc"`, and the value will be `"Attacks the frontmost enemy for {pwr} damage."` The code will be `description_label.text = tr("ability.basic_attack.desc").format({"pwr": unit.current_pwr})`