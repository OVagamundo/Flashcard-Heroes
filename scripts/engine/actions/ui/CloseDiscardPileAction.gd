# res://scripts/engine/actions/ui/CloseDiscardPileAction.gd
class_name CloseDiscardPileAction
extends GameAction

func _init() -> void:
	super._init(&"CloseDiscardPileAction")

func is_meta_action() -> bool:
	return true

func validate() -> bool:
	if not is_instance_valid(WindowManager):
		return false
	if WindowManager.has_method("is_discard_pile_window_open"):
		return WindowManager.is_discard_pile_window_open()
	return true

func execute() -> void:
	if is_instance_valid(WindowManager):
		WindowManager.close_discard_pile_window()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
