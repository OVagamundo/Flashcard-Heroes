<!-- Original: scripts/EffectInspectionWindow.gd -->

```gdscript
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		EventBus.emit_signal("background_clicked", self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary):
	var effect_definitions = context.get("effect_definition")

	# This window expects an array of ability definitions.
	# For now, we just inspect the first one.
	if not effect_definitions is Array or effect_definitions.is_empty():
		queue_free()
		return

	var effect_def = effect_definitions[0]
	if not is_instance_valid(effect_def):
		queue_free()
		return

	name_label.text = tr(effect_def.display_name_key)
	description_label.text = tr(effect_def.description_key)

```