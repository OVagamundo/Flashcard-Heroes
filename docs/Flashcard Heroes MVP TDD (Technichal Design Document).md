Flashcard Heroes Core Mechanics MVP TDD v12.1 
1. Introduction & MVP Goal
1.1. Purpose
This document provides the complete and final technical blueprint for the "Core Mechanics MVP" of Flashcard Heroes. It is a self-contained specification designed to be followed precisely by a development agent. All required data, scene structures, script logic, and interaction flows are explicitly defined herein to eliminate ambiguity and assumptions. This document is the sole source of truth for the MVP.
### 1.2. Core Architectural Principles
This project is built on three key ideas to keep the code clean and easy to manage:

1.  **Separation of Data and View:**
    *   **Data (`GachaBallInstance`):** A `Resource` file holding all information about a unique GachaBall (ID, UUID, equipped items). It has no visual component.
    *   **View (`GachaBallView`):** A UI `Scene` that visually represents a `GachaBallInstance`. Its job is to display the data it is given.

2.  **Event-Driven Communication (`EventBus`):
    *   Systems communicate indirectly by emitting signals through the global `EventBus`. For example, a button emits `start_run_requested`, and the `GameManager` listens for it. This keeps all systems decoupled.

3.  **Contextual Data Persistence:**
    *   The game operates in two distinct data contexts. The interaction logic (how you merge/swap) is universal, but its effect depends on the context.
    *   **Run Context (Permanent):** Active outside of battle. All changes made to the `run_inventory` are saved for the duration of the run.
    *   **Battle Context (Temporary):** Active during a battle. All changes (merges, draws, discards) affect a temporary copy of the inventory and last only for the current battle.

1.3. Terminology Clarification
*   **Slot:** A conceptual, numbered position within an inventory's data array (e.g., `PlayerBench[0]`). This is a data-level concept used by the programmer.
*   **Zone:** A specific area of the UI with its own interaction rules (e.g., `PlayerLineup`, `PlayerBench`, `ItemInventory`, `InventoryModal`).
*   **GachaBallView:** The player-facing UI element. The player clicks on and drags `GachaBallView`s. When this view is not displaying any data, it will show a faint placeholder frame. When it is displaying data, it shows the GachaBall's icon and other information.
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

### 1.5. MVP User Journey
A developer using only this document will build an application where a player can:
*   **Navigate and Start:** Launch the game and start a run, creating a persistent `run_inventory`.
*   **Manage Inventories:** Open an `InventoryModal` to manage their collection. The modal's content and the permanence of actions depend on the game's context (Run vs. Battle). Both Run and Battle inventory modals are fully interactive workspaces.
*   **Enter Battle:** Start a battle, creating a temporary copy of the inventory for that battle.
*   **Build a Team:** Draw GachaBalls from the temporary battle inventory, which appear on the bench or item slots.
*   **Interact with the Board:** Use a universal Drag-and-Drop or Click-and-Click system to move, swap, equip, and merge GachaBalls according to strict zone-based rules.
*   **Merge & Swap:** When a valid merge is possible, the player is prompted to either "Merge" or "Swap". If no merge is possible, a swap occurs automatically.
*   **Inspect GachaBalls:** Use specific, context-aware inputs (simple click vs. long-press/double-click) to open an inspection window for any GachaBall.
*   **Manage Discard Pile:** View the contents of the discard pile in a read-only modal and reshuffle them back into the battle's draw pools.

