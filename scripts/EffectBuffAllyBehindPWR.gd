# res://scripts/EffectBuffAllyBehindPWR.gd
@tool
extends EffectDefinition

## Grants +1 PWR to the target (ally behind the source unit).
## Used by the Empath unit's Empathic Link ability.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var target_uuid: String = targets[0]
	var target = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target):
		return EffectResult.empty() if is_simulation else null
	
	var buff_amount: int = 1
	
	if is_simulation:
		var old_pwr: int = target.current_pwr
		target.current_pwr += buff_amount
		var new_pwr: int = target.current_pwr
		
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [target_uuid],
			"ability_id": context.get("ability_id", &"empathic_link"),
			"ability_holder_uuid": source_uuid,
			"visual_payload": {
				"source_uuid": source_uuid,
				"stat": "pwr",
				"amount": buff_amount,
				"targets_old_pwr": [old_pwr],
				"targets_new_pwr": [new_pwr]
			}
		}))
		return result
	
	return null
