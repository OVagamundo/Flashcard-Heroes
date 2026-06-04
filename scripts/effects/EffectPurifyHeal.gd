@tool
extends EffectDefinition

## At turn start, heals units with negative status effects for 1 HP.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	var team: String = String(context.get("team", ""))
	if team.is_empty():
		var source_inst_fallback = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(source_inst_fallback):
			team = "PLAYER" if source_inst_fallback.location_container_tag == &"PlayerTrinkets" else "ENEMY"
	
	var lineup_tag: StringName = &"PlayerLineup" if team == "PLAYER" else &"EnemyLineup"
	
	var valid_targets: Array[String] = []
	var target_names: Array[String] = []
	var targets_old_hp: Array[int] = []
	var targets_new_hp: Array[int] = []
	
	var source_name := String(context.get("ability_id", "Purifying Pendant"))
	var source_inst = battle_manager.get_instance_by_uuid(source_uuid)
	if is_instance_valid(source_inst):
		var display_name = BattleHelpers.get_instance_display_name(source_inst)
		if not display_name.is_empty():
			source_name = display_name
	
	for unit in battle_manager.get_instances_in_container(lineup_tag):
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
			
		var has_negative = false
		for effect_id in unit.status_effects.keys():
			if unit.status_effects[effect_id] > 0:
				var def = StatusEffectRegistry.get_definition(effect_id)
				if is_instance_valid(def) and def.is_negative:
					has_negative = true
					break
		
		if has_negative:
			var old_hp = unit.current_hp
			var hp_res = battle_manager.apply_stat_delta(unit, "hp", 1)
			var new_hp = old_hp + 1
			if hp_res is Dictionary:
				new_hp = hp_res.get("new_hp", old_hp + 1)
			elif hp_res != null:
				new_hp = int(hp_res)
				
			valid_targets.append(unit.ball_uuid)
			target_names.append(BattleHelpers.get_instance_display_name(unit))
			targets_old_hp.append(old_hp)
			targets_new_hp.append(new_hp)
	
	if valid_targets.is_empty():
		return EffectResult.empty() if is_simulation else null
		
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"ability_trinket_purifying_pendant")
	
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s purifies %s (+1 HP)" % [source_name, " and ".join(target_names)]
	}))
	
	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": valid_targets,
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": {
			"source_uuid": source_uuid,
			"amount": 1,
			"stat": "hp",
			"targets_old_hp": targets_old_hp,
			"targets_new_hp": targets_new_hp
		}
	}))
	
	result.state_applied = true
	return result
