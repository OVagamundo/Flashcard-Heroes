Definitive Refactoring Plan: TDD Hybrid Architecture (Final, Complete Specification)
1. Implementation & Tooling Strategy (Windsurf Integration)
This document serves as the single source of truth for refactoring the project to the "Definitive Hybrid Architecture." It is designed to be executed by an AI code editor agent, "Windsurf." To ensure a high-fidelity, automated refactor, the following principles and strategies must be adhered to.
1.1. Core Mandate: The Document is the Authority
No Undocumented Logic: All existing logic, edge cases, and custom behaviors are assumed to be captured either in the original TDD or within this refactoring plan. If any "hack," workaround, or undocumented system exists in the current codebase, it must be explicitly identified and addressed before proceeding.
Fidelity and Synchronization: The file paths, resource names (.tres), and node names (%UniqueName) used in this document are assumed to be an exact match for the state of the project. Any deviation must be corrected in the project to match the document before initiating the refactor.
Recent Changes: All recent development must be paused. The codebase must be in a stable state that reflects the "before" picture described by the existing files. This plan will bring it to the "after" state.
1.2. Windsurf Execution Strategy
To maximize effectiveness and minimize errors, the refactor will be executed using the following Windsurf features and workflow:
Use of Cascade and Memories: The architectural principles outlined here (e.g., "Managers are stateless," "Instances are the source of truth") should be loaded into Windsurf's "Memories." The refactoring tasks will be executed in the specified order, allowing Windsurf to "Cascade" these rules consistently across all affected files.
Prompting with Specific Goals: Each task in this document is designed to be a specific, actionable prompt. For example:
Initial Prompt: "Begin refactoring project to TDD Hybrid Architecture. Load the principles from Section 1 into your memories. Start with Phase 0, Task 0.1: Create Recipe Resource Files."
Subsequent Prompt: "Now, execute Phase 1, Task 1.1: Refactor GachaBallInstance.gd."
Iterative Review Cycle: The refactor will proceed phase by phase.
Windsurf will be prompted to execute all tasks within a single Phase (e.g., "Execute all tasks in Phase 1").
The human developer will review the proposed changes from that phase.
If correct, the changes will be accepted, and Windsurf will be prompted to begin the next phase.
If incorrect, feedback will be provided (e.g., "In BattleManager.gd, you missed disconnecting the signals in _exit_tree. Please correct this.") before proceeding.
This structured, iterative approach ensures human oversight while leveraging the AI's speed and consistency.
2. Executive Summary & Core Principle
This refactor implements the "Definitive Hybrid Architecture" from our TDD. The fundamental change is moving the "source of truth" for an object's state from external containers to the object itself.
Old Way: An instance's location was determined by which manager's DataContainer array its UUID was stored in. Moving an object meant moving a string between arrays.
New Way (TDD Compliant): An instance's location is defined by properties on the GachaBallInstance resource itself (e.g., location_container_tag, location_slot_index, equipped_on_uuid). Moving an object means changing these properties on the instance. Managers and UI then query the master list of instances to find objects matching specific criteria (e.g., "find all instances where location_container_tag is BATTLE_PLAYER_LINEUP").
This change makes the system more robust, eliminates the possibility of an object being in two places at once, and simplifies state management significantly.
3. Phase 0: Pre-flight & Asset Correction
Analysis: The TDD manifest for .tres files was incomplete. The Recipes and Abilities sections were missing their data. This phase corrects that by creating the necessary resource files. This must be completed before any code refactoring begins.
Task 0.1: Create Recipe Resource Files
Goal: Create the four required MergeRecipe.tres files.
Rationale: The MergeManager and InventoryManager depend on these files to determine valid merge actions. Without them, no merges can ever occur.
Prompt for AI Coder:
Generated prompt
Create the following four new resource files in the `res://resources/recipes/` directory with the exact content specified.

**1. File: `res://resources/recipes/Merge_Unit_A_B_to_C.tres`**
```ini
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"merge_unit_a_b_to_c"
ingredient_a_id = &"unit_t1_a"
ingredient_b_id = &"unit_t1_b"
result_id = &"unit_t2_c"
is_self_merge = false
merge_type = &"UNIT"
Use code with caution.
Prompt
2. File: res://resources/recipes/Merge_Unit_C_C_to_D.tres
Generated ini
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"merge_unit_c_c_to_d"
ingredient_a_id = &"unit_t2_c"
ingredient_b_id = &"unit_t2_c"
result_id = &"unit_t3_d"
is_self_merge = true
merge_type = &"UNIT"
Use code with caution.
Ini
3. File: res://resources/recipes/Merge_Item_A_B_to_C.tres
Generated ini
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"merge_item_a_b_to_c"
ingredient_a_id = &"item_t1_a"
ingredient_b_id = &"item_t1_b"
result_id = &"item_t2_c"
is_self_merge = false
merge_type = &"ITEM"
Use code with caution.
Ini
4. File: res://resources/recipes/Merge_Item_C_C_to_D.tres
Generated ini
[gd_resource type="Resource" script_class="MergeRecipe" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/MergeRecipe.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
id = &"merge_item_c_c_to_d"
ingredient_a_id = &"item_t2_c"
ingredient_b_id = &"item_t2_c"
result_id = &"item_t3_d"
is_self_merge = true
merge_type = &"ITEM"
Use code with caution.
Ini
Generated code
Use code with caution.
Task 0.2: Create Ability Resource File
Goal: Create the BasicAttack.tres file.
Rationale: The Database loader and BattleManager's combat logic require this resource to exist to execute attacks.
Prompt for AI Coder:
Generated prompt
Create the following new resource file in the `res://resources/abilities/` directory with the exact content specified.

