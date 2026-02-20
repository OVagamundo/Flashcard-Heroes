# res://scripts/EncounterGenerator.gd
extends Node

const EncounterDefinition = preload("res://scripts/EncounterDefinition.gd")
const GachaBallDefinition = preload("res://scripts/GachaBallDefinition.gd")

## A stateless service that generates dynamic encounters using a budget-spending algorithm.
## GUARANTEES: 100% budget spending through multi-phase optimization.
## 
## Budget Formula: 5 + (day - 1) * 3
## - Day 1: 5 gold, Day 2: 8 gold, Day 3: 11 gold, etc.
## - Elite battles: daily_budget * 1.3
## - Boss battles: Boss is free, support units use daily budget
## - Boss summons: half daily budget, no trinkets

## Slot limits
const MAX_UNITS := 5
const MAX_TRINKETS := 5

## Priority weights for weighted random selection
const WEIGHT_UNIT := 3
const WEIGHT_ITEM := 2
const WEIGHT_TRINKET := 1

## Generates a complete encounter based on the given budget.
## Uses "Greedy Fill + Knapsack Top-up" algorithm to guarantee 100% budget spending.
## @param budget: int - The total budget to spend on units, items, and trinkets
## @return EncounterDefinition - A complete encounter definition with enemy placements
func generate_encounter(budget: int) -> EncounterDefinition:
	assert(budget > 0, "Encounter budget must be greater than 0")
	
	# Phase 1: Pool available resources
	var pools := _create_resource_pools(true) # Include trinkets
	
	# Phase 2: Build encounter with 100% budget guarantee
	var build := _build_encounter_with_full_spend(budget, pools, MAX_UNITS, MAX_TRINKETS)
	
	# Phase 3: Assemble the final encounter
	return _assemble_encounter(build, "dynamic_encounter")


## Generates a boss encounter with the boss placed at position 4.
## Boss is FREE (not counted against budget). Support units use the full daily budget.
## @param boss_level: int - The boss number (1-5)
## @param daily_budget: int - The daily budget for support units
## @param current_day: int - The current day (passed to EncounterDefinition for boss summon budget)
## @return EncounterDefinition - An encounter with the boss and support units
func generate_boss_encounter(boss_level: int, daily_budget: int, current_day: int) -> EncounterDefinition:
	var boss_id: StringName = &"boss_%d" % boss_level
	var boss_def = Database.get_definition(boss_id)
	assert(is_instance_valid(boss_def), "Boss definition not found: %s" % boss_id)
	
	# Boss is FREE - use full daily budget for support units
	var pools := _create_resource_pools(true) # Include trinkets
	var build := _build_encounter_with_full_spend(daily_budget, pools, MAX_UNITS - 1, MAX_TRINKETS) # Reserve 1 slot for boss
	
	# Assemble encounter - reserve position 4 for boss
	var encounter := _assemble_encounter(build, "boss_encounter_%d" % boss_level, true)
	
	# Place boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	encounter.enemy_placements.append(boss_placement)
	
	# Store day in encounter for boss summon budget calculation
	encounter.set_meta("current_day", current_day)
	
	return encounter


## Generates an elite encounter using a random boss unit.
## Elite unit is FREE (like boss battles). Full budget used for support units.
## @param total_budget: int - The total encounter budget (after 1.3x elite multiplier applied)
## @return EncounterDefinition - An encounter with a boss unit and support units
func generate_elite_encounter(total_budget: int) -> EncounterDefinition:
	# Elite encounters randomly select between Boss 1, Boss 2, and Boss 3 as a "Mini Boss"
	var boss_options: Array[StringName] = [&"boss_1", &"boss_2", &"boss_3"]
	var boss_id: StringName = boss_options.pick_random()
	var boss_def = Database.get_definition(boss_id)
	assert(is_instance_valid(boss_def), "Elite boss definition not found: %s" % boss_id)
	
	# Elite unit is FREE (like boss battles) - full budget for support units
	var pools := _create_resource_pools(true) # Include trinkets
	var build := _build_encounter_with_full_spend(total_budget, pools, MAX_UNITS - 1, MAX_TRINKETS)
	
	# Assemble encounter - reserve position 4 for elite unit
	var encounter := _assemble_encounter(build, "elite_encounter_%s" % String(boss_id), true)
	
	# Place elite boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	encounter.enemy_placements.append(boss_placement)
	
	# Mark this as an elite encounter with stat scaling for the boss
	# 1/3 stats for the "Mini Boss"
	encounter.set_meta("elite_stat_scale", 0.33)
	
	return encounter


