class_name TraitInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

# TDD Section 11.2: TraitInspectionWindow.gd
# This window displays detailed information about a trait and its active levels.
# It behaves as a standard inspection window (contextual, auto-closing).

@onready var title_label: Label = %TitleLabel
const BOLD_FONT = preload("res://assets/fonts/noto_sans_black_composite.tres")
@onready var icon_rect: TextureRect = %Icon
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var internal_background: ColorRect = $InternalBackground

const C = preload("res://scripts/Constants.gd")

var _source_view: Control
var _trait_id: String

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
				# Keep nodes with their own logic at STOP
				if child == internal_background or child == description_label:
					(child as Control).mouse_filter = MOUSE_FILTER_STOP
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, title_label, icon_rect]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants.
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func _on_internal_background_gui_input(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_trait_id = context.get("trait_id", "")
	var current_count = context.get("count", 0)

	if _trait_id.is_empty() or not C.TRAIT_DEFINITIONS.has(_trait_id):
		WindowManager.request_close_inspection_window(self, &"INVALID_TRAIT")
		return

	var def = C.TRAIT_DEFINITIONS[_trait_id]
	title_label.text = tr(def.display_name_key)
	title_label.add_theme_font_override("font", BOLD_FONT)
	title_label.add_theme_font_size_override("font_size", 32)
	
	# Set icon (reusing internal preload logic or passing texture)
	# For simplicity, we'll try to get it from the source view if it has one, or hardcode mapping
	# ideally Constants would contain icon paths.
	if is_instance_valid(_source_view) and _source_view.get("icon_texture"):
		icon_rect.texture = _source_view.icon_texture
	else:
		match _trait_id:
			"FIRE": icon_rect.texture = preload("res://assets/sprites/trinkets/Trinket7A.png")
			"EARTH": icon_rect.texture = preload("res://assets/sprites/trinkets/Trinket6A.png")
			"WATER": icon_rect.texture = preload("res://assets/sprites/items/WaterEmblem.png")
			"AIR": icon_rect.texture = preload("res://assets/sprites/items/AirEmblem.png")
	
	# Build description text with highlighting
	var text = ""
	for level in def.levels:
		var min_req = level.min
		var is_active = current_count >= min_req
		
		# Formatting
		var color_tag = "[color=#FFFF00]" if is_active else "[color=#888888]" # Yellow if active, Grey if inactive
		var end_tag = "[/color]"
		var prefix = "★ " if is_active else "○ " # Star for active, circle for inactive
		
		var desc_text = tr(level.desc_key)
		
		text += "%s[b]%s%d[/b]: %s%s\n" % [color_tag, prefix, min_req, desc_text, end_tag]
	
	var final_text = text.strip_edges()
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
