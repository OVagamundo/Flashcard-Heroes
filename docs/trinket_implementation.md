Trinket Feature: Complete Implementation Plan (V2.0 - Final)
1. Feature Overview & Implementation Goals
This document outlines the complete implementation of the passive Trinket system. Upon completion, the following goals will have been met and verified:
Player Trinket UI: A persistent 5-slot trinket inventory will be integrated directly into the TopArea of Main.tscn, positioned with flexible spacers between all top-bar elements. This is addressed in Phase 3.1.
Enemy Trinket UI: A 5-slot trinket inventory will be integrated directly into Battle.tscn below the enemy lineup, mirroring the layout of the player's battle item inventory. This is addressed in Phase 3.2.
Functional HealingAmulet Trinket: The HealingAmulet will be defined and automatically equipped to the player at run start and to enemy teams at battle start. This is addressed in Phase 1 and Phase 2.
Correct Battle Behavior: The HealingAmulet will correctly trigger its ability (on_turn_start) for both teams, healing their respective frontmost unit's current_hp by 2. This is addressed in Phase 4.
Correct Trinket Icon: The trinket will use the icon at res://assets/sprites/trinkets/Trinket1A.png. This is addressed in Phase 1.2.
Consistent UI Behavior: Trinkets in both inventories will be INSPECTION_ONLY with single-click inspection. This is addressed throughout Phase 3.
2. Core Technical Approach
Data vs. Runtime: Trinkets are defined by a new TrinketDefinition resource but are represented at runtime by the existing GachaBallInstance class to maximize code reuse.
Team-Based Abilities: The AbilityResolver will inject a team: "PLAYER" or team: "ENEMY" key into the trigger context for trinkets. BattleManager's targeting logic is updated to use this key, ensuring backward compatibility with unit/item abilities.
Implementation Steps
Phase 1: Data Schema & First Trinket Definition
Step 1.1: Create New Script TrinketDefinition.gd
ACTION: Create a new GDScript file.
FILE: res://scripts/TrinketDefinition.gd
CODE:
code
Gdscript
# res://scripts/TrinketDefinition.gd
@tool
class_name TrinketDefinition
extends Resource

@export var id: StringName
@export var name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var category: StringName = &"TRINKET"
@export var is_player_exclusive: bool = false
@export var ability_definitions: Array[AbilityDefinition]
Step 1.2: Create HealingAmulet.tres Resource
ACTION: Create a new TrinketDefinition resource file.
FILE: res://resources/trinkets/HealingAmulet.tres
CODE (.tres format):
code
Ini
[gd_resource type="Resource" script_class="TrinketDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/TrinketDefinition.gd" id="1_def"]
[ext_resource type="Texture2D" path="res://assets/sprites/trinkets/Trinket1A.png" id="2_icon"]
[ext_resource type="Script" path="res://scripts/AbilityDefinition.gd" id="3_ability"]
[ext_resource type="Script" path="res://scripts/EffectModifyStat.gd" id="4_effect"]

[sub_resource type="Resource" id="EffectModifyStat_HealingAmulet_1"]
script = ExtResource("4_effect")
parameters = { "stat": "hp", "base_value": 2 }
target_type = &"FRONTMOST_ALLY"

[sub_resource type="Resource" id="Ability_HealingAmulet_1"]
script = ExtResource("3_ability")
trigger = &"on_turn_start"
description_key = "ability.healing_amulet.desc"
effects = Array[Resource]([SubResource("EffectModifyStat_HealingAmulet_1")])

[resource]
script = ExtResource("1_def")
id = &"trinket_healing_amulet"
name_key = "trinket.healing_amulet.name"
description_key = "trinket.healing_amulet.desc"
icon = ExtResource("2_icon")
is_player_exclusive = false
ability_definitions = Array[Resource]([SubResource("Ability_HealingAmulet_1")])
Step 1.3: Update Database.gd
ACTION: Modify the Database singleton to load and retrieve TrinketDefinition resources.
FILE: res://scripts/Database.gd
CODE:
code
Gdscript
// In scripts/Database.gd

// 1. ADD this new dictionary.
var trinkets: Dictionary = {}

