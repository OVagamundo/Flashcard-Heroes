extends Control

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _gui_input(event) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Close any open inspection windows (Rule W4 - Global Close)
		if is_instance_valid(ActionQueue) and WindowManager.is_any_inspection_window_open():
			ActionQueue.request(CloseInspectionAction.new(true))
		elif is_instance_valid(WindowManager):
			WindowManager.close_all_inspection_windows()
		# Also clear selection if an entity is currently selected
		if is_instance_valid(GlobalInteractionRouter) and GlobalInteractionRouter.get_current_selection() != null:
			if is_instance_valid(ActionQueue):
				ActionQueue.request(DeselectAction.new())
			else:
				SignalBus.emit_signal("selection_clear_requested")
		# Do NOT call set_input_as_handled(), so events propagate to UI above
