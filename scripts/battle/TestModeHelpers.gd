# res://scripts/battle/TestModeHelpers.gd
class_name TestModeHelpers
extends RefCounted

const C = preload("res://scripts/Constants.gd")

## Static helper functions for test mode.
## Extracted from BattleManager to reduce main file complexity.
## All functions take a BattleManager reference as first parameter.

# Note: BattleManager container tags accessed via C.BATTLE_CONTAINER_TAGS

## Register a unit for test mode using the same logic as _setup_enemy_lineup().
## Guarantees 100% parity with real battle initialization.
static func register_test_unit(bm, unit_def_id: StringName, is_enemy: bool, position: int = -1) -> GachaBallInstance:
	var unit_def: GachaBallDefinition = Database.get_definition(unit_def_id)
	if not is_instance_valid(unit_def):
		push_warning("[TestMode] Unit definition not found: %s" % unit_def_id)
		return null
	
	var container_tag: StringName = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_enemy else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var lineup_container: DataContainer = bm.get_container(container_tag)
	if not is_instance_valid(lineup_container):
		push_warning("[TestMode] Missing lineup container: %s" % container_tag)
		return null
	
	# Find position if not specified
	var slot: int = position
	if slot < 0:
		slot = lineup_container.find_first_empty_slot()
		if slot == -1:
			push_warning("[TestMode] No empty slots in lineup")
			return null
	
	# Create instance and register via the same atomic battle API used by gameplay.
	var unit_inst: GachaBallInstance = GachaBallInstance.new()
	unit_inst.initialize(unit_def)
	if not bm.bm_add_instance(unit_inst, container_tag, slot):
		push_warning("[TestMode] Failed to register unit via bm_add_instance: %s" % unit_def_id)
		return null
	
	print("[TestMode] Registered unit: %s at %s slot %d" % [unit_def_id, container_tag, slot])
	return unit_inst

