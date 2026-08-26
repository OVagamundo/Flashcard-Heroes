extends GameAction
class_name LeaveMergeEncounterAction

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
	SignalBus.emit_signal("path_choice_scene_requested")

func _trigger_animations() -> void:
	var main_node = GameManager._active_main_node
	if main_node != null:
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
	
	_perform_mutation()
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveMergeEncounterAction"
	}
