# res://scripts/systems/encounter/drafters/DoppelkunBannerDrafter.gd
class_name DoppelkunBannerDrafter
extends BannerDrafter

## Drafts a Doppelkun encounter deploying only Mimicloaks in front slots.
## Enforces minimum 2 Mimicloaks initially, and minimum 1 (or 2 if boss is alone) per wave.
func draft_lineup(budget: int, _context: Dictionary = {}) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = StringName("encounter_doppelkun_%d" % Time.get_unix_time_from_system())
	encounter.banner_trinket_id = &"trinket_banner_doppelkun"
	encounter.boss_or_elite_unit_id = &"boss_doppelkun"

	# Doppelkun at Slot 0 (Heroic Mirror, copies player's hero at battle start)
	var doppelkun_placement := {
		"id": &"boss_doppelkun",
		"position": 0,
		"level": 1,
		"items": [] as Array[StringName],
		"bonus_hp": 0,
		"bonus_pwr": 0
	}

	var placements: Dictionary = {}
	var remaining: int = budget
	var mimic_slots: Array[int] = [1, 2, 3, 4]

	# Enforce minimum 2 Mimicloaks when no units are on the board except the boss
	var num_mimics: int = 2
	if remaining >= 8:
		num_mimics = mini(4, remaining / 4)

	for i in range(num_mimics):
		var slot: int = mimic_slots[i]
		placements[slot] = {
			"id": &"EEFASpeCos",
			"position": slot,
			"level": 1,
			"items": [] as Array[StringName],
			"bonus_hp": 0,
			"bonus_pwr": 0
		}
	remaining = maxi(0, remaining - (num_mimics * 4))

	# Level up Mimicloaks (4G each for L1 -> L2)
	for slot in mimic_slots:
		if remaining < 4:
			break
		if placements.has(slot) and int(placements[slot]["level"]) == 1:
			placements[slot]["level"] = 2
			remaining -= 4

	# Equip offensive items on Mimicloaks
	for slot in mimic_slots:
		if remaining < 1:
			break
		if placements.has(slot):
			var items: Array[StringName] = placements[slot]["items"]
			if items.is_empty():
				if remaining >= 4:
					items.append(&"item_t3_b")
					remaining -= 4
				elif remaining >= 2:
					items.append(&"item_t2_b")
					remaining -= 2
				elif remaining >= 1:
					items.append(&"item_t1_b")
					remaining -= 1

	# Distribute leftover overflow to Mimicloaks (+2 HP / +1 PWR per 1G)
	if remaining > 0 and not placements.is_empty():
		_distribute_stat_overflow(placements, remaining)
		remaining = 0

	var all_placements: Array[Dictionary] = [doppelkun_placement]
	for slot in placements:
		all_placements.append(placements[slot])
	all_placements.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	encounter.enemy_placements = all_placements
	return encounter

## Mid-combat reinforcements: Drafts only Mimicloaks into frontmost empty slots.
## Guarantees at least 1 Mimicloak per turn (or 2 if boss is alone).
func draft_reinforcements(
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	_active_trinkets: Array[StringName],
	_rng: SeededRNG
) -> Array[Dictionary]:
	if empty_slots.is_empty():
		return []

	var wave_budget: int = maxi(1, int(floor(float(daily_budget) * 0.33)))

	# Check how many living non-boss units remain on the enemy board
	var living_non_boss: int = 0
	for slot in current_board:
		var u_id: StringName = current_board[slot]
		if u_id != &"boss_doppelkun" and u_id != &"":
			living_non_boss += 1

	var min_mimics: int = 1 if living_non_boss > 0 else mini(2, empty_slots.size())
	var affordable_mimics: int = wave_budget / 4
	var count_to_summon: int = mini(empty_slots.size(), maxi(min_mimics, affordable_mimics))

	# Prefer front slot positions (sorted ascending)
	var sorted_empty: Array[int] = empty_slots.duplicate()
	sorted_empty.sort()

	var staged: Dictionary = {}
	for i in range(count_to_summon):
		var slot: int = sorted_empty[i]
		staged[slot] = {
			"unit_id": &"EEFASpeCos",
			"slot": slot,
			"level": 1,
			"items": [] as Array[StringName],
			"bonus_hp": 0,
			"bonus_pwr": 0
		}

	var remaining: int = maxi(0, wave_budget - (count_to_summon * 4))

	# Level up summoned Mimicloaks
	for slot in staged.keys():
		if remaining >= 4:
			staged[slot]["level"] = 2
			remaining -= 4

	# Equip offensive items
	for slot in staged.keys():
		if remaining < 1:
			break
		if staged[slot]["items"].is_empty():
			if remaining >= 4:
				staged[slot]["items"].append(&"item_t3_b")
				remaining -= 4
			elif remaining >= 2:
				staged[slot]["items"].append(&"item_t2_b")
				remaining -= 2
			elif remaining >= 1:
				staged[slot]["items"].append(&"item_t1_b")
				remaining -= 1

	# Stat overflow on staged mimics
	if remaining > 0 and not staged.is_empty():
		_distribute_stat_overflow(staged, remaining)
		remaining = 0

	var result: Array[Dictionary] = []
	for slot in staged.keys():
		result.append(staged[slot])
	result.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))
	return result
