Technical Design Document: Flashcard Heroes
Version: 2.0
Target Engine: Godot 4.4
Primary Language: GDScript
This document provides a complete technical blueprint for the development of "Flashcard Heroes." It is designed to be followed precisely by a development agent, ensuring architectural integrity and adherence to the Game Design Document (GDD) with zero assumptions.
1. System Architecture Diagram
This diagram illustrates the high-level architecture, emphasizing the decoupled nature of the core systems managed by autoloaded singletons and the precise flow of data and events.
graph TD
    subgraph "Engine & User"
        UserInput[User Input]
        Godot[Godot Engine]
    end

    subgraph "Data Layer (Resources)"
        GachaBallDefs[GachaBallDefinition.tres]
        AbilityDefs[AbilityDefinition.tres]
        StatusEffectDefs[StatusEffectDefinition.tres]
        FlashcardDeckDefs[FlashcardDeckDefinition.tres]
        EnemyEncounterDefs[EnemyEncounterDefinition.tres]
    end

    subgraph "Autoloaded Singletons (Core Systems)"
        EventBus[EventBus.gd]
        Database[Database.gd]
        SceneManager[SceneManager.gd]
        GameManager[GameManager.gd]
        SaveManager[SaveManager.gd]
    end

    subgraph "Scenes & UI Components"
        TitleScene[Title.tscn]
        MainScene[Main.tscn]
        TopBar[TopBar.tscn]
        BottomBar[BottomBar.tscn]
        BattleScene[Battle.tscn]
        subgraph Battle.tscn
            BattleManager[BattleManager.gd]
        end
        PathChoiceScene[PathChoice.tscn]
        GachaPoolInspection[GachaPoolInspection.tscn]
        UnitDisplay[UnitDisplay.tscn]
    end

    %% Data Flow on Startup
    Godot -- "Loads on Startup" --> Database
    Database -- "Scans & Caches" --> GachaBallDefs & AbilityDefs & StatusEffectDefs & FlashcardDeckDefs & EnemyEncounterDefs

    %% Event-Driven Communication Flow (Decoupled)
    UserInput --> TitleScene & PathChoiceScene & BattleScene & GachaPoolInspection
    TitleScene & PathChoiceScene & BattleScene -- "Emits Signals" --> EventBus
    EventBus -- "Broadcasts Signals" --> GameManager & SceneManager & BattleManager & TopBar & BottomBar
    GameManager -- "Emits State Change Signals" --> EventBus
    BattleManager -- "Emits Battle State Signals" --> EventBus
    SaveManager -- "Listens for Save/Load Requests" --> EventBus
    SceneManager -- "Listens for Scene Change Requests" --> EventBus

    %% Scene Management Flow
    SceneManager -- "Loads/Unloads Scenes" --> MainScene
    MainScene -- "Contains" --> TopBar & BottomBar
    MainScene -- "Hosts Overlays" --> GachaPoolInspection
    SceneManager -- "Loads Into Dynamic Area" --> PathChoiceScene & BattleScene

    %% Battle Initialization Flow
    PathChoiceScene -- "1. battle_start_requested" --> EventBus
    EventBus -- "2. " --> GameManager
    GameManager -- "3. Prepares Data"
    GameManager -- "4. load_scene_in_container_requested" --> EventBus
    GameManager -- "5. initiate_battle(data)" --> EventBus
    EventBus -- "6. " --> SceneManager & BattleManager

    %% Data Access (Direct Read)
    GameManager -- "Requests Definitions" --> Database
    BattleManager -- "Requests Definitions" --> Database
