# res://scripts/RunState.gd
class_name RunState
extends Resource

## The player's current run state, including all persistent progress.

## Player's current gold.
@export var gold: int = 0

## Current stage in the run.
@export var current_stage: int = 1

## Current battle in the stage.
@export var current_battle: int = 1

## The player's permanent collection of GachaBalls.
## Organized by tier: {0: [GachaBallInstance], 1: [...], 2: [...], 3: [...]} 
@export var run_inventory: Dictionary = {
	0: [], # Hero
	1: [], # Tier 1
	2: [], # Tier 2
	3: []  # Tier 3
}


## The player's hero instance for the current battle.
var hero_instance: GachaBallInstance

## Gacha pools for the current battle, generated from the run inventory.
var battle_gacha_pools: Dictionary = {}

## The discard pile for the current battle.
var battle_discard_pile: Array[GachaBallInstance] = []


## Populates the battle-specific gacha pools from the run inventory.
func create_battle_pools() -> void:
	# TODO: Implement pool creation logic based on TDD.
	# This will involve creating battle copies of units and items.
	pass

## Adds a GachaBallInstance to the battle discard pile.
func add_to_discard_pile(ball: GachaBallInstance) -> void:
	battle_discard_pile.append(ball)


## Resets the run state to the initial state for a new run.
func start_new_run() -> void:
	gold = 10  # Starting gold
	current_stage = 1
	current_battle = 1
	run_inventory = {0: [], 1: [], 2: [], 3: []}

	# Helper lambda to create and add an instance to the correct tier.
	var add_instance = func(id: StringName):
		var definition: GachaBallDefinition = Database.units.get(id, Database.items.get(id))
		if definition:
			var instance = GachaBallInstance.new()
			instance.initialize(definition)
			if definition.tier in run_inventory:
				run_inventory[definition.tier].append(instance)
			else:
				printerr("RunState: Invalid tier %d for definition %s" % [definition.tier, id])
		else:
			printerr("RunState: Could not find definition for id: ", id)

	# Per MVP TDD: 1x Hero
	add_instance.call(&"hero")
	
	# Per MVP TDD: 2x of each defined unit and item for testing.
	var ids_to_add: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d",
		&"item_t1_a", &"item_t1_b", &"item_t2_c", &"item_t3_d"
	]
	
	for id in ids_to_add:
		add_instance.call(id)
		add_instance.call(id) # Add a second time
	
	print("Initial run inventory created.")
