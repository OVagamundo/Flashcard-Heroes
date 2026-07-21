# res://scripts/EffectBuffAllyBehindPWR.gd
@tool
extends EffectDefinition

## Grants +1 PWR to the target (ally behind the source unit).
## Used by the Windy unit's Empathic Link ability.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var target_uuid: String = targets[0]
	var target = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target):
		return EffectResult.empty() if is_simulation else null
	
	# ROBUSTNESS: Use snapshotted source PWR from context if available (captured at moment of death)
	# Fallback to current PWR if context is missing (though AbilityResolver should provide it)
	var buff_amount: int = context.get("source_pwr", 1)
	
	if is_simulation:
		var old_pwr: int = target.current_pwr
		# CENTRALIZED STAT MANAGEMENT: Use apply_stat_delta to ensure triggers propagate correctly
		var new_pwr: int = battle_manager.apply_stat_delta(target, "pwr", buff_amount)
		
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [target_uuid],
			"ability_id": context.get("ability_id", &"empathic_link"),
			"ability_holder_uuid": source_uuid,
			"visual_payload": CombatPayload.pwr_change(source_uuid, buff_amount, [old_pwr], [new_pwr])
		}))
		return result
	
	return null
