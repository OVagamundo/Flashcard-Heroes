# res://scripts/engine/actions/LeaveTrainingAction.gd
class_name LeaveTrainingAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveTrainingAction")

func validate() -> bool:
	return true

func execute() -> void:
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.reset_room_tokens()
		GameManager.run_state.is_training_active = false
	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	if is_instance_valid(utg) and not ActionQueue.is_headless_mode() and utg.has_method("execute_leave_visuals"):
		utg.execute_leave_visuals()
	else:
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
