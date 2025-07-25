<!-- Original: scripts/InteractionManager.gd -->

```gdscript
# res://scripts/InteractionManager.gd
extends Node

## Central authority for all UI interactions in the game.
## Manages selection state, drag-and-drop operations, and coordinates
## between different UI components.

var _selected_location: LocationIdentifier = null
var _selected_view: Control = null

var _is_drag_active: bool = false
var _drag_source_view: Control = null
var _drag_placeholder: Control = null

func _ready():
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)
	EventBus.battle_start_requested.connect(clear_selection)

## Handles a click event on a UI element.
## @param target_view The view that was clicked (can be null for empty slots)
## @param target_loc The location that was clicked
## @param is_interactive_context Whether the click happened in a context where actions are possible
func handle_click(target_view: Control, target_loc: LocationIdentifier, is_interactive_context: bool):
	if not is_instance_valid(target_loc):
		clear_selection()
		return

	var source_loc = _selected_location

	# Case 1: Nothing is currently selected.
	if not is_instance_valid(source_loc):
		# If the click was on a valid view (not an empty slot), select it.
		if is_instance_valid(target_view):
			select_view(target_view, target_loc)
		return

	# Case 2: Clicking the same thing twice does nothing.
	if source_loc.is_equal(target_loc):
		return # Clicking the same thing twice does nothing.

	if is_interactive_context:
		# In a full-interaction context, check if an action is possible.
		if InventoryManager.is_action_valid(source_loc, target_loc):
			EventBus.emit_signal("inventory_action_requested", source_loc, target_loc)
		else:
			# The action is invalid. Deselect the old and select the new.
			select_view(target_view, target_loc)
	else:
		# In a selection-only context, any click on a valid view just changes the selection.
		if is_instance_valid(target_view):
			select_view(target_view, target_loc)
		else:
			# Clicking on an empty slot in a selection-only context clears the selection.
			clear_selection()

## Selects a view and updates the selection state.
## @param view The view to select
## @param location The location associated with the view
func select_view(view: Control, location: LocationIdentifier):
	if not is_instance_valid(view) or not is_instance_valid(location):
		clear_selection()
		return

	if _selected_view == view:
		return

	# Always clear the previous selection before making a new one.
	if is_instance_valid(_selected_view):
		var previously_selected_view = _selected_view
		_selected_view = null
		_selected_location = null
		EventBus.emit_signal("view_deselected", previously_selected_view)

	_selected_view = view
	_selected_location = location
	
	EventBus.emit_signal("view_selected", _selected_view, _selected_location)
	EventBus.emit_signal("selection_changed", _selected_location)

func clear_selection():
	if is_instance_valid(_selected_view):
		var previously_selected_view = _selected_view
		var _previously_selected_loc = _selected_location
		
		_selected_view = null
		_selected_location = null
		
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