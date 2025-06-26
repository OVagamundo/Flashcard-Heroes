<!-- Original: scripts/RunState.gd -->

```gdscript
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
	1: [], # Tier 1
	2: [], # Tier 2
	3: []  # Tier 3
}

## The player's dedicated Hero instance. Not part of the gacha inventory.
@export var hero_instance: GachaBallInstance


## Resets the run state to the initial state for a new run.
func start_new_run() -> void:
	gold = 10  # Starting gold
	current_stage = 1
	current_battle = 1
	# Initialize with no tier 0, as the Hero is separate.
	run_inventory = {1: [], 2: [], 3: []}

	# Helper lambda to create and add an instance to the correct tier.
	var add_instance = func(id: StringName):
		var definition: GachaBallDefinition = Database.units.get(id, Database.items.get(id))
		if definition:
			var instance = GachaBallInstance.new()
			instance.initialize(definition)
			if definition.tier in run_inventory:
				run_inventory[definition.tier].append(instance)
			else:
				# This error should not happen for non-hero units.
				printerr("RunState: Invalid tier %d for definition %s" % [definition.tier, id])
		else:
			printerr("RunState: Could not find definition for id: ", id)

	# Per MVP TDD: 2x of each defined unit and item for testing.
	var ids_to_add: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_b", &"unit_t2_c", &"unit_t3_d",
		&"item_t1_a", &"item_t1_b", &"item_t2_c", &"item_t3_d"
	]
	
	for id in ids_to_add:
		add_instance.call(id)
		add_instance.call(id) # Add a second time
	
	# Create and assign the Hero instance to its dedicated property.
	var hero_def: GachaBallDefinition = Database.units.get(&"hero")
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
	else:
		printerr("RunState: CRITICAL - Could not find 'hero' definition in Database.")

	print("Initial run inventory created.")

```