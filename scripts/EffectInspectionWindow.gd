class_name EffectInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready() -> void:
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

## Recursively set mouse filters to PASS for child controls so clicks bubble to the root
func _configure_mouse_filters() -> void:
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Keep the internal background STOP to capture clicks anywhere in the window
				if child == $InternalBackground:
					(child as Control).mouse_filter = MOUSE_FILTER_STOP
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, name_label]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	# Cover the entire window for background clicks inside the window area
	$InternalBackground.gui_input.connect(_on_internal_background_clicked)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants (do not close self)
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_internal_background_clicked(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		# Prune only this window's descendants via WindowManager (preferred local pattern)
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()



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
	description_label.text = final_text
	_reset_window_size()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		# Enforce shrinking on EVERY container in the hierarchy
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
