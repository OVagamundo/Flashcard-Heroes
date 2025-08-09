class_name EffectInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready():
	$InternalBackground.gui_input.connect(_on_internal_background_clicked)

func _on_internal_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Prune only this window's descendants via WindowManager (preferred local pattern)
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()









func populate(context: Dictionary):
	var effect_definitions = context.get("effect_definition")
	# Accept either a single definition or an array of definitions
	var defs: Array = []
	if effect_definitions is Array:
		defs = effect_definitions
	elif effect_definitions != null:
		defs = [effect_definitions]

	# If no abilities, show placeholder instead of closing
	if defs.is_empty():
		name_label.text = "Effects"
		description_label.text = "This unit has no special effects."
		return

	# Display the first effect definition; support Dictionary or Object types
	var first = defs[0]
	var name_key := ""
	var desc_key := ""
	if first is Dictionary:
		name_key = first.get("name_key", "")
		desc_key = first.get("description_key", "")
	elif first is Object:
		# Use safe field access via get() to avoid relying on typed properties
		name_key = first.get("name_key") if first.has_method("get") else (first.name_key if "name_key" in first else "")
		desc_key = first.get("description_key") if first.has_method("get") else (first.description_key if "description_key" in first else "")

	if name_key == "" and desc_key == "":
		name_label.text = "Effects"
		description_label.text = "No details available for this effect."
		return

	name_label.text = tr(name_key)
	description_label.text = tr(desc_key)

func get_location() -> LocationIdentifier:
	return null
