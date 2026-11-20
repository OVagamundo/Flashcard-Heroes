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

	var aura_key: StringName = AuraEvaluator.make_key(&"golden_seal", source_uuid)
	var result := EffectResult.new()
	var holder_updated: bool = false

	for instance_uuid: String in all_instances:
		var instance: GachaBallInstance = all_instances[instance_uuid]
		if not is_instance_valid(instance) or instance_uuid == source_uuid:
			continue

		var is_holder: bool = (instance_uuid == active_holder_uuid and not active_holder_uuid.is_empty())
		var desired_bonus: int = target_bonus if is_holder else 0
		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			instance, aura_key, desired_bonus, desired_bonus,
			source_uuid, AuraEvaluator.KIND_GOLDEN_SEAL,
			{"silent": true, "emit_stat_triggers": true},
			battle_manager
		)
		if not rec_res.changed:
			continue

		holder_updated = true
		var ability_id: StringName = (context.ability_id if context.ability_id != &"" else &"golden_seal_scaling")
		var holder_name: String = BattleHelpers.get_instance_display_name(instance)
		var visual_source: String = active_holder_uuid if is_holder else instance_uuid
		if is_holder:
			var gold_held: int = GameManager.run_state.gold if is_instance_valid(GameManager.run_state) else 0
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Golden Seal adjusts %s: %+d HP / %+d PWR (%d Gold held)" % [holder_name, rec_res.delta_hp, rec_res.delta_pwr, gold_held]
			}))
		else:
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Golden Seal unequipped from %s: %+d HP / %+d PWR" % [holder_name, rec_res.delta_hp, rec_res.delta_pwr]
			}))
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": visual_source,
			"target_uuids": [instance_uuid],
			"ability_id": ability_id,
			"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
			"ability_holder_uuid": source_uuid,
			"visual_payload": CombatPayload.both_stats_change(
				visual_source, rec_res.delta_hp, rec_res.delta_pwr,
				[rec_res.old_hp], [rec_res.new_hp],
				[rec_res.old_pwr], [rec_res.new_pwr]
			)
		}))

	if not holder_updated:
		return EffectResult.empty()

	result.state_applied = true
	return result
