# res://scripts/systems/encounter/drafters/SwarmBannerDrafter.gd
class_name SwarmBannerDrafter
extends BannerDrafter

## Drafts a Swarm lineup using contiguous Atomic Synergy Packages and secondary trinket voting.
func draft_lineup(budget: int, _context: Dictionary = {}) -> EncounterDefinition:
	return draft_swarm(
		budget,
		{},
		Callable(),
		true,
		RNGManager.map_rng,
		&"trinket_banner_swarm"
	)

## Reusable Modular Swarm Drafting Engine.
func draft_swarm(
	budget: int,
	reserved_slots: Dictionary = {},
	unit_filter: Callable = Callable(),
	allow_trinkets: bool = true,
	rng: SeededRNG = RNGManager.map_rng,
	banner_trinket_id: StringName = &"trinket_banner_swarm",
	initial_trinkets: Array[StringName] = [],
	package_filter: Callable = Callable(),
	unit_placed_hook: Callable = Callable(),
	score_pkg_modifier: Callable = Callable(),
	level_weight: float = 25.0,
	item_weight: float = 30.0
) -> EncounterDefinition:
	var encounter := EncounterDefinition.new()
	encounter.id = StringName("encounter_swarm_%d" % Time.get_unix_time_from_system())
	encounter.banner_trinket_id = banner_trinket_id
	encounter.enemy_trinket_ids = initial_trinkets.duplicate()
	# The commander's drafting affinities still contribute without taking a trinket slot.
	var drafting_affinities: Array[StringName] = initial_trinkets.duplicate()
	drafting_affinities.push_front(banner_trinket_id)

	var placements: Dictionary = reserved_slots.duplicate(true)
	var board: Dictionary = {}
	for slot_idx in placements.keys():
		board[int(slot_idx)] = placements[slot_idx]["id"]

	var remaining: int = budget

	# Pre-allocate 5G for Secondary Trinket if budget allows, to prevent unit over-spending
	var reserved_for_trinket: int = 0
	if allow_trinkets and remaining >= 8 and encounter.enemy_trinket_ids.size() < MAX_TRINKETS:
		var trinket_roll_chance: float = 0.70 if remaining >= 10 else 0.40
		if rng.randf() < trinket_roll_chance:
			reserved_for_trinket = 5
			remaining -= 5

	# =========================================================================
	# PHASE 1: Atomic Synergy Packages & Positional Chaining Drafting
	# =========================================================================
	var open_slots: Array[int] = []
	for s in range(MAX_UNITS):
		if not board.has(s):
			open_slots.append(s)

	while remaining > 0 and not open_slots.is_empty():
		var start_slot: int = open_slots[0]
		var avail_len: int = 0
		for s in range(start_slot, MAX_UNITS):
			if open_slots.has(s):
				avail_len += 1
			else:
				break

		var package_placed: bool = false
		if avail_len >= 2 and remaining >= 2:
			var raw_pkgs: Array[Dictionary] = EncounterSynergyRegistry.get_eligible_packages(remaining, start_slot, avail_len, unit_filter)
			var eligible_pkgs: Array[Dictionary] = []
			if package_filter.is_valid():
				for p in raw_pkgs:
					if package_filter.call(p):
						eligible_pkgs.append(p)
			else:
				eligible_pkgs = raw_pkgs

			if not eligible_pkgs.is_empty():
				var candidate_scored: Array[Dictionary] = []
				var tot_score: float = 0.0
				for pkg in eligible_pkgs:
					var sc: float = EncounterSynergyRegistry.score_package(pkg, start_slot, board, drafting_affinities)
					if score_pkg_modifier.is_valid():
						sc = float(score_pkg_modifier.call(pkg, sc))
					candidate_scored.append({"pkg": pkg, "score": sc})
					tot_score += sc

				assert(tot_score > 0.0, "SwarmBannerDrafter: tot_score must be positive")
				var roll: float = rng.randf() * tot_score
				var cum: float = 0.0
				var picked_pkg: Dictionary = candidate_scored[0]["pkg"]
				for cand in candidate_scored:
					cum += float(cand["score"])
					if roll < cum:
						picked_pkg = cand["pkg"]
						break

				var u_list: Array = picked_pkg["units"]
				var req_items: Dictionary = picked_pkg.get("required_items", {})
				for rel_idx in range(u_list.size()):
					var slot: int = start_slot + rel_idx
					var u_id: StringName = u_list[rel_idx]
					var items_arr: Array[StringName] = []
					if req_items.has(rel_idx):
						items_arr.append(req_items[rel_idx])
					var placement_dict: Dictionary = {
						"id": u_id,
						"position": slot,
						"level": 1,
						"items": items_arr,
						"bonus_hp": 0,
						"bonus_pwr": 0
					}
					if unit_placed_hook.is_valid():
						unit_placed_hook.call(placement_dict, true)
					placements[slot] = placement_dict
					board[slot] = u_id
					open_slots.erase(slot)

				remaining -= int(picked_pkg["base_cost"])
				package_placed = true

		if not package_placed:
			# Single-unit drafting fallback
			var candidate_placements: Array[Dictionary] = []
			for u_id in EncounterSynergyRegistry.UNIT_PROFILES.keys():
				if not EncounterSynergyRegistry.is_unit_enemy_draftable(u_id):
					continue
				if unit_filter.is_valid() and not unit_filter.call(u_id):
					continue
				var u_cost: int = EncounterSynergyRegistry.get_unit_cost(u_id)
				if u_cost > remaining:
					continue
				if not EncounterSynergyRegistry.is_valid_slot_for_unit(u_id, start_slot, board):
					continue

				var score: float = EncounterSynergyRegistry.score_unit_in_slot(u_id, start_slot, board, drafting_affinities)
				candidate_placements.append({
					"unit_id": u_id,
					"cost": u_cost,
					"score": score
				})

			if candidate_placements.is_empty():
				break

			var tot_score: float = 0.0
			for c in candidate_placements:
				tot_score += float(c["score"])
			var u_roll: float = rng.randf() * tot_score
			var u_cum: float = 0.0
			var picked: Dictionary = candidate_placements[0]
			for c in candidate_placements:
				u_cum += float(c["score"])
				if u_roll < u_cum:
					picked = c
					break

			var new_id: StringName = picked["unit_id"]
			var new_cost: int = int(picked["cost"])
			var placement_dict: Dictionary = {
				"id": new_id,
				"position": start_slot,
				"level": 1,
				"items": [] as Array[StringName],
				"bonus_hp": 0,
				"bonus_pwr": 0
			}
			if unit_placed_hook.is_valid():
				unit_placed_hook.call(placement_dict, false)
			placements[start_slot] = placement_dict
			board[start_slot] = new_id
			open_slots.erase(start_slot)
			remaining -= new_cost

	# =========================================================================
	# PHASE 2: Secondary Trinket Purchase
	# =========================================================================
	remaining += reserved_for_trinket
	while allow_trinkets and remaining >= 5 and board.size() >= 2 and encounter.enemy_trinket_ids.size() < MAX_TRINKETS:
		var best_trinket: StringName = EncounterSynergyRegistry.select_best_voted_trinket(board, encounter.enemy_trinket_ids, rng)
		if best_trinket == &"":
			break
		encounter.enemy_trinket_ids.append(best_trinket)
		remaining -= 5

	# =========================================================================
	# PHASE 3: Synergistic Items and Level Ups
	# =========================================================================
	while remaining > 0:
		var upgrade_actions: Array[Dictionary] = []

		# Evaluate Item candidates
		var item_candidates: Array[Dictionary] = []
		for slot in placements.keys():
			if reserved_slots.has(slot):
				continue
			var p: Dictionary = placements[slot]
			if not p["items"].is_empty():
				continue
			var prof: Dictionary = EncounterSynergyRegistry.get_profile(p["id"])
			var p_items: Array = prof.get("items", [])
			var best_item: StringName = &""
			var best_cost: int = 0
			for i_id in p_items:
				var cost: int = _get_item_cost(i_id)
				if cost <= remaining and cost > best_cost:
					best_cost = cost
					best_item = i_id
			if best_item != &"":
				item_candidates.append({
					"slot": slot,
					"item_id": best_item,
					"cost": best_cost
				})

		if not item_candidates.is_empty():
			upgrade_actions.append({
				"type": "item",
				"weight": item_weight,
				"candidates": item_candidates
			})

		# Evaluate Level Up candidates
		var level_candidates: Array[Dictionary] = []
		for slot in placements.keys():
			if reserved_slots.has(slot):
				continue
			var p: Dictionary = placements[slot]
			var cur_lvl: int = int(p.get("level", 1))
			if cur_lvl >= 3:
				continue
			var base_c: int = EncounterSynergyRegistry.get_unit_cost(p["id"])
			var upgrade_cost: int = base_c * (1 << (cur_lvl - 1))
			if upgrade_cost <= remaining:
				level_candidates.append({
					"slot": slot,
					"cost": upgrade_cost
				})

		if not level_candidates.is_empty():
			upgrade_actions.append({
				"type": "level",
				"weight": level_weight,
				"candidates": level_candidates
			})

		if upgrade_actions.is_empty():
			break

		var total_act_weight: float = 0.0
		for act in upgrade_actions:
			total_act_weight += float(act["weight"])
		var act_roll: float = rng.randf() * total_act_weight
		var act_cum: float = 0.0
		var chosen_act: Dictionary = upgrade_actions[0]
		for act in upgrade_actions:
			act_cum += float(act["weight"])
			if act_roll < act_cum:
				chosen_act = act
				break

		match chosen_act["type"]:
			"item":
				var cands: Array[Dictionary] = chosen_act["candidates"]
				var picked_item: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
				var s: int = int(picked_item["slot"])
				placements[s]["items"].append(picked_item["item_id"])
				remaining -= int(picked_item["cost"])
			"level":
				var cands: Array[Dictionary] = chosen_act["candidates"]
				var picked_lvl: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
				var s: int = int(picked_lvl["slot"])
				placements[s]["level"] = int(placements[s]["level"]) + 1
				remaining -= int(picked_lvl["cost"])

	# =========================================================================
	# PHASE 4: Stat Overflow Fallback
	# =========================================================================
	if remaining > 0:
		var reserved_keys: Array[int] = []
		for rk in reserved_slots.keys():
			reserved_keys.append(int(rk))
		_distribute_stat_overflow(placements, remaining, reserved_keys)
		remaining = 0

	for slot_idx in placements.keys():
		encounter.enemy_placements.append(placements[slot_idx])

	encounter.enemy_placements.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
	return encounter

