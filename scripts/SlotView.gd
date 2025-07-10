class_name SlotView
extends PanelContainer

const LocationIdentifier = preload("res://scripts/LocationIdentifier.gd")

var _location: LocationIdentifier

func _ready():
	EventBus.view_selected.connect(_on_view_selected)
	EventBus.view_deselected.connect(_on_view_deselected)
	
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
		get_viewport().set_input_as_handled()
		var selected_loc = InteractionManager.get_selected_location()
		if is_instance_valid(selected_loc) and selected_loc != _location:
			EventBus.emit_signal("inventory_action_requested", selected_loc, _location)
		else:
			InteractionManager.select_view(self, _location)

func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data):
	EventBus.emit_signal("inventory_action_requested", data.source_loc, _location)

func _on_view_selected(view: Control, _loc: LocationIdentifier):
	if view == self:
		_apply_selection_feedback(true)

func _on_view_deselected(view: Control):
	if view == self:
		_apply_selection_feedback(false)

func _apply_selection_feedback(is_selected: bool):
	if not is_inside_tree(): return
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if is_selected:
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
	else:
		stylebox.border_width_left = 1
		stylebox.border_width_top = 1
		stylebox.border_width_right = 1
		stylebox.border_width_bottom = 1
	add_theme_stylebox_override("panel", stylebox)