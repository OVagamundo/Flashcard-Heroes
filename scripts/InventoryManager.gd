extends Node

# --- State ---
# Stores the context for a pending choice (Merge vs. Swap).


# --- Engine Callbacks ---
func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

# TDD Action Decision Tree Implementation
func _on_inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	InteractionManager.clear_selection()

	if source_loc.is_equal(target_loc):
		InteractionManager.end_drag(false)
		return

	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	if not is_instance_valid(source_instance):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		InteractionManager.end_drag(false)
		return

	# --- MOVE (target is an empty slot) -------------------------------------------
	if not is_instance_valid(target_instance):
		if _is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			InteractionManager.end_drag(true) # successful move
		else:
			_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
			InteractionManager.end_drag(false)
		return

	# --- All actions below this line assume target_instance is VALID. ---

	# --- EQUIP ----------------------------------------------------------------------
	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	var is_equip_forward = source_def.category == &"ITEM" and target_def.category == &"UNIT" and \
						   source_loc.container == &"ItemInventory" and target_loc.container in [&"PlayerLineup", &"PlayerBench"]
	var is_equip_reverse = source_def.category == &"UNIT" and target_def.category == &"ITEM" and \
						   source_loc.container in [&"PlayerLineup", &"PlayerBench"] and target_loc.container == &"ItemInventory"

	if is_equip_forward or is_equip_reverse:
		var item_loc = source_loc if is_equip_forward else target_loc
		var unit_loc = target_loc if is_equip_forward else source_loc
		_equip_item(item_loc, unit_loc)
		InteractionManager.end_drag(true)
		return

	# --- MERGE / SWAP (target is an occupied slot) --------------------------------
	var all_instances_db: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		all_instances_db = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		all_instances_db = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)

	if is_instance_valid(recipe):
		var context = { "source_location": source_loc, "target_location": target_loc }
		WindowManager.open_dialog_window(&"ChoiceWindow", context)
		InteractionManager.end_drag(false)
		return

	# If no recipe, default to SWAP. A swap is valid if both items are of the same tier
	# and can legally move to the other's location. The definitions are already in scope.
	if source_def.tier == target_def.tier and \
	   _is_valid_placement(source_instance, target_loc) and \
	   _is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
	else:
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
	InteractionManager.end_drag(false)


func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		printerr("InventoryManager: Received choice_made with invalid locations.")
		return
		
	match choice:
		&"MERGE":
			_merge(source_loc, target_loc)
		&"SWAP":
			_swap(source_loc, target_loc)

# --- Action Handlers ---
# These functions bridge the gap between UI views and data-layer logic.

func _handle_move(source_view: Control, target_view: Control):
	var source_loc = source_view.get_meta("location_identifier")
	var target_loc = target_view.get_meta("location_identifier")
	var source_instance = _get_instance_at_location(source_loc)

	if not _is_valid_placement(source_instance, target_loc):
		_handle_invalid_action(source_view)
		return

	_move(source_loc, target_loc)

func _handle_equip(item_view: Control, unit_view: Control):
	# TDD RULE: Equipping is a battle-only action.
	if not GameManager.is_in_battle:
		_handle_invalid_action(item_view)
		return

	var item_loc = item_view.get_meta("location_identifier")
	var unit_loc = unit_view.get_meta("location_identifier")

	# TDD: Equip is only valid on the player's battle board.
	if not (item_loc.container == "ItemInventory" and unit_loc.container in ["PlayerLineup", "PlayerBench"]):
		_handle_invalid_action(item_view)
		return

	_equip_item(item_loc, unit_loc)

func _handle_merge(source_view: Control, target_view: Control):
	var source_loc = source_view.get_meta("location_identifier")
	var target_loc = target_view.get_meta("location_identifier")
	_merge(source_loc, target_loc)

# --- Core Logic Functions ---
# These functions perform the data modifications.

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var instance = _get_instance_at_location(source_loc)
	_set_instance_at_location(source_loc, null)
	_set_instance_at_location(target_loc, instance)
	_emit_data_changed_signal()

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	# The caller has already validated that the swap is legal. Just perform the data change.
	_set_instance_at_location(source_loc, target_instance)
	_set_instance_at_location(target_loc, source_instance)
	_emit_data_changed_signal()

