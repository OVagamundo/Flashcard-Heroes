Flashcard Heroes Core Mechanics MVP TDD v13.0
1. Introduction & MVP Goal
1.1. Purpose
This document provides the complete technical blueprint for the "Core Mechanics MVP" of Flashcard Heroes. It is a self-contained specification designed to be followed precisely by a development agent. All required data, scene structures, script logic, and interaction flows are explicitly defined herein to eliminate ambiguity and assumptions. This document is the sole source of truth for the MVP's architecture.
1.2. Core Architectural Principles
This project is built on four key ideas to keep the code clean, decoupled, and easy to manage:
Separation of Data and View:
Data (GachaBallInstance): A Resource file holding all information about a unique GachaBall (ID, UUID, equipped items). It has no visual component.

Event-Driven Communication (EventBus):
Systems communicate indirectly by emitting signals through the global EventBus. For example, a button emits start_run_requested, and the GameManager listens for it. This keeps all systems decoupled and unaware of each other's implementation.
Contextual Data Persistence:
The game operates in two distinct data contexts. The interaction logic (how you merge/swap) is universal, but its effect depends on the context.
Run Context (Permanent): Active outside of battle. All changes made to the run_inventory are managed by GameManager and are saved for the duration of the run.
Battle Context (Temporary): Active during a battle. All changes (merges, draws, discards) are managed by BattleManager and affect a temporary copy of the inventory that lasts only for the current battle.
The Hero is a Special Singleton Entity:
The player's Hero is a unique, non-gacha unit. It is not part of the standard tiered inventory pools.
It is stored in a dedicated hero_instance property within the RunState resource. This simplifies all inventory logic (drawing, merging, etc.), as these systems do not need special case handling for the Hero.
1.3. Terminology Clarification
Slot: A conceptual, numbered position within an inventory's data array (e.g., PlayerBench[0]). This is a data-level concept.
Zone: A specific area of the UI with its own interaction rules (e.g., PlayerLineup, PlayerBench, ItemInventory, InventoryModal).
GachaBallView: The player-facing UI element. The player clicks on and drags GachaBallViews. When not displaying data, it's invisible, allowing its parent placeholder to be seen.
*   **Workspace Window:** A large, modal-like window that provides a dedicated user workspace, such as the `InventoryModal` or `DiscardPileModal`. These windows typically have fixed, predefined positions on the screen.
*   **Inspection Window:** A smaller, context-sensitive window that provides detailed information about a specific game element, like a tooltip. Examples include the `UnitInspectionWindow` and `ItemInspectionWindow`. Their position is calculated dynamically to avoid overlapping the element that spawned them or their parent window.

