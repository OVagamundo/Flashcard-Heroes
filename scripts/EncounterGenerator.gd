# res://scripts/EncounterGenerator.gd
extends Node

const C = preload("res://scripts/Constants.gd")

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

## Slot limits
const MAX_UNITS := 5
const MAX_TRINKETS := 5

func _update_director_run_state() -> void:
	if is_instance_valid(GameManager.run_state):
		director_run_state.current_day = GameManager.run_state.day
		director_run_state.player_gold = GameManager.run_state.gold
		director_run_state.current_purpose = DirectorRunState.Purpose.ENCOUNTER
		# mastery sync if needed

## Generates a complete encounter based on the given budget.
func generate_encounter(budget: int) -> EncounterDefinition:
	assert(budget > 0, "Encounter budget must be greater than 0")
	_update_director_run_state()
	
	# Phase 1: Pool available resources
	var pools := _create_resource_pools(true) # Include trinkets
	
	# Phase 2: Build encounter with 100% budget guarantee
	var temp_encounter = EncounterDefinition.new()
	var budget_delta = _generate_slot_effects(temp_encounter, budget)
	var remaining_budget = budget + budget_delta
	if remaining_budget <= 0:
		remaining_budget = 1
	var build := _build_encounter_with_full_spend(remaining_budget, pools, MAX_UNITS, MAX_TRINKETS)
	
	# Phase 3: Assemble the final encounter
	var encounter = _assemble_encounter(build, "dynamic_encounter")
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	return encounter

## Generates a boss encounter with the boss placed at position 4.
func generate_boss_encounter(boss_level: int, daily_budget: int, current_day: int) -> EncounterDefinition:
	var boss_id: StringName = &"boss_%d" % boss_level
	var boss_def = Database.get_definition(boss_id)
	assert(is_instance_valid(boss_def), "Boss definition not found: %s" % boss_id)
	_update_director_run_state()
	
	# Boss is FREE - use reduced daily budget (85%) for support units (keeps Boss >= Elite)
	var pools := _create_resource_pools(true) # Include trinkets
	var support_budget: int = int(daily_budget * 0.85)
	# Pre-generate slot effects on a temporary EncounterDefinition
	var temp_encounter = EncounterDefinition.new()
	var budget_delta = _generate_slot_effects(temp_encounter, support_budget)
	support_budget = max(1, support_budget + budget_delta)
	var build := _build_encounter_with_full_spend(support_budget, pools, MAX_UNITS - 1, MAX_TRINKETS) # Reserve 1 slot for boss
	
	# Assemble encounter - reserve position 4 for boss
	var encounter := _assemble_encounter(build, "boss_encounter_%d" % boss_level, true)
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	
	# Place boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	encounter.enemy_placements.append(boss_placement)
	
	# Store day in encounter for boss summon budget calculation
	encounter.set_meta("current_day", current_day)
	
	return encounter

