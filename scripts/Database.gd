# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition
var abilities: Dictionary = {} # Key: StringName(id), Value: AbilityDefinition

func _ready() -> void:
	# Load translations first
	_load_translations()
	
	# Populate all data dictionaries at startup.
	_load_resources_from_path("res://resources/units/", units)
	_load_resources_from_path("res://resources/items/", items)
	_load_resources_from_path("res://resources/recipes/", recipes)
	_load_resources_from_path("res://resources/decks/", decks)
	_load_resources_from_path("res://resources/abilities/", abilities)

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
