# res://scripts/engine/actions/ui/CloseInspectionAction.gd
class_name CloseInspectionAction
extends GameAction

var close_all: bool = true

func _init(p_close_all: bool = true) -> void:
	super._init(&"CloseInspectionAction")
	close_all = p_close_all

func validate() -> bool:
	if not is_instance_valid(WindowManager):
		return false
	return true

func execute() -> void:
	if is_instance_valid(WindowManager):
		if close_all:
			WindowManager.close_all_inspection_windows(true)
		else:
			WindowManager.close_top_contextual_window()
	if is_instance_valid(GlobalInteractionRouter):
		if close_all or (is_instance_valid(WindowManager) and not WindowManager.is_any_inspection_window_open()):
			GlobalInteractionRouter.set("_is_inspection_locked", false)
			GlobalInteractionRouter.set("_locked_entity_view_id", -1)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["close_all"] = close_all
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	close_all = bool(data.get("close_all", true))
