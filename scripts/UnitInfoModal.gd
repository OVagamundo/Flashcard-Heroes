extends Panel

var unit_name_label: Label = null
var tier_label: Label = null
var ability_label: Label = null

# Reference to the unit this modal is showing info for
var current_unit: Node = null

func _ready() -> void:
	# Try to find the UI elements
	unit_name_label = find_child("UnitNameLabel", true, false) as Label
	tier_label = find_child("TierLabel", true, false) as Label
	ability_label = find_child("AbilityLabel", true, false) as Label
	
	if not unit_name_label or not tier_label or not ability_label:
		push_warning("Could not find all UI elements in UnitInfoModal")
	
	hide()

func show_unit_info(unit: Node) -> void:
	if not is_instance_valid(unit) or not unit.has_method("get_global_rect") or not unit.unit_data:
		push_error("UnitInfoModal: Invalid unit or unit data provided")
		return
	
	current_unit = unit
	
	# Update the text
	if unit_name_label:
		unit_name_label.text = unit.unit_data.display_name
		
	if tier_label:
		tier_label.text = "Tier %d" % unit.tier
		
	if ability_label:
		ability_label.text = unit.unit_data.ability_description if unit.unit_data.ability_description else "No ability"
		
	# Make sure we're visible and positioned correctly
	show()
	update_position()
	
func update_position() -> void:
	if not is_instance_valid(current_unit):
		return
		
	# Get unit's global position
	var unit_rect = current_unit.get_global_rect()
	var viewport_size = get_viewport_rect().size
	
	# Position above the unit with some padding
	var modal_size = size
	var x = clamp(unit_rect.position.x - (modal_size.x - unit_rect.size.x) / 2, 10, viewport_size.x - modal_size.x - 10)
	var y = unit_rect.position.y - modal_size.y - 10
	
	# If there's not enough space above, position below
	if y < 10:
		y = unit_rect.end.y + 10
	
	position = Vector2(x, y)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Get the global rect of this panel
		var rect = get_global_rect()
		# Check if click is outside the panel
		if not rect.has_point(event.global_position):
			hide()
			get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		update_position()
