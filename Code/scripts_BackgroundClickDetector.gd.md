<!-- Original: scripts/BackgroundClickDetector.gd -->

```gdscript
extends ColorRect

# This control sits at the back of a scene. If a click reaches it,
# it means the user clicked on the "empty" background area.
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Emit a clear, global signal indicating the user's intent.
		EventBus.emit_signal("global_background_clicked")
		# Consume the input to prevent any further processing.
		get_viewport().set_input_as_handled()

```