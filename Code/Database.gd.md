<!-- Original: Database.gd -->

```gdscript
extends Node

# Dictionaries to store definitions by type and tier
var gachaball_definitions = {
	0: [], # For Hero / Special Tier 0 units
	1: [],
	2: [],
	3: []
}

func _ready():
	_load_gachaball_definitions()

func _load_gachaball_definitions():
	# Load all GachaBallDefinition resources from the resources directory
	var dir = DirAccess.open("res://resources/")
	if not dir:
		push_error("Failed to access resources directory")
		return
	
	# Load units
	_load_definitions_from_dir("units/")
	# Load items
	_load_definitions_from_dir("items/")
	
	# Log loaded definitions for debugging
	for tier in gachaball_definitions:
		print("Loaded ", gachaball_definitions[tier].size(), " tier ", tier, " gacha balls")

func _load_definitions_from_dir(dir_path: String):
	var dir = DirAccess.open("res://resources/" + dir_path)
	if not dir:
		push_error("Failed to access directory: ", dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource = load("res://resources/" + dir_path + file_name)
			if resource and resource is GachaBallDefinition:
				# Ensure the tier exists as a key, which it should if initialized correctly.
				# This also implicitly handles if a .tres file has a tier not in 0,1,2,3
				if gachaball_definitions.has(resource.tier):
					gachaball_definitions[resource.tier].append(resource)
				else:
					push_warning("GachaBallDefinition '%s' has uninitialized tier %d in Database.gd. Skipping." % [resource.id, resource.tier])
		file_name = dir.get_next()
	dir.list_dir_end()

# Get a random gacha ball definition of the specified tier
func get_random_gachaball(tier: int) -> GachaBallDefinition:
	if tier < 1 or tier > 3:
		push_error("Invalid tier: ", tier)
		return null
		
	var available = gachaball_definitions[tier]
	if available.is_empty():
		push_error("No gacha balls available for tier: ", tier)
		return null
		
	return available.pick_random().duplicate()

```