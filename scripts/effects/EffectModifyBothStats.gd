# res://scripts/effects/EffectModifyBothStats.gd
@tool
extends EffectDefinition

## Applies both +HP and +PWR to the same target(s) in a single atomic operation.
## Parameters:
##   hp_value: int — amount of HP to grant (default 1)
##   pwr_value: int — amount of PWR to grant (default 1)
##
## Unlike using two separate EffectModifyStat effects, this guarantees that both
## stat changes go to the same resolved target(s), preventing the "split buff"
## problem where independent target resolution sends stats to different units.

func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)

	if targets.is_empty():
		return EffectResult.empty()

	var hp_value: int = int(parameters.get("hp_value", 1))
	var pwr_value: int = int(parameters.get("pwr_value", 1))

	if hp_value == 0 and pwr_value == 0:
		return EffectResult.empty()

	# Resolve visual source (items/trinkets shoot from holder if applicable)
	var visual_source_uuid: String = _source_uuid
	var source_name: String = ""
	if not _source_uuid.is_empty():
		var src = battle_manager.get_instance_by_uuid(_source_uuid)
		if is_instance_valid(src):
			source_name = BattleHelpers.get_instance_display_name(src)
			if not src.equipped_on_uuid.is_empty():
				visual_source_uuid = src.equipped_on_uuid
	if source_name.is_empty():
		source_name = String(context.get("ability_id", "effect"))

	if is_simulation:
		var result := EffectResult.new()

		var batched_uuids: Array[String] = []
		var batched_names: Array[String] = []
		var batched_old_hp: Array[int] = []
		var batched_new_hp: Array[int] = []
		var batched_old_pwr: Array[int] = []
		var batched_new_pwr: Array[int] = []

		for target_uuid in targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt):
				continue

			var old_hp: int = tgt.current_hp
			var old_pwr: int = tgt.current_pwr

			# Apply both stat deltas to the same target
			var new_hp = battle_manager.apply_stat_delta(tgt, "hp", hp_value, _source_uuid)
			var new_pwr = battle_manager.apply_stat_delta(tgt, "pwr", pwr_value, _source_uuid)

			batched_uuids.append(target_uuid)
			batched_names.append(BattleHelpers.get_instance_display_name(tgt))
			batched_old_hp.append(old_hp)
			batched_new_hp.append(new_hp)
			batched_old_pwr.append(old_pwr)
			batched_new_pwr.append(new_pwr)

		if batched_uuids.is_empty():
			return EffectResult.empty()

		# Log message
		var names_str: String = " and ".join(batched_names)
		var log_text: String = "%s grants %s +%d HP and +%d PWR" % [source_name, names_str, hp_value, pwr_value]
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

		# Single BUFF event with both_stats_change payload
		var payload := CombatPayload.both_stats_change(
			visual_source_uuid,
			hp_value,
			pwr_value,
			batched_old_hp,
			batched_new_hp,
			batched_old_pwr,
			batched_new_pwr
		)

		var ability_id: StringName = context.get("ability_id", &"modify_both_stats")
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": batched_uuids,
			"ability_id": ability_id,
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": payload
		}))

		result.state_applied = true
		return result
	else:
		# Non-simulation: apply stat changes silently
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if not is_instance_valid(inst):
				continue
			battle_manager.apply_stat_delta(inst, "hp", hp_value)
			battle_manager.apply_stat_delta(inst, "pwr", pwr_value)
		var non_sim_result := EffectResult.new()
		non_sim_result.state_applied = true
		return non_sim_result
