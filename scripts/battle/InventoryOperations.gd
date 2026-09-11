# res://scripts/battle/InventoryOperations.gd
class_name InventoryOperations
extends RefCounted

## InventoryOperations handles inventory mutations and returns results.
## BattleManager calls these methods and handles signal emission.

const C = preload("res://scripts/Constants.gd")

# ============================================================================
# RESULT CLASS
# ============================================================================

## Result class for inventory operations
class OperationResult:
	var success: bool = false
	var changed_unit_uuids: Array[String] = [] # Units whose inventory changed
	var inventory_changed: bool = false # Whether battle inventory changed
	
	# For move operations that need equip delegation
	var needs_equip: bool = false
	var equip_item_uuid: String = ""
	var equip_unit_uuid: String = ""
	var equip_slot_index: int = -1
	 
	func add_unit_change(uuid: String) -> void:
		if not uuid.is_empty() and not changed_unit_uuids.has(uuid):
			changed_unit_uuids.append(uuid)
	
	func set_success() -> void:
		success = true
		inventory_changed = true

## Result class for gacha draw operations
class DrawResult:
	var success: bool = false
	var drawn_uuid: String = ""
	var dest_container: StringName = &""
	var dest_slot: int = -1
	var source_container: StringName = &""
	var source_slot: int = -1
	var pool_emptied: bool = false
	var went_to_discard: bool = false

# ============================================================================
# GACHA DRAW
# ============================================================================

## Draw a random instance from a tier pool. Returns DrawResult.
## Does NOT handle token costs or signals - caller is responsible.
static func draw_from_tier(state: BattleState, tier: int, player_bench_capacity: int = 5) -> DrawResult:
	var result := DrawResult.new()
	
	var container_tag: StringName = "BattleInventoryT%d" % tier
	var tier_pool := state.get_instances_in_container(container_tag)
	
	# If pool is empty, caller needs to reshuffle first
	if tier_pool.is_empty():
		return result
	
	# Pick one at random
	var drawn_instance: GachaBallInstance = RNGManager.gacha_rng.pick_random(tier_pool)
	if not is_instance_valid(drawn_instance):
		return result
	
	var def := drawn_instance.get_definition()
	if not is_instance_valid(def):
		return result
	
	# Save source location
	var source_loc := drawn_instance.get_location()
	if is_instance_valid(source_loc):
		result.source_container = source_loc.container
		result.source_slot = source_loc.index
	
	# Determine target based on category
	var target_container_tag: StringName
	var target_capacity: int
	match def.category:
		&"UNIT", &"ITEM", &"CONSUMABLE":
			# Both units and items go to the unified bench
			target_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
			target_capacity = player_bench_capacity
		_:
			# Unknown category - discard
			target_container_tag = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			target_capacity = 999 # Discard has no practical limit
			result.went_to_discard = true
	
	# Find destination slot
	var target_container := state.get_container(target_container_tag)
	if not is_instance_valid(target_container):
		return result
	
	var empty_slot := target_container.find_first_empty_slot()
	if empty_slot != -1 and empty_slot < target_capacity:
		result.dest_container = target_container_tag
		result.dest_slot = empty_slot
	else:
		# Overflow to discard
		var discard := state.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
		if not is_instance_valid(discard):
			return result
		var di := discard.find_first_empty_slot()
		if di == -1:
			di = discard.get_all_uuids().size()
		result.dest_container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
		result.dest_slot = di
		result.went_to_discard = true
	
	# Apply the move atomically
	# 1. Update instance location (truth)
	state.update_instance_location(drawn_instance.ball_uuid, result.dest_container, result.dest_slot)
	
	# 2. Clear source container slot
	if not result.source_container.is_empty() and result.source_slot >= 0:
		var source_container := state.get_container(result.source_container)
		if is_instance_valid(source_container):
			source_container.set_uuid(result.source_slot, "")
	
	# 3. Set destination container slot
	var dest_container := state.get_container(result.dest_container)
	if is_instance_valid(dest_container):
		dest_container.set_uuid(result.dest_slot, drawn_instance.ball_uuid)
	
	result.drawn_uuid = drawn_instance.ball_uuid
	result.success = true
	
	# Check if pool is now empty
	if state.get_instances_in_container(container_tag).is_empty():
		result.pool_emptied = true
	
	return result

# ============================================================================
# EQUIP ITEM
# ============================================================================

