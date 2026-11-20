# res://scripts/effects/EffectRustyRingBuff.gd
@tool
extends EffectDefinition

## Effect that buffs all team units with +1 HP, +1 PWR if they have no equipment.
## Used by Rusty Ring trinket on draw, summon, or battle start.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	var all_instances: Dictionary = battle_manager.get_all_instances()
	
	# Resolve the trinket's team
	var trinket_team: String = context.team
	if trinket_team.is_empty():
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		if is_instance_valid(trinket_instance):
			trinket_team = _get_team_from_container(trinket_instance.location_container_tag)
			
	if trinket_team.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var state_applied_any := false
	
	var hp_amount := 1
	var pwr_amount := 1
	var aura_key: StringName = AuraEvaluator.make_key(&"rusty_ring", _source_uuid)
	
	# Determine target units on the same team
	var batched_target_uuids: Array[String] = []
	var batched_target_names: Array[String] = []
	var batched_old_hp: Array[int] = []
	var batched_new_hp: Array[int] = []
	var batched_max_hp: Array[int] = []
	var batched_old_pwr: Array[int] = []
	var batched_new_pwr: Array[int] = []

	for target_uuid in all_instances:
		var target_instance: GachaBallInstance = all_instances[target_uuid]
		if not is_instance_valid(target_instance) or target_instance.current_hp <= 0:
			continue
			
		# Must be on the board (lineup) and on the same team
		var container = target_instance.location_container_tag
		var is_on_board = container in [&"PlayerLineup", &"EnemyLineup"]
		if not is_on_board or _get_team_from_container(container) != trinket_team:
			continue
			
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def) or target_def.category != &"UNIT":
			continue
			
		# Prevent duplicate entry applications while already registered for this Rusty Ring.
		if target_instance.has_aura(aura_key):
			continue
			
		var has_equip: bool = AuraEvaluator._unit_has_equipment(target_instance)
		var target_hp: int = 0 if has_equip else hp_amount
		var target_pwr: int = 0 if has_equip else pwr_amount
		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			target_instance, aura_key, target_hp, target_pwr,
			_source_uuid, AuraEvaluator.KIND_RUSTY_RING,
			{
				"keep_registered": true,
				"silent": is_simulation,
				"meta": {"hp_amount": hp_amount, "pwr_amount": pwr_amount},
			}
		)
		if not rec_res.changed:
			continue
		
		if is_simulation:
			batched_target_uuids.append(target_uuid)
			batched_target_names.append(BattleHelpers.get_instance_display_name(target_instance))
			batched_old_hp.append(rec_res.old_hp)
			batched_new_hp.append(rec_res.new_hp)
			batched_max_hp.append(target_def.base_hp)
			batched_old_pwr.append(rec_res.old_pwr)
			batched_new_pwr.append(rec_res.new_pwr)
			state_applied_any = true
		else:
			state_applied_any = true

	if is_simulation and not batched_target_uuids.is_empty():
		var trinket_name := "Rusty Ring"
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		if is_instance_valid(trinket_instance):
			var trinket_def = trinket_instance.get_definition()
			if is_instance_valid(trinket_def):
				trinket_name = tr(trinket_def.name_key)

		# Single Log message for all targets
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, " and ".join(batched_target_names), hp_amount, pwr_amount]
		}))
		
		# Unified BUFF event (all projectiles launched simultaneously)
		var ability_id = (context.ability_id if context.ability_id != &"" else &"ability_trinket_rusty_ring")
		if hp_amount > 0 and pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": ability_id,
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.both_stats_change(
					_source_uuid, hp_amount, pwr_amount,
					batched_old_hp, batched_new_hp,
					batched_old_pwr, batched_new_pwr,
					batched_max_hp
				)
			}))
		elif hp_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": ability_id,
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, batched_old_hp, batched_new_hp, batched_max_hp)
			}))
		elif pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": ability_id,
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
				"buff_subgroup": C.BUFF_SUBGROUP_CONDITIONAL,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, batched_old_pwr, batched_new_pwr)
			}))

	result.state_applied = true
	return result

# Helper to determine team from container tag
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerShelf":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
