# res://scripts/effects/EffectDoppelkunMirror.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	# Find player hero in PlayerLineup or PlayerShelf
	var player_containers: Array[StringName] = [
		C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP,
		C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF
	]

	var hero_inst: GachaBallInstance = null
	for c_tag in player_containers:
		var container = battle_manager.get_container(c_tag)
		if not is_instance_valid(container):
			continue
		for i in range(container.get_size()):
			var u_uuid: String = container.get_uuid(i)
			if u_uuid.is_empty():
				continue
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(u_uuid)
			if is_instance_valid(inst) and BattleSetup.is_hero_definition(inst.get_definition()):
				hero_inst = inst
				break
		if is_instance_valid(hero_inst):
			break

	if not is_instance_valid(hero_inst):
		return EffectResult.empty()

	var hp_delta: int = hero_inst.current_hp - source.current_hp
	var pwr_delta: int = hero_inst.current_pwr - source.current_pwr

	if hp_delta == 0 and pwr_delta == 0:
		return EffectResult.empty()

	var old_hp: int = source.current_hp
	var old_pwr: int = source.current_pwr

	var new_hp: int = old_hp
	if hp_delta != 0:
		var hp_action: StringName = C.ACTION_BUFF if hp_delta > 0 else C.ACTION_DEBUFF
		new_hp = int(battle_manager.apply_stat_delta(source, "hp", hp_delta, source_uuid, hp_action, true))

	var new_pwr: int = old_pwr
	if pwr_delta != 0:
		var pwr_action: StringName = C.ACTION_BUFF if pwr_delta > 0 else C.ACTION_DEBUFF
		new_pwr = int(battle_manager.apply_stat_delta(source, "pwr", pwr_delta, source_uuid, pwr_action, true))

	var actual_hp_delta: int = new_hp - old_hp
	var actual_pwr_delta: int = new_pwr - old_pwr

	if actual_hp_delta == 0 and actual_pwr_delta == 0:
		return EffectResult.empty()

	var result := EffectResult.new()
	var ability_id: StringName = (context.ability_id if is_instance_valid(context) and context.ability_id != &"" else &"ability_doppelkun_heroic_mirror")

	if actual_hp_delta > 0 and actual_pwr_delta > 0:
		var payload := CombatPayload.both_stats_change(
			source_uuid,
			actual_hp_delta,
			actual_pwr_delta,
			[old_hp],
			[new_hp],
			[old_pwr],
			[new_pwr],
			[new_hp]
		)
		payload.action_type = C.ACTION_BUFF
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_BUFF,
			"visual_payload": payload
		}))
	elif actual_hp_delta < 0 and actual_pwr_delta < 0:
		var payload := CombatPayload.both_stats_change(
			source_uuid,
			actual_hp_delta,
			actual_pwr_delta,
			[old_hp],
			[new_hp],
			[old_pwr],
			[new_pwr],
			[new_hp]
		)
		payload.action_type = C.ACTION_DEBUFF
		result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": ability_id,
			"action_type": C.ACTION_DEBUFF,
			"visual_payload": payload
		}))
	else:
		if actual_hp_delta > 0:
			var hp_payload := CombatPayload.hp_buff(source_uuid, actual_hp_delta, [old_hp], [new_hp], [new_hp])
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_BUFF,
				"visual_payload": hp_payload
			}))
		elif actual_hp_delta < 0:
			var hp_payload := CombatPayload.hp_debuff(source_uuid, abs(actual_hp_delta), [old_hp], [new_hp])
			result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_DEBUFF,
				"visual_payload": hp_payload
			}))

		if actual_pwr_delta > 0:
			var pwr_payload := CombatPayload.pwr_buff(source_uuid, actual_pwr_delta, [old_pwr], [new_pwr])
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_BUFF,
				"visual_payload": pwr_payload
			}))
		elif actual_pwr_delta < 0:
			var pwr_payload := CombatPayload.pwr_debuff(source_uuid, abs(actual_pwr_delta), [old_pwr], [new_pwr])
			result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_id": ability_id,
				"action_type": C.ACTION_DEBUFF,
				"visual_payload": pwr_payload
			}))

	result.state_applied = true
	return result