## Register an item in test mode.
## Player target: spawn to PlayerBench (same path as real battle draws).
## Enemy target: spawn to PlayerBench, then atomically equip to the first enemy with a free slot.
static func register_test_item(bm, item_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	var item_def: GachaBallDefinition = Database.get_definition(item_def_id)
	if not is_instance_valid(item_def):
		push_warning("[TestMode] Item definition not found: %s" % item_def_id)
		return null
	
	var item_inst: GachaBallInstance = GachaBallInstance.new()
	item_inst.initialize(item_def)
	if not bm.bm_add_instance(item_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH):
		push_warning("[TestMode] Failed to add item to PlayerBench: %s" % item_def_id)
		return null
	
	if not is_enemy:
		print("[TestMode] Registered item: %s in PlayerBench" % item_def_id)
		return item_inst
	
	var enemy_unit_uuid: String = _find_first_unit_with_free_item_slot(bm, C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if enemy_unit_uuid.is_empty():
		push_warning("[TestMode] Enemy target selected but no enemy unit has a free item slot; item left in PlayerBench")
		return item_inst
	
	if not bm.bm_equip_item(item_inst.ball_uuid, enemy_unit_uuid, -1):
		push_warning("[TestMode] Failed to equip spawned item %s to enemy unit %s" % [item_def_id, enemy_unit_uuid])
		return item_inst
	
	print("[TestMode] Registered item: %s and equipped to enemy unit %s" % [item_def_id, enemy_unit_uuid])
	return item_inst

## Equip an item on a unit using the same logic as real battles.
static func register_test_item_on_unit(bm, item_def_id: StringName, unit_uuid: String) -> GachaBallInstance:
	var item_def: GachaBallDefinition = Database.get_definition(item_def_id)
	if not is_instance_valid(item_def):
		push_warning("[TestMode] Item definition not found: %s" % item_def_id)
		return null
	
	var unit: GachaBallInstance = bm.get_instance(unit_uuid)
	if not is_instance_valid(unit):
		push_warning("[TestMode] Unit not found: %s" % unit_uuid)
		return null
	
	# Check for empty equipment slot
	if not unit.equipped_item_uuids.has(""):
		push_warning("[TestMode] Unit %s has no empty equipment slots" % unit_uuid)
		return null
	
	# Create item through the same flow as battle inventory operations.
	var item_inst: GachaBallInstance = GachaBallInstance.new()
	item_inst.initialize(item_def)
	if not bm.bm_add_instance(item_inst, C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH):
		push_warning("[TestMode] Failed to add item to PlayerBench before equip")
		return null
	if not bm.bm_equip_item(item_inst.ball_uuid, unit_uuid, -1):
		bm.bm_remove_instance(item_inst.ball_uuid)
		push_warning("[TestMode] Failed to equip item %s on unit %s" % [item_def_id, unit_uuid])
		return null
	
	print("[TestMode] Equipped item: %s on unit: %s" % [item_def_id, unit_uuid])
	return item_inst

## Register a trinket for test mode.
static func register_test_trinket(bm, trinket_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	var trinket_def: Resource = Database.get_definition(trinket_def_id)
	if not is_instance_valid(trinket_def):
		push_warning("[TestMode] Trinket definition not found: %s" % trinket_def_id)
		return null
	
	var container_tag: StringName = C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS if is_enemy else C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS
	var trinket_container: DataContainer = bm.get_container(container_tag)
	if not is_instance_valid(trinket_container):
		push_warning("[TestMode] Missing trinket container: %s" % container_tag)
		return null
	
	# Find empty slot
	var slot: int = trinket_container.find_first_empty_slot()
	if slot == -1:
		push_warning("[TestMode] No empty trinket slots for team: %s" % ("enemy" if is_enemy else "player"))
		return null
	
	# Create instance
	var trinket_inst: GachaBallInstance = GachaBallInstance.new()
	trinket_inst.initialize_from_trinket(trinket_def)
	if not bm.bm_add_instance(trinket_inst, container_tag, slot):
		push_warning("[TestMode] Failed to register trinket via bm_add_instance: %s" % trinket_def_id)
		return null
	
	# Keep enemy trinket cache synchronized for BattleView.
	if is_enemy:
		_sync_enemy_trinket_cache(bm)
	
	print("[TestMode] Registered trinket: %s for %s at slot %d" % [trinket_def_id, "enemy" if is_enemy else "player", slot])
	return trinket_inst

## Trigger on_battle_start abilities for all units currently on the board.
static func trigger_test_battle_start(bm) -> void:
	print("[TestMode] Triggering on_battle_start for all units...")
	bm._trigger_battle_start_abilities()
	bm.call_deferred("_emit_stats_changed_for_equipped_units")
	bm._emit_battle_inventory_changed()
	print("[TestMode] Battle start trigger complete")

## Clear all entities for a specific team.
static func clear_test_team(bm, is_enemy: bool) -> void:
	var uuids_to_remove: Array[String] = []
	
	if is_enemy:
		# Clear enemy lineup
		var enemy_container: DataContainer = bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		if is_instance_valid(enemy_container):
			for i in range(enemy_container.get_size()):
				var uuid: String = enemy_container.get_uuid(i)
				if not uuid.is_empty():
					uuids_to_remove.append(uuid)
		
		# Clear enemy trinkets
		var enemy_trinket_container: DataContainer = bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
		if is_instance_valid(enemy_trinket_container):
			for i in range(enemy_trinket_container.get_size()):
				var trinket_uuid: String = enemy_trinket_container.get_uuid(i)
				if not trinket_uuid.is_empty():
					uuids_to_remove.append(trinket_uuid)
		
		for uuid in uuids_to_remove:
			bm.bm_remove_instance(uuid)
		
		_sync_enemy_trinket_cache(bm)
		
		print("[TestMode] Cleared enemy team")
	else:
		# Clear player lineup (excluding hero at position 0)
		var player_container: DataContainer = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		if is_instance_valid(player_container):
			for i in range(1, player_container.get_size()): # Skip hero at position 0
				var uuid: String = player_container.get_uuid(i)
				if not uuid.is_empty():
					uuids_to_remove.append(uuid)
		
		# Clear player trinkets
		var player_trinket_container: DataContainer = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
		if is_instance_valid(player_trinket_container):
			for i in range(player_trinket_container.get_size()):
				var trinket_uuid: String = player_trinket_container.get_uuid(i)
				if not trinket_uuid.is_empty():
					uuids_to_remove.append(trinket_uuid)
		
		for uuid in uuids_to_remove:
			bm.bm_remove_instance(uuid)
		
		print("[TestMode] Cleared player team (kept hero)")

static func _find_first_unit_with_free_item_slot(bm, container_tag: StringName) -> String:
	var units: Array[GachaBallInstance] = bm.get_instances_in_container(container_tag)
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.equipped_item_uuids.find("") != -1:
			return unit.ball_uuid
	return ""

static func _sync_enemy_trinket_cache(bm) -> void:
	var refreshed: Array[GachaBallInstance] = []
	var trinket_container: DataContainer = bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
	if is_instance_valid(trinket_container):
		for i in range(trinket_container.get_size()):
			var uuid: String = trinket_container.get_uuid(i)
			if uuid.is_empty():
				continue
			var inst: GachaBallInstance = bm.get_instance(uuid)
			if is_instance_valid(inst):
				refreshed.append(inst)
	bm.enemy_trinkets = refreshed
