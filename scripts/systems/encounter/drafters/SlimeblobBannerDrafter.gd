# res://scripts/systems/encounter/drafters/SlimeblobBannerDrafter.gd
class_name SlimeblobBannerDrafter
extends BannerDrafter

## Drafts an Elite Slimeblob encounter with front Spikeslimes and empty slots for Mitosis.
func draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition:
	var daily_budget: int = int(context.get("daily_budget", budget))
	var encounter := EncounterDefinition.new()
	encounter.id = StringName("encounter_slimeblob_%d" % Time.get_unix_time_from_system())
	encounter.banner_trinket_id = &"trinket_banner_slimeblob"
	encounter.boss_or_elite_unit_id = &"elite_slimeblob"

	var bonus_hp: int = int(floor(float(daily_budget) * 0.5))
	var bonus_pwr: int = int(floor(float(daily_budget) * 0.15))

	var remaining: int = budget

	# Deploy 1 Level 1 Spikeslime in Slot 0 (1G)
	var placements: Array[Dictionary] = []
	placements.append({
		"id": &"unit_spikeslime",
		"position": 0,
		"level": 1,
		"items": [] as Array[StringName],
		"bonus_hp": 0,
		"bonus_pwr": 0
	})
	remaining -= 1

	# Deploy 1 Level 1 Spikeslime in Slot 1 if budget allows (1G)
	if remaining >= 1:
		placements.append({
			"id": &"unit_spikeslime",
			"position": 1,
			"level": 1,
			"items": [] as Array[StringName],
			"bonus_hp": 0,
			"bonus_pwr": 0
		})
		remaining -= 1

	# Place Slimeblob at Slot 2
	var slimeblob_items: Array[StringName] = []

	# Secondary Trinkets (up to 2, 5G each)
	var slimeblob_trinket_options: Array[StringName] = [
		&"trinket_spiked_armor",
		&"trinket_polished_plate",
		&"trinket_trait_tank",
		&"trinket_armor_aura"
	]
	var trinkets_bought: int = 0
	while remaining >= 5 and trinkets_bought < 2 and encounter.enemy_trinket_ids.size() < MAX_TRINKETS:
		var unowned: Array[StringName] = []
		for t_id in slimeblob_trinket_options:
			if not encounter.enemy_trinket_ids.has(t_id):
				unowned.append(t_id)
		if unowned.is_empty():
			break
		var picked_t: StringName = unowned[RNGManager.map_rng.randi_range(0, unowned.size() - 1)]
		encounter.enemy_trinket_ids.append(picked_t)
		remaining -= 5
		trinkets_bought += 1

	# Synergistic defensive item on Slimeblob
	if remaining >= 4:
		slimeblob_items.append(&"item_t3_b")
		remaining -= 4
	elif remaining >= 2:
		slimeblob_items.append(&"item_t2_c")
		remaining -= 2
	elif remaining >= 1:
		slimeblob_items.append(&"item_t1_a")
		remaining -= 1

	# Stat Overflow directly onto Slimeblob
	if remaining > 0:
		bonus_hp += remaining * 2
		bonus_pwr += remaining * 1
		remaining = 0

	placements.append({
		"id": &"elite_slimeblob",
		"position": 2,
		"level": 1,
		"items": slimeblob_items,
		"bonus_hp": bonus_hp,
		"bonus_pwr": bonus_pwr
	})

	placements.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	encounter.enemy_placements = placements
	return encounter

## Slimeblob reinforcements are reactive via Mitosis and turn-start Evolution clock; horn is disabled.
func draft_reinforcements(
	_daily_budget: int,
	_current_board: Dictionary,
	_empty_slots: Array[int],
	_active_trinkets: Array[StringName],
	_rng: SeededRNG
) -> Array[Dictionary]:
	return []
