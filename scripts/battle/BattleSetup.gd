# res://scripts/battle/BattleSetup.gd
class_name BattleSetup
extends RefCounted

## BattleSetup encapsulates battle initialization logic.

const RS = preload("res://scripts/RunState.gd")
const C = preload("res://scripts/Constants.gd")

# ============================================================================
# HELPER UTILITIES
# ============================================================================

static func is_hero_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	if not def is GachaBallDefinition:
		return false
	var gbd := def as GachaBallDefinition
	var id_str = String(gbd.id).to_lower()
	if id_str == "hero":
		return true
	if gbd.tags.has(&"hero"):
		return true
	return false

static func is_trinket_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	return def is TrinketDefinition or def.get("category") == &"TRINKET"

static func is_unit_definition(def: Resource) -> bool:
	if not is_instance_valid(def):
		return false
	if not def is GachaBallDefinition:
		return false
	return (def as GachaBallDefinition).category == &"UNIT"

# ============================================================================
# SETUP FROM RUN STATE
# ============================================================================

static func create_battle_copies_from_run_state(state: RefCounted) -> Dictionary:
	var permanent_to_battle_uuid_map: Dictionary = {}
	var run_state_instances: Array = GameManager.run_state.get_all_instances().values()

	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		var is_hero = is_hero_definition(def)
		
		if is_hero:
			var hero_battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
			if is_instance_valid(hero_battle_copy):
				state.register_instance(hero_battle_copy)
				permanent_to_battle_uuid_map[perm_inst.ball_uuid] = hero_battle_copy.ball_uuid
			continue
		
		if is_trinket_definition(def):
			continue
			
		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy):
			continue
		state.register_instance(battle_copy)
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

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

static func place_instances_from_run_state(state: RefCounted, permanent_to_battle_uuid_map: Dictionary) -> void:
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
		var perm_container_str = String(perm_loc.container)
		if perm_container_str.begins_with("RunInventoryT"):
			var perm_def = perm_inst.get_definition()
			if is_instance_valid(perm_def):
				var tier = perm_def.get("tier")
				target_container_name = &"BattleInventoryT%d" % tier
			else:
				continue
		else:
			match perm_loc.container:
				RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
				RS.RUN_CONTAINER_TAGS.PLAYER_BENCH:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
				_:
					continue

		var container = state.get_container(target_container_name)
		var index: int
		if String(target_container_name).begins_with("BattleInventoryT"):
			index = container.find_first_empty_slot()
			if index == -1:
				continue
		else:
			index = perm_loc.index
		container.set_uuid(index, battle_copy.ball_uuid)
		state.update_instance_location(battle_copy.ball_uuid, target_container_name, index)

static func setup_enemy_lineup(state: RefCounted, encounter_def: Resource) -> void:
	if not is_instance_valid(encounter_def):
		return
	
	var lineup_container = state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var placements = encounter_def.get("enemy_placements")
	if not placements is Array:
		return
		
	for placement in placements:
		var unit_id = placement.get("id", placement.get("unit_id", ""))
		var unit_def = Database.get_definition(unit_id)
		if not is_instance_valid(unit_def):
			continue
			
		var enemy_inst = GachaBallInstance.new()
		enemy_inst.initialize(unit_def)
		
		var pos = placement.get("position")
		if encounter_def.has_meta("elite_stat_scale") and pos == 4:
			var id_str = String(unit_id)
			
			# Dust Elites use their own internal growth and should not be externally scaled
			if not id_str.contains("unit_dust_elite"):
				var scale: float = encounter_def.get_meta("elite_stat_scale")
				enemy_inst.current_hp = maxi(1, int(floor(enemy_inst.current_hp * scale)))
				enemy_inst.current_pwr = maxi(1, int(floor(enemy_inst.current_pwr * scale)))
			
		state.register_instance(enemy_inst)
		
		var equipment = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			var item_id = item_data if item_data is StringName or item_data is String else item_data.get("id", "")
			var item_def = Database.get_definition(item_id)
			if not is_instance_valid(item_def):
				continue
				
			var item_inst = GachaBallInstance.new()
			item_inst.initialize(item_def)
			state.register_instance(item_inst)
			_perform_static_equip(item_inst, enemy_inst)
		
		lineup_container.set_uuid(pos, enemy_inst.ball_uuid)
		state.update_instance_location(enemy_inst.ball_uuid, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, pos)

static func _perform_static_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
	var empty_slot_idx: int = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
		item_instance.equipped_on_uuid = unit_instance.ball_uuid
		item_instance.equipped_slot_index = empty_slot_idx
		unit_instance.equip_item_bonus(item_instance)

static func setup_enemy_trinkets(state: RefCounted, encounter_def: Resource) -> void:
	if not is_instance_valid(encounter_def):
		return
	var et_container = state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	if not is_instance_valid(et_container):
		return
	var slot_index := 0
	var trinket_ids: Array = []
	var encounter_trinket_ids = encounter_def.get("enemy_trinket_ids")
	if encounter_trinket_ids is Array:
		trinket_ids.assign(encounter_trinket_ids)
	_append_missing_enemy_trait_trinkets(encounter_def, trinket_ids, et_container.get_size())
	for trinket_id in trinket_ids:
		if slot_index >= et_container.get_size():
			break
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

static func _append_missing_enemy_trait_trinkets(encounter_def: Resource, trinket_ids: Array, max_slots: int) -> void:
	var soul_counts := {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	var placements = encounter_def.get("enemy_placements")
	if not placements is Array:
		return

	for placement in placements:
		var unit_def = Database.get_definition(placement.get("id", placement.get("unit_id", "")))
		_accumulate_trait_souls(soul_counts, unit_def)
		var equipment = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			var item_id = item_data if item_data is StringName or item_data is String else item_data.get("id", "")
			var item_def = Database.get_definition(item_id)
			_accumulate_trait_souls(soul_counts, item_def)

	for trait_name in C.TRAIT_SORT_ORDER:
		if trinket_ids.size() >= max_slots:
			break
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
		var levels: Array = trait_def.get("levels", [])
		if levels.is_empty():
			continue
		var min_required := int(levels[0].get("min", 999))
		if int(soul_counts.get(trait_name, 0)) < min_required:
			continue
		var trinket_id: StringName = trait_def.get("trinket_id", &"")
		if trinket_id == &"" or trinket_ids.has(trinket_id):
			continue
		trinket_ids.append(trinket_id)

static func _accumulate_trait_souls(counts: Dictionary, definition: Resource) -> void:
	if not is_instance_valid(definition) or not ("tags" in definition):
		return
	for tag in definition.tags:
		match tag:
			&"SOUL_FIRE":
				counts["FIRE"] += 1
			&"SOUL_EARTH":
				counts["EARTH"] += 1
			&"SOUL_WATER":
				counts["WATER"] += 1
			&"SOUL_AIR":
				counts["AIR"] += 1

static func setup_player_trinkets(state: RefCounted) -> void:
	if not is_instance_valid(GameManager.run_state):
		return
	var pt_container = state.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
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
