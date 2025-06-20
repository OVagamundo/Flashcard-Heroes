Flashcard Heroes Core Mechanics MVP TDD v12.1 
1. Introduction & MVP Goal
1.1. Purpose
This document provides the complete and final technical blueprint for the "Core Mechanics MVP" of Flashcard Heroes. It is a self-contained specification designed to be followed precisely by a development agent. All required data, scene structures, script logic, and interaction flows are explicitly defined herein to eliminate ambiguity and assumptions. This document is the sole source of truth for the MVP.
1.2. Core Architectural Principles
This project is built on two key ideas to keep the code clean and easy to manage:
Separation of Data and View:
Data (GachaBallInstance): This is a Resource file, which is like a data container in Godot. It holds all the information about a specific, unique GachaBall (its ID, UUID, what items it has equipped, etc.). It has no visual component and is never shown directly to the player. Think of it as the "brain" or the "character sheet."
View (GachaBallView and its variants): This is a UI Scene (Control node). It's the visual representation that the player sees and interacts with on screen. Each GachaBallView holds a reference to a GachaBallInstance. Its job is to look at the data in that instance and update its own appearance (its icon, the icons of its equipped items, etc.) to match. Think of it as the "body" or the "pawn on the board."
Event-Driven Communication (EventBus):
Instead of different parts of the code calling each other directly (which can get messy), they communicate by sending out signals, like radio broadcasts. A central, global script called EventBus manages these signals. For example, when the player clicks a button, that button's script doesn't need to know about the GameManager; it just emits a signal like start_run_requested. The GameManager, which is listening for that signal, then performs its action. This keeps all the systems decoupled and independent.
1.3. Terminology Clarification
Slot: A conceptual, numbered position within an inventory's data array (e.g., PlayerBench[0]). This is a data-level concept used by the programmer.
GachaBallView: The player-facing UI element. The player clicks on and drags GachaBallViews. When this view is not displaying any data, it will show a faint placeholder frame. When it is displaying data, it shows the GachaBall's icon and other information.
1.4. Directory Structure

The project follows a strict directory structure. All scripts reside directly in `scripts/`, and all scenes reside directly in `scenes/`. Only the `assets/` and `resources/` directories are organized with subdirectories.

```
res://
├── assets/              # All visual assets (.png, .svg, or placeholders)
│   ├── sprites/        # Sprite assets
│   │   ├── units/      # Unit sprites
│   │   └── items/      # Item sprites
│
├── resources/          # All resource files (.tres)
│   ├── units/          # Unit definitions and stats
│   ├── items/          # Item definitions and stats
│   ├── recipes/        # Merge recipe definitions
│   └── decks/          # Flashcard deck definitions
│
├── scenes/            # All scene files (.tscn) - no subdirectories
│   # Example scene files:
│   # - Battle.tscn
│   # - Title.tscn
│   # - Loadout.tscn
│   # - Main.tscn
│   # - UnitView.tscn
│   # - ItemView.tscn
│
└── scripts/           # All GDScript files (.gd) - no subdirectories
```

This structure ensures clear separation of concerns and makes the project more maintainable. All scripts go in the `scripts/` directory, all scenes in `scenes/`, and all resources in `resources/` with appropriate subdirectories.

1.5. MVP User Journey
A developer using only this document will build an application where a player can:
Launch & Start: Navigate Title -> Loadout -> Main. A default Hero and starting set of GachaBallInstances are created and stored in the persistent run_inventory.

