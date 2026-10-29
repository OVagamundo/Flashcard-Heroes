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

## Gacha tokens available for spending (synchronized with RunState if present)
var _gacha_tokens: int = 0:
	get:
		if is_instance_valid(GameManager.run_state):
			return GameManager.run_state.current_room_tokens
		return _gacha_tokens
	set(value):
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.current_room_tokens = value
		_gacha_tokens = value

## Slot effects for player lineup slots (size 5, entries can be &"burn", &"lightning", etc., or empty &"")
var player_slot_effects: Array[StringName] = [&"", &"", &"", &"", &""]

## Slot effects for enemy lineup slots (size 5, entries can be &"burn", &"lightning", etc., or empty &"")
var enemy_slot_effects: Array[StringName] = [&"", &"", &"", &"", &""]

## Staged enemy placements for sequential entrance
var staged_enemy_placements: Array = []

## Staged hero placement for entrance
var staged_hero_placement: Dictionary = {}
var staged_hero_instance: GachaBallInstance = null
var staged_hero_items: Array[GachaBallInstance] = []


# ============================================================================
# CONTAINER ACCESS
# ============================================================================

func get_container(container_name: StringName) -> DataContainer:
	if container_name.is_empty() or container_name == C.CONTAINER_EQUIPPED_ITEM:
		return null
	if _containers.has(container_name):
		return _containers[container_name]

	var new_container: DataContainer = null

	match container_name:
		BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
			new_container = FixedArrayContainer.new(C.LINEUP_CAP)
		BATTLE_CONTAINER_TAGS.PLAYER_BENCH, BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
			new_container = FixedArrayContainer.new(C.BENCH_CAP)
		BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD:
			new_container = GrowableGridContainer.new(24)
		BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			new_container = FixedArrayContainer.new(C.ENEMY_TRINKET_CAP)
		BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
			new_container = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
		_:
			if String(container_name).begins_with("BattleInventoryT"):
				new_container = GrowableGridContainer.new(24)
			else:
				return null

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
	if not is_instance_valid(loc):
		return null
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if is_instance_valid(parent) and loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
			var eq_uuid := parent.equipped_item_uuids[loc.index]
			return get_instance(eq_uuid) if not eq_uuid.is_empty() else null
		return null
	var container = get_container(loc.container)
	if not is_instance_valid(container):
		return null
	var uuid = container.get_uuid(loc.index)
	return get_instance(uuid) if not uuid.is_empty() else null

# ============================================================================
# LOCATION MANAGEMENT
# ============================================================================

func update_instance_location(uuid: String, container_name: StringName, index: int) -> void:
	assert(not container_name.is_empty(), "update_instance_location: container_name cannot be empty for active instance %s" % uuid)
	var instance = get_instance(uuid)
	if not is_instance_valid(instance):
		return

	instance.location_container_tag = container_name
	instance.location_slot_index = index
	if container_name != C.CONTAINER_EQUIPPED_ITEM:
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1

## Atomically transfer a registered instance from its current location (container or equipped slot)
## into a destination container slot. Validates destination BEFORE mutating source.
## Returns the destination slot index on success, or -1 if destination has no valid slot.
func transfer_instance_to_container(instance: GachaBallInstance, dest_container_name: StringName, dest_index: int = -1, unequip_bonus: bool = true) -> int:
	assert(is_instance_valid(instance), "transfer_instance_to_container: instance is null")
	assert(_battle_instances.has(instance.ball_uuid), "transfer_instance_to_container: instance %s is not registered in BattleState" % instance.ball_uuid)
	assert(not dest_container_name.is_empty() and dest_container_name != C.CONTAINER_EQUIPPED_ITEM, "transfer_instance_to_container: invalid destination container '%s'" % String(dest_container_name))

	var dest_container := get_container(dest_container_name)
	assert(is_instance_valid(dest_container), "transfer_instance_to_container: unknown destination container '%s'" % String(dest_container_name))

	var loc := instance.get_location()
	assert(is_instance_valid(loc), "transfer_instance_to_container: instance %s has invalid location" % instance.ball_uuid)

	# No-op if already at exact destination container and slot
	if loc.container == dest_container_name and dest_index >= 0 and loc.index == dest_index:
		return dest_index

	# Validate destination slot BEFORE mutating source
	var slot := dest_index
	if slot < 0:
		slot = dest_container.find_first_empty_slot()
		if slot == -1:
			return -1
	else:
		if slot >= dest_container.get_size():
			return -1
		var existing := dest_container.get_uuid(slot)
		if not existing.is_empty():
			return -1

	# Clear source location
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		assert(is_instance_valid(parent), "transfer_instance_to_container: missing parent unit %s for item %s" % [loc.unit_uuid, instance.ball_uuid])
		if loc.index >= 0 and loc.index < parent.equipped_item_uuids.size():
			if parent.equipped_item_uuids[loc.index] == instance.ball_uuid:
				if unequip_bonus:
					parent.unequip_item_bonus(instance)
				parent.equipped_item_uuids[loc.index] = ""
	else:
		var src_container := get_container(loc.container)
		assert(is_instance_valid(src_container), "transfer_instance_to_container: missing source container '%s' for %s" % [String(loc.container), instance.ball_uuid])
		assert(src_container.get_uuid(loc.index) == instance.ball_uuid, "transfer_instance_to_container: source slot %s:%d mismatch for %s" % [String(loc.container), loc.index, instance.ball_uuid])
		src_container.set_uuid(loc.index, "")

	# Place into destination container and update location atomically
	dest_container.set_uuid(slot, instance.ball_uuid)
	update_instance_location(instance.ball_uuid, dest_container_name, slot)
	return slot

