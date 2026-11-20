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

## Player Shelf capacity purchased for this battle. Resets when the next BattleState is created.
var player_shelf_slots_unlocked: int = C.INITIAL_SHELF_SLOTS

## Monotonic counter and per-UUID sequence index tracking the exact chronological order
## in which units transition to <= 0 HP during a turn.
var _lethal_sequence_counter: int = 0
var _lethal_sequence_by_uuid: Dictionary = {}

## Re-entrancy guard ensuring a single casualty's knockout cascade resolves atomically
## before outer knockout loops pick the next casualty.
var is_resolving_knockouts: bool = false

## Units whose knockout completion is deferred until pending counter-attacks resolve
var deferred_knockouts: Array[String] = []

## Deferred WHEN_ALLY_KNOCKED_OUT contexts waiting for counter-attacking units
var deferred_ally_knockouts_player: Array[TriggerContext] = []
var deferred_ally_knockouts_enemy: Array[TriggerContext] = []

## Enemy instance UUIDs deferred from final erasure until combat event playback finishes
var deferred_enemy_erasures: Array[String] = []
var _inventory_events: Array[CombatEvent] = []

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


func copy_for_simulation() -> BattleState:
	assert(staged_hero_placement.is_empty() and staged_enemy_placements.is_empty(), "Preview requires a settled battle entrance")
	assert(not is_resolving_knockouts and deferred_knockouts.is_empty() and deferred_enemy_erasures.is_empty(), "Preview requires settled knockouts")
	assert(deferred_ally_knockouts_player.is_empty() and deferred_ally_knockouts_enemy.is_empty(), "Preview requires settled ally knockout effects")
	assert(_inventory_events.is_empty(), "Preview requires settled inventory events")
	var copy := BattleState.new()
	copy._turn_metadata = _turn_metadata.duplicate(true)
	copy._dead_this_turn = _dead_this_turn.duplicate(true)
	copy._lethal_sequence_counter = _lethal_sequence_counter
	copy._lethal_sequence_by_uuid = _lethal_sequence_by_uuid.duplicate()
	copy.player_shelf_slots_unlocked = player_shelf_slots_unlocked
	copy.player_slot_effects = player_slot_effects.duplicate()
	copy.enemy_slot_effects = enemy_slot_effects.duplicate()
	for uuid: String in _battle_instances:
		copy._battle_instances[uuid] = get_instance(uuid).copy_for_simulation()
	for tag: StringName in _containers:
		var source: DataContainer = _containers[tag]
		var target: DataContainer = GrowableGridContainer.new(source.get_size()) if source is GrowableGridContainer else FixedArrayContainer.new(source.get_size())
		target.container_tag = tag
		for index: int in range(source.get_size()):
			target.set_uuid(index, source.get_uuid(index))
		copy._containers[tag] = target
	for trinket: GachaBallInstance in enemy_trinkets:
		copy.enemy_trinkets.append(copy.get_instance(trinket.ball_uuid))
	return copy

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
		BATTLE_CONTAINER_TAGS.PLAYER_SHELF:
			new_container = FixedArrayContainer.new(C.PLAYER_SHELF_CAP)
		BATTLE_CONTAINER_TAGS.ENEMY_SHELF:
			new_container = FixedArrayContainer.new(C.SHELF_CAP)
		BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
			new_container = FixedArrayContainer.new(C.BATTLE_DISCARD_CAP)
		BATTLE_CONTAINER_TAGS.ENEMY_GRAVEYARD:
			new_container = GrowableGridContainer.new(24)
		BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
			new_container = FixedArrayContainer.new(C.ENEMY_TRINKET_CAP)
		BATTLE_CONTAINER_TAGS.ENEMY_BANNER:
			new_container = FixedArrayContainer.new(1)
		BATTLE_CONTAINER_TAGS.PLAYER_TRINKETS:
			new_container = FixedArrayContainer.new(C.PLAYER_TRINKET_CAP)
		_:
			if String(container_name).begins_with("BattleInventoryT"):
				new_container = FixedArrayContainer.new(C.BATTLE_TIER_CAP)
			else:
				return null

	new_container.container_tag = container_name
	_containers[container_name] = new_container
	return new_container

func find_first_empty_player_shelf_slot() -> int:
	var shelf: DataContainer = get_container(BATTLE_CONTAINER_TAGS.PLAYER_SHELF)
	assert(is_instance_valid(shelf), "find_first_empty_player_shelf_slot: PlayerShelf container is required")
	var slot_limit: int = mini(player_shelf_slots_unlocked, shelf.get_size())
	for slot_index in range(slot_limit):
		if shelf.get_uuid(slot_index).is_empty():
			return slot_index
	return -1

