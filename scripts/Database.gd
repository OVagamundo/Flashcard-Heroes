# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

## Content Set Constants
const SET_BASE: StringName = &"BASE"
const SET_NOVICE: StringName = &"NOVICE"
const SET_MERCENARY: StringName = &"MERCENARY"

## Authoritative definitions belonging to Hero Content Packs
const NOVICE_SET_IDS: Array[StringName] = [
	&"?NovPla", &"?ANovFod", &"E?NovPla", &"F?NovApp", &"W?NovCos",
	&"E??ANovPla", &"F??ANovFod", &"W??ANovCos", &"EF??NovApp", &"EW??NovPla", &"FW??NovAni",
	&"item_study_pouch", &"item_review_ledger", &"item_answer_key", &"item_novice_archive", &"item_novice_emblem",
	&"trinket_trait_novice", &"trinket_beginners_charm", &"trinket_study_hall_bell", &"trinket_novice_insignia"
]

const MERCENARY_SET_IDS: Array[StringName] = [
	&"?MerSpe", &"?ASpeMerFodToy", &"E?TnkMerPlaToy", &"F?FigMerMecApp", &"W?SupMerAniCos",
	&"E??ATnkSpeMerFodPlaToy", &"FW??FigSupMerAniMecAppCos", &"W??ASupSpeMerFodAniToyCos",
	&"F??AFigSpeMerFodMecToyApp", &"EF??TnkFigMerMecPlaToyApp", &"EW??TnkSupMerAniPlaToyCos",
	&"item_claim_ticket", &"item_interest_ledger", &"item_loaded_contract", &"item_golden_seal", &"item_mercenary_emblem",
	&"trinket_trait_mercenary", &"trinket_recruiting_charm", &"trinket_wanted_poster", &"trinket_mercenary_insignia"
]

var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var trinkets: Dictionary = {} # Key: StringName(id), Value: TrinketDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition
var abilities: Dictionary = {} # Key: StringName(id), Value: AbilityDefinition
## Flashcard definitions loaded from JSON files
var flashcard_definitions: Dictionary = {} # Key: StringName(id), Value: Dictionary (question, answer, explanation)
## Deck definitions loaded from JSON files
var deck_definitions: Dictionary = {} # Key: StringName(deck_id), Value: Dictionary (metadata + card_ids)

func _ready() -> void:
	# Load translations first
	_load_translations()
	
	# Populate all data dictionaries at startup.
	_load_resources_from_path("res://resources/units/", units)
	_load_resources_from_path("res://resources/items/", items)
	_load_resources_from_path("res://resources/items/consumables/", items)
	_load_resources_from_path("res://resources/trinkets/", trinkets)
	_load_resources_from_path("res://resources/recipes/", recipes)
	_load_resources_from_path("res://resources/abilities/", abilities)
	_load_resources_from_path("res://resources/abilities/consumables/", abilities)
	
	_apply_global_textures()
	ArtStyleManager.style_changed.connect(_apply_global_textures)

	
	# Load flashcard definitions from JSON
	_load_flashcard_definitions()

func _apply_global_textures() -> void:
	for dict in [units, items, trinkets, recipes, abilities]:
		for def in dict.values():
			if not is_instance_valid(def): continue
			
			for prop in def.get_property_list():
				if prop.type == TYPE_OBJECT:
					var val = def.get(prop.name)
					if val is Texture2D:
						# Ensure we store the original texture before modifying it
						var meta_key = "original_" + prop.name
						if not def.has_meta(meta_key):
							def.set_meta(meta_key, val)
							
						var original = def.get_meta(meta_key)
						if original:
							var new_tex = ArtStyleManager.get_themed_texture(original)
							if new_tex != val:
								def.set(prop.name, new_tex)

# -----------------------------
# Public API
# -----------------------------


# Returns an AbilityDefinition by id, or null.
func get_ability_definition(id: StringName) -> AbilityDefinition:
	var def: AbilityDefinition = abilities.get(id)
	if def:
		return def
	return null

