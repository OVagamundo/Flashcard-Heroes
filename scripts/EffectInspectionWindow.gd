class_name EffectInspectionWindow
extends "res://scripts/InspectionWindow.gd"

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

func _ready() -> void:
	# Ensure the window root consumes clicks so they don't fall through to the true background
	mouse_filter = MOUSE_FILTER_STOP
	# Bubble non-link clicks on description to the root so local prune runs
	description_label.mouse_filter = MOUSE_FILTER_PASS
	# Cover the entire window for background clicks inside the window area
	$InternalBackground.gui_input.connect(_on_internal_background_clicked)
	# Configure child controls to bubble clicks to the root (except the internal background)
	_configure_mouse_filters()

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants (do not close self)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_internal_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Prune only this window's descendants via WindowManager (preferred local pattern)
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

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
	description_label.text = tr(desc_key)

func get_location() -> LocationIdentifier:
	return null
