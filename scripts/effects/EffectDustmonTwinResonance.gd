# res://scripts/effects/EffectDustmonTwinResonance.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

const DUST_IDS: Array[StringName] = [&"unit_dust_t1", &"unit_dust_t2", &"unit_dust_t3"]

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	var player_containers: Array[StringName] = [
		&"BattleInventoryT1",
		&"BattleInventoryT2",
		&"BattleInventoryT3",
		C.BATTLE_CONTAINER_TAGS.PLAYER_SHELF,
		C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP,
		C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE
	]

	var dust_count: int = 0
	for tag in player_containers:
		var container = battle_manager.get_container(tag)
		if not is_instance_valid(container):
			continue
		for i in range(container.get_size()):
			var u_uuid: String = container.get_uuid(i)
			if u_uuid.is_empty():
				continue
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(u_uuid)
			if is_instance_valid(inst) and DUST_IDS.has(inst.definition_id) and not battle_manager.is_dead_this_turn(u_uuid):
				dust_count += 1

	var last_bonus: int = source.get_status_effect_amount(&"dustmon_resonance_bonus")
	var delta: int = dust_count - last_bonus
	if delta == 0:
		return EffectResult.empty()

	source.add_status_effect_silent(&"dustmon_resonance_bonus", delta)
	var old_pwr: int = source.current_pwr
	var new_pwr: int = battle_manager.apply_stat_delta(source, "pwr", delta, source_uuid, C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF)

	var result := EffectResult.new()
	if delta > 0:
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"action_type": C.ACTION_BUFF,
			"visual_payload": CombatPayload.pwr_buff(source_uuid, delta, [old_pwr], [new_pwr])
		}))
	else:
		result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"action_type": C.ACTION_DEBUFF,
			"visual_payload": CombatPayload.pwr_debuff(source_uuid, -delta, [old_pwr], [new_pwr])
		}))
	return result
