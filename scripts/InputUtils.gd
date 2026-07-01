class_name InputUtils
extends RefCounted

const TOUCH_LONG_PRESS_SEC: float = 0.32
const TOUCH_DRAG_THRESHOLD_PX: float = 24.0


static func prefers_touch_input() -> bool:
	var os_name := OS.get_name()
	return OS.has_feature("mobile") or os_name == "Android" or os_name == "iOS"


static func is_mouse_pointer_event(event: InputEvent) -> bool:
	return event is InputEventMouseButton or event is InputEventMouseMotion


static func should_ignore_mouse_pointer_event(event: InputEvent) -> bool:
	return prefers_touch_input() and is_mouse_pointer_event(event)


static func is_primary_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton and not should_ignore_mouse_pointer_event(event) and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click: return false
		return true
	if event is InputEventScreenTouch and event.pressed:
		if event.double_tap: return false
		return true
	return false


static func is_primary_pointer_release(event: InputEvent) -> bool:
	return ((event is InputEventMouseButton and not should_ignore_mouse_pointer_event(event) and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed))


static func is_primary_pointer_motion(event: InputEvent) -> bool:
	return (event is InputEventMouseMotion and not should_ignore_mouse_pointer_event(event)) or event is InputEventScreenDrag


static func is_touch_pointer_event(event: InputEvent) -> bool:
	return event is InputEventScreenTouch or event is InputEventScreenDrag


static func get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position
	if event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO
