# res://scripts/battle/BattleSetup.gd
class_name BattleSetup
extends RefCounted

## BattleSetup encapsulates battle initialization logic.
## Responsible for creating battle copies of units from RunState and placing them.

const RS = preload("res://scripts/RunState.gd")
const C = preload("res://scripts/Constants.gd")
# EncounterDefinition is a global class, no preload needed

# ============================================================================
# HELPER UTILITIES
# ============================================================================

static func is_hero_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	var id_str = String(def.id).to_lower()
	if id_str == "hero":
		return true
	if def is GachaBallDefinition:
		var gbd = def as GachaBallDefinition
		if gbd.tags and gbd.tags.has("hero"):
			return true
	return false

static func is_trinket_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	return def.category == &"TRINKET"

static func is_unit_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	return def.category == &"UNIT"

# ============================================================================
# SETUP FROM RUN STATE
# ============================================================================

## Create battle copies of all instances from run state and place them in battle containers.
## Returns dictionary mapping permanent UUIDs to battle UUIDs.
static func create_battle_copies_from_run_state(state: BattleState) -> Dictionary:
	var permanent_to_battle_uuid_map: Dictionary = {}
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()

	# First pass: Create all battle copies and map their new UUIDs
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = is_hero_definition(def)
		
		if is_hero:
			var hero_battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
			if is_instance_valid(hero_battle_copy):
				state.register_instance(hero_battle_copy)
				permanent_to_battle_uuid_map[perm_inst.ball_uuid] = hero_battle_copy.ball_uuid
			continue
		
		# Skip trinkets - they don't need battle copies
		if is_trinket_definition(def):
			continue
			
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy):
			continue
		state.register_instance(battle_copy)
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

	# Second pass: Remap equipped item UUIDs on all battle copies
	for battle_uuid in state.get_all_instances():
		var battle_inst = state.get_instance(battle_uuid)
		if battle_inst.get_definition().category != &"UNIT":
			continue
		var original_equipped_uuids = battle_inst.equipped_item_uuids.duplicate()
		battle_inst.equipped_item_uuids.clear()
		battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())
		battle_inst.equipped_item_uuids.fill("")
		for i in range(original_equipped_uuids.size()):
			var permanent_item_uuid = original_equipped_uuids[i]
			if not permanent_item_uuid.is_empty() and permanent_to_battle_uuid_map.has(permanent_item_uuid):
				var battle_item_uuid: String = permanent_to_battle_uuid_map[permanent_item_uuid]
				battle_inst.equipped_item_uuids[i] = battle_item_uuid
				var item_instance: GachaBallInstance = state.get_instance(battle_item_uuid)
				if is_instance_valid(item_instance):
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i

	return permanent_to_battle_uuid_map

## Place battle copies in their correct containers based on run state locations.
static func place_instances_from_run_state(state: BattleState, permanent_to_battle_uuid_map: Dictionary) -> void:
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()
	
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = is_hero_definition(def)
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc):
			continue
			
		if is_hero:
			var hero_battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid, "")
			if hero_battle_uuid:
				var hero_container = state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
				hero_container.set_uuid(0, hero_battle_uuid)
				state.update_instance_location(hero_battle_uuid, C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, 0)
			continue
		
		if is_trinket_definition(def):
			continue
			
		var battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid, "")
		if not battle_uuid:
			continue
		var battle_copy = state.get_instance(battle_uuid)
		
		# Skip equipped items
		if not battle_copy.equipped_on_uuid.is_empty():
			continue
			
		var target_container_name: StringName
		if perm_loc.container.begins_with("RunInventoryT"):
			var perm_def = perm_inst.get_definition()
			if perm_def is GachaBallDefinition:
				var tier = perm_def.tier
				target_container_name = &"BattleInventoryT%d" % tier
			else:
				continue
		else:
			match perm_loc.container:
				RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
				RS.RUN_CONTAINER_TAGS.PLAYER_BENCH:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
				RS.RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
				_:
					continue

		var container: DataContainer = state.get_container(target_container_name)
		var index = perm_loc.index
		container.set_uuid(index, battle_copy.ball_uuid)
		state.update_instance_location(battle_copy.ball_uuid, target_container_name, index)

