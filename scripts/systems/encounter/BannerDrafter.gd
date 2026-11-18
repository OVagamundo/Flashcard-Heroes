# res://scripts/systems/encounter/BannerDrafter.gd
class_name BannerDrafter
extends RefCounted

const C = preload("res://scripts/Constants.gd")
const MAX_UNITS: int = 5
const MAX_TRINKETS: int = C.ENEMY_TRINKET_CAP

## Standard Mapping of Traits to their corresponding Crests, Emblems, and Tags
const TRAIT_MAP: Dictionary = {
	&"Tank": {"crest": &"trinket_trait_tank", "emblem": &"item_emblem_tank", "tags": [&"Tank"]},
	&"Fighter": {"crest": &"trinket_trait_fighter", "emblem": &"item_emblem_fighter", "tags": [&"Fighter"]},
	&"Support": {"crest": &"trinket_trait_support", "emblem": &"item_emblem_support", "tags": [&"Support"]},
	&"Specialist": {"crest": &"trinket_trait_specialist", "emblem": &"item_emblem_specialist", "tags": [&"Specialist"]},
	&"Earth": {"crest": &"trinket_trait_earth", "emblem": &"item_emblem_earth", "tags": [&"Earth", &"SOUL_EARTH"]},
	&"Fire": {"crest": &"trinket_trait_fire", "emblem": &"item_emblem_fire", "tags": [&"Fire", &"SOUL_FIRE"]},
	&"Water": {"crest": &"trinket_trait_water", "emblem": &"item_emblem_water", "tags": [&"Water", &"SOUL_WATER"]},
	&"Air": {"crest": &"trinket_trait_air", "emblem": &"item_emblem_air", "tags": [&"Air", &"SOUL_AIR"]},
	&"Mecha": {"crest": &"trinket_trait_mecha", "emblem": &"item_emblem_mecha", "tags": [&"Mecha"]},
	&"Plant": {"crest": &"trinket_trait_plant", "emblem": &"item_emblem_plant", "tags": [&"Plant"]},
	&"Animal": {"crest": &"trinket_trait_animal", "emblem": &"item_emblem_animal", "tags": [&"Animal"]},
	&"Toy": {"crest": &"trinket_trait_toy", "emblem": &"item_emblem_toy", "tags": [&"Toy"]},
	&"Costume": {"crest": &"trinket_trait_costume", "emblem": &"item_emblem_costume", "tags": [&"Costume"]},
	&"Food": {"crest": &"trinket_trait_food", "emblem": &"item_emblem_food", "tags": [&"Food"]},
	&"Appliance": {"crest": &"trinket_trait_appliance", "emblem": &"item_emblem_appliance", "tags": [&"Appliance"]},
}

## Virtual method: Subclasses must implement to draft the initial lineup.
func draft_lineup(_budget: int, _context: Dictionary = {}) -> EncounterDefinition:
	assert(false, "BannerDrafter.draft_lineup: Subclass must override draft_lineup!")
	return null

## Virtual method: Subclasses implement mid-combat reinforcement drafting.
func draft_reinforcements(
	_daily_budget: int,
	_current_board: Dictionary,
	_empty_slots: Array[int],
	_active_trinkets: Array[StringName],
	_rng: SeededRNG
) -> Array[Dictionary]:
	return []

## Composite banners can delegate waves without special cases in the generator.
func reinforcement_strategy() -> BannerDrafter:
	return self

# =============================================================================
# SHARED UTILITY METHODS
# =============================================================================

static func unit_has_trait(unit_id: StringName, trait_name: StringName) -> bool:
	var def: GachaBallDefinition = Database.get_definition(unit_id) as GachaBallDefinition
	assert(def != null, "BannerDrafter: unknown unit %s" % unit_id)
	assert(TRAIT_MAP.has(trait_name), "BannerDrafter: unknown trait %s" % trait_name)
	var match_tags: Array = TRAIT_MAP[trait_name]["tags"]
	for t in match_tags:
		if def.tags.has(t):
			return true
	return false

static func get_trait_emblem(trait_name: StringName) -> StringName:
	var info: Dictionary = TRAIT_MAP.get(trait_name, {})
	return info.get("emblem", &"")

static func get_trait_crest(trait_name: StringName) -> StringName:
	var info: Dictionary = TRAIT_MAP.get(trait_name, {})
	return info.get("crest", &"")

func _get_item_cost(item_id: StringName) -> int:
	if item_id.begins_with("item_emblem_"):
		return 0 # Emblems equipped for synergy are free
	var def = Database.get_definition(item_id)
	if is_instance_valid(def):
		match int(def.tier):
			1: return 1
			2: return 2
			3: return 4
			_: return 1
	return 1

func _get_item_tier(item_id: StringName) -> int:
	var def = Database.get_definition(item_id)
	if is_instance_valid(def):
		return int(def.tier)
	return 1

## Distributes leftover budget evenly across units at +2 HP and +1 PWR per 1 Gold.
func _distribute_stat_overflow(placements: Dictionary, remaining_budget: int, reserved_slots: Array[int] = []) -> void:
	if remaining_budget <= 0:
		return
	var eligible_slots: Array[int] = []
	for s in placements.keys():
		if not reserved_slots.has(s):
			eligible_slots.append(s)

	if eligible_slots.is_empty():
		for s in placements.keys():
			eligible_slots.append(s)

	if eligible_slots.is_empty():
		return

	var overflow_hp: int = remaining_budget * 2
	var overflow_pwr: int = remaining_budget * 1
	var num_units: int = eligible_slots.size()

	var hp_per_unit: int = overflow_hp / num_units
	var hp_rem: int = overflow_hp % num_units
	var pwr_per_unit: int = overflow_pwr / num_units
	var pwr_rem: int = overflow_pwr % num_units

	for i in range(num_units):
		var s: int = eligible_slots[i]
		placements[s]["bonus_hp"] = int(placements[s].get("bonus_hp", 0)) + hp_per_unit + (1 if i < hp_rem else 0)
		placements[s]["bonus_pwr"] = int(placements[s].get("bonus_pwr", 0)) + pwr_per_unit + (1 if i < pwr_rem else 0)
