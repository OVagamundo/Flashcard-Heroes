class_name EffectInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

var _effect_definition: Variant

func _ready() -> void:
	super._ready()
	for child in [description_label, name_label]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	enforce_display_only()

func populate(context: Dictionary) -> void:
	var effect_definitions: Variant = context.get("effect_definition")
	# Accept either a single definition or an array of definitions
	var defs: Array = []
	if effect_definitions is Array:
		defs = effect_definitions
	elif effect_definitions != null:
		defs = [effect_definitions]

	# If no abilities, show placeholder instead of closing
	if defs.is_empty():
		name_label.text = tr("ui.effects")
		description_label.text = tr("ui.no_effects")
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
		name_label.text = tr("ui.effects")
		description_label.text = tr("ui.no_effect_details")
		return

	name_label.text = tr(name_key)
	var final_text = tr(desc_key).strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	description_label.text = DescriptionParser.parse(final_text)
	_reset_window_size()

func _reset_window_size() -> void:
	if is_instance_valid(self):
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(480, 0)
		size = Vector2.ZERO # Force immediate recalculation of minimum size
		reset_size()

func get_location() -> LocationIdentifier:
	return null

