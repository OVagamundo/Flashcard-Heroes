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
	if gbd.is_hero:
		return true
	var id_str = String(gbd.id).to_lower()
	if id_str == "hero" or id_str.begins_with("hero_"):
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

static func get_ordered_run_state_instances() -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var seen: Dictionary = {}
	if not is_instance_valid(GameManager.run_state):
		return result
		
	var containers_to_check: Array[StringName] = [
		RunState.RUN_CONTAINER_TAGS.PLAYER_LINEUP,
		RunState.RUN_CONTAINER_TAGS.PLAYER_BENCH,
		&"RunInventoryT1",
		&"RunInventoryT2",
		&"RunInventoryT3",
		RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	]
	
	for cname in containers_to_check:
		var container = GameManager.run_state.get_container(cname)
		if is_instance_valid(container):
			for uuid in container.get_all_uuids():
				if not uuid.is_empty() and not seen.has(uuid):
					var inst = GameManager.run_state.get_instance_by_uuid(uuid)
					if is_instance_valid(inst):
						result.append(inst)
						seen[uuid] = true
						for eq_uuid in inst.equipped_item_uuids:
							if not eq_uuid.is_empty() and not seen.has(eq_uuid):
								var eq_inst = GameManager.run_state.get_instance_by_uuid(eq_uuid)
								if is_instance_valid(eq_inst):
									result.append(eq_inst)
									seen[eq_uuid] = true
									
	var all_insts: Dictionary = GameManager.run_state.get_all_instances()
	for uuid in all_insts.keys():
		if not seen.has(uuid):
			var inst = all_insts[uuid]
			var def_id = inst.definition_id if is_instance_valid(inst) else "unknown"
			push_warning("BattleSetup: ignoring unplaced run instance %s (%s) not found in any container" % [uuid, def_id])
			
	return result

