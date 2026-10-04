# res://scripts/engine/actions/ui/OpenDiscardPileAction.gd
class_name OpenDiscardPileAction
extends GameAction

func _init() -> void:
	super._init(&"OpenDiscardPileAction")

func validate() -> bool:
	return is_instance_valid(WindowManager) and is_instance_valid(GameManager) and GameManager.is_in_battle

func execute() -> void:
	if is_instance_valid(WindowManager) and WindowManager.has_method("open_discard_pile_window"):
		WindowManager.open_discard_pile_window()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