1.4. Directory Structure
Generated code
res://
├── assets/
│   ├── sprites/
│   │   ├── units/
│   │   └── items/
├── resources/
│   ├── units/
│   ├── items/
│   ├── recipes/
│   └── decks/
├── scenes/
└── scripts/
Use code with caution.
1.5. MVP User Journey
A player can:
Start a run, creating a persistent RunState.
Open an InventoryModal to manage their collection. The modal's content and the permanence of actions depend on the game's context (Run vs. Battle).
Start a battle, creating a temporary copy of the inventory.
Draw GachaBalls from the temporary battle inventory.
Use a universal Drag-and-Drop or Click-and-Click system to move, swap, equip, and merge GachaBalls.
Be prompted to "Merge" or "Swap" when a valid merge is possible.
Inspect units by clicking a selected unit a second time.
View the discard pile and reshuffle it back into the battle's draw pools.
2. Data Schemas & Definitions
2.1. GachaBallDefinition.gd
Inherits: Resource, class_name GachaBallDefinition
Purpose: The static template for a type of GachaBall.
Properties: @export var id: StringName, @export var display_name_key: String, @export var description_key: String, @export var icon: Texture2D, @export var tier: int, @export var category: StringName, @export var item_slot_count: int = 0
2.2. GachaBallInstance.gd
Inherits: Resource, class_name GachaBallInstance
Purpose: A unique, individual instance of a GachaBall.
Properties: definition_id: StringName, ball_uuid: String, origin_uuid: String, equipped_item_uuids: Array[String], location_state: int
Enum LocationState:
Generated gdscript
enum LocationState {
    UNDEFINED = -1,
    RUN_INVENTORY = 0,
    IN_BATTLE_INVENTORY = 1, # In the master list for the battle, but not on board.
    IN_PLAYER_LINEUP = 2,
    IN_PLAYER_BENCH = 3,
    IN_ITEM_INVENTORY = 4,   # The battle item bar.
    IN_BATTLE_DISCARD_PILE = 5,
    MERGE_PREVIEW = 6,
    INSPECT_VIEW = 7
}
Use code with caution.
Gdscript
Methods:
initialize(def: GachaBallDefinition): Sets definition_id, generates a unique ball_uuid, resizes equipped_item_uuids, and sets location_state.
create_battle_copy() -> GachaBallInstance: Creates a new, temporary instance for battle. It's crucial that this is implemented by manually creating a new GachaBallInstance resource (.new()) and copying properties, NOT by using the .duplicate() method, which can be unreliable for non-exported script variables. This new copy receives a unique ball_uuid, and its origin_uuid is set to the ball_uuid of the permanent instance it was copied from.
2.3. MergeRecipe.gd
Inherits: Resource, class_name MergeRecipe
Purpose: Defines a valid merge combination.
Properties: @export var ingredient_a_id: StringName, @export var ingredient_b_id: StringName, @export var result_id: StringName, @export var is_self_merge: bool = false, @export var merge_type: StringName
2.4. FlashcardDeckDefinition.gd
Inherits: Resource, class_name FlashcardDeckDefinition
Properties: @export var id: StringName, @export var display_name_key: String, @export var card_list: Array[Dictionary]
2.5. MVP Data File Creation & Asset Convention
(This section remains unchanged, as the data files are correct.)
Table 2.5.1: GachaBallDefinition for Units & Hero
| Filename | id (StringName) | display_name_key (String) | tier (int) | category (StringName) | item_slot_count (int) | icon (Path) |
| :---------------- | :---------------- | :-------------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| Hero.tres | hero | "hero.name" | 0 | "UNIT" | 5 | res://assets/sprites/units/Hero.png |
| UnitTier1A.tres | unit_t1_a | "unit_t1_a.name" | 1 | "UNIT" | 1 | res://assets/sprites/units/UnitTier1A.png|
| UnitTier1B.tres | unit_t1_b | "unit_t1_b.name" | 1 | "UNIT" | 1 | res://assets/sprites/units/UnitTier1B.png|
| UnitTier2C.tres | unit_t2_c | "unit_t2_c.name" | 2 | "UNIT" | 2 | res://assets/sprites/units/UnitTier2C.png|
| UnitTier3D.tres | unit_t3_d | "unit_t3_d.name" | 3 | "UNIT" | 4 | res://assets/sprites/units/UnitTier3D.png|
Table 2.5.2: GachaBallDefinition for Items
| Filename | id (StringName) | display_name_key (String) | tier (int) | category (StringName) | item_slot_count (int) | icon (Path) |
| :---------------- | :---------------- | :-------------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| ItemTier1A.tres | item_t1_a | "item_t1_a.name" | 1 | "ITEM" | 0 | res://assets/sprites/items/ItemTier1A.png|
| ItemTier1B.tres | item_t1_b | "item_t1_b.name" | 1 | "ITEM" | 0 | res://assets/sprites/items/ItemTier1B.png|
| ItemTier2C.tres | item_t2_c | "item_t2_c.name" | 2 | "ITEM" | 0 | res://assets/sprites/items/ItemTier2C.png|
| ItemTier3D.tres | item_t3_d | "item_t3_d.name" | 3 | "ITEM" | 0 | res://assets/sprites/items/ItemTier3D.png|
Table 2.5.3: MergeRecipe Data
| Filename | ingredient_a_id | ingredient_b_id | result_id | is_self_merge | merge_type |
| :------------------------- | :---------------- | :---------------- | :---------- | :-------------- | :----------- |
| Merge_Unit_A_B_to_C.tres | unit_t1_a | unit_t1_b | unit_t2_c | false | "UNIT" |
| Merge_Unit_C_C_to_D.tres | unit_t2_c | unit_t2_c | unit_t3_d | true | "UNIT" |
| Merge_Item_A_B_to_C.tres | item_t1_a | item_t1_b | item_t2_c | false | "ITEM" |
| Merge_Item_C_C_to_D.tres | item_t2_c | item_t2_c | item_t3_d | true | "ITEM" |
2.6. RunState.gd
Inherits: Resource, class_name RunState
Purpose: Holds the entire persistent state for a player's run.
Properties:
@export var gold: int
@export var current_stage: int
@export var current_battle: int
@export var run_inventory: Dictionary # Tiered gacha inventory: {1:[], 2:[], 3:[]}
@export var hero_instance: GachaBallInstance # The player's dedicated Hero instance.
Methods:
start_new_run(): Initializes properties. It populates the run_inventory with the starting set of gacha-able units and items. Crucially, it also creates the unique hero_instance and assigns it to its dedicated property.
2.7. ConditionDefinition.gd
Inherits: Resource, class_name ConditionDefinition
Purpose: Defines conditions for ability effects. For MVP, its evaluate() method is a placeholder that always returns true.
3. Autoloaded Scripts (Singletons)
3.1. EventBus.gd
Purpose: A global script containing only signal definitions.
Signals:
start_run_requested
loadout_scene_requested
main_scene_requested
battle_start_requested
inspect_inventory_requested
close_modal_requested
display_discard_pile_requested
draw_gacha_requested(tier: int)
inventory_action_requested(source_view: Control, target_view: Control)
choice_made(choice_id: String): Emitted when a player makes a choice in a `ChoiceModal`.
* `inspection_requested(source_view: Control)`
game_over(): Emitted when the game ends.
view_selected(view: Control)
view_deselected(view: Control)
invalid_action_triggered(view: Control)

