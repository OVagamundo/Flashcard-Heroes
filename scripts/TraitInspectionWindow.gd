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
	var font = Database.get_current_locale_font()
	title_label.text = tr(def.display_name_key)
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 26)
	
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	description_label.add_theme_font_size_override("normal_font_size", 22)
	description_label.add_theme_font_size_override("bold_font_size", 22)
	description_label.add_theme_constant_override("line_separation", 3)
	description_label.add_theme_constant_override("p_separation", 6)
	
	# Set icon (reusing internal preload logic or passing texture)
	if is_instance_valid(_source_view) and _source_view.get("icon_texture"):
		icon_rect.texture = _source_view.icon_texture
	elif def.has("icon_path") and ResourceLoader.exists(def["icon_path"]):
		icon_rect.texture = load(def["icon_path"])
	else:
		match _trait_id:
			"FIRE": icon_rect.texture = preload("res://assets/PixelArt/sprites/trinkets/Trinket7A.png")
			"EARTH": icon_rect.texture = preload("res://assets/PixelArt/sprites/trinkets/Trinket6A.png")
			"WATER": icon_rect.texture = preload("res://assets/PixelArt/sprites/items/WaterEmblem.png")
			"AIR": icon_rect.texture = preload("res://assets/PixelArt/sprites/items/AirEmblem.png")

	
	# Build description text with highlighting
	var text = ""
	for level in def.levels:
		var min_req = level.min
		var is_active = current_count >= min_req
		
		# Formatting
		var color_tag = "[color=#B45309]" if is_active else "[color=#64748B]" # Amber if active, Slate if inactive
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
	_shrink_window_layout(480.0, true)

func get_glossary_terms() -> Array[String]:
	return _collect_glossary_terms_from_labels([description_label])

func get_child_window_specs() -> Array[Dictionary]:
	return []
