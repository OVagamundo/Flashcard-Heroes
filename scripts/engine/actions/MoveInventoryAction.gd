extends GameAction
class_name MoveInventoryAction

var source_loc: LocationIdentifier
var target_loc: LocationIdentifier

# Internal resolved state
var _action_type: int = ACTION_INVALID
var _recipe_id: StringName = &""
var _target_instance_uuid: String = ""
var _source_instance_uuid: String = ""

enum {
	ACTION_INVALID,
	ACTION_BOUNCE,
	ACTION_MOVE,
	ACTION_SWAP,
	ACTION_EQUIP_UNIT,
	ACTION_EQUIP_SLOT,
	ACTION_MERGE,
	ACTION_CONSUMABLE
}

func _init(p_source_loc: LocationIdentifier, p_target_loc: LocationIdentifier) -> void:
	source_loc = p_source_loc
	target_loc = p_target_loc

func is_valid() -> bool:
	if source_loc == null or target_loc == null:
		return false

	var source_instance = GameManager.get_instance_from_location(source_loc)
	var target_instance = GameManager.get_instance_from_location(target_loc)

	if source_instance == null:
		return false

	_source_instance_uuid = source_instance.ball_uuid

	# Case 1: Same-slot drop
	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		_action_type = ACTION_BOUNCE
		return true

	var sdef = source_instance.get_definition()
	var target_def = target_instance.get_definition() if target_instance != null else null

	# Case 2: Consumable usage
	if sdef.category == &"CONSUMABLE" and target_instance != null:
		if target_def.category == &"UNIT":
			_action_type = ACTION_CONSUMABLE
			_target_instance_uuid = target_instance.ball_uuid
			return true

	# Case 3: Equipping ITEM directly onto UNIT
	if sdef.category == &"ITEM" and target_instance != null:
		if target_def.category == &"UNIT":
			var target_group = GlobalInteractionRouter.get_context_group(target_loc.container)
			if target_group != &"InventoryGrid":
				_action_type = ACTION_EQUIP_UNIT
				_target_instance_uuid = target_instance.ball_uuid
				return true

	# Case 4: Equipping ITEM into specific equipped_item slot
	if sdef.category == &"ITEM" and target_loc.container == "equipped_item":
		var data_owner = _get_data_owner()
		var parent_unit = data_owner.get_all_instances().get(target_loc.unit_uuid)
		var slot_is_empty = true
		if target_loc.index < parent_unit.equipped_item_uuids.size():
			slot_is_empty = parent_unit.equipped_item_uuids[target_loc.index].is_empty()
		if slot_is_empty:
			_action_type = ACTION_EQUIP_SLOT
			return true

	# Case 5: Target empty, check valid move
	if target_instance == null:
		if InventoryManager.is_valid_placement(source_instance, target_loc):
			_action_type = ACTION_MOVE
			return true
		else:
			return false

	# Case 6: Possible Merge
	var data_owner = _get_data_owner()
	var all_instances_db = data_owner.get_all_instances()
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)
	if recipe != null:
		_action_type = ACTION_MERGE
		_recipe_id = recipe.id
		return true

	# Case 7: Possible Swap
	if InventoryManager.is_valid_placement(source_instance, target_loc) and InventoryManager.is_valid_placement(target_instance, source_loc):
		_action_type = ACTION_SWAP
		_target_instance_uuid = target_instance.ball_uuid
		return true

	return false