Use code with caution.
Mermaid
2. Autoloaded Scripts (Singletons)
These scripts are configured in Project -> Project Settings -> Autoload to be globally accessible.
2.1. EventBus.gd
Purpose: A global, decoupled message-passing system. All communication between managers and scenes MUST go through the EventBus.
Properties: None.
Methods: None.
Signals:
Game Flow & State:
new_run_requested(hero_def_id: StringName, deck_def_id: StringName): Emitted from the UI to start a new game.
run_started(): Emitted by GameManager when a new run is successfully initialized.
run_ended(was_victory: bool): Emitted by GameManager when a run concludes.
save_run_requested(): Emitted to trigger a save operation.
load_run_requested(): Emitted to trigger a load operation.
Scene Management:
change_scene_to_file_requested(scene_path: String): Requests a full scene transition.
load_scene_in_container_requested(scene_path: String, container: Node): Requests a scene be loaded as a child of a specific container node.
Player State & Resources:
gold_updated(new_total: int): Emitted when the player's gold changes.
hero_hp_updated(current_hp: int, base_hp: int): Emitted when the hero's HP changes.
day_updated(new_day: int): Emitted when the day counter increments.
master_pool_changed(): Emitted when a GachaBallInstance is added to or removed from the GameManager's master pool.
trinkets_updated(active_trinkets: Array[TrinketDefinition]): Emitted by GameManager when trinkets are added or removed.
Battle & Turn Management:
battle_start_requested(encounter_definition: EnemyEncounterDefinition): Emitted from a node (e.g., PathChoice) to initiate a battle with a specific enemy setup.
initiate_battle(battle_setup_data: Dictionary): Emitted by GameManager after it has prepared all necessary temporary data for a battle. BattleManager listens for this to begin its setup.
battle_started(): Emitted by BattleManager when its setup is complete and the battle can begin.
battle_won(): Emitted by BattleManager on victory.
battle_lost(): Emitted by GameManager on defeat.
turn_phase_changed(new_phase: StringName): Emitted by BattleManager to signal a change in the battle phase (e.g., "MANAGEMENT", "COMBAT").
gacha_tokens_updated(new_total: int): Emitted when the player's temporary Gacha Tokens change.
draw_gacha_request(tier: int): Emitted by GachaMachine.tscn UI to request a draw.
unit_defeated(unit_uuid: String, is_enemy: bool): Emitted by BattleManager when a unit's HP reaches zero.
end_turn_button_pressed(): Emitted by the UI to end the Management Phase.
2.2. Database.gd
Purpose: A central, read-only repository for all game content defined as Resource files. It loads all content on startup.
Properties:
gachaball_definitions: Dictionary = {}
ability_definitions: Dictionary = {}
status_effect_definitions: Dictionary = {}
flashcard_deck_definitions: Dictionary = {}
enemy_encounter_definitions: Dictionary = {}
Methods:
_ready() -> void: Calls _load_resources_from_path() for each content type directory (e.g., "res://data/gachaballs/", "res://data/encounters/").
_load_resources_from_path(path: String, target_dictionary: Dictionary) -> void: Iterates all .tres files in the given path, loads each resource, and stores it in target_dictionary using the resource's id property as the key. Logs an error and skips if a duplicate id is found.
get_gachaball_definition(id: StringName) -> GachaBallDefinition: Returns the definition from the dictionary.
(... other get methods for each definition type ...)
2.3. SceneManager.gd
Purpose: Manages all scene loading, unloading, and transitions by listening to the EventBus.
Properties:
_current_scene: Node: A reference to the currently active main scene node.
Methods:
_ready() -> void: Connects to EventBus.change_scene_to_file_requested and EventBus.load_scene_in_container_requested.
_on_change_scene_to_file_requested(scene_path: String) -> void: If _current_scene is valid, it is freed. Then, loads and instantiates the new scene from scene_path, adds it to the tree root, and updates _current_scene.
_on_load_scene_in_container_requested(scene_path: String, container: Node) -> void: Frees all existing children of the container node. Then loads, instantiates, and adds the new scene as a child of container.
2.4. SaveManager.gd
Purpose: Handles serialization and deserialization of run data.
Constants: RUN_SAVE_PATH = "user://run_save.json"
Methods:
_ready() -> void: Connects to EventBus.save_run_requested and EventBus.load_run_requested.
_on_save_run_requested() -> void: Calls GameManager.package_run_data() to get the current run state as a dictionary, then calls save_run() with that data.
_on_load_run_requested() -> void: Calls load_run() and passes the resulting dictionary to a new method on GameManager, e.g., GameManager.reconstruct_run_from_data(data).
save_run(run_data: Dictionary) -> void: Converts run_data to JSON and saves to RUN_SAVE_PATH.
load_run() -> Dictionary: Loads and parses JSON from RUN_SAVE_PATH. Returns an empty Dictionary if the file is not found or is invalid.
has_saved_run() -> bool: Returns FileAccess.file_exists(RUN_SAVE_PATH).
2.5. GameManager.gd
Purpose: The single source of truth for the state of the current run. Manages the run lifecycle and persists data between scenes.
FSM States: NO_RUN, IN_RUN, AWAITING_BATTLE_RESULT, GAME_OVER.
Properties:
_state: StringName = "NO_RUN"
current_day: int
gold: int
hero_instance: GachaBallInstance
master_run_gacha_pool: Dictionary = {1: [], 2: [], 3: []}
active_trinkets: Array[TrinketDefinition]
(... other run-persistent properties from GDD ...)
Methods:
_ready() -> void: Connects to EventBus.new_run_requested, EventBus.battle_start_requested, EventBus.battle_won, EventBus.battle_lost.
_on_new_run_requested(hero_def_id: StringName, deck_def_id: StringName) -> void: Initializes a new run, sets _state to IN_RUN, emits run_started(), and requests SceneManager to load Main.tscn.
_on_battle_start_requested(encounter_definition: EnemyEncounterDefinition) -> void:
Transitions _state to AWAITING_BATTLE_RESULT.
Calls _prepare_battle_data(encounter_definition) to get the setup dictionary.
Emits EventBus.load_scene_in_container_requested("res://scenes/battle/Battle.tscn", get_tree().get_first_node_in_group("dynamic_content_area")).
Emits EventBus.initiate_battle(battle_data).
_prepare_battle_data(encounter_def: EnemyEncounterDefinition) -> Dictionary:
Creates a deep copy of hero_instance.
Creates deep copies of all GachaBallInstances in master_run_gacha_pool.
Returns a dictionary: {"player_hero": hero_copy, "player_pool": pool_copies, "encounter_def": encounter_def}.
_on_battle_won() -> void: Transitions _state back to IN_RUN, increments current_day, adds reward gold, emits update signals, and requests SceneManager to load PathChoice.tscn.
_on_battle_lost() -> void: Sets _state to GAME_OVER, emits run_ended(false).
package_run_data() -> Dictionary: Serializes the entire run state into a dictionary of primitive types and resource paths. For each GachaBallInstance, it saves its definition_id, ball_uuid, instance_specific_modifiers, and current_hp (for hero only).
3. Core Data Structures (Resource Definitions)
3.1. GachaBallDefinition.gd
File Path: res://scripts/data/definitions/GachaBallDefinition.gd
Inherits: Resource, class_name GachaBallDefinition
Enums: enum Category { UNIT, ITEM }, enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, HERO }
@export Variables:
@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export var icon_texture: Texture2D
@export var tier: int
@export var rarity: Rarity
@export var ball_category: Category
@export_group("Unit Stats")
@export var base_hp: int
@export var base_pwr: int
@export var ability_definition_refs: Array[AbilityDefinition]
@export var item_slot_count: int
@export_group("Item Stats")
@export var is_equippable: bool
3.2. GachaBallInstance.gd
File Path: res://scripts/data/instances/GachaBallInstance.gd
Inherits: Resource, class_name GachaBallInstance
Enums: enum LocationState { UNDEFINED, IN_MASTER_POOL, IN_BATTLE_POOL, IN_BATTLE_DISCARD, IN_PLAYER_BENCH, IN_PLAYER_LINEUP, IN_PLAYER_INVENTORY, EQUIPPED_ON_UNIT }
Properties:
definition_id: StringName
ball_uuid: String
current_hp: int
current_pwr: int
equipped_item_uuids: Array[String]
current_location_state: LocationState = LocationState.UNDEFINED
Methods:
initialize(def: GachaBallDefinition) -> void: Sets properties from the definition (definition_id, current_hp, current_pwr). Generates a unique ID using self.ball_uuid = UUID.v4().
deep_copy() -> GachaBallInstance: Creates a new GachaBallInstance, calls initialize with its own definition, and copies all current property values (ball_uuid, current_hp, etc.) to the new instance. Returns the new instance.
3.3. EnemyEncounterDefinition.gd
File Path: res://scripts/data/definitions/EnemyEncounterDefinition.gd
Inherits: Resource, class_name EnemyEncounterDefinition
@export Variables:
@export var id: StringName
@export var enemy_units: Array[GachaBallDefinition]
@export var enemy_trinkets: Array[TrinketDefinition]
(Other definitions like AbilityDefinition.gd, StatusEffectDefinition.gd, FlashcardDeckDefinition.gd, TrinketDefinition.gd follow a similar structure with relevant @export variables as per the GDD.)
4. Scene & Component Specifications
4.1. Title.tscn
Purpose: Initial entry point. Offers new game or continue options.
Node Tree: Control > VBoxContainer > Label (Title), Button (NewGameButton), Button (ContinueButton)
Script Logic (Title.gd):
_ready(): Checks SaveManager.has_saved_run() and sets ContinueButton.disabled accordingly.
NewGameButton.pressed: Emits EventBus.new_run_requested() with hardcoded starter hero/deck IDs.
ContinueButton.pressed: Emits EventBus.load_run_requested().
4.2. Main.tscn
Purpose: The persistent game shell holding UI bars and the dynamic content area.
Node Tree: Control (Root) > VBoxContainer > TopBar.tscn, Control (Name: DynamicContentArea, Group: "dynamic_content_area", V-Size Flags: "Expand Fill"), BottomBar.tscn
Script Logic (Main.gd):
_ready(): Emits EventBus.load_scene_in_container_requested("res://scenes/path/PathChoice.tscn", $VBoxContainer/DynamicContentArea).
4.3. TopBar.tscn & BottomBar.tscn
Purpose: Display persistent run information and Gacha machines.
Script Logic: Connect to relevant EventBus signals (hero_hp_updated, gold_updated, gacha_tokens_updated, etc.) in _ready() to update their respective Label nodes.
4.4. PathChoice.tscn
Purpose: Presents the player with the next node choice.
Node Tree: Control > HBoxContainer > Button (BattleNodeButton)
Script Logic (PathChoice.gd):
@export var encounter_definition: EnemyEncounterDefinition: This is linked in the Inspector to a specific .tres file.
_ready(): Connects BattleNodeButton.pressed to _on_battle_node_button_pressed.
_on_battle_node_button_pressed() -> void: Emits EventBus.battle_start_requested(encounter_definition).
4.5. Battle.tscn
Purpose: The main combat scene.
Node Tree: Control (Root) > BattleManager (Node), VBoxContainer > [EnemySideUI], [PlayerSideUI], Button (EndTurnButton)
EnemySideUI: Contains HBoxContainer (Name: EnemyLineup).
PlayerSideUI: Contains HBoxContainer (Name: PlayerLineup), HBoxContainer (Name: PlayerBench, 3 slots), HBoxContainer (Name: PlayerInventory, 3 slots).
Script Logic (BattleManager.gd):
FSM States: IDLE, SETUP, START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, VICTORY, DEFEAT.
Properties: _battle_gacha_pools: Dictionary, _battle_discard_pile: Array, _gacha_tokens: int.
_ready(): Connect to EventBus.initiate_battle, EventBus.draw_gacha_request, EventBus.end_turn_button_pressed.
SETUP State Logic:
Triggered by the _on_initiate_battle(battle_setup_data: Dictionary) handler.
Steps:
Clear all previous battle state (lineups, pools, discard).
Populate _battle_gacha_pools with the deep-copied instances from battle_setup_data["player_pool"]. Set their current_location_state to IN_BATTLE_POOL.
Instantiate UnitDisplay.tscn for each enemy unit defined in battle_setup_data["encounter_def"] and add to the EnemyLineup container.
Instantiate a UnitDisplay.tscn for the player hero from battle_setup_data["player_hero"] and add to the PlayerLineup. Set its current_location_state to IN_PLAYER_LINEUP.
Emit EventBus.battle_started().
Transition FSM to START_OF_TURN.
Draw Logic (_on_draw_gacha_request):
Check for sufficient _gacha_tokens.
Draw an instance from the correct _battle_gacha_pools tier.
If drawn instance is a UNIT: Attempt to place on PlayerBench. If full, attempt to place in PlayerLineup. If both are full, set its current_location_state to IN_BATTLE_DISCARD and add to _battle_discard_pile.
If drawn instance is an ITEM: Attempt to place in PlayerInventory. If full, set its current_location_state to IN_BATTLE_DISCARD and add to _battle_discard_pile.
Update the current_location_state of the drawn instance accordingly.
Unit Defeat Logic:
When a unit's HP reaches 0, emit EventBus.unit_defeated(unit.ball_uuid, is_enemy).
Iterate the defeated unit's equipped items, change their current_location_state to IN_BATTLE_DISCARD, and add them to the _battle_discard_pile.
Clear the defeated unit's equipped_item_uuids array.
Change the defeated unit's current_location_state to IN_BATTLE_DISCARD and add it to the _battle_discard_pile.
The Battle.tscn scene script listens for unit_defeated and removes the corresponding UnitDisplay node from the scene tree.
4.6. GachaPoolInspection.tscn
Purpose: A modal overlay to inspect a Gacha Machine's contents. Closes on an outside click.
Node Tree: Control (Root, Name: ClickCatcher) > PanelContainer (Name: ModalWindow) > ... > GridContainer (GachaGrid)
Script Logic (GachaPoolInspection.gd):
The root ClickCatcher node has its Mouse Filter set to Stop.
The ModalWindow PanelContainer has its Mouse Filter set to Ignore.
Implement _gui_input(event: InputEvent) on the root node:
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.is_pressed():
        var modal_window = $ModalWindow
        if not modal_window.get_global_rect().has_point(event.global_position):
            queue_free()
Use code with caution.
Gdscript
4.7. UnitDisplay.tscn
Purpose: Reusable scene to visually represent a GachaBallInstance.
Node Tree: PanelContainer > VBoxContainer > TextureRect (Icon), Label (HP), Label (PWR)
Script Logic (UnitDisplay.gd):
instance_data: GachaBallInstance
display_instance(inst: GachaBallInstance) -> void: Stores inst in instance_data and updates UI labels (HP, PWR) and TextureRect from the instance's data.
update_stats() -> void: Refreshes the HP and PWR labels from instance_data. This can be called via signals when stats change.