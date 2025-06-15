# File: res://scripts/Loadout.gd
extends Control

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	# Define our starting hero and their initial gachaballs.
	# In a full game, this data would come from the hero the player selects in the UI.
	var hero_def: GachaBallDefinition = load("res://resources/units/hero.tres")
	
	# The starting_gachas array MUST be explicitly typed to match the function signature in RunState.
	var starting_gachas: Array[GachaBallDefinition] = [
		# Tier 1 (6 total: 3 units, 3 items)
		load("res://resources/units/tier1_warrior.tres"),
		load("res://resources/units/tier1_warrior.tres"),
		load("res://resources/units/tier1_warrior.tres"),
		load("res://resources/items/tier1_potion.tres"),
		load("res://resources/items/tier1_potion.tres"),
		load("res://resources/items/tier1_potion.tres"),
		# Tier 2 (4 total: 2 units, 2 items)
		load("res://resources/units/tier2_knight.tres"),
		load("res://resources/units/tier2_knight.tres"),
		load("res://resources/items/tier2_sword.tres"),
		load("res://resources/items/tier2_sword.tres"),
		# Tier 3 (2 total: 1 unit, 1 item)
		load("res://resources/units/tier3_paladin.tres"),
		load("res://resources/items/tier3_amulet.tres")
	]

	# Use our global RunState singleton to set up the run's initial state.
	# This populates the hero_instance and master_run_pool variables in RunState.
	RunState.start_new_run(hero_def, starting_gachas)

	# After setup is complete, request the scene change to the main game.
	EventBus.change_scene_to_file_requested.emit("res://scenes/Main.tscn")
