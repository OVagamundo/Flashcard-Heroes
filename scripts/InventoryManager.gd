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
		# This is a cancelled action. End the drag unsuccessfully to restore the view.
		InteractionManager.end_drag(false)
		return
		
	var source_instance: GachaBallInstance = source_view.get_instance_data()
	if not is_instance_valid(source_instance):
		_handle_invalid_action(source_view)
		return

	# --- TDD UNIFIED ACTION DECISION TREE ---

	# 1. Is the target an empty slot? Intent is MOVE.
	if target_view is SlotView:
		_handle_move(source_view, target_view)
		return

	# From here on, the target is another GachaBall.
	var target_instance: GachaBallInstance = target_view.get_instance_data()
	if not is_instance_valid(target_instance):
		_handle_invalid_action(source_view)
		return
	
	# Create symmetrical variables regardless of drag direction.
	var view_a = source_view
	var view_b = target_view
	var def_a = source_instance.get_definition()
	var def_b = target_instance.get_definition()

	# 2. Check for EQUIP intent (symmetrically).
	# Is one view a UNIT and the other an ITEM?
	if (def_a.category == &"UNIT" and def_b.category == &"ITEM") or \
	   (def_a.category == &"ITEM" and def_b.category == &"UNIT"):
		
		# Identify which is which.
		var unit_view = view_a if def_a.category == &"UNIT" else view_b
		var item_view = view_b if def_a.category == &"UNIT" else view_a
		
		# The _handle_equip function contains the logic to check if they are on the
		# battle board. If they are not, it will correctly fail and become an
		# invalid action. If they are, it will equip. This correctly separates
		# the EQUIP intent from the SWAP intent.
		_handle_equip(item_view, unit_view)
		return

	# 3. If not an Equip action, check for MERGE intent.
	var recipe = MergeManager.find_recipe(def_a.id, def_b.id)
	if recipe:
		_pending_action = {"source_view": view_a, "target_view": view_b}
		WindowManager.open_dialog_window(&"ChoiceModal")
		return

	# 4. Fallback: If it's not Move, Equip, or Merge, the intent is SWAP.
	_handle_swap(view_a, view_b)

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
	var source_loc = source_view.get_meta("location_identifier", {})
	var target_loc = target_view.get_meta("location_identifier", {})
	var source_instance = _get_instance_at_location(source_loc)

	# TDD Compatibility Check
	if not _is_valid_placement(source_instance, target_loc):
		_handle_invalid_action(source_view)
		return

	# Action is valid, perform it using generic helpers
	_set_instance_at_location(target_loc, source_instance)
	_set_instance_at_location(source_loc, null)

	InteractionManager.end_drag(true) # Action was valid, end the drag successfully.
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_inventory_changed"
	EventBus.emit_signal(signal_name)

func _handle_swap(source_view: Control, target_view: Control):
	var source_loc = source_view.get_meta("location_identifier", {})
	var target_loc = target_view.get_meta("location_identifier", {})
	var source_instance = source_view.get_instance_data()
	var target_instance = _get_instance_at_location(target_loc)

	# TDD Compatibility Checks
	# We add metadata here so the compatibility checker knows the original tiers of both items.
	if is_instance_valid(source_instance):
		source_instance.set_meta("source_tier", _get_instance_at_location(source_loc).get_definition().tier)
	if is_instance_valid(target_instance):
		target_instance.set_meta("source_tier", _get_instance_at_location(target_loc).get_definition().tier)
	if not _is_valid_placement(source_instance, target_loc) or not _is_valid_placement(target_instance, source_loc):
		_handle_invalid_action(source_view)
		return

	# Action is valid
	_set_instance_at_location(target_loc, source_instance)
	_set_instance_at_location(source_loc, target_instance)

	InteractionManager.end_drag(true) # Action was valid, end the drag successfully.
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_inventory_changed"
	EventBus.emit_signal(signal_name)

func _handle_equip(item_view: Control, unit_view: Control):
	var item_instance = item_view.get_instance_data()
	var unit_instance = unit_view.get_instance_data()
	var item_loc = item_view.get_meta("location_identifier", {})
	var unit_loc = unit_view.get_meta("location_identifier", {})

	# TDD Rule: Unit must have an empty item slot.
	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	
	var is_valid = GameManager.is_in_battle and \
					_is_on_battle_board(item_loc) and \
					_is_on_battle_board(unit_loc) and \
					empty_slot_idx != -1

	if not is_valid:
		# Per TDD, if an equip is not possible, it should be a swap instead.
		_handle_swap(item_view, unit_view)
		return

	# Action is valid, proceed.
	_set_instance_at_location(item_loc, null)
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	# Place the item back into the master battle inventory.
	var bm = get_tree().get_first_node_in_group("battle_manager")
	var def = item_instance.get_definition()
	if is_instance_valid(bm) and is_instance_valid(def):
		var inventory_grid = bm.get_battle_inventory().get(def.tier)
		if inventory_grid is Array:
			var empty_inv_idx = inventory_grid.find(null)
			if empty_inv_idx != -1:
				inventory_grid[empty_inv_idx] = item_instance
			else:
				printerr("InventoryManager: CRITICAL - No space in battle inventory for equipped item. Item may be lost.")

	InteractionManager.end_drag(true) # Action was valid, end the drag successfully.
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
		
		InteractionManager.end_drag(true) # Action was valid, end the drag successfully.
		var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_inventory_changed"
		EventBus.emit_signal(signal_name)
	else:
		_handle_invalid_action(source_view)
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
			# CRITICAL FIX: Also remove from the draw pools.
			if def and bm._draw_pools.has(def.tier):
				var pool = bm._draw_pools[def.tier]
				if pool.has(instance):
					pool.erase(instance)
	else:
		var run_inv = GameManager.run_state.run_inventory
		for instance in instances:
			var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
			if def and run_inv.has(def.tier):
				var idx = run_inv[def.tier].find(instance)
				if idx != -1:
					run_inv[def.tier][idx] = null

