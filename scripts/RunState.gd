
class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

const FlashcardProgress = preload("res://scripts/FlashcardProgress.gd")

@export var gold: int = 0
@export var day: int = 1
@export var hero_instance: GachaBallInstance

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Flashcard learning progress - key = card_id (StringName), value = FlashcardProgress
@export var flashcard_progress: Dictionary = {} # key = StringName, value = FlashcardProgress
@export var active_deck_ids: Array[StringName] = [] # Cards available in the mini-game

# All containers indexed by name (e.g., "RunInventoryT1", "PlayerLineup", etc.)
var _containers: Dictionary[StringName, DataContainer] = {}

static var RUN_CONTAINER_TAGS: Dictionary = {
	HERO = &"Hero",
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	PLAYER_ITEM_INVENTORY = &"ItemInventory"
}

# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	return run_instances.get(uuid)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null
	var container = get_container(loc.container)
	if not is_instance_valid(container):
		return null
	var uuid = container.get_uuid(loc.index)
	if uuid.is_empty():
		return null
	return get_instance_by_uuid(uuid)

func get_inventory_tier_instances(tier: int) -> Array[GachaBallInstance]:
	var instances: Array[GachaBallInstance] = []
	var container_name = &"RunInventoryT%d" % tier
	var container = get_container(container_name)
	if is_instance_valid(container):
		var uuids = container.get_all_non_empty_uuids()
		for uuid in uuids:
			var instance = get_instance_by_uuid(uuid)
			if is_instance_valid(instance):
				instances.append(instance)
	return instances

func _normalize_container_tag(tag: StringName) -> StringName:
	var s := String(tag)
	if s.begins_with("RUN_INVENTORY_T"):
		var suffix := s.substr(len("RUN_INVENTORY_T"))
		return &"RunInventoryT%s" % suffix
	return tag

func get_all_instances() -> Dictionary:
	return run_instances

