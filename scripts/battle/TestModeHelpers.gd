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
	var unit_def = Database.get_definition(unit_def_id)
	if not is_instance_valid(unit_def):
		push_warning("[TestMode] Unit definition not found: %s" % unit_def_id)
		return null
	
	var container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_enemy else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	var lineup_container: DataContainer = bm.get_container(container_tag)
	
	# Find position if not specified
	var slot := position
	if slot < 0:
		slot = lineup_container.find_first_empty_slot()
		if slot == -1:
			push_warning("[TestMode] No empty slots in lineup")
			return null
	
	# Create instance EXACTLY like _setup_enemy_lineup does
	var unit_inst = GachaBallInstance.new()
	unit_inst.initialize(unit_def)
	bm._battle_instances[unit_inst.ball_uuid] = unit_inst
	
	# Place in container
	lineup_container.set_uuid(slot, unit_inst.ball_uuid)
	bm._update_instance_location(unit_inst.ball_uuid, container_tag, slot)
	
	print("[TestMode] Registered unit: %s at %s slot %d" % [unit_def_id, container_tag, slot])
	return unit_inst

## Equip an item on a unit using the same logic as real battles.
static func register_test_item_on_unit(bm, item_def_id: StringName, unit_uuid: String) -> GachaBallInstance:
	var item_def = Database.get_definition(item_def_id)
	if not is_instance_valid(item_def):
		push_warning("[TestMode] Item definition not found: %s" % item_def_id)
		return null
	
	var unit = bm.get_instance(unit_uuid)
	if not is_instance_valid(unit):
		push_warning("[TestMode] Unit not found: %s" % unit_uuid)
		return null
	
	# Check for empty equipment slot
	if not unit.equipped_item_uuids.has(""):
		push_warning("[TestMode] Unit %s has no empty equipment slots" % unit_uuid)
		return null
	
	# Create and equip item
	var item_inst = GachaBallInstance.new()
	item_inst.initialize(item_def)
	bm._battle_instances[item_inst.ball_uuid] = item_inst
	
	# Use existing _perform_equip for proper stat application
	bm._perform_equip(item_inst, unit)
	
	print("[TestMode] Equipped item: %s on unit: %s" % [item_def_id, unit_uuid])
	return item_inst

## Register a trinket for test mode.
static func register_test_trinket(bm, trinket_def_id: StringName, is_enemy: bool) -> GachaBallInstance:
	var trinket_def = Database.get_definition(trinket_def_id)
	if not is_instance_valid(trinket_def):
		push_warning("[TestMode] Trinket definition not found: %s" % trinket_def_id)
		return null
	
	var container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS if is_enemy else C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS
	var trinket_container: DataContainer = bm.get_container(container_tag)
	
	# Find empty slot
	var slot := trinket_container.find_first_empty_slot()
	if slot == -1:
		push_warning("[TestMode] No empty trinket slots for team: %s" % ("enemy" if is_enemy else "player"))
		return null
	
	# Create instance
	var trinket_inst = GachaBallInstance.new()
	trinket_inst.initialize_from_trinket(trinket_def)
	bm._battle_instances[trinket_inst.ball_uuid] = trinket_inst
	
	# Place in container
	trinket_container.set_uuid(slot, trinket_inst.ball_uuid)
	bm._update_instance_location(trinket_inst.ball_uuid, container_tag, slot)
	
	# For enemy trinkets, also add to legacy array
	if is_enemy:
		bm.enemy_trinkets.append(trinket_inst)
	
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
	if is_enemy:
		# Clear enemy lineup
		var enemy_container = bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
		for i in range(5):
			var uuid = enemy_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = bm.get_instance(uuid)
				if is_instance_valid(inst):
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							bm._battle_instances.erase(item_uuid)
					bm._battle_instances.erase(uuid)
				enemy_container.set_uuid(i, "")
		
		# Clear enemy trinkets
		bm.enemy_trinkets.clear()
		var trinket_container = bm.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				bm._battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared enemy team")
	else:
		# Clear player lineup (excluding hero at position 0)
		var player_container = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
		for i in range(1, 5): # Skip hero at position 0
			var uuid = player_container.get_uuid(i)
			if not uuid.is_empty():
				var inst = bm.get_instance(uuid)
				if is_instance_valid(inst):
					for item_uuid in inst.equipped_item_uuids:
						if not item_uuid.is_empty():
							bm._battle_instances.erase(item_uuid)
					bm._battle_instances.erase(uuid)
				player_container.set_uuid(i, "")
		
		# Clear player trinkets
		var trinket_container = bm.get_container(C.BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS)
		for i in range(5):
			var uuid = trinket_container.get_uuid(i)
			if not uuid.is_empty():
				bm._battle_instances.erase(uuid)
				trinket_container.set_uuid(i, "")
		
		print("[TestMode] Cleared player team (kept hero)")
	
	bm._emit_battle_inventory_changed()