func _equip_item(item_loc: LocationIdentifier, unit_loc: LocationIdentifier):
	var item_instance = _get_instance_at_location(item_loc)
	var unit_instance = _get_instance_at_location(unit_loc)

	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance):
		return

	# TDD: Find first empty equipment slot on the unit
	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1:
		# No empty slots, this should ideally be handled by the UI preventing the action
		# but as a fallback, we do nothing.
		return

	# First, request the inspection to avoid the view being freed prematurely.
	var unit_view = WindowManager.find_view_by_location(unit_loc)
	if is_instance_valid(unit_view):
		EventBus.emit_signal("inspection_requested", unit_view)

	# Now, modify the data.
	# The item is NOT removed from the master run_instances list, only from its visual container.
	_set_instance_at_location(item_loc, null)
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	# Finally, signal that data has changed so the UI can react.
	_emit_data_changed_signal()
	InteractionManager.end_drag(true)

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	# Get the correct master instance database based on context.
	var all_instances_db: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		all_instances_db = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		all_instances_db = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

	# Pass the correct data to the MergeManager.
	var merge_result = MergeManager.calculate_merge_result(source_instance, target_instance, source_loc, target_loc, all_instances_db)

	if merge_result.is_empty():
		# TDD: If there's no valid merge recipe, the behavior depends on context.
		# For storage grids (Run or Battle), a failed merge should attempt a swap.
		var is_in_storage_grid = source_loc.container.begins_with("RunInventoryT") or \
								 source_loc.container.begins_with("BattleInventoryT")

		if is_in_storage_grid:
			_swap(source_loc, target_loc)
		else:
			# On the battle board, a failed merge is just an invalid action.
			_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	var new_instance: GachaBallInstance = merge_result.merged_instance
	var parents_to_remove: Array[GachaBallInstance] = merge_result.parents_to_remove

	# --- CONTEXT-AWARE MERGE LOGIC ---
	# 3. Add the new instance to the master database.
	all_instances_db[new_instance.ball_uuid] = new_instance

	# 4. Place the new instance and clear the old slots based on context.
	if GameManager.is_in_battle:
		var both_in_battle_inventory = source_loc.container.begins_with("BattleInventoryT") and target_loc.container.begins_with("BattleInventoryT")
		# Always clear the source/target slots first.
		_set_instance_at_location(source_loc, null)
		_set_instance_at_location(target_loc, null)
		if both_in_battle_inventory:
			var new_loc = _find_empty_slot_for_instance_battle(new_instance)
			if is_instance_valid(new_loc):
				_set_instance_at_location(new_loc, new_instance)
		else:
			# Merges coming from the battle board still replace the target.
			_set_instance_at_location(target_loc, new_instance)
	else:
		# In the run inventory, find a new home for the merged unit.
		_set_instance_at_location(source_loc, null)
		_set_instance_at_location(target_loc, null)
		var new_loc = _find_empty_slot_for_instance(new_instance)
		if is_instance_valid(new_loc):
			_set_instance_at_location(new_loc, new_instance)

	# 5. Remove the original ingredient instances from the master database to prevent leaks.
	for ingredient in parents_to_remove:
		if all_instances_db.has(ingredient.ball_uuid):
			all_instances_db.erase(ingredient.ball_uuid)

	# 4. Notify the system that data has changed so the UI can update.
	_emit_data_changed_signal()

func _add_item_to_inventory(instance: GachaBallInstance):
	if not is_instance_valid(instance): return

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var container = bm.get_container("ItemInventory")
		var index = container.find_first_empty_slot()
		if index != -1:
			container.set_instance_at(index, instance.ball_uuid)
		else:
			printerr("InventoryManager: No space in battle item inventory. It will be lost.")
	else:
		var loc = _find_empty_slot_for_item(instance)
		if is_instance_valid(loc):
			_set_instance_at_location(loc, instance)
		else:
			printerr("InventoryManager: No space in run inventory for item. It will be lost.")

