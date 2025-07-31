class_name EffectInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready():
	$InternalBackground.gui_input.connect(_on_internal_background_clicked)

func _on_internal_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Create and emit InteractionContext for inspection window background
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