**File: `res://resources/abilities/BasicAttack.tres`**
```ini
[gd_resource type="Resource" script_class="AbilityDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/AbilityDefinition.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/BasicAttackEffect.gd" id="2_effect"]

[sub_resource type="Resource" id="SubResource_1"]
script = ExtResource("2_effect")

[resource]
script = ExtResource("1_script")
id = &"basic_attack"
name_key = "ability.basic_attack.name"
description_key = "ability.basic_attack.desc"
effect = SubResource("SubResource_1")
Use code with caution.
Prompt
Generated code
Use code with caution.
4. Phase 1: Foundational Data Model Overhaul
Task 1.1: Refactor GachaBallInstance.gd to be the Single Source of Truth
Goal: Embed all state and location information directly into the GachaBallInstance resource.
Prompt for AI Coder:
Generated prompt
Completely overhaul `scripts/GachaBallInstance.gd` to align with the new TDD architecture. This script is the most critical part of the data model. Replace its entire content with the following code:

```gdscript
# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource

## A unique, individual instance of a GachaBall. Its state is defined by its properties.

# --- Core Properties ---
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = "" # UUID of the permanent instance this battle copy was created from.

# --- State Properties ---
var current_hp: int
var current_pwr: int

# --- Location & Relationship Properties (The Single Source of Truth per TDD 3.5.A) ---
# The tag of the container this instance is in (e.g., "BATTLE_PLAYER_LINEUP"). Null if equipped.
var location_container_tag: StringName
# The slot index within the container. -1 if not in a container.
var location_slot_index: int = -1
# If this instance is an ITEM equipped on a UNIT, this is the host's UUID. Null otherwise.
var equipped_on_uuid: String = ""
# The item slot this occupies on the host unit. -1 if not equipped.
var equipped_slot_index: int = -1

# --- Dynamic State Properties ---
var dynamic_tags: Array[StringName] = [] # For status effects like "POISONED", "HONEY_ARMOR"

# --- Abilities ---
var abilities: Array[AbilityDefinition] = []

func initialize(definition: GachaBallDefinition):
    if not is_instance_valid(definition):
        printerr("GachaBallInstance.initialize() called with a null definition.")
        return

    self.definition_id = definition.id
    self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
    self.abilities = definition.ability_definitions.duplicate(true) # Deep copy
    self.current_hp = definition.base_hp
    self.current_pwr = definition.base_pwr

    # Initialize location to a non-existent state
    self.location_container_tag = null
    self.location_slot_index = -1
    self.equipped_on_uuid = ""
    self.equipped_slot_index = -1

func create_battle_copy() -> GachaBallInstance:
    var copy = self.duplicate(false) # Shallow copy of value types
    var definition = get_definition()
    if not is_instance_valid(definition):
        printerr("Cannot create battle copy, definition not found for ID: ", self.definition_id)
        return null

    # Deep copy mutable types
    copy.abilities = self.abilities.duplicate(true)
    copy.dynamic_tags = self.dynamic_tags.duplicate(true)
    
    # Assign new unique ID for the battle context
    copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
    copy.origin_uuid = self.ball_uuid # Link back to the original

    # Copy stats and location properties
    copy.current_hp = self.current_hp
    copy.current_pwr = self.current_pwr
    copy.location_container_tag = self.location_container_tag
    copy.location_slot_index = self.location_slot_index
    copy.equipped_on_uuid = self.equipped_on_uuid
    copy.equipped_slot_index = self.equipped_slot_index

    return copy

func recalculate_stats(all_instances_db: Dictionary):
    var definition = get_definition()
    if not is_instance_valid(definition): return

    var new_hp = definition.base_hp
    var new_pwr = definition.base_pwr

    # Add bonuses from each equipped item by querying the database for children.
    for key in all_instances_db:
        var instance: GachaBallInstance = all_instances_db[key]
        if is_instance_valid(instance) and instance.equipped_on_uuid == self.ball_uuid:
            var item_def = instance.get_definition()
            if is_instance_valid(item_def):
                new_hp += item_def.bonus_hp
                new_pwr += item_def.bonus_pwr

    self.current_hp = new_hp
    self.current_pwr = new_pwr

func get_definition() -> GachaBallDefinition:
    return Database.get_definition(definition_id)

func add_tag(tag: StringName):
    if not dynamic_tags.has(tag):
        dynamic_tags.append(tag)

func remove_tag(tag: StringName):
    if dynamic_tags.has(tag):
        dynamic_tags.erase(tag)

func has_tag(tag: StringName) -> bool:
    # Check static tags on the definition first.
    var def = get_definition()
    if is_instance_valid(def) and def.tags.has(tag):
        return true
    # Then check dynamic tags on this instance.
    return dynamic_tags.has(tag)
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 1.2: Update GachaBallDefinition.gd with Static Tags
Goal: Add the tags property to the definition resource.
Prompt for AI Coder:
Generated prompt
In `scripts/GachaBallDefinition.gd`, add the new `tags` property. After the `@export var icon: Texture2D` line, add the following:

```gdscript
## Static tags that define the GachaBall's inherent nature (e.g., "UNIT", "HERO", "TIER_1").
@export var tags: Array[StringName]
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 1.3: Delete Obsolete DataContainer Scripts
Goal: Purge the old, container-based data management scripts from the project.
Prompt for AI Coder:
Generated prompt
Delete the following files from the project as they are now obsolete under the new TDD architecture:
- `res://scripts/DataContainer.gd`
- `res://scripts/FixedArrayContainer.gd`
- `res://scripts/GrowableGridContainer.gd`
Use code with caution.
Prompt
5. Phase 2: Core Manager Refactoring
Task 2.1: Refactor RunState.gd to be a Simple Data Owner
Goal: Simplify RunState to only hold the master run_instances dictionary and provide query helpers.
Prompt for AI Coder:
Generated prompt
Completely overhaul `scripts/RunState.gd` to remove the DataContainer system and use the new query-based architecture. Replace the entire file content with the following code:

