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
	# 2. Separate them into pools: units, items, and trinkets.
	# 3. Sort pools by cost in ascending order to help the algorithm.
	var all_defs = Database.units.values() + Database.items.values()

	var available_units: Array[GachaBallDefinition] = []
	var available_items: Array[GachaBallDefinition] = []
	var available_trinkets: Array = [] # TrinketDefinition array
	
	for d in all_defs:
		# Skip hero units - check both ID and is_hero property
		if d.id == &"hero" or d.id == &"enemy_hero": continue
		if d.is_hero: continue # Exclude any unit marked as hero (e.g., hero_timekeeper)
		# Skip boss units from regular encounter generation
		if String(d.id).begins_with("boss_"): continue
		if d.category == &"UNIT":
			available_units.append(d)
		elif d.category == &"ITEM":
			available_items.append(d)
	
	# Add non-player-exclusive trinkets to the pool
	for trinket in Database.trinkets.values():
		if not trinket.is_player_exclusive:
			available_trinkets.append(trinket)

	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	available_items.sort_custom(func(a, b): return a.cost < b.cost)
	# Safeguard: some trinkets may not have cost property if resources weren't re-saved
	available_trinkets.sort_custom(func(a, b):
		var cost_a = a.cost if "cost" in a else 10
		var cost_b = b.cost if "cost" in b else 10
		return cost_a < cost_b
	)

	# --- Phase 2 & 3: Optimized Build Loop with Weighted Selection ---
	# Priority weights: Units (3) > Items (2) > Trinkets (1)
	var best_build: Dictionary = {"units": [], "items": [], "trinkets": [], "spent": 0}
	
	for _i in range(10): # Max 10 attempts to find a perfect build
		var purchased_units: Array[GachaBallDefinition] = []
		var purchased_items: Array[GachaBallDefinition] = []
		var purchased_trinkets: Array = [] # TrinketDefinition array
		var spent_budget = 0
		
		# Phase 2: Mandatory Unit Spend (at least 50% on units)
		var min_unit_spend = floor(budget / 2.0)
		while spent_budget < min_unit_spend and purchased_units.size() < 5:
			var affordable_units = available_units.filter(func(u): return u.cost <= (budget - spent_budget))
			if affordable_units.is_empty(): break
			var unit_to_add = affordable_units.pick_random()
			purchased_units.append(unit_to_add)
			spent_budget += unit_to_add.cost
		
		# Phase 3: Flexible Spending with Weighted Selection
		while spent_budget < budget:
			var remaining_budget = budget - spent_budget
			
			# Build weighted purchase lists
			var weighted_purchases: Array = [] # Array of {def, weight, type}
			
			# Check for affordable units (weight 3)
			if purchased_units.size() < 5:
				for u in available_units:
					if u.cost <= remaining_budget:
						weighted_purchases.append({"def": u, "weight": 3, "type": "unit"})
			
			# Check for affordable items (weight 2)
			var total_item_slots = 0
			for u in purchased_units: total_item_slots += u.item_slot_count
			if purchased_items.size() < total_item_slots:
				for item in available_items:
					if item.cost <= remaining_budget:
						weighted_purchases.append({"def": item, "weight": 2, "type": "item"})
			
			# Check for affordable trinkets (weight 1, max 1 trinket per encounter)
			if purchased_trinkets.size() < 1:
				for trinket in available_trinkets:
					var trinket_cost = trinket.cost if "cost" in trinket else 10
					if trinket_cost <= remaining_budget:
						weighted_purchases.append({"def": trinket, "weight": 1, "type": "trinket"})

			if weighted_purchases.is_empty(): break # Stuck, can't buy anything else
			
			# Weighted random selection
			var total_weight = 0
			for p in weighted_purchases: total_weight += p.weight
			var roll = randi() % total_weight
			var cumulative = 0
			var selected = weighted_purchases[0]
			for p in weighted_purchases:
				cumulative += p.weight
				if roll < cumulative:
					selected = p
					break
			
			# Add the selected purchase
			if selected.type == "unit":
				purchased_units.append(selected.def)
			elif selected.type == "item":
				purchased_items.append(selected.def)
			else: # trinket
				purchased_trinkets.append(selected.def)
			# Safeguard: trinkets might not have cost property
			var def_cost = selected.def.cost if "cost" in selected.def else 10
			spent_budget += def_cost

		# Optimization: Explicitly try to fill small gaps in the budget
		if spent_budget < budget:
			var remaining = budget - spent_budget
			# Try to find a cheap item or unit that fits exactly or close to it
			var fillers = available_items.filter(func(i): return i.cost <= remaining)
			if fillers.is_empty() and purchased_units.size() < 5:
				fillers = available_units.filter(func(u): return u.cost <= remaining)
			
			if not fillers.is_empty():
				fillers.sort_custom(func(a, b): return a.cost > b.cost) # Try most expensive first
				var filler = fillers[0]
				if filler.category == &"UNIT":
					purchased_units.append(filler)
				else:
					# Only add item if we have slots
					var slots = 0
					for u in purchased_units: slots += u.item_slot_count
					if purchased_items.size() < slots:
						purchased_items.append(filler)
						spent_budget += filler.cost

		# Store this result if it's better than the last one
		if spent_budget > best_build.spent:
			best_build = {"units": purchased_units, "items": purchased_items, "trinkets": purchased_trinkets, "spent": spent_budget}


		# If we found a perfect build, exit early
		if spent_budget == budget:
			break
		
	# --- Phase 4: Final Assembly ---
	var final_encounter = EncounterDefinition.new()
	final_encounter.id = "dynamic_encounter_%d" % Time.get_unix_time_from_system()
	
	var efficiency = (float(best_build.spent) / float(budget)) * 100.0

	
	# Place units
	var available_positions = [0, 1, 2, 3, 4]
	available_positions.shuffle()
	for unit_def in best_build.units:
		var pos = available_positions.pop_front()
		var placement: Dictionary = {"id": unit_def.id, "position": pos, "items": []}
		final_encounter.enemy_placements.append(placement)
		
	# Equip items randomly
	for item_def in best_build.items:
		var possible_parents: Array[Dictionary] = []
		for p in final_encounter.enemy_placements:
			var unit_def = Database.get_definition(p.id)
			if p.items.size() < unit_def.item_slot_count:
				possible_parents.append(p)
		if possible_parents.is_empty(): break # No more slots
		possible_parents.pick_random().items.append(item_def.id)
	
	# Assign trinkets to the encounter
	for trinket_def in best_build.trinkets:
		final_encounter.enemy_trinket_ids.append(trinket_def.id)
	
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
	# Robustness: Look up a valid Tier 1 unit instead of hardcoding ID
	var basic_enemy = Database.get_definition(&"Tier1unitA")
	if not is_instance_valid(basic_enemy):
		# Try to find ANY unit
		var all_units = Database.units.values()
		if not all_units.is_empty():
			basic_enemy = all_units[0]
			
	if is_instance_valid(basic_enemy):
		var placement: Dictionary = {"id": basic_enemy.id, "position": 0, "items": []}
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
	var analysis: Dictionary = {
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

## Generates a boss encounter for the given boss level.
## The boss is placed at position 4 (back of lineup) and remaining budget is used for support units.
## @param boss_level: int - The boss number (1-5)
## @param total_budget: int - The total encounter budget (day * 5)
## @return EncounterDefinition - An encounter with the boss at the back and units filling remaining slots
func generate_boss_encounter(boss_level: int, total_budget: int) -> EncounterDefinition:
	# Get the boss definition
	var boss_id: StringName = &"boss_%d" % boss_level
	var boss_def = Database.get_definition(boss_id)
	if not is_instance_valid(boss_def):
		push_error("Boss definition not found: %s" % boss_id)
		return _create_fallback_encounter()
	
	# Calculate remaining budget after boss cost
	var remaining_budget: int = total_budget - boss_def.cost
	
	# Generate supporting units with remaining budget (max 4 units since boss takes one slot)
	var support_encounter: EncounterDefinition = null
	if remaining_budget > 0:
		support_encounter = _generate_support_units(remaining_budget, 4)
	
	# Create the final boss encounter
	var final_encounter = EncounterDefinition.new()
	final_encounter.id = "boss_encounter_%d_%d" % [boss_level, Time.get_unix_time_from_system()]
	
	# Add support units first (they take positions 0-3)
	if support_encounter != null:
		for placement in support_encounter.enemy_placements:
			final_encounter.enemy_placements.append(placement)
		# Also copy any trinkets from support encounter
		for trinket_id in support_encounter.enemy_trinket_ids:
			final_encounter.enemy_trinket_ids.append(trinket_id)
	
	# Place boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	final_encounter.enemy_placements.append(boss_placement)
	
	# Attempt to equip items on boss if there's leftover budget and boss has slots
	if remaining_budget > 0 and boss_def.item_slot_count > 0:
		_try_equip_items_to_boss(boss_placement, remaining_budget, boss_def.item_slot_count, support_encounter)
	return final_encounter

## Generates an elite encounter using a random boss unit.
## Similar to boss encounters but picks a random boss based on player progress.
## @param total_budget: int - The total encounter budget (after 1.5x elite multiplier applied)
## @return EncounterDefinition - An encounter with a boss unit and support units
func generate_elite_encounter(total_budget: int) -> EncounterDefinition:
	# Pick a random boss (1-5) that makes sense for the budget
	# For early game, prefer lower boss levels; for late game, allow higher
	var max_boss_level: int = mini(5, maxi(1, total_budget / 10))
	var elite_level: int = randi_range(1, max_boss_level)
	
	var boss_id: StringName = &"boss_%d" % elite_level
	var boss_def = Database.get_definition(boss_id)
	if not is_instance_valid(boss_def):
		push_error("Elite boss definition not found: %s" % boss_id)
		return _create_fallback_encounter()
	
	# Calculate remaining budget after boss cost
	var remaining_budget: int = total_budget - boss_def.cost
	
	# Generate supporting units with remaining budget (max 4 units since boss takes one slot)
	var support_encounter: EncounterDefinition = null
	if remaining_budget > 0:
		support_encounter = _generate_support_units(remaining_budget, 4)
	
	# Create the final elite encounter
	var final_encounter = EncounterDefinition.new()
	final_encounter.id = "elite_encounter_%d_%d" % [elite_level, Time.get_unix_time_from_system()]
	
	# Add support units first (they take positions 0-3)
	if support_encounter != null:
		for placement in support_encounter.enemy_placements:
			final_encounter.enemy_placements.append(placement)
		# Also copy any trinkets from support encounter
		for trinket_id in support_encounter.enemy_trinket_ids:
			final_encounter.enemy_trinket_ids.append(trinket_id)
	
	# Place boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	final_encounter.enemy_placements.append(boss_placement)
	
	# Attempt to equip items on boss if there's leftover budget and boss has slots
	if remaining_budget > 0 and boss_def.item_slot_count > 0:
		_try_equip_items_to_boss(boss_placement, remaining_budget, boss_def.item_slot_count, support_encounter)
	
	return final_encounter

## Generates support units for a boss encounter (excludes boss units).
## @param budget: int - Budget for support units
## @param max_units: int - Maximum number of units to generate
## @return EncounterDefinition - An encounter with support units only
func _generate_support_units(budget: int, max_units: int) -> EncounterDefinition:
	if budget <= 0:
		return null
	
	# Get available units, items, and trinkets (exclude heroes and bosses)
	var all_defs = Database.units.values() + Database.items.values()
	var available_units: Array[GachaBallDefinition] = []
	var available_items: Array[GachaBallDefinition] = []
	var available_trinkets: Array = [] # TrinketDefinition array
	
	for d in all_defs:
		if d.id == &"hero" or d.id == &"enemy_hero": continue
		if d.is_hero: continue
		if String(d.id).begins_with("boss_"): continue
		if d.category == &"UNIT":
			available_units.append(d)
		elif d.category == &"ITEM":
			available_items.append(d)
	
	# Add non-player-exclusive trinkets to the pool
	for trinket in Database.trinkets.values():
		if not trinket.is_player_exclusive:
			available_trinkets.append(trinket)
	
	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	available_items.sort_custom(func(a, b): return a.cost < b.cost)
	# Safeguard: some trinkets may not have cost property if resources weren't re-saved
	available_trinkets.sort_custom(func(a, b):
		var cost_a = a.cost if "cost" in a else 10
		var cost_b = b.cost if "cost" in b else 10
		return cost_a < cost_b
	)
	
	# Build support team with weighted selection
	var best_build: Dictionary = {"units": [], "items": [], "trinkets": [], "spent": 0}
	
	for _i in range(10):
		var purchased_units: Array[GachaBallDefinition] = []
		var purchased_items: Array[GachaBallDefinition] = []
		var purchased_trinkets: Array = []
		var spent_budget = 0
		
		# Spend budget on units, items, and trinkets using weighted selection
		while spent_budget < budget and purchased_units.size() < max_units:
			var remaining = budget - spent_budget
			
			# Build weighted purchase lists
			var weighted_purchases: Array = []
			
			# Units (weight 3)
			if purchased_units.size() < max_units:
				for u in available_units:
					if u.cost <= remaining:
						weighted_purchases.append({"def": u, "weight": 3, "type": "unit"})
			
			# Items (weight 2)
			var total_slots = 0
			for u in purchased_units: total_slots += u.item_slot_count
			if purchased_items.size() < total_slots:
				for item in available_items:
					if item.cost <= remaining:
						weighted_purchases.append({"def": item, "weight": 2, "type": "item"})
			
			# Trinkets (weight 1, max 1 per encounter)
			if purchased_trinkets.size() < 1:
				for trinket in available_trinkets:
					var trinket_cost = trinket.cost if "cost" in trinket else 10
					if trinket_cost <= remaining:
						weighted_purchases.append({"def": trinket, "weight": 1, "type": "trinket"})
			
			if weighted_purchases.is_empty(): break
			
			# Weighted random selection
			var total_weight = 0
			for p in weighted_purchases: total_weight += p.weight
			var roll = randi() % total_weight
			var cumulative = 0
			var selected = weighted_purchases[0]
			for p in weighted_purchases:
				cumulative += p.weight
				if roll < cumulative:
					selected = p
					break
			
			if selected.type == "unit":
				purchased_units.append(selected.def)
			elif selected.type == "item":
				purchased_items.append(selected.def)
			else:
				purchased_trinkets.append(selected.def)
			# Safeguard: trinkets might not have cost property
			var def_cost2 = selected.def.cost if "cost" in selected.def else 10
			spent_budget += def_cost2
		
		if spent_budget > best_build.spent:
			best_build = {"units": purchased_units, "items": purchased_items, "trinkets": purchased_trinkets, "spent": spent_budget}
		
		if spent_budget == budget:
			break
	
	# Assemble encounter
	var encounter = EncounterDefinition.new()
	encounter.id = "support_units_%d" % Time.get_unix_time_from_system()
	
	var available_positions = [0, 1, 2, 3]
	available_positions.shuffle()
	
	for unit_def in best_build.units:
		if available_positions.is_empty(): break
		var pos = available_positions.pop_front()
		var placement: Dictionary = {"id": unit_def.id, "position": pos, "items": []}
		encounter.enemy_placements.append(placement)
	
	# Equip items
	for item_def in best_build.items:
		var possible_parents: Array[Dictionary] = []
		for p in encounter.enemy_placements:
			var unit_def = Database.get_definition(p.id)
			if p.items.size() < unit_def.item_slot_count:
				possible_parents.append(p)
		if possible_parents.is_empty(): break
		possible_parents.pick_random().items.append(item_def.id)
	
	# Assign trinkets
	for trinket_def in best_build.trinkets:
		encounter.enemy_trinket_ids.append(trinket_def.id)
	
	return encounter

## Tries to equip items to the boss using leftover budget.
func _try_equip_items_to_boss(boss_placement: Dictionary, remaining_budget: int, max_slots: int, support_encounter: EncounterDefinition) -> void:
	# Calculate actual remaining budget (subtract what was spent on support)
	var support_spent = 0
	if support_encounter != null:
		for p in support_encounter.enemy_placements:
			var unit_def = Database.get_definition(p.id)
			if is_instance_valid(unit_def):
				support_spent += unit_def.cost
				for item_id in p.items:
					var item_def = Database.get_definition(item_id)
					if is_instance_valid(item_def):
						support_spent += item_def.cost
	
	var leftover = remaining_budget - support_spent
	if leftover <= 0:
		return
	
	# Try to buy items for boss
	var available_items: Array = []
	for d in Database.items.values():
		if d.cost <= leftover:
			available_items.append(d)
	
	available_items.sort_custom(func(a, b): return a.cost > b.cost)
	
	for item_def in available_items:
		if boss_placement.items.size() >= max_slots:
			break
		if item_def.cost <= leftover:
			boss_placement.items.append(item_def.id)
			leftover -= item_def.cost