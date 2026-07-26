# res://scripts/EffectApplyStatus.gd
@tool
extends EffectDefinition

## Applies a status effect (stackable) to the target(s).
## Parameters:
## - status_id: StringName - The ID of the status effect (e.g., "burn", "armor", "spikes").
## - amount: int - The number of stacks to apply.

func execute(_source_uuid: String, targets: Array[String], _battle_manager: Node, _context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	var status_id_str = parameters.get("status_id", "")
	var raw_amount = parameters.get("amount")
	var amount = StatScaling.calculate(raw_amount, _context, "EffectApplyStatus")
	
	if status_id_str == "" or amount <= 0:
		return result
		
	var status_id = StringName(status_id_str)
	var stat_name = status_id_str + "_stacks"
	
	var all_target_uuids: Array[String] = []
	var all_old_vals: Array = []
	var all_new_vals: Array = []
	
	for target_uuid in targets:
		# 1. LOGIC: Actually apply the status effect
		var target_inst = _battle_manager.get_instance_by_uuid(target_uuid)
		var old_val = 0
		var new_val = 0
		
		if is_instance_valid(target_inst):
			old_val = target_inst.get_status_effect_amount(status_id)
			# Use BattleManager's centralized API
			new_val = _battle_manager.apply_stat_delta(target_inst, stat_name, amount)
			
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
		
	# 2. VISUALS: Create single consolidated combat event for all targets
	if not all_target_uuids.is_empty():
		var status_payload := CombatPayload.status_change(_source_uuid, amount, stat_name, all_old_vals, all_new_vals)
		status_payload.new_val = all_new_vals[0] if not all_new_vals.is_empty() else 0
		result.add_event(CombatEvent.new(
			CombatEvent.Type.STATUS_EFFECT,
			{
				"source_uuid": _source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": _context.get("ability_id", &"apply_status"),
				"trigger_type": _context.get("trigger_type", ""),
				"visual_payload": status_payload
			}
		))
	
	return result
