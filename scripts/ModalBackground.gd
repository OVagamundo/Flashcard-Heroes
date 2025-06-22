# res://scripts/ModalBackground.gd
extends ColorRect

const CLICK_MAX_TRAVEL_SQ = 10 * 10
var _mouse_down_pos: Vector2
var _is_mouse_down: bool = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_mouse_down_pos = event.position
			_is_mouse_down = true
		elif _is_mouse_down:
			_is_mouse_down = false
			# Only trigger if the mouse didn't move much between press and release
			if event.position.distance_squared_to(_mouse_down_pos) < CLICK_MAX_TRAVEL_SQ:
				# Close the modal first
				EventBus.emit_signal("close_modal_requested")
				
				# Programmatically create and inject a new click event at the same location.
				# This allows clicking "through" the modal background to interact with what's underneath.
				var press_event = InputEventMouseButton.new()
				press_event.button_index = MOUSE_BUTTON_LEFT
				press_event.pressed = true
				press_event.global_position = get_global_mouse_position()
				
				var release_event = InputEventMouseButton.new()
				release_event.button_index = MOUSE_BUTTON_LEFT
				release_event.pressed = false
				release_event.global_position = get_global_mouse_position()
				
				# Wait a tiny amount of time for the modal to close before injecting the new click.
				await get_tree().create_timer(0.01).timeout
				Input.parse_input_event(press_event)
				Input.parse_input_event(release_event)
				
				get_viewport().set_input_as_handled()
				
	elif event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		EventBus.emit_signal("close_modal_requested")
		get_viewport().set_input_as_handled()
