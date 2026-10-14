class_name InspectionTrigger
extends RefCounted

const InputUtils = preload("res://scripts/InputUtils.gd")
const InspectionPeekController = preload("res://scripts/ui/InspectionPeekController.gd")

var _owner_view: Control
var _request_callable: Callable
var _touch_press_pos: Vector2 = Vector2.ZERO
var _is_pressed: bool = false

func setup(view: Control, request_callable: Callable) -> void:
	_owner_view = view
	_request_callable = request_callable

func _get_controller() -> InspectionPeekController:
	if is_instance_valid(GlobalInteractionRouter) and GlobalInteractionRouter.has_method("get_peek_controller"):
		return GlobalInteractionRouter.get_peek_controller()
	return null

func on_mouse_entered() -> void:
	if InputUtils.prefers_touch_input():
		return
	var ctrl = _get_controller()
	if is_instance_valid(ctrl) and _request_callable.is_valid():
		var req = _request_callable.call()
		if req is Dictionary and not req.is_empty():
			ctrl.hover_enter(_owner_view, req)

func on_mouse_exited() -> void:
	if InputUtils.prefers_touch_input():
		return
	var ctrl = _get_controller()
	if is_instance_valid(ctrl):
		ctrl.hover_exit(_owner_view)

func on_pointer_pressed(pos: Vector2) -> void:
	_is_pressed = true
	_touch_press_pos = pos
	var ctrl = _get_controller()
	if is_instance_valid(ctrl) and _request_callable.is_valid():
		var req = _request_callable.call()
		if req is Dictionary and not req.is_empty():
			ctrl.press_start(_owner_view, req)

## Returns true if peek was active and handled release (suppressing click/tap)
func on_pointer_released() -> bool:
	_is_pressed = false
	var ctrl = _get_controller()
	if is_instance_valid(ctrl):
		return ctrl.press_end(_owner_view)
	return false

func on_motion(pos: Vector2) -> void:
	if _is_pressed and pos.distance_to(_touch_press_pos) > InputUtils.TOUCH_DRAG_THRESHOLD_PX:
		_is_pressed = false
		var ctrl = _get_controller()
		if is_instance_valid(ctrl):
			ctrl.cancel(_owner_view)

func cancel() -> void:
	_is_pressed = false
	var ctrl = _get_controller()
	if is_instance_valid(ctrl):
		ctrl.cancel(_owner_view)
