# res://scripts/battle/BattleState.gd
class_name BattleState
extends RefCounted

## BattleState encapsulates all battle-scoped data and provides atomic mutation APIs.
## This class is responsible for:
##   - Storing battle instances (_battle_instances)
##   - Managing containers (_containers)
##   - Tracking death registry (_dead_this_turn) and turn metadata (_turn_metadata)
##   - Providing atomic mutation operations (add, remove, move, swap, equip)
##
## BattleManager creates and holds an instance of this class, delegating data operations.
## Note: FixedArrayContainer and GrowableGridContainer are global classes, no preload needed.

# Container tag constants - imported from BattleManager (single source of truth)
const C = preload("res://scripts/Constants.gd")
const BATTLE_CONTAINER_TAGS = C.BATTLE_CONTAINER_TAGS

# ============================================================================
# STATE DATA
# ============================================================================

## All battle instances (units, items, trinkets) in the current battle
var _battle_instances: Dictionary = {}

## Container name -> DataContainer mapping
var _containers: Dictionary = {}

## Enemy trinkets array for quick access
var enemy_trinkets: Array[GachaBallInstance] = []

## Turn-scoped metadata for first-killed tracking and resurrection flags
var _turn_metadata: Dictionary = {}

## Turn-scoped death registry: {uuid: {team, died_in_phase, def_id}}
var _dead_this_turn: Dictionary = {}

## Gacha tokens available for spending
var _gacha_tokens: int = 0

# ============================================================================
# CONTAINER ACCESS
# ============================================================================

func get_container(container_name: StringName) -> DataContainer:
	if _containers.has(container_name):
		return _containers[container_name]

	var new_container: DataContainer

	match container_name:
		BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			new_container = FixedArrayContainer.new(5)
		BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
			new_container = FixedArrayContainer.new(3)
		BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
			new_container = FixedArrayContainer.new(2)
		BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
			new_container = GrowableGridContainer.new(24)
		BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			new_container = FixedArrayContainer.new(5)
		BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
			new_container = FixedArrayContainer.new(5)
		_: # Default case for BattleInventoryT*
			if container_name.begins_with("BattleInventoryT"):
				new_container = GrowableGridContainer.new(24)
			else:
				# Failsafe for unknown container types
				new_container = FixedArrayContainer.new(1)

	_containers[container_name] = new_container
	return new_container

func get_instance(uuid: String) -> GachaBallInstance:
	return _battle_instances.get(uuid)

func get_all_instances() -> Dictionary:
	return _battle_instances

func get_instances_in_container(container_tag: StringName) -> Array[GachaBallInstance]:
	var result: Array[GachaBallInstance] = []
	var container = get_container(container_tag)
	if not is_instance_valid(container): return result
	var uuids = container.get_all_non_empty_uuids()
	for uuid in uuids:
		var instance = get_instance(uuid)
		if is_instance_valid(instance): result.append(instance)
	
	# Sort by location index
	result.sort_custom(func(a, b):
		var loc_a = get_location_for_uuid(a.ball_uuid)
		var loc_b = get_location_for_uuid(b.ball_uuid)
		if not loc_a or not loc_b: return false
		return loc_a.index < loc_b.index
	)
	return result

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"BattleInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	var instance = get_instance(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	var container = get_container(loc.container)
	if not is_instance_valid(container): return null
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid) if not uuid.is_empty() else null

# ============================================================================
# LOCATION MANAGEMENT
# ============================================================================

func update_instance_location(uuid: String, container_name: StringName, index: int) -> void:
	var instance = get_instance(uuid)
	if not is_instance_valid(instance): return
	
	instance.location_container_tag = container_name
	instance.location_slot_index = index
	# Only clear equip linkage when moving to a physical container or clearing location.
	if container_name != C.CONTAINER_EQUIPPED_ITEM:
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1

func remove_instance_from_container(instance: GachaBallInstance) -> void:
	assert(is_instance_valid(instance), "remove_instance_from_container: instance is null")
	var loc = get_location_for_uuid(instance.ball_uuid)
	assert(is_instance_valid(loc), "remove_instance_from_container: instance has no location")
	var container = get_container(loc.container)
	if is_instance_valid(container):
		var uuids = container.get_all_uuids()
		var idx: int = uuids.find(instance.ball_uuid)
		if idx != -1:
			container.set_uuid(idx, "")
			update_instance_location(instance.ball_uuid, &"", -1)
		else:
			push_error("Remove failed: %s not found in stated container %s" % [instance.ball_uuid, String(loc.container)])

# ============================================================================
# TURN/DEATH TRACKING
# ============================================================================

