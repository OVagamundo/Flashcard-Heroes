<!-- Original: scripts/EncounterGenerator.gd -->

```gdscript
# res://scripts/EncounterGenerator.gd
extends Node

const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
const GachaBallDefinition = preload("res://scripts/GachaBallDefinition.gd")

## A stateless service that generates dynamic encounters using the "Constrained Random Build" algorithm.
## Implements the TDD V7.0 specification for encounter generation.

## Generates a complete encounter based on the given budget.
## @param budget: int - The total budget to spend on units and items
## @return EncounterDefinition - A complete encounter definition with enemy placements
func generate_encounter(budget: int) -> EncounterDefinition:

	# Validate input
	if budget <= 0:
		return _create_fallback_encounter()
	
	# --- Phase 1: Setup & Data Pooling ---
	# 1. Get all non-hero GachaBallDefinitions from the Database singleton.
	# 2. Separate them into two pools: `available_units` and `available_items`.
	#    Sort both pools by cost in ascending order to help the algorithm.
	var all_defs = Database.units.values() + Database.items.values()

	var available_units: Array[GachaBallDefinition] = []
	var available_items: Array[GachaBallDefinition] = []
	for d in all_defs:
		if d.id == &"hero" or d.id == &"enemy_hero": continue
		if d.category == &"UNIT":
			available_units.append(d)
		elif d.category == &"ITEM":
			available_items.append(d)
	

	
	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	available_items.sort_custom(func(a, b): return a.cost < b.cost)

	# --- Phase 2 & 3: Optimized Build Loop ---
	# This combines the mandatory spend and flexible spend into a single, robust process.
	var best_build = {"units": [], "items": [], "spent": 0}
	
	for _i in range(10): # Max 10 attempts to find a perfect build
		var purchased_units: Array[GachaBallDefinition] = []
		var purchased_items: Array[GachaBallDefinition] = []
		var spent_budget = 0
		
		# Phase 2: Mandatory Unit Spend
		var min_unit_spend = floor(budget / 2.0)
		while spent_budget < min_unit_spend and purchased_units.size() < 6:
			var affordable_units = available_units.filter(func(u): return u.cost <= (budget - spent_budget))
			if affordable_units.is_empty(): break
			var unit_to_add = affordable_units.pick_random()
			purchased_units.append(unit_to_add)
			spent_budget += unit_to_add.cost
		
		# Phase 3: Flexible Spending
		while spent_budget < budget:
			var possible_purchases: Array[GachaBallDefinition] = []
			var remaining_budget = budget - spent_budget
			
			# Check for affordable units
			if purchased_units.size() < 6:
				possible_purchases.append_array(available_units.filter(func(u): return u.cost <= remaining_budget))
			
			# Check for affordable items
			var total_item_slots = 0
			for u in purchased_units: total_item_slots += u.item_slot_count
			if purchased_items.size() < total_item_slots:
				possible_purchases.append_array(available_items.filter(func(i): return i.cost <= remaining_budget))

			if possible_purchases.is_empty(): break # Stuck, can't buy anything else
			
			var purchase = possible_purchases.pick_random()
			if purchase.category == &"UNIT":
				purchased_units.append(purchase)
			else:
				purchased_items.append(purchase)
			spent_budget += purchase.cost

				# Store this result if it's better than the last one
		if spent_budget > best_build.spent:
			best_build = {"units": purchased_units, "items": purchased_items, "spent": spent_budget}


		# If we found a perfect build, exit early
		if spent_budget == budget:
			break
		
	# --- Phase 4: Final Assembly ---
	var final_encounter = EncounterDefinition.new()
	final_encounter.id = "dynamic_encounter_%d" % Time.get_unix_time_from_system()
	
	var efficiency = (float(best_build.spent) / float(budget)) * 100.0

	
	# Place units
	var available_positions = [0, 1, 2, 3, 4, 5]
	available_positions.shuffle()
	for unit_def in best_build.units:
		var pos = available_positions.pop_front()
		var placement = {"id": unit_def.id, "position": pos, "items": []}
		final_encounter.enemy_placements.append(placement)
		
	# Equip items randomly
	for item_def in best_build.items:
		var possible_parents = final_encounter.enemy_placements.filter(func(p): 
			var unit_def = Database.get_definition(p.id)
			return p.items.size() < unit_def.item_slot_count
		)
		if possible_parents.is_empty(): break # No more slots
		possible_parents.pick_random().items.append(item_def.id)
	
	# Validate the final encounter
	if not _validate_encounter(final_encounter):
		return _create_fallback_encounter()
		
	return final_encounter

## Creates a fallback encounter when generation fails.
## @return EncounterDefinition - A basic encounter with minimal units
func _create_fallback_encounter() -> EncounterDefinition:
	var fallback = EncounterDefinition.new()
	fallback.id = "fallback_encounter_%d" % Time.get_unix_time_from_system()
	
	# Add a basic enemy if available
	var basic_enemy = Database.get_definition(&"Tier1unitA")
	if is_instance_valid(basic_enemy):
		var placement = {"id": basic_enemy.id, "position": 0, "items": []}
		fallback.enemy_placements.append(placement)
	
	return fallback

## Validates that the generated encounter is valid.
## @param encounter: EncounterDefinition - The encounter to validate
## @return bool - True if the encounter is valid
func _validate_encounter(encounter: EncounterDefinition) -> bool:
	if not is_instance_valid(encounter):
		return false
	
	if encounter.enemy_placements.is_empty():
		return false
	
	# Check that all units have valid definitions
	for placement in encounter.enemy_placements:
		var unit_def = Database.get_definition(placement.id)
		if not is_instance_valid(unit_def):
			return false
		
		# Check that items don't exceed unit's item slots
		if placement.items.size() > unit_def.item_slot_count:
			return false
	
	return true

## Calculates the total power of an encounter for debugging purposes.
## @param encounter: EncounterDefinition - The encounter to analyze
## @return Dictionary - Analysis data including total power, unit count, etc.
func analyze_encounter(encounter: EncounterDefinition) -> Dictionary:
	var analysis = {
		"unit_count": 0,
		"item_count": 0,
		"total_power": 0,
		"total_hp": 0,
		"total_cost": 0
	}
	
	for placement in encounter.enemy_placements:
		var unit_def = Database.get_definition(placement.id)
		if is_instance_valid(unit_def):
			analysis.unit_count += 1
			analysis.total_power += unit_def.base_pwr
			analysis.total_hp += unit_def.base_hp
			analysis.total_cost += unit_def.cost
			
			# Add item stats
			for item_id in placement.items:
				var item_def = Database.get_definition(item_id)
				if is_instance_valid(item_def):
					analysis.item_count += 1
					analysis.total_cost += item_def.cost
					analysis.total_power += item_def.bonus_pwr
					analysis.total_hp += item_def.bonus_hp
	
	return analysis 
```