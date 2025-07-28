# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition
var abilities: Dictionary = {} # Key: StringName(id), Value: AbilityDefinition
## Flashcard definitions loaded from JSON files
var flashcard_definitions: Dictionary = {} # Key: StringName(id), Value: Dictionary (question, answer, explanation)

func _ready() -> void:
	# Load translations first
	_load_translations()
	
	# Populate all data dictionaries at startup.
	_load_resources_from_path("res://resources/units/", units)
	_load_resources_from_path("res://resources/items/", items)
	_load_resources_from_path("res://resources/recipes/", recipes)
	_load_resources_from_path("res://resources/abilities/", abilities)
	_load_reward_pool_definitions()
	
	# Load flashcard definitions from JSON
	_load_flashcard_definitions()

# -----------------------------
# Public API
# -----------------------------



# Returns an AbilityDefinition by id, or null.
func get_ability_definition(id: StringName) -> AbilityDefinition:
	var def = abilities.get(id)
	if def:
		return def
	printerr("Database: Ability definition for ID %s not found." % id)
	return null

## A helper function that iterates through a directory, loads each `.tres` file,
## and stores it in the provided dictionary, using the resource's `id` property as the key.
func _load_resources_from_path(path: String, dictionary: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		printerr("Database: Could not open directory at path: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path = path.path_join(file_name)
			var resource = load(resource_path)
			if is_instance_valid(resource):
				if "id" in resource:
					dictionary[resource.id] = resource
				else:
					printerr("Database: Resource at '%s' is missing the 'id' property." % resource_path)
			else:
				printerr("Database: Failed to load resource at path: ", resource_path)
		file_name = dir.get_next()

## Loads the translation CSV file and adds it to the TranslationServer
func _load_translations() -> void:
	# Create a new Translation resource
	var translation = Translation.new()
	translation.locale = "en"
	
	# Load the CSV file
	var csv_file = FileAccess.open("res://localization/game.csv", FileAccess.READ)
	if not csv_file:
		printerr("Database: Failed to open translation file: res://localization/game.csv")
		return
	
	# Skip the header line
	var header = csv_file.get_csv_line()
	
	# Read all translation pairs
	while not csv_file.eof_reached():
		var line = csv_file.get_csv_line()
		if line.size() >= 2:
			var key = line[0]
			var value = line[1]
			translation.add_message(key, value)
	
	csv_file.close()
	
	# Add the translation to the server
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("en")
	
	print("Database: Successfully loaded translations")
	print("Database: Testing translation - hero.name = ", tr("hero.name"))

## A central helper to find any GachaBallDefinition by its ID, regardless of category.
func get_definition(id: StringName) -> GachaBallDefinition:
	var definition = units.get(id)
	if definition:
		return definition
	
	definition = items.get(id)
	if definition:
		return definition
	

	printerr("Database: Definition for ID ", id, " not found in units/items.")
	return null

## A helper to get a GachaBallDefinition from a deck by card ID
func get_definition_from_deck(card_id: StringName) -> GachaBallDefinition:
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
	return hero_defs

## Returns metadata for all available decks
func get_all_deck_metadata() -> Array[Dictionary]:
	var deck_meta: Array[Dictionary] = []
	
	# For now, return the katakana deck metadata
	deck_meta.append({
		"deck_id": "katakana_main",
		"display_name": "Katakana",
		"description": "Learn Japanese katakana characters"
	})
	
	return deck_meta

## Loads all GachaBallDefinitions from the reward pool and adds them to the units/items dictionaries
## This ensures all possible reward definitions are properly registered with the database
func _load_reward_pool_definitions() -> void:
	var reward_pool = load("res://resources/reward_pool.tres")
	if not is_instance_valid(reward_pool):
		printerr("Database: Could not load or parse res://resources/reward_pool.tres")
		return

	for definition in reward_pool.definitions:
		if not is_instance_valid(definition):
			continue
		
		if definition.category == &"UNIT":
			if not units.has(definition.id):
				units[definition.id] = definition
		elif definition.category == &"ITEM":
			if not items.has(definition.id):
				items[definition.id] = definition

## Loads flashcard definitions from JSON files in the decks directory
func _load_flashcard_definitions() -> void:
	var dir = DirAccess.open("res://decks/")
	if not dir:
		printerr("Database: Could not open decks directory")
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
					if deck_data.has("cards"):
						for card in deck_data.cards:
							if card.has("id") and card.has("question") and card.has("answer"):
								flashcard_definitions[StringName(card.id)] = {
									"question": card.question,
									"answer": card.answer,
									"explanation": card.get("explanation", "")
								}
				else:
					printerr("Database: Failed to parse JSON file: ", file_path)
			else:
				printerr("Database: Failed to open file: ", file_path)
		file_name = dir.get_next()
