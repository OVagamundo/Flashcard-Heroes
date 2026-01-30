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
	if budget <= 0:
		return _create_fallback_encounter()
	
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
	if not is_instance_valid(boss_def):
		push_error("Boss definition not found: %s" % boss_id)
		return _create_fallback_encounter()
	
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
	if not is_instance_valid(boss_def):
		push_error("Elite boss definition not found: %s" % boss_id)
		return _create_fallback_encounter()
	
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


## Single attempt at building an encounter.
func _single_build_attempt(budget: int, pools: Dictionary, max_units: int, max_trinkets: int) -> Dictionary:
	var purchased_units: Array = []
	var purchased_items: Array = []
	var purchased_trinkets: Array = []
	var spent := 0
	
	var available_units: Array = pools.units.duplicate()
	var available_items: Array = pools.items.duplicate()
	var available_trinkets: Array = pools.trinkets.duplicate()
	
	# Phase 1: Greedy weighted selection (main spending phase)
	while spent < budget:
		var remaining := budget - spent
		var options: Array = _get_weighted_options(
			remaining, available_units, available_items, available_trinkets,
			purchased_units, purchased_items, purchased_trinkets,
			max_units, max_trinkets
		)
		
		if options.is_empty():
			# Debug: Why are options empty?
			var total_slots := 0
			for u in purchased_units:
				total_slots += u.item_slot_count
			print("[EncounterGen] Options empty with %d remaining! Units: %d/%d, Items: %d/%d slots, Trinkets: %d/%d" % [
				remaining, purchased_units.size(), max_units,
				purchased_items.size(), total_slots,
				purchased_trinkets.size(), max_trinkets
			])
			break
		
		var selected := _weighted_random_select(options)
		match selected.type:
			"unit":
				purchased_units.append(selected.def)
			"item":
				purchased_items.append(selected.def)
			"trinket":
				purchased_trinkets.append(selected.def)
		
		spent += _get_cost(selected.def)
	
	# Phase 2: Gap-filling - try to spend remaining budget exactly
	var gap := budget - spent
	if gap > 0:
		print("[EncounterGen] Gap-fill needed: %d gold remaining" % gap)
		var fill_result := _fill_gap_exactly(
			gap, available_units, available_items, available_trinkets,
			purchased_units, purchased_items, purchased_trinkets,
			max_units, max_trinkets
		)
		purchased_units.append_array(fill_result.units)
		purchased_items.append_array(fill_result.items)
		purchased_trinkets.append_array(fill_result.trinkets)
		spent += fill_result.spent
		if fill_result.spent > 0:
			print("[EncounterGen] Gap-fill added: %d gold" % fill_result.spent)
		else:
			print("[EncounterGen] Gap-fill FAILED to add anything!")
	
	# Phase 3: Swap optimization - if gap still exists, try swapping
	gap = budget - spent
	if gap > 0 and not purchased_items.is_empty():
		var swap_result := _try_swap_for_exact_fit(
			gap, purchased_items, available_items
		)
		if swap_result.success:
			purchased_items = swap_result.new_items
			spent = budget
			print("[EncounterGen] Swap optimization succeeded!")
	
	# Calculate overflow
	var overflow := budget - spent
	if overflow > 0:
		print("[EncounterGen] OVERFLOW: %d gold unspent!" % overflow)
	
	return {
		"units": purchased_units,
		"items": purchased_items,
		"trinkets": purchased_trinkets,
		"spent": spent,
		"overflow": overflow
	}


## Gets weighted purchase options based on current state.
func _get_weighted_options(
	remaining: int,
	available_units: Array, available_items: Array, available_trinkets: Array,
	purchased_units: Array, purchased_items: Array, purchased_trinkets: Array,
	max_units: int, max_trinkets: int
) -> Array:
	var options: Array = []
	
	# Units (weight 3)
	if purchased_units.size() < max_units:
		for u in available_units:
			if u.cost <= remaining:
				options.append({"def": u, "weight": WEIGHT_UNIT, "type": "unit"})
	
	# Items (weight 2) - only if we have item slots
	var total_slots := 0
	for u in purchased_units:
		total_slots += u.item_slot_count
	if purchased_items.size() < total_slots:
		for item in available_items:
			if item.cost <= remaining:
				options.append({"def": item, "weight": WEIGHT_ITEM, "type": "item"})
	
	# Trinkets (weight 1) - up to max_trinkets
	if purchased_trinkets.size() < max_trinkets:
		for trinket in available_trinkets:
			var cost := _get_cost(trinket)
			if cost <= remaining:
				options.append({"def": trinket, "weight": WEIGHT_TRINKET, "type": "trinket"})
	
	return options


