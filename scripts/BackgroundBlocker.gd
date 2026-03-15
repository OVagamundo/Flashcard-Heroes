# res://scripts/BackgroundBlocker.gd
class_name BackgroundBlocker
extends ColorRect

const InputUtils = preload("res://scripts/InputUtils.gd")

## A full-screen, semi-transparent layer that captures all mouse input
## behind a modal window and emits a signal when clicked.



func _gui_input(event: InputEvent) -> void:
	# If the blocker receives any mouse button press, it means the user
	# clicked outside the modal window that is on top of it.
	if InputUtils.is_primary_pointer_press(event):
		SignalBus.emit_signal("background_clicked")
		# Consume the event to prevent it from propagating further.
		get_viewport().set_input_as_handled()
		if InputUtils.is_touch_pointer_event(event):
			accept_event()
