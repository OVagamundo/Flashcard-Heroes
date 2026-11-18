# res://scripts/systems/encounter/drafters/ToughmonBannerDrafter.gd
class_name ToughmonBannerDrafter
extends SwarmBannerDrafter

## Drafts a Toughmon encounter with a free Tank Crest, frontline tank wall,
## and free Tank Emblems on non-tank units forming synergy packages.
func draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition:
	var daily_budget: int = int(context.get("daily_budget", budget))
	var rng: SeededRNG = RNGManager.map_rng

	var bonus_hp: int = int(floor(float(daily_budget) * 0.3))
	var bonus_pwr: int = int(floor(float(daily_budget) * 0.1))

	var reserved: Dictionary = {
		4: {
			"id": &"boss_toughmon",
			"position": 4,
			"level": 1,
			"items": [] as Array[StringName],
			"bonus_hp": bonus_hp,
			"bonus_pwr": bonus_pwr
		}
	}

	# Innate Secondary Trinket: trinket_trait_tank at 0G cost
	var initial_trinkets: Array[StringName] = [&"trinket_trait_tank"]

	# Unit filter for single-unit drafts: must natively have Tank trait
	var tank_unit_filter := func(u_id: StringName) -> bool:
		return unit_has_trait(u_id, &"Tank")

	# Package filter: package must contain at least one Tank unit
	var tank_pkg_filter := func(pkg: Dictionary) -> bool:
		var u_list: Array = pkg.get("units", [])
		for u_id in u_list:
			if unit_has_trait(u_id, &"Tank"):
				return true
		return false

	# Emblem injection hook: non-tank units in packages receive a free item_emblem_tank
	var emblem_hook := func(placement: Dictionary, _is_pkg: bool) -> void:
		var u_id: StringName = placement.get("id", placement.get("unit_id", &""))
		var items: Array = placement.get("items", [])
		if not unit_has_trait(u_id, &"Tank") and items.is_empty():
			items.append(&"item_emblem_tank")

	var encounter: EncounterDefinition = draft_swarm(
		budget,
		reserved,
		tank_unit_filter,
		true, # Allow 1 additional secondary defensive trinket if budget permits
		rng,
		&"trinket_banner_toughmon",
		initial_trinkets,
		tank_pkg_filter,
		emblem_hook
	)

	encounter.boss_or_elite_unit_id = &"boss_toughmon"
	return encounter

## Mid-combat reinforcements: Summons tanks or packages with free Tank Emblems on non-tank units.
func draft_reinforcements(
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_trinkets: Array[StringName],
	rng: SeededRNG
) -> Array[Dictionary]:
	var wave_budget: int = maxi(1, int(floor(float(daily_budget) * 0.33)))

	var tank_unit_filter := func(u_id: StringName) -> bool:
		return unit_has_trait(u_id, &"Tank")

	var tank_pkg_filter := func(pkg: Dictionary) -> bool:
		var u_list: Array = pkg.get("units", [])
		for u_id in u_list:
			if unit_has_trait(u_id, &"Tank"):
				return true
		return false

	var emblem_hook := func(placement: Dictionary, _is_pkg: bool) -> void:
		var u_id: StringName = placement.get("unit_id", &"")
		var items: Array = placement.get("items", [])
		if not unit_has_trait(u_id, &"Tank") and items.is_empty():
			items.append(&"item_emblem_tank")

	return draft_reinforcements_modular(
		wave_budget,
		current_board,
		empty_slots,
		active_trinkets,
		tank_unit_filter,
		rng,
		tank_pkg_filter,
		emblem_hook
	)
