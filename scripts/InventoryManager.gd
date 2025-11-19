# res://scripts/InventoryManager.gd
extends Node

func _ready() -> void:
	SignalBus.try_inventory_action.connect(_on_try_inventory_action)
	SignalBus.choice_made.connect(_on_choice_made)

# --- Main Action Handler ---

func _on_try_inventory_action(source_loc, target_loc) -> void:
	
	# Early-case: Allow equipping items onto units even across functional groups
	var early_source_instance = _get_instance_at_location(source_loc)
	var early_target_instance = _get_instance_at_location(target_loc)
	if is_instance_valid(early_source_instance) and is_instance_valid(early_target_instance):
		var sdef = early_source_instance.get_definition()
		var tdef = early_target_instance.get_definition()
		# Rule I3: Allow equipping from any InventoryGrid onto a UNIT on the board
		var s_group = GlobalInteractionRouter.get_context_group(source_loc.container)
		if sdef.category == &"ITEM" and tdef.category == &"UNIT" and s_group == &"InventoryGrid" and target_loc.container in [&"PlayerLineup", &"PlayerBench"]:
			# Use atomic equip API
			var owner = _get_data_owner()
			if is_instance_valid(owner):
				owner.equip_item(early_source_instance.ball_uuid, early_target_instance.ball_uuid, -1)
			GlobalInteractionRouter.end_drag(true)
			return

	# Early-case: Allow equipping items by dropping onto an equipped_item slot (empty or same-unit slot)
	if is_instance_valid(early_source_instance) and target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
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
						# Use atomic equip with explicit slot
						data_owner.equip_item(early_source_instance.ball_uuid, parent_unit.ball_uuid, target_loc.index)
						GlobalInteractionRouter.end_drag(true)
						return

	# TDD 4.3.IV: Check for invalid actions between incompatible contexts
	var source_context_group = GlobalInteractionRouter.get_context_group(source_loc.container)
	var target_context_group = GlobalInteractionRouter.get_context_group(target_loc.container)
	# SelectionOnly contexts (Shop/Rewards): all inventory actions are invalid by design.
	# Cancel drag immediately so the original sprite reappears and nothing moves.
	if source_context_group == &"SelectionOnly" or target_context_group == &"SelectionOnly":
		SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
		GlobalInteractionRouter.end_drag(false)
		return
	
	# If contexts are incompatible, this is an invalid action
	if source_context_group != target_context_group:
		# Exception: Allow InventoryGrid -> equipped_item (click-to-click equip)
		if source_context_group == &"InventoryGrid" and target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			# Allowed exception; fall through to normal handling below
			pass
		else:
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
		var context: Dictionary = { "source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id }
		WindowManager.open_choice_window(context)
		GlobalInteractionRouter.end_drag(false)
		return

	# Case 4: Possible Swap
	if _is_valid_placement(source_instance, target_loc) and _is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
		GlobalInteractionRouter.end_drag(true)
		return

	# If we reach the end and no valid action was found, report it.
	SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
	GlobalInteractionRouter.end_drag(false)


func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName) -> void:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return
	# Activate suppression via GIR for the parent inspection window of the target (or source) view
	# to avoid premature closure during swap/merge execution triggered by ChoiceWindow.
	var wm = WindowManager
	var anchor_view: Control = wm.find_view_for_location(target_loc)
	if not is_instance_valid(anchor_view):
		anchor_view = wm.find_view_for_location(source_loc)
	var parent_window: Control = wm.find_ancestor_window_for_view(anchor_view) if is_instance_valid(anchor_view) else null
	var parent_id: int = parent_window.get_instance_id() if is_instance_valid(parent_window) else -1
	var inside_unit: bool = target_loc.container == C.CONTAINER_EQUIPPED_ITEM or target_loc.container in [&"PlayerLineup", &"PlayerBench"]
	if parent_id != -1:
		# Note: Using GIR's suppression helper to ensure WindowManager.request_close_inspection_window honors it.
		GlobalInteractionRouter.activate_close_suppression_for_window_id(parent_id, 420 if inside_unit else 320)

	match choice:
		&"MERGE":
			_merge(source_loc, target_loc, recipe_id)
		&"SWAP":
			_swap(source_loc, target_loc)

# --- Core Logic Functions ---

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> void:
	var instance_to_move = _get_instance_at_location(source_loc)
	if not is_instance_valid(instance_to_move): return

	# Special-case: moving an item into an equipped slot on a unit.
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var data_owner = _get_data_owner()
		if not is_instance_valid(data_owner): return
		var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
		if is_instance_valid(parent_unit):
			# Atomic equip handles removal and signaling
			data_owner.equip_item(instance_to_move.ball_uuid, parent_unit.ball_uuid, target_loc.index)
			SignalBus.emit_signal("selection_clear_requested")
			return

	# Default move behaviour for normal containers
	var owner = _get_data_owner()
	if not is_instance_valid(owner): return
	owner.move_instance(source_loc, target_loc)
	SignalBus.emit_signal("selection_clear_requested")

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> void:
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return
	
	var all_instances_db = data_owner.get_all_instances()
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	# Use atomic swap APIs
	data_owner.swap_instances(source_loc, target_loc)

	SignalBus.emit_signal("selection_clear_requested")