// 2. In _ready(), ADD the line to load trinkets.
func _ready() -> void:
    // ... after loading abilities ...
    _load_resources_from_path("res://resources/trinkets/", trinkets) // ADD THIS
    // ...

// 3. REPLACE the entire get_definition() function.
func get_definition(id: StringName) -> Resource:
    var definition: GachaBallDefinition = units.get(id)
    if definition: return definition
    
    definition = items.get(id)
    if definition: return definition

    var trinket_def: TrinketDefinition = trinkets.get(id)
    if trinket_def: return trinket_def

    return null
Phase 2: Core System Integration
Step 2.1: Update RunState.gd
ACTION: Modify RunState to create a dedicated container for player trinkets and route them correctly.
FILE: res://scripts/RunState.gd
CODE:
code
Gdscript
// In scripts/RunState.gd

// 1. ADD the new container variable.
@export var player_trinkets: FixedArrayContainer

// 2. In initialize_run(), create the container and add the starter trinket.
func initialize_run(hero_def_id: StringName, deck_id: StringName) -> void:
    start_new_run()
    player_trinkets = FixedArrayContainer.new(5) // ADD THIS
    // ... (existing hero and flashcard setup) ...
    
    // ADD THIS BLOCK after inventory container creation
    var healing_amulet_def = Database.get_definition(&"trinket_healing_amulet")
    if healing_amulet_def:
        var trinket_inst = GachaBallInstance.new()
        trinket_inst.initialize(healing_amulet_def)
        add_instance(trinket_inst, "")

// 3. ADD routing logic to the TOP of the add_instance() function.
func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
    var definition = instance.get_definition()
    // ADD THIS BLOCK FOR TRINKET ROUTING
    if is_instance_valid(definition) and definition.category == &"TRINKET":
        var trinket_container = get_container(C.CONTAINER_PLAYER_TRINKETS)
        var slot = trinket_container.find_first_empty_slot()
        if slot == -1: return false
        trinket_container.set_uuid(slot, instance.ball_uuid)
        instance.location_container_tag = C.CONTAINER_PLAYER_TRINKETS
        instance.location_slot_index = slot
        run_instances[instance.ball_uuid] = instance
        SignalBus.emit_signal("run_data_changed")
        return true
    
    // Original function logic continues below.
    if not is_instance_valid(instance): return false
    var container = get_container(container_name)
    // ...
Step 2.2: Update BattleManager.gd
ACTION: Update BattleManager for enemy trinkets and team-aware targeting.
FILE: res://scripts/BattleManager.gd
CODE:
code
Gdscript
// In scripts/BattleManager.gd

// 1. ADD this new variable.
var enemy_trinkets: Array[GachaBallInstance] = []

// 2. In _setup_battle(), ADD the block to create the enemy's test trinket.
func _setup_battle(encounter_def: EncounterDefinition = null) -> void:
    // ... after _battle_over_emitted = false ...
    enemy_trinkets.clear() // ADD THIS

    // ADD THIS BLOCK
    var trinket_def = Database.get_definition(&"trinket_healing_amulet")
    if is_instance_valid(trinket_def):
        var trinket_inst = GachaBallInstance.new()
        trinket_inst.initialize(trinket_def)
        _battle_instances[trinket_inst.ball_uuid] = trinket_inst
        _update_instance_location(trinket_inst.ball_uuid, C.CONTAINER_ENEMY_TRINKETS, 0)
        enemy_trinkets.append(trinket_inst)
    
    // ... (rest of the function)

// 3. REPLACE the entire resolve_target function with this new version.
func resolve_target(source_uuid: String, target_type: StringName, context: Dictionary) -> Array[String]:
    var source_instance = get_instance_by_uuid(source_uuid)
    var is_player_team: bool
    if context.has("team"):
        is_player_team = (context.get("team") == "PLAYER")
    elif is_instance_valid(source_instance):
        is_player_team = _is_player_unit(source_instance)
    else:
        return []

    match target_type:
        C.TARGET_SELF:
            return [source_uuid] if not source_uuid.is_empty() else []
        // ... (other cases are handled by the new 'is_player_team' variable) ...
        C.TARGET_FRONTMOST_ENEMY:
            var target_is_player_side = not is_player_team
            var target = _get_frontmost_target(target_is_player_side)
            if is_instance_valid(target): return [target.ball_uuid]
            return []
        C.TARGET_ALL_ALLIES:
            var ally_lineup_tag = BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if is_player_team else BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
            var allies = get_instances_in_container(ally_lineup_tag)
            return allies.map(func(ally): return ally.ball_uuid)
        _:
            return []
