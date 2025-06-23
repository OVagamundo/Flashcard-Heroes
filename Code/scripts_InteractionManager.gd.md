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

## Selects a view, or deselects if it's already selected.
func select_view(view: Control) -> void:
	if not is_instance_valid(view):
		clear_selection()
		return
		
	# If clicking the same view again, check if it's a unit to be inspected.
	if _selected_view == view:
		# NEW LOGIC STARTS HERE
		if view is GachaBallView:
			var gacha_view = view as GachaBallView
			var instance_data = gacha_view.get_instance_data()
			if instance_data:
				var definition = Database.units.get(instance_data.definition_id)
				if definition and definition.category == "UNIT":
					EventBus.emit_signal("unit_inspection_requested", gacha_view)
					clear_selection() # Deselect after opening the modal.
					return
		# If it's not a unit or something went wrong, just deselect as normal.
		clear_selection()
		return
		# NEW LOGIC ENDS HERE

	# If a different view was selected, deselect it first.
	if is_instance_valid(_selected_view):
		clear_selection()

	# Select the new view.
	_selected_view = view
	EventBus.emit_signal("view_selected", _selected_view)
	print("View selected: ", String(view.name) if view else "null")

## Clears the current selection.
func clear_selection() -> void:
	if is_instance_valid(_selected_view):
		var previously_selected = _selected_view
		_selected_view = null
		EventBus.emit_signal("view_deselected", previously_selected)
		print("View deselected: ", previously_selected.name if previously_selected else "null")

## Returns the currently selected view.
func get_selected_view() -> Control:
	return _selected_view

## Emits a signal to trigger visual feedback for an invalid action.
func trigger_invalid_action_feedback(view: Control) -> void:
	if is_instance_valid(view):
		EventBus.emit_signal("invalid_action_triggered", view)
		print("Invalid action triggered on view: ", String(view.name) if view else "null")

```