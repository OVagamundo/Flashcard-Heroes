# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.

var run_state: RunState
var is_inspecting_inventory: bool = false

func _ready() -> void:
    EventBus.start_run_requested.connect(_on_start_run_requested)
    EventBus.inspect_inventory_requested.connect(func(): is_inspecting_inventory = true)
    EventBus.close_modal_requested.connect(func(): is_inspecting_inventory = false)
    EventBus.inventory_action_requested.connect(_on_inventory_action_requested)

func _on_start_run_requested() -> void:
    print("GameManager: Start run requested. Creating new RunState.")
    run_state = RunState.new()
    run_state.start_new_run()
    EventBus.emit_signal("run_inventory_changed")
    EventBus.emit_signal("loadout_scene_requested")

func _on_inventory_action_requested(source_view: Control, target_view: Control) -> void:
    if not is_inspecting_inventory:
        return

    if not source_view or not target_view: return
    if not source_view.has_method("get_instance_data") or not target_view.has_method("get_instance_data"): return

    var source_data: GachaBallInstance = source_view.get_instance_data()
    var target_data: GachaBallInstance = target_view.get_instance_data()

    if not source_data or not target_data: return

    var merged_instance = MergeManager.attempt_merge(source_data, target_data, run_state.run_inventory)
    
    if merged_instance:
        print("Permanent merge successful. New unit: ", merged_instance.definition_id)
        # BUGFIX: A merge is a change to the inventory and must emit the signal.
        EventBus.emit_signal("run_inventory_changed")
    else:
        # Handle swap logic only if merge fails.
        _swap_instances_in_run_inventory(source_data, target_data)
        # The swap helper will emit the signal on success.

## Helper function to swap two instances within the tiered run_inventory.
func _swap_instances_in_run_inventory(inst_a: GachaBallInstance, inst_b: GachaBallInstance) -> void:
    var def_a = Database.units.get(inst_a.definition_id, Database.items.get(inst_a.definition_id))
    var def_b = Database.units.get(inst_b.definition_id, Database.items.get(inst_b.definition_id))

    if not def_a or not def_b: return

    # BUGFIX: Prevent swapping items of different categories or tiers in the run inventory.
    if def_a.category != def_b.category or def_a.tier != def_b.tier:
        InteractionManager.trigger_invalid_action_feedback(inst_a.get_meta("view_node"))
        InteractionManager.trigger_invalid_action_feedback(inst_b.get_meta("view_node"))
        print("GameManager: Invalid swap between different tiers or categories.")
        return

    var tier = def_a.tier
    if not run_state.run_inventory.has(tier): return

    var inventory_tier = run_state.run_inventory[tier]
    var idx_a = inventory_tier.find(inst_a)
    var idx_b = inventory_tier.find(inst_b)

    if idx_a == -1 or idx_b == -1: return

    inventory_tier[idx_a] = inst_b
    inventory_tier[idx_b] = inst_a
        
    print("Permanent swap successful.")
    EventBus.emit_signal("run_inventory_changed")
