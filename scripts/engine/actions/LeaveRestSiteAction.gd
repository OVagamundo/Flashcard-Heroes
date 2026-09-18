# res://scripts/engine/actions/LeaveRestSiteAction.gd
class_name LeaveRestSiteAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveRestSiteAction")

func validate() -> bool:
	return true

func execute() -> void:
	var rest_site = Engine.get_main_loop().root.find_child("RestSite", true, false)
	if is_instance_valid(rest_site) and not ActionQueue.is_headless_mode() and rest_site.has_method("execute_leave_visuals"):
		rest_site.execute_leave_visuals()
	else:
		GameManager.auto_claim_all_rest_site_prizes()
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.reset_room_tokens()
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
