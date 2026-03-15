# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

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

	
	# Load flashcard definitions from JSON
	_load_flashcard_definitions()

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

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_exported_resource_file(file_name):
			var resource_path = path.path_join(_get_resource_load_name(file_name))
			var resource = load(resource_path)
			if is_instance_valid(resource):
				if "id" in resource:
					dictionary[resource.id] = resource
				else:
					pass
			else:
				pass
		file_name = dir.get_next()


## Loads the translation CSV file and adds it to the TranslationServer
func _load_translations() -> void:
	var translation_paths := PackedStringArray([
		"res://localization/game.en.translation",
		"res://localization/game.pt_BR.translation"
	])
	
	for translation_path in translation_paths:
		var translation := load(translation_path) as Translation
		if translation:
			TranslationServer.add_translation(translation)
	
	# Set default locale (could load from saved preference later)
	TranslationServer.set_locale("en")

## Sets the game locale and triggers UI updates
func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
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

## A helper to get a definition from a deck by card ID
func get_definition_from_deck(card_id: StringName) -> Resource:
	return get_definition(card_id)

## A helper to get flashcard data from a deck by card ID
func get_flashcard_definition(card_id: StringName) -> Dictionary:
	return flashcard_definitions.get(card_id, {})

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
	
	for deck_id in deck_definitions:
		var deck = deck_definitions[deck_id]
		deck_meta.append({
			"deck_id": deck.deck_id,
			"display_name": deck.display_name,
			"description": deck.get("description", "")
		})
	
	return deck_meta

## Returns the list of card IDs for a specific deck
func get_cards_for_deck(deck_id: StringName) -> Array[StringName]:
	if deck_definitions.has(deck_id):
		return deck_definitions[deck_id].card_ids
	return []

## Returns all definitions valid for the reward/shop pool (Tier > 0, non-Hero, non-Boss, non-Token)
func get_all_pool_definitions() -> Array[GachaBallDefinition]:
	var pool: Array[GachaBallDefinition] = []
	
	# Collect from units
	for unit in units.values():
		if _is_valid_for_pool(unit):
			pool.append(unit)
			
	# Collect from items
	for item in items.values():
		if _is_valid_for_pool(item):
			pool.append(item)
			
	return pool

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

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = "res://decks/" + file_name
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
								
								# Store card definition globally (last write wins if duplicates exist across decks, 
								# which is acceptable for now or we could namespace them)
								flashcard_definitions[card_id] = {
									"question": card.question,
									"answer": card.answer,
									"explanation": card.get("explanation", "")
								}
						
						# Store deck definition
						deck_definitions[deck_id] = {
							"deck_id": deck_id,
							"display_name": deck_data.get("display_name", deck_id),
							"description": deck_data.get("description", ""),
							"card_ids": card_ids
						}
				else:
					pass
			else:
				pass
		file_name = dir.get_next()


func _is_exported_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".res") or file_name.ends_with(".tres.remap") or file_name.ends_with(".res.remap")


func _get_resource_load_name(file_name: String) -> String:
	if file_name.ends_with(".remap"):
		return file_name.trim_suffix(".remap")
	return file_name
