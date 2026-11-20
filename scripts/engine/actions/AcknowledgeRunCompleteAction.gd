# res://scripts/engine/actions/AcknowledgeRunCompleteAction.gd
class_name AcknowledgeRunCompleteAction
extends GameAction

func _init() -> void:
	super._init(&"AcknowledgeRunCompleteAction")

func validate() -> bool:
	return true
func execute() -> void:
	ActionQueue.pause_timer()
	var popup = Engine.get_main_loop().root.find_child("RunCompletePopup", true, false)
	if is_instance_valid(popup):
		popup.queue_free()
	else:
		WindowManager._close_top_modal()
	if not GameManager.is_replay_run:
		SaveManager.clear_save()
	SignalBus.emit_signal("title_scene_requested")

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
