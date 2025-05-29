extends Node

# UnitLibrary.gd - Autoload Singleton
# Stores all predefined UnitData resources and merge recipes.

var _unit_database: Dictionary = {}
# Stores merge recipes as ["type1_type2"] = result_unit_id
var _merge_recipes: Dictionary = {}

func _ready() -> void:
	_initialize_database()
	_initialize_merge_recipes()

func _initialize_database() -> void:
	# Hero Unit
	var hero_data := UnitData.new()
	hero_data.id = "hero"
	hero_data.display_name = "Hero"
	hero_data.max_hp = 10
	hero_data.pwr = 2
	hero_data.tier = 0 # Special tier for Hero, distinct from gacha tiers
	hero_data.unit_type_tag = "hero"
	# hero_data.texture = preload("res://assets/units/hero.png") # Placeholder, assign actual texture
	_unit_database[hero_data.id] = hero_data

	# --- Tier 1 Units --- #
	# Offensive T1
	var offensive_t1_data := UnitData.new()
	offensive_t1_data.id = "offensive_t1"
	offensive_t1_data.display_name = "Offensive Unit T1"
	offensive_t1_data.max_hp = 1
	offensive_t1_data.pwr = 3
	offensive_t1_data.tier = 1
	offensive_t1_data.unit_type_tag = "offensive"
	# offensive_t1_data.texture = preload("res://assets/units/offensive_t1.png") # Placeholder
	_unit_database[offensive_t1_data.id] = offensive_t1_data

	# Defensive T1
	var defensive_t1_data := UnitData.new()
	defensive_t1_data.id = "defensive_t1"
	defensive_t1_data.display_name = "Defensive Unit T1"
	defensive_t1_data.max_hp = 3
	defensive_t1_data.pwr = 1
	defensive_t1_data.tier = 1
	defensive_t1_data.unit_type_tag = "defensive"
	# defensive_t1_data.texture = preload("res://assets/units/defensive_t1.png") # Placeholder
	_unit_database[defensive_t1_data.id] = defensive_t1_data

	# Utility T1
	var utility_t1_data := UnitData.new()
	utility_t1_data.id = "utility_t1"
	utility_t1_data.display_name = "Utility Unit T1"
	utility_t1_data.max_hp = 2
	utility_t1_data.pwr = 2
	utility_t1_data.tier = 1
	utility_t1_data.unit_type_tag = "utility"
	# utility_t1_data.texture = preload("res://assets/units/utility_t1.png") # Placeholder
	_unit_database[utility_t1_data.id] = utility_t1_data

	# Magical T1
	var magical_t1_data := UnitData.new()
	magical_t1_data.id = "magical_t1"
	magical_t1_data.display_name = "Magical Unit T1"
	magical_t1_data.max_hp = 1
	magical_t1_data.pwr = 3
	magical_t1_data.tier = 1
	magical_t1_data.unit_type_tag = "magical"
	# magical_t1_data.texture = preload("res://assets/units/magical_t1.png") # Placeholder
	_unit_database[magical_t1_data.id] = magical_t1_data

	# --- Tier 2 Units --- #
	# Berserker (Offensive + Offensive)
	var berserker_data := UnitData.new()
	berserker_data.id = "berserker_t2"
	berserker_data.display_name = "Berserker T2"
	berserker_data.max_hp = 2  # 1 + 1
	berserker_data.pwr = 8     # 3 + 3 + 20% bonus
	berserker_data.tier = 2
	berserker_data.unit_type_tag = "offensive"
	_unit_database[berserker_data.id] = berserker_data

	# Guardian (Defensive + Defensive)
	var guardian_data := UnitData.new()
	guardian_data.id = "guardian_t2"
	guardian_data.display_name = "Guardian T2"
	guardian_data.max_hp = 8   # 3 + 3 + 2 (30% bonus)
	guardian_data.pwr = 2      # 1 + 1
	guardian_data.tier = 2
	guardian_data.unit_type_tag = "defensive"
	_unit_database[guardian_data.id] = guardian_data

	# Archmage (Magical + Magical)
	var archmage_data := UnitData.new()
	archmage_data.id = "archmage_t2"
	archmage_data.display_name = "Archmage T2"
	archmage_data.max_hp = 2   # 1 + 1
	archmage_data.pwr = 8      # 3 + 3 + 25% bonus
	archmage_data.tier = 2
	archmage_data.unit_type_tag = "magical"
	_unit_database[archmage_data.id] = archmage_data

	# Cleric (Utility + Utility)
	var cleric_data := UnitData.new()
	cleric_data.id = "cleric_t2"
	cleric_data.display_name = "Cleric T2"
	cleric_data.max_hp = 5     # 2 + 2 + 1 (25% bonus)
	cleric_data.pwr = 4       # 2 + 2
	cleric_data.tier = 2
	cleric_data.unit_type_tag = "utility"
	_unit_database[cleric_data.id] = cleric_data

	# Battlemage (Offensive + Magical)
	var battlemage_data := UnitData.new()
	battlemage_data.id = "battlemage_t2"
	battlemage_data.display_name = "Battlemage T2"
	battlemage_data.max_hp = 1  # Average of 1 and 1
	battlemage_data.pwr = 7     # 3 + 3 + 15% bonus
	battlemage_data.tier = 2
	battlemage_data.unit_type_tag = "hybrid"
	_unit_database[battlemage_data.id] = battlemage_data

	# Paladin (Offensive + Defensive)
	var paladin_data := UnitData.new()
	paladin_data.id = "paladin_t2"
	paladin_data.display_name = "Paladin T2"
	paladin_data.max_hp = 4     # 1 + 3
	paladin_data.pwr = 4       # 3 + 1
	paladin_data.tier = 2
	paladin_data.unit_type_tag = "hybrid"
	_unit_database[paladin_data.id] = paladin_data

	# Warlock (Offensive + Utility)
	var warlock_data := UnitData.new()
	warlock_data.id = "warlock_t2"
	warlock_data.display_name = "Warlock T2"
	warlock_data.max_hp = 1     # Average of 1 and 2
	warlock_data.pwr = 6       # 3 + 2 + 10% bonus
	warlock_data.tier = 2
	warlock_data.unit_type_tag = "hybrid"
	_unit_database[warlock_data.id] = warlock_data

	# Warden (Defensive + Magical)
	var warden_data := UnitData.new()
	warden_data.id = "warden_t2"
	warden_data.display_name = "Warden T2"
	warden_data.max_hp = 5      # 3 + 1 + 1 (15% bonus)
	warden_data.pwr = 4        # 1 + 3
	warden_data.tier = 2
	warden_data.unit_type_tag = "hybrid"
	_unit_database[warden_data.id] = warden_data

	# Druid (Defensive + Utility)
	var druid_data := UnitData.new()
	druid_data.id = "druid_t2"
	druid_data.display_name = "Druid T2"
	druid_data.max_hp = 6      # 3 + 2 + 1 (20% bonus)
	druid_data.pwr = 2         # 1 + 1 (average)
	druid_data.tier = 2
	druid_data.unit_type_tag = "hybrid"
	_unit_database[druid_data.id] = druid_data

	# Elementalist (Magical + Utility)
	var elementalist_data := UnitData.new()
	elementalist_data.id = "elementalist_t2"
	elementalist_data.display_name = "Elementalist T2"
	elementalist_data.max_hp = 2  # 1 + 1
	elementalist_data.pwr = 6     # 3 + 2 + 15% bonus
	elementalist_data.tier = 2
	elementalist_data.unit_type_tag = "hybrid"
	_unit_database[elementalist_data.id] = elementalist_data

	print("UnitLibrary initialized with %s units." % _unit_database.size())

