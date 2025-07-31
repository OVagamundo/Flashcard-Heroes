<!-- Original: scripts/EffectInspectionWindow.gd -->

```gdscript
class_name EffectInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready():
	pass



func _is_interactive_element(control: Control) -> bool:
	if not is_instance_valid(control):
		return false
	
	# Check if it's a Button
	if control is Button:
		return true
	
	# Check if it has a specific class name that indicates interactivity
	var control_class = control.get_class()
	if control_class in ["Button", "LinkButton", "OptionButton", "CheckBox", "CheckButton", "RadioButton"]:
		return true
	
	# Check if it's a GachaBallView (interactive game element)
	if control is GachaBallView:
		return true
	
	# Check if it's a SlotView (interactive game element)
	if control is SlotView:
		return true
	
	return false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Check if the click is within the RichTextLabel's bounds (if it has any)
		if description_label.get_global_rect().has_point(event.global_position):
			# This is a click on the text area, don't interfere
			return
		
		# Check if the click is on any interactive element
		var clicked_control = _get_control_at_position(event.global_position)
		if _is_interactive_element(clicked_control):
			# This is a click on an interactive element, don't interfere
			return
		
		# This is a background click, create and emit InteractionContext
		var context = InteractionContext.new()
		context.source_view_instance_id = get_instance_id()
		context.event_type = &"SINGLE_CLICK"
		context.location = null  # No specific location for background
		context.entity_uuid = ""
		context.entity_type = &"WINDOW_BACKGROUND"
		context.interaction_mode = &"FULLY_INTERACTIVE"
		context.window_group_id = 1  # Inspection window group
		
		EventBus.emit_signal("interaction_context_received", context)
		get_viewport().set_input_as_handled()

func _get_control_at_position(position: Vector2) -> Control:
	# Recursively search for the control at the given position
	return _find_control_recursive(self, position)

func _find_control_recursive(node: Node, position: Vector2) -> Control:
	# Check if this node is a Control and contains the position
	if node is Control:
		var control = node as Control
		if control.get_global_rect().has_point(position):
			# This control contains the position, but check if any child also contains it
			for child in node.get_children():
				var child_result = _find_control_recursive(child, position)
				if is_instance_valid(child_result):
					return child_result
			# No child contains the position, so this is the deepest control
			return control
	
	# If this node is not a Control, check its children
	for child in node.get_children():
		var result = _find_control_recursive(child, position)
		if is_instance_valid(result):
			return result
	
	return null

func populate(context: Dictionary):
	var effect_definitions = context.get("effect_definition")

	# If the unit/item has no abilities, show a placeholder instead of closing.
	if not effect_definitions is Array or effect_definitions.is_empty():
		name_label.text = "Effects"
		description_label.text = "This unit has no special effects."
		return

	# If there are abilities, display the first one as before.
	var effect_def = effect_definitions[0]
	if not is_instance_valid(effect_def):
		queue_free()
		return

	name_label.text = tr(effect_def.name_key)
	description_label.text = tr(effect_def.description_key)

func get_location() -> LocationIdentifier:
	return null

```