Phase 3: UI Implementation
Step 3.1: Player Trinket Bar (Main.tscn & Main.gd)
ACTION: Modify Main.tscn scene and Main.gd script.
INSTRUCTIONS (Editor for Main.tscn):
Open Main.tscn. Navigate to VBoxContainer/TopArea/HBoxContainer.
Ensure there is a Control node with "Layout > Container Sizing > Horizontal" set to "Expand Fill" between each visible element (GoldLabel, TokensLabel, and DaysLabel).
Select the Control spacer located just before DaysLabel.
Add a new HBoxContainer as its child. Name it PlayerTrinketBar.
Set the PlayerTrinketBar's "Layout > Container Sizing > Horizontal" to "Shrink End".
Add 5 instances of SlotView.tscn as children of PlayerTrinketBar.
CODE (Main.gd):
code
Gdscript
// In scripts/Main.gd
// 1. ADD this @onready var.
@onready var player_trinket_bar: HBoxContainer = %PlayerTrinketBar

// 2. ADD calls to the new populate function.
func _ready():
    // ...
    _populate_player_trinkets()
func _on_run_data_changed():
    // ...
    _populate_player_trinkets()

// 3. ADD the new function to the script.
func _populate_player_trinkets() -> void:
    if not is_instance_valid(GameManager.run_state): return
    var trinket_container = GameManager.run_state.get_container(C.CONTAINER_PLAYER_TRINKETS)
    if not is_instance_valid(trinket_container): return
    var slots = player_trinket_bar.get_children()
    for i in range(slots.size()):
        var slot_view: SlotView = slots[i]
        for child in slot_view.get_children():
            child.queue_free()

        var loc = LocationIdentifier.new(C.CONTAINER_PLAYER_TRINKETS, i)
        slot_view.populate(loc)
        slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

        var instance = GameManager.get_instance_from_location(loc)
        if is_instance_valid(instance):
            var gacha_view = GachaBallView.instantiate()
            slot_view.add_child(gacha_view)
            gacha_view.populate(loc, instance, true, true)
            gacha_view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
Step 3.2: Enemy Trinket Bar (Battle.tscn & BattleView.gd)
ACTION: Modify Battle.tscn scene and BattleView.gd script.
INSTRUCTIONS (Editor for Battle.tscn):
Open Battle.tscn. Navigate to TeamAreas/EnemyArea.
Add a new HBoxContainer as a child of EnemyArea. Name it EnemyTrinketBar.
Set its "Layout > Alignment" property to "Center".
Add a new Control node as a child of EnemyArea. Set its "Layout > Container Sizing > Vertical" to "Expand Fill".
Arrange the children of EnemyArea in this order: Control, EnemyLineupContainer, EnemyTrinketBar, Control2, DiscardArea, Control3.
Add 5 instances of SlotView.tscn as children of EnemyTrinketBar.
CODE (BattleView.gd):
code
Gdscript
// In scripts/BattleView.gd
// 1. ADD this @onready var.
@onready var enemy_trinket_bar: HBoxContainer = %EnemyTrinketBar

// 2. In _redraw_board(), ADD the call to the new function.
func _redraw_board():
    // ... after populating enemy_lineup
    _populate_enemy_trinkets()

