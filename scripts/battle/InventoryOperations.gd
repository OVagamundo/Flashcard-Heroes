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
	
	# For item discard / replacement
	var replaced_item_uuid: String = ""
	var replaced_item_icon: Texture2D = null
	var replaced_item_icon_path: String = ""
	var replaced_item_name: String = ""
	var replaced_from_unit_uuid: String = ""
	var delta_hp: int = 0
	var delta_pwr: int = 0
	 
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
static func draw_from_tier(state: BattleState, tier: int, player_shelf_capacity: int = C.PLAYER_SHELF_CAP) -> DrawResult:
	var result := DrawResult.new()

	var container_tag: StringName = &"BattleInventoryT%d" % tier
	var tier_pool := state.get_instances_in_container(container_tag)
	if tier_pool.is_empty():
		return result

	var drawn_instance: GachaBallInstance = RNGManager.gacha_rng.pick_random(tier_pool)
	if not is_instance_valid(drawn_instance):
		return result

	var def := drawn_instance.get_definition()
	if not is_instance_valid(def):
		return result

	var source_loc := drawn_instance.get_location()
	if is_instance_valid(source_loc):
		result.source_container = source_loc.container
		result.source_slot = source_loc.index

	var target_container_tag: StringName
	var target_capacity: int
	match def.category:
		&"UNIT", &"ITEM", &"CONSUMABLE":
			target_container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
			target_capacity = player_shelf_capacity
		_:
			target_container_tag = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			target_capacity = -1
			result.went_to_discard = true

	var target_container := state.get_container(target_container_tag)
	if not is_instance_valid(target_container):
		return result

	var desired_slot := -1
	if target_container_tag != C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
		var empty_slot := state.find_first_empty_player_shelf_slot() if target_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF else target_container.find_first_empty_slot()
		if empty_slot != -1 and empty_slot < target_capacity:
			result.dest_container = target_container_tag
			desired_slot = empty_slot
		else:
			result.dest_container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
			desired_slot = -1
			result.went_to_discard = true
	else:
		result.dest_container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
		desired_slot = -1

	var final_slot := state.transfer_instance_to_container(drawn_instance, result.dest_container, desired_slot)
	assert(final_slot != -1, "draw_from_tier: failed to transfer %s to %s" % [drawn_instance.ball_uuid, String(result.dest_container)])
	result.dest_slot = final_slot
	result.drawn_uuid = drawn_instance.ball_uuid
	result.success = true

	if state.get_instances_in_container(container_tag).is_empty():
		result.pool_emptied = true

	return result

## Draw a random instance from the Discard to its appropriate tier machine.
## Returns DrawResult with source_container = DiscardPile and dest_container = BattleInventoryT{tier}.
static func draw_from_discard(state: BattleState) -> DrawResult:
	var result := DrawResult.new()
	var discard_pool := state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	if discard_pool.is_empty():
		return result
	var tiers_with_room: Array[int] = []
	for tier: int in range(1, 4):
		if state.has_tier_space(tier):
			tiers_with_room.append(tier)
	if tiers_with_room.is_empty():
		return result
	var eligible: Array[GachaBallInstance] = []
	for instance: GachaBallInstance in discard_pool:
		if tiers_with_room.has(instance.get_definition().tier):
			eligible.append(instance)
	var drawn_instance: GachaBallInstance = RNGManager.gacha_rng.pick_random(discard_pool if eligible.is_empty() else eligible)
	result.source_container = C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
	result.source_slot = drawn_instance.location_slot_index
	result.dest_container = result.source_container
	result.dest_slot = result.source_slot
	result.went_to_discard = eligible.is_empty()
	if not result.went_to_discard:
		drawn_instance.reset_battle_stats_silent()
		result.dest_container = &"BattleInventoryT%d" % drawn_instance.get_definition().tier
		result.dest_slot = state.transfer_instance_to_container(drawn_instance, result.dest_container)
		assert(result.dest_slot >= 0, "Eligible capsule must have a free tier slot")
	result.drawn_uuid = drawn_instance.ball_uuid
	result.success = true
	if state.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE).is_empty():
		result.pool_emptied = true

	return result

