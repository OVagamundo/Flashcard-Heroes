# res://scripts/InventoryManager.gd
extends Node

var _pending_action: Dictionary = {}

func _ready():
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested, CONNECT_DEFERRED)
	EventBus.choice_made.connect(_on_choice_made)

func _on_inventory_action_requested(source_view: Control, target_view: Control):
	var source_data: GachaBallInstance = source_view.get_instance_data()
	
	if target_view is PanelContainer and target_view.get_child_count() == 0:
		_handle_move(source_view, target_view)
		return

	if not target_view is GachaBallView:
		trigger_invalid_action_feedback(source_view)
		return
		
	var target_data: GachaBallInstance = target_view.get_instance_data()
	if not source_data or not target_data:
		trigger_invalid_action_feedback(source_view)
		return

	var source_def = Database.units.get(source_data.definition_id, Database.items.get(source_data.definition_id))
	var target_def = Database.units.get(target_data.definition_id, Database.items.get(target_data.definition_id))

	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		_handle_equip(source_data, target_data)
		return
	
	if source_def.category == target_def.category:
		var recipe = MergeManager.find_recipe(source_data.definition_id, target_data.definition_id)
		if recipe:
			_pending_action = {"source_data": source_data, "target_data": target_data}
			WindowManager.open_dialog_window(&"ChoicePrompt")
		else:
			_handle_swap(source_data, target_data)
	else:
		trigger_invalid_action_feedback(source_view)

func _on_choice_made(choice: StringName):
	var source_data = _pending_action.get("source_data")
	var target_data = _pending_action.get("target_data")
	if not is_instance_valid(source_data) or not is_instance_valid(target_data):
		_pending_action.clear()
		return
		
	if choice == &"MERGE": _handle_merge(source_data, target_data)
	elif choice == &"SWAP": _handle_swap(source_data, target_data)
	_pending_action.clear()

# BUGFIX: All handlers now only operate on data and emit signals. No view manipulation.
func _handle_merge(source_data: GachaBallInstance, target_data: GachaBallInstance):
	var inventory_context = _get_current_inventory_context()
	var merged_instance = MergeManager.attempt_merge(source_data, target_data, inventory_context.inventory)
	if merged_instance:
		EventBus.emit_signal(inventory_context.changed_signal)
	else:
		# This should be rare, but handle it.
		printerr("InventoryManager: Merge failed unexpectedly after successful recipe check.")

func _handle_swap(inst_a: GachaBallInstance, inst_b: GachaBallInstance):
	var inventory_context = _get_current_inventory_context()
	var def_a = Database.units.get(inst_a.definition_id, Database.items.get(inst_a.definition_id))
	var def_b = Database.units.get(inst_b.definition_id, Database.items.get(inst_b.definition_id))

	if def_a.category != def_b.category or def_a.tier != def_b.tier:
		# Cannot get view from data, so we can't trigger feedback here.
		# This check is a safeguard; UI should prevent this.
		return

	var tier = def_a.tier
	var inventory = inventory_context.inventory
	if not inventory.has(tier): return
	var idx_a = inventory[tier].find(inst_a)
	var idx_b = inventory[tier].find(inst_b)

	if idx_a == -1 or idx_b == -1: return

	inventory[tier][idx_a] = inst_b
	inventory[tier][idx_b] = inst_a
	EventBus.emit_signal(inventory_context.changed_signal)

func _handle_move(source_view: GachaBallView, target_slot: PanelContainer):
	source_view.get_parent().remove_child(source_view)
	target_slot.add_child(source_view)

func _handle_equip(item_data: GachaBallInstance, unit_data: GachaBallInstance):
	var empty_slot_idx = unit_data.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_data.equipped_item_uuids[empty_slot_idx] = item_data.ball_uuid
		
		var inventory_context = _get_current_inventory_context()
		# The item instance itself must be removed from the inventory list.
		var item_def = Database.items.get(item_data.definition_id)
		if item_def and inventory_context.inventory.has(item_def.tier):
			inventory_context.inventory[item_def.tier].erase(item_data)
			
		EventBus.emit_signal(inventory_context.changed_signal)
	else:
		# Cannot get view from data, so we can't trigger feedback here.
		pass

func _get_current_inventory_context() -> Dictionary:
	if GameManager.is_in_battle:
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		return {
			"inventory": battle_manager.get_battle_inventory(),
			"changed_signal": "battle_inventory_changed"
		}
	else:
		return {
			"inventory": GameManager.run_state.run_inventory,
			"changed_signal": "run_inventory_changed"
		}

func trigger_invalid_action_feedback(view: Control):
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