// 3. ADD the new function to the script.
func _populate_enemy_trinkets() -> void:
    if not is_instance_valid(battle_manager): return
    var trinket_instances = battle_manager.enemy_trinkets
    var slots = enemy_trinket_bar.get_children()
    for i in range(slots.size()):
        var slot_view: SlotView = slots[i]
        for child in slot_view.get_children():
            child.queue_free()

        var loc = LocationIdentifier.new(C.CONTAINER_ENEMY_TRINKETS, i)
        slot_view.populate(loc)
        slot_view.set_interaction_context(&"INSPECTION_ONLY", 0)

        if i < trinket_instances.size():
            var instance = trinket_instances[i]
            if is_instance_valid(instance):
                var gacha_view = GachaBallView.instantiate()
                slot_view.add_child(gacha_view)
                gacha_view.populate(loc, instance, true, true)
                gacha_view.set_interaction_context(&"INSPECTION_ONLY", &"TRINKET", 0)
Phase 4: Core Logic Activation
Step 4.1: Modify AbilityResolver.gd
ACTION: Replace the process_trigger function to enable trinket ability processing.
FILE: res://scripts/AbilityResolver.gd
RATIONALE: Activates trinkets by feeding them into the processing pipeline with the new team-based context.
CODE:
code
Gdscript
// In scripts/AbilityResolver.gd
// REPLACE the entire process_trigger function with this version.
func process_trigger(trigger: StringName, context: Dictionary) -> void:
    var battle_manager = get_tree().get_first_node_in_group("battle_manager")
    if not is_instance_valid(battle_manager): return

    # Loop 1: GachaBallInstances (Units & Equipped Items)
    var all_instances = battle_manager.get_all_instances()
    for instance_uuid in all_instances:
        var instance = all_instances.get(instance_uuid)
        if not is_instance_valid(instance): continue
        var definition = instance.get_definition()
        if not is_instance_valid(definition) or not definition.has("ability_definitions"): continue
        if definition.ability_definitions.is_empty(): continue
        for ability in definition.ability_definitions:
            if ability.trigger == trigger:
                _process_ability(ability, instance_uuid, battle_manager, context)

    # Loop 2: Player Trinkets
    if is_instance_valid(GameManager.run_state):
        var player_trinkets_container = GameManager.run_state.get_container(C.CONTAINER_PLAYER_TRINKETS)
        if is_instance_valid(player_trinkets_container):
            for trinket_uuid in player_trinkets_container.get_all_non_empty_uuids():
                var trinket_instance = GameManager.get_instance_by_uuid(trinket_uuid)
                if not is_instance_valid(trinket_instance): continue
                var trinket_def = trinket_instance.get_definition()
                if is_instance_valid(trinket_def) and not trinket_def.ability_definitions.is_empty():
                    for ability in trinket_def.ability_definitions:
                        if ability.trigger == trigger:
                            var new_context = context.duplicate(true)
                            new_context["team"] = "PLAYER"
                            _process_ability(ability, "", battle_manager, new_context)
                            
    # Loop 3: Enemy Trinkets
    if not battle_manager.enemy_trinkets.is_empty():
        for trinket_instance in battle_manager.enemy_trinkets:
            if not is_instance_valid(trinket_instance): continue
            var trinket_def = trinket_instance.get_definition()
            if is_instance_valid(trinket_def) and not trinket_def.ability_definitions.is_empty():
                for ability in trinket_def.ability_definitions:
                    if ability.trigger == trigger:
                        var new_context = context.duplicate(true)
                        new_context["team"] = "ENEMY"
                        _process_ability(ability, "", battle_manager, new_context)
Phase 5: Final Integration & Verification
Step 5.1: Update Constants.gd
ACTION: Add new constants for the trinket containers.
FILE: res://scripts/Constants.gd
CODE:
code
Gdscript
// In scripts/Constants.gd, add these lines
const CONTAINER_PLAYER_TRINKETS = &"PlayerTrinkets"
const CONTAINER_ENEMY_TRINKETS = &"EnemyTrinkets"
Step 5.2: Update Localization File
ACTION: Add the new text keys for the HealingAmulet.
FILE: res://localization/game.csv
INSTRUCTIONS: Append these lines to the game.csv file.
CSV CONTENT:
code
Csv
trinket.healing_amulet.name,"Healing Amulet"
trinket.healing_amulet.desc,"A simple but reliable enchanted charm."
ability.healing_amulet.desc,"At the start of the turn, restores 2 HP to the frontmost ally."