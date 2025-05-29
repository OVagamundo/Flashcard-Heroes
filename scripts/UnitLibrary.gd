extends Node

# UnitLibrary.gd - Autoload Singleton
# Stores all predefined UnitData resources.

var _unit_database: Dictionary = {}

func _ready() -> void:
	_initialize_database()

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

	print("UnitLibrary initialized with %s units." % _unit_database.size())


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
