<!-- Original: scripts/RunState.gd -->

```gdscript

class_name RunState
extends Resource

## Persistent state for a run using the single-source-of-truth data model.

@export var gold: int = 0
@export var day: int = 1
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
	if uuid.is_empty():
		return null
	
	var instance = get_instance_by_uuid(uuid)
	if is_instance_valid(instance):
		return instance.get_location()
	
	printerr("RunState: Could not find instance with UUID %s to get location." % uuid)
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
		var container_name: StringName = &"RunInventoryT%d" % t
		run_inventory_containers[container_name] = preload("res://scripts/GrowableGridContainer.gd").new(16, 4)

	# --- Create hero instance ---
	var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
	if hero_def:
		hero_instance = GachaBallInstance.new()
		hero_instance.initialize(hero_def)
		
		# --- Inlined logic from the deleted add_instance function ---
		var hero_container = get_container(RUN_CONTAINER_TAGS.PLAYER_LINEUP)
		var hero_slot = 0 # Hero always goes in the first slot
		
		# 1. Update the Index
		hero_container.set_uuid(hero_slot, hero_instance.ball_uuid)
		# 2. Update the Truth
		hero_instance.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_LINEUP
		hero_instance.location_slot_index = hero_slot
		# 3. Add to master dictionary
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
		
		var container_name: StringName = &"RunInventoryT%d" % def.tier
		
		# --- Inlined logic from the deleted add_instance function ---
		var container = get_container(container_name)
		if not is_instance_valid(container):
			printerr("RunState: Failed to find container for starter instance '%s'." % id)
			continue
		
		var target_slot = container.find_first_empty_slot()
		
		# 1. Update the Index
		container.set_uuid(target_slot, inst.ball_uuid)
		# 2. Update the Truth
		inst.location_container_tag = container_name
		inst.location_slot_index = target_slot
		# 3. Add to master dictionary
		run_instances[inst.ball_uuid] = inst

```