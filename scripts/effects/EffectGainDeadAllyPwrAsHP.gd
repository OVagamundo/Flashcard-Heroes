@tool
class_name EffectGainDeadAllyPwrAsHP
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Effect: Gains HP equal to the dead ally's current combat PWR (min 1).
## Triggers on_ally_death for the Starter Hero.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var fainting_uuid: String = context.ally_knocked_out_uuid
	if fainting_uuid.is_empty() or fainting_uuid == source_uuid:
		return EffectResult.empty()
		
	# Get source unit (the hero)
	var source_unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit) or source_unit.current_hp <= 0:
		return EffectResult.empty()
		
	var dead_ally: GachaBallInstance = battle_manager.get_instance_by_uuid(fainting_uuid)
	if not is_instance_valid(dead_ally):
		return EffectResult.empty()
		
	# Query the dying unit's dynamic combat Power at the moment of death
	var current_pwr: int = dead_ally.current_pwr
	if context.ally_knocked_out_pwr >= 0:
		current_pwr = context.ally_knocked_out_pwr
		
	# Formula: max(1, current_pwr) (100% of dead ally PWR)
	var amount: int = maxi(1, current_pwr)
	
	var old_hp: int = source_unit.current_hp
	var res = battle_manager.apply_stat_delta(source_unit, "hp", amount, source_uuid, C.ACTION_BUFF, true, &"", &"", {}, C.BUFF_SUBGROUP_DISCRETE)
	var new_hp: int = old_hp + amount
	if res is int:
		new_hp = res
	elif res is Dictionary:
		new_hp = res.get("new_hp", new_hp)
		
	var result := EffectResult.new()
	var ability_id: StringName = (context.ability_id if context.ability_id != &"" else &"hero_starter_ally_death_absorb")
	
	var hero_name = BattleHelpers.get_instance_display_name(source_unit)
	var dead_name = BattleHelpers.get_instance_display_name(dead_ally)
	var log_text = "%s harvests %s's soul (+%d HP)" % [hero_name, dead_name, amount]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.trigger_type if context.trigger_type != &"" else C.TRIGGER_WHEN_ALLY_KNOCKED_OUT,
		"action_type": C.ACTION_BUFF,
		"buff_subgroup": C.BUFF_SUBGROUP_DISCRETE,
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.hp_buff(source_uuid, amount, [old_hp], [new_hp])
	}))
	
	result.state_applied = true
	return result
