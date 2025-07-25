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

func _exit_tree():
	pass

func _notification(what):
	pass

func populate(loc: LocationIdentifier):
	self._location = loc
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

func _gui_input(event: InputEvent):
	if not is_instance_valid(_location): 
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# This block is essential for correctly closing child inspection windows.
		var win: Node = self
		while win and win != get_tree().root:
			if win is InspectionWindow:
				WindowManager.handle_inspection_background_click(win as Control)
				break
			win = win.get_parent()

		get_viewport().set_input_as_handled()

		# For slots, we always want to allow interactions when something is selected
		InteractionManager.handle_click(null, _location, true)

func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
	EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)

```