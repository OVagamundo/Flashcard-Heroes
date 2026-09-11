extends GameAction
class_name SellRewardAction

var reward_loc: LocationIdentifier
var start_pos: Vector2
var gold_amount: int
var elite_mode: bool

func _init(p_reward_loc: LocationIdentifier, p_start_pos: Vector2, p_gold_amount: int, p_elite_mode: bool = false) -> void:
	reward_loc = p_reward_loc
	start_pos = p_start_pos
	gold_amount = p_gold_amount
	elite_mode = p_elite_mode

func is_valid() -> bool:
	if reward_loc == null or reward_loc.container != &"Rewards":
		return false
	
	var instance = GameManager._temporary_reward_container.get_uuid(reward_loc.index)
	if instance.is_empty():
		return false
	
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	SignalBus.emit_signal("selection_clear_requested")
	SignalBus.emit_signal("reward_chosen", {"type": "gold", "amount": gold_amount})
	if elite_mode:
		SignalBus.emit_signal("reward_chosen", {"type": "elite_choice_complete"})

func _trigger_animations() -> void:
	var reward_scene = GameManager.get_tree().get_first_node_in_group("reward_scene")
	if reward_scene == null:
		_perform_mutation()
		finish_visuals()
		return
	
	# Clear slot visually
	if reward_scene.has_method("_clear_prize_slot"):
		reward_scene._clear_prize_slot(reward_loc.index)
	elif reward_scene.has_method("_clear_reward_slot"):
		reward_scene._clear_reward_slot(reward_loc.index)
		
	var mn = GameManager._active_main_node
	if mn != null:
		if mn.has_method("hide_reward_drop_zones"):
			mn.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open() and mn.has_method("show_action_instruction"):
			mn.show_action_instruction(tr("ui.reward_instruction"))
	
	var cb = func():
		_perform_mutation()
		if reward_scene.has_method("_complete_choice"):
			reward_scene._complete_choice()
		finish_visuals()
		
	_run_sell_anim(reward_scene, cb)

func _run_sell_anim(reward_scene: Node, cb: Callable) -> void:
	if reward_scene.has_method("_animate_gold_receive"):
		# Elite and Normal have slightly different viewport mapping which is handled inside the functions or passed in.
		# Elite maps start_pos to VFX viewport before calling this! 
		# If the caller didn't, we might have an issue, but we'll assume start_pos is correctly projected.
		await reward_scene._animate_gold_receive(gold_amount, start_pos)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "SellRewardAction",
		"reward_loc": reward_loc.to_dict(),
		"start_pos": {"x": start_pos.x, "y": start_pos.y},
		"gold_amount": gold_amount,
		"elite_mode": elite_mode
	}
