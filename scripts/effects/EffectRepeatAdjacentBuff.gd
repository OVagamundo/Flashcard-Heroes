# res://scripts/effects/EffectRepeatAdjacentBuff.gd
@tool
extends EffectDefinition
class_name EffectRepeatAdjacentBuff

## Repeats the buff (HP or PWR) that triggered this effect on the target unit.
## This acts as an "echo" of the original buff.
## The source of THIS new buff is the unit owning this effect (e.g., Unit G).

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Extract the original buff details from context
	var stat = context.get("stat")
	var amount = context.get("amount", 0)
	
	if stat == null or amount <= 0:
		return EffectResult.empty() if is_simulation else null
		
	# Validate targets
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null

	if is_simulation:
		var result := EffectResult.new()
		var valid_targets: Array[String] = []
		
		# For visuals
		var all_target_uuids: Array[String] = []
		var all_old_vals: Array[int] = []
		var all_new_vals: Array[int] = []
		var all_max_hp: Array[int] = []
		
		var source_name = ""
		var src_inst = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(src_inst):
			source_name = BattleHelpers.get_instance_display_name(src_inst)
		
		for target_uuid in targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt) or tgt.current_hp <= 0:
				continue
				
			valid_targets.append(target_uuid)
			var old_val: int = tgt.current_hp if stat == "hp" else tgt.current_pwr
			var max_hp = 0
			var def = tgt.get_definition()
			if is_instance_valid(def): max_hp = def.base_hp
			
			# Apply the echo buff
			# Pass source_uuid to prevent infinite loops (though AbilityResolver should filter it too)
			var new_val = battle_manager.apply_stat_delta(tgt, stat, amount, false, source_uuid)
			
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
			all_max_hp.append(max_hp)
			
			if stat == "hp":
				result.mark_healed(target_uuid, amount)

		if valid_targets.is_empty():
			return EffectResult.empty()
			
		# Visuals
		var stat_str = "HP" if stat == "hp" else "PWR"
		var log_text = "%s echoes buff! Grants +%d %s to adjacent ally." % [source_name, amount, stat_str]
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

		if stat == "hp":
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": "unit_t2_g_buff_echo",
				"trigger_type": "on_stat_increased",
				"ability_holder_uuid": source_uuid,
				"visual_payload": {
					"source_uuid": source_uuid,
					"amount": amount,
					"stat": "hp",
					"targets_old_hp": all_old_vals,
					"targets_new_hp": all_new_vals,
					"targets_max_hp": all_max_hp
				}
			}))
		elif stat == "pwr":
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": "unit_t2_g_buff_echo",
				"trigger_type": "on_stat_increased",
				"ability_holder_uuid": source_uuid,
				"visual_payload": {
					"source_uuid": source_uuid,
					"amount": amount,
					"stat": "pwr",
					"targets_old_pwr": all_old_vals,
					"targets_new_pwr": all_new_vals
				}
			}))
			
		result.state_applied = true
		return result
	else:
		# Non-simulation
		for target_uuid in targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				battle_manager.apply_stat_delta(tgt, stat, amount, false, source_uuid)
		return null