## Setup enemy lineup from encounter definition
static func setup_enemy_lineup(state: BattleState, encounter_def: EncounterDefinition) -> void:
	if not is_instance_valid(encounter_def):
		_setup_fallback_enemy_lineup(state)
		return
	
	var lineup_container = state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	for placement in encounter_def.enemy_placements:
		var unit_id = placement.get("id", placement.get("unit_id", ""))
		var unit_def = Database.get_definition(unit_id)
		if not is_instance_valid(unit_def):
			continue
			
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		state.register_instance(enemy_inst)
		
		# Equip items
		var equipment = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			var item_id = item_data if item_data is StringName or item_data is String else item_data.get("id", "")
			var item_def = Database.get_definition(item_id)
			if not is_instance_valid(item_def):
				continue
				
			var item_inst = GachaBallInstance.new()
			item_inst.initialize(item_def)
			state.register_instance(item_inst)
			
			# Perform atomic equip
			_perform_static_equip(item_inst, enemy_inst)
		
		lineup_container.set_uuid(placement.position, enemy_inst.ball_uuid)
		state.update_instance_location(enemy_inst.ball_uuid, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, placement.position)

static func _setup_fallback_enemy_lineup(state: BattleState) -> void:
	# Fallback to hardcoded enemy lineup for testing or broken encounters
	var enemy_unit_ids = [&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d", &"enemy_hero"]
	var lineup_container = state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	
	for i in range(min(enemy_unit_ids.size(), 5)):
		var unit_def = Database.get_definition(enemy_unit_ids[i])
		if not is_instance_valid(unit_def):
			continue
		
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		state.register_instance(enemy_inst)
		
		lineup_container.set_uuid(i, enemy_inst.ball_uuid)
		state.update_instance_location(enemy_inst.ball_uuid, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, i)

static func _perform_static_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
	var empty_slot_idx: int = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
		item_instance.equipped_on_uuid = unit_instance.ball_uuid
		item_instance.equipped_slot_index = empty_slot_idx
		
		# Apply the item's stat bonuses to the unit
		unit_instance.equip_item_bonus(item_instance)

## Setup enemy trinkets from encounter definition
static func setup_enemy_trinkets(state: BattleState, encounter_def: EncounterDefinition) -> void:
	if not is_instance_valid(encounter_def):
		return
	
	var et_container := state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	if not is_instance_valid(et_container):
		return
	
	var slot_index := 0
	for trinket_id in encounter_def.enemy_trinket_ids:
		var trinket_def = Database.get_definition(trinket_id)
		if not is_instance_valid(trinket_def):
			continue
		var trinket_inst := GachaBallInstance.new()
		trinket_inst.initialize_from_trinket(trinket_def)
		state.register_instance(trinket_inst)
		et_container.set_uuid(slot_index, trinket_inst.ball_uuid)
		state.update_instance_location(trinket_inst.ball_uuid, C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, slot_index)
		state.enemy_trinkets.append(trinket_inst)
		slot_index += 1

## Setup player trinkets from run state
static func setup_player_trinkets(state: BattleState) -> void:
	if not is_instance_valid(GameManager.run_state):
		return
	
	var pt_container := state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
	var slot_index := 0
	
	for perm_inst in GameManager.run_state.get_all_instances().values():
		var def = perm_inst.get_definition()
		if not is_trinket_definition(def):
			continue
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc):
			continue
		if perm_loc.container != RS.RUN_CONTAINER_TAGS.PLAYER_TRINKETS:
			continue
		
		var battle_trinket: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_trinket):
			continue
		state.register_instance(battle_trinket)
		pt_container.set_uuid(slot_index, battle_trinket.ball_uuid)
		state.update_instance_location(battle_trinket.ball_uuid, C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, slot_index)
		slot_index += 1
