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
## Returns null if the location is invalid or the instance cannot be found.
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null

	if is_in_battle:
		# TODO: Refactor with BattleManager helpers post-Phase 3
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		if not is_instance_valid(battle_manager): return null
		# This part still uses old container logic and will need to be refactored
		var container = battle_manager.get_container(loc.container)
		if not is_instance_valid(container): return null
		var uuid = container.get_uuid(loc.index)
		if uuid.is_empty(): return null
		return battle_manager.get_instance(uuid)
	else: # Run context
		if not is_instance_valid(run_state): return null
		
		var instances_in_container = run_state.get_instances_in_container(loc.container)
		for instance in instances_in_container:
			if instance.location_slot_index == loc.index:
				return instance

	return null

```