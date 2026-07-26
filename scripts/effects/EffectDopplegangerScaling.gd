# res://scripts/effects/EffectDopplegangerScaling.gd
@tool
extends EffectDefinition

## Grants +3 PWR for every OTHER Doppleganger in the Battle Pool.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator
	var all_instances = battle_manager.get_all_instances()
	var copy_count = 0
	
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or battle_manager.is_dead_this_turn(source_uuid):
		return EffectResult.empty()
		
	var source_is_player = _is_player_unit_team(source, battle_manager)
	
	for uuid in all_instances:
		if uuid == source_uuid: 
			continue
		var inst = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if inst.definition_id == &"unit_t3_i": 
			if _is_player_unit_team(inst, battle_manager) == source_is_player:
				copy_count += 1
	
	var scale_amount = self.parameters.get("scale_amount", 3)
	var bonus_pwr = copy_count * scale_amount
	var status_key = &"doppleganger_scaling"
	var last_scaling = source.get_status_effect_amount(status_key)
	var delta = bonus_pwr - last_scaling
	
	if delta == 0: 
		return EffectResult.empty()

	# Sync status effect amount silently
	if last_scaling > 0: 
		source.clear_status_effect(status_key)
	if bonus_pwr > 0: 
		source.add_status_effect_silent(status_key, bonus_pwr)
		
	# Apply standard PWR modification
	source.apply_pwr_delta(delta, {"silent": is_simulation})

	var result := EffectResult.new()
	if is_simulation:
		var skip_anim = source.has_meta("skip_initial_scaling_anim")
		# Use BUFF for both positive and negative stat changes to avoid attack/damage animations
		var visual_source_uuid = "" # Omit source_uuid to prevent self-projectile
		var payload = CombatPayload.pwr_change(visual_source_uuid, delta, [], [source.current_pwr])
		payload.skip_bump = skip_anim # Silently update the UI without hopping or flashing
		
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": visual_source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.get("ability_id", &"doppleganger_scaling"),
			"ability_holder_uuid": source_uuid,
			"visual_payload": payload
		}))
		
		if not skip_anim:
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "Doppleganger scales by %+d PWR (%d copies)" % [delta, copy_count]
			}))
	
	result.state_applied = true
	return result

func _is_player_unit_team(inst: GachaBallInstance, battle_manager: Node) -> bool:
	if not is_instance_valid(inst):
		return false
	return battle_manager._is_player_unit(inst) or battle_manager._is_player_owned(inst)

func _is_on_board(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"PlayerBench" or container == &"EnemyLineup" or container == &"EnemyBench"
