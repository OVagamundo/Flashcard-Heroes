extends Control

signal merge_pressed
signal swap_pressed

func _on_merge_pressed():
	merge_pressed.emit()
	queue_free()

func _on_swap_pressed():
	swap_pressed.emit()
	queue_free()

func _on_background_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		queue_free()
