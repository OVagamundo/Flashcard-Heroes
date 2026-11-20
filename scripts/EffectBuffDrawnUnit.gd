# res://scripts/EffectBuffDrawnUnit.gd
@tool
extends EffectDefinition

## Effect that buffs Level 1 units when they enter the board.
## Used by Apprentice Insignia to grant +1 HP and +1 PWR to Level 1 units.
## Expected parameters:
##   - hp_amount: int (default 1) - HP buff amount
##   - pwr_amount: int (default 1) - PWR buff amount

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation: bool = context.is_simulation
	
	# Get the target unit UUID from context
	# Context key depends on trigger:
	# - on_draw: "drawn_uuid"
	# - on_ally_summon: "summoned_uuid"
	# - on_merge: "merged_uuid"
	# - on_battle_start: "source_uuid" (the unit starting battle)
	# Determine targets: Use _targets if provided, otherwise infer from context
	var targets_to_process: Array[String] = []
	if not _targets.is_empty():
		targets_to_process = _targets.duplicate()
	else:
		var ctx_uuid: String = context.entered_uuid
		if ctx_uuid.is_empty():
			ctx_uuid = context.drawn_uuid
		if ctx_uuid.is_empty():
			ctx_uuid = context.summoned_uuid
		if ctx_uuid.is_empty():
			ctx_uuid = context.merged_uuid
		if ctx_uuid.is_empty():
			ctx_uuid = context.source_uuid
		if not ctx_uuid.is_empty():
			targets_to_process.append(ctx_uuid)
	
	if targets_to_process.is_empty():
		return EffectResult.empty()
	
	var result := EffectResult.new()
	var state_applied_any := false
	
	# TEAM CHECK: Ensure targets are on same team as trinket owner
	var trinket_instance = battle_manager.get_instance(_source_uuid)
	var source_team := ""
	if is_instance_valid(trinket_instance):
		source_team = _get_team_from_container(trinket_instance.location_container_tag)
	var batched_target_uuids: Array[String] = []
	var batched_target_names: Array[String] = []
	var batched_old_hp: Array[int] = []
	var batched_new_hp: Array[int] = []
	var batched_max_hp: Array[int] = []
	var batched_old_pwr: Array[int] = []
	var batched_new_pwr: Array[int] = []

	var raw_hp = parameters.get("hp_amount", 1)
	var hp_amount: int = int(raw_hp) if raw_hp != null else 1
	
	var raw_pwr = parameters.get("pwr_amount", 1)
	var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 1
	
	var trinket_name: String = ""
	if is_instance_valid(trinket_instance):
		var trinket_def = trinket_instance.get_definition()
		if is_instance_valid(trinket_def):
			trinket_name = tr(trinket_def.name_key)
	if trinket_name.is_empty():
		trinket_name = "Apprentice Insignia"

	var aura_key: StringName = AuraEvaluator.make_key(&"insignia", _source_uuid)
	var aura_meta: Dictionary = {
		"hp_amount": hp_amount,
		"pwr_amount": pwr_amount,
		"target_level": 1,
		"target_tier": 0,
		"target_trait": "",
		"trinket_name": trinket_name,
	}

	for target_uuid in targets_to_process:
		# Get the target instance
		var target_instance = battle_manager.get_instance(target_uuid)
		if not is_instance_valid(target_instance):
			continue
		if target_instance.location_container_tag not in [&"PlayerLineup", &"EnemyLineup"]:
			continue
		
		# Team check
		if not source_team.is_empty():
			var target_team = _get_team_from_container(target_instance.location_container_tag)
			if target_team != source_team:
				continue
		
		# Get definition to check category and hero status
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def):
			continue
		
		# Only buff UNIT category
		if target_def.category != &"UNIT":
			continue
		
		# Heroes do not have levels or tiers and are not affected by this trinket
		if target_def.is_hero:
			continue
		
		# Apprentice Insignia applies to Level 1 units only (no tier requirement)
		if target_instance.level != 1:
			continue
		
		# Prevent duplicate aura application for this insignia instance
		if target_instance.has_aura(aura_key):
			continue
		
		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			target_instance, aura_key, hp_amount, pwr_amount,
			_source_uuid, AuraEvaluator.KIND_INSIGNIA,
			{"keep_registered": true, "silent": is_simulation, "meta": aura_meta}
		)
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
		# Single Log message for all targets
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, " and ".join(batched_target_names), hp_amount, pwr_amount]
		}))
		
		# Unified BUFF event
		if hp_amount > 0 and pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": &"ability_trinket_royal_insignia",
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
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
				"ability_id": &"ability_trinket_royal_insignia",
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, batched_old_hp, batched_new_hp, batched_max_hp)
			}))
		elif pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": &"ability_trinket_royal_insignia",
				"trigger_type": context.trigger_type,
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, batched_old_pwr, batched_new_pwr)
			}))

	result.state_applied = state_applied_any
	return result

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerShelf":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
