# res://scripts/Database.gd
extends Node

## Loads all .tres files from the resource directories into dictionaries
## on game startup for fast, cached access.

var units: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var items: Dictionary = {} # Key: StringName(id), Value: GachaBallDefinition
var recipes: Dictionary = {} # Key: StringName(id), Value: MergeRecipe
var decks: Dictionary = {} # Key: StringName(id), Value: FlashcardDeckDefinition

func _ready() -> void:
	# Populate all data dictionaries at startup.
	_load_resources_from_path("res://resources/units/", units)
	_load_resources_from_path("res://resources/items/", items)
	_load_resources_from_path("res://resources/recipes/", recipes)
	_load_resources_from_path("res://resources/decks/", decks)
	print("Database loaded.")
	print(" - Units: ", units.size())
	print(" - Items: ", items.size())
	print(" - Recipes: ", recipes.size())
	print(" - Decks: ", decks.size())

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
