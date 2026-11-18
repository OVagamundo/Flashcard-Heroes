# res://scripts/effects/EffectDopplegangerScaling.gd
@tool
extends EffectDefinition

## Grants PWR for every other allied BubbleGunger anywhere in the battle pool.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var all_instances: Dictionary = battle_manager.get_all_instances()
	var copy_count: int = 0
	
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	assert(source != null, "BubbleGunger scaling: source must be registered")
	if battle_manager.is_dead_this_turn(source_uuid):
		return EffectResult.empty()
		
	var source_is_player: bool = battle_manager._is_player_owned(source)
	
	for uuid: String in all_instances:
		if uuid == source_uuid: 
			continue
		var inst: GachaBallInstance = all_instances[uuid]
		if inst.definition_id == source.definition_id:
			if battle_manager._is_player_owned(inst) == source_is_player:
				copy_count += 1
	
	var scale_amount: int = parameters.get("scale_amount", 3)
	var bonus_pwr: int = copy_count * scale_amount
	if not _is_on_board(source):
		bonus_pwr = 0
		
	var status_key: StringName = &"doppleganger_scaling"
	var last_scaling: int = source.get_status_effect_amount(status_key)
	var delta: int = bonus_pwr - last_scaling
	
	if delta == 0: 
		return EffectResult.empty()

	# Sync status effect amount silently
	if last_scaling > 0: 
		source.clear_status_effect(status_key)
	if bonus_pwr > 0: 
		source.add_status_effect_silent(status_key, bonus_pwr)
		
	# Apply standard PWR modification
	source.apply_pwr_delta(delta, {
		"silent": true,
		"merge_source_type": &"CONDITIONAL_ABILITY"
	})

	var result := EffectResult.new()
	if _is_on_board(source):
		# Use BUFF for both positive and negative stat changes to avoid attack/damage animations
		var visual_source_uuid: String = source_uuid
		var payload: CombatPayload = CombatPayload.pwr_change(visual_source_uuid, delta, [source.current_pwr - delta], [source.current_pwr])
		
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": visual_source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": (context.ability_id if context.ability_id != &"" else &"doppleganger_scaling"),
			"ability_holder_uuid": source_uuid,
			"visual_payload": payload
		}))
		
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "BubbleGunger scales by %+d PWR (%d copies)" % [delta, copy_count]
		}))
	
	result.state_applied = true
	return result

func _is_on_board(inst: GachaBallInstance) -> bool:
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"EnemyLineup"
