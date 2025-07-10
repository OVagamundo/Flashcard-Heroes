<!-- Original: scripts/InventoryManager.gd -->

```gdscript
extends Node

# --- State ---
# Stores the context for a pending choice (Merge vs. Swap).


# --- Engine Callbacks ---
func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

# TDD Action Decision Tree Implementation
func _on_inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var source_view = WindowManager.find_view_by_location(source_loc)
	var target_view = WindowManager.find_view_by_location(target_loc)

	if not is_instance_valid(source_view) or not is_instance_valid(target_view):
		printerr("InventoryManager: Could not find views for one or both locations.")
		InteractionManager.clear_selection()
		InteractionManager.end_drag(false)
		return

	InteractionManager.clear_selection()

	if source_view == target_view:
		InteractionManager.end_drag(false)
		return

	var source_instance = _get_instance_at_location(source_loc)
	if not is_instance_valid(source_instance):
		_handle_invalid_action(source_view)
		return

	# --- TDD UNIFIED ACTION DECISION TREE ---

	# 1. Is the target an empty slot? Intent is MOVE.
	if target_view is SlotView:
		_handle_move(source_view, target_view)
		return

	# From here on, the target is another GachaBall.
	var target_instance = _get_instance_at_location(target_loc)
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
	if (def_a.category == "UNIT" and def_b.category == "ITEM") or \
	   (def_a.category == "ITEM" and def_b.category == "UNIT"):
		
		# TDD: This is the core of being context-aware.
		# If we are in a battle, the intent is EQUIP.
		if GameManager.is_in_battle:
			var unit_view = view_a if def_a.category == "UNIT" else view_b
			var item_view = view_b if def_a.category == "UNIT" else view_a
			_handle_equip(item_view, unit_view)
			return
		# If we are NOT in a battle, equipping is impossible. The user's intent
		# in this context can only be to SWAP the two items. The decision tree
		# will naturally fall through to the _swap call below.

	# 3. If not an Equip action, check for MERGE intent.
	var recipe = MergeManager.find_recipe(def_a.id, def_b.id)
	if recipe:
		# TDD: Don't act directly. Ask the user by opening a choice window.
		# Pass the LOCATIONS, not the views, as context.
		var context = {
			"source_location": source_loc,
			"target_location": target_loc
		}
		WindowManager.open_dialog_window("ChoiceWindow", context)
		return

	# 4. Fallback: If it's not Move, Equip, or Merge, the intent is SWAP.
	# But first, validate that the containers are compatible for a swap.
	if not _are_containers_compatible_for_swap(source_loc, target_loc):
		_handle_invalid_action(source_view)
		return
	
	_swap(source_loc, target_loc)

func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
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

	# Validate that both instances are allowed in the other's location.
	if not _is_valid_placement(source_instance, target_loc) or not _is_valid_placement(target_instance, source_loc):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return
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
	_set_instance_at_location(item_loc, null)
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	# Finally, signal that data has changed so the UI can react.
	_emit_data_changed_signal()

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	# CORRECTED LOGIC: Get the correct master instance database based on context.
	var all_instances_db: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		all_instances_db = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		all_instances_db = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

	# Pass the correct data to the MergeManager.
	var merge_result: Dictionary = MergeManager.calculate_merge_result(source_instance, target_instance, all_instances_db)

	if merge_result.is_empty():
		# TDD: If there's no valid merge recipe, the behavior depends on context.
		if GameManager.is_in_battle:
			_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		else:
			# In the run inventory, a failed merge results in a swap.
			_swap(source_loc, target_loc)
		return

	var new_instance: GachaBallInstance = merge_result.merged_instance
	var parents_to_remove: Array[GachaBallInstance] = merge_result.parents_to_remove

	# --- CONTEXT-AWARE MERGE LOGIC ---
	# 3. Add the new instance to the master database.
	all_instances_db[new_instance.ball_uuid] = new_instance

	# 4. Place the new instance and clear the old slots based on context.
	if GameManager.is_in_battle:
		# In battle, the new unit replaces the target.
		_set_instance_at_location(source_loc, null)
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

# --- TDD Compatibility & Validation ---

func _are_containers_compatible_for_swap(loc_a: LocationIdentifier, loc_b: LocationIdentifier) -> bool:
	if not is_instance_valid(loc_a) or not is_instance_valid(loc_b):
		return false

	var data_owner: Object
	if not GameManager.is_in_battle:
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(data_owner):
		return false

	var container_a = data_owner.get_container(loc_a.container)
	var container_b = data_owner.get_container(loc_b.container)

	if not is_instance_valid(container_a) or not is_instance_valid(container_b):
		return false

	# Rule: Containers must be of the same type (e.g., both UNIT or both ITEM).
	# Note: We are accessing the properties of the container NODE, not its data script.
	if "type" in container_a and "type" in container_b and container_a.type != container_b.type:
		return false

	# Rule: If containers have tiers, they must match.
	var a_has_tier = "tier" in container_a
	var b_has_tier = "tier" in container_b

	if a_has_tier and b_has_tier:
		if container_a.tier != container_b.tier:
			return false
	elif a_has_tier != b_has_tier:
		# If one has a tier and the other doesn't, they are not compatible.
		return false

	return true


func _is_valid_placement(instance: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(instance) or not is_instance_valid(target_loc):
		return false

	var def = instance.get_definition()
	var target_container = target_loc.container

	# Rule: Hero can only be in the lineup.
	if def.id == "hero" and target_container != "PlayerLineup":
		return false

	# Rule: Inventory Grids must have matching tiers.
	if target_container.begins_with("RunInventoryT"):
		var target_tier = target_container.substr(len("RunInventoryT")).to_int()
		if def.tier != target_tier:
			return false

	# Rule: Battle Board container type restrictions.
	if not target_container.begins_with("RunInventory"):
		if def.category == "UNIT" and target_container == "ItemInventory":
			return false
		if def.category == "ITEM" and target_container in ["PlayerLineup", "PlayerBench"]:
			return false

	return true

# --- DATA ACCESS HELPERS ---

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
		var container = bm.get_container(loc.container)
		if is_instance_valid(container):
			uuid = container.get_uuid(loc.index)
			return bm._battle_instances.get(uuid)
	else:
		var container = GameManager.run_state.get_container(loc.container)
		if is_instance_valid(container):
			uuid = container.get_uuid(loc.index)
			return GameManager.run_state.run_instances.get(uuid)
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

```