battle_state_changed(is_in_battle: bool) # Emitted by BattleManager to inform the app of its state.
3.2. Database.gd
Purpose: Loads all .tres files from resource directories into dictionaries on startup for fast access.
3.3. GameManager.gd
Purpose: Manages the persistent RunState of the current run. It is the authority for inventory actions in the Run Context.
Methods:
_ready(): Connects to start_run_requested, inspect_inventory_requested, close_modal_requested, and inventory_action_requested.
_on_start_run_requested(): Creates a new RunState, calls start_new_run(), emits run_inventory_changed, and emits loadout_scene_requested.
_on_inventory_action_requested(source_view, target_view): This function only proceeds if is_battle_active is false. It delegates merge logic to MergeManager. If merge fails, it performs a swap. It then emits `run_inventory_changed`.
3.4. InteractionManager.gd
Purpose: Manages the temporary UI state of a user's action (e.g., which view is selected).
Methods:
select_view(view: Control): If _selected_view is the same as view (i.e., the user clicks an already selected item), it is treated as an inspection request. It emits the standard EventBus.inspection_requested(view) signal and then clears the selection. This provides the primary 'double-click' style interaction for inspection in the MVP. If a different view is clicked, it deselects the old one, selects the new one, and emits view_selected.
3.5. MergeManager.gd
Purpose: A dedicated, stateless manager to handle all merge logic for any inventory context.
3.6. AbilityResolver.gd
Purpose: Manages the resolution of abilities and their effects.

Properties:
_ability_queue: Array[Ability]

Methods:
_ready(): Connects to `EventBus.ability_requested`.
_on_ability_requested(ability: Ability): Adds an ability to the queue and starts resolution if not already in progress.
_resolve_next_ability(): Resolves the next ability in the queue, applying its effects and emitting `EventBus.ability_resolved`.

3.7. WindowManager.gd
Purpose: A powerful, global manager for the entire lifecycle of all pop-up windows, both Workspace and Inspection types. It is the single source of truth for window state, hierarchy, positioning, and the universal closing logic.

Properties:
var _open_windows: Array[Control] # An array used as a stack to track the hierarchy of open windows.
var _window_scenes: Dictionary # Preloads all window scenes for fast instantiation.

Methods:
_ready() -> void:
- Preloads scenes like `InventoryModal.tscn`, `UnitInspectionWindow.tscn`, etc., into `_window_scenes`.
- Connects to EventBus signals that request windows: `inspect_inventory_requested`, `display_discard_pile_requested`, `inspection_requested`.
- Connects to EventBus.close_modal_requested to provide a programmatic way to close the topmost window.

_unhandled_input(event) -> void:
- Implements the universal "click-through" closing logic.
- On a mouse click (that is not part of a drag), it iterates through `_open_windows` from child to parent.
- If the click is outside a window's boundary, it closes that window and all its children (all windows above it in the stack).
- It then programmatically re-issues a "phantom" click at the original coordinates, allowing the UI element underneath to process the input.

