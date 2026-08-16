extends GameAction
class_name LeaveRestSiteAction

func _init() -> void:
	pass

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	# Same as upgrade, we trust the UI to handle the auto-apply logic in a visual context
	# since tokens are not persisted to the RunState.
	SignalBus.emit_signal("gacha_tokens_changed", 0)
	SignalBus.emit_signal("gacha_tokens_visual_changed", 0)
	SignalBus.emit_signal("path_choice_scene_requested")

func _trigger_animations() -> void:
	var rest_site = GameManager._active_main_node._current_content_node
		
	var cb = func():
		_perform_mutation()
		# Scene freeing handled natively by Main.gd
		finish_visuals()
		
	_run_leave_anim(rest_site, cb)

func _run_leave_anim(rest_site: Node, cb: Callable) -> void:
	if rest_site.has_method("_run_auto_collect_sequence"):
		await rest_site._run_auto_collect_sequence()
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveRestSiteAction"
	}
