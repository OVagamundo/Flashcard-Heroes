<!-- Original: scripts/SlotView.gd -->

```gdscript
class_name SlotView
extends PanelContainer


var _location: LocationIdentifier

func _ready():
	# Add a simple stylebox to make the empty slot visible.
	var style = StyleBoxFlat.new()
	style.set_bg_color(Color(0,0,0,0.2))
	style.set_border_width_all(1)
	style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
	add_theme_stylebox_override("panel", style)

func populate(loc: LocationIdentifier):
	self._location = loc
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

func _gui_input(event: InputEvent):
	if not is_instance_valid(_location): return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Prune any child inspection windows first (standard inspection behavior).
		var win: Node = self
		while win and win != get_tree().root:
			if win is InspectionWindow:
				WindowManager.handle_inspection_background_click(win as Control)
				break
			win = win.get_parent()

		get_viewport().set_input_as_handled()
		var selected_loc = InteractionManager.get_selected_location()
		
		# Only emit a signal if something is already selected and this slot is the target.
		if is_instance_valid(selected_loc) and selected_loc != _location:
			EventBus.emit_signal("inventory_action_requested", selected_loc, _location)
		
		# An empty slot should never be the source of an action.
		# Clicking it with nothing else selected should just clear the context.
		else:
			InteractionManager.clear_selection()

func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
	EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)

```