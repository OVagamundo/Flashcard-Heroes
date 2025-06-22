# res://scripts/DropTarget.gd
extends PanelContainer

# This script makes a simple PanelContainer a valid drop target for a GachaBallView.

func _can_drop_data(_at_position, data) -> bool:
	# It can only accept drops from a GachaBallView.
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	
	# When a view is dropped here, its original drag preview is cancelled
	# and it becomes visible again. We need to tell the InteractionManager
	# that the drag is over.
	source_view.visible = true
	InteractionManager.is_drag_active = false
	
	# The BattleManager listens for this signal and will handle the move.
	EventBus.emit_signal("inventory_action_requested", source_view, self)
