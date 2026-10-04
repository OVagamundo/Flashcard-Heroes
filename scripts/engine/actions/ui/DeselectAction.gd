# res://scripts/engine/actions/ui/DeselectAction.gd
class_name DeselectAction
extends GameAction

func _init() -> void:
	super._init(&"DeselectAction")

func validate() -> bool:
	return true

func execute() -> void:
	if is_instance_valid(GlobalInteractionRouter):
		GlobalInteractionRouter.apply_deselect_entity()

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
