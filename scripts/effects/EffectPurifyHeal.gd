@tool
extends EffectDefinition

## On hurt by a negative status effect, removes all remaining stacks of that status effect.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	var cause = context.get("trigger_cause", "")
	if cause != "status_effect":
		return EffectResult.empty() if is_simulation else null
		
	var status_id = context.get("status_id", &"")
	if status_id == &"":
		return EffectResult.empty() if is_simulation else null
		
	var def = StatusEffectRegistry.get_definition(status_id)
	if not is_instance_valid(def) or not def.is_negative:
		return EffectResult.empty() if is_simulation else null
	
	# Determine team
	var team: String = String(context.get("team", ""))
	if team.is_empty():
		var source_inst_fallback = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(source_inst_fallback):
			team = "PLAYER" if source_inst_fallback.location_container_tag == &"PlayerTrinkets" else "ENEMY"
			
	var victim_team = context.get("victim_team", "")
	if team != victim_team:
		return EffectResult.empty() if is_simulation else null
		
	var victim_uuid = context.get("victim_uuid", "")
	var victim_inst = battle_manager.get_instance_by_uuid(victim_uuid)
	if not is_instance_valid(victim_inst) or victim_inst.current_hp <= 0:
		return EffectResult.empty() if is_simulation else null
		
	var stacks = victim_inst.get_status_effect_amount(status_id)
	if stacks <= 0:
		return EffectResult.empty() if is_simulation else null
		
	# Apply negative stacks to clear it
	var stat_name = String(status_id) + "_stacks"
	var old_val = stacks
	var new_val = battle_manager.apply_stat_delta(victim_inst, stat_name, -stacks)
	
	if not is_simulation:
		return null
		
	var result = EffectResult.new()
	var source_name := String(context.get("ability_id", "Purifying Pendant"))
	var source_inst = battle_manager.get_instance_by_uuid(source_uuid)
	if is_instance_valid(source_inst):
		var display_name = BattleHelpers.get_instance_display_name(source_inst)
		if not display_name.is_empty():
			source_name = display_name
			
	var victim_name = BattleHelpers.get_instance_display_name(victim_inst)
	var status_name = tr(def.display_name_key) if not def.display_name_key.is_empty() else String(def.id)
			
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s purifies %s, clearing %s!" % [source_name, victim_name, status_name]
	}))
	
	result.add_event(CombatEvent.new(
		CombatEvent.Type.STATUS_EFFECT,
		{
			"target_uuids": [victim_uuid],
			"visual_payload": CombatPayload.status_change(source_uuid, -stacks, stat_name, [old_val], [new_val], def.color)
		}
	))
	
	result.state_applied = true
	return result
