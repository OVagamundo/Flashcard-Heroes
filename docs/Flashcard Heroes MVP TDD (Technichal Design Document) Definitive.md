Flashcard Heroes - Core Mechanics MVP TDD (Definitive Edition)
Part 1: Project Blueprint
1.1 Architectural Principles
Data is the Source of Truth: Game state is stored in data structures (Arrays, Dictionaries). The UI is a disposable reflection of this data.
The Intent-Action Model: User input is translated into a clear "intent" signal before being processed by logic controllers.
Hierarchical Input Handling: User input is processed in a strict order of priority. An input event is "consumed" at the first level that can handle it, preventing it from propagating further. The order is: 1) Modal Blockers, 2) Individual UI Components (Buttons, Views), 3) Inspection Window Panels, 4) The Global _unhandled_input handler in WindowManager as a final fallback for "background" clicks.
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
│   ├── recipes/
│   └── decks/
├── scenes/
└── scripts/
Use code with caution.
Part 2: Data Schemas & Structures
2.1 Data Resource Schemas
GachaBallDefinition.gd: Resource, class_name GachaBallDefinition. The template for a GachaBall.
Properties: @export var id: StringName, @export var display_name_key: String, @export var description_key: String, @export var icon: Texture2D, @export var tier: int, @export var category: StringName, @export var item_slot_count: int
GachaBallInstance.gd: Resource, class_name GachaBallInstance. A unique instance of a GachaBall.
Properties: definition_id: StringName, ball_uuid: String, origin_uuid: String, equipped_item_uuids: Array[String]
Method: initialize(def: GachaBallDefinition): Sets definition_id, generates ball_uuid, and resizes equipped_item_uuids to def.item_slot_count, filling it with empty strings ("").
Method: create_battle_copy() -> GachaBallInstance: Creates a new deep copy, assigning a new ball_uuid and setting origin_uuid to the original's ball_uuid.
MergeRecipe.gd: Resource, class_name MergeRecipe. Defines a valid merge.
Properties: @export var id: StringName, @export var ingredient_a_id: StringName, @export var ingredient_b_id: StringName, @export var result_id: StringName, @export var is_self_merge: bool, @export var merge_type: StringName
ConditionDefinition.gd: Resource, class_name ConditionDefinition. Defines ability conditions. For MVP, its evaluate() method is a placeholder that always returns true.
FlashcardDeckDefinition.gd: Resource, class_name FlashcardDeckDefinition.
Properties: @export var id: StringName, @export var display_name_key: String, @export var card_list: Array[Dictionary]
2.2 Inventory Data Structures
This table defines the size, structure, and behavior of every data container in the game.
Container Name	Data Path	Structure	Initial Size	Growth Logic
Run Inventory (per Tier)	RunState.run_inventory[tier] | Data Grid (Array) | 4x4 (16 slots) | Fixed size (with plan to add growth logic later). *Implementation: A 1D Array where null represents an empty slot.*
Battle Inventory (per Tier) | BattleManager._battle_inventory[tier] | Data Grid (Array) | 4x4 (16 slots) | Grows vertically by 4 slots when full. *Implementation: A 1D Array where null represents an empty slot.*
Discard Pile	BattleManager.discard_pile | Data Grid (Array) | 4x4 (16 slots) | Grows vertically by 4 slots when full | Stores units and items of all tiers discarded (by death or other means) during the battle. *Implementation: A 1D Array where null represents an empty slot.*
Player Lineup	BattleManager.lineup_data	Fixed-Size Array	6 slots	None. Fixed size.
Player Bench	BattleManager.bench_data	Fixed-Size Array	3 slots	None. Fixed size.
Item Inventory	BattleManager.item_data	Fixed-Size Array	3 slots	None. Fixed size.
2.3 MVP Data File Manifest
The following .tres files must be created in their respective res://resources/ subdirectories.
Units & Hero (res://resources/units/)
| Filename | id | tier | category | item_slot_count | icon (Path) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Hero.tres | hero | 0 | "UNIT" | 5 | res://assets/sprites/units/Hero.png |
| UnitTier1A.tres | unit_t1_a | 1 | "UNIT" | 1 | res://assets/sprites/units/UnitTier1A.png|
| UnitTier1B.tres | unit_t1_b | 1 | "UNIT" | 1 | res://assets/sprites/units/UnitTier1B.png|
| UnitTier2C.tres | unit_t2_c | 2 | "UNIT" | 2 | res://assets/sprites/units/UnitTier2C.png|
| UnitTier3D.tres | unit_t3_d | 3 | "UNIT" | 4 | res://assets/sprites/units/UnitTier3D.png|
Items (res://resources/items/)
| Filename | id | tier | category | icon (Path) |
| :--- | :--- | :--- | :--- | :--- |
| ItemTier1A.tres | item_t1_a | 1 | "ITEM" | res://assets/sprites/items/ItemTier1A.png|
| ItemTier1B.tres | item_t1_b | 1 | "ITEM" | res://assets/sprites/items/ItemTier1B.png|
| ItemTier2C.tres | item_t2_c | 2 | "ITEM" | res://assets/sprites/items/ItemTier2C.png|
| ItemTier3D.tres | item_t3_d | 3 | "ITEM" | res://assets/sprites/items/ItemTier3D.png|
Recipes (res://resources/recipes/)
| Filename | ingredient_a_id | ingredient_b_id | result_id | is_self_merge | merge_type |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Merge_Unit_A_B_to_C.tres | unit_t1_a | unit_t1_b | unit_t2_c | false | "UNIT" |
| Merge_Unit_C_C_to_D.tres | unit_t2_c | unit_t2_c | unit_t3_d | true | "UNIT" |
| Merge_Item_A_B_to_C.tres | item_t1_a | item_t1_b | item_t2_c | false | "ITEM" |
| Merge_Item_C_C_to_D.tres | item_t2_c | item_t2_c | item_t3_d | true | "ITEM" |
Part 3: Logic Layer & Managers
3.1 EventBus Signals
start_run_requested, loadout_scene_requested, main_scene_requested, battle_start_requested
inspect_inventory_requested, display_discard_pile_requested, close_modal_requested
draw_gacha_requested(tier: int)
inventory_action_requested(source_view: Control, target_view: Control)
choice_made(choice_id: String)
inspection_requested(source_view: Control)
view_selected(view: Control), view_deselected(view: Control)
invalid_action_triggered(view: Control)
selection_context_changed(view: Control): Purpose is to announce that the user's selection focus has shifted to a new view, allowing other systems to react before the selection is finalized.
run_inventory_changed, battle_inventory_changed
battle_state_changed(is_in_battle: bool)
3.2 Singleton Managers
GameManager.gd: Holds the RunState resource and the global is_in_battle: bool flag.
InventoryManager.gd: Sole listener for inventory_action_requested. It uses the Action Decision Tree and Compatibility Rules Table below to process all inventory logic.
InteractionManager.gd: This is NOT an input handler. It is a state machine that holds the _selected_view. It does not process raw input. It is instructed to change state by other UI components (like GachaBallView) that handle the raw input themselves. Its primary job is to track the "selected" state and provide that information to other systems. It also manages drag-and-drop state. It must emit the selection_context_changed signal whenever a new view is selected that is different from the currently selected one. This signal must be emitted before the old selection is cleared and the new one is set.
MergeManager.gd: A stateless helper used by InventoryManager. Its primary method takes two parent instances and the inventory they exist in. It finds a valid recipe, calculates the resulting new instance with its inherited items, and returns a data package containing the new instance and a list of all parent instances that should be removed. It does not modify any inventory data directly.
Database.gd: Loads all .tres resources on startup for fast access.
SceneManager.gd: Handles scene transitions.
AbilityResolver.gd: Manages ability queue and resolution (placeholder logic for MVP).
UUIDUtils.gd: Provides a generate_uuid() utility function.
### 3.2 Unified Interaction & Window Management Model

**WindowManager.gd** is the sole authority for the lifecycle of all modal and inspection windows. No other script creates, destroys, or positions these UI elements directly. This centralized control prevents race conditions and ensures a predictable UI state.

#### 3.2.1 Core Principles

1.  **Centralized Authority**: All requests to open or close windows (e.g., `inspect_inventory_requested`, `display_discard_pile_requested`) are handled by `WindowManager`. It manages window instances, positioning, and cleanup.
2.  **Hierarchical Window Groups**: `WindowManager` tracks all open inspection windows in a data structure: `_inspection_window_groups: Array[Array]`. Each inner array represents a single hierarchical chain of windows (e.g., `[UnitInspectWindow, ItemInspectWindow, TooltipWindow]`). This structure is the source of truth for which inspection windows are currently active.
3.  **Exclusive Inspection Chains**: Only one inspection chain can be active at a time. If a user action requests a "root" inspection (i.e., clicking an item on the main game board or in a modal inventory grid), `WindowManager` will first destroy any and all existing inspection chains before creating the new one. This prevents multiple, unrelated inspection windows from cluttering the screen.
4.  **Selection Context Invalidation**: The WindowManager must react to a change in the user's selection context. When a new "root" view (a view not contained within an existing inspection window) is selected, the WindowManager must immediately close all open inspection window chains. This provides instant feedback that the previous inspection context is no longer relevant and prevents orphaned windows when the user's focus shifts.
4.  **Hierarchical Pruning**: Clicking on the background of an already-open inspection window (e.g., clicking the panel of `UnitInspectWindow` while `ItemInspectWindow` is also open) will close all of its descendants in the chain, but leave the clicked window and its ancestors open. This provides an intuitive way for the user to "step back" through an inspection chain.
5.  **Modal Context Cleanup**: The opening of any major modal window (like the Inventory or Discard Pile) must trigger `WindowManager` to close all active inspection windows. Similarly, when a modal window is closed, any inspection windows that were spawned from it must also be closed.

#### 3.2.2 Critical `mouse_filter` Usage

The entire system relies on the correct `mouse_filter` properties on UI elements to route input correctly:

*   **Inspection Windows** (e.g., `UnitInspectionWindow`): The root `PanelContainer` must have `mouse_filter = STOP`. This is critical for capturing background clicks *on itself* and enabling the hierarchical pruning logic.
*   **Modal Content Panels** (e.g., the main `PanelContainer` in `InventoryModal`): Must have `mouse_filter = PASS`. This allows clicks on their empty background areas to "pass through" to the `BackgroundBlocker` behind them, correctly triggering the modal close event.
*   **Full-Screen Backgrounds** (e.g., a panel behind the main game UI): Must have `mouse_filter = IGNORE` so they do not consume clicks intended for the global `_unhandled_input` handler.

#### 3.2.3 Global Input Handling (`_unhandled_input`)

The `WindowManager`'s global input handler is the final authority on clicks that are not consumed by other UI controls. It is responsible for deselection and closing windows when the user clicks on the "background".

1.  **Event**: An unhandled mouse click is detected.
2.  **Check Modals**: The handler iterates through all active modal windows. If the click is within the rect of any modal's content panel, the event is ignored (as the modal's own logic or `BackgroundBlocker` will handle it).
3.  **Check Inspection Windows**: The handler iterates through all active inspection windows (`_inspection_window_groups`). If the click is within the rect of any inspection window, the event is ignored (as the window's own `STOP` filter will handle it for pruning).
4.  **Global Close/Deselect**: If all checks fail, the click is a true "background" click. `WindowManager` will then:
    *   Call `InteractionManager.clear_selection()` to deselect any selected view.
    *   Call its own `close_all_inspection_windows()` method to clear all inspection chains.

3.3 Inventory Action Logic
Action Decision Tree (in InventoryManager.gd)
This logic is followed strictly in order for any inventory_action_requested event.
Target is Empty (SlotView): Intent is Move.
Target is Filled (GachaBallView):
Check for Merge: Does a valid merge recipe exist between the source and target?
Yes: Request a ChoiceModal from WindowManager (Merge/Swap).
No: Proceed to the next check.
Check for Equip: Is the source an ITEM, the target a UNIT, and are both located on the Battle Board (i.e., their data exists in lineup_data, bench_data, or item_data)?
Yes: Intent is Equip.
All other cases: Intent is Swap. (e.g., Unit-Unit with no recipe, Item-Item with no recipe, Unit-Item, Item-Unit in Run Inventory, Item-Unit where one or both are not on the Battle Board).
Merge Destination Logic
In Run Inventory: The parent instances are removed. The new merged instance is placed in the first available null slot of its corresponding tier grid in RunState.run_inventory.
In Battle (via Inventory Modal): The parent instances are removed from the _battle_inventory master list. The new merged instance is placed in the first available null slot of its corresponding tier grid in BattleManager._battle_inventory. It does not go directly to the bench or lineup.
Compatibility Rules Table (in InventoryManager.gd)
These are additional hard-fail checks applied during action handling.
| Action | Context | Source/Target Location | Compatibility Check | Result |
| :--- | :--- | :--- | :--- | :--- |
| Move | Any | Hero -> Not in lineup_data | Invalid. Hero is locked to lineup. | Invalid |
| Move | Any | Any -> Full Fixed-Size Grid | Target grid has no null slots. | Invalid |
| Swap | Any | Hero <-> Any Unit | Allowed only if target is in lineup_data. | Valid |
| Equip | Run Inventory | Any -> Any | GameManager.is_in_battle is false. | Invalid (Fallback to Swap) |
| Equip | Battle | Item or Unit not on Battle Board | Instance not in lineup_data, bench_data, or item_data. | Invalid |
| Equip | Any | Item -> Unit | Unit has no empty "" in equipped_item_uuids. | Invalid |
Asynchronous Action Safeguard
Buttons triggering actions with visual delays (Draw, Reshuffle, Merge) must be disabled immediately on being pressed. They are re-enabled only after the corresponding *_inventory_changed signal is processed and the UI redraw is complete.
Part 4: Presentation Layer (UI)
4.1 UI Component Blueprints
GachaBallView.tscn:
Purpose: Visual representation of a GachaBallInstance.
Scene Tree: PanelContainer -> TextureRect (%Icon), Label (%Tier), AnimationPlayer.
Script (GachaBallView.gd): Holds instance_data. An initialize() method stores its location context. A new public property, is_selectable: bool = true, dictates its behavior.
The view component must have a public boolean property, is_selectable, which defaults to true.
The view's click behavior is dictated by this property:
If is_selectable is true (e.g., for a view in a main inventory grid), a click is routed through the InteractionManager to handle the standard select/inspect/deselect cycle.
If is_selectable is false (e.g., for a view representing a child item inside an already-open inspection window), a click bypasses the InteractionManager's selection logic and directly emits a global inspection_requested event for that view. This creates a "one-click inspect" behavior for non-selectable, nested items.
The script also enables a yellow outline on view_selected and plays a "shake" animation on invalid_action_triggered.
SlotView.tscn:
Purpose: Visual representation of a null value in a data grid.
Scene Tree: A simple PanelContainer.
Script (SlotView.gd): An initialize() method stores its location context in the node's metadata (`set_meta`). Reports interactions to InteractionManager.
4.2 Window & UI Scene Blueprints
UnitInspectionWindow.tscn:
Scene Tree: PanelContainer -> VBoxContainer -> %NameLabel (Label), %DescriptionLabel (Label), %ItemGrid (GridContainer).
Scripting Note: Its root PanelContainer must have its `mouse_filter` property set to `STOP` to enable parent-click pruning.
ItemInspectionWindow.tscn:
Scene Tree: PanelContainer -> VBoxContainer -> %NameLabel (Label), %DescriptionLabel (Label).
Scripting Note: Its root PanelContainer must have its `mouse_filter` property set to `STOP` to enable parent-click pruning.
ChoiceModal.tscn:
Purpose: Prompts user for Merge/Swap choice.
Scene Tree: PanelContainer -> VBoxContainer -> Label ("What would you like to do?"), HBoxContainer -> %MergeButton (Button), %SwapButton (Button).
Battle.tscn UI Elements:
BackgroundBlocker.tscn:
Purpose: A full-screen, semi-transparent layer that captures all mouse input behind a modal window.
Scene Tree: A `ColorRect` node covering the entire screen.
Script (BackgroundBlocker.gd): Emits a `background_clicked` signal on user input, which `WindowManager` uses to close the top-most modal.
Includes a %ReshuffleButton and a %DiscardPileButton.

### 4.3 Modal Window Interaction Rules

To ensure a fluid and intuitive user experience, all modal windows that occupy a portion of the screen must adhere to the following architectural rules:

1.  **Composition:** A modal consists of two primary nodes: a `BackgroundBlocker` scene instance that covers the full screen, and a primary `PanelContainer` (or similar `Control` node) that contains the modal's actual content and sits visually on top of the blocker.
2.  **Background Closing:** A click on the `BackgroundBlocker` must close the modal. This is the blocker's primary function.
3.  **"Pass-Through" Panel Behavior (Designer Mandate):** The modal's primary content `PanelContainer` must have its `mouse_filter` property set to `PASS`. This is a critical rule to ensure that clicks on the panel's empty background area (i.e., not on an interactive child like a button or item grid) are not stopped by the panel. Instead, they "pass through" to the `BackgroundBlocker` behind it, which then correctly interprets the click as an intent to close the modal.
Part 5: Game Flows
5.1 Battle Setup Flow (BattleManager._setup_battle)
Retrieves hero_instance from GameManager, creates a battle copy, and places its data in lineup_data[0].
Iterates through GameManager.run_state.run_inventory. For each non-null instance, creates a battle copy.
Each copy is added to both the master _battle_inventory and the consumable _draw_pools for the appropriate tier.
Emits battle_inventory_changed to trigger the initial board draw.
5.2 Gacha Draw Flow (BattleManager.gd)
Receives draw_gacha_requested(tier).
Picks a random instance from _draw_pools[tier] and removes it from that pool.
Determines the destination grid based on category (bench_data for Units, item_data for Items).
Finds the first available null slot in the destination grid.
If a slot is found, places the instance's data there.
If no slot is found, the instance's data is added to the _discard_pile grid.
Emits battle_inventory_changed.
5.3 Reshuffle Flow (BattleManager._on_reshuffle_requested)
Triggered by the %ReshuffleButton.
Iterates through the _discard_pile grid.
For each non-null instance, moves it from _discard_pile to the correct _draw_pools[tier].
Clears the _discard_pile grid (fills it with null values).
Emits battle_inventory_changed.