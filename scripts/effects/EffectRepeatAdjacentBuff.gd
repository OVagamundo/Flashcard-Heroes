# res://scripts/effects/EffectRepeatAdjacentBuff.gd
@tool
extends EffectDefinition
class_name EffectRepeatAdjacentBuff

## Repeats the buff (HP or PWR) that triggered this effect on the target unit.
## This acts as an "echo" of the original buff.
## The source of THIS new buff is the unit owning this effect (e.g., Unit G).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Only stackable buffs are echoed (prevents infinite echoing and non-stacking stat inflation)
	if not context.get("is_stackable", true):
		return EffectResult.empty()
	
	# Extract the original buff details from context
	var stat = context.get("stat")
	var amount = context.get("amount", 0)
	
	if stat == null or amount <= 0:
		return EffectResult.empty()
		
	var multiplier = parameters.get("effectiveness", 1.0)
	amount = int(floor(amount * multiplier))
		
	# Validate targets
	if targets.is_empty():
		return EffectResult.empty()

	var src_inst = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(src_inst):
		return EffectResult.empty()

	# Filter targets to adjacent allies of the echoer
	var adjacent_allies = battle_manager._get_adjacent_allies(src_inst)
	var adjacent_uuids: Array[String] = []
	for ally in adjacent_allies:
		adjacent_uuids.append(ally.ball_uuid)

	if is_simulation:
		var result := EffectResult.new()
		var valid_targets: Array[String] = []
		
		# For visuals
		var all_target_uuids: Array[String] = []
		var all_old_vals: Array[int] = []
		var all_new_vals: Array[int] = []
		var all_max_hp: Array[int] = []
		
		var source_name = BattleHelpers.get_instance_display_name(src_inst)
		
		for target_uuid in targets:
			if target_uuid not in adjacent_uuids:
				continue

			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt) or tgt.current_hp <= 0:
				continue
				
			valid_targets.append(target_uuid)
			var old_val: int = tgt.current_hp if stat == "hp" else tgt.current_pwr
			var max_hp = 0
			var def = tgt.get_definition()
			if is_instance_valid(def): max_hp = def.base_hp
			
			# Apply the echo buff
			var new_val = battle_manager.apply_stat_delta(tgt, stat, amount, source_uuid, C.ACTION_BUFF, true)
			if new_val == null:
				new_val = old_val
			
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
			all_max_hp.append(max_hp)

		if valid_targets.is_empty():
			return EffectResult.empty()
			
		# Visuals
		var stat_str = "HP" if stat == "hp" else "PWR"
		var log_text = "%s echoes buff! Grants +%d %s to adjacent ally." % [source_name, amount, stat_str]
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

		var visual_source_uuid = source_uuid

		if stat == "hp":
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": &"unit_t2_g_buff_echo",
				"trigger_type": &"on_stat_increased",
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.hp_buff(visual_source_uuid, amount, all_old_vals, all_new_vals, all_max_hp)
			}))
		elif stat == "pwr":
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": all_target_uuids,
				"ability_id": &"unit_t2_g_buff_echo",
				"trigger_type": &"on_stat_increased",
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_buff(visual_source_uuid, amount, all_old_vals, all_new_vals)
			}))
			
		result.state_applied = true
		return result
	else:
		# Non-simulation
		for target_uuid in targets:
			if target_uuid not in adjacent_uuids:
				continue
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				battle_manager.apply_stat_delta(tgt, stat, amount, source_uuid, C.ACTION_BUFF, true)
		return EffectResult.empty()