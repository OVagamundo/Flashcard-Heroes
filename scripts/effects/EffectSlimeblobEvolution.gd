# res://scripts/effects/EffectSlimeblobEvolution.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty()
	var def = source.get_definition()
	if is_instance_valid(def) and def.category == &"UNIT" and source.current_hp <= 0:
		return EffectResult.empty()

	var enemy_container = battle_manager.get_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	if not is_instance_valid(enemy_container):
		return EffectResult.empty()

	# Check if any slot is empty (Priority: Frontmost vacant slot 0 -> 4, replacing corpses)
	var first_empty_slot: int = -1
	for i in range(5):
		var u_uuid: String = enemy_container.get_uuid(i)
		if u_uuid.is_empty():
			first_empty_slot = i
			break
		var u_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(u_uuid)
		if not is_instance_valid(u_inst) or u_inst.current_hp <= 0 or battle_manager.is_dead_this_turn(u_uuid):
			first_empty_slot = i
			break

	# Step 1: Any slot empty -> summon L1 Spikeslime into frontmost empty slot
	if first_empty_slot != -1:
		var result := EffectResult.new()
		result.summon_units_request = [{
			"unit_id": &"unit_spikeslime",
			"slot": first_empty_slot,
			"level": 1
		}]
		result.summon_team = "ENEMY"
		return result

	# All 5 slots full: inspect Spikeslimes
	var enemy_lineup = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var living_spikeslimes: Array[GachaBallInstance] = []
	for u in enemy_lineup:
		if is_instance_valid(u) and u.definition_id == &"unit_spikeslime" and u.current_hp > 0 and not battle_manager.is_dead_this_turn(u.ball_uuid):
			living_spikeslimes.append(u)

	living_spikeslimes.sort_custom(func(a, b): return a.location_slot_index < b.location_slot_index)

	if living_spikeslimes.is_empty():
		return EffectResult.empty()

	# Step 2: Any Spikeslime < Level 3 -> level up first one
	for s_unit in living_spikeslimes:
		if s_unit.level < 3:
			s_unit.level += 1
			var old_hp = s_unit.current_hp
			var old_pwr = s_unit.current_pwr
			var new_hp = battle_manager.apply_stat_delta(s_unit, "hp", 1, source_uuid, C.ACTION_BUFF, true)
			var new_pwr = battle_manager.apply_stat_delta(s_unit, "pwr", 1, source_uuid, C.ACTION_BUFF, true)
			var u_def = s_unit.get_definition()
			var max_hp = u_def.base_hp if is_instance_valid(u_def) else 0

			var result := EffectResult.new()
			var buff_payload := CombatPayload.both_stats_change(
				source_uuid,
				1,
				1,
				[old_hp],
				[new_hp],
				[old_pwr],
				[new_pwr],
				[max_hp]
			)
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [s_unit.ball_uuid],
				"action_type": C.ACTION_BUFF,
				"visual_payload": buff_payload
			}))

			var old_spikes = s_unit.get_status_effect_amount(&"spikes")
			var new_spikes = battle_manager.apply_stat_delta(s_unit, "spikes_stacks", 1, source_uuid)
			var s_payload := CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [old_spikes], [new_spikes])
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [s_unit.ball_uuid],
				"visual_payload": s_payload
			}))
			return result

	# Step 3: All 5 slots full and all living Spikeslimes are Level 3 -> frontmost gets +3 HP heal and +2 Spikes
	var front_spikeslime: GachaBallInstance = living_spikeslimes[0]
	var old_hp = front_spikeslime.current_hp
	var new_hp = battle_manager.apply_stat_delta(front_spikeslime, "hp", 3, source_uuid, C.ACTION_HEAL)
	var f_def = front_spikeslime.get_definition()
	var max_hp = f_def.base_hp if is_instance_valid(f_def) else 0

	var result := EffectResult.new()
	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [front_spikeslime.ball_uuid],
		"action_type": C.ACTION_HEAL,
		"visual_payload": CombatPayload.heal(source_uuid, 3, [old_hp], [new_hp], [max_hp])
	}))

	var old_spikes = front_spikeslime.get_status_effect_amount(&"spikes")
	var new_spikes = battle_manager.apply_stat_delta(front_spikeslime, "spikes_stacks", 2, source_uuid)
	var s_payload := CombatPayload.status_change(source_uuid, 2, "spikes_stacks", [old_spikes], [new_spikes])
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": [front_spikeslime.ball_uuid],
		"visual_payload": s_payload
	}))
	return result