## A helper function that iterates through a directory, loads each `.tres` file,
## and stores it in the provided dictionary, using the resource's `id` property as the key.
func _load_resources_from_path(path: String, dictionary: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_exported_resource_file(file_name):
			file_names.append(file_name)
		file_name = dir.get_next()

	file_names.sort()

	for fn in file_names:
		var resource_path = path.path_join(_get_resource_load_name(fn))
		var resource = load(resource_path)
		if is_instance_valid(resource):
			if "id" in resource:
				if NOVICE_SET_IDS.has(resource.id):
					resource.set_id = SET_NOVICE
				elif MERCENARY_SET_IDS.has(resource.id):
					resource.set_id = SET_MERCENARY
				dictionary[resource.id] = resource
			else:
				pass
		else:
			pass


## Locale-to-font mapping: Each locale maps to its dedicated primary font with NO fallbacks.
## In alignment with fail-fast architecture, missing glyphs or unsupported locales fail visibly.
const LOCALE_FONTS := {
	"en": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"pt_BR": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"de": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"fr": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"es": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"it": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"ru": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"pl": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"tr": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"vi": "res://assets/fonts/noto_sans/NotoSans-Black.ttf",
	"ja": "res://assets/fonts/static/NotoSansJP-Black.ttf",
	"zh_CN": "res://assets/fonts/NotoSansSC-VariableFont_wght.ttf",
	"zh_TW": "res://assets/fonts/NotoSansTC-VariableFont_wght.ttf",
	"ko": "res://assets/fonts/NotoSansKR-VariableFont_wght.ttf",
	"th": "res://assets/fonts/NotoSansThai-VariableFont_wdth_wght.ttf",
}

## Loads the translation PO files and registers them with TranslationServer
func _load_translations() -> void:
	var translation_paths := PackedStringArray([
		"res://localization/en.po",
		"res://localization/pt_BR.po"
	])
	
	for translation_path in translation_paths:
		var translation := load(translation_path) as Translation
		if translation:
			TranslationServer.add_translation(translation)
		else:
			push_error("CRITICAL: Failed to load translation file '%s'" % translation_path)
	
	# Set default locale and apply its font
	set_locale("en")

## Returns the dedicated font for a given locale (or its base language code)
func get_font_for_locale(locale: String) -> Font:
	var font_path: String = ""
	if LOCALE_FONTS.has(locale):
		font_path = LOCALE_FONTS[locale]
	else:
		var base_locale := locale.split("_")[0]
		if LOCALE_FONTS.has(base_locale):
			font_path = LOCALE_FONTS[base_locale]
	
	assert(not font_path.is_empty(), "CRITICAL: No dedicated font configured for locale '%s'!" % locale)
	var font := load(font_path) as Font
	assert(font != null, "CRITICAL: Failed to load font at '%s' for locale '%s'!" % [font_path, locale])
	return font

## Returns the dedicated font for the currently active locale
func get_current_locale_font() -> Font:
	return get_font_for_locale(TranslationServer.get_locale())

## Applies the dedicated locale font to the global game theme
func _apply_locale_font(locale: String) -> void:
	var font := get_font_for_locale(locale)
	if font == null:
		return
	
	var theme := preload("res://assets/styles/game_theme.tres") as Theme
	theme.default_font = font
	theme.set_font("font", "Button", font)
	theme.set_font("font", "Label", font)
	theme.set_font("font", "HeaderLabel", font)
	theme.set_font("font", "HUDLabel", font)
	theme.set_font("font", "LineEdit", font)
	theme.set_font("normal_font", "RichTextLabel", font)
	theme.set_font("bold_font", "RichTextLabel", font)
	theme.set_font("italics_font", "RichTextLabel", font)
	theme.set_font("bold_italics_font", "RichTextLabel", font)
	theme.set_font("mono_font", "RichTextLabel", font)

## Sets the game locale, updates theme typography, and triggers UI updates
func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_apply_locale_font(locale)
	SignalBus.emit_signal("locale_changed")


## A central helper to find any definition by its ID (Unit, Item, Trinket).
func get_definition(id: StringName) -> Resource:
	var definition: GachaBallDefinition = units.get(id)
	if definition:
		return definition
	
	definition = items.get(id)
	if definition:
		return definition

	var trinket_def = trinkets.get(id)
	if trinket_def:
		return trinket_def

	return null

## Returns the MergeRecipe that produces the given result_id, or null if none.
func get_recipe_for_result(result_id: StringName) -> MergeRecipe:
	for recipe in recipes.values():
		if recipe.result_id == result_id:
			return recipe
	return null

## Returns the self-merge recipe for the given definition_id, or null if none.
func get_self_merge_recipe(definition_id: StringName) -> MergeRecipe:
	for recipe in recipes.values():
		if recipe.is_self_merge and recipe.ingredient_a_id == definition_id:
			return recipe
	return null

## A helper to get a definition from a deck by card ID
func get_definition_from_deck(card_id: StringName) -> Resource:
	return get_definition(card_id)

## A helper to get flashcard data from a deck by card ID
func get_flashcard_definition(card_id: StringName) -> Dictionary:
	var def = flashcard_definitions.get(card_id, {}).duplicate()
	if TranslationServer.get_locale().begins_with("pt"):
		var pt_expl = def.get("explanation_pt", "")
		if not pt_expl.is_empty():
			def["explanation"] = pt_expl
		
		var pt_answer = def.get("answer_pt", "")
		if not pt_answer.is_empty():
			def["answer"] = pt_answer
			
		var pt_question = def.get("question_pt", "")
		if not pt_question.is_empty():
			def["question"] = pt_question
	return def

## Returns all hero definitions
func get_hero_definitions() -> Array[GachaBallDefinition]:
	var hero_defs: Array[GachaBallDefinition] = []
	for unit in units.values():
		if unit.is_hero:
			hero_defs.append(unit)
	hero_defs.sort_custom(func(a: GachaBallDefinition, b: GachaBallDefinition) -> bool:
		return String(a.id) < String(b.id)
	)
	return hero_defs

## Returns metadata for all available decks
func get_all_deck_metadata() -> Array[Dictionary]:
	var deck_meta: Array[Dictionary] = []
	var is_pt = TranslationServer.get_locale().begins_with("pt")
	
	for deck_id in deck_definitions:
		var deck = deck_definitions[deck_id]
		var display_name = deck.get("display_name", deck_id)
		var description = deck.get("description", "")
		
		if is_pt:
			display_name = deck.get("display_name_pt", display_name)
			description = deck.get("description_pt", description)
			
		deck_meta.append({
			"deck_id": deck.deck_id,
			"display_name": display_name,
			"description": description
		})
	
	return deck_meta

## Returns the list of card IDs for a specific deck
func get_cards_for_deck(deck_id: StringName) -> Array[StringName]:
	if deck_definitions.has(deck_id):
		return deck_definitions[deck_id].card_ids
	return []

## Maps a hero definition ID to their associated Hero Set.
## Heroes without a specialized set map to SET_BASE.
static func get_hero_set(hero_id: StringName) -> StringName:
	match hero_id:
		&"hero_starter":
			return SET_NOVICE
		&"hero_bounty_hunter", &"hero":
			return SET_MERCENARY
		_:
			return SET_BASE

## Returns the definitive content set ID for a resource definition.
static func get_entity_set(entity: Resource) -> StringName:
	if not is_instance_valid(entity):
		return SET_BASE
	if "id" in entity:
		if NOVICE_SET_IDS.has(entity.id):
			return SET_NOVICE
		if MERCENARY_SET_IDS.has(entity.id):
			return SET_MERCENARY
	if "set_id" in entity and entity.set_id != &"" and entity.set_id != SET_BASE:
		return entity.set_id
	return SET_BASE

## Returns all definitions valid for the reward/shop pool (Tier > 0, non-Hero, non-Boss, non-Token).
## When active_set is provided (or resolved via GameManager.run_state), only SET_BASE and
## matching active_set definitions are returned. Pass &"ALL" to bypass set filtering.
func get_all_pool_definitions(active_set: StringName = &"") -> Array[GachaBallDefinition]:
	var effective_set := active_set
	if effective_set.is_empty():
		if is_instance_valid(GameManager.run_state):
			effective_set = GameManager.run_state.get_active_hero_set()
		else:
			effective_set = SET_BASE

	var pool: Array[GachaBallDefinition] = []
	
	# Collect from units
	for unit in units.values():
		if _is_valid_for_pool(unit):
			var u_set = get_entity_set(unit)
			if effective_set == &"ALL" or u_set == SET_BASE or u_set == effective_set:
				pool.append(unit)
			
	# Collect from items
	for item in items.values():
		if _is_valid_for_pool(item):
			var i_set = get_entity_set(item)
			if effective_set == &"ALL" or i_set == SET_BASE or i_set == effective_set:
				pool.append(item)
			
	pool.sort_custom(func(a: GachaBallDefinition, b: GachaBallDefinition) -> bool:
		return String(a.id) < String(b.id)
	)
	return pool

## Returns all eligible units for in-combat random summons filtered by tier, team, and active run set.
## Enemy summons are restricted strictly to non-player-exclusive units belonging to SET_BASE.
## Player summons are restricted to SET_BASE and the active hero set (active_set or GameManager.run_state.active_hero_set).
func get_eligible_summon_units(tier: int, is_player: bool, active_set: StringName = &"") -> Array[GachaBallDefinition]:
	var effective_set := active_set
	if effective_set.is_empty():
		if is_instance_valid(GameManager.run_state):
			effective_set = GameManager.run_state.get_active_hero_set()
		else:
			effective_set = SET_BASE

	var candidates: Array[GachaBallDefinition] = []
	for unit_def: GachaBallDefinition in units.values():
		if not is_instance_valid(unit_def):
			continue
		if unit_def.category != &"UNIT":
			continue
		if unit_def.tier != tier:
			continue
		if unit_def.is_hero:
			continue
		if unit_def.tags.has(&"BOSS") or unit_def.tags.has(&"TOKEN") or unit_def.tags.has(&"HIDDEN"):
			continue
		var unit_id_lower := String(unit_def.id).to_lower()
		if unit_id_lower.contains("dust") or unit_id_lower.contains("elite"):
			continue

		var u_set: StringName = get_entity_set(unit_def)
		if not is_player:
			if unit_def.is_player_exclusive:
				continue
			if u_set != SET_BASE:
				continue
		else:
			if effective_set != &"ALL" and u_set != SET_BASE and u_set != effective_set:
				continue

		candidates.append(unit_def)

	candidates.sort_custom(func(a: GachaBallDefinition, b: GachaBallDefinition) -> bool:
		return String(a.id) < String(b.id)
	)
	return candidates

## Returns all trinket definitions eligible for rewards, sorted deterministically by id.
## When active_set is provided (or resolved via GameManager.run_state), only SET_BASE and
## matching active_set trinkets are returned. Pass &"ALL" to bypass set filtering.
func get_eligible_trinkets_for_reward(active_set: StringName = &"") -> Array[TrinketDefinition]:
	var effective_set := active_set
	if effective_set.is_empty():
		if is_instance_valid(GameManager.run_state):
			effective_set = GameManager.run_state.get_active_hero_set()
		else:
			effective_set = SET_BASE

	var eligible: Array[TrinketDefinition] = []
	for t in trinkets.values():
		if t is TrinketDefinition and not t.is_enemy_exclusive:
			var t_set = get_entity_set(t)
			if effective_set == &"ALL" or t_set == SET_BASE or t_set == effective_set:
				eligible.append(t)
	eligible.sort_custom(func(a: TrinketDefinition, b: TrinketDefinition) -> bool:
		return String(a.id) < String(b.id)
	)
	return eligible

func _is_valid_for_pool(def: GachaBallDefinition) -> bool:
	if not is_instance_valid(def): return false
	if def.is_hero: return false
	if def.tier < 1: return false
	if def.tags.has(&"BOSS"): return false
	if def.tags.has(&"TOKEN"): return false
	if def.tags.has(&"HIDDEN"): return false
	return true

## Loads flashcard definitions from JSON files in the decks directory
func _load_flashcard_definitions() -> void:
	var dir = DirAccess.open("res://decks/")
	if not dir:
		return

	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			file_names.append(file_name)
		file_name = dir.get_next()

	file_names.sort()

	for fn in file_names:
		var file_path = "res://decks/" + fn
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				var deck_data = json.data
				if deck_data.has("deck_id") and deck_data.has("cards"):
					var deck_id = StringName(deck_data.deck_id)
					var card_ids: Array[StringName] = []
					
					for card in deck_data.cards:
						if card.has("id") and card.has("question") and card.has("answer"):
							var card_id = StringName(card.id)
							card_ids.append(card_id)
							
							# Store card definition globally
							flashcard_definitions[card_id] = {
								"question": card.question,
								"question_pt": card.get("question_pt", ""),
								"answer": card.answer,
								"answer_pt": card.get("answer_pt", ""),
								"explanation": card.get("explanation", ""),
								"explanation_pt": card.get("explanation_pt", "")
							}
					
					# Store deck definition
					deck_definitions[deck_id] = {
						"deck_id": deck_id,
						"display_name": deck_data.get("display_name", deck_id),
						"display_name_pt": deck_data.get("display_name_pt", ""),
						"description": deck_data.get("description", ""),
						"description_pt": deck_data.get("description_pt", ""),
						"card_ids": card_ids
					}
				else:
					pass
			else:
				pass


func _is_exported_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res.remap")


func _get_resource_load_name(file_name: String) -> String:
	if file_name.ends_with(".remap"):
		return file_name.trim_suffix(".remap")
	return file_name
