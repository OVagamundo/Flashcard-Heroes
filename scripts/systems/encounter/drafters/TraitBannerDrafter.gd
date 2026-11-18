class_name TraitBannerDrafter
extends BannerDrafter

class Plan extends RefCounted:
	var units: Dictionary[int, EncounterDraftUnit] = {}
	var weight: float = 100.0
	func cost() -> int:
		var total: int = 0
		for unit: EncounterDraftUnit in units.values():
			total += unit.gold_cost()
		return total

var profile: EnemyTraitBannerProfile
var _seeds: Array[Plan] = []
var _seed_keys: Dictionary[String, bool] = {}
var _seeds_ready: bool = false

func _init(strategy: EnemyTraitBannerProfile) -> void:
	assert(strategy != null, "TraitBannerDrafter requires a strategy profile")
	profile = strategy

func minimum_budget() -> int:
	_prepare_seeds()
	var minimum: int = 2147483647
	for seed: Plan in _seeds:
		minimum = mini(minimum, seed.cost())
	assert(minimum < 2147483647, "No viable formation for %s" % profile.trait_name)
	return minimum

func draft_lineup(budget: int, _context: Dictionary = {}) -> EncounterDefinition:
	_prepare_seeds()
	return _lineup(budget, _seeds, profile.banner_id, RNGManager.map_rng)

## Burnie reserves a slot, but the boss itself is inserted by BurnieBannerDrafter.
func draft_with_reserved(budget: int, reserved_unit: EncounterDraftUnit, banner_id: StringName) -> EncounterDefinition:
	var reserved_board: Dictionary[int, EncounterDraftUnit] = {reserved_unit.slot: reserved_unit}
	var seeds: Array[Plan] = _build_seeds(reserved_board)
	return _lineup(budget, seeds, banner_id, RNGManager.map_rng)

func _lineup(budget: int, seeds: Array[Plan], banner_id: StringName, rng: SeededRNG) -> EncounterDefinition:
	assert(budget > 0, "Trait banner budget must be positive")
	var affordable: Array[Plan] = []
	for seed: Plan in seeds:
		if seed.cost() <= budget:
			affordable.append(seed)
	assert(not affordable.is_empty(), "%s cannot afford a working core with %d Gold" % [banner_id, budget])
	var board: Dictionary[int, EncounterDraftUnit] = _copy_board(_pick(affordable, rng).units)
	_fill(board, budget, rng, false)
	var trinkets: Array[StringName] = [profile.crest()]
	_spend_upgrades(board, budget, trinkets, rng)
	assert(_trait_count(board) >= profile.threshold() and _valid_board(board), "Broken trait_name banner formation: %s" % banner_id)
	var encounter := EncounterDefinition.new()
	encounter.id = StringName("%s_%s" % [banner_id, _board_key(board)])
	encounter.banner_trinket_id = banner_id
	encounter.enemy_trinket_ids = trinkets
	for slot: int in range(MAX_UNITS):
		if board.has(slot) and not board[slot].reserved:
			encounter.enemy_placements.append(board[slot].placement())
	return encounter

func _prepare_seeds() -> void:
	if _seeds_ready:
		return
	var empty: Dictionary[int, EncounterDraftUnit] = {}
	_seeds = _build_seeds(empty)
	assert(not _seeds.is_empty(), "Trait banner %s has no valid core" % profile.trait_name)
	_seeds_ready = true

func _build_seeds(reserved_board: Dictionary[int, EncounterDraftUnit]) -> Array[Plan]:
	var result: Array[Plan] = []
	_seed_keys.clear()
	for package: Dictionary in profile.packages():
		for start: int in package["valid_start_slots"]:
			var candidate: Plan = _package_plan(package, start, reserved_board, false)
			if candidate != null:
				_complete_seed(candidate, result)
	if not reserved_board.is_empty():
		# A preplaced boss can supply the trait threshold at very small support budgets.
		for unit_id: StringName in profile.filler_ids():
			for slot: int in range(MAX_UNITS):
				if reserved_board.has(slot):
					continue
				var candidate := Plan.new()
				candidate.units = _copy_board(reserved_board)
				candidate.units[slot] = EncounterDraftUnit.new(unit_id, slot)
				if _ensure_healing(candidate.units):
					_complete_seed(candidate, result)
	return result