# ============================================================================
# EQUIP ITEM
# ============================================================================

## Atomically register a newly created item instance and equip it onto a unit.
## Never places the item in an intermediate container or unplaced state.
static func register_and_equip_item(state: BattleState, item: GachaBallInstance, unit_uuid: String, slot_index: int = -1) -> OperationResult:
	var result := OperationResult.new()

	assert(is_instance_valid(item), "register_and_equip_item: item is null")
	assert(not state.get_all_instances().has(item.ball_uuid), "register_and_equip_item: item %s is already registered" % item.ball_uuid)
	if item.definition_id == C.ITEM_INCUBATOR:
		return result

	var unit := state.get_instance(unit_uuid)
	if not is_instance_valid(unit):
		return result
	if not state.is_lineup_location(unit.get_location()):
		return result

	var item_def = item.get_definition()
	if not is_instance_valid(item_def) or item_def.category != &"ITEM":
		return result

	var target_slot := slot_index
	if target_slot < 0:
		var empty_idx := unit.equipped_item_uuids.find("")
		target_slot = empty_idx if empty_idx != -1 else 0
	if target_slot >= unit.equipped_item_uuids.size():
		return result

	# If target slot is occupied, atomically move existing item to discard BEFORE registering new item
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	var existing: GachaBallInstance = null
	if not existing_uuid.is_empty():
		existing = state.get_instance(existing_uuid)
		if is_instance_valid(existing):
			var discard_result := move_instance_to_discard(state, existing, false)
			if not discard_result.success:
				return result
			result.replaced_item_uuid = discard_result.replaced_item_uuid
			result.replaced_item_icon = discard_result.replaced_item_icon
			result.replaced_item_icon_path = discard_result.replaced_item_icon_path
			result.replaced_item_name = discard_result.replaced_item_name
			result.replaced_from_unit_uuid = discard_result.replaced_from_unit_uuid
			for changed_uuid in discard_result.changed_unit_uuids:
				result.add_unit_change(changed_uuid)
			if discard_result.inventory_changed:
				result.inventory_changed = true

	# Register and link atomically
	state.register_instance(item)
	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot
	var deltas := unit.replace_item_bonus(existing, item)
	result.delta_hp = deltas.get("delta_hp", 0)
	result.delta_pwr = deltas.get("delta_pwr", 0)
	result.inventory_changed = true

	result.add_unit_change(unit.ball_uuid)
	result.set_success()
	return result

## Equip an already-registered item to a unit atomically. Returns OperationResult.
## Caller is responsible for signal emission.
static func can_incubate(state: BattleState, item: GachaBallInstance, unit: GachaBallInstance) -> bool:
	return item.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF \
		and state.is_player_shelf_slot_unlocked(item.location_slot_index) \
		and unit.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP \
		and unit.get_definition().category == C.CATEGORY_UNIT and unit.current_hp > 0

