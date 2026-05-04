# scripts/utils/DropZone.gd
extends PanelContainer

## A simple script to make programmatic panels act as Godot drop targets.
## This ensures is_drag_successful() returns true and triggers GIR.end_drag(true).

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return true

func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	# Inform GIR that the drag was handled by a drop zone
	if GlobalInteractionRouter:
		GlobalInteractionRouter.end_drag(true)