func _complete_seed(candidate: Plan, result: Array[Plan]) -> void:
	var key: String = _board_key(candidate.units)
	if _seed_keys.has(key):
		return
	_seed_keys[key] = true
	if _trait_count(candidate.units) >= profile.threshold() and _native_anchor(candidate.units) and _valid_board(candidate.units):
		result.append(candidate)
		return
	if candidate.units.size() == MAX_UNITS:
		return
	for unit_id: StringName in profile.filler_ids():
		for slot: int in range(MAX_UNITS):
			if candidate.units.has(slot):
				continue
			var next := Plan.new()
			next.units = _copy_board(candidate.units)
			next.weight = candidate.weight
			next.units[slot] = EncounterDraftUnit.new(unit_id, slot)
			# Adding another unit cannot repair a forbidden slot or a missing durable heal target.
			if not EncounterSynergyRegistry.is_valid_slot_for_unit(unit_id, slot, _id_board(next.units)):
				continue
			if _ensure_healing(next.units):
				_complete_seed(next, result)

func _package_plan(package: Dictionary, start: int, board: Dictionary[int, EncounterDraftUnit], repair: bool) -> Plan:
	var candidate := Plan.new()
	candidate.units = _copy_board(board)
	candidate.weight = float(package.get("base_weight", 100.0))
	var ids: Array = package["units"]
	var required: Dictionary = package["required_items"]
	var matches: int = 0
	var additions: int = 0
	for relative: int in range(ids.size()):
		var slot: int = start + relative
		if slot >= MAX_UNITS:
			return null
		var unit_id: StringName = ids[relative]
		assert(EncounterSynergyRegistry.is_unit_enemy_draftable(unit_id), "Illegal enemy package unit %s" % unit_id)
		if board.has(slot):
			if not repair or board[slot].unit_id != unit_id or board[slot].trait_count(profile.trait_name) == 0:
				return null
			if required.has(relative) and not board[slot].items.has(required[relative]):
				return null
			matches += 1
			continue
		var unit := EncounterDraftUnit.new(unit_id, slot)
		if required.has(relative):
			unit.items.append(required[relative])
		if not profile.native_unit(unit_id):
			if not unit.items.is_empty() and unit.items[0] != profile.emblem():
				return null # This variant cannot fit its required item and emblem in one slot.
			if unit.items.is_empty():
				unit.items.append(profile.emblem())
		candidate.units[slot] = unit
		additions += 1
	if additions == 0 or (repair and matches == 0):
		return null
	# A transfer must not overwrite a required emblem or another package's equipment.
	for relative: int in range(ids.size() - 1):
		if ids[relative] == &"FFWASupMec" and not candidate.units[start + relative + 1].items.is_empty():
			return null
	if not _ensure_healing(candidate.units):
		return null
	return candidate

func _ensure_healing(board: Dictionary[int, EncounterDraftUnit]) -> bool:
	for unit: EncounterDraftUnit in board.values():
		if unit.reserved or unit.unit_id not in [&"EFTnkMec", &"FWFigFod"]:
			continue
		if not _healing_available(unit, board):
			if not unit.items.is_empty():
				return false
			unit.items.append(&"item_t1_a")
	return true

func _healing_available(unit: EncounterDraftUnit, board: Dictionary[int, EncounterDraftUnit]) -> bool:
	if unit.items.has(&"item_t1_a") or unit.items.has(&"item_t2_c") or unit.items.has(&"item_t3_c"):
		return true
	if board.has(unit.slot + 1) and board[unit.slot + 1].unit_id == &"WSupAni":
		return true
	if _trait_count(board) < profile.threshold():
		return false
	if profile.trait_name == &"Animal" and unit.trait_count(&"Animal") > 0:
		return true
	if profile.trait_name == &"Food" and board.has(unit.slot - 1) and board[unit.slot - 1].trait_count(&"Food") > 0:
		return true
	return profile.trait_name == &"Water" and board.has(unit.slot + 1) and board[unit.slot + 1].trait_count(&"Water") > 0

func _restores_dependency(before: Dictionary[int, EncounterDraftUnit], after: Dictionary[int, EncounterDraftUnit]) -> bool:
	for unit: EncounterDraftUnit in before.values():
		if unit.unit_id in [&"EFTnkMec", &"FWFigFod"] and not _healing_available(unit, before) and _healing_available(unit, after):
			return true
		if unit.unit_id == &"WSupAni" and not before.has(unit.slot - 1) and after.has(unit.slot - 1):
			return true
		if unit.unit_id in [&"ASpeFod", &"FFWASupMec"] and not before.has(unit.slot + 1) and after.has(unit.slot + 1):
			return true
		if unit.unit_id == &"FWWATnkFod":
			for neighbor: int in [unit.slot - 1, unit.slot + 1]:
				if not before.has(neighbor) and after.has(neighbor) and after[neighbor].unit_id == &"EWFigCos":
					return true
		if unit.unit_id == &"EFFASupMec":
			for slot: int in after:
				if not before.has(slot) and after[slot].unit_id in [&"EASupToy", &"EFAASupToy"]:
					return true
	return false