static func setup_from_run_state(state: BattleState) -> void:
	var permanent_to_battle_uuid_map: Dictionary = {}
	var battle_copies: Dictionary = {}
	var run_state_instances: Array[GachaBallInstance] = get_ordered_run_state_instances()

	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		if is_trinket_definition(def):
			continue
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc):
			continue

		var battle_copy: GachaBallInstance = perm_inst.create_battle_copy()
		if not is_instance_valid(battle_copy):
			continue
		battle_copies[battle_copy.ball_uuid] = battle_copy
		permanent_to_battle_uuid_map[perm_inst.ball_uuid] = battle_copy.ball_uuid

	# Remap equipped item links between battle copies before registering into BattleState
	for battle_uuid in battle_copies.keys():
		var battle_inst: GachaBallInstance = battle_copies[battle_uuid]
		if battle_inst.get_definition().category != &"UNIT":
			continue
		var original_equipped_uuids = battle_inst.equipped_item_uuids.duplicate()
		battle_inst.equipped_item_uuids.clear()
		battle_inst.equipped_item_uuids.resize(original_equipped_uuids.size())
		battle_inst.equipped_item_uuids.fill("")
		for i in range(original_equipped_uuids.size()):
			var permanent_item_uuid: String = original_equipped_uuids[i]
			if not permanent_item_uuid.is_empty() and permanent_to_battle_uuid_map.has(permanent_item_uuid):
				var battle_item_uuid: String = permanent_to_battle_uuid_map[permanent_item_uuid]
				var item_instance: GachaBallInstance = battle_copies.get(battle_item_uuid)
				if is_instance_valid(item_instance):
					battle_inst.equipped_item_uuids[i] = battle_item_uuid
					item_instance.equipped_on_uuid = battle_inst.ball_uuid
					item_instance.equipped_slot_index = i
					item_instance.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
					item_instance.location_slot_index = i

	for battle_uuid in battle_copies.keys():
		var battle_inst: GachaBallInstance = battle_copies[battle_uuid]
		var battle_def = battle_inst.get_definition()
		if is_instance_valid(battle_def) and battle_def.category == &"UNIT":
			battle_inst.current_hp = battle_inst.get_effective_starting_hp(battle_copies)
			battle_inst.current_pwr = battle_inst.get_effective_starting_pwr(battle_copies)

	# Atomically place copies into BattleState containers (or stage hero for entrance)
	for perm_inst in run_state_instances:
		var def = perm_inst.get_definition()
		if is_trinket_definition(def):
			continue
		var perm_loc = GameManager.run_state.get_location_for_uuid(perm_inst.ball_uuid)
		if not is_instance_valid(perm_loc):
			continue

		var battle_uuid: String = permanent_to_battle_uuid_map.get(perm_inst.ball_uuid, "")
		if battle_uuid.is_empty():
			continue
		var battle_copy: GachaBallInstance = battle_copies.get(battle_uuid)
		if not is_instance_valid(battle_copy):
			continue

		# Equipped items are registered atomically alongside their parent unit
		if not battle_copy.equipped_on_uuid.is_empty():
			continue

		if is_hero_definition(def):
			var hero_pos: int = perm_loc.index if perm_loc.container == RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP else 0
			var hero_items: Array[GachaBallInstance] = []
			for eq_uuid in battle_copy.equipped_item_uuids:
				if not eq_uuid.is_empty() and battle_copies.has(eq_uuid):
					hero_items.append(battle_copies[eq_uuid])
			state.staged_hero_placement = {
				"uuid": battle_copy.ball_uuid,
				"position": hero_pos
			}
			state.staged_hero_instance = battle_copy
			state.staged_hero_items = hero_items
			continue

		var target_container_name: StringName
		var target_index: int = -1
		var perm_container_str := String(perm_loc.container)
		if perm_container_str.begins_with("RunInventoryT"):
			assert(is_instance_valid(def), "BattleSetup: instance %s definition missing" % perm_inst.ball_uuid)
			target_container_name = &"BattleInventoryT%d" % int(def.get("tier"))
			target_index = -1
		else:
			match perm_loc.container:
				RS.RUN_CONTAINER_TAGS.PLAYER_LINEUP:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
					target_index = perm_loc.index
				RS.RUN_CONTAINER_TAGS.PLAYER_BENCH:
					target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
					target_index = perm_loc.index
				_:
					assert(false, "BattleSetup: unhandled container %s for %s" % [perm_loc.container, perm_inst.ball_uuid])
					continue

		var added: bool = state.bm_add_instance(battle_copy, target_container_name, target_index)
		assert(added, "BattleSetup: failed to place %s into %s:%d" % [battle_copy.ball_uuid, String(target_container_name), target_index])
		for eq_uuid in battle_copy.equipped_item_uuids:
			if not eq_uuid.is_empty() and battle_copies.has(eq_uuid):
				state.register_instance(battle_copies[eq_uuid])

static func stage_enemy_lineup(state: RefCounted, encounter_def: Resource) -> void:
	if not is_instance_valid(encounter_def):
		return
	
	var placements = encounter_def.get("enemy_placements")
	if not placements is Array:
		return
		
	state.staged_enemy_placements.clear()
	for placement in placements:
		var unit_id = placement.get("id", placement.get("unit_id", ""))
		var unit_def = Database.get_definition(unit_id)
		if not is_instance_valid(unit_def):
			continue
			
		var pos = placement.get("position", 0)
		var scale: float = 1.0
		if encounter_def.has_meta("elite_stat_scale") and pos == 4:
			var id_str = String(unit_id)
			if not id_str.contains("unit_dust_elite"):
				scale = float(encounter_def.get_meta("elite_stat_scale"))
		
		var equipment = placement.get("equipment", placement.get("items", []))
		state.staged_enemy_placements.append({
			"id": unit_id,
			"position": pos,
			"equipment": equipment,
			"elite_stat_scale": scale
		})

