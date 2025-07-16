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

	# Get data owner and containers
	var data_owner = _get_data_owner()
	var all_instances_db = data_owner.get_all_instances()
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)
	
	if source_container == null or target_container == null:
		_handle_invalid_action(null)
		return

	# Get instance UUIDs from containers
	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)
	
	# Get instances from the database
	var source_instance = all_instances_db.get(source_uuid) if not source_uuid.is_empty() else null
	var target_instance = all_instances_db.get(target_uuid) if not target_uuid.is_empty() else null

	if not is_instance_valid(source_instance):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	# --- Case 1: Target is an empty slot (MOVE) ---
	if not is_instance_valid(target_instance):
		if _is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			InteractionManager.end_drag(true)
		else:
			_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	# --- From here, target_instance is always valid ---

	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	# --- Case 2: One is an Item, the other is a Unit (EQUIP) ---
	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		# This is a potential equip action. Check if it's valid.
		if target_loc.container in [&"PlayerLineup", &"PlayerBench"]:
			# It's a valid equip on the battle board.
			_equip_item(source_loc, target_loc)
			InteractionManager.end_drag(true)
			return # The action is complete, so we exit the function.
		# If not on the battle board, we do nothing here and let the code
		# fall through to the merge/swap logic below.

	# --- Case 3: Both are Units or both are Items (MERGE or SWAP) ---
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)

	if is_instance_valid(recipe):
		# A valid recipe exists. Let the user choose.
		var context = {
			"source_location": source_loc,
			"target_location": target_loc,
			"recipe_id": recipe.id # Pass the recipe ID to the choice window
		}
		WindowManager.open_dialog_window(&"ChoiceWindow", context)
		InteractionManager.end_drag(false) # Action is not complete yet
		return

	# --- Case 4: No merge recipe, default to SWAP ---
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
	var data_owner = _get_data_owner()
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)
	
	var uuid = source_container.get_uuid(source_loc.index)
	source_container.set_uuid(source_loc.index, "")
	target_container.set_uuid(target_loc.index, uuid)
	
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)

	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)

	source_container.set_uuid(source_loc.index, target_uuid)
	target_container.set_uuid(target_loc.index, source_uuid)

	EventBus.emit_signal("inventory_ui_refresh_requested")

func _equip_item(item_loc: LocationIdentifier, unit_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	var all_instances_db = data_owner.get_all_instances()
	var item_container = data_owner.get_container(item_loc.container)
	var unit_container = data_owner.get_container(unit_loc.container)

	var item_uuid = item_container.get_uuid(item_loc.index)
	var unit_uuid = unit_container.get_uuid(unit_loc.index)
	
	var item_instance = all_instances_db.get(item_uuid)
	var unit_instance = all_instances_db.get(unit_uuid)
	var unit_def = unit_instance.get_definition()

	var empty_slot_idx = -1
	for i in range(unit_def.item_slot_count):
		if unit_instance.get_equipped_item_uuid(i).is_empty():
			empty_slot_idx = i
			break
	
	if empty_slot_idx == -1:
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	item_container.set_uuid(item_loc.index, "")
	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = empty_slot_idx
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	EventBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	var data_owner = _get_data_owner()
	var all_instances_db = data_owner.get_all_instances()
	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)

	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)
	var source_instance = all_instances_db.get(source_uuid)
	var target_instance = all_instances_db.get(target_uuid)

	var recipe: MergeRecipe = Database.recipes.get(recipe_id)
	if not is_instance_valid(recipe):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	var result_def = Database.get_definition(recipe.result_id)
	if not is_instance_valid(result_def):
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	# Create the new instance and handle item inheritance
	var new_instance = GachaBallInstance.new()
	new_instance.initialize(result_def)
	var all_parent_items = MergeManager._get_equipped_item_instances(source_instance, all_instances_db)
	all_parent_items.append_array(MergeManager._get_equipped_item_instances(target_instance, all_instances_db))

	for i in range(min(all_parent_items.size(), new_instance.equipped_item_uuids.size())):
		var item_to_equip = all_parent_items[i]
		item_to_equip.equipped_on_uuid = new_instance.ball_uuid
		item_to_equip.equipped_slot_index = i
		new_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid

	all_instances_db[new_instance.ball_uuid] = new_instance
	source_container.set_uuid(source_loc.index, "")

	if source_loc.container == target_loc.container and new_instance.get_definition().tier == source_instance.get_definition().tier:
		target_container.set_uuid(target_loc.index, new_instance.ball_uuid)
	else:
		target_container.set_uuid(target_loc.index, "")
		var new_container_name = ("RunInventoryT%d" if not GameManager.is_in_battle else "BattleInventoryT%d") % new_instance.get_definition().tier
		var new_container = data_owner.get_container(new_container_name)
		var new_slot = new_container.find_first_empty_slot()
		if new_slot != -1:
			new_container.set_uuid(new_slot, new_instance.ball_uuid)
		elif GameManager.is_in_battle:
			data_owner._move_instance_to_discard(new_instance)

	all_instances_db.erase(source_instance.ball_uuid)
	all_instances_db.erase(target_instance.ball_uuid)

	EventBus.emit_signal("unit_inventory_changed", new_instance.ball_uuid)
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
			var loc = LocationIdentifier.new()
			loc.container = container_name
			loc.index = idx
			loc.tier = tier
			return loc
	return null

# Find first empty slot for given instance in RUN inventory grids.
func _find_empty_slot_for_instance(instance: GachaBallInstance) -> LocationIdentifier:
	if not is_instance_valid(instance) or not is_instance_valid(GameManager.run_state):
		return null

	var tier = instance.get_definition().tier
	var container_name = "RunInventoryT%d" % tier
	var container = GameManager.run_state.get_container(container_name)
	
	if is_instance_valid(container):
		var idx = container.find_first_empty_slot()
		if idx != -1:
			var loc = LocationIdentifier.new()
			loc.container = container_name
			loc.index = idx
			loc.tier = tier
			return loc
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
	if not is_instance_valid(instance_to_check): return true # Moving an empty slot is always valid.

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

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

func _emit_data_changed_signal():
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	EventBus.emit_signal(signal_name)

func _handle_invalid_action(view: Control = null):
	if is_instance_valid(view):
		view.shake()
	InteractionManager.end_drag(false)
	InteractionManager.clear_selection()
