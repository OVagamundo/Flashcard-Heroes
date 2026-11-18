# res://scripts/systems/encounter/drafters/DustmonBannerDrafter.gd
class_name DustmonBannerDrafter
extends SwarmBannerDrafter

## Drafts a Dustmon encounter rolling 1 or 2 random traits, injecting free Crests/Emblems,
## and assembling lower-tier swarm packages.
func draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition:
	var daily_budget: int = int(context.get("daily_budget", budget))
	var rng: SeededRNG = RNGManager.map_rng

	var bonus_hp: int = int(floor(float(daily_budget) * 0.4))
	var bonus_pwr: int = int(floor(float(daily_budget) * 0.2))

	var reserved: Dictionary = {
		4: {
			"id": &"boss_dustmon",
			"position": 4,
			"level": 1,
			"items": [] as Array[StringName],
			"bonus_hp": bonus_hp,
			"bonus_pwr": bonus_pwr
		}
	}

	# Roll 1 or 2 random traits
	var all_traits: Array[StringName] = EnemyTraitBannerProfiles.TRAITS.duplicate()
	rng.shuffle(all_traits)
	var trait_count: int = rng.randi_range(1, 2)
	var rolled_traits: Array[StringName] = []
	for idx in range(trait_count):
		rolled_traits.append(all_traits[idx])

	# Add trait Crests for free (0G)
	var initial_trinkets: Array[StringName] = []
	for t in rolled_traits:
		var crest: StringName = get_trait_crest(t)
		if crest != &"" and not initial_trinkets.has(crest):
			initial_trinkets.append(crest)

	# Unit filter for single-unit drafts: must match one of the rolled traits
	var trait_unit_filter := func(u_id: StringName) -> bool:
		return _unit_has_any_trait(u_id, rolled_traits)

	# Package filter: package must contain at least one unit with a rolled trait
	var trait_pkg_filter := func(pkg: Dictionary) -> bool:
		var u_list: Array = pkg.get("units", [])
		for u_id in u_list:
			if _unit_has_any_trait(u_id, rolled_traits):
				return true
		return false

	# Emblem injection hook: non-matching units in packages receive a free trait emblem
	var emblem_hook := func(placement: Dictionary, _is_pkg: bool) -> void:
		var u_id: StringName = placement.get("id", placement.get("unit_id", &""))
		var items: Array = placement.get("items", [])
		if not _unit_has_any_trait(u_id, rolled_traits) and items.is_empty():
			var emblem_id: StringName = get_trait_emblem(rolled_traits[0])
			if emblem_id != &"":
				items.append(emblem_id)

	# Score package modifier: heavily prefer lower tier / lower cost packages (T1 & T2)
	var pkg_score_mod := func(pkg: Dictionary, base_score: float) -> float:
		var c: int = int(pkg.get("base_cost", 1))
		if c <= 3:
			return base_score * 2.0
		elif c <= 6:
			return base_score * 1.3
		return base_score * 0.4

	# Use Swarm modular drafting with support budget
	var encounter: EncounterDefinition = draft_swarm(
		budget,
		reserved,
		trait_unit_filter,
		false, # Trinkets already populated with free Crests
		rng,
		&"trinket_banner_dustmon",
		initial_trinkets,
		trait_pkg_filter,
		emblem_hook,
		pkg_score_mod,
		10.0, # Deprioritize high level ups
		35.0  # Prefer items
	)

	encounter.boss_or_elite_unit_id = &"boss_dustmon"
	return encounter

## Mid-combat reinforcements: Prioritizes active traits and equips free emblems on non-matching units.
func draft_reinforcements(
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_trinkets: Array[StringName],
	rng: SeededRNG
) -> Array[Dictionary]:
	var wave_budget: int = maxi(1, int(floor(float(daily_budget) * 0.33)))
	var active_traits: Array[StringName] = _get_traits_from_crests(active_trinkets)
	if active_traits.is_empty():
		# Fallback if no trait Crest was present
		active_traits = [&"Tank"]

	# Unit filter: must have one of active traits and preferably cost <= 2
	var fodder_filter := func(u_id: StringName) -> bool:
		if EncounterSynergyRegistry.get_unit_cost(u_id) > 2:
			return false
		return _unit_has_any_trait(u_id, active_traits)

	var pkg_filter := func(pkg: Dictionary) -> bool:
		var u_list: Array = pkg.get("units", [])
		for u_id in u_list:
			if _unit_has_any_trait(u_id, active_traits):
				return true
		return false

	var emblem_hook := func(placement: Dictionary, _is_pkg: bool) -> void:
		var u_id: StringName = placement.get("unit_id", &"")
		var items: Array = placement.get("items", [])
		if not _unit_has_any_trait(u_id, active_traits) and items.is_empty():
			var emblem_id: StringName = get_trait_emblem(active_traits[0])
			if emblem_id != &"":
				items.append(emblem_id)

	return draft_reinforcements_modular(
		wave_budget,
		current_board,
		empty_slots,
		active_trinkets,
		fodder_filter,
		rng,
		pkg_filter,
		emblem_hook
	)

static func _unit_has_any_trait(unit_id: StringName, traits: Array[StringName]) -> bool:
	for t in traits:
		if unit_has_trait(unit_id, t):
			return true
	return false

static func _get_traits_from_crests(active_trinkets: Array[StringName]) -> Array[StringName]:
	var found: Array[StringName] = []
	for t_name in TRAIT_MAP.keys():
		var crest: StringName = get_trait_crest(t_name)
		if active_trinkets.has(crest):
			found.append(t_name)
	return found
