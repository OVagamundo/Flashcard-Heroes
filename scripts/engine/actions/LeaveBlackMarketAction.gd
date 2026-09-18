# res://scripts/engine/actions/LeaveBlackMarketAction.gd
class_name LeaveBlackMarketAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveBlackMarketAction")

func validate() -> bool:
	return true

func execute() -> void:
	var bm = Engine.get_main_loop().root.find_child("BlackMarket", true, false)
	if is_instance_valid(bm) and not ActionQueue.is_headless_mode() and bm.has_method("execute_leave_visuals"):
		bm.execute_leave_visuals()
	else:
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
