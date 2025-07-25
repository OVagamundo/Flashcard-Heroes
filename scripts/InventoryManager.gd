# res://scripts/InventoryManager.gd
extends Node

func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)

# --- Main Action Handler ---

func _on_inventory_action_requested(source_loc, target_loc):
	EventBus.emit_signal("selection_clear_requested")

	if source_loc.is_equal(target_loc):
		InteractionManager.end_drag(false)
		return

	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	# --- ACTION ROUTER ---
	if not is_instance_valid(source_instance):
		_handle_invalid_action()
		return

	if not is_instance_valid(target_instance):
		if _is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			InteractionManager.end_drag(true)
		else:
			_handle_invalid_action()
		return
	
	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		if target_loc.container in [&"PlayerLineup", &"PlayerBench"]:
			_equip_item(source_instance, target_instance)
			InteractionManager.end_drag(true)
			return
	
	var data_owner: Object = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var all_instances_db = data_owner.get_all_instances()
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)

	if is_instance_valid(recipe):
		var context = { "source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id }
		WindowManager.open_dialog_window(&"ChoiceWindow", context)
		InteractionManager.end_drag(false)
		return

	if _is_valid_placement(source_instance, target_loc) and _is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
		InteractionManager.end_drag(true)
	else:
		_handle_invalid_action()


func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		printerr("InventoryManager: Received choice_made with invalid locations.")
		return
		
	match choice:
		&"MERGE":
			_merge(source_loc, target_loc, recipe_id)
		&"SWAP":
			_swap(source_loc, target_loc)

# --- Core Logic Functions ---

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var instance_to_move = _get_instance_at_location(source_loc)
	if not is_instance_valid(instance_to_move): return

	# Special-case: moving an item into an equipped slot on a unit.
	if target_loc.container == &"equipped_item":
		var data_owner = _get_data_owner()
		if not is_instance_valid(data_owner): return
		var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
		if is_instance_valid(parent_unit):
			_remove_from_location(source_loc)
			_perform_equip(instance_to_move, parent_unit, target_loc.index)
			_emit_data_changed_signal()
			return

	# Default move behaviour for normal containers
	_remove_from_location(source_loc)
	_place_in_container_slot(instance_to_move, target_loc.container, target_loc.index)
	_emit_data_changed_signal()

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return
	
	var all_instances_db = data_owner.get_all_instances()
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	_remove_from_location(source_loc)
	_remove_from_location(target_loc)

	if target_loc.container == &"equipped_item":
		var target_parent_unit = all_instances_db.get(target_loc.unit_uuid)
		_perform_equip(source_instance, target_parent_unit, target_loc.index)
	else:
		_place_in_container_slot(source_instance, target_loc.container, target_loc.index)

	if source_loc.container == &"equipped_item":
		var source_parent_unit = all_instances_db.get(source_loc.unit_uuid)
		_perform_equip(target_instance, source_parent_unit, source_loc.index)
	else:
		_place_in_container_slot(target_instance, source_loc.container, source_loc.index)

	_emit_data_changed_signal()

func _equip_item(item_instance: GachaBallInstance, unit_instance: GachaBallInstance):
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): 
		_handle_invalid_action()
		return

	# Restrict: If the item is already equipped on a unit, it may only be
	# re-equipped on THE SAME unit (i.e., moving between slots). Otherwise block.
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		_handle_invalid_action()
		return

	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1:
		_handle_invalid_action()
		return

	_remove_from_location(item_instance.get_location())
	_perform_equip(item_instance, unit_instance, empty_slot_idx)
	_emit_data_changed_signal()

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var all_instances_db = data_owner.get_all_instances()
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	var recipe: MergeRecipe = Database.recipes.get(recipe_id)
	var result_def = Database.get_definition(recipe.result_id)
	if not is_instance_valid(result_def): return

	var new_instance = GachaBallInstance.new()
	new_instance.initialize(result_def)
	all_instances_db[new_instance.ball_uuid] = new_instance
	
	var all_parent_items = MergeManager._get_equipped_item_instances(source_instance, all_instances_db)
	all_parent_items.append_array(MergeManager._get_equipped_item_instances(target_instance, all_instances_db))

	for i in range(min(all_parent_items.size(), new_instance.equipped_item_uuids.size())):
		var item_to_equip = all_parent_items[i]
		_perform_equip(item_to_equip, new_instance, i)

	_remove_from_location(source_loc)
	_remove_from_location(target_loc)

	# --- CONTEXT-AWARE PLACEMENT LOGIC ---
	var source_is_equipped = source_loc.container == &"equipped_item"
	var target_is_equipped = target_loc.container == &"equipped_item"
	var is_board_merge = target_loc.container.begins_with("Player") # PlayerLineup, PlayerBench

	# Case 1: Most specific. Merging two items on the same unit.
	if source_is_equipped and target_is_equipped and source_loc.unit_uuid == target_loc.unit_uuid:
		var parent_unit = all_instances_db.get(target_loc.unit_uuid)
		_perform_equip(new_instance, parent_unit, target_loc.index)
	# Case 2: Merging on the battle board (Lineup/Bench). Result stays on the board.
	elif is_board_merge:
		_place_in_container_slot(new_instance, target_loc.container, target_loc.index)
	# Case 3: Merging in an inventory. This is where tier-up logic applies.
	elif result_def.tier > source_instance.get_definition().tier:
		var prefix = "BattleInventoryT" if GameManager.is_in_battle else "RunInventoryT"
		var new_container_tag = &"%s%d" % [prefix, result_def.tier]
		var new_container = data_owner.get_container(new_container_tag)
		var new_slot = new_container.find_first_empty_slot()
		_place_in_container_slot(new_instance, new_container_tag, new_slot)
	# Case 4: Default. Same-tier merge in inventory. Result goes in target's old slot.
	else:
		_place_in_container_slot(new_instance, target_loc.container, target_loc.index)

	all_instances_db.erase(source_instance.ball_uuid)
	all_instances_db.erase(target_instance.ball_uuid)

	_emit_data_changed_signal()

