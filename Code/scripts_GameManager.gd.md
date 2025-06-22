<!-- Original: scripts/GameManager.gd -->

```gdscript
# res://scripts/GameManager.gd
extends Node

## Manages the persistent state of the current run by holding a RunState resource.

signal run_inventory_changed

## The single source of truth for the current run's state.
var run_state: RunState

## State flag to determine if inventory actions are permanent (in modal) or temporary (in battle).
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
    run_inventory_changed.emit()
    EventBus.emit_signal("loadout_scene_requested") # TDD says start_run -> loadout -> main

func _on_inventory_action_requested(source_view: Control, target_view: Control) -> void:
    if not is_inspecting_inventory:
        return # Do nothing if not in the permanent inventory inspection view.

    if not source_view or not target_view: return
    if not source_view.has_method("get_instance_data") or not target_view.has_method("get_instance_data"): return

    var source_data: GachaBallInstance = source_view.get_instance_data()
    var target_data: GachaBallInstance = target_view.get_instance_data()

    if not source_data or not target_data: return

    # Delegate the merge logic to the MergeManager.
    var merged_instance = MergeManager.attempt_merge(source_data, target_data, run_state.run_inventory)
    
    if merged_instance:
        # The merge was successful. The inventory modal will need to be refreshed.
        print("Permanent merge successful. New unit: ", merged_instance.definition_id)
    else:
        # Handle swap logic if merge fails.
        _swap_instances_in_run_inventory(source_data, target_data)

    run_inventory_changed.emit()

## Helper function to swap two instances within the tiered run_inventory.
func _swap_instances_in_run_inventory(inst_a: GachaBallInstance, inst_b: GachaBallInstance) -> void:
    var def_a = Database.units.get(inst_a.definition_id, Database.items.get(inst_a.definition_id))
    var def_b = Database.units.get(inst_b.definition_id, Database.items.get(inst_b.definition_id))

    if not def_a or not def_b:
        printerr("GameManager: Cannot find definition for swap.")
        return

    var tier_a = def_a.tier
    var tier_b = def_b.tier

    if not run_state.run_inventory.has(tier_a) or not run_state.run_inventory.has(tier_b):
        printerr("GameManager: Invalid tier for swap.")
        return

    var idx_a = run_state.run_inventory[tier_a].find(inst_a)
    var idx_b = run_state.run_inventory[tier_b].find(inst_b)

    if idx_a == -1 or idx_b == -1:
        printerr("GameManager: Instance not found for swap.")
        return

    # If instances are in the same tier, perform a simple swap.
    if tier_a == tier_b:
        run_state.run_inventory[tier_a][idx_a] = inst_b
        run_state.run_inventory[tier_a][idx_b] = inst_a
    else: # If in different tiers, move them.
        run_state.run_inventory[tier_a].remove_at(idx_a)
        run_state.run_inventory[tier_b].remove_at(idx_b)
        run_state.run_inventory[tier_a].append(inst_b)
        run_state.run_inventory[tier_b].append(inst_a)
        
    print("Permanent swap successful.")

```