## Generates an elite encounter using a random boss unit (with weighted pity system).
func generate_elite_encounter(total_budget: int, history: Dictionary = {}, last_elite_id: StringName = &"") -> EncounterDefinition:
	# 1. Define elite boss options with priority baseline (T1 > T2 > T3)
	var boss_options: Array[StringName] = [&"unit_dust_elite_t1", &"unit_dust_elite_t2", &"unit_dust_elite_t3"]
	var baseline_weights: Dictionary = {
		&"unit_dust_elite_t1": 300.0,
		&"unit_dust_elite_t2": 200.0,
		&"unit_dust_elite_t3": 100.0
	}
	
	# 2. Calculate weights based on history (Pity System) and Never-Twice-In-Row
	var weights: Array[float] = []
	var total_weight: float = 0.0
	
	for boss_id in boss_options:
		# Never appear twice in a row
		if boss_id == last_elite_id:
			weights.append(0.0)
			continue
			
		var count = history.get(boss_id, 0)
		var baseline = baseline_weights.get(boss_id, 100.0)
		# Reduction formula: weight = baseline / (1 + count * 2)
		# 0 encounters -> baseline, 1 -> baseline/3, 2 -> baseline/5...
		var w: float = baseline / (1.0 + float(count) * 2.0)
		weights.append(w)
		total_weight += w
	
	# 3. Pick weighted boss
	var roll = randf() * total_weight
	var cumulative_weight: float = 0.0
	var selected_boss_id: StringName = boss_options[0] # Fallback
	
	for i in range(boss_options.size()):
		cumulative_weight += weights[i]
		if roll < cumulative_weight:
			selected_boss_id = boss_options[i]
			break
			
	if OS.is_debug_build():
		pass
		# print("[EncounterGenerator] Elite weighting: ", weights, " (Last: ", last_elite_id, ") Picked: ", selected_boss_id)

	var boss_def = Database.get_definition(selected_boss_id)
	assert(is_instance_valid(boss_def), "Elite boss definition not found: %s" % selected_boss_id)
	_update_director_run_state()
	
	# Elite unit is FREE (like boss battles) - reduced budget (85%) for support units
	var pools := _create_resource_pools(true) # Include trinkets
	var support_budget: int = int(total_budget * 0.85)
	# Pre-generate slot effects on a temporary EncounterDefinition
	var temp_encounter = EncounterDefinition.new()
	var budget_delta = _generate_slot_effects(temp_encounter, support_budget)
	support_budget = max(1, support_budget + budget_delta)
	var build := _build_encounter_with_full_spend(support_budget, pools, MAX_UNITS - 1, MAX_TRINKETS)
	
	# Assemble encounter - reserve position 4 for elite unit
	var encounter := _assemble_encounter(build, "elite_encounter_%s" % String(selected_boss_id), true)
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	
	# Place elite boss at position 4 (back of lineup)
	var boss_placement: Dictionary = {"id": boss_def.id, "position": 4, "items": []}
	encounter.enemy_placements.append(boss_placement)
	
	# Mark this as an elite encounter with stat scaling for the boss
	encounter.set_meta("elite_stat_scale", 0.33)
	
	# Metadata for GameManager to record history
	encounter.set_meta("elite_boss_id", selected_boss_id)
	
	return encounter

## Generates summons for boss abilities.
func generate_boss_summons(day: int, max_units: int) -> Array:
	# Standardized baseline (3 instead of 5) and reduced multiplier (0.33 instead of 0.5)
	var daily_budget: int = 3 + (day - 1) * 1
	var budget: int = int(floor(daily_budget * 0.33))
	_update_director_run_state()
	
	if budget <= 0 or max_units <= 0:
		return []
	
	# Pool resources (NO trinkets for boss summons)
	var pools := _create_resource_pools(false)
	
	# Build with full spend guarantee
	var build := _build_encounter_with_full_spend(budget, pools, max_units, 0)
	
	var summons: Array = []
	var item_index := 0
	for unit_def in build.units:
		var summon := {"unit_id": unit_def.id, "items": []}
		var slots_to_fill: int = unit_def.item_slot_count
		while slots_to_fill > 0 and item_index < build.items.size():
			summon.items.append(build.items[item_index].id)
			item_index += 1
			slots_to_fill -= 1
		summons.append(summon)
	
	return summons

# =============================================================================
# CORE ALGORITHM: Greedy Fill + Knapsack Top-up (Director Refactored)
# =============================================================================

func _build_encounter_with_full_spend(budget: int, pools: Dictionary, max_units: int, max_trinkets: int) -> Dictionary:
	var best_build: Dictionary = {"units": [], "items": [], "trinkets": [], "spent": 0, "overflow": budget}
	
	for attempt in range(10):
		var build := _single_build_attempt(budget, pools, max_units, max_trinkets)
		if build.spent > best_build.spent:
			best_build = build
		elif build.spent == best_build.spent and build.units.size() > best_build.units.size():
			best_build = build
		
		if build.spent == budget and build.units.size() >= mini(max_units, 3):
			break
	
	return best_build

