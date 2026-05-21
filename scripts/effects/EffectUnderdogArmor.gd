@tool
extends EffectDefinition

## At turn start, if the trinket's team has fewer living lineup units than the enemy,
## grant all living allied lineup units 2 Armor per unit difference.
func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = bool(context.get("is_simulation", false))
	var team: String = String(context.get("team", ""))
	if team.is_empty():
		var source_inst_fallback: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(source_inst_fallback):
			team = "PLAYER" if source_inst_fallback.location_container_tag == &"PlayerTrinkets" else "ENEMY"

	var ally_lineup_tag: StringName = &"PlayerLineup" if team == "PLAYER" else &"EnemyLineup"
	var enemy_lineup_tag: StringName = &"EnemyLineup" if team == "PLAYER" else &"PlayerLineup"

	var ally_count := 0
	for unit in battle_manager.get_instances_in_container(ally_lineup_tag):
		if is_instance_valid(unit) and unit.current_hp > 0:
			ally_count += 1

	var enemy_count := 0
	for unit in battle_manager.get_instances_in_container(enemy_lineup_tag):
		if is_instance_valid(unit) and unit.current_hp > 0:
			enemy_count += 1

	var difference: int = enemy_count - ally_count
	if difference <= 0:
		return EffectResult.empty() if is_simulation else null

	var amount: int = difference * 2
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null

	var source_name := String(context.get("ability_id", "effect"))
	var source_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if is_instance_valid(source_inst):
		var display_name := BattleHelpers.get_instance_display_name(source_inst)
		if not display_name.is_empty():
			source_name = display_name

	var target_names: Array[String] = []
	var targets_old_val: Array[int] = []
	var targets_new_val: Array[int] = []
	var valid_targets: Array[String] = []

	for target_uuid in targets:
		var target_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(target_uuid)
		if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
			continue

		valid_targets.append(target_uuid)
		target_names.append(BattleHelpers.get_instance_display_name(target_inst))
		targets_old_val.append(target_inst.get_status_effect_amount(&"armor"))
		targets_new_val.append(battle_manager.apply_stat_delta(target_inst, "armor_stacks", amount))

	if valid_targets.is_empty():
		return EffectResult.empty() if is_simulation else null

	var result := EffectResult.new()
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s grants %s +%d Armor" % [source_name, " and ".join(target_names), amount]
	}))
	result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
		"source_uuid": source_uuid,
		"target_uuids": valid_targets,
		"ability_id": context.get("ability_id", &"ability_trinket_underdog_emblem"),
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": {
			"source_uuid": source_uuid,
			"amount": amount,
			"stat": "armor_stacks",
			"targets_old_val": targets_old_val,
			"targets_new_val": targets_new_val
		}
	}))
	result.state_applied = true
	return result