static func setup_enemy_lineup(state: BattleState, encounter_def: Resource) -> void:
	if not is_instance_valid(encounter_def):
		return

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

		var pos: int = int(placement.get("position", 0))
		if encounter_def.has_meta("elite_stat_scale") and pos == 4:
			var id_str = String(unit_id)

			# Dust Elites use their own internal growth and should not be externally scaled
			if not id_str.contains("unit_dust_elite"):
				var scale: float = encounter_def.get_meta("elite_stat_scale")
				enemy_inst.current_hp = maxi(1, int(floor(enemy_inst.current_hp * scale)))
				enemy_inst.current_pwr = maxi(1, int(floor(enemy_inst.current_pwr * scale)))

		var added: bool = state.bm_add_instance(enemy_inst, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP, pos)
		assert(added, "BattleSetup: failed to place enemy %s at EnemyLineup:%d" % [enemy_inst.ball_uuid, pos])

		var equipment = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			var item_id = item_data if item_data is StringName or item_data is String else item_data.get("id", "")
			var item_def = Database.get_definition(item_id)
			if not is_instance_valid(item_def):
				continue

			var item_inst = GachaBallInstance.new()
			item_inst.initialize(item_def)
			var eq_res := InventoryOperations.register_and_equip_item(state, item_inst, enemy_inst.ball_uuid)
			if not eq_res.success:
				push_warning("BattleSetup: failed to equip static item %s on %s" % [item_id, enemy_inst.ball_uuid])

static func setup_enemy_trinkets(state: BattleState, encounter_def: Resource) -> void:
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
		if not is_instance_valid(trinket_def) or trinket_def.get("is_player_exclusive") == true:
			continue
		var trinket_inst := GachaBallInstance.new()
		trinket_inst.initialize_from_trinket(trinket_def)
		var added: bool = state.bm_add_instance(trinket_inst, C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, slot_index)
		assert(added, "BattleSetup: failed to place enemy trinket %s at slot %d" % [trinket_inst.ball_uuid, slot_index])
		state.enemy_trinkets.append(trinket_inst)
		slot_index += 1

static func _append_missing_enemy_trait_trinkets(encounter_def: Resource, trinket_ids: Array, max_slots: int) -> void:
	var trait_counts: Dictionary = {}
	for t in C.TRAIT_SORT_ORDER:
		trait_counts[t] = 0

	var placements = encounter_def.get("enemy_placements")
	if not placements is Array:
		return

	for placement in placements:
		var unit_def = Database.get_definition(placement.get("id", placement.get("unit_id", "")))
		_accumulate_trait_souls(trait_counts, unit_def)
		var equipment = placement.get("equipment", placement.get("items", []))
		for item_data in equipment:
			var item_id = item_data if item_data is StringName or item_data is String else item_data.get("id", "")
			var item_def = Database.get_definition(item_id)
			_accumulate_trait_souls(trait_counts, item_def)

	for trait_name in C.TRAIT_SORT_ORDER:
		if trinket_ids.size() >= max_slots:
			break
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
		var levels: Array = trait_def.get("levels", [])
		if levels.is_empty():
			continue
		var min_required := int(levels[0].get("min", 999))
		if int(trait_counts.get(trait_name, 0)) < min_required:
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
				counts["FIRE"] = counts.get("FIRE", 0) + 1
			&"SOUL_EARTH":
				counts["EARTH"] = counts.get("EARTH", 0) + 1
			&"SOUL_WATER":
				counts["WATER"] = counts.get("WATER", 0) + 1
			&"SOUL_AIR":
				counts["AIR"] = counts.get("AIR", 0) + 1
			_:
				var upper = String(tag).to_upper()
				if counts.has(upper):
					counts[upper] = counts.get(upper, 0) + 1


static func setup_player_trinkets(state: BattleState) -> void:
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
		if slot_index >= pt_container.get_size():
			break
		var added: bool = state.bm_add_instance(battle_trinket, C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS, slot_index)
		assert(added, "BattleSetup: failed to place player trinket %s at slot %d" % [battle_trinket.ball_uuid, slot_index])
		slot_index += 1