func _single_build_attempt(budget: int, pools: Dictionary, max_units: int, max_trinkets: int) -> Dictionary:
	var purchased_units: Array = []
	var purchased_items: Array = []
	var purchased_trinkets: Array = []
	var spent := 0
	
	# 1. Buy units using Director
	while spent < budget and purchased_units.size() < max_units:
		var affordable_units = pools.units.filter(func(x): return _get_cost(x) <= budget - spent)
		if affordable_units.is_empty(): break
		var u = director.draw_item(affordable_units, director_run_state)
		if u == null: break
		purchased_units.append(u)
		spent += _get_cost(u)
		
	# 2. Buy items using Director
	var total_slots = 0
	for u in purchased_units: total_slots += u.item_slot_count
	while spent < budget and purchased_items.size() < total_slots:
		var affordable_items = pools.items.filter(func(x): return _get_cost(x) <= budget - spent)
		if affordable_items.is_empty(): break
		var item = director.draw_item(affordable_items, director_run_state)
		if item == null: break
		purchased_items.append(item)
		spent += _get_cost(item)
		
	# 3. Buy trinkets using Director
	director_run_state.clear_exclusions()

	while spent < budget and purchased_trinkets.size() < max_trinkets:
		var affordable_trinkets = pools.trinkets.filter(func(x): return _get_cost(x) <= budget - spent)
		if affordable_trinkets.is_empty(): break
		var t = director.draw_item(affordable_trinkets, director_run_state)
		if t == null: break
		purchased_trinkets.append(t)
		director_run_state.exclude_entity(t.id)
		spent += _get_cost(t)
		
	# 4. Upgrade logic using Director
	while spent < budget:
		var upgraded = false
		var remaining = budget - spent
		
		var upgrade_candidates = []
		# Wrap upgrades as (collection, index, old_item)
		for i in purchased_units.size(): upgrade_candidates.append([purchased_units, i, pools.units])
		for i in purchased_items.size(): upgrade_candidates.append([purchased_items, i, pools.items])
		for i in purchased_trinkets.size(): upgrade_candidates.append([purchased_trinkets, i, pools.trinkets])
		upgrade_candidates.shuffle()
		
		for candidate in upgrade_candidates:
			var list = candidate[0]
			var idx = candidate[1]
			var pool = candidate[2]
			var current_item = list[idx]
			var current_cost = _get_cost(current_item)
			
			var potential_upgrades = pool.filter(func(x): return _get_cost(x) > current_cost and _get_cost(x) <= current_cost + remaining)
			if not potential_upgrades.is_empty():
				var upgrade = director.draw_item(potential_upgrades, director_run_state)
				if upgrade:
					list[idx] = upgrade
					spent += (_get_cost(upgrade) - current_cost)
					upgraded = true
					break
		
		if not upgraded: break
		
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
		
		# Skip units with special tags (Hidden, Token, Boss)
		# Dust units are now tagged HIDDEN. Bosses are always excluded.
		if d.tags.has(&"HIDDEN") or d.tags.has(&"TOKEN") or d.tags.has(&"BOSS"):
			continue
			
		available_units.append(d)
	
	for d in Database.items.values():
		# Filter out consumables
		if d.category == &"CONSUMABLE":
			continue
		available_items.append(d)
	
	if include_trinkets:
		for trinket in Database.trinkets.values():
			if trinket.is_player_exclusive:
				continue
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
	_append_required_trait_trinkets(encounter)
	for trinket_def in build.trinkets:
		if encounter.enemy_trinket_ids.size() >= MAX_TRINKETS:
			break
		if encounter.enemy_trinket_ids.has(trinket_def.id):
			continue
		encounter.enemy_trinket_ids.append(trinket_def.id)
	
	# Validate
	assert(_validate_encounter(encounter), "Generated encounter failed validation")
	
	return encounter