static func equip_item(state: BattleState, item_uuid: String, unit_uuid: String, slot_index: int = -1) -> OperationResult:
	var result := OperationResult.new()

	var item := state.get_instance(item_uuid)
	var unit := state.get_instance(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return result
	if not state.is_lineup_location(unit.get_location()):
		return result
	if item.location_container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not state.is_player_shelf_slot_unlocked(item.location_slot_index):
		return result
	var incubating: bool = item.definition_id == C.ITEM_INCUBATOR
	if incubating and not can_incubate(state, item, unit):
		return result

	var item_def = item.get_definition()
	if not is_instance_valid(item_def) or item_def.category != &"ITEM":
		return result

	# Determine target slot
	var target_slot := slot_index
	if target_slot < 0:
		var empty_idx := unit.equipped_item_uuids.find("")
		target_slot = empty_idx if empty_idx != -1 else 0
	if target_slot >= unit.equipped_item_uuids.size():
		return result

	# No-op if already equipped in the exact same slot on the same unit
	if item.equipped_on_uuid == unit.ball_uuid and item.equipped_slot_index == target_slot:
		result.set_success()
		return result

	# Pre-validate source location BEFORE mutating anything
	var item_loc := item.get_location()
	if not is_instance_valid(item_loc):
		return result

	var src_container: DataContainer = null
	var src_slot: int = -1
	var prev_unit: GachaBallInstance = null
	var prev_slot: int = -1

	if item_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		prev_unit = state.get_instance(item.equipped_on_uuid)
		if not is_instance_valid(prev_unit):
			return result
		prev_slot = item.equipped_slot_index
		if prev_slot < 0 or prev_slot >= prev_unit.equipped_item_uuids.size() or prev_unit.equipped_item_uuids[prev_slot] != item.ball_uuid:
			return result
	else:
		src_container = state.get_container(item_loc.container)
		if not is_instance_valid(src_container):
			return result
		src_slot = item_loc.index
		if src_slot < 0 or src_container.get_uuid(src_slot) != item.ball_uuid:
			src_slot = src_container.get_index_of_uuid(item.ball_uuid)
			if src_slot == -1:
				return result

	# If target slot is occupied, move existing item to discard BEFORE mutating item's source
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	var existing: GachaBallInstance = null
	if not existing_uuid.is_empty() and existing_uuid != item.ball_uuid:
		existing = state.get_instance(existing_uuid)
		if is_instance_valid(existing):
			var discard_result := move_instance_to_discard(state, existing, false)
			if not discard_result.success:
				return result
			result.replaced_item_uuid = discard_result.replaced_item_uuid
			result.replaced_item_icon = discard_result.replaced_item_icon
			result.replaced_item_icon_path = discard_result.replaced_item_icon_path
			result.replaced_item_name = discard_result.replaced_item_name
			result.replaced_from_unit_uuid = discard_result.replaced_from_unit_uuid
			for changed_uuid in discard_result.changed_unit_uuids:
				result.add_unit_change(changed_uuid)
			if discard_result.inventory_changed:
				result.inventory_changed = true

	# Atomically transition item from source to unit's equipped slot
	if is_instance_valid(prev_unit):
		prev_unit.unequip_item_bonus(item)
		if prev_unit.equipped_item_uuids[prev_slot] == item.ball_uuid:
			prev_unit.equipped_item_uuids[prev_slot] = ""
		result.add_unit_change(prev_unit.ball_uuid)
	elif is_instance_valid(src_container):
		src_container.set_uuid(src_slot, "")

	unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
	item.location_slot_index = target_slot
	var deltas := unit.replace_item_bonus(existing, item)
	result.delta_hp = deltas.get("delta_hp", 0)
	result.delta_pwr = deltas.get("delta_pwr", 0)
	result.inventory_changed = true

	if incubating:
		var moved_slot: int = state.transfer_instance_to_container(unit, item_loc.container, src_slot)
		assert(moved_slot == src_slot, "Incubator must move its holder to the vacated Shelf slot")

	result.add_unit_change(unit.ball_uuid)
	result.set_success()
	return result

# ============================================================================
# MOVE INSTANCE
# ============================================================================

## Move an instance from source to target location. Returns OperationResult.
## NOTE: If target is an equipped slot, caller must handle the equip via equip_item after this returns.
static func move_instance(state: BattleState, source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> OperationResult:
	var result := OperationResult.new()

	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return result

	if source_loc.container.is_empty() or target_loc.container.is_empty():
		push_warning("move_instance rejected: source or target container tag is empty")
		return result
	if source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not state.is_player_shelf_slot_unlocked(source_loc.index):
		return result

	# Target is equipping onto a unit - delegate to caller via special flag
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := state.get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return result

		var item := state.get_instance_by_location(source_loc)
		if not is_instance_valid(item):
			return result

		result.success = false
		result.inventory_changed = false
		result.needs_equip = true
		result.equip_item_uuid = item.ball_uuid
		result.equip_unit_uuid = unit.ball_uuid
		result.equip_slot_index = target_loc.index
		return result

	var instance := state.get_instance_by_location(source_loc)
	if not is_instance_valid(instance):
		return result

	var to_container := state.get_container(target_loc.container)
	if not is_instance_valid(to_container) or not to_container.is_valid_index(target_loc.index):
		return result

	var existing_target_uuid := to_container.get_uuid(target_loc.index)
	if not existing_target_uuid.is_empty():
		push_error("move_instance rejected: target slot %s:%d is occupied by %s" % [target_loc.container, target_loc.index, existing_target_uuid])
		return result

	var prev_parent_uuid := instance.equipped_on_uuid if source_loc.container == C.CONTAINER_EQUIPPED_ITEM else ""
	var final_slot := state.transfer_instance_to_container(instance, target_loc.container, target_loc.index, true)
	if final_slot == -1:
		return result

	if not prev_parent_uuid.is_empty():
		result.add_unit_change(prev_parent_uuid)
	result.set_success()
	return result

# ============================================================================
# SWAP INSTANCES
# ============================================================================

## Swap two instances atomically. Returns OperationResult.
static func swap_instances(state: BattleState, source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> OperationResult:
	var result := OperationResult.new()

	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return result
	# A swap must never send a deployed ball or equipped item back to the Shelf.
	if (source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF) != (target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF):
		return result

	if source_loc.container.is_empty() or target_loc.container.is_empty():
		push_warning("swap_instances rejected: source or target container tag is empty")
		return result
	if source_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not state.is_player_shelf_slot_unlocked(source_loc.index):
		return result
	if target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not state.is_player_shelf_slot_unlocked(target_loc.index):
		return result

	# Normalize so that if only one side is an equipped slot, it is target_loc
	if source_loc.container == C.CONTAINER_EQUIPPED_ITEM and target_loc.container != C.CONTAINER_EQUIPPED_ITEM:
		return swap_instances(state, target_loc, source_loc)

	# Handle swaps where target is an equipped slot
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var unit := state.get_instance(target_loc.unit_uuid)
		if not is_instance_valid(unit):
			return result
		if target_loc.index < 0 or target_loc.index >= unit.equipped_item_uuids.size():
			return result

		var item_a: GachaBallInstance = null
		var src_unit: GachaBallInstance = null
		var src_container: DataContainer = null

		if source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			if source_loc.unit_uuid == target_loc.unit_uuid and source_loc.index == target_loc.index:
				result.set_success()
				return result
			src_unit = state.get_instance(source_loc.unit_uuid)
			if not is_instance_valid(src_unit):
				return result
			if source_loc.index < 0 or source_loc.index >= src_unit.equipped_item_uuids.size():
				return result
			var a_uuid := src_unit.equipped_item_uuids[source_loc.index]
			if a_uuid.is_empty():
				return result
			item_a = state.get_instance(a_uuid)
		else:
			src_container = state.get_container(source_loc.container)
			if not is_instance_valid(src_container) or not src_container.is_valid_index(source_loc.index):
				return result
			item_a = state.get_instance_by_location(source_loc)

		if not is_instance_valid(item_a):
			return result
		var item_a_def = item_a.get_definition()
		if not is_instance_valid(item_a_def) or item_a_def.category != &"ITEM":
			return result

		var existing_uuid := unit.equipped_item_uuids[target_loc.index]
		var item_b: GachaBallInstance = state.get_instance(existing_uuid) if not existing_uuid.is_empty() else null

		# All preconditions validated — execute swap atomically without intermediate empty states
		if is_instance_valid(src_unit):
			src_unit.unequip_item_bonus(item_a)
			src_unit.equipped_item_uuids[source_loc.index] = ""
		else:
			src_container.set_uuid(source_loc.index, "")

		if is_instance_valid(item_b):
			unit.unequip_item_bonus(item_b)
			unit.equipped_item_uuids[target_loc.index] = ""

			if is_instance_valid(src_unit):
				src_unit.equipped_item_uuids[source_loc.index] = item_b.ball_uuid
				item_b.equipped_on_uuid = src_unit.ball_uuid
				item_b.equipped_slot_index = source_loc.index
				item_b.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
				item_b.location_slot_index = source_loc.index
				src_unit.equip_item_bonus(item_b)
				result.add_unit_change(src_unit.ball_uuid)
			else:
				src_container.set_uuid(source_loc.index, item_b.ball_uuid)
				state.update_instance_location(item_b.ball_uuid, source_loc.container, source_loc.index)
		elif is_instance_valid(src_unit):
			result.add_unit_change(src_unit.ball_uuid)

		unit.equipped_item_uuids[target_loc.index] = item_a.ball_uuid
		item_a.equipped_on_uuid = unit.ball_uuid
		item_a.equipped_slot_index = target_loc.index
		item_a.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
		item_a.location_slot_index = target_loc.index
		unit.equip_item_bonus(item_a)

		result.add_unit_change(unit.ball_uuid)
		result.set_success()
		return result

	# General swap across physical containers
	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		result.set_success()
		return result

	var a_container := state.get_container(source_loc.container)
	var b_container := state.get_container(target_loc.container)
	if not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return result
	if not a_container.is_valid_index(source_loc.index) or not b_container.is_valid_index(target_loc.index):
		return result

	var a := state.get_instance_by_location(source_loc)
	if not is_instance_valid(a) or a_container.get_uuid(source_loc.index) != a.ball_uuid:
		return result

	var b := state.get_instance_by_location(target_loc)
	if not is_instance_valid(b):
		a_container.set_uuid(source_loc.index, "")
		b_container.set_uuid(target_loc.index, a.ball_uuid)
		state.update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
		result.set_success()
		return result

	var b_uuid2 := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid2)
	state.update_instance_location(a.ball_uuid, target_loc.container, target_loc.index)
	state.update_instance_location(b.ball_uuid, source_loc.container, source_loc.index)

	result.set_success()
	return result

# ============================================================================
# MOVE TO DISCARD
# ============================================================================

## Move an instance to the Discard atomically. Handles equipped items and containers.
## Returns OperationResult.
static func move_instance_to_discard(state: BattleState, instance: GachaBallInstance, unequip_bonus: bool = true) -> OperationResult:
	var result := OperationResult.new()
	assert(is_instance_valid(instance), "move_instance_to_discard: instance is null")

	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return result

	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := state.get_instance(loc.unit_uuid)
		if is_instance_valid(parent):
			result.replaced_from_unit_uuid = parent.ball_uuid
			result.replaced_item_uuid = instance.ball_uuid
			var idef = instance.get_definition()
			if is_instance_valid(idef):
				if "icon" in idef and is_instance_valid(idef.icon):
					result.replaced_item_icon = idef.icon
					result.replaced_item_icon_path = idef.icon.resource_path
				elif "icon_path" in idef and idef.icon_path is String:
					result.replaced_item_icon_path = idef.icon_path
				if "display_name_key" in idef:
					result.replaced_item_name = idef.display_name_key
			result.add_unit_change(parent.ball_uuid)

	var dest_tag := C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE if state.is_player_owned(instance) else C.BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD
	var slot := state.transfer_instance_to_container(instance, dest_tag, -1, unequip_bonus)
	if slot == -1:
		push_error("Discard container %s full; cannot move %s" % [String(dest_tag), instance.ball_uuid])
		return result

	result.add_unit_change(instance.ball_uuid)
	result.set_success()
	return result
