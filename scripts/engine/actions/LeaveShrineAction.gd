# res://scripts/engine/actions/LeaveShrineAction.gd
class_name LeaveShrineAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveShrineAction")

func validate() -> bool:
	return true

func execute() -> void:
	var shrine = Engine.get_main_loop().root.find_child("Shrine", true, false)
	if is_instance_valid(shrine) and not ActionQueue.is_headless_mode() and shrine.has_method("execute_leave_visuals"):
		shrine.execute_leave_visuals()
	else:
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
