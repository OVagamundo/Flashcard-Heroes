extends Node

# FSM States
enum { NO_RUN, IN_RUN, AWAITING_BATTLE_RESULT, GAME_OVER }

var _state: int = NO_RUN

# Run State Properties
var current_day: int
var gold: int
var hero_instance: GachaBallInstance
var master_run_gacha_pool: Dictionary = {1: [], 2: [], 3: []} # Tier -> Array[GachaBallInstance]
var active_trinkets: Array[Resource] # Array[TrinketDefinition]

# Meta-Progression Properties (loaded from SaveManager)
var unlocked_hero_ids: Array[StringName]
var unlocked_deck_ids: Array[StringName]
var unlocked_gachaball_ids: Array[StringName]
var unlocked_trinket_ids: Array[StringName]
var unlocked_merge_recipe_ids: Array[StringName]

func _ready() -> void:
	# Load meta-progression
	var meta_data = SaveManager.load_meta_data()
	if not meta_data.is_empty():
		unlocked_hero_ids = meta_data.get("unlocked_hero_ids", [])
		# ... load other unlocked arrays ...

	# Connect to game flow signals
	EventBus.new_run_requested.connect(_on_new_run_requested)
	EventBus.battle_start_requested.connect(_on_battle_start_requested)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)

func _on_new_run_requested(hero_def_id: StringName, deck_def_id: StringName) -> void:
	if _state != NO_RUN and _state != GAME_OVER:
		return

	# Reset run state
	current_day = 1
	gold = 10 # Starting gold
	master_run_gacha_pool = {1: [], 2: [], 3: []}
	active_trinkets = []

	# Create hero instance
	var hero_def = Database.get_gachaball_definition(hero_def_id)
	if hero_def:
		hero_instance = GachaBallInstance.new()
		hero_instance.initialize(hero_def)
		hero_instance.current_location_state = GachaBallInstance.LocationState.IN_PLAYER_LINEUP
	else:
		print("Error: Could not find hero definition for id: " + hero_def_id)
		return

	_state = IN_RUN
	EventBus.emit_signal("run_started")
	EventBus.emit_signal("gold_updated", gold)
	EventBus.emit_signal("hero_hp_updated", hero_instance.current_hp, hero_instance.get_reference_hp())
	EventBus.emit_signal("day_updated", current_day)
	EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")

func _on_battle_start_requested(encounter_def: Resource) -> void:
	if _state != IN_RUN:
		return

	_state = AWAITING_BATTLE_RESULT
	var battle_data = _prepare_battle_data(encounter_def)
	# The container is found by the SceneManager via a group name in Main.tscn
	var main_scene_root = get_tree().get_first_node_in_group("main_scene_root")
	if main_scene_root:
		var container = main_scene_root.find_child("DynamicContentArea")
		EventBus.load_scene_in_container_requested.emit("res://scenes/Battle.tscn", container)
		EventBus.initiate_battle.emit(battle_data)
	else:
		print("Error: Could not find DynamicContentArea to load battle scene.")

func _prepare_battle_data(encounter_def: Resource) -> Dictionary:
	var player_pool_copy = {}
	for tier in master_run_gacha_pool:
		player_pool_copy[tier] = []
		for unit_instance in master_run_gacha_pool[tier]:
			player_pool_copy[tier].append(unit_instance.create_battle_copy())

	return {
		"player_hero": hero_instance.create_battle_copy(),
		"player_pool": player_pool_copy,
		"encounter_def": encounter_def
	}

func _on_battle_won() -> void:
	_state = IN_RUN
	# Give rewards, etc.
	# For now, just load the path choice scene again.
	var main_scene_root = get_tree().get_first_node_in_group("main_scene_root")
	if main_scene_root:
		var container = main_scene_root.find_child("DynamicContentArea")
		EventBus.load_scene_in_container_requested.emit("res://scenes/PathChoice.tscn", container)

func _on_battle_lost() -> void:
	_state = GAME_OVER
	EventBus.emit_signal("run_ended", false)
	# Transition to a game over screen

func package_run_data() -> Dictionary:
	# This needs to serialize GachaBallInstances properly.
	# For now, it's a simplified version.
	return {
		"current_day": current_day,
		"gold": gold,
		# hero_instance and master_run_gacha_pool require a custom serialization method
		# to convert GachaBallInstance objects to dictionaries.
	}

func reconstruct_run_from_data(data: Dictionary) -> void:
	# This needs to deserialize GachaBallInstances properly.
	# For now, it's a simplified version.
	current_day = data.get("current_day", 1)
	gold = data.get("gold", 0)
	_state = IN_RUN

	# Re-emit signals to update UI
	EventBus.emit_signal("run_started")
	EventBus.emit_signal("gold_updated", gold)
	# ... emit other signals ...
	EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")
