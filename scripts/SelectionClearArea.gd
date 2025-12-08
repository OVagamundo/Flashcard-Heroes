extends Control

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS

func _gui_input(event) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		# Close any open inspection windows (Rule W4 - Global Close)
		WindowManager.close_all_inspection_windows()
		# Also clear selection
		SignalBus.emit_signal("selection_clear_requested")
		# Do NOT call set_input_as_handled(), so events propagate to UI above