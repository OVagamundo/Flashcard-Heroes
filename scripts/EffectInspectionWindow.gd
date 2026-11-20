class_name EffectInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

var _effect_definition: Variant
var _canonical_keyword: String = ""
var _desc_key: String = ""

func _ready() -> void:
	super._ready()
	if is_instance_valid(name_label):
		name_label.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(description_label):
		description_label.custom_minimum_size = Vector2(236, 0)
	enforce_display_only()

func populate(window_data: Dictionary) -> void:
	var effect_definitions: Variant = window_data.get("effect_definition")
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
	var desc_key := ""
	if first is Dictionary:
		desc_key = first.get("description_key", "")
	elif first is Object:
		desc_key = String(first.get("description_key")) if "description_key" in first else ""

	if desc_key == "":
		name_label.text = tr("ui.effects")
		description_label.text = tr("ui.no_effect_details")
		return

	_desc_key = desc_key

	# Effect definitions are passed as dictionaries with a localization key.
	# Ability definitions intentionally keep the generic heading because abilities
	# no longer have display names.
	var effect_def: CombatEffectDefinition = null
	if first is Dictionary:
		var effect_name_key: String = first.get("name_key", "")
		if not effect_name_key.is_empty() and is_instance_valid(CombatEffectRegistry):
			for candidate in CombatEffectRegistry.get_all_definitions():
				if candidate.display_name_key == effect_name_key:
					effect_def = candidate
					break

	var font = Database.get_current_locale_font()
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 22)
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	description_label.add_theme_font_size_override("normal_font_size", 20)
	description_label.add_theme_font_size_override("bold_font_size", 20)
	description_label.add_theme_constant_override("line_separation", 3)
	description_label.add_theme_constant_override("p_separation", 4)

	var effect_color := Color("#0F172A") # High-contrast default
	if is_instance_valid(effect_def):
		name_label.text = tr(effect_def.display_name_key)
		var kw_info = DescriptionParser.get_keyword_info(effect_def.id)
		if not kw_info.is_empty():
			effect_color = Color(kw_info.get("color", "#0F172A"))
			_canonical_keyword = kw_info.get("meta", String(effect_def.id))
		else:
			effect_color = effect_def.color
			_canonical_keyword = String(effect_def.id)
	elif first is Dictionary and not first.get("name_key", "").is_empty():
		name_label.text = tr(first.get("name_key"))
		var term_key: String = first.get("name_key", "").replace("GLOSSARY_", "").replace("STATUS_", "")
		var kw_info = DescriptionParser.get_keyword_info(term_key)
		if not kw_info.is_empty():
			effect_color = Color(kw_info.get("color", "#0F172A"))
			_canonical_keyword = kw_info.get("meta", term_key)
		elif first.has("color"):
			effect_color = Color(first.get("color"))
	else:
		name_label.text = tr("ui.ability")
		effect_color = Color("#0F172A")
		
	name_label.add_theme_color_override("font_color", effect_color)
	var final_text = tr(desc_key).strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	description_label.text = DescriptionParser.parse(final_text)
	_reset_window_size()

func _reset_window_size() -> void:
	_shrink_window_layout(260.0, false)

func get_own_keyword_canonical() -> String:
	return _canonical_keyword

func get_glossary_terms() -> Array[String]:
	var terms: Array[String] = []
	if not _desc_key.is_empty():
		terms.append_array(DescriptionParser.find_keywords(tr(_desc_key)))
	elif is_instance_valid(description_label) and not description_label.text.is_empty():
		terms.append_array(DescriptionParser.find_keywords(description_label.text))
	return terms

func get_location() -> LocationIdentifier:
	return null