## Generates summons for boss abilities (used by EffectBossSummon).
## Uses half the daily budget, no trinkets.
## @param day: int - The current day for budget calculation
## @param max_units: int - Maximum number of units to summon
## @return Array - Array of {unit_id: StringName, items: Array[StringName]}
func generate_boss_summons(day: int, max_units: int) -> Array:
	# Calculate half of daily budget
	var daily_budget: int = 5 + (day - 1) * 3
	var budget: int = int(floor(daily_budget / 2.0))
	
	if budget <= 0 or max_units <= 0:
		return []
	
	# Pool resources (NO trinkets for boss summons)
	var pools := _create_resource_pools(false)
	
	# Build with full spend guarantee
	var build := _build_encounter_with_full_spend(budget, pools, max_units, 0)
	
	# Convert to summon format
	var summons: Array = []
	var item_index := 0
	for unit_def in build.units:
		var summon := {"unit_id": unit_def.id, "items": []}
		# Assign items to this unit up to its slot count
		var slots_to_fill: int = unit_def.item_slot_count
		while slots_to_fill > 0 and item_index < build.items.size():
			summon.items.append(build.items[item_index].id)
			item_index += 1
			slots_to_fill -= 1
		summons.append(summon)
	
	return summons


# =============================================================================
# CORE ALGORITHM: Greedy Fill + Knapsack Top-up
# =============================================================================

## Builds an encounter that spends EXACTLY 100% of the budget.
## Returns a dictionary with units, items, trinkets, spent, and overflow.
## Runs multiple attempts and picks the best build (prioritizing unit count).
func _build_encounter_with_full_spend(budget: int, pools: Dictionary, max_units: int, max_trinkets: int) -> Dictionary:
	var best_build: Dictionary = {"units": [], "items": [], "trinkets": [], "spent": 0, "overflow": budget}
	
	# Run multiple attempts to find the best build
	for attempt in range(10):
		var build := _single_build_attempt(budget, pools, max_units, max_trinkets)
		
		# Prefer builds that spend more budget, then builds with more units
		var is_better := false
		if build.spent > best_build.spent:
			is_better = true
		elif build.spent == best_build.spent and build.units.size() > best_build.units.size():
			is_better = true
		
		if is_better:
			best_build = build
		
		# Perfect build: full budget spent with reasonable unit count
		if build.spent == budget and build.units.size() >= mini(max_units, 3):
			break
	
	print("[EncounterGen] Budget: %d, Spent: %d, Units: %d, Items: %d, Trinkets: %d" % [
		budget, best_build.spent, best_build.units.size(), best_build.items.size(), best_build.trinkets.size()
	])
	
	return best_build


## Single deterministic attempt at building an encounter that perfectly spends the budget.
func _single_build_attempt(budget: int, pools: Dictionary, max_units: int, max_trinkets: int) -> Dictionary:
	var purchased_units: Array = []
	var purchased_items: Array = []
	var purchased_trinkets: Array = []
	var spent := 0
	
	# Helper to find the highest cost affordable item randomly from the top tier
	var get_best = func(arr: Array, max_cost: int):
		var best = null
		var valid = arr.filter(func(x): return _get_cost(x) <= max_cost)
		if valid.size() > 0:
			valid.sort_custom(func(a, b): return _get_cost(a) > _get_cost(b))
			var highest_cost = _get_cost(valid[0])
			var top_tier = valid.filter(func(x): return _get_cost(x) == highest_cost)
			best = top_tier[randi() % top_tier.size()]
		return best

	# 1. Buy units
	while spent < budget and purchased_units.size() < max_units:
		var u = get_best.call(pools.units, budget - spent)
		if u == null: break
		purchased_units.append(u)
		spent += _get_cost(u)
		
	# 2. Buy items for unit slots
	var total_slots = 0
	for u in purchased_units: total_slots += u.item_slot_count
	while spent < budget and purchased_items.size() < total_slots:
		var item = get_best.call(pools.items, budget - spent)
		if item == null: break
		purchased_items.append(item)
		spent += _get_cost(item)
		
	# 3. Buy trinkets
	while spent < budget and purchased_trinkets.size() < max_trinkets:
		var t = get_best.call(pools.trinkets, budget - spent)
		if t == null: break
		purchased_trinkets.append(t)
		spent += _get_cost(t)
		
	# 4. If we still haven't spent budget, try to upgrade! (e.g. replace 1-cost with 2-cost)
	while spent < budget:
		var upgraded = false
		var remaining = budget - spent
		
		# Upgrade units
		var u_indices = range(purchased_units.size())
		u_indices.shuffle()
		for i in u_indices:
			var u = purchased_units[i]
			var cost = _get_cost(u)
			var upgrade = get_best.call(pools.units, cost + remaining)
			if upgrade and _get_cost(upgrade) > cost:
				purchased_units[i] = upgrade
				spent += (_get_cost(upgrade) - cost)
				upgraded = true
				break
				
		if upgraded: continue
		
		# Upgrade items
		var i_indices = range(purchased_items.size())
		i_indices.shuffle()
		for i in i_indices:
			var item = purchased_items[i]
			var cost = _get_cost(item)
			var upgrade = get_best.call(pools.items, cost + remaining)
			if upgrade and _get_cost(upgrade) > cost:
				purchased_items[i] = upgrade
				spent += (_get_cost(upgrade) - cost)
				upgraded = true
				break
				
		if upgraded: continue
		
		# Upgrade trinkets
		var t_indices = range(purchased_trinkets.size())
		t_indices.shuffle()
		for i in t_indices:
			var t = purchased_trinkets[i]
			var cost = _get_cost(t)
			var upgrade = get_best.call(pools.trinkets, cost + remaining)
			if upgrade and _get_cost(upgrade) > cost:
				purchased_trinkets[i] = upgrade
				spent += (_get_cost(upgrade) - cost)
				upgraded = true
				break
				
		if not upgraded: break # Mathematically impossible or capped out
		
	return {
		"units": purchased_units,
		"items": purchased_items,
		"trinkets": purchased_trinkets,
		"spent": spent,
		"overflow": budget - spent
	}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Creates pools of available resources (units, items, optionally trinkets).
