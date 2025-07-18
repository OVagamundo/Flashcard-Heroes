<!-- Original: scripts/InventoryManager.gd -->

```gdscript
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

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)
	var all_instances = data_owner.get_all_instances()

	# 1. Update the Index
	var uuid = source_container.get_uuid(source_loc.index)
	source_container.set_uuid(source_loc.index, "")
	target_container.set_uuid(target_loc.index, uuid)

	# 2. Update the Truth
	var instance = all_instances.get(uuid)
	if is_instance_valid(instance):
		instance.location_container_tag = target_loc.container
		instance.location_slot_index = target_loc.index
		# Ensure equip state is cleared on move
		instance.equipped_on_uuid = ""
		instance.equipped_slot_index = -1

	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var source_container = data_owner.get_container(source_loc.container)
	var target_container = data_owner.get_container(target_loc.container)
	var all_instances = data_owner.get_all_instances()

	var source_uuid = source_container.get_uuid(source_loc.index)
	var target_uuid = target_container.get_uuid(target_loc.index)

	# 1. Update the Index
	source_container.set_uuid(source_loc.index, target_uuid)
	target_container.set_uuid(target_loc.index, source_uuid)

	# 2. Update the Truth
	if not source_uuid.is_empty():
		var source_instance = all_instances.get(source_uuid)
		if is_instance_valid(source_instance):
			source_instance.location_container_tag = target_loc.container
			source_instance.location_slot_index = target_loc.index
	
	if not target_uuid.is_empty():
		var target_instance = all_instances.get(target_uuid)
		if is_instance_valid(target_instance):
			target_instance.location_container_tag = source_loc.container
			target_instance.location_slot_index = source_loc.index

	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _equip_item(item_loc: LocationIdentifier, unit_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return
	
	var item_instance = _get_instance_at_location(item_loc)
	var unit_instance = _get_instance_at_location(unit_loc)
	
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): 
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1:
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	# 1. Update the Index (remove from old container)
	var item_container = data_owner.get_container(item_loc.container)
	item_container.set_uuid(item_loc.index, "")
	
	# 2. Update the Truth (on the item instance itself)
	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = empty_slot_idx
	item_instance.location_container_tag = &"" # No longer in a container
	item_instance.location_slot_index = -1     # No longer in a container
	
	# Also update the unit's list of equipped items
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	EventBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)
	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var all_instances_db = data_owner.get_all_instances()
	
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	var recipe: MergeRecipe = Database.recipes.get(recipe_id)
	if not is_instance_valid(recipe): return

	var result_def = Database.get_definition(recipe.result_id)
	if not is_instance_valid(result_def): return

	# --- Create new instance and handle item inheritance ---
	var new_instance = GachaBallInstance.new()
	new_instance.initialize(result_def)
	all_instances_db[new_instance.ball_uuid] = new_instance
	
	var all_parent_items = MergeManager._get_equipped_item_instances(source_instance, all_instances_db)
	all_parent_items.append_array(MergeManager._get_equipped_item_instances(target_instance, all_instances_db))

	for i in range(min(all_parent_items.size(), new_instance.equipped_item_uuids.size())):
		var item_to_equip = all_parent_items[i]
		# Update the Truth for the inherited item
		item_to_equip.equipped_on_uuid = new_instance.ball_uuid
		item_to_equip.equipped_slot_index = i
		item_to_equip.location_container_tag = &""
		item_to_equip.location_slot_index = -1
		new_instance.equipped_item_uuids[i] = item_to_equip.ball_uuid

	# --- Remove parent instances from their containers (Update Index) ---
	var source_container = data_owner.get_container(source_loc.container)
	source_container.set_uuid(source_loc.index, "")
	var target_container = data_owner.get_container(target_loc.container)
	target_container.set_uuid(target_loc.index, "")

	# --- Place the new instance (Update Index and Truth) ---
	var final_container_name: StringName
	var final_container: DataContainer
	var final_slot: int

	# Determine where the new instance should go
	if result_def.tier == source_instance.get_definition().tier:
		final_container_name = target_loc.container
		final_container = target_container
		final_slot = target_loc.index
	else:
		final_container_name = ("RunInventoryT%d" if not GameManager.is_in_battle else "BattleInventoryT%d") % result_def.tier
		final_container = data_owner.get_container(final_container_name)
		final_slot = final_container.find_first_empty_slot()

	if final_slot != -1:
		# 1. Update Index
		final_container.set_uuid(final_slot, new_instance.ball_uuid)
		# 2. Update Truth
		new_instance.location_container_tag = final_container_name
		new_instance.location_slot_index = final_slot
	elif GameManager.is_in_battle: # No space, discard if in battle
		var discard_container = data_owner.get_container(&"DiscardPile")
		var discard_slot = discard_container.find_first_empty_slot()
		# 1. Update Index
		discard_container.set_uuid(discard_slot, new_instance.ball_uuid)
		# 2. Update Truth
		new_instance.location_container_tag = &"DiscardPile"
		new_instance.location_slot_index = discard_slot

	# --- Final Cleanup: Remove parent instances from the master DB ---
	all_instances_db.erase(source_instance.ball_uuid)
	all_instances_db.erase(target_instance.ball_uuid)

	EventBus.emit_signal("unit_inventory_changed", new_instance.ball_uuid)
	_emit_data_changed_signal()
	EventBus.emit_signal("inventory_ui_refresh_requested")
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

func _handle_invalid_action(_view: Control = null):
	InteractionManager.end_drag(false)
	InteractionManager.clear_selection()

```