func clear_turn_data() -> void:
	_turn_metadata.clear()
	_dead_this_turn.clear()

func get_turn_metadata() -> Dictionary:
	return _turn_metadata

func get_dead_this_turn() -> Dictionary:
	return _dead_this_turn

func set_gacha_tokens(value: int) -> void:
	_gacha_tokens = value

func get_gacha_tokens() -> int:
	return _gacha_tokens

func add_gacha_tokens(amount: int) -> void:
	_gacha_tokens += amount

func spend_gacha_tokens(amount: int) -> bool:
	if _gacha_tokens < amount:
		return false
	_gacha_tokens -= amount
	return true

# ============================================================================
# RESHUFFLE (Internal Helper)
# ============================================================================

## Helper to determine if an instance is player-owned based on container
func is_player_owned(instance: GachaBallInstance) -> bool:
	if not is_instance_valid(instance):
		return false
	var loc = instance.get_location()
	if not is_instance_valid(loc):
		return false
	var container = String(loc.container)
	# Player containers or common battle containers (discard, etc.)
	return (container.begins_with("Player") or
			container.begins_with("BattleInventory") or
			container == "DiscardPile" or
			container == "ItemInventory")

## Reshuffle instances of specified tier from discard back to draw pool
func reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag = "BattleInventoryT%d" % tier_to_reshuffle
	var dest_container = get_container(dest_container_tag)
	if not is_instance_valid(source_container) or not is_instance_valid(dest_container):
		return false
	var all_discarded = get_instances_in_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var instances_to_move: Array[GachaBallInstance] = []
	for inst in all_discarded:
		var inst_def = inst.get_definition()
		if (inst_def is GachaBallDefinition) and inst_def.tier == tier_to_reshuffle and is_player_owned(inst):
			instances_to_move.append(inst)
	if instances_to_move.is_empty():
		return false
	for instance in instances_to_move:
		# Restore stats to base values before moving back to draw pool
		instance.reset_battle_stats()
		remove_instance_from_container(instance)
		var new_index = dest_container.find_first_empty_slot()
		if new_index == -1:
			new_index = dest_container.get_all_uuids().size()
		dest_container.set_uuid(new_index, instance.ball_uuid)
		update_instance_location(instance.ball_uuid, dest_container_tag, new_index)
	return true

# ============================================================================
# INITIALIZATION / CLEANUP
# ============================================================================

func clear() -> void:
	_battle_instances.clear()
	_containers.clear()
	enemy_trinkets.clear()
	_turn_metadata.clear()
	_dead_this_turn.clear()
	_gacha_tokens = 0

func register_instance(instance: GachaBallInstance) -> void:
	_battle_instances[instance.ball_uuid] = instance

func unregister_instance(uuid: String) -> void:
	_battle_instances.erase(uuid)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Check if an instance is in a player container (for targeting)
func is_player_unit(instance: GachaBallInstance) -> bool:
	if not is_instance_valid(instance):
		return false
	var loc = instance.get_location()
	if not is_instance_valid(loc):
		return false
	return is_in_player_container_tag(loc.container)

## Check if a container tag is a player container
func is_in_player_container_tag(tag: StringName) -> bool:
	return tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or tag == BATTLE_CONTAINER_TAGS.PLAYER_BENCH

# ============================================================================
# ATOMIC MUTATION API (Pure Data - No Signals)
# ============================================================================

## Add an instance to a container. Returns true on success.
## NOTE: Does NOT emit signals - caller is responsible for that.
func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	assert(is_instance_valid(instance), "bm_add_instance: instance is null")
	var container = get_container(container_name)
	if not is_instance_valid(container):
		return false
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			return false
	container.set_uuid(slot, instance.ball_uuid)
	_battle_instances[instance.ball_uuid] = instance
	update_instance_location(instance.ball_uuid, container_name, slot)
	return true