## Equip an item to a unit. Returns OperationResult.
## Caller is responsible for signal emission.
static func equip_item(state: BattleState, item_uuid: String, unit_uuid: String, slot_index: int = -1, silent: bool = false) -> OperationResult:
	var result := OperationResult.new()
	
	var item := state.get_instance(item_uuid)
	var unit := state.get_instance(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return result
	
	# Determine slot
	var target_slot := slot_index
	if target_slot < 0:
		target_slot = 0
	if target_slot >= unit.equipped_item_uuids.size():
		return result
	
	# If item is in a physical container, remove it
	var item_loc := item.get_location()
	if is_instance_valid(item_loc) and item_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		_remove_from_container(state, item)
	else:
		# If currently equipped elsewhere, clear the previous mapping
		if not item.equipped_on_uuid.is_empty():
			var prev_unit := state.get_instance(item.equipped_on_uuid)
			if is_instance_valid(prev_unit):
				var prev_idx := item.equipped_slot_index
				if prev_idx >= 0 and prev_idx < prev_unit.equipped_item_uuids.size():
					prev_unit.unequip_item_bonus(item, silent)
					if prev_unit.equipped_item_uuids[prev_idx] == item.ball_uuid:
						prev_unit.equipped_item_uuids[prev_idx] = ""
				result.add_unit_change(prev_unit.ball_uuid)
			item.equipped_on_uuid = ""
			item.equipped_slot_index = -1
		state.update_instance_location(item.ball_uuid, &"", -1)
	
	# If slot occupied, move existing to player item inventory
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	if not existing_uuid.is_empty():
		var existing := state.get_instance(existing_uuid)
		if is_instance_valid(existing):
			var discard_result := move_instance_to_discard(state, existing)
			if not discard_result.success:
				return result
			for changed_uuid in discard_result.changed_unit_uuids:
				result.add_unit_change(changed_uuid)
			if discard_result.inventory_changed:
				result.inventory_changed = true
	
	# Equip item
	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot
	unit.equip_item_bonus(item, silent)
	
	result.add_unit_change(unit.ball_uuid)
	result.set_success()
	return result

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func _remove_from_container(state: BattleState, instance: GachaBallInstance) -> void:
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return
	var container := state.get_container(loc.container)
	if is_instance_valid(container):
		var uuids := container.get_all_uuids()
		var idx := uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			state.update_instance_location(instance.ball_uuid, &"", -1)

# ============================================================================
# MOVE INSTANCE
# ============================================================================

## Move an instance from source to target location. Returns OperationResult.
## NOTE: If target is an equipped slot, caller must handle the equip via equip_item after this returns.
static func move_instance(state: BattleState, source_loc: LocationIdentifier, target_loc: LocationIdentifier, silent: bool = false) -> OperationResult:
	var result := OperationResult.new()
	
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return result
		
	if source_loc.container.is_empty() or target_loc.container.is_empty():
		push_warning("move_instance rejected: source or target container tag is empty")
		return result
	
	# Target is equipping onto a unit - delegate to caller via special flag
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := state.get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return result
		
		var item_uuid := ""
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			# Moving between equipped slots
			var src_unit := state.get_instance(source_loc.unit_uuid)
			if not is_instance_valid(src_unit):
				return result
			if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
				return result
			item_uuid = src_unit.equipped_item_uuids[source_loc.index]
			# Do not mutate state here; let equip_item handle it atomically
		else:
			# From container to equipped slot
			var src_container := state.get_container(source_loc.container)
			if not is_instance_valid(src_container):
				return result
			var src_inst_uuid := src_container.get_uuid(source_loc.index)
			# Do not mutate state here; let equip_item handle it atomically
			item_uuid = src_inst_uuid
		
		if item_uuid.is_empty():
			return result

		var item := state.get_instance(item_uuid)
		if not is_instance_valid(item):
			return result

		# Return with flag to call equip_item
		result.success = false # Caller must call equip_item
		result.inventory_changed = false # No change yet
		# Store data for caller
		result.needs_equip = true
		result.equip_item_uuid = item_uuid
		result.equip_unit_uuid = unit.ball_uuid
		result.equip_slot_index = target_loc.index
		return result
	
	# Source is an equipped slot moving to a container
	if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var src_unit := state.get_instance(source_loc.unit_uuid)
		if not is_instance_valid(src_unit):
			return result
		if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
			return result
		var a_uuid := src_unit.equipped_item_uuids[source_loc.index]
		if a_uuid.is_empty():
			return result
		var a := state.get_instance(a_uuid)
		if not is_instance_valid(a):
			return result
		
		# Remove bonuses and clear mapping
		src_unit.unequip_item_bonus(a, silent)
		src_unit.equipped_item_uuids[source_loc.index] = ""
		a.equipped_on_uuid = ""
		a.equipped_slot_index = -1
		
		# Place into target container
		var target_container := state.get_container(target_loc.container)
		if not is_instance_valid(target_container):
			return result
		target_container.set_uuid(target_loc.index, a.ball_uuid)
		state.update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
		
		result.add_unit_change(src_unit.ball_uuid)
		result.set_success()
		return result
	
	var from_container := state.get_container(source_loc.container)
	var to_container := state.get_container(target_loc.container)
	if not is_instance_valid(from_container) or not is_instance_valid(to_container):
		return result
	
	# Prevent overwriting an existing unit (Golden Rule)
	# swap_instances should be used if the target is occupied
	var existing_target_uuid := to_container.get_uuid(target_loc.index)
	if not existing_target_uuid.is_empty():
		push_error("move_instance rejected: target slot %s:%d is occupied by %s" % [target_loc.container, target_loc.index, existing_target_uuid])
		return result
	
	var inst_uuid := from_container.get_uuid(source_loc.index)
	if inst_uuid.is_empty():
		return result
	var instance := state.get_instance(inst_uuid)
	if not is_instance_valid(instance):
		return result
	
	from_container.set_uuid(source_loc.index, "")
	to_container.set_uuid(target_loc.index, instance.ball_uuid)
	state.update_instance_location(instance.ball_uuid, target_loc.container, target_loc.index)
	
	result.set_success()
	return result

# ============================================================================
# SWAP INSTANCES
# ============================================================================

## Swap two instances. Returns OperationResult.
static func swap_instances(state: BattleState, source_loc: LocationIdentifier, target_loc: LocationIdentifier, silent: bool = false) -> OperationResult:
	var result := OperationResult.new()
	
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return result

	if source_loc.container.is_empty() or target_loc.container.is_empty():
		push_warning("swap_instances rejected: source or target container tag is empty")
		return result
	
	# Handle swaps where target is an equipped slot
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := state.get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return result
		
		# Resolve A from source
		var item_a: GachaBallInstance = null
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var src_unit := state.get_instance(source_loc.unit_uuid)
			if not is_instance_valid(src_unit):
				return result
			if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
				return result
			var a_uuid := src_unit.equipped_item_uuids[source_loc.index]
			item_a = state.get_instance(a_uuid)
			if is_instance_valid(item_a):
				src_unit.unequip_item_bonus(item_a, silent)
			src_unit.equipped_item_uuids[source_loc.index] = ""
			if is_instance_valid(item_a):
				item_a.equipped_on_uuid = ""
				item_a.equipped_slot_index = -1
				state.update_instance_location(item_a.ball_uuid, &"", -1)
		else:
			# Validate target slot BEFORE mutating source state
			if target_loc.index < 0 or target_loc.index >= unit.equipped_item_uuids.size():
				return result
				
			item_a = state.get_instance_by_location(source_loc)
			if not is_instance_valid(item_a):
				return result
			_remove_from_container(state, item_a)
		
		if not is_instance_valid(item_a):
			return result
		
		# Resolve existing item B in target equipped slot
		# (Index validation was done above)
		var existing_uuid := unit.equipped_item_uuids[target_loc.index]
		var item_b: GachaBallInstance = null
		if not existing_uuid.is_empty():
			item_b = state.get_instance(existing_uuid)
		
		# If B exists, move it into source origin
		if is_instance_valid(item_b):
			unit.unequip_item_bonus(item_b, silent)
			unit.equipped_item_uuids[target_loc.index] = ""
			item_b.equipped_on_uuid = ""
			item_b.equipped_slot_index = -1
			
			if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
				var src_unit2 := state.get_instance(source_loc.unit_uuid)
				if not is_instance_valid(src_unit2):
					return result
				src_unit2.equipped_item_uuids[source_loc.index] = item_b.ball_uuid
				item_b.equipped_on_uuid = src_unit2.ball_uuid
				item_b.equipped_slot_index = source_loc.index
				item_b.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
				item_b.location_slot_index = source_loc.index
				src_unit2.equip_item_bonus(item_b, silent)
				result.add_unit_change(src_unit2.ball_uuid)
			else:
				var src_container := state.get_container(source_loc.container)
				if not is_instance_valid(src_container):
					return result
				src_container.set_uuid(source_loc.index, item_b.ball_uuid)
				state.update_instance_location(item_b.ball_uuid, source_loc.container, source_loc.index)
		
		# Equip A into target slot
		unit.equipped_item_uuids[target_loc.index] = item_a.ball_uuid
		item_a.equipped_on_uuid = unit.ball_uuid
		item_a.equipped_slot_index = target_loc.index
		item_a.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
		item_a.location_slot_index = target_loc.index
		unit.equip_item_bonus(item_a, silent)
		
		# Notify source unit if it was an equipped slot and target had no B
		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM and not is_instance_valid(item_b):
			var src_unit3 := state.get_instance(source_loc.unit_uuid)
			if is_instance_valid(src_unit3):
				result.add_unit_change(src_unit3.ball_uuid)
		
		result.add_unit_change(unit.ball_uuid)
		result.set_success()
		return result
	
	# General swap across containers
	var a_container := state.get_container(source_loc.container)
	var b_container := state.get_container(target_loc.container)
	if not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return result
	
	var a := state.get_instance_by_location(source_loc)
	if not is_instance_valid(a):
		return result
	
	var b := state.get_instance_by_location(target_loc)
	if not is_instance_valid(b):
		# Degrade to move if target is empty
		if a_container.get_uuid(source_loc.index) != a.ball_uuid:
			return result
		a_container.set_uuid(source_loc.index, "")
		b_container.set_uuid(target_loc.index, a.ball_uuid)
		state.update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
		result.set_success()
		return result
	
	# True swap across containers
	if a_container.get_uuid(source_loc.index) != a.ball_uuid:
		return result
	var b_uuid2 := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid2)
	state.update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
	state.update_instance_location(b.ball_uuid, source_loc.container, source_loc.index)
	
	result.set_success()
	return result