func execute() -> void:
	match _action_type:
		ACTION_BOUNCE:
			SignalBus.emit_signal("inventory_action_completed", [_source_instance_uuid])
			GlobalInteractionRouter.end_drag(false)
		ACTION_MOVE:
			var data_owner = _get_data_owner()
			# Move logic handles equipping into slot
			if target_loc.container == "equipped_item":
				var parent_unit = data_owner.get_all_instances().get(target_loc.unit_uuid)
				data_owner.equip_item(_source_instance_uuid, parent_unit.ball_uuid, target_loc.index)
				SignalBus.emit_signal("selection_clear_requested")
				SignalBus.emit_signal("inventory_action_completed", [parent_unit.ball_uuid])
				GlobalInteractionRouter.end_drag(true)
				return
			
			data_owner.move_instance(source_loc, target_loc)
			SignalBus.emit_signal("selection_clear_requested")
			SignalBus.emit_signal.call_deferred("inventory_action_completed", [_source_instance_uuid])
			GlobalInteractionRouter.end_drag(true)
		ACTION_SWAP:
			var data_owner = _get_data_owner()
			data_owner.swap_instances(source_loc, target_loc)
			SignalBus.emit_signal("selection_clear_requested")
			SignalBus.emit_signal.call_deferred("inventory_action_completed", [_source_instance_uuid, _target_instance_uuid])
			GlobalInteractionRouter.end_drag(true)
		ACTION_EQUIP_UNIT:
			var data_owner = _get_data_owner()
			data_owner.equip_item(_source_instance_uuid, _target_instance_uuid, -1)
			GlobalInteractionRouter.end_drag(true)
			SignalBus.emit_signal("inventory_action_completed", [_target_instance_uuid])
		ACTION_EQUIP_SLOT:
			var data_owner = _get_data_owner()
			var parent_unit = data_owner.get_all_instances().get(target_loc.unit_uuid)
			data_owner.equip_item(_source_instance_uuid, parent_unit.ball_uuid, target_loc.index)
			GlobalInteractionRouter.end_drag(true)
			SignalBus.emit_signal("inventory_action_completed", [parent_unit.ball_uuid])
		ACTION_MERGE:
			# Merge prompts the choice window. This isn't purely deterministic yet,
			# as it requires further user input. A real implementation would split this
			# into a prompt, and a separate `ConfirmMergeAction`.
			# For now, replicate legacy flow but driven by ActionQueue.
			var context: Dictionary = {
				"source_location": source_loc, 
				"target_location": target_loc, 
				"recipe_id": _recipe_id,
				# "result_id" is needed, but for simplicity we rely on ChoiceWindow resolving it or MergeManager.
			}
			# Fetch recipe again to get result_id safely
			var data_owner = _get_data_owner()
			var source_instance = GameManager.get_instance_from_location(source_loc)
			var target_instance = GameManager.get_instance_from_location(target_loc)
			var all_instances_db = data_owner.get_all_instances()
			var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)
			context["result_id"] = recipe.result_id
			
			var source_view = GlobalInteractionRouter.get_drag_source_view()
			if not is_instance_valid(source_view):
				var slot_view = WindowManager.find_view_for_location(source_loc)
				if is_instance_valid(slot_view):
					for child in slot_view.get_children():
						if child.has_method("play_landing_bounce"):
							source_view = child
							break
							
			if is_instance_valid(source_view):
				source_view.visible = false
				context["source_view_id"] = source_view.get_instance_id()
			else:
				context["source_view_id"] = -1
			GlobalInteractionRouter.end_drag(true)
			WindowManager.open_choice_window(context)
		ACTION_CONSUMABLE:
			# Similarly, consumable usage executes effects which may queue animations.
			var source_instance = GameManager.get_instance_from_location(source_loc)
			var target_instance = GameManager.get_instance_from_location(target_loc)
			InventoryManager._use_consumable(source_instance, target_instance)
			
	if not yields_for_visuals():
		finish_visuals()

func yields_for_visuals() -> bool:
	# In Phase 1, most basic inventory actions don't have explicit visual yielding contracts yet,
	# except maybe consumable usage. For now, assume false so queue unblocks instantly after processing.
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "MoveInventoryAction",
		"source_loc": source_loc.to_dict() if is_instance_valid(source_loc) and source_loc.has_method("to_dict") else {},
		"target_loc": target_loc.to_dict() if is_instance_valid(target_loc) and target_loc.has_method("to_dict") else {}
	}

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return GameManager.get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state
