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
	var all_instances_db = _get_current_instance_db()
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
	if _is_valid_placement(source_instance, target_loc) and \
	   _is_valid_placement(target_instance, source_loc):
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
	var instance = _get_instance_at_location(source_loc)
	_set_instance_at_location(source_loc, null)
	_set_instance_at_location(target_loc, instance)
	_emit_data_changed_signal()

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier):
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	_set_instance_at_location(source_loc, target_instance)
	_set_instance_at_location(target_loc, source_instance)
	_emit_data_changed_signal()

func _equip_item(item_loc: LocationIdentifier, unit_loc: LocationIdentifier):
	var item_instance = _get_instance_at_location(item_loc)
	var unit_instance = _get_instance_at_location(unit_loc)
	var unit_def = unit_instance.get_definition()

	var empty_slot_idx = -1
	for i in range(unit_def.item_slot_count):
		if unit_instance.get_equipped_item_uuid(i).is_empty():
			empty_slot_idx = i
			break
	
	if empty_slot_idx == -1:
		_handle_invalid_action(WindowManager.find_view_by_location(item_loc))
		return

	_set_instance_at_location(item_loc, null)
	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = empty_slot_idx
	unit_instance.equipped_item_uuids[empty_slot_idx] = item_instance.ball_uuid

	EventBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)
	_emit_data_changed_signal()

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName):
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	var all_instances_db = _get_current_instance_db()

	var recipe: MergeRecipe = Database.recipes.get(recipe_id)
	if not is_instance_valid(recipe):
		printerr("InventoryManager: Merge failed, invalid recipe_id received: ", recipe_id)
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	var result_def = Database.get_definition(recipe.result_id)
	if not is_instance_valid(result_def):
		printerr("InventoryManager: Merge failed, could not find result definition: ", recipe.result_id)
		_handle_invalid_action(WindowManager.find_view_by_location(source_loc))
		return

	# --- Create the new instance and handle item inheritance ---
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

	# --- NEW: Robust, Context-Aware Placement Logic ---
	# This is the definitive fix that handles all merge contexts correctly.

	# First, always clear the source ingredient's slot.
	_set_instance_at_location(source_loc, null)

	var is_inventory_merge = source_loc.container.begins_with("RunInventoryT") or source_loc.container.begins_with("BattleInventoryT")

	if is_inventory_merge:
		# This is a "crafting" action in an inventory grid.
		if new_instance.get_definition().tier == target_loc.tier:
			# Case 1: Same-tier merge (e.g., T1+T1->T1). Result replaces the target.
			_set_instance_at_location(target_loc, new_instance)
		else:
			# Case 2: Tier-up merge (e.g., T2+T2->T3). Result goes to a new slot.
			# The target slot becomes empty.
			_set_instance_at_location(target_loc, null)
			
			var new_loc: LocationIdentifier
			if GameManager.is_in_battle:
				new_loc = _find_empty_slot_for_instance_battle(new_instance)
			else:
				new_loc = _find_empty_slot_for_instance(new_instance)
			
			if is_instance_valid(new_loc):
				_set_instance_at_location(new_loc, new_instance)
			else:
				# This is the failsafe for the error you saw.
				printerr("InventoryManager: No empty slot found for merge result %s" % new_instance.definition_id)
				if GameManager.is_in_battle:
					var bm = get_tree().get_first_node_in_group("battle_manager")
					bm._move_instance_to_discard(new_instance)
	else:
		# This is a "tactical" action on the battle board. Result always replaces the target.
		_set_instance_at_location(target_loc, new_instance)

	# --- Cleanup and Signals ---
	all_instances_db.erase(source_instance.ball_uuid)
	all_instances_db.erase(target_instance.ball_uuid)

	EventBus.emit_signal("unit_inventory_changed", new_instance.ball_uuid)
	_emit_data_changed_signal()

# --- Helpers ---

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

# Find first empty slot for given instance in RUN inventory grids.
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

func _is_valid_placement(instance: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	var def = instance.get_definition()
	var target_container = target_loc.container
	var target_instance = _get_instance_at_location(target_loc)

	# Check tier compatibility first for all placements
	if target_container.begins_with("RunInventoryT"):
		var container_tier = target_container.substr(len("RunInventoryT")).to_int()
		if def.tier != container_tier: return false
	if target_container.begins_with("BattleInventoryT"):
		var container_tier_b = target_container.substr(len("BattleInventoryT")).to_int()
		if def.tier != container_tier_b: return false

	# Check if target is empty slot (for move operations)
	if not is_instance_valid(target_instance):
		pass

	# Check category compatibility
	if target_container in [&"PlayerLineup", &"PlayerBench"] and def.category == &"ITEM":
		return false
	if target_container == &"ItemInventory" and def.category == &"UNIT":
		return false

	return true

func _get_instance_at_location(loc: LocationIdentifier) -> GachaBallInstance:
	if not is_instance_valid(loc): return null
	var db = _get_current_instance_db()
	var container = _get_container_by_loc(loc)
	if is_instance_valid(container):
		var uuid = container.get_uuid(loc.index)
		return db.get(uuid)
	return null

func _set_instance_at_location(loc: LocationIdentifier, instance: GachaBallInstance):
	if not is_instance_valid(loc): return
	var uuid_to_set = "" if not is_instance_valid(instance) else instance.ball_uuid
	var container = _get_container_by_loc(loc)
	if is_instance_valid(container):
		container.set_uuid(loc.index, uuid_to_set)
	if is_instance_valid(instance):
		instance.location_container_tag = loc.container
		instance.location_slot_index = loc.index

func _get_container_by_loc(loc: LocationIdentifier) -> DataContainer:
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		return bm.get_container(loc.container) if is_instance_valid(bm) else null
	else:
		return GameManager.run_state.get_container(loc.container) if is_instance_valid(GameManager.run_state) else null

func _get_current_instance_db() -> Dictionary:
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		return bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _emit_data_changed_signal():
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	EventBus.emit_signal(signal_name)

func _handle_invalid_action(source_view: Control):
	if is_instance_valid(source_view):
		EventBus.emit_signal("invalid_action_triggered", source_view)
	InteractionManager.end_drag(false)
	InteractionManager.clear_selection()