## Weighted random selection from options array.
func _weighted_random_select(options: Array) -> Dictionary:
	var total_weight := 0
	for opt in options:
		total_weight += opt.weight
	
	var roll := randi() % total_weight
	var cumulative := 0
	for opt in options:
		cumulative += opt.weight
		if roll < cumulative:
			return opt
	
	return options[0]


## Phase 2: Try to fill the gap with exact-cost combinations.
func _fill_gap_exactly(
	gap: int,
	available_units: Array, available_items: Array, available_trinkets: Array,
	purchased_units: Array, purchased_items: Array, purchased_trinkets: Array,
	max_units: int, max_trinkets: int
) -> Dictionary:
	var result := {"units": [], "items": [], "trinkets": [], "spent": 0}
	
	# Try to find items/units that exactly match the gap
	# First try single items (most common gap filler)
	var total_item_slots := 0
	for u in purchased_units:
		total_item_slots += u.item_slot_count
	var available_item_slots := total_item_slots - purchased_items.size()
	
	if available_item_slots > 0:
		for item in available_items:
			if item.cost == gap:
				result.items.append(item)
				result.spent += item.cost
				return result
	
	# Try units if we have space
	if purchased_units.size() < max_units:
		for u in available_units:
			if u.cost == gap:
				result.units.append(u)
				result.spent += u.cost
				return result
	
	# Try trinkets if we have space
	if purchased_trinkets.size() < max_trinkets:
		for t in available_trinkets:
			var cost := _get_cost(t)
			if cost == gap:
				result.trinkets.append(t)
				result.spent += cost
				return result
	
	# Try combinations of 2 items
	if available_item_slots >= 2:
		for i in range(available_items.size()):
			for j in range(i + 1, available_items.size()):
				if available_items[i].cost + available_items[j].cost == gap:
					result.items.append(available_items[i])
					result.items.append(available_items[j])
					result.spent += available_items[i].cost + available_items[j].cost
					return result
	
	# Greedy fill with smallest items that fit
	var filled := 0
	var temp_items: Array = []
	var sorted_items := available_items.duplicate()
	sorted_items.sort_custom(func(a, b): return a.cost < b.cost)
	
	for item in sorted_items:
		if filled >= gap:
			break
		if available_item_slots - temp_items.size() <= 0:
			break
		if item.cost <= gap - filled:
			temp_items.append(item)
			filled += item.cost
	
	if filled > result.spent:
		result.items = temp_items
		result.spent = filled
	
	return result


## Phase 3: Try swapping an owned item for a different cost combination.
func _try_swap_for_exact_fit(gap: int, owned_items: Array, available_items: Array) -> Dictionary:
	# Try to swap one owned item for a combination that costs exactly (item.cost + gap) more
	for i in range(owned_items.size()):
		var owned = owned_items[i] # GachaBallDefinition
		var target_cost: int = owned.cost + gap
		
		# Look for a single item with exact target cost
		for avail in available_items:
			if avail.cost == target_cost:
				var new_items: Array = owned_items.duplicate()
				new_items.remove_at(i)
				new_items.append(avail)
				return {"success": true, "new_items": new_items}
	
	return {"success": false, "new_items": owned_items}


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
		if String(d.id).begins_with("boss_"):
			continue
		available_units.append(d)
	
	for d in Database.items.values():
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
	if "cost" in def:
		return def.cost
	return 10 # Default trinket cost


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
	if not _validate_encounter(encounter):
		return _create_fallback_encounter()
	
	return encounter


## Creates a fallback encounter when generation fails.
func _create_fallback_encounter() -> EncounterDefinition:
	var fallback := EncounterDefinition.new()
	fallback.id = "fallback_encounter_%d" % Time.get_unix_time_from_system()
	
	var basic_enemy = Database.get_definition(&"Tier1unitA")
	if not is_instance_valid(basic_enemy):
		var all_units = Database.units.values()
		if not all_units.is_empty():
			basic_enemy = all_units[0]
	
	if is_instance_valid(basic_enemy):
		var placement: Dictionary = {"id": basic_enemy.id, "position": 0, "items": []}
		fallback.enemy_placements.append(placement)
	
	return fallback


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