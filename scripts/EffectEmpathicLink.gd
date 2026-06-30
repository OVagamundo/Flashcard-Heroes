# res://scripts/EffectEmpathicLink.gd
@tool
extends EffectDefinition

## Cascading buff that travels down the lineup based on depth.
## Gives PWR to the unit behind it, then halves it for the next, and so on.
## Minimum PWR given is 1.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var depth: int = parameters.get("depth", 1)
	
	# ROBUSTNESS: Use snapshotted source PWR from context if available (captured at moment of death)
	var current_buff: float = float(context.get("source_pwr", 1))
	
	var result := EffectResult.new() if is_simulation else null
	var current_target_uuid: String = targets[0]
	var current_target = battle_manager.get_instance_by_uuid(current_target_uuid)
	
	for i in range(depth):
		if not is_instance_valid(current_target):
			break
			
		var apply_buff: int = int(floor(current_buff))
		if apply_buff < 1:
			apply_buff = 1
			
		if is_simulation:
			var old_pwr: int = current_target.current_pwr
			# CENTRALIZED STAT MANAGEMENT: Use apply_stat_delta to ensure triggers propagate correctly
			var new_pwr: int = battle_manager.apply_stat_delta(current_target, "pwr", apply_buff, false, source_uuid)
			
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [current_target.ball_uuid],
				"ability_id": context.get("ability_id", &"empathic_link"),
				"ability_holder_uuid": source_uuid,
				"visual_payload": {
					"source_uuid": source_uuid,
					"stat": "pwr",
					"amount": apply_buff,
					"targets_old_pwr": [old_pwr],
					"targets_new_pwr": [new_pwr]
				}
			}))
			
		current_target = battle_manager._get_ally_behind(current_target)
		current_buff /= 2.0
		
	return result if is_simulation else null