open_workspace_window(type: StringName, context_data: Dictionary) -> void:
- Closes all currently open windows.
- Instantiates the requested workspace window (e.g., `InventoryModal`).
- Populates the window with the provided `context_data`.
- Places it at its predefined, fixed position.
- Adds it to the `_open_windows` stack and the scene tree.

open_inspection_window(source_view: Control) -> void:
- Determines the hierarchy level of the `source_view` (is it on the board, or inside another window?).
- Closes any existing windows at or above the new window's hierarchy level.
- Instantiates the correct inspection window (`Unit` or `Item`) based on the `source_view`'s data.
- Calls `_calculate_window_position()` to get its placement.
- Adds the new window to the `_open_windows` stack and the scene tree.

_calculate_window_position(source_view: Control, new_window: Control) -> Vector2:
- A detailed algorithm to dynamically place an inspection window.
- It gets the global rectangles of the `source_view`, the `new_window`, the screen `viewport`, and any potential `parent_window`.
- It tests a priority list of positions (Right, Left, Bottom, Top) relative to the `source_view`.
- A position is valid if it is within the viewport **and** does not overlap the `parent_window` (if one exists).
- The first valid position found is returned.
- If no position is valid, it falls back to the first on-screen position, even if it causes an overlap, to ensure the window is always visible.

3.8. SceneManager.gd
Purpose: Handles scene transitions and management.

Properties:
*   _current_scene: Node

Methods:
*   `_ready()`: Initializes the scene manager.
*   `goto_scene(path: String)`: Changes the current scene to the specified path.

3.9. UUIDUtils.gd
Purpose: Provides utility functions for generating and managing UUIDs.

Methods:
*   `generate_uuid()`: Generates a new UUID.
*   `is_valid_uuid(uuid: String)`: Checks if a string is a valid UUID.

4. Scene Blueprints & Associations

4.1. UI Component Blueprints

**GachaBallView.tscn**: A reusable UI component for displaying a single `Gachapon Ball` (either a `Unit` or an `Item`). It handles visual feedback for selection, hover, and drag-and-drop.

**UnitInspectionWindow.tscn**: A dynamically positioned window for displaying detailed unit information.
- **Scene Tree:** Its root is a `PanelContainer` with the `UnitInspectionWindow.gd` script. It contains:
  - VBoxContainer
    - %NameLabel (Label)
    - %DescriptionLabel (Label)
    - %ItemGrid (GridContainer): Dynamically populated with `GachaBallView` instances for equipped items.

**ItemInspectionWindow.tscn**: A dynamically positioned window for displaying detailed item information.
- **Scene Tree:** Its root is a `PanelContainer` with the `ItemInspectionWindow.gd` script. It contains:
  - VBoxContainer
    - %NameLabel (Label)
*   **`GachaBallView.gd`**: This is a 'dumb' view component that handles only the visual representation of a GachaBall. It receives user input and forwards it to the appropriate manager.
    *   **Input Logic**: Its `_gui_input` function detects clicks and drag-and-drop actions. All action logic is initiated by passing control to the `InteractionManager` or by emitting signals on the `EventBus`.
    *   **Properties**: `instance_data: GachaBallInstance` (read-only, updated by its parent container/manager)
    *   **Methods**: `update_display()`: Updates visuals based on `instance_data`. `play_animation(anim_name)`: Plays visual feedback animations.

4.2. Main.tscn & Main.gd
The persistent UI shell. Its script, Main.gd, acts as a UI controller, primarily responsible for showing/hiding the "Draw Tier" buttons based on the battle_state_changed signal. The "Inspect Inventory" button directly emits the inspect_inventory_requested signal, which is handled globally by the WindowManager. The WindowManager then determines the context and opens the InventoryModal with the correct data source.

4.3. Battle.tscn & BattleManager.gd
The battle scene. BattleManager.gd is the authority for all game logic in the Battle Context. It manages the temporary _battle_inventory, _draw_pools, and _discard_pile. It is the sole handler of inventory_action_requested signals while a battle is active.

4.4. Placeholder Slots & DropTarget.gd
All placeholder slots in Battle.tscn (and any other drop zone) are PanelContainer nodes with the DropTarget.gd script attached. This script allows the empty slot to be a valid target for both drag-and-drop and click-to-move actions, emitting inventory_action_requested upon interaction.

