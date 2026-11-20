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
		RunState.RUN_CONTAINER_TAGS.PLAYER_SHELF,
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
				RS.RUN_CONTAINER_TAGS.PLAYER_SHELF:
					if perm_loc.index < C.PLAYER_SHELF_CAP:
						target_container_name = C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
						target_index = perm_loc.index
					else:
						# Run saves can use the last Shelf slot, which the tray occupies in battle.
						target_container_name = &"BattleInventoryT%d" % def.tier
				_:
					assert(false, "BattleSetup: unhandled container %s for %s" % [perm_loc.container, perm_inst.ball_uuid])
					continue

		var added: bool = state.bm_add_instance(battle_copy, target_container_name, target_index, true)
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
			
		var pos: int = int(placement.get("position", 0))
		var equipment = placement.get("equipment", placement.get("items", []))
		state.staged_enemy_placements.append({
			"id": unit_id,
			"position": pos,
			"level": int(placement.get("level", 1)),
			"bonus_hp": int(placement.get("bonus_hp", 0)),
			"bonus_pwr": int(placement.get("bonus_pwr", 0)),
			"equipment": equipment
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

		var enemy_inst := GachaBallInstance.new()
		enemy_inst.initialize(unit_def)

		var unit_level: int = int(placement.get("level", 1))
		if unit_level > 1:
			enemy_inst.set_unit_level(unit_level)
		var b_hp: int = int(placement.get("bonus_hp", 0))
		var b_pwr: int = int(placement.get("bonus_pwr", 0))
		if b_hp != 0 or b_pwr != 0:
			enemy_inst.apply_encounter_stat_bonus(b_hp, b_pwr)

		var pos: int = int(placement.get("position", 0))
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
	var encounter: EncounterDefinition = encounter_def as EncounterDefinition
	assert(encounter != null, "BattleSetup requires an EncounterDefinition")
	var et_container: DataContainer = state.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	var banner_id: StringName = encounter.banner_trinket_id
	var trinket_definitions: Array[TrinketDefinition] = []
	for trinket_id: StringName in encounter.enemy_trinket_ids:
		var trinket_def: TrinketDefinition = Database.get_definition(trinket_id) as TrinketDefinition
		assert(trinket_def != null and not trinket_def.is_player_exclusive, "Invalid enemy trinket: %s" % trinket_id)
		# Normalize legacy saved encounters at the setup boundary.
		if trinket_def.is_banner:
			assert(banner_id.is_empty() or banner_id == trinket_id, "Encounter contains conflicting banners")
			banner_id = trinket_id
			continue
		trinket_definitions.append(trinket_def)
	# Register the commander first to preserve the existing ability ordering.
	if not banner_id.is_empty():
		var banner_def: TrinketDefinition = Database.get_definition(banner_id) as TrinketDefinition
		assert(banner_def != null and banner_def.is_banner and banner_def.is_enemy_exclusive, "Invalid encounter banner: %s" % banner_id)
		var banner: GachaBallInstance = GachaBallInstance.new()
		banner.initialize_from_trinket(banner_def)
		var added: bool = state.bm_add_instance(banner, C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER, 0)
		assert(added, "BattleSetup: failed to place encounter banner %s" % banner_id)
	assert(trinket_definitions.size() <= et_container.get_size(), "Encounter exceeds enemy trinket capacity")
	for slot_index: int in range(trinket_definitions.size()):
		var trinket_inst: GachaBallInstance = GachaBallInstance.new()
		trinket_inst.initialize_from_trinket(trinket_definitions[slot_index])
		var added: bool = state.bm_add_instance(trinket_inst, C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, slot_index)
		assert(added, "BattleSetup: failed to place enemy trinket %s at slot %d" % [trinket_inst.ball_uuid, slot_index])
		state.enemy_trinkets.append(trinket_inst)


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