## Mid-combat reinforcements: Every other turn, 33% daily budget.
func draft_reinforcements(
	daily_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_trinkets: Array[StringName],
	rng: SeededRNG
) -> Array[Dictionary]:
	var wave_budget: int = maxi(1, int(floor(float(daily_budget) * 0.33)))
	return draft_reinforcements_modular(wave_budget, current_board, empty_slots, active_trinkets, Callable(), rng)

## Reusable Modular Reinforcement Engine.
func draft_reinforcements_modular(
	wave_budget: int,
	current_board: Dictionary,
	empty_slots: Array[int],
	active_secondary_trinkets: Array[StringName],
	unit_filter: Callable,
	rng: SeededRNG,
	package_filter: Callable = Callable(),
	unit_placed_hook: Callable = Callable()
) -> Array[Dictionary]:
	var remaining: int = wave_budget
	var board: Dictionary = current_board.duplicate()
	var sorted_empty_slots: Array[int] = empty_slots.duplicate()
	sorted_empty_slots.sort()
	var staged_summons: Dictionary = {}

	var i: int = 0
	while i < sorted_empty_slots.size() and remaining > 0:
		var slot: int = sorted_empty_slots[i]
		var package_placed: bool = false

		if i + 1 < sorted_empty_slots.size() and sorted_empty_slots[i + 1] == slot + 1 and remaining >= 2:
			var raw_pkgs: Array[Dictionary] = EncounterSynergyRegistry.get_eligible_packages(remaining, slot, 2, unit_filter)
			var eligible_pkgs: Array[Dictionary] = []
			if package_filter.is_valid():
				for p in raw_pkgs:
					if package_filter.call(p):
						eligible_pkgs.append(p)
			else:
				eligible_pkgs = raw_pkgs

			if not eligible_pkgs.is_empty():
				var candidate_scored: Array[Dictionary] = []
				var tot_score: float = 0.0
				for pkg in eligible_pkgs:
					var sc: float = EncounterSynergyRegistry.score_package(pkg, slot, board, active_secondary_trinkets)
					candidate_scored.append({"pkg": pkg, "score": sc})
					tot_score += sc

				assert(tot_score > 0.0, "SwarmBannerDrafter: tot_score must be positive")
				var roll: float = rng.randf() * tot_score
				var cum: float = 0.0
				var picked_pkg: Dictionary = candidate_scored[0]["pkg"]
				for cand in candidate_scored:
					cum += float(cand["score"])
					if roll < cum:
						picked_pkg = cand["pkg"]
						break

				var u_list: Array = picked_pkg["units"]
				var req_items: Dictionary = picked_pkg.get("required_items", {})
				for rel_idx in range(u_list.size()):
					var target_s: int = slot + rel_idx
					var u_id: StringName = u_list[rel_idx]
					var items_arr: Array[StringName] = []
					if req_items.has(rel_idx):
						items_arr.append(req_items[rel_idx])
					var staged_dict: Dictionary = {
						"unit_id": u_id,
						"slot": target_s,
						"level": 1,
						"items": items_arr,
						"bonus_hp": 0,
						"bonus_pwr": 0
					}
					if unit_placed_hook.is_valid():
						unit_placed_hook.call(staged_dict, true)
					staged_summons[target_s] = staged_dict
					board[target_s] = u_id

				remaining -= int(picked_pkg["base_cost"])
				package_placed = true
				i += 2

		if not package_placed:
			var candidate_placements: Array[Dictionary] = []
			for u_id in EncounterSynergyRegistry.UNIT_PROFILES.keys():
				if not EncounterSynergyRegistry.is_unit_enemy_draftable(u_id):
					continue
				if unit_filter.is_valid() and not unit_filter.call(u_id):
					continue
				var u_cost: int = EncounterSynergyRegistry.get_unit_cost(u_id)
				if u_cost > remaining:
					continue
				if not EncounterSynergyRegistry.is_valid_slot_for_unit(u_id, slot, board):
					continue

				var score: float = EncounterSynergyRegistry.score_unit_in_slot(u_id, slot, board, active_secondary_trinkets)
				candidate_placements.append({
					"unit_id": u_id,
					"cost": u_cost,
					"score": score
				})

			if not candidate_placements.is_empty():
				var tot_score: float = 0.0
				for c in candidate_placements:
					tot_score += float(c["score"])
				var roll: float = rng.randf() * tot_score
				var cum: float = 0.0
				var picked: Dictionary = candidate_placements[0]
				for c in candidate_placements:
					cum += float(c["score"])
					if roll < cum:
						picked = c
						break

				var p_id: StringName = picked["unit_id"]
				var p_cost: int = int(picked["cost"])
				var staged_dict: Dictionary = {
					"unit_id": p_id,
					"slot": slot,
					"level": 1,
					"items": [] as Array[StringName],
					"bonus_hp": 0,
					"bonus_pwr": 0
				}
				if unit_placed_hook.is_valid():
					unit_placed_hook.call(staged_dict, false)
				staged_summons[slot] = staged_dict
				board[slot] = p_id
				remaining -= p_cost
			i += 1

	if remaining > 0 and not staged_summons.is_empty():
		_distribute_stat_overflow(staged_summons, remaining)
		remaining = 0

	var result: Array[Dictionary] = []
	for slot in staged_summons.keys():
		result.append(staged_summons[slot])
	result.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))
	return result
