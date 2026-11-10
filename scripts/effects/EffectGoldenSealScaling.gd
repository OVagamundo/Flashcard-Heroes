# res://scripts/effects/EffectGoldenSealScaling.gd
@tool
class_name EffectGoldenSealScaling
extends EffectDefinition

## Dynamically scales the holder's HP and PWR by +1 per full 10 Gold currently held.
## Recalculates whenever Gold is earned/spent, at pre-combat, or when board state updates.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	if not is_simulation:
		return EffectResult.empty()

	var all_instances: Dictionary = battle_manager.get_all_instances()
	var item: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(item):
		return EffectResult.empty()

	var active_holder_uuid: String = item.equipped_on_uuid
	var target_bonus: int = 0
	if not active_holder_uuid.is_empty():
		assert(all_instances.has(active_holder_uuid), "EffectGoldenSealScaling: source holder is not registered")
		var active_holder: GachaBallInstance = all_instances[active_holder_uuid]
		if active_holder.current_hp > 0:
			var gold: int = 0
			if is_instance_valid(GameManager.run_state):
				gold = GameManager.run_state.gold
			target_bonus = int(gold / 10)

	var status_key: StringName = StringName("golden_seal_scaling_" + source_uuid)
	var result := EffectResult.new()
	var holder_updated: bool = false

	for instance_uuid: String in all_instances:
		var instance: GachaBallInstance = all_instances[instance_uuid]
		if not is_instance_valid(instance) or instance_uuid == source_uuid:
			continue

		var previous_bonus: int = instance.get_status_effect_amount(status_key)
		if instance_uuid == active_holder_uuid and not active_holder_uuid.is_empty():
			var delta: int = target_bonus - previous_bonus
			if delta == 0:
				continue
			if previous_bonus > 0:
				instance.clear_status_effect(status_key)
			if target_bonus > 0:
				instance.add_status_effect_silent(status_key, target_bonus)

			var old_hp: int = instance.current_hp
			var old_pwr: int = instance.current_pwr
			var action_type: StringName = C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF

			var new_hp = battle_manager.apply_stat_delta(instance, "hp", delta, source_uuid, action_type, false, &"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL)
			var new_pwr = battle_manager.apply_stat_delta(instance, "pwr", delta, source_uuid, action_type, false, &"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL)

			holder_updated = true
			var ability_id: StringName = (context.ability_id if context.ability_id != &"" else &"golden_seal_scaling")
			var holder_name: String = BattleHelpers.get_instance_display_name(instance)
			var gold_held: int = GameManager.run_state.gold if is_instance_valid(GameManager.run_state) else 0

			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Golden Seal adjusts %s: %+d HP / %+d PWR (%d Gold held)" % [holder_name, delta, delta, gold_held]
			}))
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": active_holder_uuid,
				"target_uuids": [instance_uuid],
				"ability_id": ability_id,
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.both_stats_change(
					active_holder_uuid, delta, delta,
					[old_hp], [new_hp],
					[old_pwr], [new_pwr]
				)
			}))
		elif previous_bonus > 0:
			# Unequipped or moved from this previous holder: remove previously applied scaling
			instance.clear_status_effect(status_key)
			var old_hp: int = instance.current_hp
			var old_pwr: int = instance.current_pwr
			var new_hp = battle_manager.apply_stat_delta(instance, "hp", -previous_bonus, source_uuid, C.ACTION_DEBUFF, false, &"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL)
			var new_pwr = battle_manager.apply_stat_delta(instance, "pwr", -previous_bonus, source_uuid, C.ACTION_DEBUFF, false, &"", &"", {}, C.BUFF_SUBGROUP_CONDITIONAL)

			holder_updated = true
			var holder_name: String = BattleHelpers.get_instance_display_name(instance)
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Golden Seal unequipped from %s: -%d HP / -%d PWR" % [holder_name, previous_bonus, previous_bonus]
			}))
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": instance_uuid,
				"target_uuids": [instance_uuid],
				"ability_id": &"golden_seal_scaling",
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.both_stats_change(
					instance_uuid, -previous_bonus, -previous_bonus,
					[old_hp], [new_hp],
					[old_pwr], [new_pwr]
				)
			}))

	if not holder_updated:
		return EffectResult.empty()

	result.state_applied = true
	return result