```gdscript
# res://scripts/RunState.gd
class_name RunState
extends Resource

## The persistent state for an entire run.

@export var gold: int = 0
@export var hero_instance: GachaBallInstance

# The master registry for all permanent instances in the run.
# Location is defined by the properties on the instances themselves.
@export var run_instances: Dictionary = {} # Key: ball_uuid (String), Value: GachaBallInstance

# --- Public API ---

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
    return run_instances.get(uuid)

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
    var results: Array[GachaBallInstance] = []
    for uuid in run_instances:
        var instance: GachaBallInstance = run_instances[uuid]
        if instance.location_container_tag == container_tag:
            results.append(instance)
    
    results.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
    return results

func add_instance(instance: GachaBallInstance) -> bool:
    if not is_instance_valid(instance): return false
    var def = instance.get_definition()
    if not is_instance_valid(def): return false

    var container_tag = "RUN_INVENTORY_T%d" % def.tier
    var existing_instances_in_container = get_instances_in_container(container_tag)
    
    var occupied_slots: Array[int] = []
    for inst in existing_instances_in_container:
        occupied_slots.append(inst.location_slot_index)
    
    var new_slot_index = 0
    while new_slot_index in occupied_slots:
        new_slot_index += 1

    instance.location_container_tag = container_tag
    instance.location_slot_index = new_slot_index
    run_instances[instance.ball_uuid] = instance
    return true

func remove_instance_by_uuid(uuid: String):
    if run_instances.has(uuid):
        run_instances.erase(uuid)

func start_new_run() -> void:
    gold = 10
    run_instances.clear()

    var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
    if hero_def:
        hero_instance = GachaBallInstance.new()
        hero_instance.initialize(hero_def)
    else:
        printerr("RunState: CRITICAL - Could not find 'hero' definition in Database.")

    var items_to_add: Array[StringName] = [
        &"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
        &"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
        &"unit_t2_c", &"unit_t2_c", &"item_t2_c", &"item_t2_c",
        &"unit_t3_d", &"unit_t3_d", &"item_t3_d", &"item_t3_d"
    ]
    
    for item_id in items_to_add:
        var definition: GachaBallDefinition = Database.get_definition(item_id)
        if not is_instance_valid(definition): continue
        
        var instance = GachaBallInstance.new()
        instance.initialize(definition)
        
        if not add_instance(instance):
            printerr("RunState: Failed to add starting item '%s' to inventory." % item_id)
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 2.2: Refactor BattleManager.gd to be a Query-Based State Controller
Goal: Transform BattleManager into the sole authority for battle state, providing relational query functions as its primary API.
Prompt for AI Coder:
Generated prompt
Completely overhaul `scripts/BattleManager.gd` to use the new TDD property-based architecture and relational queries. Replace the entire file content with the following code:

```gdscript
extends Node
class_name BattleManager

enum Phases { START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, BATTLE_OVER }
var _current_battle_phase: Phases

var _battle_instances: Dictionary = {} # Master registry for ALL temporary battle copies.
var _gacha_tokens: int = 0

func _ready():
    add_to_group("battle_manager")
    _setup_battle()
    _connect_signals()

    GameManager.is_in_battle = true
    EventBus.emit_signal("battle_state_changed", true)
    
    # Initial state setup finished, notify UI to draw.
    EventBus.emit_signal("instance_location_changed", "") # Generic signal to trigger full redraw

    _change_phase(Phases.START_OF_TURN)

func _exit_tree():
    GameManager.is_in_battle = false
    EventBus.emit_signal("battle_state_changed", false)
    EventBus.end_turn_requested.disconnect(_on_end_turn_requested)
    EventBus.draw_gacha_requested.disconnect(_on_draw_gacha_requested)

func _connect_signals():
    EventBus.end_turn_requested.connect(_on_end_turn_requested)
    EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)

# --- Public API for Managers ---

func get_instance(uuid: String) -> GachaBallInstance:
    return _battle_instances.get(uuid)

func get_all_instances() -> Dictionary:
    return _battle_instances

# --- Relational Query API (TDD 3.5.B) ---

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
    var results: Array[GachaBallInstance] = []
    for uuid in _battle_instances:
        var instance: GachaBallInstance = _battle_instances[uuid]
        if instance.location_container_tag == container_tag:
            results.append(instance)
    results.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)
    return results

func get_frontmost_target(is_player_attacking: bool) -> GachaBallInstance:
    var target_container_tag = "BATTLE_ENEMY_LINEUP" if is_player_attacking else "BATTLE_PLAYER_LINEUP"
    var potential_targets = get_instances_in_container(target_container_tag)
    potential_targets = potential_targets.filter(func(inst): return inst.current_hp > 0)
    if not potential_targets.is_empty():
        return potential_targets[0]
    return null

func get_player_hero() -> GachaBallInstance:
    for uuid in _battle_instances:
        var instance = _battle_instances[uuid]
        if instance.has_tag("HERO") and not instance.has_tag("ENEMY_HERO"):
            return instance
    return null

# --- Battle Setup ---