func _initialize_merge_recipes() -> void:
	# Clear any existing recipes
	_merge_recipes.clear()
	
	# Same type merges
	_merge_recipes["offensive_offensive"] = "berserker_t2"
	_merge_recipes["defensive_defensive"] = "guardian_t2"
	_merge_recipes["magical_magical"] = "archmage_t2"
	_merge_recipes["utility_utility"] = "cleric_t2"
	
	# Cross-type merges
	_merge_recipes["offensive_defensive"] = "paladin_t2"
	_merge_recipes["defensive_offensive"] = "paladin_t2"
	
	_merge_recipes["offensive_magical"] = "battlemage_t2"
	_merge_recipes["magical_offensive"] = "battlemage_t2"
	
	_merge_recipes["offensive_utility"] = "warlock_t2"
	_merge_recipes["utility_offensive"] = "warlock_t2"
	
	_merge_recipes["defensive_magical"] = "warden_t2"
	_merge_recipes["magical_defensive"] = "warden_t2"
	
	_merge_recipes["defensive_utility"] = "druid_t2"
	_merge_recipes["utility_defensive"] = "druid_t2"
	
	_merge_recipes["magical_utility"] = "elementalist_t2"
	_merge_recipes["utility_magical"] = "elementalist_t2"


func get_unit_data(id: String) -> UnitData:
	if _unit_database.has(id):
		return _unit_database[id]
	push_error("UnitLibrary: UnitData not found for id: %s" % id)
	return null


func get_gacha_pool_t1() -> Array[UnitData]:
	var pool: Array[UnitData] = []
	for unit_id in _unit_database:
		var unit_data: UnitData = _unit_database[unit_id]
		# Tier 1 units, excluding the hero
		if unit_data.tier == 1 and unit_data.unit_type_tag != "hero":
			pool.append(unit_data)
	return pool


func get_enemy_pool_t1() -> Array[UnitData]:
	# For now, the enemy pool is the same as the T1 gacha pool.
	# This can be diversified later if needed.
	var pool: Array[UnitData] = []
	for unit_id in _unit_database:
		var unit_data: UnitData = _unit_database[unit_id]
		# Tier 1 units, excluding the hero
		if unit_data.tier == 1 and unit_data.unit_type_tag != "hero":
			pool.append(unit_data)
	return pool

# Returns the result unit ID if the two unit types can be merged, otherwise returns empty string
func get_merge_result(unit1: UnitData, unit2: UnitData) -> String:
	if not unit1 or not unit2:
		return ""
		
	# Can't merge heroes or units of different tiers
	if unit1.unit_type_tag == "hero" or unit2.unit_type_tag == "hero":
		return ""
		
	if unit1.tier != unit2.tier:
		return ""
		
	# Create a sorted key to check merge recipes
	var type1 = unit1.unit_type_tag
	var type2 = unit2.unit_type_tag
	var key = ""
	
	# Ensure consistent ordering for the key
	if type1 < type2:
		key = type1 + "_" + type2
	else:
		key = type2 + "_" + type1
	
	return _merge_recipes.get(key, "")
