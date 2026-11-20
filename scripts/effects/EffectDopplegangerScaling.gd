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
	
	var scale_amount: int = int(parameters.get("scale_amount", 3))
	var bonus_pwr: int = copy_count * scale_amount
	if not _is_on_board(source):
		bonus_pwr = 0

	var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
		source, &"doppleganger", 0, bonus_pwr, source_uuid, AuraEvaluator.KIND_DOPPLEGANGER,
		{"silent": true, "meta": {"scale_amount": scale_amount}}
	)
	if not rec_res.changed:
		return EffectResult.empty()

	var result := EffectResult.new()
	if _is_on_board(source):
		# Use BUFF for both positive and negative stat changes to avoid attack/damage animations
		var visual_source_uuid: String = source_uuid
		var payload: CombatPayload = CombatPayload.pwr_change(visual_source_uuid, rec_res.delta_pwr, [rec_res.old_pwr], [rec_res.new_pwr])
		
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": visual_source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": (context.ability_id if context.ability_id != &"" else &"doppleganger_scaling"),
			"ability_holder_uuid": source_uuid,
			"visual_payload": payload
		}))
		
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "BubbleGunger scales by %+d PWR (%d copies)" % [rec_res.delta_pwr, copy_count]
		}))
	
	result.state_applied = true
	return result

func _is_on_board(inst: GachaBallInstance) -> bool:
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"EnemyLineup"