func _setup_battle():
    if is_instance_valid(GameManager.run_state):
        for uuid in GameManager.run_state.run_instances:
            var permanent_instance = GameManager.run_state.run_instances[uuid]
            if is_instance_valid(permanent_instance):
                var battle_copy = permanent_instance.create_battle_copy()
                var def = battle_copy.get_definition()
                if is_instance_valid(def):
                    battle_copy.location_container_tag = "BATTLE_DRAW_POOL_T%d" % def.tier
                    _battle_instances[battle_copy.ball_uuid] = battle_copy

    var player_hero_copy = GameManager.run_state.hero_instance.create_battle_copy()
    player_hero_copy.location_container_tag = "BATTLE_PLAYER_LINEUP"
    player_hero_copy.location_slot_index = 0
    _battle_instances[player_hero_copy.ball_uuid] = player_hero_copy

    _setup_enemy_lineup()
    
    for instance in _battle_instances.values():
        if is_instance_valid(instance) and instance.has_tag("UNIT"):
            instance.recalculate_stats(_battle_instances)

func _setup_enemy_lineup():
    var enemy_unit_defs = [Database.get_definition(&"enemy_hero"), Database.get_definition(&"unit_t1_a"), Database.get_definition(&"unit_t1_b"), Database.get_definition(&"unit_t2_c"), Database.get_definition(&"unit_t3_d")]
    var all_item_defs = Database.items.values()

    for i in range(min(enemy_unit_defs.size(), 6)):
        var unit_def = enemy_unit_defs[i]
        if not unit_def: continue
        
        var enemy_instance = GachaBallInstance.new()
        enemy_instance.initialize(unit_def)
        enemy_instance.location_container_tag = "BATTLE_ENEMY_LINEUP"
        enemy_instance.location_slot_index = i
        _battle_instances[enemy_instance.ball_uuid] = enemy_instance
        
        var item_slot_count = enemy_instance.get_definition().item_slot_count
        for j in range(item_slot_count):
            if not all_item_defs.is_empty():
                var item_def_to_equip = all_item_defs.pick_random()
                var item_instance = GachaBallInstance.new()
                item_instance.initialize(item_def_to_equip)
                item_instance.equipped_on_uuid = enemy_instance.ball_uuid
                item_instance.equipped_slot_index = j
                item_instance.location_container_tag = "EQUIPPED"
                _battle_instances[item_instance.ball_uuid] = item_instance

# --- State Machine & Game Flow ---

func _change_phase(new_phase: Phases):
    if _current_battle_phase == Phases.BATTLE_OVER: return
    _current_battle_phase = new_phase
    EventBus.emit_signal("battle_phase_changed", StringName(Phases.keys()[new_phase]))
    
    match _current_battle_phase:
        Phases.START_OF_TURN: await _enter_start_of_turn_phase()
        Phases.MANAGEMENT: pass
        Phases.COMBAT: await _enter_combat_phase()
        Phases.END_OF_TURN: _enter_end_of_turn_phase()

func _enter_start_of_turn_phase():
    _gacha_tokens = 5
    EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)
    _change_phase(Phases.MANAGEMENT)

func _enter_combat_phase():
    await _execute_combat_resolution()
    _change_phase(Phases.END_OF_TURN)

func _enter_end_of_turn_phase():
    if _is_battle_over():
        var player_hero = get_player_hero()
        var is_victory = is_instance_valid(player_hero) and player_hero.current_hp > 0
        _current_battle_phase = Phases.BATTLE_OVER
        WindowManager.open_end_battle_popup(is_victory)
    else:
        _change_phase(Phases.START_OF_TURN)

func _execute_combat_resolution():
    var player_lineup = get_instances_in_container("BATTLE_PLAYER_LINEUP")
    var enemy_lineup = get_instances_in_container("BATTLE_ENEMY_LINEUP")
    var basic_attack_def = Database.abilities.get(&"basic_attack")

    var all_combatants = player_lineup + enemy_lineup
    all_combatants.sort_custom(func(a,b): return a.location_slot_index > b.location_slot_index)

    for attacker in all_combatants:
        if attacker.current_hp <= 0: continue
        var is_player = attacker.location_container_tag == "BATTLE_PLAYER_LINEUP"
        var target = get_frontmost_target(is_player)
        if is_instance_valid(target):
            var ability_def = attacker.abilities[0] if not attacker.abilities.is_empty() else basic_attack_def
            if is_instance_valid(ability_def):
                AbilityResolver.enqueue_effect(ability_def.effect, attacker, [target], self)
                await get_tree().create_timer(0.2).timeout
                if _check_for_deaths() or _is_battle_over(): return

func _check_for_deaths() -> bool:
    var changed = false
    for uuid in _battle_instances.keys():
        var instance = _battle_instances.get(uuid)
        if is_instance_valid(instance) and instance.has_tag("UNIT") and instance.current_hp <= 0 and instance.location_container_tag != "BATTLE_DISCARD_PILE":
            instance.location_container_tag = "BATTLE_DISCARD_PILE"
            EventBus.emit_signal("instance_destroyed", uuid)
            changed = true
    return changed

func _is_battle_over():
    var enemies_alive = get_instances_in_container("BATTLE_ENEMY_LINEUP").filter(func(inst): return inst.current_hp > 0)
    var player_hero = get_player_hero()
    return enemies_alive.is_empty() or not is_instance_valid(player_hero) or player_hero.current_hp <= 0

func _on_end_turn_requested():
    if _current_battle_phase == Phases.MANAGEMENT:
        _change_phase(Phases.COMBAT)

