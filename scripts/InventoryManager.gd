# res://scripts/InventoryManager.gd
extends Node

func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

# --- Main Action Handler ---

func _on_inventory_action_requested(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	InteractionManager.clear_selection()

	if source_loc.is_equal(target_loc):
		InteractionManager.end_drag(false)
		return

	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	# --- ACTION ROUTER ---

	# Case 1: Source is empty. Invalid action.
	if not is_instance_valid(source_instance):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	# Case 2: Target is an empty slot. This is a MOVE.
	if not is_instance_valid(target_instance):
		if _is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			InteractionManager.end_drag(true)
		else:
			_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return
	
	# --- From here, both source and target instances are valid. ---
	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	# Case 3: Item on Unit. This is a contextual EQUIP.
	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		if target_loc.container in [&"PlayerLineup", &"PlayerBench"]:
			_equip_item(source_loc, target_loc)
			InteractionManager.end_drag(true)
		else:
			# Not on the battle board, so treat as a potential SWAP.
			# Fall through to the MERGE/SWAP logic below.
			pass
	
	# Case 4: Everything else. Attempt a MERGE, or fallback to SWAP.
	var data_owner: Object
	if not GameManager.is_in_battle:
		if not is_instance_valid(GameManager.run_state):
			return
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
		if not is_instance_valid(data_owner):
			return

	var all_instances_db = data_owner.get_all_instances()
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)

	if is_instance_valid(recipe):
		# A valid merge recipe exists. Show the choice window.
		var context = { "source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id }
		WindowManager.open_dialog_window(&"ChoiceWindow", context)
		InteractionManager.end_drag(false)
		return

	# Fallback Case: No merge recipe. This is a SWAP.
	# A swap is only valid if BOTH items are allowed in the other's destination.
	if _is_valid_placement(source_instance, target_loc) and _is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
		InteractionManager.end_drag(true)
	else:
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))


func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		printerr("InventoryManager: Received choice_made with invalid locations.")
		return
		
	match choice:
		&"MERGE":
			# The recipe_id is now guaranteed to be valid here.
			_merge(source_loc, target_loc, recipe_id)
		&"SWAP":
			_swap(source_loc, target_loc)

# --- Core Logic Functions ---

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner: Object
	if not GameManager.is_in_battle:
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)
	
	var uuid = source_container.get_uuid(source_loc.index)
	source_container.set_uuid(source_loc.index, "")
	target_container.set_uuid(target_loc.index, uuid)
	
	if GameManager.is_in_battle:
		data_owner._update_instance_location(uuid, target_loc.container, target_loc.index)
	
	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner: Object
	if not GameManager.is_in_battle:
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)

	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)

	source_container.set_uuid(source_loc.index, target_uuid)
	target_container.set_uuid(target_loc.index, source_uuid)

	if GameManager.is_in_battle:
		if not source_uuid.is_empty():
			data_owner._update_instance_location(source_uuid, target_loc.container, target_loc.index)
		if not target_uuid.is_empty():
			data_owner._update_instance_location(target_uuid, source_loc.container, source_loc.index)

	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _equip_item(item_loc: LocationIdentifier, unit_loc: LocationIdentifier):
	var data_owner: Object
	if not GameManager.is_in_battle:
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	var _all_instances_db = data_owner.get_all_instances()
	
	var item_instance = _get_instance_at_location(item_loc)
	var unit_instance = _get_instance_at_location(unit_loc)
	
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): 
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	var _unit_def = unit_instance.get_definition()
	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	
	if empty_slot_idx == -1:
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	var item_container = data_owner.get_container(item_loc.container)
	item_container.set_uuid(item_loc.index, "")
	
	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = empty_slot_idx
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	if GameManager.is_in_battle:
		data_owner._instance_locations.erase(item_instance.ball_uuid)

	EventBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)
	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	var data_owner: Object
	if not GameManager.is_in_battle:
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
	var all_instances_db = data_owner.get_all_instances()
	
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): 
		return

	var recipe: MergeRecipe = Database.recipes.get(recipe_id)
	if not is_instance_valid(recipe): 
		return

	var result_def = Database.get_definition(recipe.result_id)
	if not is_instance_valid(result_def): 
		return

	var new_instance = GachaBallInstance.new()
	new_instance.initialize(result_def)
	all_instances_db[new_instance.ball_uuid] = new_instance
	
	var all_parent_items = MergeManager._get_equipped_item_instances(source_instance, all_instances_db)
	all_parent_items.append_array(MergeManager._get_equipped_item_instances(target_instance, all_instances_db))

	for i in range(min(all_parent_items.size(), new_instance.equipped_item_uuids.size())):
		var item_to_equip = all_parent_items[i]
		item_to_equip.equipped_on_uuid = new_instance.ball_uuid
		item_to_equip.equipped_slot_index = i
		new_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid
		if GameManager.is_in_battle: 
			data_owner._instance_locations.erase(item_to_equip.ball_uuid)

	var source_container = data_owner.get_container(source_loc.container)
	source_container.set_uuid(source_loc.index, "")
	var target_container = data_owner.get_container(target_loc.container)

	if source_loc.container == target_loc.container and result_def.tier == source_instance.get_definition().tier:
		target_container.set_uuid(target_loc.index, new_instance.ball_uuid)
		if GameManager.is_in_battle: 
			data_owner._update_instance_location(new_instance.ball_uuid, target_loc.container, target_loc.index)
	else:
		target_container.set_uuid(target_loc.index, "")
		var new_container_name = ("RunInventoryT%d" if not GameManager.is_in_battle else "BattleInventoryT%d") % result_def.tier
		var new_container = data_owner.get_container(new_container_name)
		var new_slot = new_container.find_first_empty_slot()
		if new_slot != -1:
			new_container.set_uuid(new_slot, new_instance.ball_uuid)
			if GameManager.is_in_battle: 
				data_owner._update_instance_location(new_instance.ball_uuid, new_container_name, new_slot)
		elif GameManager.is_in_battle:
			data_owner._move_instance_to_discard(new_instance)

	all_instances_db.erase(source_instance.ball_uuid)
	all_instances_db.erase(target_instance.ball_uuid)
	if GameManager.is_in_battle:
		data_owner._instance_locations.erase(source_instance.ball_uuid)
		data_owner._instance_locations.erase(target_instance.ball_uuid)

	EventBus.emit_signal("unit_inventory_changed", new_instance.ball_uuid)
	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

