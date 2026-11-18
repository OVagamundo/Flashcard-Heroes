# res://scripts/systems/encounter/drafters/BurnieBannerDrafter.gd
class_name BurnieBannerDrafter
extends BannerDrafter

var _fire_drafter: FireBannerDrafter = FireBannerDrafter.new()

func reinforcement_strategy() -> BannerDrafter:
	return _fire_drafter

## Drafts an Elite Burnie encounter with preplaced Burnie in Slot 2 and Fire support.
func draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition:
	var daily_budget: int = int(context.get("daily_budget", budget))
	var bonus_hp: int = int(floor(float(daily_budget) * 0.4))
	var bonus_pwr: int = int(floor(float(daily_budget) * 0.2))

	var fire_context: Dictionary = context.duplicate()
	fire_context["preplaced_burnie_slot"] = 2

	var encounter: EncounterDefinition = _fire_drafter.draft_lineup(budget, fire_context)
	encounter.banner_trinket_id = &"trinket_banner_burnie"
	encounter.boss_or_elite_unit_id = &"elite_burnie"

	# Insert Elite Burnie at Slot 2
	var burnie_placement := {
		"id": &"elite_burnie",
		"position": 2,
		"level": 1,
		"items": [] as Array[StringName],
		"bonus_hp": bonus_hp,
		"bonus_pwr": bonus_pwr
	}

	encounter.enemy_placements.append(burnie_placement)
	encounter.enemy_placements.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	return encounter

## Burnie reinforces using the Fire Banner reinforcement engine.
func draft_reinforcements(
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_trinkets: Array[StringName],
	rng: SeededRNG
) -> Array[Dictionary]:
	return _fire_drafter.draft_reinforcements(daily_budget, current_board, empty_slots, active_trinkets, rng)
