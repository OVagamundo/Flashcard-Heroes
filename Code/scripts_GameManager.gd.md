<!-- Original: scripts/GameManager.gd -->

```gdscript
# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.
## Also acts as the single source of truth for the game's battle state.

var run_state: RunState
var is_in_battle: bool = false # The global authority on whether a battle is active.

func _ready() -> void:
	# Connect to signals to manage the run and battle state.
	EventBus.start_run_requested.connect(_on_start_run_requested)
	EventBus.battle_state_changed.connect(func(in_battle): is_in_battle = in_battle)
	EventBus.title_scene_requested.connect(_on_return_to_title)
	EventBus.new_game_requested.connect(_on_new_game_requested)

func _on_start_run_requested() -> void:
	run_state = RunState.new()
	run_state.start_new_run()
	EventBus.emit_signal("run_data_changed") # Use the new signal
	EventBus.emit_signal("loadout_scene_requested")

func _on_new_game_requested() -> void:
	_on_start_run_requested()

func _on_return_to_title() -> void:
	# Clear the run state when returning to the title screen
	run_state = null

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## This is the central, authoritative function for resolving a LocationIdentifier to an instance.
## Returns null if the location is invalid or the instance cannot be found.
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	# Step 1: Determine the current context (battle or run) to get the right data source.
	var data_owner: Object
	if is_in_battle:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	else:
		data_owner = run_state

	if not is_instance_valid(data_owner):
		printerr("GameManager: Could not determine a valid data owner.")
		return null

	# Step 2: Apply contextual understanding based on the location type.
	# This is the core fix that adheres to the TDD.
	
	# Case A: The location is for an equipped item (a conceptual location).
	if loc.container == &"equipped_item":
		if loc.unit_uuid.is_empty():
			printerr("GameManager: LocationIdentifier for equipped_item is missing a unit_uuid.")
			return null
		
		var all_instances_db = data_owner.get_all_instances()
		var parent_unit: GachaBallInstance = all_instances_db.get(loc.unit_uuid)
		
		if not is_instance_valid(parent_unit):
			printerr("GameManager: Could not find parent unit with UUID: ", loc.unit_uuid)
			return null
		
		var item_uuid = parent_unit.get_equipped_item_uuid(loc.index)
		if item_uuid.is_empty():
			return null # The slot is empty.
		
		return all_instances_db.get(item_uuid)

	# Case B: The location is a standard physical container.
	# Delegate the simple lookup to the appropriate data owner.
	else:
		if data_owner.has_method("get_instance_by_location"):
			return data_owner.get_instance_by_location(loc)

	# Fallback if no valid case is met.
	printerr("GameManager: Unhandled location type in get_instance_from_location for container: ", loc.container)
	return null

```