# --- Helpers ---

# Find first empty slot for given instance in BATTLE inventory grids.
func _find_empty_slot_for_instance_battle(instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(instance):
		return null

	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(bm):
		return null

	var tier = instance.get_definition().tier
	var container_name = "BattleInventoryT%d" % tier
	var container = bm.get_container(container_name)
	
	if is_instance_valid(container):
		var idx = container.find_first_empty_slot()
		if idx != -1:
			return LocationIdentifier.new(container_name, idx)
	return null

# Find first empty slot for given instance in RUN inventory grids.
func _find_empty_slot_for_instance(instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(instance):
		return null
		
	var data_owner: Object
	if not GameManager.is_in_battle:
		if not is_instance_valid(GameManager.run_state):
			return null
		data_owner = GameManager.run_state
	else:
		data_owner = get_tree().get_first_node_in_group("battle_manager")
		if not is_instance_valid(data_owner):
			return null

	var tier = instance.get_definition().tier
	var container_name = ("BattleInventoryT%d" if GameManager.is_in_battle else "RunInventoryT%d") % tier
	var container = data_owner.get_container(container_name)
	
	if is_instance_valid(container):
		var idx = container.find_first_empty_slot()
		if idx != -1:
			return LocationIdentifier.new(container_name, idx)
	return null

func _can_swap(source_instance: GachaBallInstance, target_instance: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance) or not is_instance_valid(target_loc):
		return false

	# Can't swap with itself
	if source_instance.ball_uuid == target_instance.ball_uuid:
		return false

	# Check if the source can go to the target location
	if not _is_valid_placement(source_instance, target_loc):
		return false

	# For now, allow all swaps that pass the above checks
	# Additional restrictions can be added here if needed
	return true

func _is_valid_placement(instance_to_check: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	# An empty source slot can always be "moved" (this is a no-op).
	if not is_instance_valid(instance_to_check): return true

	var def = instance_to_check.get_definition()
	var target_container_name = target_loc.container

	# Rule 1: Check tier compatibility for inventory containers.
	if target_container_name.begins_with("RunInventoryT"):
		var container_tier = target_container_name.substr(len("RunInventoryT")).to_int()
		if def.tier != container_tier: return false
	if target_container_name.begins_with("BattleInventoryT"):
		var container_tier_b = target_container_name.substr(len("BattleInventoryT")).to_int()
		if def.tier != container_tier_b: return false

	# Rule 2: Check category compatibility for board containers.
	if target_container_name in [&"PlayerLineup", &"PlayerBench"] and def.category == &"ITEM":
		return false
	if target_container_name == &"ItemInventory" and def.category == &"UNIT":
		return false

	# All checks passed for this direction.
	return true

func _get_instance_at_location(loc: LocationIdentifier) -> GachaBallInstance:
	return GameManager.get_instance_from_location(loc)

func _emit_data_changed_signal():
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	EventBus.emit_signal(signal_name)

func _handle_invalid_action(view: Control = null):
	if is_instance_valid(view):
		view.shake()
	InteractionManager.end_drag(false)
	InteractionManager.clear_selection()
