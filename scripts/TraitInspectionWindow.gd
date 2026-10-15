class_name TraitInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

# TDD Section 11.2: TraitInspectionWindow.gd
# This window displays detailed information about a trait and its active levels.
# It behaves as a standard inspection window (contextual, auto-closing).

@onready var title_label: Label = %TitleLabel
@onready var icon_rect: TextureRect = %Icon
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var internal_background: ColorRect = $InternalBackground

const C = preload("res://scripts/Constants.gd")

var _source_view: Control
var _trait_id: String

func _ready() -> void:
	super._ready()
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, title_label, icon_rect]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	enforce_display_only()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_trait_id = context.get("trait_id", "")
	var current_count = context.get("count", 0)

	if _trait_id.is_empty() or not C.TRAIT_DEFINITIONS.has(_trait_id):
		WindowManager.request_close_inspection_window(self, &"INVALID_TRAIT")
		return

	var def = C.TRAIT_DEFINITIONS[_trait_id]
	title_label.text = tr(def.display_name_key)
	title_label.add_theme_font_override("font", Database.get_current_locale_font())
	title_label.add_theme_font_size_override("font_size", 32)
	
	# Set icon (reusing internal preload logic or passing texture)
	if is_instance_valid(_source_view) and _source_view.get("icon_texture"):
		icon_rect.texture = _source_view.icon_texture
	elif def.has("icon_path") and ResourceLoader.exists(def["icon_path"]):
		icon_rect.texture = load(def["icon_path"])
	else:
		match _trait_id:
			"FIRE": icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket7A.png")
			"EARTH": icon_rect.texture = preload("res://assets/Realistic/sprites/trinkets/Trinket6A.png")
			"WATER": icon_rect.texture = preload("res://assets/Realistic/sprites/items/WaterEmblem.png")
			"AIR": icon_rect.texture = preload("res://assets/Realistic/sprites/items/AirEmblem.png")

	
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

func get_child_window_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var text_to_search: String = ""
	if is_instance_valid(description_label):
		text_to_search += description_label.text + " "
	
	var keywords = DescriptionParser.find_keywords(text_to_search)
	var seen_effects: Dictionary = {}
	for kw in keywords:
		if not seen_effects.has(kw):
			seen_effects[kw] = true
			var name_key = "STATUS_" + kw.to_upper()
			var desc_key = "STATUS_" + kw.to_upper() + "_DESC"
			specs.append({
				"window_type": &"EffectInspection",
				"populate_context": {
					"effect_definition": {
						"name_key": name_key,
						"description_key": desc_key
					},
					"is_inside_unit_inspection": true,
					"target_parent_window_id": get_instance_id()
				}
			})
	return specs
