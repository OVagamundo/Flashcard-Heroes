# res://scripts/effects/EffectTwinCharmScaling.gd
@tool
extends EffectDefinition

## Grants allied units +1 PWR for each pair of that unit
## in the allied battle pool (lineup, shelf, gacha trays, discard).
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator
	var all_instances: Dictionary = battle_manager.get_all_instances()
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty()

	var team: String = context.team if not context.team.is_empty() else _get_team_for_instance(source, battle_manager)
	var aura_key: StringName = AuraEvaluator.make_key(&"twin_charm", team)
	var copy_counts: Dictionary = {}
	var changed_units := 0
	var total_delta := 0


	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if not _is_valid_count_target(inst, team, battle_manager):
			continue
		copy_counts[inst.definition_id] = int(copy_counts.get(inst.definition_id, 0)) + 1

	var buff_groups: Dictionary = {} # delta -> { "targets": [], "old_pwrs": [], "new_pwrs": [] }
	var debuff_groups: Dictionary = {}
	var silent_buff_groups: Dictionary = {}
	var silent_debuff_groups: Dictionary = {} # abs(delta) -> { "targets": [], "old_pwrs": [], "new_pwrs": [] }

	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst) or battle_manager.is_dead_this_turn(uuid):
			continue
		if inst.location_container_tag in [&"PlayerShelf", &"EnemyShelf"]:
			continue

		var target_bonus: int = 0
		if _is_valid_count_target(inst, team, battle_manager) and _is_on_board(inst):
			var total_copies: int = int(copy_counts.get(inst.definition_id, 0))
			target_bonus = total_copies / 2

		var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
			inst, aura_key, 0, target_bonus, source_uuid, AuraEvaluator.KIND_TWIN_CHARM,
			{"silent": is_simulation, "meta": {"team": team}}
		)
		if not rec_res.changed:
			continue

		var delta: int = rec_res.delta_pwr
		changed_units += 1
		total_delta += delta

		if is_simulation and _is_on_board(inst):
			var is_silent: bool = inst.has_meta("skip_initial_scaling_anim")
			if delta > 0:
				var groups = silent_buff_groups if is_silent else buff_groups
				if not groups.has(delta):
					groups[delta] = {"targets": [] as Array[String], "old_pwrs": [] as Array[int], "new_pwrs": [] as Array[int]}
				groups[delta]["targets"].append(uuid)
				groups[delta]["old_pwrs"].append(rec_res.old_pwr)
				groups[delta]["new_pwrs"].append(rec_res.new_pwr)
			else:
				var groups = silent_debuff_groups if is_silent else debuff_groups
				var abs_delta: int = absi(delta)
				if not groups.has(abs_delta):
					groups[abs_delta] = {"targets": [] as Array[String], "old_pwrs": [] as Array[int], "new_pwrs": [] as Array[int]}
				groups[abs_delta]["targets"].append(uuid)
				groups[abs_delta]["old_pwrs"].append(rec_res.old_pwr)
				groups[abs_delta]["new_pwrs"].append(rec_res.new_pwr)

	if changed_units == 0:
		return EffectResult.empty()

	if is_simulation:
		var result := EffectResult.new()
		var visual_source_uuid = source_uuid

		for d in buff_groups:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": buff_groups[d]["targets"],
				"ability_id": (context.ability_id if context.ability_id != &"" else &"twin_charm_scaling"),
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_change(visual_source_uuid, d, buff_groups[d]["old_pwrs"], buff_groups[d]["new_pwrs"])
			}))
			
		for d in silent_buff_groups:
			var payload = CombatPayload.pwr_change("", d, silent_buff_groups[d]["old_pwrs"], silent_buff_groups[d]["new_pwrs"])
			payload.skip_bump = true
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": "",
				"target_uuids": silent_buff_groups[d]["targets"],
				"ability_holder_uuid": source_uuid,
				"visual_payload": payload
			}))
			
		for d in debuff_groups:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": debuff_groups[d]["targets"],
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_change(visual_source_uuid, -d, debuff_groups[d]["old_pwrs"], debuff_groups[d]["new_pwrs"])
			}))
			
		for d in silent_debuff_groups:
			var payload = CombatPayload.pwr_change("", -d, silent_debuff_groups[d]["old_pwrs"], silent_debuff_groups[d]["new_pwrs"])
			payload.skip_bump = true
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": "",
				"target_uuids": silent_debuff_groups[d]["targets"],
				"ability_holder_uuid": source_uuid,
				"visual_payload": payload
			}))
			
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Twin Charm updated %d units (%+d total PWR)" % [changed_units, total_delta]
		}))
		result.state_applied = true
		return result

	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

func _is_valid_count_target(inst: GachaBallInstance, team: String, battle_manager: Node) -> bool:
	if not is_instance_valid(inst):
		return false
	var definition: Resource = inst.get_definition()
	if not is_instance_valid(definition):
		return false
	if definition.category != &"UNIT":
		return false
	return _get_team_for_instance(inst, battle_manager) == team

func _get_team_for_instance(inst: GachaBallInstance, battle_manager: Node) -> String:
	if not is_instance_valid(inst):
		return ""
	if battle_manager._is_player_owned(inst):
		return "PLAYER"

	var container: StringName = inst.location_container_tag
	if container == &"EnemyLineup" or container == &"EnemyShelf":
		return "ENEMY"

	return ""

func _is_on_board(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"EnemyLineup"
