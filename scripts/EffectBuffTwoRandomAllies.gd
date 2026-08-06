# res://scripts/EffectBuffTwoRandomAllies.gd
@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

## Buffs two random allies with a specified stat amount each.
## Each ally is selected independently, so the same ally can receive both buffs.
## The animation source is the item holder (equipped_on_uuid), not the item itself.
## Used by Power Amulet (T3 Item B) on_attack trigger.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the buff amount and stat from parameters
	var buff_amount: int = int(parameters.get("base_value", 2))
	var num_buffs: int = int(parameters.get("buff_count", 2))
	var buff_stat: String = parameters.get("stat", "pwr")
	
	# Zero-Instance-Query Compliant: Get holder UUID from context
	# For items, BattleManager pre-populates source_holder_uuid
	var holder_uuid: String = context.get("source_holder_uuid", "")
	if holder_uuid.is_empty():
		push_warning("[EffectBuffTwoRandomAllies] source_holder_uuid missing from context")
		return EffectResult.empty()
	
	# We still need holder instance for team detection
	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder):
		return EffectResult.empty()
	
	# Determine which team the holder is on
	var holder_is_player: bool = battle_manager._is_player_unit(holder)
	
	# Get all living allies (including the holder)
	var lineup_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP if holder_is_player else C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	var allies = battle_manager.get_instances_in_container(lineup_tag).filter(func(u): return u.current_hp > 0)
	
	if allies.is_empty():
		return EffectResult.empty()
	
	# Select random targets independently for each buff
	var buff_targets: Array[String] = []
	for i in range(num_buffs):
		var random_ally = RNGManager.combat_rng.pick_random(allies)
		buff_targets.append(random_ally.ball_uuid)
	
	if is_simulation:
		var result := EffectResult.new()
		var batched_target_uuids: Array[String] = []
		var batched_target_names: Array[String] = []
		var batched_old_vals: Array[int] = []
		var batched_new_vals: Array[int] = []
		var batched_max_hp: Array[int] = []
		
		for target_uuid in buff_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt):
				continue
			
			# Capture old stat for animation
			var old_val: int = tgt.current_pwr if buff_stat == "pwr" else tgt.current_hp
			var tgt_max_hp: int = tgt.get_definition().base_hp if is_instance_valid(tgt.get_definition()) else tgt.current_hp
			
			# Apply buff to model
			var new_val = battle_manager.apply_stat_delta(tgt, buff_stat, buff_amount)
			
			batched_target_uuids.append(target_uuid)
			batched_target_names.append(BattleHelpers.get_instance_display_name(tgt))
			batched_old_vals.append(old_val)
			batched_new_vals.append(new_val)
			batched_max_hp.append(tgt_max_hp)
		
		if not batched_target_uuids.is_empty():
			var holder_name: String = BattleHelpers.get_instance_display_name(holder)
			var stat_label: String = "PWR" if buff_stat == "pwr" else "HP"
			
			# Single Log message for all targets
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s grants %s +%d %s" % [holder_name, " and ".join(batched_target_names), buff_amount, stat_label]
			}))
			
			var visual_payload := CombatPayload.new()
			visual_payload.source_uuid = holder_uuid
			visual_payload.amount = buff_amount
			visual_payload.stat = buff_stat
			if buff_stat == "pwr":
				visual_payload.targets_old_pwr = batched_old_vals
				visual_payload.targets_new_pwr = batched_new_vals
			else:
				visual_payload.targets_old_val = batched_old_vals
				visual_payload.targets_new_val = batched_new_vals
				visual_payload.targets_max_hp = batched_max_hp
			
			# Single batched BUFF event for all targets simultaneously
			var event_type = CombatEvent.Type.HEAL if buff_stat == "hp" else CombatEvent.Type.BUFF
			result.add_event(CombatEvent.new(event_type, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": context.get("ability_id", &"buff_two_random"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": holder_uuid,
				"visual_payload": visual_payload
			}))
		
		result.state_applied = true
		return result
	else:
		# Apply buffs immediately (execution mode)
		for target_uuid in buff_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if is_instance_valid(tgt):
				battle_manager.apply_stat_delta(tgt, buff_stat, buff_amount)
		var non_sim_result := EffectResult.new()
		non_sim_result.state_applied = true
		return non_sim_result