# ============================================================================
# REMOVE INSTANCE
# ============================================================================

## Remove instance from its container (for enemy units or cleanup).
## Returns OperationResult.
static func remove_instance_from_container(state: BattleState, instance: GachaBallInstance) -> OperationResult:
	var result := OperationResult.new()
	assert(is_instance_valid(instance), "remove_instance_from_container: instance is null")
	
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return result
	
	var container := state.get_container(loc.container)
	if is_instance_valid(container):
		var uuids := container.get_all_uuids()
		var idx := uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			state.update_instance_location(instance.ball_uuid, &"", -1)
			
			result.add_unit_change(instance.ball_uuid)
			result.set_success()
		else:
			push_error("Remove failed: %s not found in stated container %s" % [instance.ball_uuid, String(loc.container)])
	
	return result

# ============================================================================
# MOVE TO DISCARD
# ============================================================================

## Move an instance to the discard pile. Handles equipped items and containers.
## Returns OperationResult.
static func move_instance_to_discard(state: BattleState, instance: GachaBallInstance, silent: bool = false) -> OperationResult:
	var result := OperationResult.new()
	assert(is_instance_valid(instance), "move_instance_to_discard: instance is null")
	
	var loc := instance.get_location()
	if is_instance_valid(loc):
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent := state.get_instance(loc.unit_uuid)
			if is_instance_valid(parent):
				if loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
					# Clear the parent's slot mapping if it points to this instance
					if parent.equipped_item_uuids[loc.index] == instance.ball_uuid:
						parent.unequip_item_bonus(instance, silent)
						parent.equipped_item_uuids[loc.index] = ""
						result.add_unit_change(parent.ball_uuid)
			# Clear equipped linkage on the item itself
			instance.equipped_on_uuid = ""
			instance.equipped_slot_index = -1
		else:
			var src := state.get_container(loc.container)
			if is_instance_valid(src):
				var uuids := src.get_all_uuids()
				var si := uuids.find(instance.ball_uuid)
				if si != -1:
					src.set_uuid(si, "")
	
	# Place into discard
	var discard_container := state.get_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if not is_instance_valid(discard_container):
		push_error("Discard pile container not found")
		return result
		
	var index := discard_container.find_first_empty_slot()
	if index == -1:
		# If somehow full (unlikely), try to append if possible or just log error
		# Based on logic elsewhere, discard has high capacity. If full, we fail.
		push_error("Discard pile full; cannot move %s" % instance.ball_uuid)
		return result
	
	discard_container.set_uuid(index, instance.ball_uuid)
	state.update_instance_location(instance.ball_uuid, C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, index)
	
	result.add_unit_change(instance.ball_uuid)
	result.set_success()
	return result
