Flashcard Heroes TDD v3.0 (Complete and Final)
Technical Design Document: Flashcard Heroes
Version: 3.0
Target Engine: Godot 4.4
Primary Language: GDScript
This document provides a complete technical blueprint for the development of "Flashcard Heroes." It is designed to be followed precisely by a development agent, ensuring architectural integrity and adherence to the Game Design Document (GDD) with zero assumptions.

### 1. System Architecture Diagram
This diagram illustrates the high-level architecture, emphasizing the decoupled nature of the core systems managed by autoloaded singletons and the precise flow of data and events.
```mermaid
graph TD
    subgraph "Engine & User"
        UserInput[User Input]
        Godot[Godot Engine]
    end

    subgraph "Data Layer (Resources)"
        GachaBallDefs[GachaBallDefinition.tres]
        AbilityDefs[AbilityDefinition.tres]
        ConditionDefs[ConditionDefinition.tres]
        EffectDefs[EffectDefinition.tres]
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
        AbilityResolver[AbilityResolver.gd]
    end

    subgraph "Scenes & UI Components"
        TitleScene[Title.tscn]
        MainScene[Main.tscn]
        TopArea[TopArea.tscn]
        BottomArea[BottomArea.tscn]
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
    Database -- "Scans & Caches" --> GachaBallDefs & AbilityDefs & ConditionDefs & EffectDefs & StatusEffectDefs & FlashcardDeckDefs & EnemyEncounterDefs

    %% Event-Driven Communication Flow (Decoupled)
    UserInput --> TitleScene & PathChoiceScene & BattleScene & GachaPoolInspection
    TitleScene & PathChoiceScene & BattleScene & BattleManager -- "Emits Signals" --> EventBus
    EventBus -- "Broadcasts Signals" --> GameManager & SceneManager & BattleManager & AbilityResolver & TopArea & BottomArea
    GameManager -- "Emits State Change Signals" --> EventBus
    SaveManager -- "Listens for Save/Load Requests" --> EventBus
    SceneManager -- "Listens for Scene Change Requests" --> EventBus
    AbilityResolver -- "Listens for Game Events" --> EventBus

    %% Scene Management Flow
    SceneManager -- "Loads/Unloads Scenes" --> MainScene
    MainScene -- "Contains" --> TopArea & BottomArea
    MainScene -- "Hosts Overlays" --> GachaPoolInspection
    SceneManager -- "Loads Into Dynamic Area" --> PathChoiceScene & BattleScene

    %% Battle Initialization Flow
    PathChoiceScene -- "1. battle_start_requested" --> EventBus
    EventBus -- "2. " --> GameManager
    GameManager -- "3. Prepares Data"
    GameManager -- "4. load_scene_in_container_requested" --> EventBus
    GameManager -- "5. initiate_battle(data)" --> EventBus
    EventBus -- "6. " --> SceneManager & BattleManager

    %% Data Access
    GameManager -- "Requests Definitions" --> Database
    BattleManager -- "Requests Definitions" --> Database
    AbilityResolver -- "Requests Data from" --> BattleManager
Use code with caution.
Markdown
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
run_inventory_changed(): Emitted when a GachaBallInstance is added to or removed from the GameManager's run_inventory.
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
end_turn_button_pressed(): Emitted by the UI to end the Management Phase.
merge_units_requested(unit_a_uuid: String, unit_b_uuid: String): Emitted from the UI when the player attempts to merge two units.
equip_item_requested(item_uuid: String, target_unit_uuid: String): Emitted from the UI when the player attempts to equip an item onto a unit.
Ability System Triggers:
turn_started(): Emitted by BattleManager at the start of the turn phase.
turn_ended(): Emitted by BattleManager at the end of the turn phase.
unit_performed_attack(attacker_instance: GachaBallInstance, target_instance: GachaBallInstance): Emitted by a unit's logic when it performs its primary attack action.
unit_took_damage(attacker_instance: GachaBallInstance, defender_instance: GachaBallInstance, damage_amount: int): Emitted by a unit's logic whenever it receives damage.
unit_was_merged(merged_unit_instance: GachaBallInstance): Emitted by BattleManager when a unit is created as the result of a merge.
unit_defeated(unit_uuid: String, is_enemy: bool): Emitted by BattleManager when a unit's HP reaches zero.
2.2. Database.gd
Purpose: A central, read-only repository for all game content defined as Resource files. It loads all content on startup.
Properties:
gachaball_definitions: Dictionary = {}
ability_definitions: Dictionary = {}
status_effect_definitions: Dictionary = {}
flashcard_deck_definitions: Dictionary = {}
enemy_encounter_definitions: Dictionary = {}
merge_recipes: Dictionary = {}
trinket_definitions: Dictionary = {}
synergy_definitions: Dictionary = {}
Methods:
_ready() -> void: Calls _load_resources_from_path() for each content type directory, including the new definition types (MergeRecipe, TrinketDefinition, SynergyDefinition).
_load_resources_from_path(path: String, target_dictionary: Dictionary) -> void: Iterates all .tres files in the given path, loads each resource, and stores it in target_dictionary using the resource's id property as the key.
get_gachaball_definition(id: StringName) -> GachaBallDefinition: Returns the definition from the dictionary.
(... other get methods for each definition type ...)
2.3. SceneManager.gd
Purpose: Manages all scene loading, unloading, and transitions by listening to the EventBus.
Properties:
_current_scene: Node: A reference to the currently active main scene node.
Methods:
_ready() -> void: Connects to EventBus.change_scene_to_file_requested and EventBus.load_scene_in_container_requested.
_on_change_scene_to_file_requested(scene_path: String) -> void: Frees _current_scene, then loads and adds the new scene to the tree root.
_on_load_scene_in_container_requested(scene_path: String, container: Node) -> void: Frees all existing children of the container, then loads and adds the new scene as a child of container.
2.4. SaveManager.gd
Purpose: Handles serialization and deserialization of run data.
Constants:
RUN_SAVE_PATH = "user://run_save.json"
META_SAVE_PATH = "user://meta_save.json"
Methods:
_ready() -> void: Connects to EventBus.save_run_requested and EventBus.load_run_requested.
_on_save_run_requested() -> void: Calls GameManager.package_run_data() to get the current run state, then calls save_run() with that data.
_on_load_run_requested() -> void:
Call load_run() to get the saved data dictionary.
Validate the loaded data structure.
Call GameManager.reconstruct_run_from_data(data).
The GameManager is now responsible for re-emitting all state signals (e.g., gold_updated, hero_hp_updated) with the loaded values.
The GameManager will then request the SceneManager to load the appropriate scene.
save_run(run_data: Dictionary) -> void: Converts run_data to JSON and saves to RUN_SAVE_PATH.
load_run() -> Dictionary: Loads and parses JSON from RUN_SAVE_PATH.
has_saved_run() -> bool: Returns FileAccess.file_exists(RUN_SAVE_PATH).
save_meta_data(data: Dictionary) -> void: Saves meta-progression data to META_SAVE_PATH.
load_meta_data() -> Dictionary: Loads and parses meta-progression data from META_SAVE_PATH.
2.5. AbilityResolver.gd
Purpose: A global singleton that acts as the central hub for processing all triggered abilities and effects. It listens for game events from the EventBus, checks all active game entities for abilities that should trigger based on the event, and resolves their effects in a structured queue.
Properties:
effect_queue: Array[Dictionary]: A queue that holds effects waiting to be resolved. Each entry is a dictionary containing the effect, source, target, and priority.
_battle_manager_ref: BattleManager: A direct reference to the current BattleManager, set on battle start and cleared on battle end.
Signals:
resolve_queue_completed(): Emitted after the effect queue has been fully processed.
Methods:
_ready() -> void: Connects to all relevant EventBus signals that can trigger abilities (e.g., turn_started, unit_took_damage, initiate_battle).
_on_initiate_battle(battle_setup_data: Dictionary) -> void: Listens for the initiate_battle signal to acquire and store a reference to the newly created BattleManager instance for use in ability and condition resolution.
_on_game_event(...) -> void: A generic handler pattern for various game events. It will:
Get all active units from _battle_manager_ref.
Query all active game objects (units, items, etc.) for any AbilityDefinitions that have a matching trigger.
For each found ability, check its Conditions against the current game state by calling ConditionDefinition.evaluate().
If conditions are met, determine the target(s) based on the ability's targeting_rule.
For each valid target, call queue_effect() for each EffectDefinition in the ability.
queue_effect(effect: EffectDefinition, source: GachaBallInstance, target: GachaBallInstance) -> void: Creates a dictionary for the effect and appends it to the effect_queue, setting priority based on whether the source is a player or enemy unit.
resolve_queue() -> void:
Sorts the effect_queue based on a two-level priority: 1. Team Priority (Player-sourced effects resolve before Enemy-sourced effects), and 2. Positional Priority (Within each team, effects are resolved based on the source unit's lineup position, from front-to-back, e.g., position 1 to 6). It then iterates through the sorted queue, resolving each effect by calling _apply_effect().
Clears the queue after processing.
If new effects were queued during resolution, this process may repeat.
Emits resolve_queue_completed when the queue is fully empty.
_apply_effect(effect_data: Dictionary) -> void: Contains the logic to execute a single effect. It uses a match statement on the effect_type to call the appropriate methods on the target GachaBallInstance (e.g., target.take_damage(), target.increase_hp()).
2.6. GameManager.gd
Purpose: The single source of truth for the state of the current run. Manages the run lifecycle and persists data between scenes.
FSM States: NO_RUN, IN_RUN, AWAITING_BATTLE_RESULT, GAME_OVER.
Properties:
_state: StringName = "NO_RUN"
current_day: int
gold: int
hero_instance: GachaBallInstance
run_inventory: Dictionary = {1: [], 2: [], 3: []}  # Tiered dictionary for persistent run inventory
active_trinkets: Array[TrinketDefinition]
unlocked_hero_ids: Array[StringName]
unlocked_deck_ids: Array[StringName]
unlocked_gachaball_ids: Array[StringName]
unlocked_trinket_ids: Array[StringName]
unlocked_merge_recipe_ids: Array[StringName]
Methods:
_ready() -> void: Loads meta-progression data using SaveManager.load_meta_data() to populate unlocked_* arrays. Connects to EventBus.new_run_requested, EventBus.battle_start_requested, EventBus.battle_won, EventBus.battle_lost.
_on_new_run_requested(hero_def_id, deck_def_id) -> void: Initializes a new run.
_on_battle_start_requested(encounter_def) -> void: Prepares battle data and emits signals to start the battle.
_prepare_battle_data(encounter_def) -> Dictionary: Creates deep copies of the hero and run inventory for the battle.
_on_battle_won() -> void: Transitions state, gives rewards, and loads the next scene.
_on_battle_lost() -> void: Ends the run.
package_run_data() -> Dictionary: Serializes the entire run state into a dictionary for saving.
3. Core Data Structures (Resource Definitions)
3.1. GachaBallDefinition.gd
File Path: res://scripts/data/definitions/GachaBallDefinition.gd
Inherits: Resource, class_name GachaBallDefinition
Enums: enum Category { UNIT, ITEM }, enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, HERO }
@export Variables:
id: StringName
display_name_key: String
description_key: String
icon_texture: Texture2D
tier: int
rarity: Rarity
ball_category: Category
tags: Array[StringName]
@export_group("Unit Stats")
base_hp: int
base_pwr: int
ability_definition_refs: Array[AbilityDefinition]
item_slot_count: int
@export_group("Item Stats")
is_equippable: bool
is_consumable: bool
target_type_restriction: StringName # e.g., "HERO_ONLY", "ANY_UNIT"
3.2. GachaBallInstance.gd
File Path: res://scripts/data/instances/GachaBallInstance.gd
Inherits: Resource, class_name GachaBallInstance
Enums:
enum LocationState { 
    UNDEFINED, 
    IN_RUN_INVENTORY_TIER_1, 
    IN_RUN_INVENTORY_TIER_2, 
    IN_RUN_INVENTORY_TIER_3, 
    IN_BATTLE_INVENTORY_TIER_1, 
    IN_BATTLE_INVENTORY_TIER_2, 
    IN_BATTLE_INVENTORY_TIER_3, 
    IN_PLAYER_BENCH, 
    IN_PLAYER_LINEUP, 
    IN_ENEMY_LINEUP, 
    IN_ITEM_INVENTORY, 
    EQUIPPED_ON_UNIT, 
    IN_BATTLE_DISCARD_PILE 
}
Use code with caution.
Gdscript
Properties:
definition_id: StringName
ball_uuid: String
origin_uuid: String: Tracks the original instance UUID for battle copies.
current_hp: int
current_pwr: int
equipped_item_uuids: Array[String]
active_status_effects: Dictionary: Stores active status effects and their stacks.
current_location_state: LocationState = LocationState.UNDEFINED
instance_specific_modifiers: Dictionary = {}: Stores permanent stat changes for the run, e.g., {"base_hp_bonus": 5}.
Methods:
initialize(def: GachaBallDefinition) -> void: Sets properties from the definition and applies any values from instance_specific_modifiers to establish the instance's initial stats. Generates a new ball_uuid.
create_battle_copy() -> GachaBallInstance: Creates a new, battle-specific instance. The new instance gets a unique ball_uuid, its origin_uuid is set to this instance's ball_uuid, and all persistent modifiers and current stats are copied over.
apply_modifiers() -> void: Recalculates current_hp and current_pwr based on the base definition and any values in instance_specific_modifiers.
get_reference_hp() -> int: Calculates the reference HP value for percentage-based effects. This is derived from the unit's base_hp in its definition plus any permanent modifiers. This value is not a cap on current_hp.
increase_hp(amount: int) -> void: Increases the current_hp by the given amount.
take_damage(amount: int, source_instance: GachaBallInstance) -> void: Reduces current_hp by the damage amount, emits EventBus.unit_took_damage, and if HP reaches 0, emits EventBus.unit_defeated.
apply_status_effect(status_def: StatusEffectDefinition, stacks: int) -> void: Adds or updates a status effect in the active_status_effects dictionary.
has_status_effect(effect_id: StringName) -> bool: Checks if the instance currently has a given status effect.
has_item_equipped(item_def_id: StringName) -> bool: Checks if the instance has an item of the given definition ID equipped. This check may require assistance from the BattleManager which holds the master list of battle instances.
has_ability(ability_def_id: StringName) -> bool: Checks if the instance has a given ability, either from its base definition or granted by other sources like items.
3.3. AbilityDefinition.gd
File Path: res://scripts/data/definitions/AbilityDefinition.gd
Inherits: Resource, class_name AbilityDefinition
@export Variables:
trigger: StringName
conditions: Array[ConditionDefinition]
effects: Array[EffectDefinition]
targeting_rule: StringName
3.4. ConditionDefinition.gd
File Path: res://scripts/data/definitions/ConditionDefinition.gd
Inherits: Resource, class_name ConditionDefinition
Enums:
enum ConditionType {
    NONE,
    HAS_TAG,                  # Checks if target has a specific tag
    HAS_STATUS_EFFECT,        # Checks if target has a specific status effect
    HAS_ITEM_EQUIPPED,       # Checks if target has a specific item equipped
    HP_PERCENT_BELOW,        # Current HP % is below value
    HP_PERCENT_ABOVE,        # Current HP % is above value
    RANDOM_CHANCE,           # Random chance based on value (0-1)
    TURN_COUNT_EQUALS,       # Current turn count equals value
    TURN_COUNT_GREATER_THAN, # Current turn count > value
    TURN_COUNT_LESS_THAN,    # Current turn count < value
    HAS_ALLY_WITH_TAG,       # Has at least X allies with tag
    HAS_ENEMY_WITH_TAG,      # Has at least X enemies with tag
    IS_CRITICAL_HIT,         # Current attack is a critical hit
    IS_FRONTLINE,            # Unit is in front 3 positions
    IS_BACKLINE,             # Unit is in back 3 positions
    HAS_ACTIVE_ABILITY,      # Unit has a specific ability ID
    HAS_ACTIVE_EFFECT        # Unit has an effect with specific ID
}

enum ComparisonOperator {
    EQUALS,
    NOT_EQUALS,
    GREATER_THAN,
    LESS_THAN,
    GREATER_THAN_OR_EQUAL,
    LESS_THAN_OR_EQUAL
}
Use code with caution.
Gdscript
@export Variables:
@export var condition_type: ConditionType = ConditionType.NONE
@export var string_value: String = ""
@export var numeric_value: float = 0.0
@export var comparison: ComparisonOperator = ComparisonOperator.EQUALS
@export var secondary_numeric_value: float = 0.0
Methods:
evaluate(source: GachaBallInstance, target: GachaBallInstance, battle_manager: BattleManager, event_data: Dictionary = {}) -> bool: Evaluates this condition against the current game state. It uses the provided source, target, and battle_manager reference to access necessary game data (like turn count or unit positions). Returns true if the condition is met, false otherwise.
3.5. EffectDefinition.gd
File Path: res://scripts/data/definitions/EffectDefinition.gd
Inherits: Resource, class_name EffectDefinition
Purpose: Defines the actual outcome of an ability in a data-driven way.
Enums:
enum ValueType { 
    FLAT,                   # The 'value' is a direct, flat number.
    SOURCE_PWR_MULTIPLIER,  # 'value' is a multiplier for the source's PWR.
    TARGET_REF_HP_MULTIPLIER # 'value' is a multiplier for the target's reference HP.
}
Use code with caution.
Gdscript
@export Variables:
@export var effect_type: StringName # e.g., "DEAL_DAMAGE", "INCREASE_HP"
@export var value_type: ValueType = ValueType.FLAT
@export var value: float # The magnitude or multiplier of the effect.
@export var status_effect_to_apply: StatusEffectDefinition # Link to a status effect resource.
@export var duration: int # Duration in turns for temporary effects.
3.6. StatusEffectDefinition.gd
File Path: res://scripts/data/definitions/StatusEffectDefinition.gd
Inherits: Resource, class_name StatusEffectDefinition
@export Variables:
id: StringName
icon: Texture2D
abilities: Array[AbilityDefinition]
3.7. EnemyEncounterDefinition.gd
File Path: res://scripts/data/definitions/EnemyEncounterDefinition.gd
Inherits: Resource, class_name EnemyEncounterDefinition
@export Variables:
id: StringName
enemy_units: Array[GachaBallDefinition]
enemy_trinkets: Array[TrinketDefinition]

3.8. TrinketDefinition.gd
File Path: res://scripts/data/definitions/TrinketDefinition.gd
Inherits: Resource, class_name TrinketDefinition
@export Variables:
id: StringName
display_name_key: String
description_key: String
icon_texture: Texture2D
rarity: GachaBallDefinition.Rarity # Re-use the existing Rarity enum
passive_abilities: Array[AbilityDefinition]

3.9. MergeRecipe.gd
File Path: res://scripts/data/definitions/MergeRecipe.gd
Inherits: Resource, class_name MergeRecipe
@export Variables:
id: StringName
ingredient_a_id: StringName
ingredient_b_id: StringName
result_id: StringName
is_unlocked_by_default: bool

3.10. SynergyDefinition.gd
File Path: res://scripts/data/definitions/SynergyDefinition.gd
Inherits: Resource, class_name SynergyDefinition
@export Variables:
tag: StringName # e.g., "Warrior"
tier_thresholds: Array[int] # e.g., [2, 4] for Tier 1 and Tier 2
tier_abilities: Array[AbilityDefinition] # The abilities granted at each corresponding tier

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
Node Tree: Control (Root) > VBoxContainer > TopArea.tscn, Control (Name: ContentArea, Group: "content_area"), BottomArea.tscn
Script Logic (Main.gd):
_ready(): Emits EventBus.load_scene_in_container_requested("res://scenes/path/PathChoice.tscn", $VBoxContainer/DynamicContentArea).
4.3. TopArea.tscn & BottomArea.tscn
Purpose: Display persistent run information and Gacha machines.
Script Logic: Connect to relevant EventBus signals (hero_hp_updated, gold_updated, etc.) in _ready() to update their respective Label nodes.
4.4. PathChoice.tscn
Purpose: Presents the player with the next node choice.
Node Tree: Control > HBoxContainer > Button (BattleNodeButton)
Script Logic (PathChoice.gd):
@export var encounter_definition: EnemyEncounterDefinition
_ready(): Connects BattleNodeButton.pressed to _on_battle_node_button_pressed.
_on_battle_node_button_pressed() -> void: Emits EventBus.battle_start_requested(encounter_definition).
4.5. Battle.tscn
Purpose: The main combat scene.
Node Tree:
Control (Root)
BattleManager (Node, Name: BattleManager, Group: "battle_manager")
VBoxContainer
[EnemySideUI]
[PlayerSideUI]
Button (EndTurnButton)
EnemySideUI: Contains HBoxContainer (Name: EnemyLineup).
PlayerSideUI: Contains HBoxContainer (Name: PlayerLineup), HBoxContainer (Name: PlayerBench, 3 slots), HBoxContainer (Name: PlayerInventory, 3 slots).
Script Logic (BattleManager.gd):
FSM States: IDLE, SETUP, START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, VICTORY, DEFEAT.
Properties:
battle_inventory: Dictionary: Stores the drawable instances for each tier for the current battle.
_battle_discard_pile: Array: Stores all instances removed from play during the current battle.
_gacha_tokens: int: The player's currency for the Gacha Machines in this battle.
active_synergies: Dictionary: Tracks currently active synergies and their tiers.
_ready():
Connect to EventBus signals: initiate_battle, draw_gacha_request, end_turn_button_pressed, merge_units_requested, equip_item_requested.
SETUP State Logic:
Clear all previous battle state (lineups, pools, discard).
Populate _battle_gacha_pools by calling create_battle_copy() on each instance from battle_setup_data["player_pool"].
Set each copied instance's current_location_state to the appropriate IN_BATTLE_INVENTORY_TIER_X.
Instantiate UnitDisplay.tscn for each enemy unit defined in battle_setup_data["encounter_def"] and add to the EnemyLineup container.
Instantiate a UnitDisplay.tscn for the player hero from battle_setup_data["player_hero"] and add to the PlayerLineup.
Set hero's current_location_state to IN_PLAYER_LINEUP.
Call _update_and_apply_synergies() to calculate initial synergies from the Hero unit.
Emit EventBus.battle_started().
Transition FSM to START_OF_TURN.
START_OF_TURN State Logic:
# Prototype Note: The full Flashcard Mini-Game specified in the GDD is currently simplified to a flat gain of Gacha Tokens.
# The full implementation will include the SRS-based flashcard system with mastery tracking.
_gacha_tokens += 3
Emit EventBus.gacha_tokens_updated(_gacha_tokens)
Emit EventBus.turn_started() to allow the AbilityResolver to process ON_TURN_START effects.
await AbilityResolver.resolve_queue_completed
Transition FSM to MANAGEMENT.
COMBAT State Logic:
# Create action order based on team and position
var action_order: Array[GachaBallInstance] = []

# Populate with all units from both lineups
for unit in _player_lineup.get_children() + _enemy_lineup.get_children():
    if unit.unit_instance and unit.unit_instance.current_hp > 0:
        action_order.append(unit.unit_instance)

# Sort: Player team first, then by position (back-to-front)
action_order.sort_custom(func(a, b):
    if a.team != b.team:
        return a.team == "PLAYER"
    return a.position > b.position
)

# Process each unit's action
for unit in action_order:
    if unit.current_hp <= 0:
        continue
        
    # Emit event that this unit is acting - AbilityResolver will handle all triggers
    EventBus.emit_signal("unit_is_acting", unit)
    await AbilityResolver.resolve_queue_completed
    
    # Visual feedback and delay between actions
    var unit_display = _find_unit_display(unit)
    if unit_display:
        unit_display.play_act_animation()
    await get_tree().create_timer(0.5).timeout

# All actions complete
transition_to(State.END_OF_TURN)
New Methods:
_on_merge_units_requested(unit_a_uuid: String, unit_b_uuid: String) -> void:
Validate both units exist and are merge-compatible.
Determine the resulting unit's definition from a merge recipe.
Create a new merged GachaBallInstance.
Transfer all equipped items from both parent units to the new unit's vacant slots.
Combine instance_specific_modifiers from both parents.
Remove old units from the battle and add the new unit to the bench.
Update UI and call _update_and_apply_synergies().
Emit EventBus.unit_was_merged signal with the new unit instance.
_on_equip_item_requested(item_uuid: String, target_unit_uuid: String) -> void:
Logic to validate the unit has an empty item slot.
Updates the GachaBallInstance data for both the item and the unit.
Updates the UnitDisplay UI to show an icon for the equipped item.
_update_and_apply_synergies() -> void:
Clear all current synergy bonuses.
Count all unique tags from units currently in the PlayerLineup.
For each tag, check the count against the unlocked SynergyDefinition tiers.
For each activated synergy tier, apply its passive effects to all qualifying units via the AbilityResolver.
Draw Logic (_on_draw_gacha_request):
Check for sufficient _gacha_tokens.
Draw an instance from the correct _battle_gacha_pools tier.
If drawn instance is a UNIT: Attempt to place on PlayerBench. If full, attempt to place in PlayerLineup. If both are full, set its current_location_state to IN_BATTLE_DISCARD and add to _battle_discard_pile.
If drawn instance is an ITEM: Attempt to place in PlayerInventory. If full, set its current_location_state to IN_BATTLE_DISCARD and add to _battle_discard_pile.
Update the current_location_state of the drawn instance accordingly.
After a successful draw, check if the battle pool for that tier is empty. If so, call a private method to reshuffle all matching-tier instances from the _battle_discard_pile back into the battle pool.
Unit Defeat Logic:
When a unit's HP reaches 0, GachaBallInstance.take_damage() emits EventBus.unit_defeated.
The BattleManager listens for this signal to perform cleanup.
Iterate the defeated unit's equipped items, change their current_location_state to IN_BATTLE_DISCARD, and add them to the _battle_discard_pile.
Clear the defeated unit's equipped_item_uuids array.
Change the defeated unit's current_location_state to IN_BATTLE_DISCARD and add it to the _battle_discard_pile.
The Battle.tscn scene script listens for unit_defeated and removes the corresponding UnitDisplay node from the scene tree.
4.6. In-Battle Interaction Model
Purpose: Defines the precise, step-by-step user interactions for performing actions during the Battle Management Phase.
Properties (in BattleManager.gd or a dedicated UI manager):
_selected_entity_uuid: String = ""
_selected_entity_type: String = ""
Interaction Flow for Merging:
Player clicks a UnitDisplay. UI sets selection state and adds visual feedback.
Player clicks a second, compatible UnitDisplay.
UI validates the merge and emits EventBus.merge_units_requested().
Selection state is cleared.
Interaction Flow for Equipping:
Player clicks an ItemDisplay. UI sets selection state and adds visual feedback.
Player clicks a UnitDisplay.
UI validates the equip action and emits EventBus.equip_item_requested().
Selection state is cleared.
Selection Cancellation: Clicking empty space or pressing ESC clears the current selection.
4.7. GachaPoolInspection.tscn
Purpose: A modal overlay to inspect a Gacha Machine's contents. Closes on an outside click.
Node Tree: Control (Root, Name: ClickCatcher) > PanelContainer (Name: ModalWindow) > ... > GridContainer (GachaGrid)
Script Logic (GachaPoolInspection.gd):
The root ClickCatcher node has its Mouse Filter set to Stop.
The ModalWindow PanelContainer has its Mouse Filter set to Ignore.
Implement _gui_input(event: InputEvent) on the root node to detect clicks outside the modal's rect and queue_free() the scene.
4.8. UnitDisplay.tscn
Purpose: Reusable scene to visually represent a GachaBallInstance.
Node Tree: PanelContainer > VBoxContainer > TextureRect (Icon), Label (HP), Label (PWR)
Script Logic (UnitDisplay.gd):
instance_data: GachaBallInstance
display_instance(inst: GachaBallInstance) -> void: Stores inst in instance_data and updates UI labels and the icon texture.
update_stats() -> void: Refreshes the HP and PWR labels from instance_data.