func _equip_item(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
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

	# Use atomic equip API (slot resolved above)
	var owner = _get_data_owner()
	if is_instance_valid(owner):
		owner.equip_item(item_instance.ball_uuid, unit_instance.ball_uuid, empty_slot_idx)
	SignalBus.emit_signal("selection_clear_requested")

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName) -> void:
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
	# Collect items equipped on parents (if any) to equip onto a UNIT result later
	var all_parent_items: Array[GachaBallInstance] = MergeManager._get_equipped_item_instances(source_instance, all_instances_db)
	all_parent_items.append_array(MergeManager._get_equipped_item_instances(target_instance, all_instances_db))

	# --- CONTEXT-AWARE PLACEMENT LOGIC (atomic) ---
	var source_is_equipped = source_loc.container == C.CONTAINER_EQUIPPED_ITEM
	var target_is_equipped = target_loc.container == C.CONTAINER_EQUIPPED_ITEM
	# CORRECTED: A "board merge" now includes the ItemInventory, not just player unit containers.
	var is_board_merge = target_loc.container.begins_with("Player") or target_loc.container == &"ItemInventory"

	var placed_container: StringName = &""
	var placed_index: int = -1

	# For all merges except equipping two items on the same unit, remove source/target first
	var is_same_unit_item_merge := source_is_equipped and target_is_equipped and source_loc.unit_uuid == target_loc.unit_uuid
	if not is_same_unit_item_merge:
		data_owner.remove_instance(source_instance.ball_uuid)
		data_owner.remove_instance(target_instance.ball_uuid)

	# Case 1: Most specific. Merging two items on the same unit -> remove both items, then equip the new item on same unit slot
	if is_same_unit_item_merge:
		# Remove old items first (safe for equipped items)
		data_owner.remove_instance(source_instance.ball_uuid)
		data_owner.remove_instance(target_instance.ball_uuid)
		# Register new item temporarily into ItemInventory, then equip onto the unit slot
		var temp_container: StringName = &"ItemInventory"
		data_owner.add_instance(new_instance, temp_container, -1)
		data_owner.equip_item(new_instance.ball_uuid, target_loc.unit_uuid, target_loc.index)
		placed_container = C.CONTAINER_EQUIPPED_ITEM
		placed_index = target_loc.index
	# Case 2: Merging on the board (Lineup/Bench/ItemInventory) -> place result into target slot
	elif is_board_merge:
		data_owner.add_instance(new_instance, target_loc.container, target_loc.index)
		placed_container = target_loc.container
		placed_index = target_loc.index
	# Case 3: Draw pool tier-up -> place in higher-tier container first empty slot
	elif ("tier" in result_def) and ("tier" in source_instance.get_definition()) and result_def.tier > source_instance.get_definition().tier:
		var prefix = "BattleInventoryT" if GameManager.is_in_battle else "RunInventoryT"
		var new_container_tag = &"%s%d" % [prefix, result_def.tier]
		# Use atomic add with index -1 (first empty)
		data_owner.add_instance(new_instance, new_container_tag, -1)
		placed_container = new_container_tag
		placed_index = -1
	# Case 4: Default same-tier draw pool -> place in target's old slot
	else:
		data_owner.add_instance(new_instance, target_loc.container, target_loc.index)
		placed_container = target_loc.container
		placed_index = target_loc.index

	# If the result is a UNIT, equip parent items onto it using atomic equip
	if result_def.category == &"UNIT":
		var max_slots = new_instance.equipped_item_uuids.size()
		for i in range(min(all_parent_items.size(), max_slots)):
			var it: GachaBallInstance = all_parent_items[i]
			if not is_instance_valid(it):
				continue
			data_owner.equip_item(it.ball_uuid, new_instance.ball_uuid, i)

	# (removals were performed earlier for all non-same-unit item merges)

	# Clear selection at the end for UX consistency
	SignalBus.emit_signal("selection_clear_requested")

# --- Single-Responsibility Helpers ---

func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance, target_item_slot: int) -> void:
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): return

	# If the item was previously equipped on another unit, unequip its bonus from that unit
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		var data_owner = _get_data_owner()
		if is_instance_valid(data_owner):
			var prev_unit: GachaBallInstance = data_owner.get_all_instances().get(item_instance.equipped_on_uuid)
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
	if source_loc and source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		return target_container_name == C.CONTAINER_EQUIPPED_ITEM and target_loc.unit_uuid == source_loc.unit_uuid

	# 2. If the target is an equipped_item container, only allow equipping
	#    from ItemInventory (Rule I3). All actual equipping is handled in the
	#    early equip path; general placement into equipped_item is otherwise illegal.
	if target_container_name == C.CONTAINER_EQUIPPED_ITEM:
		return source_loc.container == &"ItemInventory"


	if target_container_name.begins_with("RunInventoryT"):
		var container_tier = target_container_name.substr(len("RunInventoryT")).to_int()
		# Definitions without 'tier' (e.g., TrinketDefinition) are not allowed in tiered inventory containers
		if not ("tier" in def) or def.tier != container_tier:
			return false
	if target_container_name.begins_with("BattleInventoryT"):
		var container_tier_b = target_container_name.substr(len("BattleInventoryT")).to_int()
		# Definitions without 'tier' (e.g., TrinketDefinition) are not allowed in tiered inventory containers
		if not ("tier" in def) or def.tier != container_tier_b:
			return false

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

func _emit_data_changed_signal() -> void:
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
		if location.container == C.CONTAINER_EQUIPPED_ITEM:
			continue
			
		var container = data_owner.get_container(location.container)
		if not is_instance_valid(container):
			continue
			
		if container.get_uuid(location.index) != instance_uuid:
			push_error("State inconsistency detected: Instance %s location mismatch" % instance_uuid)
			return false
	
	return true

func _atomic_move_instance(instance: GachaBallInstance, from_loc: LocationIdentifier, to_loc: LocationIdentifier) -> void:
	"""Performs an atomic move using centralized atomic APIs"""
	var owner = _get_data_owner()
	if not is_instance_valid(owner):
		return
	owner.move_instance(from_loc, to_loc)
	# Optional extra validation (atomic APIs already validate in debug builds)
	if OS.is_debug_build():
		_validate_state_consistency()
