# res://scripts/effects/EffectEchoingOrbScaling.gd
@tool
extends EffectDefinition

## Grants +2 PWR to the holder for every Echoing Orb in the Battle Pool (including itself).
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator
	var all_instances = battle_manager.get_all_instances()
	var copy_count = 0
	
	# Find the Echoing Orb item instance
	var source_item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_item):
		return EffectResult.empty()

	var source_is_player = _is_player_item(source_item, battle_manager)

	for uuid in all_instances:
		var inst = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if inst.definition_id == &"item_t2_d": 
			if _is_player_item(inst, battle_manager) == source_is_player:
				copy_count += 1
	
	var bonus_pwr = copy_count * 2
	var status_key = StringName("echoing_orb_scaling_" + source_uuid)
	
	# Clear any old scaling status effect that might have been stored on the item itself
	if source_item.get_status_effect_amount(status_key) > 0:
		source_item.clear_status_effect(status_key)

	# Update the HOLDER's stats (and clean up any old holders)
	var active_holder_uuid = source_item.equipped_on_uuid
	var holder_updated = false
	var result := EffectResult.new()
	
	for uuid in all_instances:
		var inst = all_instances[uuid]
		if not is_instance_valid(inst) or battle_manager.is_dead_this_turn(uuid):
			continue
		var inst_last_scaling = inst.get_status_effect_amount(status_key)
		
		# Skip the item itself
		if uuid == source_uuid:
			continue
			
		if uuid == active_holder_uuid and not active_holder_uuid.is_empty():
			# This is the current holder. Only apply bonus if on board
			var target_bonus = bonus_pwr if _is_on_board(inst) else 0
			var holder_delta = target_bonus - inst_last_scaling
			if holder_delta != 0:
				if inst_last_scaling > 0: 
					inst.clear_status_effect(status_key)
				if target_bonus > 0: 
					inst.add_status_effect_silent(status_key, target_bonus)
				inst.apply_pwr_delta(holder_delta, {"silent": is_simulation})
				holder_updated = true
				
				if is_simulation and _is_on_board(inst):
					# Self buff event targeting the holder unit
					var visual_source_uuid = active_holder_uuid
					var payload = CombatPayload.pwr_change(visual_source_uuid, holder_delta, [inst.current_pwr - holder_delta], [inst.current_pwr])
					result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
						"source_uuid": visual_source_uuid,
						"target_uuids": [active_holder_uuid],
						"ability_id": context.get("ability_id", &"echoing_orb_scaling"),
						"ability_holder_uuid": active_holder_uuid,
						"visual_payload": payload
					}))
		elif inst_last_scaling > 0:
			# This unit was previously holding this orb, but is no longer the holder
			inst.clear_status_effect(status_key)
			inst.apply_pwr_delta(-inst_last_scaling, {"silent": is_simulation})
			holder_updated = true
			if is_simulation and _is_on_board(inst):
				var visual_source_uuid = uuid
				var payload = CombatPayload.pwr_change(visual_source_uuid, -inst_last_scaling, [inst.current_pwr + inst_last_scaling], [inst.current_pwr])
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": visual_source_uuid,
					"target_uuids": [uuid],
					"ability_id": context.get("ability_id", &"echoing_orb_scaling"),
					"ability_holder_uuid": uuid,
					"visual_payload": payload
				}))
	
	if not holder_updated: 
		return EffectResult.empty()

	if is_simulation:
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Echoing Orb (%s) updated holder %s (%+d PWR, %d copies)" % [source_uuid, active_holder_uuid, bonus_pwr, copy_count]
		}))
	
	result.state_applied = true
	return result

func _is_on_board(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"PlayerBench" or container == &"EnemyLineup" or container == &"EnemyBench"

func _is_player_item(inst: GachaBallInstance, battle_manager: Node) -> bool:
	if not is_instance_valid(inst):
		return false
	if not inst.equipped_on_uuid.is_empty():
		var holder = battle_manager.get_instance_by_uuid(inst.equipped_on_uuid)
		if is_instance_valid(holder):
			return battle_manager._is_player_unit(holder) or battle_manager._is_player_owned(holder)
	return battle_manager._is_player_unit(inst) or battle_manager._is_player_owned(inst)