## Atomically place the staged hero (and register any equipped hero items) into PlayerLineup.
func place_staged_hero() -> GachaBallInstance:
	if staged_hero_placement.is_empty() or not is_instance_valid(staged_hero_instance):
		return null
	var hero_inst := staged_hero_instance
	var hero_items := staged_hero_items.duplicate()
	var pos: int = int(staged_hero_placement.get("position", 0))
	staged_hero_placement.clear()
	staged_hero_instance = null
	staged_hero_items.clear()

	var added := bm_add_instance(hero_inst, BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, pos)
	assert(added, "place_staged_hero: failed to place hero %s at PlayerLineup:%d" % [hero_inst.ball_uuid, pos])
	for item_inst in hero_items:
		if is_instance_valid(item_inst):
			_battle_instances[item_inst.ball_uuid] = item_inst
	return hero_inst

## Atomically replace a unit in its container slot with a new unit, transferring equipped items directly.
func replace_unit_preserving_items(old_unit: GachaBallInstance, new_unit: GachaBallInstance) -> bool:
	assert(is_instance_valid(old_unit) and is_instance_valid(new_unit), "replace_unit_preserving_items: invalid unit")
	var loc := old_unit.get_location()
	assert(is_instance_valid(loc) and not loc.container.is_empty() and loc.container != C.CONTAINER_EQUIPPED_ITEM, "replace_unit_preserving_items: invalid source location")
	var container := get_container(loc.container)
	assert(is_instance_valid(container) and container.get_uuid(loc.index) == old_unit.ball_uuid, "replace_unit_preserving_items: source slot mismatch")

	container.set_uuid(loc.index, new_unit.ball_uuid)
	_battle_instances[new_unit.ball_uuid] = new_unit
	update_instance_location(new_unit.ball_uuid, loc.container, loc.index)

	for slot_idx in range(old_unit.equipped_item_uuids.size()):
		var item_uuid := old_unit.equipped_item_uuids[slot_idx]
		if item_uuid.is_empty():
			continue
		var item_inst := get_instance(item_uuid)
		old_unit.equipped_item_uuids[slot_idx] = ""
		if not is_instance_valid(item_inst):
			continue
		old_unit.unequip_item_bonus(item_inst)
		if slot_idx < new_unit.equipped_item_uuids.size() and new_unit.equipped_item_uuids[slot_idx].is_empty():
			new_unit.equipped_item_uuids[slot_idx] = item_inst.ball_uuid
			item_inst.equipped_on_uuid = new_unit.ball_uuid
			item_inst.equipped_slot_index = slot_idx
			item_inst.location_container_tag = C.CONTAINER_EQUIPPED_ITEM
			item_inst.location_slot_index = slot_idx
			new_unit.equip_item_bonus(item_inst)
		else:
			var fallback_tag := BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE if is_player_owned(new_unit) else BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD
			var fallback_container := get_container(fallback_tag)
			var f_slot := fallback_container.find_first_empty_slot()
			assert(f_slot != -1, "replace_unit_preserving_items: failed to allocate overflow slot")
			fallback_container.set_uuid(f_slot, item_inst.ball_uuid)
			update_instance_location(item_inst.ball_uuid, fallback_tag, f_slot)

	_battle_instances.erase(old_unit.ball_uuid)
	return true

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
	if amount <= 0: return
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_tokens(amount, true)
		_gacha_tokens = GameManager.run_state.current_room_tokens
	else:
		_gacha_tokens += amount

func spend_gacha_tokens(amount: int) -> bool:
	if is_instance_valid(GameManager.run_state):
		var success: bool = GameManager.run_state.spend_tokens(amount, true)
		if success:
			_gacha_tokens = GameManager.run_state.current_room_tokens
		return success
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
	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if is_instance_valid(parent):
			return is_player_owned(parent)
		return false
	var container = String(loc.container)
	# Player containers or common battle containers (discard, etc.)
	return (container.begins_with("Player") or
			container.begins_with("BattleInventory") or
			container == "DiscardPile")

## Reshuffle instances of specified tier from discard back to draw pool
func reshuffle_tier_from_discard(tier_to_reshuffle: int) -> bool:
	var source_container = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var dest_container_tag: StringName = &"BattleInventoryT%d" % tier_to_reshuffle
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
		var new_index := transfer_instance_to_container(instance, dest_container_tag, -1)
		assert(new_index != -1, "reshuffle_tier_from_discard: failed to transfer %s to %s" % [instance.ball_uuid, String(dest_container_tag)])
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
	player_slot_effects = [&"", &"", &"", &"", &""]
	enemy_slot_effects = [&"", &"", &"", &"", &""]
	staged_enemy_placements.clear()
	staged_hero_placement.clear()
	staged_hero_instance = null
	staged_hero_items.clear()


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

