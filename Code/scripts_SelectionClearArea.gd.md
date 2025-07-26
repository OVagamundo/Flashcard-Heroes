<!-- Original: scripts/SelectionClearArea.gd -->

```gdscript
extends Control

func _ready():
	mouse_filter = MOUSE_FILTER_PASS

func _gui_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		EventBus.emit_signal("selection_clear_requested")
		# Do NOT call set_input_as_handled(), so events propagate to UI above 
```