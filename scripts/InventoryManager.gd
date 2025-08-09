# res://scripts/InventoryManager.gd
extends Node

func _ready():
	SignalBus.try_inventory_action.connect(_on_try_inventory_action)
	SignalBus.choice_made.connect(_on_choice_made)

# --- Main Action Handler ---

func _on_try_inventory_action(source_loc, target_loc):
	print("InventoryManager: try_inventory_action src=", source_loc.container, " -> tgt=", target_loc.container)
	
	# Early-case: Allow equipping items onto units even across functional groups
	var early_source_instance = _get_instance_at_location(source_loc)
	var early_target_instance = _get_instance_at_location(target_loc)
	if is_instance_valid(early_source_instance) and is_instance_valid(early_target_instance):
		var sdef = early_source_instance.get_definition()
		var tdef = early_target_instance.get_definition()
		# Rule I3: Allow equipping from any InventoryGrid onto a UNIT on the board
		var s_group = GlobalInteractionRouter.get_context_group(source_loc.container)
		if sdef.category == &"ITEM" and tdef.category == &"UNIT" and s_group == &"InventoryGrid" and target_loc.container in [&"PlayerLineup", &"PlayerBench"]:
			print("InventoryManager: Early equip path triggered (ITEM -> UNIT on board)")
			_equip_item(early_source_instance, early_target_instance)
			GlobalInteractionRouter.end_drag(true)
			return

	# Early-case: Allow equipping items by dropping onto an equipped_item slot (empty or same-unit slot)
	if is_instance_valid(early_source_instance) and target_loc.container == &"equipped_item":
		var sdef2 = early_source_instance.get_definition()
		if sdef2.category == &"ITEM":
			var data_owner = _get_data_owner()
			if is_instance_valid(data_owner):
				var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
				if is_instance_valid(parent_unit):
					# If slot already occupied, fall through to swap logic later
					# Rule I3: Allow equipping into equipped_item from any InventoryGrid and only to empty slot
					var s_group2 = GlobalInteractionRouter.get_context_group(source_loc.container)
					if s_group2 == &"InventoryGrid" and target_loc.index < parent_unit.equipped_item_uuids.size() and parent_unit.equipped_item_uuids[target_loc.index] == "":
						print("InventoryManager: Early equip path triggered (ITEM -> equipped_item slot)")
						_remove_from_location(source_loc)
						_perform_equip(early_source_instance, parent_unit, target_loc.index)
						_emit_data_changed_signal()
						GlobalInteractionRouter.end_drag(true)
						return

	# TDD 4.3.IV: Check for invalid actions between incompatible contexts
	var source_context_group = GlobalInteractionRouter.get_context_group(source_loc.container)
	var target_context_group = GlobalInteractionRouter.get_context_group(target_loc.container)
	print("InventoryManager: Groups src=", source_context_group, " tgt=", target_context_group)
	
	# If contexts are incompatible, this is an invalid action
	if source_context_group != target_context_group:
		# Exception: Allow InventoryGrid -> equipped_item (click-to-click equip)
		if source_context_group == &"InventoryGrid" and target_loc.container == &"equipped_item":
			print("InventoryManager: Allowing InventoryGrid -> equipped_item despite group mismatch")
		else:
			print("InventoryManager: Group mismatch; rejecting unless SelectionOnly target")
			# Special case: Selection-Only contexts allow changing selection
			if target_context_group == &"SelectionOnly":
				# We shouldn't reach here, but if we do, it's invalid
				SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
				GlobalInteractionRouter.end_drag(false)
				return
			else:
				# Incompatible contexts - invalid action
				SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
				GlobalInteractionRouter.end_drag(false)
				return
	
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	if not is_instance_valid(source_instance):
		GlobalInteractionRouter.end_drag(false)
		return

	if not is_instance_valid(target_instance):
		if _is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			GlobalInteractionRouter.end_drag(true)
		else:
			# The placement is invalid. Report it.
			SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
			GlobalInteractionRouter.end_drag(false)
		return

	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	var data_owner: Object = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var all_instances_db = data_owner.get_all_instances()

	# Case 3: Possible Merge
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)
	if is_instance_valid(recipe):
		var context = { "source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id }
		WindowManager.open_choice_window(context)
		GlobalInteractionRouter.end_drag(true)
		return

	# Case 4: Possible Swap
	if _is_valid_placement(source_instance, target_loc) and _is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
		GlobalInteractionRouter.end_drag(true)
		return

	# If we reach the end and no valid action was found, report it.
	SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
	GlobalInteractionRouter.end_drag(false)


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
	SignalBus.emit_signal("selection_clear_requested")
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

	SignalBus.emit_signal("selection_clear_requested")
	_emit_data_changed_signal()

func _equip_item(item_instance: GachaBallInstance, unit_instance: GachaBallInstance):
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): 
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return

	# Restrict: If the item is already equipped on a unit, it may only be
	# re-equipped on THE SAME unit (i.e., moving between slots). Otherwise block.
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return

	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1:
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return

	_remove_from_location(item_instance.get_location())
	_perform_equip(item_instance, unit_instance, empty_slot_idx)
	SignalBus.emit_signal("selection_clear_requested")
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
	# CORRECTED: A "board merge" now includes the ItemInventory, not just player unit containers.
	var is_board_merge = target_loc.container.begins_with("Player") or target_loc.container == &"ItemInventory"

	# Case 1: Most specific. Merging two items on the same unit.
	if source_is_equipped and target_is_equipped and source_loc.unit_uuid == target_loc.unit_uuid:
		var parent_unit = all_instances_db.get(target_loc.unit_uuid)
		_perform_equip(new_instance, parent_unit, target_loc.index)
	# Case 2: Merging on the battle board (Lineup/Bench/ItemInventory). Result stays on the board.
	elif is_board_merge:
		_place_in_container_slot(new_instance, target_loc.container, target_loc.index)
	# Case 3: Merging in a draw pool. This is where tier-up logic applies.
	elif result_def.tier > source_instance.get_definition().tier:
		var prefix = "BattleInventoryT" if GameManager.is_in_battle else "RunInventoryT"
		var new_container_tag = &"%s%d" % [prefix, result_def.tier]
		var new_container = data_owner.get_container(new_container_tag)
		var new_slot = new_container.find_first_empty_slot()
		_place_in_container_slot(new_instance, new_container_tag, new_slot)
	# Case 4: Default. Same-tier merge in a draw pool. Result goes in target's old slot.
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

	SignalBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)

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
			SignalBus.emit_signal("unit_inventory_changed", parent_uuid)

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

	# 2. If the target is an equipped_item container, only allow equipping
	#    from ItemInventory (Rule I3). All actual equipping is handled in the
	#    early equip path; general placement into equipped_item is otherwise illegal.
	if target_container_name == &"equipped_item":
		return source_loc.container == &"ItemInventory"


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
	SignalBus.emit_signal(signal_name)
	SignalBus.emit_signal("inventory_ui_refresh_requested")

# --- Golden Rule Validation Helpers ---

func _validate_state_consistency() -> bool:
	"""Validates that the index and truth are synchronized across all instances"""
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner):
		return false
	
	var all_instances = data_owner.get_all_instances()
	
	for instance_uuid in all_instances:
		var instance = all_instances[instance_uuid]
		var location = instance.get_location()
		
		# Skip equipped items (they have special handling)
		if location.container == &"equipped_item":
			continue
			
		var container = data_owner.get_container(location.container)
		if not is_instance_valid(container):
			continue
			
		if container.get_uuid(location.index) != instance_uuid:
			push_error("State inconsistency detected: Instance %s location mismatch" % instance_uuid)
			return false
	
	return true

func _atomic_move_instance(instance: GachaBallInstance, from_loc: LocationIdentifier, to_loc: LocationIdentifier) -> void:
	"""Performs an atomic move operation ensuring Golden Rule compliance"""
	# Step 1: Update the index (DataContainer)
	_remove_from_location(from_loc)
	_place_in_container_slot(instance, to_loc.container, to_loc.index)
	
	# Step 2: Validate consistency (debug only)
	if OS.is_debug_build():
		if not _validate_state_consistency():
			push_error("State inconsistency detected after atomic move operation")
