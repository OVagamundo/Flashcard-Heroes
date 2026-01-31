# res://scripts/EffectGrantPWRAsHP.gd
@tool
extends EffectDefinition

## Grants the source unit's current PWR as HP to the target.
## Used by protection abilities that heal based on the protector's strength.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty() if is_simulation else null
	
	var heal_amount: int = source.current_pwr
	if heal_amount <= 0:
		return EffectResult.empty() if is_simulation else null
	
	# Simulation mode: create heal events
	if is_simulation:
		var result := EffectResult.new()
		var all_target_uuids: Array[String] = []
		var all_old_vals: Array[int] = []
		var all_new_vals: Array[int] = []
		var all_max_hp: Array[int] = []
		var target_names: Array[String] = []
		
		var source_name = BattleHelpers.get_instance_display_name(source)
		
		for target_uuid in targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt) or tgt.current_hp <= 0:
				continue
			
			var old_hp: int = tgt.current_hp
			var tgt_def = tgt.get_definition()
			var max_hp: int = tgt_def.base_hp if is_instance_valid(tgt_def) else 0
			
			var new_hp = battle_manager.apply_stat_delta(tgt, "hp", heal_amount)
			
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_hp)
			all_new_vals.append(new_hp)
			all_max_hp.append(max_hp)
			target_names.append(BattleHelpers.get_instance_display_name(tgt))
			result.mark_healed(target_uuid)
		
		if not all_target_uuids.is_empty():
			var log_text = "%s grants %s +%d HP" % [source_name, " and ".join(target_names), heal_amount]
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": context.get("ability_id", &"grant_pwr_as_hp"),
				"trigger_type": context.get("trigger_type", ""),
				"visual_payload": {
					"source_uuid": source_uuid,
					"amount": heal_amount,
					"stat": "hp",
					"skip_bump": false,
					"targets_old_hp": all_old_vals,
					"targets_new_hp": all_new_vals,
					"targets_max_hp": all_max_hp
				}
			}))
		
		result.state_applied = true
		return result
	else:
		# Non-simulation: apply stat changes immediately (legacy path)
		for target_uuid in targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt) or tgt.current_hp <= 0:
				continue
			var new_hp = max(0, tgt.current_hp + heal_amount)
			tgt.set_current_hp(new_hp)
		return heal_amount
