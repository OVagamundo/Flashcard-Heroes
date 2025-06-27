<!-- Original: scripts/InteractionManager.gd -->

```gdscript
# res://scripts/InteractionManager.gd
extends Node

## Manages the temporary UI state of a user's action (e.g., which
## GachaBallView is currently selected).

var _selected_view: Control = null
var is_drag_active: bool = false

func _ready() -> void:
	# Connect to signals to manage state.
	EventBus.inventory_action_requested.connect(func(_s, _t): clear_selection())
	EventBus.close_modal_requested.connect(clear_selection)
	EventBus.main_scene_requested.connect(clear_selection)

## Selects a view, or deselects if it's already selected.
func select_view(view: Control) -> void:
	if not is_instance_valid(view):
		clear_selection()
		return
		
	# If clicking the same view again, it's an inspection request.
	if _selected_view == view:
		# The InteractionManager's job is just to report the intent.
		# The WindowManager will decide what to do with it.
		EventBus.emit_signal("inspection_requested", view)
		clear_selection() # Deselect after emitting the request.
		return

	# If a different view was selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	# Select the new view.
	_selected_view = view
	EventBus.emit_signal("view_selected", _selected_view)

## Clears the current selection.
func clear_selection() -> void:
	if is_instance_valid(_selected_view):
		var previously_selected = _selected_view
		_selected_view = null
		EventBus.emit_signal("view_deselected", previously_selected)

## Returns the currently selected view.
func get_selected_view() -> Control:
	return _selected_view
func trigger_invalid_action_feedback(view: Control) -> void:
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
		print("Invalid action triggered on view: ", String(view.name) if view else "null")

```