func _on_draw_gacha_requested(tier: int):
    if _gacha_tokens < tier: return
    var draw_pool = get_instances_in_container("BATTLE_DRAW_POOL_T%d" % tier)
    if draw_pool.is_empty():
        var relevant_discards = get_instances_in_container("BATTLE_DISCARD_PILE").filter(func(inst): return inst.get_definition().tier == tier)
        for inst in relevant_discards:
            inst.location_container_tag = "BATTLE_DRAW_POOL_T%d" % tier
            EventBus.emit_signal("instance_location_changed", inst.ball_uuid)
        draw_pool = relevant_discards
        if draw_pool.is_empty(): return

    _gacha_tokens -= tier
    EventBus.emit_signal("gacha_tokens_changed", _gacha_tokens)

    var drawn_instance = draw_pool.pick_random()
    var target_container_tag = "BATTLE_PLAYER_BENCH" if drawn_instance.has_tag("UNIT") else "BATTLE_ITEM_INVENTORY"
    var target_container_instances = get_instances_in_container(target_container_tag)
    var occupied_slots = target_container_instances.map(func(inst): return inst.location_slot_index)
    var new_slot_index = 0
    while new_slot_index in occupied_slots: new_slot_index += 1
    
    if new_slot_index < 3: # Max slots for bench/item inventory
        drawn_instance.location_container_tag = target_container_tag
        drawn_instance.location_slot_index = new_slot_index
    else:
        drawn_instance.location_container_tag = "BATTLE_DISCARD_PILE"
    
    EventBus.emit_signal("instance_location_changed", drawn_instance.ball_uuid)
Use code with caution.
Prompt
Generated code
Use code with caution.
6. Phase 3: Interaction & Logic Controller Refactoring
Task 3.1: Refactor InventoryManager.gd with Explicit Validation
Prompt for AI Coder:
Generated prompt
Completely overhaul `scripts/InventoryManager.gd` to function as a stateless action controller with explicit validation logic. Replace the entire file content with the following code:

```gdscript
# res://scripts/InventoryManager.gd
extends Node

func _ready():
    EventBus.inventory_action_requested.connect(_on_inventory_action_requested)

func _on_inventory_action_requested(source_uuid: String, target_info: Dictionary):
    InteractionManager.clear_selection()

    var data_owner = GameManager.run_state if not GameManager.is_in_battle else get_tree().get_first_node_in_group("battle_manager")
    if not is_instance_valid(data_owner): return

    var all_instances = data_owner.run_instances if not GameManager.is_in_battle else data_owner.get_all_instances()
    var source_instance = all_instances.get(source_uuid)
    if not is_instance_valid(source_instance): return

    # Case 1: Target is an EMPTY SLOT
    if target_info.has("is_empty_slot"):
        if _is_valid_placement(source_instance, target_info.get("container_tag")):
            _handle_move(source_instance, target_info)
        return

    # Case 2: Target is ANOTHER INSTANCE
    var target_uuid = target_info.get("uuid")
    if source_uuid == target_uuid: return
    
    var target_instance = all_instances.get(target_uuid)
    if not is_instance_valid(target_instance): return

    if source_instance.has_tag("ITEM") and target_instance.has_tag("UNIT"):
        _handle_equip(source_instance, target_instance, all_instances)
        return
    
    var recipe = MergeManager.find_recipe(source_instance, target_instance)
    if is_instance_valid(recipe):
        _handle_merge(recipe, source_instance, target_instance, all_instances)
        return
        
    if _is_valid_placement(source_instance, target_instance.location_container_tag) and \
       _is_valid_placement(target_instance, source_instance.location_container_tag):
        _handle_swap(source_instance, target_instance)

func _is_valid_placement(instance: GachaBallInstance, target_container_tag: StringName) -> bool:
    if not is_instance_valid(instance): return false
    
    var is_unit = instance.has_tag("UNIT")
    var is_item = instance.has_tag("ITEM")
    
    if is_unit and target_container_tag == "BATTLE_ITEM_INVENTORY": return false
    if is_item and (target_container_tag == "BATTLE_PLAYER_LINEUP" or target_container_tag == "BATTLE_PLAYER_BENCH"): return false
    
    return true

func _handle_move(source_instance: GachaBallInstance, target_slot_info: Dictionary):
    source_instance.location_container_tag = target_slot_info.get("container_tag")
    source_instance.location_slot_index = target_slot_info.get("slot_index")
    source_instance.equipped_on_uuid = ""
    source_instance.equipped_slot_index = -1
    EventBus.emit_signal("instance_location_changed", source_instance.ball_uuid)

func _handle_swap(source_instance: GachaBallInstance, target_instance: GachaBallInstance):
    var temp_container = source_instance.location_container_tag
    var temp_index = source_instance.location_slot_index
    source_instance.location_container_tag = target_instance.location_container_tag
    source_instance.location_slot_index = target_instance.location_slot_index
    target_instance.location_container_tag = temp_container
    target_instance.location_slot_index = temp_index
    EventBus.emit_signal("instance_location_changed", source_instance.ball_uuid)
    EventBus.emit_signal("instance_location_changed", target_instance.ball_uuid)

func _handle_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance, all_instances: Dictionary):
    var equipped_items = all_instances.values().filter(func(inst): return inst.equipped_on_uuid == unit_instance.ball_uuid)
    var occupied_slots = equipped_items.map(func(item): return item.equipped_slot_index)
    var new_slot_index = -1
    for i in range(unit_instance.get_definition().item_slot_count):
        if not i in occupied_slots: new_slot_index = i; break
    if new_slot_index == -1: return

    item_instance.location_container_tag = "EQUIPPED"
    item_instance.location_slot_index = -1
    item_instance.equipped_on_uuid = unit_instance.ball_uuid
    item_instance.equipped_slot_index = new_slot_index
    
    unit_instance.recalculate_stats(all_instances)
    
    EventBus.emit_signal("instance_location_changed", item_instance.ball_uuid)
    EventBus.emit_signal("instance_data_changed", unit_instance.ball_uuid)

func _handle_merge(recipe: MergeRecipe, inst_a: GachaBallInstance, inst_b: GachaBallInstance, all_instances: Dictionary):
    var result_def = Database.get_definition(recipe.result_id)
    if not is_instance_valid(result_def): return
    
    var new_instance = GachaBallInstance.new()
    new_instance.initialize(result_def)

    var items_to_transfer = []
    for item in all_instances.values():
        if item.equipped_on_uuid == inst_a.ball_uuid or item.equipped_on_uuid == inst_b.ball_uuid:
            items_to_transfer.append(item)
    
    for i in range(min(items_to_transfer.size(), new_instance.get_definition().item_slot_count)):
        items_to_transfer[i].equipped_on_uuid = new_instance.ball_uuid
        items_to_transfer[i].equipped_slot_index = i
        EventBus.emit_signal("instance_location_changed", items_to_transfer[i].ball_uuid)

    new_instance.location_container_tag = inst_b.location_container_tag
    new_instance.location_slot_index = inst_b.location_slot_index
    all_instances[new_instance.ball_uuid] = new_instance
    
    all_instances.erase(inst_a.ball_uuid)
    all_instances.erase(inst_b.ball_uuid)
    
    new_instance.recalculate_stats(all_instances)

    EventBus.emit_signal("instance_created", new_instance.ball_uuid)
    EventBus.emit_signal("instance_destroyed", inst_a.ball_uuid)
    EventBus.emit_signal("instance_destroyed", inst_b.ball_uuid)
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 3.2: Refactor MergeManager.gd
Prompt for AI Coder:
Generated prompt
Refactor `scripts/MergeManager.gd` to be a simple, stateless recipe validation helper. Replace its entire content with the following code:

```gdscript
# res://scripts/MergeManager.gd
extends Node