2. Data Schemas & Definitions
These are the custom data structures for the project. They should be created as GDScript files inheriting from Resource.
2.1. GachaBallDefinition.gd (res://scripts/)
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

2.3. MergeRecipe.gd
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

2.4. FlashcardDeckDefinition.gd (res://scripts/)
Inherits: Resource, class_name FlashcardDeckDefinition
Purpose: This resource defines a collection of flashcards that will be used in the game's educational component.

Properties:
@export var id: StringName # Unique identifier for the deck.
@export var display_name_key: String # Localization key for the deck's display name.
@export var card_list: Array[Dictionary] # e.g., [{"question": "Q1", "answer": "A1"}]

2.5. MVP Data File Creation & Asset Convention

**Asset Placeholder Convention:** For this MVP, visual asset files (e.g., `.png`) are not provided. They will be generated during development as placeholder `ColorRect` textures or simple `StyleBoxFlat` resources. However, the `.tres` files will still point to the intended final asset paths as specified below (e.g., `res://assets/sprites/units/UnitTier1A.png`).

**Data Convention:** The following `.tres` files must be created with the exact property values listed in the tables below to ensure testability and consistency. The `id` and `display_name` are derived from the resource's filename.

**Table 2.5.1: GachaBallDefinition for Units & Hero**
| Filename          | `id` (StringName) | `display_name_key` (String) | `tier` (int) | `category` (StringName) | `item_slot_count` (int) | `icon` (Path)                            |
| :---------------- | :---------------- | :-------------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| `Hero.tres`       | `hero`            | "hero.name"                 | 0            | "UNIT"                  | 5                       | `res://assets/sprites/units/Hero.png`      |
| `UnitTier1A.tres` | `unit_t1_a`       | "unit_t1_a.name"            | 1            | "UNIT"                  | 1                       | `res://assets/sprites/units/UnitTier1A.png`|
| `UnitTier1B.tres` | `unit_t1_b`       | "unit_t1_b.name"            | 1            | "UNIT"                  | 1                       | `res://assets/sprites/units/UnitTier1B.png`|
| `UnitTier2C.tres` | `unit_t2_c`       | "unit_t2_c.name"            | 2            | "UNIT"                  | 2                       | `res://assets/sprites/units/UnitTier2C.png`|
| `UnitTier3D.tres` | `unit_t3_d`       | "unit_t3_d.name"            | 3            | "UNIT"                  | 4                       | `res://assets/sprites/units/UnitTier3D.png`|

**Table 2.5.2: GachaBallDefinition for Items**
| Filename          | `id` (StringName) | `display_name_key` (String) | `tier` (int) | `category` (StringName) | `item_slot_count` (int) | `icon` (Path)                            |
| :---------------- | :---------------- | :-------------------------- | :----------- | :---------------------- | :---------------------- | :--------------------------------------- |
| `ItemTier1A.tres` | `item_t1_a`       | "item_t1_a.name"            | 1            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier1A.png`|
| `ItemTier1B.tres` | `item_t1_b`       | "item_t1_b.name"            | 1            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier1B.png`|
| `ItemTier2C.tres` | `item_t2_c`       | "item_t2_c.name"            | 2            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier2C.png`|
| `ItemTier3D.tres` | `item_t3_d`       | "item_t3_d.name"            | 3            | "ITEM"                  | 0                       | `res://assets/sprites/items/ItemTier3D.png`|

**Table 2.5.3: MergeRecipe Data**
| Filename                   | `ingredient_a_id` | `ingredient_b_id` | `result_id` | `is_self_merge` | `merge_type` |
| :------------------------- | :---------------- | :---------------- | :---------- | :-------------- | :----------- |
| `Merge_Unit_A_B_to_C.tres` | `unit_t1_a`       | `unit_t1_b`       | `unit_t2_c` | `false`         | "UNIT"       |
| `Merge_Unit_C_C_to_D.tres` | `unit_t2_c`       | `unit_t2_c`       | `unit_t3_d` | `true`          | "UNIT"       |
| `Merge_Item_A_B_to_C.tres` | `item_t1_a`       | `item_t1_b`       | `item_t2_c` | `false`         | "ITEM"       |
| `Merge_Item_C_C_to_D.tres` | `item_t2_c`       | `item_t2_c`       | `item_t3_d` | `true`          | "ITEM"       |

2.6. RunState.gd (res://scripts/)
Inherits: Resource, class_name RunState
Purpose: Holds the entire persistent state for a player's run. It is created by the GameManager at the start of a run and contains the inventory and other progress markers.

Properties:
@export var gold: int
@export var current_stage: int
@export var current_battle: int
@export var run_inventory: Dictionary # Tiered inventory: {0:[], 1:[], 2:[], 3:[]}

Methods:
start_new_run(): Initializes all properties to their starting values (e.g., gold=10, stage=1). It clears the `run_inventory` dictionary and then populates it with the starting set of GachaBallInstances as defined in Section 3.3.

2.7. ConditionDefinition.gd (res://scripts/)
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
Purpose: Manages the persistent state of the current run by creating and holding the `RunState` resource. It handles permanent inventory actions by delegating to the MergeManager.

Properties:
run_state: RunState  # The single source of truth for the current run's state.
is_inspecting_inventory: bool = false

Signals:
run_inventory_changed() # Emitted after a permanent merge or swap occurs.

Methods:
_ready() -> void:
- Connects to EventBus.start_run_requested.
- Connects to EventBus.inspect_inventory_requested to set its state.
- Connects to EventBus.close_modal_requested to clear its state.
- Connects to EventBus.inventory_action_requested to handle permanent merges/swaps.

_on_start_run_requested() -> void:
- Creates a new `RunState` resource instance.
- Calls `run_state.start_new_run()` to populate the initial inventory.
- Emits `run_inventory_changed`.
- Emits `main_scene_requested`.

_on_inventory_action_requested(source_view: Control, target_view: Control) -> void:
- This function only proceeds if `is_inspecting_inventory` is true.
- It retrieves the GachaBallInstance data from both the source and target views.
- It delegates the merge logic to `MergeManager.attempt_merge(source_data, target_data, self.run_state.run_inventory)`.
- If the merge is successful, it emits `run_inventory_changed`.
- If the merge fails (returns null), it performs a swap of the two instances within the `run_state.run_inventory` tiered dictionary.
- After a successful swap, it emits `run_inventory_changed`.
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

**GachaBallView.tscn**: The primary visual element for any unit or item. This single, reusable scene is instanced everywhere a GachaBall needs to be represented.
- **Design Principle:** The `GachaBallView.tscn` is always the same. There are no different versions for inventories or equipped items. A parent manager (like `BattleManager`) may dynamically change properties of an instance, such as its `custom_minimum_size` or `is_interactable` flag, for layout purposes (e.g., to make equipped item icons appear smaller), but it is always the same base scene being used.
- **Scene Tree:** Its root node is a PanelContainer with the `GachaBallView.gd` script attached. Its tree must contain:
  - VBoxContainer
    - %Icon (TextureRect): Displays the main icon of the unit or item.
    - %ItemGrid (GridContainer): For units, this is dynamically populated with `GachaBallView` instances representing equipped items.
4.2. Main Scenes
Title.tscn & Loadout.tscn: Simple scenes with one button each that emit a signal to the EventBus.
Main.tscn: The persistent shell.
Node Tree: Main(Control) > %ContentArea(SubViewportContainer), %BottomArea(PanelContainer), %ModalLayer(CanvasLayer).
%BottomArea contains one "Inspect Inventory" button and three hidden "Draw Tier X" buttons.
PathChoice.tscn: Loaded into ContentArea. Contains one "Start Battle" button.
Battle.tscn: Loaded into ContentArea.
Node Tree: Battle(Node) > UI(Control), %ModalLayer(CanvasLayer).
UI contains Control nodes for PlayerLineup (6 empty Control placeholders) and PlayerBench (3 empty Control placeholders). It also contains a DiscardPileArea with "Discard Pile" and "Reshuffle" buttons.

### 4.4. Battle Board Zone Rules
The containers within `Battle.tscn` define the primary interaction zones, each with strict rules governing its contents.

*   **`%PlayerLineup` (`ZONE_LINEUP`):** Can **only** contain GachaBalls of category "UNIT".
*   **`%PlayerBench` (`ZONE_BENCH`):** Can **only** contain GachaBalls of category "UNIT".
*   **`ItemInventory` (`ZONE_ITEM_INV`):** Can **only** contain GachaBalls of category "ITEM".
*   **`EnemyLineup` (`ZONE_ENEMY_LINEUP`):** For the MVP, this zone is non-interactive for the player. Any attempt to drag a player view to this zone is an invalid action.

During the SETUP state, the BattleManager will create a temporary `_battle_inventory` (a master list for the battle) and `_draw_pools` (a consumable gacha inventory) by creating battle copies of every instance in the `GameManager.run_state.run_inventory`.
- Instantiate GachaBallView instances for all units in the battle
- Position them in the appropriate placeholders
- Set up their initial state and connections
- Handle the "Start Battle" button press to transition to the ACTIVE state. This transient battle state (team, position) is stored on the visual GachaBallView node, not the data resource



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
## 6. Detailed Logic Flows & Behaviors

### 6.1. Gacha Draw Flow (in BattleManager.gd)
1.  Receives `draw_gacha_requested(tier: int)`.
2.  Removes a random GachaBallInstance from the `_draw_pools[tier]`.
3.  Emits `battle_inventory_changed` to notify the UI that the pools have changed.
4.  Finds the first available empty slot in the appropriate zone (`PlayerBench`/`PlayerLineup` for Units, `ItemInventory` for Items).
5.  If a slot is found, places the new view there. If not, the instance is added to the `_discard_pile`.

### 6.2. Master Interaction Flow (The Unified Handler)
This logic is implemented in both `GameManager` and `BattleManager` to handle the `inventory_action_requested` signal, ensuring consistent behavior based on zones.

**Pre-Check:** The system first determines the **Zone** of the source and target views. If the zones are different (e.g., Board to Modal) or invalid for the interaction (e.g., Player to Enemy), the action is rejected.

**Case A: Moving to an Empty Slot**
*   This is a **Move** operation.
*   **Validation:** The system checks if the source GachaBall's category ("UNIT" or "ITEM") is allowed in the target slot's zone.
*   **Outcome:** If valid, the view is moved. If invalid (e.g., moving a Unit to an Item slot), it's an invalid action.

**Case B: View on View**
*   **Equip Check (Board Only):** If the source is an "ITEM" from the `ItemInventory` zone and the target is a "UNIT" in the `PlayerLineup` or `PlayerBench` zone, it is processed as an **Equip** action. This check takes precedence over the merge/swap logic.
*   **Merge/Swap Logic:** If it's not an equip action, the universal "Merge > Prompt > Swap" flow is triggered.

**Design Note on Unequipping:** Unequipping an item by dragging it off a unit is intentionally not a feature in the MVP. Once an item is equipped, the player is committed to that choice. An item can only be moved to a new unit when its current wielder is used as an ingredient in a merge, at which point the item is transferred to the resulting merged unit.

*   **Inside a Modal (`RunInventory` or `BattleInventory`):** The data is updated in the corresponding inventory dictionary (`run_inventory` or `_battle_inventory` + `_draw_pools`). The modal then refreshes itself automatically by listening to the `run_inventory_changed` or `battle_inventory_changed` signal, showing the new unit in its correct tier.

#### 6.3.2. Merge Process (Inside `MergeManager.attempt_merge`)
1.  **Validation:** Confirms both instances belong to the same inventory context and that a valid recipe exists.
2.  **New Instance Creation:** Creates a new `GachaBallInstance` based on the recipe's result definition and generates a new UUID.
3.  **Item Transfer:** Creates a temporary list of all `GachaBallInstance` objects representing the items equipped on both parent units. The item instances themselves are **not copied**; they are re-assigned to the new merged unit to preserve any battle-specific state they may have accumulated.
4.  **Inventory Update:** Removes both parent instances and all their transferred items from the source inventory/inventories. Then adds the new merged instance and re-adds the transferred items back into the inventory, now linked to the new unit.