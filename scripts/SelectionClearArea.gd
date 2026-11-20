extends Control

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _gui_input(event) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Close any open inspection windows (Rule W4 - Global Close)
		if WindowManager.is_any_inspection_window_open():
			ActionQueue.request(CloseInspectionAction.new(true))
		else:
			WindowManager.close_all_inspection_windows(true)
		# Also clear selection if an entity is currently selected
		if GlobalInteractionRouter.get_current_selection() != null:
			ActionQueue.request(DeselectAction.new())
		# Do NOT call set_input_as_handled(), so events propagate to UI above
