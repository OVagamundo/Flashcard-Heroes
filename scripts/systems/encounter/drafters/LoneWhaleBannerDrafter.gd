# res://scripts/systems/encounter/drafters/LoneWhaleBannerDrafter.gd
class_name LoneWhaleBannerDrafter
extends BannerDrafter

## Drafts a solitary Soliwhale encounter scaling with empty slots.
func draft_lineup(budget: int, _context: Dictionary = {}) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = StringName("encounter_lone_whale_%d" % Time.get_unix_time_from_system())
	encounter.banner_trinket_id = &"trinket_banner_lone_whale"

	var soliwhale_cost: int = 2
	var remaining: int = budget - soliwhale_cost
	if remaining < 0:
		remaining = 0

	var unit_level: int = 1
	if remaining >= 6:
		unit_level = 3
		remaining -= 6
	elif remaining >= 2:
		unit_level = 2
		remaining -= 2

	var equipped_items: Array[StringName] = []
	if remaining >= 4:
		var t3_options: Array[StringName] = [&"item_t3_b", &"item_t3_c", &"item_t3_d"]
		equipped_items.append(t3_options[RNGManager.map_rng.randi_range(0, t3_options.size() - 1)])
		remaining -= 4
	elif remaining >= 2:
		equipped_items.append(&"item_t2_c")
		remaining -= 2
	elif remaining >= 1:
		equipped_items.append(&"item_t1_a")
		remaining -= 1

	var soliwhale_trinket_votes: Array[StringName] = [
		&"trinket_underdog_emblem",
		&"trinket_spiked_armor",
		&"trinket_polished_plate",
		&"trinket_aegis"
	]
	while remaining >= 5 and encounter.enemy_trinket_ids.size() < MAX_TRINKETS:
		var unowned: Array[StringName] = []
		for t_id in soliwhale_trinket_votes:
			if not encounter.enemy_trinket_ids.has(t_id):
				unowned.append(t_id)
		if unowned.is_empty():
			break
		var picked_t: StringName = unowned[RNGManager.map_rng.randi_range(0, unowned.size() - 1)]
		encounter.enemy_trinket_ids.append(picked_t)
		remaining -= 5

	var bonus_hp: int = remaining * 2
	var bonus_pwr: int = remaining * 1

	encounter.enemy_placements.append({
		"id": &"WATnkAni",
		"position": 0,
		"level": unit_level,
		"items": equipped_items,
		"bonus_hp": bonus_hp,
		"bonus_pwr": bonus_pwr
	})

	return encounter

## Lone Whale employs solitary unit identity: zero reinforcements.
func draft_reinforcements(
	_daily_budget: int,
	_current_board: Dictionary,
	_empty_slots: Array[int],
	_active_trinkets: Array[StringName],
	_rng: SeededRNG
) -> Array[Dictionary]:
	return []
