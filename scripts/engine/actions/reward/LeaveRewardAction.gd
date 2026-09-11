extends GameAction
class_name LeaveRewardAction

var elite_mode: bool

func _init(p_elite_mode: bool = false) -> void:
	elite_mode = p_elite_mode

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	if not elite_mode:
		for i in range(5):
			var uuid = GameManager._temporary_reward_container.get_uuid(i)
			if not uuid.is_empty():
				SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		
		SignalBus.emit_signal("gacha_tokens_changed", 0)
		SignalBus.emit_signal("gacha_tokens_visual_changed", 0)
	SignalBus.emit_signal("path_choice_scene_requested")

func _trigger_animations() -> void:
	var reward_scene = GameManager.get_tree().get_first_node_in_group("reward_scene")
	
	if reward_scene.has_node("LeaveButton"):
		var leave = reward_scene.get_node("LeaveButton")
		if leave is Button: leave.disabled = true
	
	var mn = GameManager._active_main_node
	if mn != null:
		if mn.has_method("hide_reward_drop_zones"):
			mn.hide_reward_drop_zones()

	# If it's normal reward mode, it collects all remaining prizes automatically!
	if not elite_mode and reward_scene.has_method("_run_auto_collect_sequence"):
		var cb = func():
			_perform_mutation()
			finish_visuals()
		# Start the async visual sequence. The sequence itself will NOT mutate data.
		_run_leave_sequence(reward_scene, cb)
	else:
		_perform_mutation()
		finish_visuals()

func _run_leave_sequence(reward_scene: Node, cb: Callable) -> void:
	await reward_scene._run_auto_collect_sequence()
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveRewardAction",
		"elite_mode": elite_mode
	}