## A dedicated, stateless helper to find a valid merge recipe.

func find_recipe(instance_a: GachaBallInstance, instance_b: GachaBallInstance) -> MergeRecipe:
    if not is_instance_valid(instance_a) or not is_instance_valid(instance_b):
        return null

    var def_a = instance_a.get_definition()
    var def_b = instance_b.get_definition()
    if not is_instance_valid(def_a) or not is_instance_valid(def_b):
        return null
        
    # A merge is only possible between two instances of the same category (UNIT or ITEM).
    if not def_a.tags.has("ITEM") or not def_b.tags.has("ITEM"):
        if not def_a.tags.has("UNIT") or not def_b.tags.has("UNIT"):
            return null

    for recipe_key in Database.recipes:
        var recipe: MergeRecipe = Database.recipes[recipe_key]
        
        if recipe.is_self_merge:
            if instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_a_id:
                return recipe
        else: # Check for A+B or B+A
            if (instance_a.definition_id == recipe.ingredient_a_id and instance_b.definition_id == recipe.ingredient_b_id) or \
               (instance_a.definition_id == recipe.ingredient_b_id and instance_b.definition_id == recipe.ingredient_a_id):
                return recipe
                
    return null
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 3.3: Refactor InteractionManager.gd
Prompt for AI Coder:
Generated prompt
Refactor `scripts/InteractionManager.gd` to align with the new UUID-based interaction model. Replace the entire file content with the following code:

```gdscript
# res://scripts/InteractionManager.gd
extends Node

var _selected_uuid: String = ""
var _selected_view: Control = null

var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null

func _ready():
    EventBus.close_modal_requested.connect(clear_selection)
    EventBus.main_scene_requested.connect(clear_selection)
    EventBus.battle_start_requested.connect(clear_selection)
    EventBus.inventory_action_requested.connect(func(_s, _t): clear_selection())

func select_view(view: Control, uuid: String):
    if not is_instance_valid(view) or uuid.is_empty():
        clear_selection()
        return

    if _selected_view == view: return

    if is_instance_valid(_selected_view): clear_selection()

    _selected_view = view
    _selected_uuid = uuid
    
    EventBus.emit_signal("view_selected", _selected_view, _selected_uuid)

func clear_selection():
    if is_instance_valid(_selected_view):
        var previously_selected_view = _selected_view
        _selected_view = null
        _selected_uuid = ""
        EventBus.emit_signal("view_deselected", previously_selected_view)

func get_selected_uuid() -> String:
    return _selected_uuid

func is_drag_active() -> bool:
    return _is_drag_active

func get_drag_source_view() -> Control:
    return _drag_source_view

func start_drag(source_view: Control, placeholder: Control):
    if not is_instance_valid(source_view): return
    clear_selection()
    _is_drag_active = true
    _drag_source_view = source_view
    _drag_placeholder = placeholder
    source_view.visible = false

func end_drag(was_handled: bool):
    if not _is_drag_active: return
    if not was_handled and is_instance_valid(_drag_source_view):
        _drag_source_view.visible = true
    if is_instance_valid(_drag_placeholder):
        _drag_placeholder.queue_free()
    _is_drag_active = false
    _drag_source_view = null
    _drag_placeholder = null

func cancel_active_drag():
    if _is_drag_active:
        end_drag(false)
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 3.4: Update EventBus.gd with New Signals
Prompt for AI Coder:
Generated prompt
Update `scripts/EventBus.gd` to use the new, granular state change signals from the TDD. Replace the entire content of the script with the following:

```gdscript
# res://scripts/EventBus.gd
extends Node

# --- Run/Scene Signals ---
signal start_run_requested
signal loadout_scene_requested
signal main_scene_requested
signal battle_start_requested
signal inspection_test_scene_requested
signal title_scene_requested

