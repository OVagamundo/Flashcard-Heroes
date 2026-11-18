# res://scripts/effects/EffectDustmonSporeInjection.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	# A machine T in {1, 2, 3} is eligible iff inventory has empty slot AND has at least 1 gachaball
	var eligible_tiers: Array[int] = []
	for tier in [1, 2, 3]:
		var inv_tag: StringName = StringName("BattleInventoryT%d" % tier)
		var inv = battle_manager.get_container(inv_tag)
		if is_instance_valid(inv):
			if inv.find_first_empty_slot() != -1 and inv.get_all_non_empty_uuids().size() >= 1:
				eligible_tiers.append(tier)

	if eligible_tiers.is_empty():
		for tier in [1, 2, 3]:
			var inv_tag: StringName = StringName("BattleInventoryT%d" % tier)
			var inv = battle_manager.get_container(inv_tag)
			if is_instance_valid(inv) and inv.find_first_empty_slot() != -1:
				eligible_tiers.append(tier)

	if eligible_tiers.is_empty():
		return EffectResult.empty()

	var last_machine: int = source.get_status_effect_amount(&"dustmon_last_machine")
	var candidates: Array[int] = eligible_tiers.duplicate()
	if candidates.size() > 1 and candidates.has(last_machine):
		candidates.erase(last_machine)

	var chosen_tier: int = candidates[RNGManager.combat_rng.randi_range(0, candidates.size() - 1)]
	source.add_status_effect_silent(&"dustmon_last_machine", chosen_tier - last_machine)

	var chosen_inv_tag: StringName = StringName("BattleInventoryT%d" % chosen_tier)
	var chosen_inv = battle_manager.get_container(chosen_inv_tag)
	var empty_slot: int = chosen_inv.find_first_empty_slot()
	assert(empty_slot != -1, "EffectDustmonSporeInjection: empty_slot should be valid")

	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": StringName("unit_dust_t%d" % chosen_tier),
		"holder_uuid": "",
		"holder_location": LocationIdentifier.new(chosen_inv_tag, empty_slot),
		"spawn_source_uuid": source_uuid,
		"unit_tier": chosen_tier
	}
	return result
