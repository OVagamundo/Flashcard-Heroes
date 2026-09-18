# res://scripts/engine/actions/LeaveShopAction.gd
class_name LeaveShopAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveShopAction")

func validate() -> bool:
	return true

func execute() -> void:
	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	if is_instance_valid(shop) and not ActionQueue.is_headless_mode() and shop.has_method("execute_leave_visuals"):
		shop.execute_leave_visuals()
	else:
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
