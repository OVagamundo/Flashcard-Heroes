# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action (e.g., which
## GachaBallView is currently selected).

signal drag_operation_started(source_view: Control)
signal drag_operation_ended(was_handled: bool)

var _selected_view: Control = null
var _is_drag_active: bool = false
var _drag_source_view: Control = null

func _ready() -> void:
	# BUGFIX: Removed faulty connection to 'inventory_action_requested'.
	# The selection state is managed by the functions below, making this
	# connection both incorrect and redundant.
	
	# Connect to modal and scene changes to prevent stale selections.
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)

func _unhandled_input(event: InputEvent) -> void:
	if _is_drag_active and (event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.is_pressed())):
		end_drag(false)
		get_viewport().set_input_as_handled()

func select_view(view: Control) -> void:
	if not is_instance_valid(view):
		clear_selection()
		return
		
	if _selected_view == view:
		EventBus.emit_signal("inspection_requested", view)
		clear_selection()
		return

	# A new item is being selected. Broadcast this context change so other systems (like WindowManager) can react.
	EventBus.emit_signal("selection_context_changed", view)

	if is_instance_valid(_selected_view):
		clear_selection()

	_selected_view = view
	EventBus.emit_signal("view_selected", _selected_view)
	
	# This explicit return ensures all code paths return a value, fixing the parser error.
	return

func clear_selection() -> void:
	if is_instance_valid(_selected_view):
		var previously_selected = _selected_view
		_selected_view = null
		EventBus.emit_signal("view_deselected", previously_selected)

func get_selected_view() -> Control:
	return _selected_view

func is_drag_active() -> bool:
	return _is_drag_active

func get_drag_source_view() -> Control:
	return _drag_source_view

func start_drag(source_view: Control):
	if not is_instance_valid(source_view): return
	_is_drag_active = true
	_drag_source_view = source_view
	emit_signal("drag_operation_started", source_view)
	clear_selection()

func end_drag(was_handled: bool):
	_is_drag_active = false
	emit_signal("drag_operation_ended", was_handled)

func trigger_invalid_action_feedback(view: Control) -> void:
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