5. Detailed Input Handling & Interaction Model
This section explicitly defines the two primary input paradigms: action-oriented and information-oriented.

5.1. Input Types on GachaBallView
There are two primary input paradigms: Action-Oriented (selecting and moving pieces) and Information-Oriented (inspecting pieces). For the MVP, these are handled as follows:
*   **Short-Click / Drag-and-Drop (Action):** These inputs are used to select, move, swap, merge, and equip items. This entire flow is managed by the `InteractionManager`.
*   **Click on Selected (Information):** The sole method for inspecting a unit in the MVP. If a user clicks on a `GachaBallView` that is already selected, the `InteractionManager` interprets this as a request for information and emits `EventBus.inspection_requested(self)`.

5.2. Action-Oriented Flow (InteractionManager)
This flow is for manipulating game pieces.
*   **State:** The `InteractionManager` holds `_selected_view: Control = null`.
*   **Click-to-Select:** A short-click on a `GachaBallView` calls `InteractionManager.select_view(self)`. If nothing is selected, it becomes selected. If it's already selected, it's deselected.
*   **Click-to-Act:** If a view is already selected, short-clicking another view emits `EventBus.inventory_action_requested(source_view, target_view)`.
*   **Drag-to-Act:** Dragging one view and dropping it onto another emits `EventBus.inventory_action_requested(source_view, target_view)`.

5.3. Information-Oriented Flow (WindowManager)
This flow is for opening and managing `Inspection Windows`.
*   **Trigger:** A user clicks on a `GachaBallView` that is already selected (as tracked by `InteractionManager`). The `InteractionManager` then emits `EventBus.inspection_requested(self)`.
*   **Handling:** The global `WindowManager` receives this signal and orchestrates the opening of the appropriate `UnitInspectionWindow` or `ItemInspectionWindow`, calculating its position to avoid overlapping its parent.

5.4. Universal Window Closing Logic (WindowManager)
All pop-up windows, regardless of type, are governed by a single, universal closing mechanism managed by `WindowManager`.
*   **Trigger:** A click (press and release without significant movement) anywhere on the screen.
*   **Execution:**
    1.  The `WindowManager`'s global `_unhandled_input` function intercepts the click.
    2.  It checks if the click location is outside the boundaries of the topmost window in its hierarchy stack (`_open_windows`).
    3.  If it is, that window and any of its children are instantly closed and removed from the scene. The process repeats down the hierarchy until it finds a window that contains the click, or all windows are closed.
    4.  A "phantom" click is then programmatically sent to the exact screen coordinates of the original click.
*   **Result:** This allows a user to close a window and interact with whatever is behind it in a single, fluid action. For example, clicking a different item in a unit's inventory will close the old item's inspection window and simultaneously trigger the long-press to open the new one.

6. Detailed Logic Flows & Behaviors
6.1. Battle Setup Flow (in BattleManager.gd)
When Battle.tscn is instantiated, BattleManager executes the following setup sequence:
Retrieves the hero_instance directly from GameManager.run_state.
Creates a battle copy of the Hero using create_battle_copy().
Adds the Hero copy to its _battle_inventory and places its view in the first lineup slot. The Hero is not added to the _draw_pools.
Iterates through the GameManager.run_state.run_inventory (tiers 1, 2, 3).
For each permanent instance, it creates a battle copy.
Each copy is added to both the master _battle_inventory and the consumable _draw_pools for the appropriate tier.
Finally, it emits battle_state_changed(true) to notify the rest of the application that a battle is now active.
6.2. Gacha Draw Flow (in BattleManager.gd)
Receives draw_gacha_requested(tier).
Picks a random instance from _draw_pools[tier] and removes it from that pool (it remains in _battle_inventory).
Finds the first available empty slot (PlayerBench for Units, ItemInventory for Items).
If a slot is found, places the new view there. If not, the instance is added to the _discard_pile.

6.4. Merge Process (in MergeManager.gd)
Validation: Finds a valid recipe for the two ingredient instance IDs.
New Instance Creation: Creates a new GachaBallInstance for the result.
Item Transfer: Gathers all equipped item instances from both parents. The item instances themselves are re-assigned, not copied, preserving their state.
Inventory Update: Removes both parent instances and all their transferred items from the source inventory dictionary. Then adds the new merged instance and re-adds the transferred items back into the inventory, now linked to the new unit's UUID.