# --- Window/Modal Signals ---
signal inspect_inventory_requested
signal display_discard_pile_requested
signal close_modal_requested
signal background_clicked
signal global_background_clicked

# --- Action Signals ---
signal draw_gacha_requested(tier: int)
signal inventory_action_requested(source_uuid: String, target_info: Dictionary)
signal inspection_requested(source_view: Control)
signal end_turn_requested

# --- Selection Signals ---
signal view_selected(view: Control, uuid: String)
signal view_deselected(view: Control)
signal invalid_action_triggered(view: Control)

# --- State Change Signals (TDD Compliant) ---
signal instance_created(uuid: String)
signal instance_destroyed(uuid: String)
signal instance_location_changed(uuid: String) # For moves, swaps, equips
signal instance_data_changed(uuid: String)   # For stat changes, tag changes

signal battle_state_changed(is_in_battle: bool)
signal battle_phase_changed(phase_name: StringName)
signal gacha_tokens_changed(new_amount: int)
Use code with caution.
Prompt
Generated code
Use code with caution.
7. Phase 4: Presentation Layer Refactoring
Task 4.1: Refactor BattleView.gd to be a Reactive UI
Prompt for AI Coder:
Generated prompt
Refactor `scripts/BattleView.gd` to be a reactive UI that draws itself based on queries to the BattleManager. Replace the entire file content with the following code:

```gdscript
# res://scripts/BattleView.gd
class_name BattleView
extends Control

const GachaBallView = preload("res://scenes/GachaBallView.tscn")
const SlotView = preload("res://scenes/SlotView.tscn")

@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = %PlayerBench
@onready var item_inventory: HBoxContainer = %ItemInventory
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer
@onready var gacha_token_label: Label = %GachaTokenLabel
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton

var battle_manager: BattleManager

func _ready():
    battle_manager = get_node("BattleManager")
    if not is_instance_valid(battle_manager):
        printerr("BattleView CRITICAL: BattleManager node not found!")
        return

    # Connect to state change signals to trigger redraws
    EventBus.instance_created.connect(_on_state_changed)
    EventBus.instance_destroyed.connect(_on_state_changed)
    EventBus.instance_location_changed.connect(_on_state_changed)
    
    EventBus.gacha_tokens_changed.connect(_update_gacha_token_label)
    EventBus.battle_phase_changed.connect(_on_battle_phase_changed)
    
    end_turn_button.pressed.connect(func(): EventBus.emit_signal("end_turn_requested"))
    discard_pile_button.pressed.connect(func(): EventBus.emit_signal("display_discard_pile_requested"))
    
    # Initial draw
    _redraw_all()
    _update_gacha_token_label(battle_manager._gacha_tokens)

func _on_state_changed(_uuid: String):
    _redraw_all()

func _redraw_all():
    if not is_instance_valid(battle_manager): return

    _populate_container(player_lineup, "BATTLE_PLAYER_LINEUP", false, 6)
    _populate_container(player_bench, "BATTLE_PLAYER_BENCH", false, 3)
    _populate_container(item_inventory, "BATTLE_ITEM_INVENTORY", false, 3)
    _populate_container(enemy_lineup, "BATTLE_ENEMY_LINEUP", true, 6)

    var discard_pile = battle_manager.get_instances_in_container("BATTLE_DISCARD_PILE")
    discard_pile_button.text = "Discard Pile (%d)" % discard_pile.size()

func _populate_container(ui_container: HBoxContainer, container_tag: StringName, is_enemy: bool, max_slots: int):
    for child in ui_container.get_children():
        child.queue_free()

    var instances_in_container = battle_manager.get_instances_in_container(container_tag)
    var slot_map = {}
    for instance in instances_in_container:
        slot_map[instance.location_slot_index] = instance

    for i in range(max_slots):
        var view: Control
        if slot_map.has(i):
            var instance = slot_map[i]
            view = GachaBallView.instantiate()
            view.populate(instance.ball_uuid)
            if view.has_method("set_is_enemy"):
                view.set_is_enemy(is_enemy)
        else:
            view = SlotView.instantiate()
            view.populate_empty(container_tag, i)
        ui_container.add_child(view)

func _update_gacha_token_label(new_amount: int):
    gacha_token_label.text = "Tokens: %d" % new_amount

func _on_battle_phase_changed(phase_name: StringName):
    var is_management_phase = (phase_name == &"MANAGEMENT")
    end_turn_button.disabled = not is_management_phase
    
    var main_node = get_tree().get_root().find_child("Main", true, false)
    if not is_instance_valid(main_node): return
    
    var draw_buttons_parent = main_node.get_node_or_null("VBoxContainer/BottomArea/HBoxContainer")
    if is_instance_valid(draw_buttons_parent):
        for button in draw_buttons_parent.get_children():
            if button is Button and button.name.begins_with("DrawTier"):
                button.disabled = not is_management_phase
Use code with caution.
Prompt
Generated code
Use code with caution.
Task 4.2: Refactor GachaBallView.gd and SlotView.gd with Complete Code
Prompt for AI Coder:
Generated prompt
Refactor `scripts/GachaBallView.gd` and `scripts/SlotView.gd`. The previous plans were missing critical code. This version is complete.

**1. In `scripts/GachaBallView.gd`, replace the entire file content with this:**
```gdscript
# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel

var _instance_uuid: String
var _is_selected: bool = false

func _ready():
    EventBus.view_selected.connect(_on_view_selected)
    EventBus.view_deselected.connect(_on_view_deselected)
    EventBus.instance_data_changed.connect(_on_instance_data_changed)