func _create_resource_pools(include_trinkets: bool) -> Dictionary:
	var available_units: Array = []
	var available_items: Array = []
	var available_trinkets: Array = []
	
	for d in Database.units.values():
		# Skip heroes and bosses
		if d.id == &"hero" or d.id == &"enemy_hero":
			continue
		if d.is_hero:
			continue
		if d.get("is_player_exclusive") == true:
			continue
		if String(d.id).begins_with("boss_"):
			continue
		available_units.append(d)
	
	for d in Database.items.values():
		# Filter out consumables
		if d.category == &"CONSUMABLE":
			continue
		available_items.append(d)
	
	if include_trinkets:
		for trinket in Database.trinkets.values():
			if not trinket.is_player_exclusive:
				available_trinkets.append(trinket)
	
	# Sort by cost ascending for optimization algorithms
	available_units.sort_custom(func(a, b): return a.cost < b.cost)
	available_items.sort_custom(func(a, b): return a.cost < b.cost)
	available_trinkets.sort_custom(func(a, b): return _get_cost(a) < _get_cost(b))
	
	return {
		"units": available_units,
		"items": available_items,
		"trinkets": available_trinkets
	}


## Gets the cost of a definition (handles trinkets that might not have cost).
func _get_cost(def) -> int:
	return GameManager.get_item_cost(def)


## Assembles the final EncounterDefinition from a build dictionary.
## @param reserve_position_4: bool - If true, only use positions 0-3 (for boss/elite encounters)
func _assemble_encounter(build: Dictionary, id_prefix: String, reserve_position_4: bool = false) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = "%s_%d" % [id_prefix, Time.get_unix_time_from_system()]
	
	# Place units at random positions
	var available_positions: Array
	if reserve_position_4:
		available_positions = [0, 1, 2, 3] # Reserve position 4 for boss/elite
	else:
		available_positions = [0, 1, 2, 3, 4]
	available_positions.shuffle()
	
	for unit_def in build.units:
		if available_positions.is_empty():
			break
		var pos: int = available_positions.pop_front()
		var placement: Dictionary = {"id": unit_def.id, "position": pos, "items": []}
		encounter.enemy_placements.append(placement)
	
	# Equip items on units randomly
	for item_def in build.items:
		var possible_parents: Array = []
		for p in encounter.enemy_placements:
			var unit_def = Database.get_definition(p.id)
			if is_instance_valid(unit_def) and p.items.size() < unit_def.item_slot_count:
				possible_parents.append(p)
		if possible_parents.is_empty():
			break
		possible_parents.pick_random().items.append(item_def.id)
	
	# Assign trinkets
	for trinket_def in build.trinkets:
		encounter.enemy_trinket_ids.append(trinket_def.id)
	
	# Validate
	assert(_validate_encounter(encounter), "Generated encounter failed validation")
	
	return encounter


## Validates that the generated encounter is valid.
func _validate_encounter(encounter: EncounterDefinition) -> bool:
	if not is_instance_valid(encounter):
		return false
	
	if encounter.enemy_placements.is_empty():
		return false
	
	for placement in encounter.enemy_placements:
		var unit_def = Database.get_definition(placement.id)
		if not is_instance_valid(unit_def):
			return false
		if placement.items.size() > unit_def.item_slot_count:
			return false
	
	return true


## Calculates the total power of an encounter for debugging purposes.
func analyze_encounter(encounter: EncounterDefinition) -> Dictionary:
	var analysis: Dictionary = {
		"unit_count": 0,
		"item_count": 0,
		"trinket_count": encounter.enemy_trinket_ids.size(),
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
			
			for item_id in placement.items:
				var item_def = Database.get_definition(item_id)
				if is_instance_valid(item_def):
					analysis.item_count += 1
					analysis.total_cost += item_def.cost
					analysis.total_power += item_def.bonus_pwr
					analysis.total_hp += item_def.bonus_hp
	
	# Add trinket costs
	for trinket_id in encounter.enemy_trinket_ids:
		var trinket_def = Database.trinkets.get(trinket_id)
		if is_instance_valid(trinket_def):
			analysis.total_cost += _get_cost(trinket_def)
	
	return analysis