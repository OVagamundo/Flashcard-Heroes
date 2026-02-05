# res://scripts/EffectApplyStatus.gd
@tool
extends EffectDefinition

## Applies a status effect (stackable) to the target(s).
## Parameters:
## - status_id: StringName - The ID of the status effect (e.g., "burn", "armor", "spikes").
## - amount: int - The number of stacks to apply.

func execute(_source_uuid: String, targets: Array[String], _battle_manager: Node, _context: Dictionary) -> Variant:
	var result := EffectResult.new()
	
	var status_id_str = parameters.get("status_id", "")
	var amount = int(parameters.get("amount", 0))
	
	if status_id_str == "" or amount <= 0:
		return result
		
	var status_id = StringName(status_id_str)
	var stat_name = status_id_str + "_stacks"
	
	for target_uuid in targets:
		# 1. LOGIC: Actually apply the status effect
		var target_inst = _battle_manager.get_instance_by_uuid(target_uuid)
		var old_val = 0
		var new_val = 0
		
		if is_instance_valid(target_inst):
			old_val = target_inst.get_status_effect_amount(status_id)
			# Use BattleManager's centralized API
			new_val = _battle_manager.apply_stat_delta(target_inst, stat_name, amount)
		
		# 2. VISUALS: Create correct combat event
		result.add_event(CombatEvent.new(
			CombatEvent.Type.STATUS_EFFECT,
			{
				"target_uuids": [target_uuid],
				"visual_payload": {
					"source_uuid": _source_uuid,
					"amount": amount,
					"stat": stat_name,
					"targets_old_val": [old_val],
					"targets_new_val": [new_val],
					# Default colors (can be enhanced via StatusEffectRegistry later if needed)
					"status_color": Color.WHITE
				}
			}
		))
	
	return result
