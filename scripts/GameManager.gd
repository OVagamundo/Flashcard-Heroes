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
## Returns null if the location is invalid or the instance cannot be found.
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc):
		return null

	if is_in_battle:
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(battle_manager) and battle_manager.has_method("get_instance_by_location"):
			return battle_manager.get_instance_by_location(loc)
	else: # Run context
		if is_instance_valid(run_state) and run_state.has_method("get_instance_by_location"):
			return run_state.get_instance_by_location(loc)

	return null
