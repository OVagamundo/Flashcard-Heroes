class_name EncounterDraftUnit
extends RefCounted

## Value object used by drafting only. Never mutates a shared resource or live unit.
var unit_id: StringName
var slot: int
var level: int = 1
var items: Array[StringName] = []
var bonus_hp: int = 0
var bonus_pwr: int = 0
var reserved: bool = false
var snapshot_tags: Array[StringName] = []
var snapshot_hp: int = -1

func _init(id: StringName = &"", position: int = -1) -> void:
	unit_id = id
	slot = position

static func from_live(unit: GachaBallInstance, all_instances: Dictionary) -> EncounterDraftUnit:
	var result := EncounterDraftUnit.new(unit.definition_id, unit.location_slot_index)
	result.level = unit.level
	result.snapshot_hp = unit.current_hp
	result.snapshot_tags = unit.get_active_tags(all_instances)
	# Membership tags are unique; elemental counts must preserve every individual soul.
	var souls: Dictionary = unit.get_trait_soul_counts(all_instances)
	for element: String in ["FIRE", "EARTH", "WATER", "AIR"]:
		var tag := StringName("SOUL_" + element)
		result.snapshot_tags.erase(tag)
		for index: int in range(int(souls[element])):
			result.snapshot_tags.append(tag)
	for item_uuid: String in unit.equipped_item_uuids:
		if item_uuid.is_empty():
			continue
		var item: GachaBallInstance = all_instances[item_uuid]
		assert(item != null, "Missing equipped drafting snapshot item %s" % item_uuid)
		result.items.append(item.definition_id)
	return result

func copy() -> EncounterDraftUnit:
	var result := EncounterDraftUnit.new(unit_id, slot)
	result.level = level
	result.items = items.duplicate()
	result.bonus_hp = bonus_hp
	result.bonus_pwr = bonus_pwr
	result.reserved = reserved
	result.snapshot_tags = snapshot_tags.duplicate()
	result.snapshot_hp = snapshot_hp
	return result

func definition() -> GachaBallDefinition:
	var result: GachaBallDefinition = Database.get_definition(unit_id) as GachaBallDefinition
	assert(result != null, "EncounterDraftUnit: unknown unit %s" % unit_id)
	return result

func effective_tags() -> Array[StringName]:
	if not snapshot_tags.is_empty():
		return snapshot_tags.duplicate()
	var result: Array[StringName] = definition().tags.duplicate()
	for item_id: StringName in items:
		var item: GachaBallDefinition = Database.get_definition(item_id) as GachaBallDefinition
		assert(item != null, "EncounterDraftUnit: unknown item %s" % item_id)
		result.append_array(item.tags)
	return result

func trait_count(trait_name: StringName) -> int:
	var tags: Array[StringName] = effective_tags()
	if trait_name in [&"Fire", &"Earth", &"Water", &"Air"]:
		return tags.count(StringName("SOUL_" + String(trait_name).to_upper()))
	return 1 if tags.has(trait_name) else 0

func gold_cost() -> int:
	if reserved:
		return 0
	var result: int = EncounterSynergyRegistry.get_unit_cost(unit_id) * (1 << (level - 1))
	for item_id: StringName in items:
		if String(item_id).begins_with("item_emblem_"):
			continue
		var item: GachaBallDefinition = Database.get_definition(item_id) as GachaBallDefinition
		assert(item != null and not item.is_player_exclusive, "Invalid enemy equipment %s" % item_id)
		result += item.cost
	return result

func placement() -> Dictionary:
	return {"id": unit_id, "position": slot, "level": level, "items": items.duplicate(), "bonus_hp": bonus_hp, "bonus_pwr": bonus_pwr}

func summon() -> Dictionary:
	return {"unit_id": unit_id, "slot": slot, "level": level, "items": items.duplicate(), "bonus_hp": bonus_hp, "bonus_pwr": bonus_pwr}
