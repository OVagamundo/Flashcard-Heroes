extends GameAction
class_name LeaveTrainingAction

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
	if is_instance_valid(main_node) and main_node.has_node("%UnitTrainingGround"):
		var training_node = main_node.get_node("%UnitTrainingGround")
		training_node._on_leave_training_mutation_complete()
			
	_perform_mutation()
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveTrainingAction"
	}
