# res://scripts/engine/actions/CloseTrainingPopupAction.gd
class_name CloseTrainingPopupAction
extends GameAction

func _init() -> void:
	super._init(&"CloseTrainingPopupAction")

func validate() -> bool:
	return true

func execute() -> void:
	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	if is_instance_valid(utg) and utg.has_method("_close_training_popup"):
		utg._close_training_popup()
	elif is_instance_valid(GameManager.run_state):
		GameManager.run_state.is_training_active = false

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
