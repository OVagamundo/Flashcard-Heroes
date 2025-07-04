<!-- Original: scripts/InventoryManager.gd -->

```gdscript
extends Node

# --- State ---
# Stores the context for a pending choice (Merge vs. Swap).
var _pending_action: Dictionary = {}

# --- Engine Callbacks ---
func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

# TDD Action Decision Tree Implementation
func _on_inventory_action_requested(source_view: Control, target_view: Control):
	InteractionManager.clear_selection()

	if source_view == target_view:
		InteractionManager.select_view(source_view)
		return

	var source_instance: GachaBallInstance = source_view.get_instance_data()
	if not is_instance_valid(source_instance):
		trigger_invalid_action_feedback(source_view)
		return

	# Case 1: Target is an empty slot. Intent is MOVE.
	if target_view is SlotView:
		_handle_move(source_view, target_view)
		return

	# From here, target is a GachaBallView.
	var target_instance: GachaBallInstance = target_view.get_instance_data()
	if not is_instance_valid(target_instance):
		trigger_invalid_action_feedback(source_view)
		return

	var source_def = Database.units.get(source_instance.definition_id, Database.items.get(source_instance.definition_id))
	var target_def = Database.units.get(target_instance.definition_id, Database.items.get(target_instance.definition_id))

	# Categories must match for Merge or Swap.
	if source_def.category == target_def.category:
		# Case 2: A valid recipe exists. Intent is MERGE (pending choice).
		var recipe = MergeManager.find_recipe(source_instance.definition_id, target_instance.definition_id)
		if recipe:
			_pending_action = {"source_view": source_view, "target_view": target_view}
			WindowManager.open_dialog_window(&"ChoiceModal")
			return
		else:
			# Case 4 (Fallback): No recipe. Intent is SWAP.
			_handle_swap(source_view, target_view)
			return
	
	# Categories are different.
	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		# Case 3: Item on Unit. Intent is EQUIP.
		_handle_equip(source_view, target_view)
		return

	# All other combinations are invalid.
	trigger_invalid_action_feedback(source_view)


func _on_choice_made(choice: StringName):
	var source_view = _pending_action.get("source_view")
	var target_view = _pending_action.get("target_view")
	
	if not is_instance_valid(source_view) or not is_instance_valid(target_view):
		_pending_action.clear()
		return
		
	if choice == &"MERGE": 
		_handle_merge(source_view, target_view)
	elif choice == &"SWAP": 
		_handle_swap(source_view, target_view)
		
	_pending_action.clear()

func _handle_move(source_view: Control, target_view: Control):
	var source_instance = source_view.get_instance_data()
	# TDD Rule: The Hero is locked to the lineup and cannot be moved.
	if source_instance.definition_id == &"hero":
		trigger_invalid_action_feedback(source_view)
		return

	var source_loc = source_view.get_meta("location_identifier", {})
	var target_loc = target_view.get_meta("location_identifier", {})

	if source_loc.is_empty() or target_loc.is_empty():
		trigger_invalid_action_feedback(source_view)
		return

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		bm.set_slot_data(source_loc.container, source_loc.index, null)
		bm.set_slot_data(target_loc.container, target_loc.index, source_instance)
		EventBus.emit_signal("battle_inventory_changed")
	else:
		if source_loc.tier != target_loc.tier:
			trigger_invalid_action_feedback(source_view)
			return
		
		var tier_grid = GameManager.run_state.run_inventory[source_loc.tier]
		tier_grid[target_loc.index] = source_instance
		tier_grid[source_loc.index] = null
		EventBus.emit_signal("run_inventory_changed")

func _handle_swap(source_view: Control, target_view: Control):
	var source_instance = source_view.get_instance_data()
	var target_instance = target_view.get_instance_data()
	var source_loc = source_view.get_meta("location_identifier", {})
	var target_loc = target_view.get_meta("location_identifier", {})

	if source_loc.is_empty() or target_loc.is_empty():
		trigger_invalid_action_feedback(source_view)
		return

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if source_instance.definition_id == &"hero" and target_loc.container != "PlayerLineup":
			trigger_invalid_action_feedback(source_view); return
		if target_instance.definition_id == &"hero" and source_loc.container != "PlayerLineup":
			trigger_invalid_action_feedback(source_view); return
		
		bm.set_slot_data(source_loc.container, source_loc.index, target_instance)
		bm.set_slot_data(target_loc.container, target_loc.index, source_instance)
		EventBus.emit_signal("battle_inventory_changed")
	else:
		if source_loc.tier != target_loc.tier:
			trigger_invalid_action_feedback(source_view); return
		
		var tier_grid = GameManager.run_state.run_inventory[source_loc.tier]
		tier_grid[source_loc.index] = target_instance
		tier_grid[target_loc.index] = source_instance
		EventBus.emit_signal("run_inventory_changed")

func _handle_equip(item_view: Control, unit_view: Control):
	var item_instance = item_view.get_instance_data()
	var unit_instance = unit_view.get_instance_data()

	# TDD Rule: Equip is only valid in battle.
	if not GameManager.is_in_battle:
		trigger_invalid_action_feedback(item_view); return

	# TDD Rule: Both item and unit must be on the Battle Board.
	# We verify this by checking if their locations came from a battle context.
	var item_loc = item_view.get_meta("location_identifier", {})
	var unit_loc = unit_view.get_meta("location_identifier", {})
	if item_loc.get("container", "").is_empty() or unit_loc.get("container", "").is_empty():
		trigger_invalid_action_feedback(item_view); return

	# TDD Rule: Unit must have an empty item slot.
	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1:
		trigger_invalid_action_feedback(item_view); return

	# Action is valid, proceed.
	var bm = get_tree().get_first_node_in_group("battle_manager")
	bm.set_slot_data(item_loc.container, item_loc.index, null)
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid
	
	EventBus.emit_signal("battle_inventory_changed")

func _handle_merge(source_view: Control, target_view: Control):
	var source_instance = source_view.get_instance_data()
	var target_instance = target_view.get_instance_data()
	
	var inventory_context = {}
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		inventory_context = {
			"is_battle": true,
			"battle_inventory": bm.get_battle_inventory(),
			"lineup_data": bm.lineup_data, "bench_data": bm.bench_data, "item_data": bm.item_data
		}
	else:
		inventory_context = {
			"is_battle": false,
			"run_inventory": GameManager.run_state.run_inventory
		}

	var merge_result = MergeManager.calculate_merge_result(source_instance, target_instance, inventory_context)
	
	if merge_result:
		var merged_instance = merge_result.merged_instance
		var parents_to_remove = merge_result.parents_to_remove

		_remove_instances_from_inventories(parents_to_remove)
		_place_merged_instance(merged_instance, source_view, target_view)
		
		var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_inventory_changed"
		EventBus.emit_signal(signal_name)
	else:
		trigger_invalid_action_feedback(source_view)
		printerr("InventoryManager: Merge calculation failed.")

func _remove_instances_from_inventories(instances: Array[GachaBallInstance]):
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		for instance in instances:
			# Remove from battle board
			var loc = _find_battle_location(instance, bm)
			if not loc.is_empty():
				bm.set_slot_data(loc.container, loc.index, null)
			# Remove from master battle inventory
			var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
			if def and bm.get_battle_inventory().has(def.tier):
				var grid = bm.get_battle_inventory()[def.tier]
				var idx = grid.find(instance)
				if idx != -1: grid[idx] = null
	else:
		var run_inv = GameManager.run_state.run_inventory
		for instance in instances:
			var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
			if def and run_inv.has(def.tier):
				var idx = run_inv[def.tier].find(instance)
				if idx != -1:
					run_inv[def.tier][idx] = null

# TDD Merge Destination Logic Implementation
func _place_merged_instance(instance: GachaBallInstance, source_view: Control, target_view: Control):
	var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
	if not def: return
	
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var battle_inv_grid = bm.get_battle_inventory()[def.tier]
		var empty_idx = battle_inv_grid.find(null)
		if empty_idx != -1:
			battle_inv_grid[empty_idx] = instance
		else:
			# This case should be rare, but handles grid growth if needed.
			printerr("InventoryManager: No space in battle inventory for merged item. It will be lost.")
	else: # Run Inventory
		var run_inv_grid = GameManager.run_state.run_inventory[def.tier]
		var empty_idx = run_inv_grid.find(null)
		if empty_idx != -1:
			run_inv_grid[empty_idx] = instance
		else:
			printerr("InventoryManager: No space in run inventory for merged item. It will be lost.")


func _find_battle_location(instance: GachaBallInstance, bm: BattleManager) -> Dictionary:
	var idx = bm.lineup_data.find(instance); if idx != -1: return {"container": "PlayerLineup", "index": idx}
	idx = bm.bench_data.find(instance); if idx != -1: return {"container": "PlayerBench", "index": idx}
	idx = bm.item_data.find(instance); if idx != -1: return {"container": "ItemInventory", "index": idx}
	return {}

# _get_battle_view_location has been removed as it is no longer needed.
# View metadata is now the source of truth for location.

func trigger_invalid_action_feedback(view: Control):
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
```