func _append_required_trait_trinkets(encounter: EncounterDefinition) -> void:
	var soul_counts := {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}

	for placement in encounter.enemy_placements:
		var unit_def = Database.get_definition(placement.id)
		_accumulate_trait_souls(soul_counts, unit_def)
		for item_id in placement.get("items", []):
			var item_def = Database.get_definition(item_id)
			_accumulate_trait_souls(soul_counts, item_def)

	for trait_name in C.TRAIT_SORT_ORDER:
		if encounter.enemy_trinket_ids.size() >= MAX_TRINKETS:
			break
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
		var levels: Array = trait_def.get("levels", [])
		if levels.is_empty():
			continue
		var min_required := int(levels[0].get("min", 999))
		if int(soul_counts.get(trait_name, 0)) < min_required:
			continue
		var trinket_id: StringName = trait_def.get("trinket_id", &"")
		if trinket_id == &"" or encounter.enemy_trinket_ids.has(trinket_id):
			continue
		encounter.enemy_trinket_ids.append(trinket_id)

func _accumulate_trait_souls(counts: Dictionary, definition: Resource) -> void:
	if not is_instance_valid(definition) or not ("tags" in definition):
		return
	for tag in definition.tags:
		match tag:
			&"SOUL_FIRE":
				counts["FIRE"] += 1
			&"SOUL_EARTH":
				counts["EARTH"] += 1
			&"SOUL_WATER":
				counts["WATER"] += 1
			&"SOUL_AIR":
				counts["AIR"] += 1


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


func _generate_slot_effects(encounter: EncounterDefinition, budget: int) -> int:
	encounter.player_slot_effects = [&"", &"", &"", &"", &""]
	encounter.enemy_slot_effects = [&"", &"", &"", &"", &""]
	
	var day: int = director_run_state.current_day
	if day <= 0:
		day = 1
		
	# Determine if we should generate slots
	var spawn_chance := 0.0
	if day <= 10:
		spawn_chance = 0.10
	elif day <= 20:
		spawn_chance = 0.40
	elif day <= 40:
		spawn_chance = 0.75
	else:
		spawn_chance = 1.0
		
	if randf() > spawn_chance:
		return 0 # No slots generated
		
	# We are generating slots. We want at least one slot on each team.
	# --- 1. Player Team Slots ---
	var possible_player_combinations := []
	for b in range(4): # 0 to 3 burn slots
		for l in range(4): # 0 to 3 lightning slots
			if b + l == 0:
				continue
			if b + l > 5:
				continue
			var cost = b * 3 + l * 2
			if cost <= budget - 1: # Leave at least 1 gold for unit generation
				possible_player_combinations.append({"burn": b, "lightning": l, "cost": cost})
				
	var player_cost = 0
	if not possible_player_combinations.is_empty():
		var chosen = possible_player_combinations[randi() % possible_player_combinations.size()]
		var num_burn: int = chosen["burn"]
		var num_lightning: int = chosen["lightning"]
		player_cost = chosen["cost"]
		
		# Assign randomly
		var pos = [0, 1, 2, 3, 4]
		pos.shuffle()
		for j in range(num_burn):
			encounter.player_slot_effects[pos.pop_back()] = &"burn"
		for j in range(num_lightning):
			encounter.player_slot_effects[pos.pop_back()] = &"lightning"
			
	# --- 2. Enemy Team Slots ---
	var possible_enemy_combinations := []
	for b in range(4): # 0 to 3 burn slots
		for l in range(4): # 0 to 3 lightning slots
			if b + l == 0:
				continue
			if b + l > 5:
				continue
			var bonus = b * 3 + l * 2
			possible_enemy_combinations.append({"burn": b, "lightning": l, "bonus": bonus})
			
	var enemy_bonus = 0
	if not possible_enemy_combinations.is_empty():
		var chosen = possible_enemy_combinations[randi() % possible_enemy_combinations.size()]
		var num_burn: int = chosen["burn"]
		var num_lightning: int = chosen["lightning"]
		enemy_bonus = chosen["bonus"]
		
		# Assign randomly
		var pos = [0, 1, 2, 3, 4]
		pos.shuffle()
		for j in range(num_burn):
			encounter.enemy_slot_effects[pos.pop_back()] = &"burn"
		for j in range(num_lightning):
			encounter.enemy_slot_effects[pos.pop_back()] = &"lightning"
			
	return enemy_bonus - player_cost
