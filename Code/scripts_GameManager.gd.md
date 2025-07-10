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

func _on_start_run_requested() -> void:
    run_state = RunState.new()
    run_state.start_new_run()
    EventBus.emit_signal("run_state_changed") # Use the new signal
    EventBus.emit_signal("loadout_scene_requested")

func _on_return_to_title() -> void:
    # Clear the run state when returning to the title screen
    run_state = null

## Retrieves a GachaBallInstance from any location, whether in battle or not.
## Returns null if the location is invalid or the instance cannot be found.
func get_instance_from_location(loc: LocationIdentifier) -> GachaBallInstance:
    if not is_instance_valid(loc): return null

    var data_owner: Object
    var all_instances: Dictionary

    if is_in_battle:
        data_owner = get_tree().get_first_node_in_group("battle_manager")
        if not is_instance_valid(data_owner): return null
        all_instances = data_owner.get_all_instances()
    else:
        data_owner = run_state
        if not is_instance_valid(data_owner): return null
        all_instances = data_owner.run_instances

    if not data_owner.has_method("get_container"): return null
    
    var container = data_owner.get_container(loc.container)
    if not is_instance_valid(container): return null
    
    var uuid = container.get_uuid(loc.index)
    if uuid.is_empty(): return null
    
    return all_instances.get(uuid)

```