func get_run_inventory_containers() -> Dictionary:
	var inventory_data: Dictionary = {}
	for tier in [1, 2, 3]:
		var container_name = &"RunInventoryT%d" % tier
		var container = get_container(container_name)
		if is_instance_valid(container):
			inventory_data[container_name] = container
	return inventory_data

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	if uuid.is_empty():
		return null
	
	var instance = get_instance_by_uuid(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	return null

func get_container(container_name: StringName) -> DataContainer:
	# Check if container exists
	if _containers.has(container_name):
		return _containers[container_name]
	
	# Handle standard containers with default sizes if they don't exist yet
	if container_name == RUN_CONTAINER_TAGS.PLAYER_LINEUP or container_name == RUN_CONTAINER_TAGS.PLAYER_BENCH:
		_containers[container_name] = FixedArrayContainer.new(6)
		return _containers[container_name]
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
		_containers[container_name] = FixedArrayContainer.new(12)
		return _containers[container_name]
	
	return null

# ------------------------------------------------------------------
# Mutation helpers
# ------------------------------------------------------------------

func remove_instance_by_uuid(uuid: String) -> void:
	run_instances.erase(uuid)

# ------------------------------------------------------------------
# Atomic mutation API
# ------------------------------------------------------------------

func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	# Adds an instance to the given container/index atomically.
	if not is_instance_valid(instance):
		return false
	var container = get_container(container_name)
	if not is_instance_valid(container):
		return false
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			return false
	# Update Index
	container.set_uuid(slot, instance.ball_uuid)
	# Update Truth
	instance.location_container_tag = container_name
	instance.location_slot_index = slot
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1
	# Register
	run_instances[instance.ball_uuid] = instance
	# Validate (debug only)
	if OS.is_debug_build():
		_validate_state_consistency()
	# Emit
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Progression and Unit Stats atomic API
# ------------------------------------------------------------------

func advance_day(delta: int = 1) -> bool:
	if delta == 0:
		return true
	day += delta
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	return true

func modify_unit_stats(unit_uuid: String, hp_delta: int = 0, pwr_delta: int = 0) -> bool:
	if unit_uuid.is_empty():
		return false
	var inst := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(inst):
		return false
	if hp_delta != 0:
		inst.current_hp += hp_delta
	if pwr_delta != 0:
		inst.current_pwr += pwr_delta
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("unit_stats_changed", unit_uuid)
	SignalBus.emit_signal("run_data_changed")
	return true

func remove_instance(uuid: String) -> bool:
	# Removes an instance from its current location and registry.
	if uuid.is_empty():
		return false
	var instance := get_instance_by_uuid(uuid)
	if not is_instance_valid(instance):
		return false
	var loc := instance.get_location()
	if not is_instance_valid(loc):
		return false
	if loc.container == &"equipped_item":
		# Clearing from equipped slot
		var parent_unit := get_instance_by_uuid(loc.unit_uuid)
		if not is_instance_valid(parent_unit):
			return false
		if loc.index < 0 or loc.index >= parent_unit.equipped_item_uuids.size():
			return false
		parent_unit.equipped_item_uuids[loc.index] = ""
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1
	else:
		var container := get_container(loc.container)
		if not is_instance_valid(container):
			return false
		if container.get_uuid(loc.index) == instance.ball_uuid:
			container.set_uuid(loc.index, "")
	# Erase from registry
	run_instances.erase(uuid)
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func move_instance(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	# Moves an instance from source to target. Handles equipping when target is equipped_item.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	var instance: GachaBallInstance = get_instance_by_location(source_loc)
	if not is_instance_valid(instance):
		return false
	# Equipping path
	if target_loc.container == &"equipped_item":
		var unit_instance: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
		if not is_instance_valid(unit_instance):
			return false
		return equip_item(instance.ball_uuid, unit_instance.ball_uuid, target_loc.index)
	# Default move between containers
	var from_container: DataContainer = get_container(source_loc.container)
	var to_container: DataContainer = get_container(target_loc.container)
	if not is_instance_valid(from_container) or not is_instance_valid(to_container):
		return false
	# Clear from source index (Index)
	if source_loc.container != &"equipped_item":
		if from_container.get_uuid(source_loc.index) == instance.ball_uuid:
			from_container.set_uuid(source_loc.index, "")
	# Place into target index (Index)
	to_container.set_uuid(target_loc.index, instance.ball_uuid)
	# Update Truth
	instance.location_container_tag = target_loc.container
	instance.location_slot_index = target_loc.index
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1
	# Validate and emit
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

func swap_instances(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> bool:
	# Swaps two instances across containers, supporting equipped slots.
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return false
	var a: GachaBallInstance = get_instance_by_location(source_loc)
	var b: GachaBallInstance = get_instance_by_location(target_loc)
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	# If swapping with an equipped slot
	if target_loc.container == &"equipped_item":
		# Equip A onto target unit; move B to source slot
		var target_unit: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
		if not is_instance_valid(target_unit):
			return false
		var target_slot := target_loc.index
		# Remove A from its source index
		if source_loc.container != &"equipped_item":
			var src_container: DataContainer = get_container(source_loc.container)
			if not is_instance_valid(src_container):
				return false
			if src_container.get_uuid(source_loc.index) == a.ball_uuid:
				src_container.set_uuid(source_loc.index, "")
		# If slot occupied by B, move B to source
		var moved_b_to_source := false
		if is_instance_valid(b) and b.ball_uuid != "":
			# If B is currently equipped, clear its equip slot
			if b.get_location().container == &"equipped_item":
				var parent: GachaBallInstance = run_instances.get(target_loc.unit_uuid)
				if is_instance_valid(parent) and target_slot >= 0 and target_slot < parent.equipped_item_uuids.size():
					parent.equipped_item_uuids[target_slot] = ""
					b.equipped_on_uuid = ""
					b.equipped_slot_index = -1
			# Place B into source container slot
			var src_container2: DataContainer = get_container(source_loc.container)
			if is_instance_valid(src_container2):
				src_container2.set_uuid(source_loc.index, b.ball_uuid)
				b.location_container_tag = source_loc.container
				b.location_slot_index = source_loc.index
				b.equipped_on_uuid = ""
				b.equipped_slot_index = -1
				moved_b_to_source = true
		# Equip A into target slot
		var ok := equip_item(a.ball_uuid, target_unit.ball_uuid, target_slot)
		if not ok:
			return false
		if OS.is_debug_build():
			_validate_state_consistency()
		return true
	# General container-to-container swap
	var a_container := get_container(source_loc.container)
	var b_container := get_container(target_loc.container)
	if not is_instance_valid(a_container) or not is_instance_valid(b_container):
		return false
	# Swap index values
	if a_container.get_uuid(source_loc.index) != a.ball_uuid:
		return false
	var b_uuid := b.ball_uuid
	b_container.set_uuid(target_loc.index, a.ball_uuid)
	a_container.set_uuid(source_loc.index, b_uuid)
	# Update Truth
	a.location_container_tag = target_loc.container
	a.location_slot_index = target_loc.index
	a.equipped_on_uuid = ""
	a.equipped_slot_index = -1
	b.location_container_tag = source_loc.container
	b.location_slot_index = source_loc.index
	b.equipped_on_uuid = ""
	b.equipped_slot_index = -1
	# Validate and emit
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true

# ------------------------------------------------------------------
# Economy (Gold) atomic API
# ------------------------------------------------------------------

func add_gold(amount: int) -> bool:
	# Adds gold atomically; emits change signals
	if amount == 0:
		return true
	if amount < 0:
		return spend_gold(-amount)
	gold += amount
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("gold_changed", gold)
	SignalBus.emit_signal("run_data_changed")
	return true

func spend_gold(amount: int) -> bool:
	# Spends gold if available; emits change signals
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	if OS.is_debug_build():
		_validate_state_consistency()
	SignalBus.emit_signal("gold_changed", gold)
	SignalBus.emit_signal("run_data_changed")
	return true


func equip_item(item_uuid: String, unit_uuid: String, slot_index: int = -1) -> bool:
	# Equips an item onto a unit, filling first empty slot if not specified.
	if item_uuid.is_empty() or unit_uuid.is_empty():
		return false
	var item := get_instance_by_uuid(item_uuid)
	var unit := get_instance_by_uuid(unit_uuid)
	if not is_instance_valid(item) or not is_instance_valid(unit):
		return false
	# Determine slot
	var target_slot := slot_index
	if target_slot < 0:
		target_slot = unit.equipped_item_uuids.find("")
		if target_slot == -1:
			return false
	if target_slot >= unit.equipped_item_uuids.size():
		return false
	# If the item is currently equipped (same or different unit), clear the previous mapping
	# and remove bonuses first to avoid ghost copies and double-apply during intra-unit moves.
	var prev_parent_uuid := item.equipped_on_uuid
	if not prev_parent_uuid.is_empty():
		var prev_parent := get_instance_by_uuid(prev_parent_uuid)
		if is_instance_valid(prev_parent):
			if item.equipped_slot_index >= 0 and item.equipped_slot_index < prev_parent.equipped_item_uuids.size():
				prev_parent.equipped_item_uuids[item.equipped_slot_index] = ""
			# Remove previous bonus (even if same unit; will re-apply after placing)
			prev_parent.unequip_item_bonus(item)
			SignalBus.emit_signal("unit_inventory_changed", prev_parent.ball_uuid)
	# If item currently in a container, remove it from index
	var item_loc := item.get_location()
	if is_instance_valid(item_loc) and item_loc.container != &"equipped_item":
		var src_container := get_container(item_loc.container)
		if is_instance_valid(src_container) and src_container.get_uuid(item_loc.index) == item.ball_uuid:
			src_container.set_uuid(item_loc.index, "")
	# If target slot occupied, unequip existing item to ItemInventory (fallback: first empty)
	var existing_uuid := unit.equipped_item_uuids[target_slot]
	if not existing_uuid.is_empty():
		var existing_item := get_instance_by_uuid(existing_uuid)
		if is_instance_valid(existing_item):
			existing_item.equipped_on_uuid = ""
			existing_item.equipped_slot_index = -1
			# Place into ItemInventory (or any available appropriate container)
			var inv := get_container(RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY)
			if is_instance_valid(inv):
				var empty := inv.find_first_empty_slot()
				if empty != -1:
					inv.set_uuid(empty, existing_item.ball_uuid)
					existing_item.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY
					existing_item.location_slot_index = empty
				else:
					return false
		unit.equipped_item_uuids[target_slot] = item.ball_uuid
	item.equipped_on_uuid = unit.ball_uuid
	item.equipped_slot_index = target_slot
	item.location_container_tag = &"equipped_item"
	item.location_slot_index = target_slot
	# Apply item bonuses
	unit.equip_item_bonus(item)
	# Emit ordering: unit_inventory_changed first
	SignalBus.emit_signal("unit_inventory_changed", unit.ball_uuid)
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	if OS.is_debug_build():
		_validate_state_consistency()
	return true

# ------------------------------------------------------------------
# Golden Rule Validation
# ------------------------------------------------------------------

func _validate_state_consistency() -> bool:
	# Ensures no duplicate UUIDs across containers and truth matches index.
	var seen: Dictionary = {}
	# Validate container slots
	for cname in _containers.keys():
		var c: DataContainer = _containers[cname]
		if not is_instance_valid(c):
			continue
		var uuids := c.get_all_uuids()
		for i in range(uuids.size()):
			var u := uuids[i]
			if u.is_empty():
				continue
			if seen.has(u):
				push_error("Duplicate UUID %s found in containers" % u)
				return false
			seen[u] = true
			var inst: GachaBallInstance = run_instances.get(u)
			if not is_instance_valid(inst):
				push_error("Container references missing instance %s" % u)
				return false
			# Equipped items should not appear in container slots
			if inst.get_location().container == &"equipped_item":
				push_error("Equipped item %s appears in a container slot" % u)
				return false
	# Validate instances' truth against index
	for u in run_instances.keys():
		var inst: GachaBallInstance = run_instances[u]
		if not is_instance_valid(inst):
			continue
		var loc := inst.get_location()
		if not is_instance_valid(loc):
			continue
		if loc.container == &"equipped_item":
			var parent: GachaBallInstance = run_instances.get(loc.unit_uuid)
			if not is_instance_valid(parent):
				push_error("Equipped parent missing for %s" % u)
				return false
			if loc.index < 0 or loc.index >= parent.equipped_item_uuids.size():
				push_error("Equipped index out of range for %s" % u)
				return false
			if parent.equipped_item_uuids[loc.index] != u:
				push_error("Equipped mapping mismatch for %s" % u)
				return false
		else:
			var c2 := get_container(loc.container)
			if not is_instance_valid(c2):
				push_error("Missing container %s for %s" % [String(loc.container), u])
				return false
			if c2.get_uuid(loc.index) != u:
				push_error("Index/truth mismatch for %s" % u)
				return false
	return true

# ------------------------------------------------------------------
# Run lifecycle
# ------------------------------------------------------------------

func start_new_run() -> void:
	gold = 5 # Set starting gold
	day = 0
	run_instances.clear()
	_containers.clear()
	flashcard_progress.clear()
	active_deck_ids.clear()

func initialize_run(hero_def_id: StringName, deck_id: StringName) -> void:
	start_new_run()
	
	# Create hero instance from the selected hero definition
	var hero_def = Database.get_definition(hero_def_id)
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
		# Register hero via atomic API in the first lineup slot
		add_instance(self.hero_instance, RUN_CONTAINER_TAGS.PLAYER_LINEUP, 0)
	
	# Initialize flashcard progress for the selected deck
	var deck_card_ids = Database.flashcard_definitions.keys()
	for card_id in deck_card_ids:
		if not flashcard_progress.has(card_id):
			var progress = FlashcardProgress.new()
			flashcard_progress[card_id] = progress
	
	# Populate the initial active deck with the first 10 cards
	var all_card_ids = flashcard_progress.keys()
	for i in range(min(10, all_card_ids.size())):
		active_deck_ids.append(all_card_ids[i])
	
	# Create fresh empty inventory containers for tiers 1-3
	for t in [1, 2, 3]:
		var container_name: StringName = &"RunInventoryT%d" % t
		_containers[container_name] = GrowableGridContainer.new(16)

	# --- Add starter units/items to inventory ---
	var starters: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
		&"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
		&"unit_t2_c", &"unit_t2_c", &"item_t2_c", &"item_t2_c",
		&"unit_t3_d", &"unit_t3_d", &"item_t3_d", &"item_t3_d"
	]

	for id in starters:
		var def: GachaBallDefinition = Database.get_definition(id)
		if not def:
			continue
			
		var inst := GachaBallInstance.new()
		inst.initialize(def)
		
		var container_name: StringName = &"RunInventoryT%d" % def.tier
		# Use atomic add to register and place instance
		add_instance(inst, container_name, -1)
