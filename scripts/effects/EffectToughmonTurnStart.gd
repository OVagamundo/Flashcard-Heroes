# res://scripts/effects/EffectToughmonTurnStart.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.empty()

	var enemy_lineup = battle_manager.get_instances_in_container(C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
	var surviving_allies: Array[GachaBallInstance] = []
	for ally in enemy_lineup:
		if is_instance_valid(ally) and ally.ball_uuid != source_uuid and ally.current_hp > 0 and not battle_manager.is_dead_this_turn(ally.ball_uuid):
			surviving_allies.append(ally)

	var result := EffectResult.new()

	# 1. Self-Preservation Armor: +2 Armor per surviving ally
	var self_armor_amount: int = 2 * surviving_allies.size()
	if self_armor_amount > 0:
		var old_armor = source.get_status_effect_amount(&"armor")
		var new_armor = battle_manager.apply_stat_delta(source, "armor_stacks", self_armor_amount, source_uuid)
		var armor_payload := CombatPayload.status_change(source_uuid, self_armor_amount, "armor", [old_armor], [new_armor])
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"visual_payload": armor_payload
		}))

	# 2. Toughmon's Command: Every living ally in front of Toughmon gets +2 Armor and +1 Spikes
	for ally in surviving_allies:
		if ally.location_slot_index < source.location_slot_index:
			var old_a = ally.get_status_effect_amount(&"armor")
			var new_a = battle_manager.apply_stat_delta(ally, "armor_stacks", 2, source_uuid)
			var a_payload := CombatPayload.status_change(source_uuid, 2, "armor", [old_a], [new_a])
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [ally.ball_uuid],
				"visual_payload": a_payload
			}))

			var old_s = ally.get_status_effect_amount(&"spikes")
			var new_s = battle_manager.apply_stat_delta(ally, "spikes_stacks", 1, source_uuid)
			var s_payload := CombatPayload.status_change(source_uuid, 1, "spikes_stacks", [old_s], [new_s])
			result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
				"source_uuid": source_uuid,
				"target_uuids": [ally.ball_uuid],
				"visual_payload": s_payload
			}))

	return result
