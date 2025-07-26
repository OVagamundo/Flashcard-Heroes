<!-- Original: scripts/InteractionManager.gd -->

```gdscript
# res://scripts/InteractionManager.gd
extends Node


## Manages the temporary UI state of a user's action, such as the currently
## selected view/location and any active drag-and-drop operations.

var _selected_location: LocationIdentifier = null
var _selected_view: Control = null

var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null

func _ready():
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)
	EventBus.battle_start_requested.connect(clear_selection)
	EventBus.selection_clear_requested.connect(clear_selection)

func select_view(view: Control, location: LocationIdentifier):
	if not is_instance_valid(view) or not is_instance_valid(location):
		clear_selection()
		return

	# If clicking the same view again, do nothing to allow drag to start.
	if _selected_view == view:
		return

	# If a different view was already selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	_selected_view = view
	_selected_location = location
	
	EventBus.emit_signal("view_selected", _selected_view, _selected_location)
	EventBus.emit_signal("selection_changed", _selected_location)

func clear_selection():
	var previously_selected_view = _selected_view
	var _previously_selected_loc = _selected_location
	_selected_view = null
	_selected_location = null
	if is_instance_valid(previously_selected_view):
		EventBus.emit_signal("view_deselected", previously_selected_view)
	EventBus.emit_signal("selection_changed", null)

func get_selected_location() -> LocationIdentifier:
	return _selected_location

func get_selected_view() -> Control:
	return _selected_view

# --- Drag & Drop State Management ---

func is_drag_active() -> bool:
	return _is_drag_active

func get_drag_source_view() -> Control:
	return _drag_source_view

func start_drag(source_view: Control, placeholder: Control):
	if not is_instance_valid(source_view): return
	
	clear_selection() # A drag operation overrides any selection
	
	_is_drag_active = true
	_drag_source_view = source_view
	_drag_placeholder = placeholder
	
	# The view itself is made invisible, and the placeholder takes its spot
	# in the layout to prevent reflowing.
	source_view.visible = false

func end_drag(was_handled: bool):
	if not _is_drag_active: return
	
	# If drag was not handled (e.g., dropped on invalid area), restore visibility.
	if not was_handled and is_instance_valid(_drag_source_view):
		_drag_source_view.visible = true

	if is_instance_valid(_drag_placeholder):
		_drag_placeholder.queue_free()
		
	_is_drag_active = false
	_drag_source_view = null
	_drag_placeholder = null

func cancel_active_drag():
	if _is_drag_active:
		end_drag(false)

```