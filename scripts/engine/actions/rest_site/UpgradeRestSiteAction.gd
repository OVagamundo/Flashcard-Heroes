extends GameAction
class_name UpgradeRestSiteAction

var prize_index: int

func _init(p_prize_index: int) -> void:
	prize_index = p_prize_index

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	# Because we are removing defensive code, we trust the UI to send the right indices
	# To make this fully deterministic headless, we'd need a robust Node state payload.
	# For now, this is a proxy action to wrap UI state.
	pass

func _trigger_animations() -> void:
	var rest_site = GameManager._active_main_node._current_content_node
		
	var cb = func():
		_perform_mutation()
		finish_visuals()
		
	_run_upgrade_anim(rest_site, cb)

func _run_upgrade_anim(rest_site: Node, cb: Callable) -> void:
	if rest_site.has_method("_apply_prize"):
		await rest_site._apply_prize(prize_index)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "UpgradeRestSiteAction",
		"prize_index": prize_index
	}
