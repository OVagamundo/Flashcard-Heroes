# res://scripts/RunState.gd
class_name RunState
extends Resource

## The player's current run state, including all persistent progress.

const INVENTORY_TIER_SIZE = 16

@export var gold: int = 0
@export var current_stage: int = 1
@export var current_battle: int = 1

@export var run_inventory: Dictionary = {
	1: [], 2: [], 3: []
}

@export var hero_instance: GachaBallInstance

func start_new_run() -> void:
	gold = 10
	current_stage = 1
	current_battle = 1
	
	run_inventory = { 1: [], 2: [], 3: [] }
	run_inventory[1].resize(INVENTORY_TIER_SIZE)
	run_inventory[1].fill(null)
	run_inventory[2].resize(INVENTORY_TIER_SIZE)
	run_inventory[2].fill(null)
	run_inventory[3].resize(INVENTORY_TIER_SIZE)
	run_inventory[3].fill(null)

	# BUGFIX: Corrected typo from 'item_2_c' to 'item_t2_c'.
	var items_to_add: Array[StringName] = [
		&"unit_t1_a", &"unit_t1_a", &"unit_t1_b", &"unit_t1_b",
		&"item_t1_a", &"item_t1_a", &"item_t1_b", &"item_t1_b",
		&"unit_t2_c", &"unit_t2_c", &"item_t2_c", &"item_t2_c",
		&"unit_t3_d", &"unit_t3_d", &"item_t3_d", &"item_t3_d"
	]
	
	for id in items_to_add:
		var definition: GachaBallDefinition = Database.get_definition(id)
		if not definition:
			printerr("RunState: Could not find definition for id: ", id)
			continue
			
		var tier_grid = run_inventory.get(definition.tier)
		if tier_grid is Array:
			var empty_slot_index = tier_grid.find(null)
			if empty_slot_index != -1:
				var instance = GachaBallInstance.new()
				instance.initialize(definition)
				tier_grid[empty_slot_index] = instance
			else:
				printerr("RunState: No empty slots in tier %d for item %s" % [definition.tier, id])
		else:
			printerr("RunState: Invalid tier %d for definition %s" % [definition.tier, id])

	var hero_def: GachaBallDefinition = Database.get_definition(&"hero")
	if hero_def:
		self.hero_instance = GachaBallInstance.new()
		self.hero_instance.initialize(hero_def)
	else:
		printerr("RunState: CRITICAL - Could not find 'hero' definition in Database.")

	print("RunState initialized with TDD-compliant data grids.")
