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

func _on_start_run_requested() -> void:
    run_state = RunState.new()
    run_state.start_new_run()
    EventBus.emit_signal("run_inventory_changed")
    EventBus.emit_signal("loadout_scene_requested")
