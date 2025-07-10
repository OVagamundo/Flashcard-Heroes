extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		EventBus.emit_signal("background_clicked", self)
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