# TDD Merge Destination Logic Implementation
# The result of a merge is always placed in the first available slot of the
# corresponding inventory grid (Run or Battle) for its tier. This ensures
# consistent and predictable behavior, removing special cases for the battle bench.
# TDD Merge Destination Logic Implementation
# The destination of a merged item depends on the context of the action.
func _place_merged_instance(merged_instance: GachaBallInstance, _source_view: Control, target_view: Control):
	var def = merged_instance.get_definition()
	if not def: return

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var target_loc = target_view.get_meta("location_identifier", {})

		# Check if the merge happened on the battle board itself.
		if _is_on_battle_board(target_loc):
			# If so, the new instance takes the place of the target view.
			# This ensures merges on the bench/lineup feel immediate and correct.
			_set_instance_at_location(target_loc, merged_instance)
			return
		else:
			# If the merge happened in the inventory modal, place the result
			# in the main battle inventory grid.
			var battle_inv_grid = bm.get_battle_inventory().get(def.tier)
			if battle_inv_grid is Array:
				var empty_idx = battle_inv_grid.find(null)
				if empty_idx != -1:
					battle_inv_grid[empty_idx] = merged_instance
				else:
					printerr("InventoryManager: No space in battle inventory for merged item. It will be lost.")
			else:
				printerr("InventoryManager: Invalid tier %d for merged item in battle." % def.tier)
	else: # Run Inventory (This logic remains the same)
		var run_inv_grid = GameManager.run_state.run_inventory.get(def.tier)
		if run_inv_grid is Array:
			var empty_idx = run_inv_grid.find(null)
			if empty_idx != -1:
				run_inv_grid[empty_idx] = merged_instance
			else:
				printerr("InventoryManager: No space in run inventory for merged item. It will be lost.")
		else:
			printerr("InventoryManager: Invalid tier %d for merged item in run." % def.tier)


func _find_battle_location(instance: GachaBallInstance, bm: BattleManager) -> Dictionary:
	var idx = bm.lineup_data.find(instance); if idx != -1: return {"container": "PlayerLineup", "index": idx}
	idx = bm.bench_data.find(instance); if idx != -1: return {"container": "PlayerBench", "index": idx}
	idx = bm.item_data.find(instance); if idx != -1: return {"container": "ItemInventory", "index": idx}
	return {}

# --- NEW: Centralized Data Access Helpers ---

func _get_instance_at_location(loc: Dictionary) -> GachaBallInstance:
	var container = loc.get("container", "")
	var index = loc.get("index", -1)
	var tier = loc.get("tier", -1)

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if container.begins_with("Tier"): # Battle Inventory Modal
			return bm.get_battle_inventory()[tier][index]
		else: # Battle Board (Lineup, Bench, Items)
			return bm.get_data_array_and_instance(container, index).instance
	else: # Run Inventory
		return GameManager.run_state.run_inventory[tier][index]

func _set_instance_at_location(loc: Dictionary, instance: GachaBallInstance):
	var container = loc.get("container", "")
	var index = loc.get("index", -1)
	var tier = loc.get("tier", -1)
	
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if container.begins_with("Tier"): # Battle Inventory Modal Grid
			bm.get_battle_inventory()[tier][index] = instance
		else: # Battle Board
			bm.set_slot_data(container, index, instance)
	else: # Run Inventory
		GameManager.run_state.run_inventory[tier][index] = instance

# --- NEW: TDD Compatibility Rule Helpers ---

func _is_on_battle_board(loc: Dictionary) -> bool:
	var container = loc.get("container", "")
	return container in ["PlayerLineup", "PlayerBench", "ItemInventory"]

func _is_valid_placement(instance: GachaBallInstance, target_loc: Dictionary) -> bool:
	if not is_instance_valid(instance): return true # Moving a null is always valid

	var def = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
	var target_container = target_loc.get("container", "")

	# Rule: Hero can only be in the lineup or swapped with another unit in the lineup.
	if def.id == &"hero" and target_container != "PlayerLineup":
		return false

	# Rule: Inventory Grids (Run or Battle) must have matching tiers. Battle Board slots don't have tiers.
	if target_container.begins_with("Tier"):
		# For swaps, we need to check both items.
		var source_tier = instance.get_meta("source_tier", def.tier) # Get tier from meta if it's a swap
		if source_tier != target_loc.get("tier", -1):
			return false
	
	# Rule: Battle Board container type restrictions (applies to move and swap)
	if not target_container.is_empty() and not target_container.begins_with("Tier"):
		if def.category == &"UNIT" and target_container == "ItemInventory":
			return false
		if def.category == &"ITEM" and target_container in ["PlayerLineup", "PlayerBench"]:
			return false

	return true

# --- NEW: Robust Invalid Action Handler ---

func _handle_invalid_action(source_view: Control):
	"""
	The definitive handler for any failed inventory action.
	It provides user feedback AND restores the UI state.
	"""
	if not is_instance_valid(source_view):
		# If the source view is gone, just cancel any lingering drag.
		if InteractionManager.is_drag_active():
			InteractionManager.cancel_active_drag()
		return

	# 1. Provide visual feedback to the user.
	EventBus.emit_signal("invalid_action_triggered", source_view)
	
	# 2. CRITICAL: If a drag was in progress, end it unsuccessfully to restore the UI.
	# This fixes all "disappearing item" bugs.
	InteractionManager.end_drag(false)

	# 3. Clear any pending selections.
	InteractionManager.clear_selection()
