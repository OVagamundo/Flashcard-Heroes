# res://scripts/EncounterGenerator.gd
extends Node

const C = preload("res://scripts/Constants.gd")

var director: WeightedPoolDirector = WeightedPoolDirector.new()
var director_run_state: DirectorRunState = DirectorRunState.new()

## Slot limits
const MAX_UNITS := 5
const MAX_TRINKETS := C.ENEMY_TRINKET_CAP

func _update_director_run_state() -> void:
	if is_instance_valid(GameManager) and is_instance_valid(GameManager.run_state):
		director_run_state.current_day = GameManager.run_state.day
		director_run_state.player_gold = GameManager.run_state.gold
		director_run_state.current_purpose = DirectorRunState.Purpose.ENCOUNTER

# =============================================================================
# UNIFIED WEIGHTED SELECTION ALGORITHM
# =============================================================================

func _pick_weighted_decay(options: Array[StringName], history: Dictionary, last_id: StringName, rng: SeededRNG) -> StringName:
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for opt in options:
		var count: int = int(history.get(opt, 0))
		var w: float = 100.0 / (1.0 + (float(count) * 2.0))
		if opt == last_id:
			w *= 0.20
		weights.append(w)
		total_weight += w

	assert(total_weight > 0.0, "EncounterGenerator: total_weight must be positive")
	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in range(options.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return options[i]
	return options[0]

# =============================================================================
# PRIMARY ENTRY POINTS (Macro Encounter Generation)
# =============================================================================

## Generates a regular encounter governed by a selected Banner Trinket.
func generate_encounter(daily_budget: int) -> EncounterDefinition:
	assert(daily_budget > 0, "generate_encounter: daily_budget must be positive")
	_update_director_run_state()

	var run_state = GameManager.run_state if is_instance_valid(GameManager) else null
	var history: Dictionary = run_state.regular_banner_history if is_instance_valid(run_state) else {}
	var last_id: StringName = run_state.last_regular_banner_id if is_instance_valid(run_state) else &""

	var temp_encounter := EncounterDefinition.new()
	var budget_delta: int = _generate_slot_effects(temp_encounter, daily_budget)
	var effective_budget: int = maxi(1, daily_budget + budget_delta)
	var regular_banners: Array[StringName] = BannerDraftingRegistry.regular_banner_ids(effective_budget)
	var chosen_banner: StringName = _pick_weighted_decay(regular_banners, history, last_id, RNGManager.map_rng)
	if is_instance_valid(run_state):
		run_state.record_regular_banner(chosen_banner)

	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(chosen_banner)
	var encounter: EncounterDefinition = drafter.draft_lineup(effective_budget)

	encounter.banner_trinket_id = chosen_banner
	encounter.encounter_day = run_state.day if is_instance_valid(run_state) else 1
	encounter.daily_budget = daily_budget
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	return encounter

## Generates an elite encounter using a selected Elite Banner and boss/elite unit.
func generate_elite_encounter(daily_budget: int, history: Dictionary = {}, last_elite_id: StringName = &"") -> EncounterDefinition:
	assert(daily_budget > 0, "generate_elite_encounter: daily_budget must be positive")
	_update_director_run_state()

	var run_state = GameManager.run_state if is_instance_valid(GameManager) else null
	var eff_history: Dictionary = history if not history.is_empty() else (run_state.elite_encounter_history if is_instance_valid(run_state) else {})
	var eff_last_id: StringName = last_elite_id if last_elite_id != &"" else (run_state.last_elite_id if is_instance_valid(run_state) else &"")

	var elite_options: Array[StringName] = [&"elite_slimeblob", &"elite_burnie"]
	var chosen_elite: StringName = _pick_weighted_decay(elite_options, eff_history, eff_last_id, RNGManager.map_rng)
	if is_instance_valid(run_state):
		run_state.record_elite_encounter(chosen_elite)

	var temp_encounter := EncounterDefinition.new()
	var raw_support_budget: int = int(floor(daily_budget * 0.85))
	var budget_delta: int = _generate_slot_effects(temp_encounter, raw_support_budget)
	var support_budget: int = maxi(1, raw_support_budget + budget_delta)

	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter_for_entity(chosen_elite)
	var encounter: EncounterDefinition = drafter.draft_lineup(support_budget, {"daily_budget": daily_budget})

	encounter.boss_or_elite_unit_id = chosen_elite
	encounter.encounter_day = run_state.day if is_instance_valid(run_state) else 1
	encounter.daily_budget = daily_budget
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	return encounter

## Generates a milestone boss encounter governed by the chosen Boss Banner.
func generate_boss_encounter(_boss_level: int, daily_budget: int, current_day: int) -> EncounterDefinition:
	assert(daily_budget > 0, "generate_boss_encounter: daily_budget must be positive")
	_update_director_run_state()

	var run_state = GameManager.run_state if is_instance_valid(GameManager) else null
	var history: Dictionary = run_state.boss_encounter_history if is_instance_valid(run_state) else {}
	var last_id: StringName = run_state.last_boss_id if is_instance_valid(run_state) else &""

	var boss_options: Array[StringName] = [&"boss_dustmon", &"boss_toughmon", &"boss_doppelkun"]
	var chosen_boss: StringName = _pick_weighted_decay(boss_options, history, last_id, RNGManager.map_rng)
	if is_instance_valid(run_state):
		run_state.record_boss_encounter(chosen_boss)

	var temp_encounter := EncounterDefinition.new()
	var raw_support_budget: int = int(floor(daily_budget * 0.85))
	var budget_delta: int = _generate_slot_effects(temp_encounter, raw_support_budget)
	var support_budget: int = maxi(1, raw_support_budget + budget_delta)

	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter_for_entity(chosen_boss)
	var encounter: EncounterDefinition = drafter.draft_lineup(support_budget, {"daily_budget": daily_budget})

	encounter.boss_or_elite_unit_id = chosen_boss
	encounter.encounter_day = current_day
	encounter.daily_budget = daily_budget
	encounter.player_slot_effects = temp_encounter.player_slot_effects
	encounter.enemy_slot_effects = temp_encounter.enemy_slot_effects
	return encounter

# =============================================================================
# MID-COMBAT REINFORCEMENTS DISPATCHER
# =============================================================================

func generate_banner_reinforcements(
	banner_id: StringName,
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_secondary_trinkets: Array[StringName],
	rng: SeededRNG = RNGManager.combat_rng,
	board_snapshot: Array[EncounterDraftUnit] = []
) -> Array[Dictionary]:
	if empty_slots.is_empty():
		return []

	if not BannerDraftingRegistry.has_drafter(banner_id):
		return []

	var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(banner_id).reinforcement_strategy()
	if drafter is TraitBannerDrafter:
		var trait_drafter: TraitBannerDrafter = drafter as TraitBannerDrafter
		assert(board_snapshot.size() == current_board.size(), "Trait banner reinforcement requires the equipped survivor snapshot")
		return trait_drafter.draft_reinforcements_from_snapshot(daily_budget, board_snapshot, empty_slots, active_secondary_trinkets, rng)
	return drafter.draft_reinforcements(daily_budget, current_board, empty_slots, active_secondary_trinkets, rng)

# =============================================================================
# RESOURCE POOLS & SLOT EFFECTS
# =============================================================================

## Creates pools of available resources for enemy encounters (units, items, optionally trinkets).
func _create_resource_pools(include_trinkets: bool) -> Dictionary:
	var available_units: Array = []
	var available_items: Array = []
	var available_trinkets: Array = []

	for unit_value in Database.units.values():
		var d: GachaBallDefinition = unit_value
		if d.id == &"hero" or d.id == &"enemy_hero" or d.is_hero or d.is_player_exclusive:
			continue
		if String(d.id).begins_with("boss_") or String(d.id).begins_with("elite_"):
			continue
		if Database.get_entity_set(d) != Database.SET_BASE:
			continue
		if d.tags.has(&"HIDDEN") or d.tags.has(&"TOKEN") or d.tags.has(&"BOSS"):
			continue
		if EncounterSynergyRegistry.ENEMY_EXCLUDED_UNITS.has(d.id):
			continue
		available_units.append(d)

	for item_value in Database.items.values():
		var d: GachaBallDefinition = item_value
		if d.category == &"CONSUMABLE" or d.is_player_exclusive:
			continue
		if Database.get_entity_set(d) != Database.SET_BASE:
			continue
		available_items.append(d)

	if include_trinkets:
		for trinket_value in Database.trinkets.values():
			var trinket: TrinketDefinition = trinket_value
			if trinket.is_player_exclusive or trinket.is_banner or trinket.is_enemy_exclusive:
				continue
			if Database.get_entity_set(trinket) != Database.SET_BASE:
				continue
			available_trinkets.append(trinket)

	return {
		"units": available_units,
		"items": available_items,
		"trinkets": available_trinkets
	}

func _generate_slot_effects(encounter: EncounterDefinition, budget: int) -> int:
	encounter.player_slot_effects = [&"", &"", &"", &"", &""]
	encounter.enemy_slot_effects = [&"", &"", &"", &"", &""]

	var day: int = director_run_state.current_day
	if day <= 0:
		day = 1

	var spawn_chance := 0.0
	if day <= 10:
		spawn_chance = 0.10
	elif day <= 20:
		spawn_chance = 0.40
	elif day <= 40:
		spawn_chance = 0.75
	else:
		spawn_chance = 1.0

	if RNGManager.map_rng.randf() > spawn_chance:
		return 0

	var possible_player_combinations := []
	for b in range(4):
		for l in range(4):
			if b + l == 0:
				continue
			if b + l > 5:
				continue
			var cost = b * 3 + l * 2
			if cost <= budget - 1:
				possible_player_combinations.append({"burn": b, "lightning": l, "cost": cost})

	var player_cost = 0
	if not possible_player_combinations.is_empty():
		var chosen = RNGManager.map_rng.pick_random(possible_player_combinations)
		var num_burn: int = chosen["burn"]
		var num_lightning: int = chosen["lightning"]
		player_cost = chosen["cost"]

		var pos = [0, 1, 2, 3, 4]
		RNGManager.map_rng.shuffle(pos)
		for j in range(num_burn):
			encounter.player_slot_effects[pos.pop_back()] = &"burn"
		for j in range(num_lightning):
			encounter.player_slot_effects[pos.pop_back()] = &"lightning"

	var possible_enemy_combinations := []
	for b in range(4):
		for l in range(4):
			if b + l == 0:
				continue
			if b + l > 5:
				continue
			var bonus = b * 3 + l * 2
			if bonus <= budget - 1:
				possible_enemy_combinations.append({"burn": b, "lightning": l, "bonus": bonus})

	var enemy_bonus = 0
	if not possible_enemy_combinations.is_empty():
		var chosen = RNGManager.map_rng.pick_random(possible_enemy_combinations)
		var num_burn: int = chosen["burn"]
		var num_lightning: int = chosen["lightning"]
		enemy_bonus = chosen["bonus"]

		var pos = [0, 1, 2, 3, 4]
		RNGManager.map_rng.shuffle(pos)
		for j in range(num_burn):
			encounter.enemy_slot_effects[pos.pop_back()] = &"burn"
		for j in range(num_lightning):
			encounter.enemy_slot_effects[pos.pop_back()] = &"lightning"

	return enemy_bonus - player_cost
