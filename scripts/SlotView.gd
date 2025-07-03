# res://scripts/SlotView.gd
class_name SlotView
extends PanelContainer

# This script represents an empty, interactable slot in a data grid.

func _ready():
	# Add a simple stylebox to make the empty slot visible.
	var style = StyleBoxFlat.new()
	style.set_bg_color(Color(0,0,0,0.2))
	style.set_border_width_all(1)
	style.set_border_color(Color(0.5, 0.5, 0.5, 0.5))
	add_theme_stylebox_override("panel", style)

# Called to give this slot its location context.
func initialize(tier: int, index: int, container_name: StringName = ""):
	# TDD Compliance: The view must know its location. We store it in metadata.
	var location_identifier = {"tier": tier, "index": index, "container": container_name}
	set_meta("location_identifier", location_identifier)
	self.name = "Slot_%s_%d_%d" % [container_name, tier, index]

# TDD: Reports interactions to InteractionManager.
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var selected_view = InteractionManager.get_selected_view()
		if is_instance_valid(selected_view):
			# An item is selected, and this empty slot was clicked. This is a "Move" intent.
			EventBus.emit_signal("inventory_action_requested", selected_view, self)
			get_viewport().set_input_as_handled()

# TDD: Must be a valid drop target.
func _can_drop_data(_at_position, data) -> bool:
	return data is GachaBallView

func _drop_data(_at_position, data):
	var source_view = data as GachaBallView
	source_view.visible = true # Make the original visible again.
	# A successful drop is a "handled" drag.
	InteractionManager.end_drag(true)
	# A view was dropped on this empty slot. This is a "Move" intent.
	EventBus.emit_signal("inventory_action_requested", source_view, self)