## Remove an instance from the battle. Returns result dict with success and signals_to_emit.
## NOTE: Does NOT emit signals - caller is responsible for emitting signals from the result.
func bm_remove_instance(uuid: String) -> Dictionary:
	var result := {"success": false, "unit_changed_uuid": ""}
	
	assert(not uuid.is_empty(), "bm_remove_instance: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_remove_instance: instance not found for uuid " + uuid)
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return result
	
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if not is_instance_valid(parent):
			return result
		if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
			return result
		# Remove bonuses from the parent before clearing the mapping
		parent.unequip_item_bonus(instance)
		parent.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
		update_instance_location(instance.ball_uuid, &"", -1)
		result.unit_changed_uuid = parent.ball_uuid
	else:
		# If this is a player unit with equipped items, unequip and move them to inventory
		if instance.equipped_item_uuids.size() > 0:
			if is_player_unit(instance):
				var inv := get_container(BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
				for i in range(instance.equipped_item_uuids.size()):
					var it_uuid := instance.equipped_item_uuids[i]
					if it_uuid.is_empty():
						continue
					var it := get_instance(it_uuid)
					if not is_instance_valid(it):
						continue
					instance.equipped_item_uuids[i] = ""
					it.equipped_on_uuid = ""
					it.equipped_slot_index = -1
					if is_instance_valid(inv):
						var empty := inv.find_first_empty_slot()
						if empty != -1:
							inv.set_uuid(empty, it.ball_uuid)
							update_instance_location(it.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY, empty)
						else:
							return result
			else:
				# Enemy unit: destroy equipped items
				for it_uuid in instance.equipped_item_uuids:
					if not it_uuid.is_empty():
						_battle_instances.erase(it_uuid)
		# Extra hardening: clear any stray items that believe they are equipped on this unit
		if is_player_unit(instance):
			var inv2 := get_container(BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
			for k in _battle_instances.keys():
				var maybe_item: GachaBallInstance = _battle_instances[k]
				if not is_instance_valid(maybe_item):
					continue
				if maybe_item.equipped_on_uuid == instance.ball_uuid:
					maybe_item.equipped_on_uuid = ""
					maybe_item.equipped_slot_index = -1
					if is_instance_valid(inv2):
						var empty2 := inv2.find_first_empty_slot()
						if empty2 != -1:
							inv2.set_uuid(empty2, maybe_item.ball_uuid)
							update_instance_location(maybe_item.ball_uuid, BATTLE_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY, empty2)
						else:
							return result
		remove_instance_from_container(instance)
	
	_battle_instances.erase(uuid)
	result.success = true
	return result

# ============================================================================
# VALIDATION
# ============================================================================

## Validate state consistency (Golden Rule check)
## Returns true if state is valid, false otherwise
func validate_state_consistency() -> bool:
	# Pass 1: scan containers, detect duplicates and equipped-item leaks
	var occurrences: Dictionary = {}
	for cname in _containers.keys():
		var c: DataContainer = _containers[cname]
		if not is_instance_valid(c):
			continue
		var uuids := c.get_all_uuids()
		for i in range(uuids.size()):
			var u := uuids[i]
			if u.is_empty():
				continue
			if occurrences.has(u):
				push_error("Duplicate UUID %s also present at %s:%d" % [u, String(cname), i])
				return false
			occurrences[u] = [ {"container": cname, "index": i}]
			var inst: GachaBallInstance = _battle_instances.get(u)
			if not is_instance_valid(inst):
				push_error("Container references missing battle instance %s" % u)
				return false
			if inst.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				push_error("Equipped item %s appears in a battle container slot at %s:%d" % [u, String(cname), i])
				return false
	# Pass 2: verify each instance's declared location matches container truth
	for u in _battle_instances.keys():
		var inst: GachaBallInstance = _battle_instances[u]
		if not is_instance_valid(inst):
			continue
		# Skip dead units - they may be pending cleanup and have no container temporarily
		if _dead_this_turn.has(u):
			continue
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			continue
		if loc.container == C.CONTAINER_EQUIPPED_ITEM:
			var parent: GachaBallInstance = _battle_instances.get(loc.unit_uuid)
			if not is_instance_valid(parent):
				push_error("Equipped item %s has missing parent %s" % [u, loc.unit_uuid])
				return false
			if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
				push_error("Equipped item %s has invalid equipped index %d on %s" % [u, loc.index, parent.ball_uuid])
				return false
			if parent.equipped_item_uuids[loc.index] != u:
				push_error("Equipped item %s mapping mismatch on %s at slot %d" % [u, parent.ball_uuid, loc.index])
				return false
		else:
			# Instances MUST always have a valid container
			if loc.container == &"" or loc.container.is_empty():
				push_error("Golden Rule violation: instance %s has empty container (left in unplaced state)" % u)
				return false
			var c2 := get_container(loc.container)
			if not is_instance_valid(c2):
				push_error("Missing battle container %s for %s" % [String(loc.container), u])
				return false
			var all2 := c2.get_all_uuids()
			if loc.index < 0 or loc.index >= all2.size():
				push_error("Location index out of bounds for %s: %s:%d (capacity=%d)" % [u, String(loc.container), loc.index, all2.size()])
				return false
			var actual = c2.get_uuid(loc.index)
			if actual != u:
				push_error("Location/content mismatch for %s: loc %s:%d has %s" % [u, String(loc.container), loc.index, actual])
				return false
	return true