func is_player_shelf_slot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < player_shelf_slots_unlocked

## Equipped item slots inherit the placement of their holder.
func is_lineup_location(location: LocationIdentifier) -> bool:
	if location.container == C.CONTAINER_EQUIPPED_ITEM:
		var holder: GachaBallInstance = get_instance(location.unit_uuid)
		assert(holder != null, "is_lineup_location: equipped slot holder is missing")
		return holder.location_container_tag in [BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP]
	return location.container in [BATTLE_CONTAINER_TAGS.PLAYER_LINEUP, BATTLE_CONTAINER_TAGS.ENEMY_LINEUP]

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

func has_tier_space(tier: int) -> bool:
	return get_container(&"BattleInventoryT%d" % tier).find_first_empty_slot() >= 0

func _resolve_storage_destination(tag: StringName) -> StringName:
	if String(tag).begins_with("BattleInventoryT") and get_container(tag).find_first_empty_slot() == -1:
		return BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
	return tag

func _allocate_discard_slot() -> int:
	var discard: DataContainer = get_container(BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE)
	var empty_slot: int = discard.find_first_empty_slot()
	if empty_slot >= 0:
		return empty_slot
	var ejected_uuid: String = RNGManager.gacha_rng.pick_random(discard.get_all_non_empty_uuids())
	var ejected: GachaBallInstance = get_instance(ejected_uuid)
	var slot: int = ejected.location_slot_index
	var payload := CombatPayload.new()
	payload.unit_tier = ejected.get_definition().tier
	payload.new_unit_snapshot = {
		"tier": payload.unit_tier,
		"attributes": {&"level": ejected.level},
		"definition_id": ejected.definition_id,
	}
	var event := CombatEvent.new(CombatEvent.Type.DISCARD_EJECT, {"source_uuid": ejected_uuid, "visual_payload": payload})
	_inventory_events.append(event)
	# Discarded capsules are sealed. Remove any attached equipment from this battle with its capsule.
	for item_uuid: String in ejected.equipped_item_uuids:
		if not item_uuid.is_empty():
			_battle_instances.erase(item_uuid)
	discard.set_uuid(slot, "")
	_battle_instances.erase(ejected_uuid)
	return slot

func take_inventory_events() -> Array[CombatEvent]:
	var events: Array[CombatEvent] = _inventory_events
	_inventory_events = []
	return events

## Atomically transfer a registered instance from its current location (container or equipped slot)
## into a destination container slot. Validates destination BEFORE mutating source.
## Returns the destination slot index on success, or -1 if destination has no valid slot.
func transfer_instance_to_container(instance: GachaBallInstance, dest_container_name: StringName, dest_index: int = -1, unequip_bonus: bool = true) -> int:
	assert(is_instance_valid(instance), "transfer_instance_to_container: instance is null")
	assert(_battle_instances.has(instance.ball_uuid), "transfer_instance_to_container: instance %s is not registered in BattleState" % instance.ball_uuid)
	assert(not dest_container_name.is_empty() and dest_container_name != C.CONTAINER_EQUIPPED_ITEM, "transfer_instance_to_container: invalid destination container '%s'" % String(dest_container_name))

	var loc := instance.get_location()
	assert(is_instance_valid(loc), "transfer_instance_to_container: instance %s has invalid location" % instance.ball_uuid)
	# Incubation is the only way to reseal a deployed unit.
	if dest_container_name == BATTLE_CONTAINER_TAGS.PLAYER_SHELF:
		var incubating: bool = loc.container == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and get_equipped_incubator(instance) != null
		if not incubating and loc.container != BATTLE_CONTAINER_TAGS.PLAYER_SHELF and not String(loc.container).begins_with("BattleInventoryT"):
			return -1

	# No-op if already at exact destination container and slot
	if loc.container == dest_container_name and dest_index >= 0 and loc.index == dest_index:
		return dest_index
	if loc.container != dest_container_name:
		dest_container_name = _resolve_storage_destination(dest_container_name)
		if loc.container == dest_container_name:
			return loc.index
	var entering_discard: bool = dest_container_name == BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE and loc.container != dest_container_name
	if not entering_discard and dest_container_name == BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE and dest_index < 0:
		return loc.index
	var dest_container: DataContainer = get_container(dest_container_name)
	assert(dest_container != null, "transfer_instance_to_container: unknown destination %s" % dest_container_name)

	# Validate the destination before detaching the source. Discard always makes room.
	var slot: int = dest_index
	if entering_discard:
		slot = -1
	elif slot < 0:
		slot = find_first_empty_player_shelf_slot() if dest_container_name == BATTLE_CONTAINER_TAGS.PLAYER_SHELF else dest_container.find_first_empty_slot()
		if slot == -1:
			return -1
	else:
		if slot >= dest_container.get_size():
			return -1
		if dest_container_name == BATTLE_CONTAINER_TAGS.PLAYER_SHELF and slot >= player_shelf_slots_unlocked:
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

	# An equipped source is already detached if its old holder is ejected.
	if entering_discard:
		slot = _allocate_discard_slot()
	dest_container.set_uuid(slot, instance.ball_uuid)
	update_instance_location(instance.ball_uuid, dest_container_name, slot)
	return slot

