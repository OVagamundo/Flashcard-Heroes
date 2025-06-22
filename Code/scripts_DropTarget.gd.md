<!-- Original: scripts/DropTarget.gd -->

```gdscript
extends PanelContainer

# This script makes a simple PanelContainer a valid drop target for a GachaBallView.
# It handles both drag-and-drop and click-and-click interactions.

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

func _gui_input(event: InputEvent):
	# Handle click-and-click interaction.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Check if a view is currently selected in the InteractionManager.
		var selected_view = InteractionManager.get_selected_view()
		if is_instance_valid(selected_view):
			# If a view is selected, this empty slot is the target of the action.
			EventBus.emit_signal("inventory_action_requested", selected_view, self)
			get_viewport().set_input_as_handled()

```