func _valid_board(board: Dictionary[int, EncounterDraftUnit]) -> bool:
	var ids: Dictionary = _id_board(board)
	for unit: EncounterDraftUnit in board.values():
		if unit.reserved:
			continue
		if not EncounterSynergyRegistry.is_valid_slot_for_unit(unit.unit_id, unit.slot, ids):
			return false
		if unit.unit_id == &"EEFWSupPla" and not board.has(unit.slot - 1):
			return false
		if unit.unit_id == &"WSupAni":
			if not board.has(unit.slot - 1):
				return false
			var front: EncounterDraftUnit = board[unit.slot - 1]
			var hp: int = front.definition().base_hp + front.level - 1 + front.bonus_hp
			for item_id: StringName in front.items:
				var item: GachaBallDefinition = Database.get_definition(item_id) as GachaBallDefinition
				hp += item.bonus_hp
			if front.snapshot_hp >= 0:
				hp = front.snapshot_hp
			if hp <= 1:
				return false
	return true

func _fill(board: Dictionary[int, EncounterDraftUnit], budget: int, rng: SeededRNG, reinforcement: bool) -> void:
	while board.size() < MAX_UNITS and _cost(board) < budget:
		var candidates: Array[Plan] = []
		var repairs: Array[Plan] = []
		var dependency_repairs: Array[Plan] = []
		# Complete packages and partial repairs share exactly the same emblem/item rules.
		for package: Dictionary in profile.packages():
			for start: int in package["valid_start_slots"]:
				var candidate: Plan = _package_plan(package, start, board, false)
				if candidate != null and candidate.cost() <= budget and _valid_board(candidate.units) and _native_anchor(candidate.units):
					candidates.append(candidate)
			for start: int in package["valid_start_slots"]:
				var repaired: Plan = _package_plan(package, start, board, true)
				if repaired != null and repaired.cost() <= budget and _valid_board(repaired.units):
					if reinforcement:
						if _restores_dependency(board, repaired.units):
							dependency_repairs.append(repaired)
						else:
							repairs.append(repaired)
					else:
						candidates.append(repaired) # Chain another approved package onto the core.
		if not dependency_repairs.is_empty():
			candidates = dependency_repairs
		elif not repairs.is_empty():
			candidates = repairs
		else:
			for unit_id: StringName in profile.filler_ids():
				for slot: int in range(MAX_UNITS):
					if board.has(slot):
						continue
					var candidate := Plan.new()
					candidate.units = _copy_board(board)
					candidate.units[slot] = EncounterDraftUnit.new(unit_id, slot)
					if not _ensure_healing(candidate.units) or candidate.cost() > budget or not _valid_board(candidate.units):
						continue
					candidate.weight = EncounterSynergyRegistry.score_unit_in_slot(unit_id, slot, _id_board(board), [profile.crest()])
					candidates.append(candidate)
		if candidates.is_empty():
			break
		var selected: Plan = _pick(candidates, rng)
		board.assign(selected.units)

func _spend_upgrades(board: Dictionary[int, EncounterDraftUnit], budget: int, trinkets: Array[StringName], rng: SeededRNG) -> void:
	var remaining: int = budget - _cost(board)
	while remaining >= 5 and trinkets.size() < MAX_TRINKETS:
		var equipped: Array[EncounterDraftUnit] = []
		equipped.assign(board.values())
		var trinket: StringName = EncounterSynergyRegistry.select_best_voted_trinket(_id_board(board), trinkets, rng, equipped)
		if trinket == &"":
			break
		trinkets.append(trinket)
		remaining -= 5
	while remaining > 0:
		var upgrades: Array[Dictionary] = []
		for slot: int in range(MAX_UNITS):
			if not board.has(slot) or board[slot].reserved:
				continue
			var unit: EncounterDraftUnit = board[slot]
			if unit.level < 3:
				var cost: int = EncounterSynergyRegistry.get_unit_cost(unit.unit_id) * (1 << (unit.level - 1))
				if cost <= remaining:
					upgrades.append({"slot": slot, "cost": cost, "item": &""})
			if unit.items.is_empty():
				var preferences: Array = EncounterSynergyRegistry.UNIT_PROFILES[unit.unit_id]["items"]
				for item_id: StringName in preferences:
					var item: GachaBallDefinition = Database.get_definition(item_id) as GachaBallDefinition
					assert(item != null, "Unknown upgrade item %s" % item_id)
					if item.is_player_exclusive or String(item_id).begins_with("item_emblem_"):
						continue
					if item.cost <= remaining:
						upgrades.append({"slot": slot, "cost": item.cost, "item": item_id})
		if upgrades.is_empty():
			break
		var upgrade: Dictionary = upgrades[rng.randi_range(0, upgrades.size() - 1)]
		var target: EncounterDraftUnit = board[int(upgrade["slot"])]
		if upgrade["item"] == &"":
			target.level += 1
		else:
			target.items.append(upgrade["item"])
		remaining -= int(upgrade["cost"])
	_overflow(board, remaining)

