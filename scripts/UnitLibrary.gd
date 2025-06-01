extends Node

# UnitLibrary.gd - Autoload Singleton
# Loads and provides access to all UnitData resources and merge recipes.

var _unit_database: Dictionary = {}
# Stores merge recipes as ["type1_type2"] = result_unit_id
var _merge_recipes: Dictionary = {}

const UNITS_DIR = "res://resources/units/"

func _ready() -> void:
	_load_unit_resources()
	_initialize_merge_recipes()

func _get_texture_for_t1_unit(unit_type: String) -> Texture2D:
	var texture_path = "res://assets/sprites/units/"
	match unit_type:
		"offensive":
			texture_path += "01_offensive.png"
		"defensive":
			texture_path += "02_defensive.png"
		"utility":
			texture_path += "03_utility.png"
		"magical":
			texture_path += "04_magical.png"
		_:
			texture_path += "default.png"
	
	if ResourceLoader.exists(texture_path):
		return load(texture_path)
	else:
		push_warning("Texture not found: " + texture_path)
		return null

func _load_unit_resources() -> void:
	var dir = DirAccess.open(UNITS_DIR)
	if not dir:
		push_error("Failed to open units directory: " + UNITS_DIR)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path = UNITS_DIR + file_name
			var resource = load(resource_path)
			
			if resource is UnitData:
				var unit_data: UnitData = resource as UnitData
				
				# Automatically set texture for T1 units if not already set
				if unit_data.tier == 1 and unit_data.unit_type_tag in ["offensive", "defensive", "utility", "magical"]:
					var texture = _get_texture_for_t1_unit(unit_data.unit_type_tag)
					if texture:
						unit_data.texture = texture
				
				_unit_database[unit_data.id] = unit_data
				loaded_count += 1
			else:
				push_error("Resource is not a UnitData: " + file_name)
		file_name = dir.get_next()
	
	print("Loaded ", loaded_count, " unit resources")

	# Note: All unit data is now loaded from .tres resource files in the resources/units/ directory

func _initialize_merge_recipes() -> void:
	# Clear any existing recipes
	_merge_recipes.clear()
	
	# Same type merges
	_merge_recipes["offensive_offensive"] = "berserker_t2"
	_merge_recipes["defensive_defensive"] = "guardian_t2"
	_merge_recipes["utility_utility"] = "cleric_t2"
	_merge_recipes["magical_magical"] = "archmage_t2"
	
	# Cross-type merges (defensive + utility)
	_merge_recipes["defensive_utility"] = "druid_t2"
	_merge_recipes["utility_defensive"] = "druid_t2"
	
	# Cross-type merges (offensive + magical)
	_merge_recipes["offensive_magical"] = "battlemage_t2"
	_merge_recipes["magical_offensive"] = "battlemage_t2"
	
	# Cross-type merges (offensive + utility)
	_merge_recipes["offensive_utility"] = "spellblade_t2"
	_merge_recipes["utility_offensive"] = "spellblade_t2"
	
	# Cross-type merges (defensive + magical)
	_merge_recipes["defensive_magical"] = "warden_t2"
	_merge_recipes["magical_defensive"] = "warden_t2"
	
	# Cross-type merges (magical + utility)
	_merge_recipes["magical_utility"] = "elementalist_t2"
	_merge_recipes["utility_magical"] = "elementalist_t2"

# Returns an array of all tier 1 unit data for the gacha system
func get_gacha_pool_t1() -> Array[UnitData]:
	var t1_units: Array[UnitData] = []
	for unit_id in _unit_database:
		var unit_data: UnitData = _unit_database[unit_id]
		if unit_data.tier == 1:  # Only include tier 1 units in the gacha pool
			t1_units.append(unit_data)
	return t1_units

# Returns an array of all tier 1 unit data for enemy generation
func get_enemy_pool_t1() -> Array[UnitData]:
	# For now, we'll use the same pool as the gacha, but this can be customized
	return get_gacha_pool_t1()

# Gets a unit data by its ID
func get_unit_data(unit_id: String) -> UnitData:
	if _unit_database.has(unit_id):
		return _unit_database[unit_id]
	push_error("UnitLibrary.get_unit_data(): No unit found with id: " + str(unit_id))
	return null

# Gets the result of merging two unit types
func get_merge_result(type1: String, type2: String) -> String:
	var key1 = type1 + "_" + type2
	var key2 = type2 + "_" + type1
	
	if _merge_recipes.has(key1):
		return _merge_recipes[key1]
	return _merge_recipes.get(key2, "")

# Gets the result unit ID if the two unit types can be merged, otherwise returns empty string
func get_merge_result_for_units(unit1: UnitData, unit2: UnitData) -> String:
	if not unit1 or not unit2:
		return ""
		
	# Can't merge heroes or units of different tiers
	if unit1.unit_type_tag == "hero" or unit2.unit_type_tag == "hero":
		return ""
		
	if unit1.tier != unit2.tier:
		return ""
		
	return get_merge_result(unit1.unit_type_tag, unit2.unit_type_tag)
