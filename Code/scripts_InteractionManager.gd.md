<!-- Original: scripts/InteractionManager.gd -->

```gdscript
# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action (e.g., which
## GachaBallView is currently selected).

signal drag_operation_started(source_view: Control)
signal drag_operation_ended(was_handled: bool)

var _selected_view: Control = null
var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null # To hold grid position

func _ready() -> void:
	# Connect to modal and scene changes to prevent stale selections.
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)

func select_view(view: Control) -> void:
	if not is_instance_valid(view):
		clear_selection()
		return
		
	if _selected_view == view:
		EventBus.emit_signal("inspection_requested", view)
		clear_selection()
		return

	EventBus.emit_signal("selection_context_changed", view)

	if is_instance_valid(_selected_view):
		clear_selection()

	_selected_view = view
	EventBus.emit_signal("view_selected", _selected_view)
	
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

func start_drag(source_view: Control, placeholder: Control):
	if not is_instance_valid(source_view): return
	_is_drag_active = true
	_drag_source_view = source_view
	_drag_placeholder = placeholder
	emit_signal("drag_operation_started", source_view)
	clear_selection()

func end_drag(was_handled: bool):
	if not _is_drag_active: return
	
	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
		_drag_placeholder = null
		
	# If drag was not handled, the source view (hidden by engine) needs to be shown again.
	if not was_handled and is_instance_valid(_drag_source_view):
		_drag_source_view.visible = true
	
	_is_drag_active = false
	emit_signal("drag_operation_ended", was_handled)
	_drag_source_view = null
	emit_signal("drag_operation_ended", was_handled)
	_drag_source_view = null

	# If drag was not handled, the source view (hidden by engine) needs to be shown again.
	if not was_handled and is_instance_valid(_drag_source_view):
		_drag_source_view.visible = true
	
	_is_drag_active = false
	emit_signal("drag_operation_ended", was_handled)
	_drag_source_view = null

func trigger_invalid_action_feedback(view: Control) -> void:
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)

func cancel_active_drag() -> void:
	if _is_drag_active:
		end_drag(false)
```