func draft_reinforcements(daily_budget: int, current_board: Dictionary, empty_slots: Array[int], active_trinkets: Array[StringName], rng: SeededRNG) -> Array[Dictionary]:
	assert(current_board.is_empty(), "Trait reinforcement drafting requires the equipped board snapshot")
	var empty: Array[EncounterDraftUnit] = []
	return draft_reinforcements_from_snapshot(daily_budget, empty, empty_slots, active_trinkets, rng)

func draft_reinforcements_from_snapshot(daily_budget: int, survivors: Array[EncounterDraftUnit], empty_slots: Array[int], _active_trinkets: Array[StringName], rng: SeededRNG) -> Array[Dictionary]:
	var board: Dictionary[int, EncounterDraftUnit] = {}
	for survivor: EncounterDraftUnit in survivors:
		var unit: EncounterDraftUnit = survivor.copy()
		unit.reserved = true
		board[unit.slot] = unit
	for slot: int in range(MAX_UNITS):
		assert(board.has(slot) != empty_slots.has(slot), "Reinforcement snapshot disagrees at slot %d" % slot)
	var budget: int = maxi(1, int(floor(daily_budget * profile.wave_fraction)))
	_fill(board, budget, rng, true)
	_overflow(board, budget - _cost(board))
	var result: Array[Dictionary] = []
	for slot: int in range(MAX_UNITS):
		if board.has(slot) and not board[slot].reserved:
			result.append(board[slot].summon())
	return result

func _overflow(board: Dictionary[int, EncounterDraftUnit], gold: int) -> void:
	assert(gold >= 0, "Trait banner overspent its budget")
	var eligible: Array[EncounterDraftUnit] = []
	for slot: int in range(MAX_UNITS):
		if board.has(slot) and not board[slot].reserved:
			eligible.append(board[slot])
	if eligible.is_empty():
		return
	var hp_per_unit: int = (gold * 2) / eligible.size()
	var pwr_per_unit: int = gold / eligible.size()
	for index: int in range(eligible.size()):
		eligible[index].bonus_hp += hp_per_unit + (1 if index < (gold * 2) % eligible.size() else 0)
		eligible[index].bonus_pwr += pwr_per_unit + (1 if index < gold % eligible.size() else 0)

func _pick(candidates: Array[Plan], rng: SeededRNG) -> Plan:
	assert(not candidates.is_empty(), "Cannot pick from empty trait_name banner plans")
	var total: float = 0.0
	for candidate: Plan in candidates:
		total += candidate.weight
	var roll: float = rng.randf() * total
	for candidate: Plan in candidates:
		roll -= candidate.weight
		if roll < 0.0:
			return candidate
	return candidates.back()

func _trait_count(board: Dictionary[int, EncounterDraftUnit]) -> int:
	var total: int = 0
	for unit: EncounterDraftUnit in board.values():
		total += unit.trait_count(profile.trait_name)
	return total

func _native_anchor(board: Dictionary[int, EncounterDraftUnit]) -> bool:
	for unit: EncounterDraftUnit in board.values():
		if profile.native_unit(unit.unit_id):
			return true
	return false

func _cost(board: Dictionary[int, EncounterDraftUnit]) -> int:
	var total: int = 0
	for unit: EncounterDraftUnit in board.values():
		total += unit.gold_cost()
	return total

func _copy_board(board: Dictionary[int, EncounterDraftUnit]) -> Dictionary[int, EncounterDraftUnit]:
	var result: Dictionary[int, EncounterDraftUnit] = {}
	for slot: int in range(MAX_UNITS):
		if board.has(slot):
			result[slot] = board[slot].copy()
	return result

func _id_board(board: Dictionary[int, EncounterDraftUnit]) -> Dictionary:
	var result: Dictionary = {}
	for slot: int in range(MAX_UNITS):
		if board.has(slot):
			result[slot] = board[slot].unit_id
	return result

func _board_key(board: Dictionary[int, EncounterDraftUnit]) -> String:
	var parts: PackedStringArray = []
	for slot: int in range(MAX_UNITS):
		if board.has(slot):
			parts.append("%d:%s:%s" % [slot, board[slot].unit_id, str(board[slot].items)])
	return "|".join(parts)
