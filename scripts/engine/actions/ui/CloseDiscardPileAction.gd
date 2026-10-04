# res://scripts/engine/actions/ui/CloseDiscardPileAction.gd
class_name CloseDiscardPileAction
extends GameAction

func _init() -> void:
	super._init(&"CloseDiscardPileAction")

func validate() -> bool:
	return is_instance_valid(WindowManager)

func execute() -> void:
	if is_instance_valid(WindowManager):
		WindowManager.close_all_inspection_windows()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