## Add a new instance to a container. Returns true on success.
## NOTE: Does NOT emit signals - caller is responsible for that.
func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	assert(is_instance_valid(instance), "bm_add_instance: instance is null")
	assert(not container_name.is_empty() and container_name != C.CONTAINER_EQUIPPED_ITEM, "bm_add_instance: invalid container_name '%s' for %s" % [String(container_name), instance.ball_uuid])
	var container = get_container(container_name)
	assert(is_instance_valid(container), "bm_add_instance: unknown battle container '%s'" % String(container_name))
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			return false
	else:
		if slot >= container.get_size():
			push_error("bm_add_instance rejected: slot %d out of bounds in %s (capacity=%d)" % [slot, container_name, container.get_size()])
			return false
		var existing := container.get_uuid(slot)
		if not existing.is_empty():
			push_error("bm_add_instance rejected: slot %d in %s is already occupied by %s" % [slot, container_name, existing])
			return false
	container.set_uuid(slot, instance.ball_uuid)
	_battle_instances[instance.ball_uuid] = instance
	update_instance_location(instance.ball_uuid, container_name, slot)
	return true

## Remove an instance from the battle. Returns result dict with success and unit_changed_uuid.
## NOTE: Does NOT emit signals - caller is responsible for emitting signals from the result.
func bm_remove_instance(uuid: String) -> Dictionary:
	var result := {"success": false, "unit_changed_uuid": ""}

	assert(not uuid.is_empty(), "bm_remove_instance: uuid is empty")
	var instance := get_instance(uuid)
	assert(is_instance_valid(instance), "bm_remove_instance: instance not found for uuid " + uuid)
	var loc := instance.get_location()
	assert(is_instance_valid(loc), "bm_remove_instance: instance %s has invalid location" % uuid)

	if loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var parent := get_instance(loc.unit_uuid)
		if not is_instance_valid(parent):
			return result
		if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
			return result
		parent.unequip_item_bonus(instance)
		parent.equipped_item_uuids[loc.index] = ""
		result.unit_changed_uuid = parent.ball_uuid
	else:
		if instance.equipped_item_uuids.size() > 0:
			if is_player_owned(instance):
				var bench := get_container(BATTLE_CONTAINER_TAGS.PLAYER_BENCH)
				for i in range(instance.equipped_item_uuids.size()):
					var it_uuid := instance.equipped_item_uuids[i]
					if it_uuid.is_empty():
						continue
					var it := get_instance(it_uuid)
					if not is_instance_valid(it):
						instance.equipped_item_uuids[i] = ""
						continue
					var dest_tag := BATTLE_CONTAINER_TAGS.PLAYER_BENCH
					if not is_instance_valid(bench) or bench.find_first_empty_slot() == -1:
						dest_tag = BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
					var moved_slot := transfer_instance_to_container(it, dest_tag, -1, true)
					assert(moved_slot != -1, "bm_remove_instance: failed to rehome item %s from %s" % [it.ball_uuid, instance.ball_uuid])
					result.unit_changed_uuid = instance.ball_uuid
			else:
				for i in range(instance.equipped_item_uuids.size()):
					var it_uuid := instance.equipped_item_uuids[i]
					if it_uuid.is_empty():
						continue
					instance.equipped_item_uuids[i] = ""
					_battle_instances.erase(it_uuid)

		var c := get_container(loc.container)
		assert(is_instance_valid(c), "bm_remove_instance: missing container '%s' for %s" % [String(loc.container), uuid])
		if loc.index >= 0 and c.get_uuid(loc.index) == instance.ball_uuid:
			c.set_uuid(loc.index, "")

	_battle_instances.erase(uuid)
	result.success = true
	return result

# ============================================================================
# VALIDATION
# ============================================================================

## Validate state consistency (Golden Rule check).
## Every instance in _battle_instances must be either in a valid container slot or equipped on a registered parent unit.
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
			occurrences[u] = [{"container": cname, "index": i}]
			var inst: GachaBallInstance = _battle_instances.get(u)
			if not is_instance_valid(inst):
				push_error("Container references missing battle instance %s" % u)
				return false
			if inst.get_location().container == C.CONTAINER_EQUIPPED_ITEM:
				push_error("Equipped item %s appears in a battle container slot at %s:%d" % [u, String(cname), i])
				return false
	# Pass 2: verify every registered instance's declared location matches container/equipment truth
	for u in _battle_instances.keys():
		var inst: GachaBallInstance = _battle_instances[u]
		if not is_instance_valid(inst):
			push_error("Invalid battle instance registered for UUID %s" % u)
			return false
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			push_error("Instance %s returned invalid LocationIdentifier" % u)
			return false
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