# --- Single-Responsibility Helpers ---

func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance, target_item_slot: int):
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): return

	# If the item was previously equipped on another unit, unequip its bonus from that unit
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		var data_owner = _get_data_owner()
		if is_instance_valid(data_owner):
			var prev_unit = data_owner.get_all_instances().get(item_instance.equipped_on_uuid)
			if is_instance_valid(prev_unit):
				prev_unit.unequip_item_bonus(item_instance)

	# If the item was previously equipped on this unit, unequip from old slot
	if item_instance.equipped_on_uuid == unit_instance.ball_uuid:
		unit_instance.unequip_item_bonus(item_instance)

	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = target_item_slot
	item_instance.location_container_tag = &""
	item_instance.location_slot_index = -1

	if target_item_slot < unit_instance.equipped_item_uuids.size():
		unit_instance.equipped_item_uuids[target_item_slot] = item_instance.ball_uuid

	# Equip the bonus to the new unit
	unit_instance.equip_item_bonus(item_instance)

	EventBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)

func _perform_unequip(item_instance: GachaBallInstance):
	if not is_instance_valid(item_instance): return
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var parent_uuid = item_instance.equipped_on_uuid
	if not parent_uuid.is_empty():
		var parent_unit = data_owner.get_all_instances().get(parent_uuid)
		if is_instance_valid(parent_unit):
			if item_instance.equipped_slot_index < parent_unit.equipped_item_uuids.size():
				parent_unit.equipped_item_uuids[item_instance.equipped_slot_index] = ""
			EventBus.emit_signal("unit_inventory_changed", parent_uuid)

	item_instance.equipped_on_uuid = ""
	item_instance.equipped_slot_index = -1

func _place_in_container_slot(instance: GachaBallInstance, container_tag: StringName, slot_index: int):
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner) or not is_instance_valid(instance): return
	var container = data_owner.get_container(container_tag)
	if not is_instance_valid(container): return
	
	# Update Index
	container.set_uuid(slot_index, instance.ball_uuid)
	# Update Truth (and guarantee it's not also equipped)
	instance.location_container_tag = container_tag
	instance.location_slot_index = slot_index
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1

func _remove_from_location(loc: LocationIdentifier):
	var instance = _get_instance_at_location(loc)
	if not is_instance_valid(instance): return
	
	if loc.container == &"equipped_item":
		_perform_unequip(instance)
	else:
		var data_owner = _get_data_owner()
		var container = data_owner.get_container(loc.container)
		if is_instance_valid(container):
			container.set_uuid(loc.index, "")

# --- Other Helpers ---

func _is_valid_placement(instance_to_check: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(instance_to_check): return true

	var def = instance_to_check.get_definition()
	var target_container_name = target_loc.container

	# ------------------------------------------------------------------
	# HERO RESTRICTION: Heroes may only reside in PlayerLineup.
	var is_hero := String(def.id).to_lower() == "hero"
	if not is_hero:
		for tag in def.tags:
			if String(tag).to_lower() == "hero":
				is_hero = true
				break
	if is_hero:
		return target_container_name == &"PlayerLineup"

	# ------------------------------------------------------------------
	# EQUIPPED ITEM RESTRICTIONS
	var source_loc := instance_to_check.get_location()

	# 1. If the item is currently equipped, it cannot be moved anywhere except
	#    another slot on the SAME parent unit.
	if source_loc and source_loc.container == &"equipped_item":
		return target_container_name == &"equipped_item" and target_loc.unit_uuid == source_loc.unit_uuid

	# 2. If the target is an equipped_item container, only allow if the source
	#    item is NOT equipped and we're equipping it onto that unit (handled
	#    elsewhere), so ensure it's a different container.
	if target_container_name == &"equipped_item":
		# Only allowed when moving from non-equipped to equipped of SAME unit.
		return source_loc.container != &"equipped_item" and target_loc.unit_uuid == target_loc.unit_uuid # always true, but keeps symmetry


	if target_container_name.begins_with("RunInventoryT"):
		var container_tier = target_container_name.substr(len("RunInventoryT")).to_int()
		if def.tier != container_tier: return false
	if target_container_name.begins_with("BattleInventoryT"):
		var container_tier_b = target_container_name.substr(len("BattleInventoryT")).to_int()
		if def.tier != container_tier_b: return false

	if target_container_name in [&"PlayerLineup", &"PlayerBench"] and def.category == &"ITEM":
		return false
	if target_container_name == &"ItemInventory" and def.category == &"UNIT":
		return false

	return true

func _get_instance_at_location(loc: LocationIdentifier) -> GachaBallInstance:
	return GameManager.get_instance_from_location(loc)

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

func _emit_data_changed_signal():
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	EventBus.emit_signal(signal_name)
	EventBus.emit_signal("inventory_ui_refresh_requested")

func _handle_invalid_action():
	InteractionManager.end_drag(false)
	EventBus.emit_signal("selection_clear_requested")
