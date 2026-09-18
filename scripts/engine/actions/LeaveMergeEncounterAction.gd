# res://scripts/engine/actions/LeaveMergeEncounterAction.gd
class_name LeaveMergeEncounterAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveMergeEncounterAction")

func validate() -> bool:
	return true

func execute() -> void:
	var me = Engine.get_main_loop().root.find_child("MergeEncounter", true, false)
	if is_instance_valid(me) and not ActionQueue.is_headless_mode() and me.has_method("execute_leave_visuals"):
		me.execute_leave_visuals()
	else:
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
