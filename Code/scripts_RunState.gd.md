<!-- Original: scripts/RunState.gd -->

```gdscript

class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

@export var gold: int = 0
@export var hero_instance: GachaBallInstance

# Master registry of all permanent instances in this run.
@export var run_instances: Dictionary = {} # key = uuid (String), value = GachaBallInstance

# Inventory containers indexed by name (e.g., "RunInventoryT1").
var run_inventory_containers: Dictionary = {} # key = StringName, value = DataContainer
# Additional containers (lineup, bench, etc.) cached here
var _other_containers: Dictionary = {}

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

func get_location_for_uuid(uuid: String) -> LocationIdentifier:
	if uuid.is_empty(): return null
	
	for container_name in run_inventory_containers:
		var container: DataContainer = run_inventory_containers[container_name]
		var all_uuids = container.get_all_uuids()
		var index = all_uuids.find(uuid)
		if index != -1:
			var loc = LocationIdentifier.new()
			loc.set_values(container_name, index)
			return loc

	for container_name in _other_containers:
		var container: DataContainer = _other_containers[container_name]
		var all_uuids = container.get_all_uuids()
		var index = all_uuids.find(uuid)
		if index != -1:
			var loc = LocationIdentifier.new()
			loc.set_values(container_name, index)
			return loc
	
	return null

func get_container(container_name: StringName) -> DataContainer:
	# Check inventory containers first
	if run_inventory_containers.has(container_name):
		return run_inventory_containers[container_name]

	# Check other containers
	if _other_containers.has(container_name):
		return _other_containers[container_name]
	
	# Handle standard containers with default sizes if they don't exist yet
	if container_name == RUN_CONTAINER_TAGS.PLAYER_LINEUP or container_name == RUN_CONTAINER_TAGS.PLAYER_BENCH:
		_other_containers[container_name] = preload("res://scripts/FixedArrayContainer.gd").new(6)
		return _other_containers[container_name]
	elif container_name == RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY:
		_other_containers[container_name] = preload("res://scripts/FixedArrayContainer.gd").new(3)
		return _other_containers[container_name]
	
	return null

# ------------------------------------------------------------------
# Mutation helpers
# ------------------------------------------------------------------

func add_instance(instance: GachaBallInstance) -> bool:
	if not is_instance_valid(instance): return false
	var def: GachaBallDefinition = instance.get_definition()
	if not is_instance_valid(def): 
		return false

	var container_tag = &"RunInventoryT%d" % def.tier
	var container = get_container(container_tag)
	if container == null: 
		printerr("RunState: Could not find container for tag: ", container_tag)
		return false

	var slot_index = container.find_first_empty_slot()
	if slot_index == -1: 
		printerr("RunState: No empty slot in container: ", container_tag)
		return false

	run_instances[instance.ball_uuid] = instance
	container.set_uuid(slot_index, instance.ball_uuid)
	return true

func remove_instance_by_uuid(uuid: String) -> void:
	run_instances.erase(uuid)

# ------------------------------------------------------------------
# Run lifecycle
# ------------------------------------------------------------------

func start_new_run() -> void:
	gold = 10
	run_instances.clear()
	run_inventory_containers.clear()
	_other_containers.clear()
	
	# Create fresh empty inventory containers for tiers 1-3
	for t in [1, 2, 3]:
		var container_name: StringName = StringName("RunInventoryT%d" % t)
		run_inventory_containers[container_name] = preload("res://scripts/GrowableGridContainer.gd").new(16, 4)
	
	# Create standard game containers with correct sizes
	# These will be created on-demand by get_container if needed, but we'll create them here explicitly
	_other_containers[RUN_CONTAINER_TAGS.HERO] = preload("res://scripts/FixedArrayContainer.gd").new(1)
	_other_containers[RUN_CONTAINER_TAGS.PLAYER_LINEUP] = preload("res://scripts/FixedArrayContainer.gd").new(6)
	_other_containers[RUN_CONTAINER_TAGS.PLAYER_BENCH] = preload("res://scripts/FixedArrayContainer.gd").new(3)
	_other_containers[RUN_CONTAINER_TAGS.PLAYER_ITEM_INVENTORY] = preload("res://scripts/FixedArrayContainer.gd").new(3)

	# --- Create hero instance ---
	var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
	if hero_def:
		hero_instance = GachaBallInstance.new()
		hero_instance.initialize(hero_def)
		
		# Add hero to lineup at position 0
		get_container(RUN_CONTAINER_TAGS.PLAYER_LINEUP).set_uuid(0, hero_instance.ball_uuid)
		run_instances[hero_instance.ball_uuid] = hero_instance
	else:
		printerr("RunState: CRITICAL – could not find hero definition in Database.")

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
			printerr("RunState: Missing definition '%s' while starting new run." % id)
			continue
			
		var inst := GachaBallInstance.new()
		inst.initialize(def)
		
		# Add to the appropriate container based on type
		if inst.has_tag(&"Item"):
			# Try to add to item inventory first
			var item_container = get_container(RUN_CONTAINER_TAGS.ITEM_INVENTORY)
			var slot = item_container.find_first_empty_slot()
			if slot != -1:
				item_container.set_uuid(slot, inst.ball_uuid)
				run_instances[inst.ball_uuid] = inst
				continue
				
		# For units or if item inventory is full, add to regular inventory
		if not add_instance(inst):
			printerr("RunState: Failed to add starter instance '%s'." % id)

	# New run initialized

```