func populate(uuid: String):
    _instance_uuid = uuid
    var instance = _get_instance_by_uuid(uuid)
    if not is_instance_valid(instance):
        visible = false
        return
    
    visible = true
    var definition = instance.get_definition()
    icon_rect.texture = definition.icon
    tier_label.text = "T%d" % definition.tier
    tooltip_text = tr(definition.display_name_key)
    
    _update_display(instance)

func set_is_enemy(is_enemy: bool):
    if is_instance_valid(icon_rect):
        icon_rect.flip_h = is_enemy

func _update_display(instance: GachaBallInstance):
    if not is_instance_valid(instance): return
    
    if instance.has_tag("UNIT"):
        hp_label.visible = true
        pwr_label.visible = true
        hp_label.text = "HP: %d" % instance.current_hp
        pwr_label.text = "PWR: %d" % instance.current_pwr
    else:
        hp_label.visible = false
        pwr_label.visible = false

    for child in item_grid.get_children():
        child.queue_free()
    
    var all_instances = _get_all_instances_db()
    if all_instances.is_empty(): return
    
    var equipped_items = all_instances.values().filter(func(i): return i.equipped_on_uuid == _instance_uuid)
    equipped_items.sort_custom(func(a,b): return a.equipped_slot_index < b.equipped_slot_index)

    for item_instance in equipped_items:
        var slot_panel = Panel.new()
        slot_panel.custom_minimum_size = Vector2(12, 12)
        var item_def = item_instance.get_definition()
        if is_instance_valid(item_def):
            var icon = TextureRect.new()
            icon.texture = item_def.icon
            icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            slot_panel.add_child(icon)
            icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        item_grid.add_child(slot_panel)

func _on_instance_data_changed(uuid: String):
    if _instance_uuid == uuid:
        var instance = _get_instance_by_uuid(uuid)
        if is_instance_valid(instance):
            _update_display(instance)

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        get_viewport().set_input_as_handled()
        if event.double_click:
            EventBus.emit_signal("inspection_requested", self)
            InteractionManager.clear_selection()
            return

        var selected_uuid = InteractionManager.get_selected_uuid()
        if not selected_uuid.is_empty() and selected_uuid != _instance_uuid:
            EventBus.emit_signal("inventory_action_requested", selected_uuid, {"uuid": _instance_uuid})
        else:
            InteractionManager.select_view(self, _instance_uuid)

func _get_drag_data(_at_position: Vector2):
    var placeholder = Control.new()
    placeholder.custom_minimum_size = self.size
    get_parent().add_child(placeholder)
    get_parent().move_child(placeholder, get_index())

    var preview = TextureRect.new()
    preview.texture = icon_rect.texture
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.custom_minimum_size = Vector2(64, 64)
    set_drag_preview(preview)
    
    InteractionManager.start_drag(self, placeholder)
    return {"source_uuid": _instance_uuid}

func _can_drop_data(_at_position, data) -> bool:
    return data is Dictionary and data.has("source_uuid")

func _drop_data(_at_position, data):
    EventBus.emit_signal("inventory_action_requested", data.source_uuid, {"uuid": _instance_uuid})

func _on_view_selected(view: Control, uuid: String):
    if view == self: _is_selected = true; _apply_selection_feedback()

func _on_view_deselected(view: Control):
    if view == self: _is_selected = false; _apply_selection_feedback()

func _apply_selection_feedback():
    if not is_inside_tree(): return
    var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
    if _is_selected:
        stylebox.border_color = Color.GOLD
        stylebox.border_width_left = 2
        stylebox.border_width_top = 2
        stylebox.border_width_right = 2
        stylebox.border_width_bottom = 2
    else:
        stylebox.border_width_left = 0
        stylebox.border_width_top = 0
        stylebox.border_width_right = 0
        stylebox.border_width_bottom = 0
    add_theme_stylebox_override("panel", stylebox)

func _notification(what: int):
    if what == NOTIFICATION_DRAG_END:
        if InteractionManager.is_drag_active() and InteractionManager.get_drag_source_view() == self:
            InteractionManager.end_drag(false)

func _get_all_instances_db() -> Dictionary:
    if GameManager.is_in_battle:
        var bm = get_tree().get_first_node_in_group("battle_manager")
        return bm.get_all_instances() if is_instance_valid(bm) else {}
    return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _get_instance_by_uuid(uuid: String) -> GachaBallInstance:
    return _get_all_instances_db().get(uuid)
Use code with caution.
Prompt
2. In scripts/SlotView.gd, replace the entire file content with this:
Generated gdscript
# res://scripts/SlotView.gd
class_name SlotView
extends PanelContainer

var _container_tag: StringName
var _slot_index: int

func _ready():
    var style = StyleBoxFlat.new()
    style.set_bg_color(Color(0,0,0,0.2))
    style.set_border_width_all(1)
    style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
    add_theme_stylebox_override("panel", style)

func populate_empty(container_tag: StringName, slot_index: int):
    _container_tag = container_tag
    _slot_index = slot_index

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        get_viewport().set_input_as_handled()
        var selected_uuid = InteractionManager.get_selected_uuid()
        if not selected_uuid.is_empty():
            var target_info = {
                "is_empty_slot": true,
                "container_tag": _container_tag,
                "slot_index": _slot_index
            }
            EventBus.emit_signal("inventory_action_requested", selected_uuid, target_info)

func _can_drop_data(_at_position, data) -> bool:
    return data is Dictionary and data.has("source_uuid")

func _drop_data(_at_position, data):
    var target_info = {
        "is_empty_slot": true,
        "container_tag": _container_tag,
        "slot_index": _slot_index
    }
    EventBus.emit_signal("inventory_action_requested", data.source_uuid, target_info)