func _find_empty_slot_for_item(item_instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(item_instance): return null
	var item_def = item_instance.get_definition()
	if not item_def or not item_def.has("tier"): return null

	var target_tier = item_def.tier
	var container_name = "RunInventoryT%d" % target_tier
	var container = GameManager.run_state.get_container(container_name)

	if not is_instance_valid(container): return null

	var empty_index = container.find_first_empty_slot()
	if empty_index != -1:
		var loc = LocationIdentifier.new()
		loc.tier = target_tier
		loc.index = empty_index
		loc.container = container_name
		return loc

	return null


func _is_valid_placement(instance: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(instance) or not is_instance_valid(target_loc):
		return false

	var def = instance.get_definition()
	var target_container = target_loc.container



	# Rule: Run Inventory container must match item's tier, but ONLY if the slot is empty.
	# For swaps, the tier-matching is handled by the caller.
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(target_instance):
		if target_container.begins_with("RunInventoryT"):
			var container_tier = target_container.substr(len("RunInventoryT")).to_int()
			if def.tier != container_tier:
				return false

	# Rule: Battle Board container type restrictions.
	# Items cannot be placed on the player's lineup/bench; Units cannot be placed in the ItemInventory.
	if target_container in [&"PlayerLineup", &"PlayerBench"] and def.category == &"ITEM":
		return false
	if target_container == &"ItemInventory" and def.category == &"UNIT":
		return false

	# Additional validation for Battle Inventory grids: tier must match.
	if target_container.begins_with("BattleInventoryT"):
		var container_tier_b = target_container.substr(len("BattleInventoryT")).to_int()
		if def.tier != container_tier_b:
			return false

	return true

# --- DATA ACCESS HELPERS ---

# Find first empty slot for given instance in BATTLE inventory grids.
func _find_empty_slot_for_instance_battle(instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(instance):
		return null
	var def = instance.get_definition()
	if not is_instance_valid(def):
		return null
	var tier = def.tier
	var container_name = "BattleInventoryT%d" % tier
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(bm):
		return null
	var container = bm.get_container(container_name)
	if not is_instance_valid(container):
		return null
	var empty_idx = container.find_first_empty_slot()
	if empty_idx == -1:
		return null
	var loc = LocationIdentifier.new()
	loc.tier = tier
	loc.index = empty_idx
	loc.container = container_name
	return loc


func _find_empty_slot_for_instance(instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(instance): return null

	var def = instance.get_definition()
	if not is_instance_valid(def): return null

	var target_tier = def.tier
	var container_name = "RunInventoryT%d" % target_tier
	
	var container = GameManager.run_state.get_container(container_name)
	if not is_instance_valid(container):
		return null

	var empty_index = container.find_first_empty_slot()
	if empty_index != -1:
		var loc = LocationIdentifier.new()
		loc.tier = target_tier
		loc.index = empty_index
		loc.container = container_name
		return loc

	return null
func _get_instance_at_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null

	var uuid: String

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var battle_container = bm.get_container(loc.container)
		if is_instance_valid(battle_container):
			uuid = battle_container.get_uuid(loc.index)
			# In battle, instances are managed in a separate, temporary database.
			return bm.get_all_instances().get(uuid)
	else:
		var run_container = GameManager.run_state.get_container(loc.container)
		if is_instance_valid(run_container):
			uuid = run_container.get_uuid(loc.index)
			# In the run, the RunState is the single source of truth.
			return GameManager.run_state.get_instance_by_uuid(uuid)

	return null

func _set_instance_at_location(loc: LocationIdentifier, instance: GachaBallInstance):
	if not is_instance_valid(loc): return

	var uuid_to_set = "" if not is_instance_valid(instance) else instance.ball_uuid

	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		var container = bm.get_container(loc.container)
		if is_instance_valid(container):
			container.set_uuid(loc.index, uuid_to_set)
	else:
		var container = GameManager.run_state.get_container(loc.container)
		if is_instance_valid(container):
			container.set_uuid(loc.index, uuid_to_set)

	# Also update the instance's own location fields so data and UI remain in sync.
	if is_instance_valid(instance):
		instance.location_container_tag = loc.container
		instance.location_slot_index = loc.index

func _emit_data_changed_signal():
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	EventBus.emit_signal(signal_name)

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