Main Scene: The Main scene appears. The user can click "Inspect Inventory" to open a modal view of their run_inventory. Inside this modal, the user can perform permanent merges by dragging one GachaBall onto another. Swapping and moving GachaBalls is also supported.
Enter Battle: From PathChoice, the user starts a battle. The Battle scene loads into the Main scene's ContentArea. The BottomArea UI updates to show "Draw" buttons.
Battle Setup: A temporary BattleInventory (copy of RunInventory) is created. The player's board starts empty, save for the Hero. A "Discard Pile" button appears.
Build a Team: The user clicks "Draw" buttons to pull random GachaBallInstances. A corresponding GachaBallView is instantiated and placed on the board. If a destination is full, the drawn instance goes to the DiscardPile.
Manage the Board: The user interacts with GachaBallViews via two equivalent methods: Click-and-Click or Drag-and-Drop to move, equip, swap, and merge.
Item Transfer on Merge: When units are merged, all items they held are transferred to the new, higher-tier unit.
Discard & Reshuffle: The user can view the DiscardPile and click "Reshuffle" to return its contents to the BattleInventory.
2. Data Schemas & Definitions
These are the custom data structures for the project. They should be created as GDScript files inheriting from Resource.
2.1. GachaBallDefinition.gd (res://resources/units/)
Inherits: Resource, class_name GachaBallDefinition
Purpose: The static template for a type of GachaBall.
Properties:
@export var id: StringName  # Unique identifier (e.g., "unit_warrior_t1")
@export var display_name_key: String  # Localization key for display name (e.g., "unit_warrior_name")
@export var description_key: String  # Localization key for description (e.g., "unit_warrior_desc")
@export var icon: Texture2D  # Visual representation of the GachaBall
@export var tier: int  # Tier level (1-3)
@export var category: StringName  # "UNIT" or "ITEM"
@export var item_slot_count: int = 0  # Number of item slots (for units only)
2.2. GachaBallInstance.gd (res://scripts/)
Inherits: Resource, class_name GachaBallInstance
Purpose: A unique, individual instance of a GachaBall.

Properties:
definition_id: StringName
ball_uuid: String
origin_uuid: String
equipped_item_uuids: Array[String]
location_state: int

# Enum for tracking the instance's current location in the game
enum LocationState {
    UNDEFINED = -1,
    RUN_INVENTORY = 0,
    BATTLE_INVENTORY = 1,
    BATTLE_BOARD = 2,
    DISCARD_PILE = 3,
    MERGE_PREVIEW = 4,
    INSPECT_VIEW = 5
}

Methods:
initialize(def: GachaBallDefinition): Sets definition_id, generates a unique ball_uuid using the global `UUIDUtils` autoload, resizes equipped_item_uuids to def.item_slot_count (filling it with empty strings), and sets the initial location_state to RUN_INVENTORY. The UUID format is descriptive, e.g., "unit_t1_a_1677628800_1234".
create_battle_copy() -> GachaBallInstance: Creates a temporary copy for a battle session. A new ball_uuid is generated, the origin_uuid links back to the permanent instance in the RunInventory, and the copy's location_state is set to BATTLE_INVENTORY.

2.3. MergeRecipe.gd (res://scripts/)
Inherits: Resource, class_name MergeRecipe
Purpose: Defines a valid merge combination.
Properties:
@export var ingredient_a_id: StringName
@export var ingredient_b_id: StringName
@export var result_id: StringName
@export var is_self_merge: bool = false
@export var merge_type: StringName # "UNIT" or "ITEM"
Example .tres Files:
Recipes: Merge_Unit_A_B_to_C.tres, Merge_Unit_C_C_to_D.tres, Merge_Item_A_B_to_C.tres, Merge_Item_C_C_to_D.tres.

2.4. FlashcardDeckDefinition.gd (res://resources/flashcard_decks/)
Inherits: Resource, class_name FlashcardDeckDefinition
Purpose: Defines a flashcard deck for the educational component of the game.

@export Variables:
| `id` | String | A unique identifier for this GachaBall definition (e.g., "warrior_t1"). |
| `display_name_key` | String | Localization key for the display name (e.g., "unit_warrior_name"). |
| `description_key` | String | Localization key for the description (e.g., "unit_warrior_desc"). |

**MVP Placeholder:** For the MVP, the game will use direct string values for display, but the architecture is designed to support localization in the future.

Purpose: This resource defines a collection of flashcards that will be used in the game's educational component. Each deck represents a set of related questions and answers that players will engage with during gameplay.

2.5. MVP Data File Creation & Asset Convention

**Asset Placeholder Convention:** For this MVP, visual asset files (e.g., `.png`) are not provided. They will be generated during development as placeholder `ColorRect` textures or simple `StyleBoxFlat` resources. However, the `.tres` files will still point to the intended final asset paths as specified below (e.g., `res://assets/sprites/units/UnitTier1A.png`).

**Data Convention:** The following `.tres` files must be created with the exact property values listed in the tables below to ensure testability and consistency. The `id` and `display_name` are derived from the resource's filename.

**Table 2.5.1: GachaBallDefinition for Units & Hero**
| Filename          | `id` (StringName) | `display_name` (String) | `tier` (int) | `category` (StringName) | `item_slot_count` (int) | `icon` (Path)                            |
| :---------------- | :---------------- | :---------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| `Hero.tres`       | `hero`            | "Hero"                  | 0            | "UNIT"                  | 5                       | `res://assets/sprites/units/Hero.png`      |
| `UnitTier1A.tres` | `unit_t1_a`       | "UnitTier1A"            | 1            | "UNIT"                  | 1                       | `res://assets/sprites/units/UnitTier1A.png`|
| `UnitTier1B.tres` | `unit_t1_b`       | "UnitTier1B"            | 1            | "UNIT"                  | 1                       | `res://assets/sprites/units/UnitTier1B.png`|
| `UnitTier2C.tres` | `unit_t2_c`       | "UnitTier2C"            | 2            | "UNIT"                  | 2                       | `res://assets/sprites/units/UnitTier2C.png`|
| `UnitTier3D.tres` | `unit_t3_d`       | "UnitTier3D"            | 3            | "UNIT"                  | 4                       | `res://assets/sprites/units/UnitTier3D.png`|

**Table 2.5.2: GachaBallDefinition for Items**
| Filename          | `id` (StringName) | `display_name` (String) | `tier` (int) | `category` (StringName) | `item_slot_count` (int) | `icon` (Path)                            |
| :---------------- | :---------------- | :---------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| `ItemTier1A.tres` | `item_t1_a`       | "ItemTier1A"            | 1            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier1A.png`|
| `ItemTier1B.tres` | `item_t1_b`       | "ItemTier1B"            | 1            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier1B.png`|
| `ItemTier2C.tres` | `item_t2_c`       | "ItemTier2C"            | 2            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier2C.png`|
| `ItemTier3D.tres` | `item_t3_d`       | "ItemTier3D"            | 3            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier3D.png`|

**Table 2.5.3: MergeRecipe Data**
| Filename                   | `ingredient_a_id` | `ingredient_b_id` | `result_id` | `is_self_merge` | `merge_type` |
| :------------------------- | :---------------- | :---------------- | :---------- | :-------------- | :----------- |
| `Merge_Unit_A_B_to_C.tres` | `unit_t1_a`       | `unit_t1_b`       | `unit_t2_c` | `false`         | "UNIT"       |
| `Merge_Unit_C_C_to_D.tres` | `unit_t2_c`       | `unit_t2_c`       | `unit_t3_d` | `true`          | "UNIT"       |
| `Merge_Item_A_B_to_C.tres` | `item_t1_a`       | `item_t1_b`       | `item_t2_c` | `false`         | "ITEM"       |
| `Merge_Item_C_C_to_D.tres` | `item_t2_c`       | `item_t2_c`       | `item_t3_d` | `true`          | "ITEM"       |

2.6. ConditionDefinition.gd (res://scripts/)
Inherits: Resource, class_name ConditionDefinition
Purpose: Defines conditions for ability effects and other game mechanics.

Methods:
evaluate(source: GachaBallInstance, target: GachaBallInstance, battle_manager: BattleManager, event_data: Dictionary = {}) -> bool:
MVP Scope Note: For the MVP, this method will be a placeholder and will always return true to ensure the architectural flow can be tested without implementing the specific logic for each condition type.

3. Autoloaded Scripts (Singletons)
These are configured in Project -> Project Settings -> Autoload to be globally accessible.
3.1. EventBus.gd
Purpose: A global script containing only signal definitions for the entire game. All communication between major systems happens through these signals.

Signals:
* `start_run_requested`
* `loadout_scene_requested`
* `main_scene_requested`
* `battle_start_requested`
* `inspect_inventory_requested`
* `close_modal_requested`
* `draw_gacha_requested(tier: int)`
* `inventory_action_requested(source_view: Control, target_view: Control)`
* `show_choice_prompt(options: Dictionary)`
* `choice_made(choice: StringName)` # "MERGE" or "SWAP"
* `view_selected(view: Control)`
* `view_deselected(view: Control)`
* `invalid_action_triggered(view: Control)`
* `view_data_updated(view: Control)`
* `display_discard_pile_requested`
* `reshuffle_discard_pile_requested`
3.2. Database.gd
Purpose: Loads all .tres files from the resource directories into dictionaries on game startup for fast access.

Properties:
var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition

Methods:
_ready() -> void:
- Connects to a utility function `_load_resources_from_path` to populate the dictionaries.
- Scans `res://resources/units/` and populates `units`.
- Scans `res://resources/items/` and populates `items`.
- Scans `res://resources/recipes/` and populates `recipes`.
- Scans `res://resources/decks/` and populates `decks`.

_load_resources_from_path(path: String, dictionary: Dictionary) -> void:
- A helper function that iterates through a directory, loads each `.tres` file, and stores it in the provided dictionary, using the resource's `id` property as the key.
3.3. GameManager.gd
Purpose: Manages the persistent state of the current run (RunInventory). It initializes the run and handles permanent inventory actions by delegating to the MergeManager.

Properties:
run_state: RunState  # Holds the tiered inventory structure
is_inspecting_inventory: bool = false

Methods:
_ready() -> void:
- Connects to EventBus.start_run_requested.
- Connects to EventBus.inspect_inventory_requested to set its state.
- Connects to EventBus.close_modal_requested to clear its state.
- Connects to EventBus.inventory_action_requested to handle permanent merges.

_on_start_run_requested() -> void:
- Clears any existing run_inventory.
- Calls _create_initial_run_inventory().
- Emits main_scene_requested.

_on_inventory_action_requested(source_view: Control, target_view: Control) -> void:
- This function only proceeds if is_inspecting_inventory is true.
- It retrieves the GachaBallInstance data from both the source and target views.
- It delegates the merge logic to MergeManager.attempt_merge(source_data, target_data, self.run_state.run_inventory). The run_inventory is now a tiered dictionary, and the MergeManager is responsible for all manipulations within it.
- If the merge is successful, the inventory is updated, and the logic concludes.
- If the merge fails (i.e., returns null), it proceeds to perform a swap. It finds the indices of the source and target instances in the run_inventory array and swaps their positions.
- This ensures that any interaction between two views in the inventory modal results in either a merge or a swap, providing consistent and intuitive feedback to the player.
- If the merge is successful, it triggers a UI refresh of the inventory modal.

_create_initial_run_inventory() -> void:
- Creates a starting set of GachaBallInstances containing two of every defined unit and item type to allow for direct testing of all merge recipes. The inventory will contain: 1x Hero, 2x UnitTier1A, 2x UnitTier1B, 2x UnitTier2C, 2x UnitTier3D, 2x ItemTier1A, 2x ItemTier1B, 2x ItemTier2C, and 2x ItemTier3D.
- For each GachaBallInstance created, it reads the tier from its definition and adds the instance to the correct sub-array within the run_state.run_inventory dictionary (e.g., run_inventory[definition.tier].append(instance)).
3.4. InteractionManager.gd
Purpose: Manages the temporary UI state of a user's action (e.g., which GachaBallView is currently selected). It acts as the central point for handling player input state.

Properties:
var _selected_view: Control = null
var is_drag_active: bool = false

Methods:
_ready() -> void:
- Connects to `EventBus.inventory_action_requested` to clear the selection after an action is committed.

select_view(view: Control) -> void:
- If `_selected_view` is the same as `view`, calls `clear_selection()`.
- Otherwise, deselects any currently selected view and selects the new `view`.
- Emits `EventBus.view_selected(view)`.

clear_selection() -> void:
- If a view is selected, emits `EventBus.view_deselected(_selected_view)`.
- Sets `_selected_view = null`.

get_selected_view() -> Control:
- Returns the `_selected_view`.

trigger_invalid_action_feedback(view: Control) -> void:
- Emits `EventBus.invalid_action_triggered(view)`.
3.5. MergeManager.gd
Purpose: A dedicated, global manager to handle all merge logic for both the permanent RunInventory and the temporary BattleInventory. This centralizes the complex interaction logic. It is called by GameManager for permanent merges and BattleManager for in-battle merges.

Methods:
attempt_merge(instance_a: GachaBallInstance, instance_b: GachaBallInstance, inventory_dict: Dictionary) -> GachaBallInstance:
- Takes two instances and the tiered inventory dictionary they belong to (either run_state.run_inventory or battle_inventory).
- Validates that both instances can be merged by checking for a valid recipe.
- If valid, creates a new GachaBallInstance based on the recipe result.
- Transfers all equipped items from both parents to the new instance.
- Removes the parent instances from their respective tier-specific arrays within the source inventory_dict.
- Adds the new result instance to the correct tier-specific array in the inventory_dict.
- Returns the newly created merged_instance on success, or null on failure.

find_recipe(id_a: StringName, id_b: StringName) -> MergeRecipe:
- A helper function to find a matching recipe for two GachaBall definition IDs.

3.6. AbilityResolver.gd
Purpose: A global script that processes ability effects and conditions.

Properties:
var ability_queue: Array = []

Methods:
_apply_effect(effect_data: Dictionary) -> void:
- MVP Scope Note: For the initial MVP, this method will be implemented with a match statement but the logic within each case will be commented out or use `pass`.

resolve_queue() -> void:
- MVP Scope Note: For the MVP, this method will simply clear the `ability_queue` array.
3.7. SceneManager.gd
Purpose: Manages all scene loading and transitions in response to EventBus signals.

Properties:
var scene_paths = {
    "Title": "res://scenes/Title.tscn",
    "Loadout": "res://scenes/Loadout.tscn",
    "Main": "res://scenes/Main.tscn"
}
var current_scene: Node

Methods:
_ready() -> void:
- Connects to scene change signals from EventBus: `loadout_scene_requested`, `main_scene_requested`.
- Loads the initial Title scene.

_on_loadout_scene_requested() -> void:
- Calls `_change_scene_to(scene_paths["Loadout"])`.

_on_main_scene_requested() -> void:
- Calls `_change_scene_to(scene_paths["Main"])`.

_change_scene_to(path: String) -> void:
- Frees the `current_scene`.
- Loads the new scene resource at `path`.
- Instantiates the scene and adds it as a child of the main SceneTree.
- Sets `current_scene` to the new instance.

3.8. UUIDUtils.gd
Purpose: A global utility for generating unique, descriptive, and debug-friendly string identifiers for all GachaBallInstances.

Implementation:
extends Node

func _ready() -> void:
    randomize()

# Generates a UUID, e.g., "unit_t1_a_1677628800_1234"
func generate_uuid(prefix: StringName) -> String:
    var timestamp = Time.get_unix_time_from_system()
    var random_suffix = randi() % 10000
    return "%s_%d_%d" % [prefix, timestamp, random_suffix]

4. Scene Blueprints & Node-by-Node Specification
4.1. Reusable UI Components (Views)
The project will use a single, versatile scene for all visual representations of GachaBall data:

**GachaBallView.tscn**: The primary visual element for any unit or item, whether it's on the board, in an inventory, or shown as an equipped item. Its root node is a PanelContainer with the GachaBallView.gd script attached. Its scene tree must contain:
- VBoxContainer
  - %Icon (TextureRect): Displays the main icon of the unit or item.
  - %ItemGrid (GridContainer): For units that can hold items, this container will be dynamically populated with other GachaBallView instances (configured to be non-interactive) representing the equipped items.
4.2. Main Scenes
Title.tscn & Loadout.tscn: Simple scenes with one button each that emit a signal to the EventBus.
Main.tscn: The persistent shell.
Node Tree: Main(Control) > %ContentArea(SubViewportContainer), %BottomArea(PanelContainer), %ModalLayer(CanvasLayer).
%BottomArea contains one "Inspect Inventory" button and three hidden "Draw Tier X" buttons.
PathChoice.tscn: Loaded into ContentArea. Contains one "Start Battle" button.
Battle.tscn: Loaded into ContentArea.
Node Tree: Battle(Node) > UI(Control), %ModalLayer(CanvasLayer).
UI contains Control nodes for PlayerLineup (6 empty Control placeholders) and PlayerBench (3 empty Control placeholders). It also contains a DiscardPileArea with "Discard Pile" and "Reshuffle" buttons.

4.4. Battle Setup (BattleManager.gd)
During the SETUP state, the BattleManager will:
- Create a _battle_inventory dictionary, structured by tier: {0: [], 1: [], 2: [], 3: []}
- Iterate through the GameManager.run_state.run_inventory dictionary, creating a battle copy of each instance and placing it into the corresponding tier of the new _battle_inventory
- Place each GachaBallView instance in the appropriate container (PlayerLineup or EnemyLineup)
- Instantiate GachaBallView instances for all units in the battle
- Position them in the appropriate placeholders
- Set up their initial state and connections
- Handle the "Start Battle" button press to transition to the ACTIVE state. This transient battle state (team, position) is stored on the visual GachaBallView node, not the data resource
- Place each GachaBallView instance in the appropriate container (PlayerLineup or EnemyLineup)

InspectInventoryView.tscn & DiscardPileView.tscn: Modal overlays with a ScrollContainer and a GridContainer. The grid will be dynamically populated with GachaBallView.tscn instances to display the contents of the RunInventory or DiscardPile respectively, not pre-filled with empty views.
ChoicePromptUI.tscn: A simple modal with "Merge" and "Swap" buttons.

4.5. Script and Scene Associations
To ensure clarity, the following core scripts are attached to their respective scene's root node:

*   **`GachaBallView.gd`**: This is a 'dumb' view component that handles only the visual representation of a GachaBall. It does not manage its own state or make decisions about game logic. The view receives updates from the BattleManager or GameManager and renders accordingly. Key characteristics:
    *   **Stateless**: Does not store or manage the GachaBallInstance data; it only displays what it's given.
    *   **Event Forwarder**: Forwards all input events to the parent manager (BattleManager/GameManager) for processing.
    *   **Visual Only**: Focuses solely on visual representation without any business logic.
    *   **Properties**:
        *   `instance_data: GachaBallInstance` (read-only, updated by parent manager)
        *   `is_interactable: bool` (set by parent manager)
        *   `is_highlighted: bool` (visual state, set by parent manager)
        *   `is_selected: bool` (visual state, set by parent manager)
    *   **Methods**:
        *   `update_display()`: Updates the visual representation based on current instance_data
        *   `_on_input_event(event)`: Forwards input to parent manager
        *   `play_animation(anim_name)`: Plays visual feedback animations
*   **`BattleManager.gd`**: This script is attached to the root `Node` of `Battle.tscn`. It manages the entire battle state, logic, and interaction flows.

4.6. Explicit Scene Node Naming and Layout
To ensure consistency, the following node names, text, and layout structures must be used. All scene files (`.tscn`) will be saved directly in `res://scenes/`.

*   **Title.tscn:** The primary button shall be named `%StartRunButton` and have its text set to "Start Run".
*   **Loadout.tscn:** The primary button shall be named `%BeginButton` and have its text set to "Begin".
*   **Main.tscn:** The buttons in the `%BottomArea` shall be named and configured as follows:
    *   `%InspectInventoryButton` (Button): Text "Inspect Inventory".
    *   `%DrawTier1Button` (Button): Text "Draw Tier 1". Initially hidden.
    *   `%DrawTier2Button` (Button): Text "Draw Tier 2". Initially hidden.
    *   `%DrawTier3Button` (Button): Text "Draw Tier 3". Initially hidden.
*   **Battle.tscn:**
    *   The `PlayerLineup` area will contain an `HBoxContainer` node holding 6 `Control` nodes as placeholders, named `%LineupSlot0` through `%LineupSlot5`.
    *   The `PlayerBench` area will contain an `HBoxContainer` node holding 3 `Control` nodes as placeholders, named `%BenchSlot0` through `%BenchSlot2`.

5. Detailed Input Handling & Interaction Model
This section explicitly defines the behavior for every possible user interaction.
Core Principle: The user can achieve the same result with two equivalent methods: Click-and-Click or Drag-and-Drop.
State: The InteractionManager holds _selected_view: GachaBallView = null.
Action: Player clicks on View_A (displaying an instance).
Behavior: If _selected_view is null, it becomes View_A, which shows "Selected" feedback. If _selected_view is already View_A, the selection is cancelled.
Action: With View_A selected, the player clicks on View_B.
Behavior: EventBus.inventory_action_requested(View_A, View_B) is emitted. The selection is cleared.
Action: Player drags View_A and drops it on View_B.
Behavior: EventBus.inventory_action_requested(View_A, View_B) is emitted.
Action: Player drags View_A.
Implementation: In View_A's script, _get_drag_data() calls set_drag_preview(self) and then sets self.visible = false. This makes the view itself follow the cursor, leaving its original spot empty. If the drag is cancelled, self.visible is set back to true.
**Modal Window Closing:** All modals are closed by pressing the 'Escape' key or by clicking their semi-transparent background. A "click" is defined as a mouse press or touch and release that occurs in the same general area. This action triggers a sequential behavior:
1. The modal is closed instantly.
2. A "phantom" click is programmatically sent to the exact screen coordinates of the original click, activating any UI element underneath.
This allows a user to close a modal and interact with the game behind it in a single, fluid action. This behavior does **not** trigger if the user clicks and then drags the mouse; this distinction prevents interference with the drag-and-drop system.

*Implementation Note:* This will be achieved using a `ColorRect` node for the modal background. Its `mouse_filter` property must be set to **`MOUSE_FILTER_STOP`** to intercept the click. Its script will connect to the `gui_input` signal. The function will detect a valid click (an `InputEventMouseButton` that is pressed and then released without significant mouse travel), at which point it will first emit `EventBus.close_modal_requested`, then immediately inject a new pair of mouse button press/release events at the click's global position using `Input.parse_input_event()`, and finally consume the original event to prevent duplicates.
6. Detailed Logic Flows & Behaviors
6.1. Gacha Draw Flow (in BattleManager.gd)
1. Receives `draw_gacha_requested(tier: int)` signal from EventBus.
2. If `_battle_inventory[tier]` is empty, calls `_reshuffle_tier_from_discard(tier)`.
3. If the tier's pool is still empty, the action fails silently.
4. Removes a random GachaBallInstance from the tier's pool in `_battle_inventory`.
5. Determines the first available empty placeholder on the PlayerBench, then the PlayerLineup.
6. If an empty placeholder is found:
   - Instantiates a new GachaBallView.tscn
   - Assigns the drawn GachaBallInstance data to the view
   - Places the new view as a child of the empty placeholder Control node
   - Updates the view to display the correct data
7. If no empty placeholder is found on the board, the drawn GachaBallInstance is added directly to the `_discard_pile` array.
6.2. Master Interaction Flow (in BattleManager.gd)
1. Receives `inventory_action_requested(source_view: Control, target_view: Control)` from EventBus.
2. Retrieves the GachaBallInstance data from both views.

3. Master Interaction Logic:
The BattleManager (or GameManager for the run inventory) will analyze the interaction based on the source and target views in a precise order:

**Case A: Interaction between two GachaBallView instances.**
- Retrieve instance_data from both source and target views.
- Check for Merge Possibility: Call MergeManager.find_recipe() with the definition IDs of the two instances.
  - If a valid recipe exists (Complex Interaction): The interaction is both a potential merge and a potential swap. Emit the EventBus.show_choice_prompt signal with the options "MERGE" and "SWAP". The manager will then wait for the EventBus.choice_made signal to execute the player's chosen action.
  - If no recipe exists: The action cannot be a merge. Proceed to check if it's a valid swap (e.g., both are units, or both are items). If it is a valid swap, execute the swap logic immediately. If not, treat it as an invalid action.

**Case B: Interaction between a GachaBallView and an empty placeholder Control node.**
- This is a Move operation. The GachaBallView's data does not change, but the view itself is moved to become a child of the target placeholder node, visually moving it on the board.

**Case C: Interaction between an Item GachaBallView and a Unit GachaBallView.**
- This is an Equip operation. Check the target unit's equipped_item_uuids data array for an empty slot. If found, update the data on both instances. Then, instantiate a new GachaBallView for the item, set its is_interactable property to false, and place it inside the target unit's %ItemGrid container. If the unit has no empty item slots, treat it as an invalid action.

**Design Note:** Unequipping an item by dragging it off a unit is intentionally not a feature in the MVP. Once an item is equipped, the player is committed to that choice. An item can only be moved to a new unit when its current wielder is used as an ingredient in a merge, at which point the item is transferred to the resulting merged unit. In case the unit is sent to the discard pile with the equipped items, in this case the unit and its equipped items are both sent to the discard pile separately.

**Case D: All other interactions.**
- These are considered an Invalid Action. Emit EventBus.invalid_action_triggered to provide feedback to the player.
6.3. Merge Logic
1. **Merge Trigger**
   - When two GachaBallInstances are dropped onto each other, the system checks for a valid merge recipe using `MergeManager.find_recipe()`
   - If a valid recipe exists, the merge process begins

2. **Merge Process** (handled by `MergeManager.attempt_merge()`)
   - **Validation**:
     - Verifies both instances belong to the same inventory (either both in RunInventory or both in BattleInventory)
     - Confirms the merge recipe is valid for the given instance types
   
   - **New Instance Creation**:
     - Creates a new GachaBallInstance using the recipe's result definition
     - Generates a new UUID for the merged instance
     - Sets the `origin_uuid` to maintain lineage (useful for battle copies)
   
   - **Item Transfer**:
     - Creates a temporary list of all GachaBallInstance objects representing the items equipped on both parent units.
     - The item instances themselves are not copied. They are re-assigned to the new merged unit. This is a critical design choice to ensure that any state changes an item accumulates during a battle (e.g., a "times equipped" counter, stat boosts) persist with that unique item instance for the duration of the battle.
     - The MergeManager will handle moving the data references from the parents' equipped_item_uuids arrays to the new unit's array.
   
   - **Inventory Update**:
     - Removes both parent instances from their source inventory
     - Adds the new merged instance to the same inventory
     - Equips items from the temporary list to the new instance, respecting its `item_slot_count`
   
   - **UI Update**:
     - Removes the visual representations of the parent units
     - Creates and positions a new GachaBallView for the merged unit
     - Updates any relevant UI elements to reflect the inventory changes

3. **Post-Merge Effects**
   - Emits appropriate signals for visual/audio feedback
   - Updates the game state if necessary
   - Triggers any post-merge abilities or effects

4. **Error Handling**:
   - If the merge fails at any point (invalid recipe, full inventory, etc.), the operation is rolled back
   - Provides appropriate feedback to the player
   - Ensures game state remains consistent