# res://scripts/effects/EffectTwinCharmScaling.gd
@tool
extends EffectDefinition

## Grants allied units +1 PWR for each pair of that unit
## in the allied battle pool (lineup, bench, gacha trays, discard).
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator
	var all_instances: Dictionary = battle_manager.get_all_instances()
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty()

	var team: String = String(context.get("team", _get_team_for_instance(source, battle_manager)))
	var status_key := StringName("twin_charm_scaling_" + source_uuid)
	var copy_counts: Dictionary = {}
	var changed_units := 0
	var total_delta := 0
	
	var buff_groups: Dictionary = {} # delta -> { "targets": [], "new_pwrs": [] }
	var debuff_groups: Dictionary = {} # abs(delta) -> { "targets": [], "new_pwrs": [] }

	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if not _is_valid_count_target(inst, team, battle_manager):
			continue
		copy_counts[inst.definition_id] = int(copy_counts.get(inst.definition_id, 0)) + 1

	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst) or battle_manager.is_dead_this_turn(uuid):
			continue

		var last_bonus: int = inst.get_status_effect_amount(status_key)
		if not _is_valid_count_target(inst, team, battle_manager):
			if last_bonus > 0:
				_clear_scaling(inst, status_key, last_bonus, is_simulation)
				changed_units += 1
				total_delta -= last_bonus
				
				if is_simulation and _is_on_board(inst):
					if not debuff_groups.has(last_bonus):
						debuff_groups[last_bonus] = {"targets": [], "new_pwrs": []}
					debuff_groups[last_bonus]["targets"].append(uuid)
					debuff_groups[last_bonus]["new_pwrs"].append(inst.current_pwr)
			continue

		var total_copies: int = int(copy_counts.get(inst.definition_id, 0))
		var bonus_pwr: int = total_copies / 2
		var delta: int = bonus_pwr - last_bonus
		if delta == 0:
			continue

		_set_scaling(inst, status_key, last_bonus, bonus_pwr, delta, is_simulation)
		changed_units += 1
		total_delta += delta

		if is_simulation and _is_on_board(inst) and not inst.has_meta("skip_initial_scaling_anim"):
			if delta > 0:
				if not buff_groups.has(delta):
					buff_groups[delta] = {"targets": [] as Array[String], "new_pwrs": [] as Array[int]}
				buff_groups[delta]["targets"].append(uuid)
				buff_groups[delta]["new_pwrs"].append(inst.current_pwr)
			else:
				var abs_delta = abs(delta)
				if not debuff_groups.has(abs_delta):
					debuff_groups[abs_delta] = {"targets": [] as Array[String], "new_pwrs": [] as Array[int]}
				debuff_groups[abs_delta]["targets"].append(uuid)
				debuff_groups[abs_delta]["new_pwrs"].append(inst.current_pwr)

	if changed_units == 0:
		return EffectResult.empty()

	if is_simulation:
		var result := EffectResult.new()
		var visual_source_uuid = source.equipped_on_uuid if source.get("equipped_on_uuid") and not source.equipped_on_uuid.is_empty() else source_uuid

		for d in buff_groups:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": buff_groups[d]["targets"],
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_change(visual_source_uuid, d, [], buff_groups[d]["new_pwrs"])
			}))
			
		for d in debuff_groups:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": visual_source_uuid,
				"target_uuids": debuff_groups[d]["targets"],
				"ability_holder_uuid": source_uuid,
				"visual_payload": CombatPayload.pwr_change(visual_source_uuid, -d, [], debuff_groups[d]["new_pwrs"])
			}))
			
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Twin Charm updated %d units (%+d total PWR)" % [changed_units, total_delta]
		}))
		result.state_applied = true
		return result

	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

func _set_scaling(unit: GachaBallInstance, status_key: StringName, last_bonus: int, new_bonus: int, delta: int, is_simulation: bool) -> void:
	if last_bonus > 0:
		_clear_status(unit, status_key, last_bonus, is_simulation)
	if new_bonus > 0:
		unit.add_status_effect_silent(status_key, new_bonus)
	unit.apply_pwr_delta(delta, {"silent": is_simulation})

func _clear_scaling(unit: GachaBallInstance, status_key: StringName, last_bonus: int, is_simulation: bool) -> void:
	_clear_status(unit, status_key, last_bonus, is_simulation)
	unit.apply_pwr_delta(-last_bonus, {"silent": is_simulation})

func _clear_status(unit: GachaBallInstance, status_key: StringName, last_bonus: int, is_simulation: bool) -> void:
	if is_simulation:
		unit.status_effects.erase(status_key)
	else:
		unit.clear_status_effect(status_key)

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
	if container == &"EnemyLineup" or container == &"EnemyBench":
		return "ENEMY"

	return ""

func _is_on_board(inst: GachaBallInstance) -> bool:
	if not is_instance_valid(inst):
		return false
	var container: StringName = inst.location_container_tag
	return container == &"PlayerLineup" or container == &"PlayerBench" or container == &"EnemyLineup" or container == &"EnemyBench"
