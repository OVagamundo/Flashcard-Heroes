<!-- Original: scripts/RunState.gd -->

```gdscript
# res://scripts/RunState.gd
class_name RunState
extends Resource

## The player's current run state, including all persistent progress.
## TDD-Compliant Version.

const GrowableGridContainer = preload("res://scripts/GrowableGridContainer.gd")

@export var gold: int = 0
@export var hero_instance: GachaBallInstance

# The master registry for all permanent instances in the run.
@export var run_instances: Dictionary = {} # Key: ball_uuid (String), Value: GachaBallInstance

# The registry for all persistent data containers.
@export var run_inventory_containers: Dictionary = {} # Key: container_name (StringName), Value: GrowableGridContainer


func _init():
	# Initialize containers as specified in TDD table 2.2
	if not run_inventory_containers.has(&"RunInventoryT1"):
		run_inventory_containers[&"RunInventoryT1"] = GrowableGridContainer.new(16)
	if not run_inventory_containers.has(&"RunInventoryT2"):
		run_inventory_containers[&"RunInventoryT2"] = GrowableGridContainer.new(16)
	if not run_inventory_containers.has(&"RunInventoryT3"):
		run_inventory_containers[&"RunInventoryT3"] = GrowableGridContainer.new(16)

## Finds the appropriate container for a given instance.
func get_container_for_instance(instance: GachaBallInstance) -> GrowableGridContainer:
	if not is_instance_valid(instance): return null
	var def = instance.get_definition()
	if not is_instance_valid(def): return null
	
	var container_name = &"RunInventoryT%d" % def.tier
	return run_inventory_containers.get(container_name)

## Retrieves a container by its name.
func get_container(container_name: StringName) -> GrowableGridContainer:
	return run_inventory_containers.get(container_name)

func get_instance_by_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc) or not run_inventory_containers.has(loc.container):
		return null
	var container = run_inventory_containers[loc.container]
	var uuid = container.get_uuid(loc.index)
	if uuid and run_instances.has(uuid):
		return run_instances[uuid]
	return null

## Adds a new instance to the run, placing it in the correct container.
func add_instance(instance: GachaBallInstance) -> bool:
	if not is_instance_valid(instance): return false
	
	var container = get_container_for_instance(instance)
	if not is_instance_valid(container):
		printerr("RunState: No valid container for instance tier.")
		return false
		
	var empty_idx = container.find_first_empty_slot()
	if empty_idx == -1:
		printerr("RunState: Container is full.")
		return false
	
	run_instances[instance.ball_uuid] = instance
	container.set_uuid(empty_idx, instance.ball_uuid)
	return true

## Removes an instance from the run, deleting it from the master list and its container.
func remove_instance(uuid: String):
	if uuid.is_empty() or not run_instances.has(uuid):
		return

	# 1. DO NOT Remove from the master instance registry.
	# An instance should only be removed when it's consumed in a merge or sold.
	# Moving it between containers (including to/from an equipment slot) does not delete it.
	# run_instances.erase(uuid)

	# 2. Find and remove from any container it might be in.
	for container in run_inventory_containers.values():
		# This requires GrowableGridContainer to have a find_uuid method.
		var index = container.find_uuid(uuid)
		if index != -1:
			container.set_uuid(index, "") # Clear the slot.
			return # Exit once found, as it can only be in one place.

func start_new_run() -> void:
	gold = 10
	run_instances.clear()
	for container in run_inventory_containers.values():
		container.clear()

	var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
	if hero_def:
		hero_instance = GachaBallInstance.new()
		hero_instance.initialize(hero_def)
		# The hero instance itself is not in the inventory, just held separately.
	else:
		printerr("RunState: CRITICAL - Could not find 'hero' definition in Database.")

	# Add starting items to the run inventory as per the restored original script.
	var items_to_add: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
		&"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
		&"unit_t2_c", &"unit_t2_c", &"item_t2_c", &"item_t2_c",
		&"unit_t3_d", &"unit_t3_d", &"item_t3_d", &"item_t3_d"
	]
	
	for item_id in items_to_add:
		var definition: GachaBallDefinition = Database.get_definition(item_id)
		if not is_instance_valid(definition):
			printerr("RunState: Could not find definition for starting item '%s'." % item_id)
			continue
		
		var instance = GachaBallInstance.new()
		instance.initialize(definition)
		
		if not add_instance(instance):
			printerr("RunState: Failed to add starting item '%s' to inventory." % item_id)
	
	print("RunState initialized with TDD-compliant data grids.")

## Finds an instance by its UUID from the master registry.
func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
	# The run_instances dictionary is the single source of truth. All instances,
	# including equipped ones, must reside here. This function is now a simple, direct lookup.
	return run_instances.get(uuid, null)

```