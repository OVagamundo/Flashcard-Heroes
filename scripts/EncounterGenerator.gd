# res://scripts/EncounterGenerator.gd
extends Node

const EncounterDefinition = preload("res://scripts/data/EncounterDefinition.gd")
const GachaBallDefinition = preload("res://scripts/GachaBallDefinition.gd")

# Main public function. Generates a complete encounter based on a budget.
func generate_encounter(budget: int) -> EncounterDefinition:
	print("EncounterGenerator: Generating encounter with budget: ", budget)
	# --- Phase 1: Setup & Data Pooling ---
	# 1. Get all non-hero GachaBallDefinitions from the Database singleton.
	# 2. Separate them into two pools: `available_units` and `available_items`.
	#    Sort both pools by cost in ascending order to help the algorithm.
	var all_defs = Database.units.values() + Database.items.values()
	print("EncounterGenerator: Total definitions found: ", all_defs.size())
	print("EncounterGenerator: Database.units size: ", Database.units.size())
	print("EncounterGenerator: Database.items size: ", Database.items.size())
	var available_units: Array[GachaBallDefinition] = []
	var available_items: Array[GachaBallDefinition] = []
	for d in all_defs:
		if d.id == &"hero" or d.id == &"enemy_hero": continue
		if d.category == &"UNIT":
			available_units.append(d)
		elif d.category == &"ITEM":
			available_items.append(d)
	
	print("EncounterGenerator: Available units: ", available_units.size(), ", Available items: ", available_items.size())
	
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
		if spent_budget == budget: break
		
	# --- Phase 4: Final Assembly ---
	var final_encounter = EncounterDefinition.new()
	final_encounter.id = "dynamic_encounter_%d" % Time.get_unix_time_from_system()
	print("EncounterGenerator: Final build - Units: ", best_build.units.size(), ", Items: ", best_build.items.size(), ", Spent: ", best_build.spent)
	
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
		
	return final_encounter 