func get_equipped_incubator(unit: GachaBallInstance) -> GachaBallInstance:
	for item_uuid: String in unit.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		var item: GachaBallInstance = get_instance(item_uuid)
		assert(item != null, "Equipped item %s must be registered" % item_uuid)
		if item.definition_id == C.ITEM_INCUBATOR:
			return item
	return null

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
	_lethal_sequence_counter = 0
	_lethal_sequence_by_uuid.clear()
	is_resolving_knockouts = false
	deferred_knockouts.clear()
	deferred_ally_knockouts_player.clear()
	deferred_ally_knockouts_enemy.clear()
	deferred_enemy_erasures.clear()

func record_lethal_transition(uuid: String) -> int:
	if uuid.is_empty():
		return 999999
	if not _lethal_sequence_by_uuid.has(uuid):
		_lethal_sequence_counter += 1
		_lethal_sequence_by_uuid[uuid] = _lethal_sequence_counter
	return int(_lethal_sequence_by_uuid[uuid])

func clear_lethal_transition(uuid: String) -> void:
	_lethal_sequence_by_uuid.erase(uuid)

func get_lethal_sequence(uuid: String) -> int:
	return int(_lethal_sequence_by_uuid.get(uuid, 999999))

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
	player_shelf_slots_unlocked = C.INITIAL_SHELF_SLOTS
	_battle_instances.clear()
	_containers.clear()
	enemy_trinkets.clear()
	_turn_metadata.clear()
	_dead_this_turn.clear()
	_lethal_sequence_counter = 0
	_lethal_sequence_by_uuid.clear()
	is_resolving_knockouts = false
	deferred_knockouts.clear()
	deferred_ally_knockouts_player.clear()
	deferred_ally_knockouts_enemy.clear()
	deferred_enemy_erasures.clear()
	_inventory_events.clear()
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
	return tag == BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or tag == BATTLE_CONTAINER_TAGS.PLAYER_SHELF

# ============================================================================
# ATOMIC MUTATION API (Pure Data - No Signals)
# ============================================================================

## Add a new instance to a container. Returns true on success.
## NOTE: Does NOT emit signals - caller is responsible for that.
func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1, allow_locked_shelf_slot: bool = false) -> bool:
	assert(is_instance_valid(instance), "bm_add_instance: instance is null")
	assert(not container_name.is_empty() and container_name != C.CONTAINER_EQUIPPED_ITEM, "bm_add_instance: invalid container_name '%s' for %s" % [String(container_name), instance.ball_uuid])
	container_name = _resolve_storage_destination(container_name)
	if container_name == BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
		index = _allocate_discard_slot()
	var container: DataContainer = get_container(container_name)
	assert(is_instance_valid(container), "bm_add_instance: unknown battle container '%s'" % String(container_name))
	var slot := index
	if slot < 0:
		slot = find_first_empty_player_shelf_slot() if container_name == BATTLE_CONTAINER_TAGS.PLAYER_SHELF else container.find_first_empty_slot()
		if slot == -1:
			return false
	else:
		if slot >= container.get_size():
			push_error("bm_add_instance rejected: slot %d out of bounds in %s (capacity=%d)" % [slot, container_name, container.get_size()])
			return false
		if container_name == BATTLE_CONTAINER_TAGS.PLAYER_SHELF and slot >= player_shelf_slots_unlocked and not allow_locked_shelf_slot:
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
				for i in range(instance.equipped_item_uuids.size()):
					var it_uuid := instance.equipped_item_uuids[i]
					if it_uuid.is_empty():
						continue
					var it := get_instance(it_uuid)
					if not is_instance_valid(it):
						instance.equipped_item_uuids[i] = ""
						continue
					# Opened equipment cannot return to sealed Shelf storage when its holder leaves.
					var moved_slot := transfer_instance_to_container(it, BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, -1, true)
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
