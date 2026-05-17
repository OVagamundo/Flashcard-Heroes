# res://scripts/effects/EffectDopplegangerScaling.gd
@tool
extends EffectDefinition

## Grants +3 PWR for every OTHER Doppleganger in the Battle Pool.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation = context.get("is_simulation", false)
	var all_instances = battle_manager.get_all_instances()
	var copy_count = 0
	
	for uuid in all_instances:
		if uuid == source_uuid: 
			continue
		var inst = all_instances[uuid]
		if inst.definition_id == &"unit_t3_i": 
			copy_count += 1
	
	var bonus_pwr = copy_count * 3
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty() if is_simulation else null
		
	var status_key = &"doppleganger_scaling"
	var last_scaling = source.get_status_effect_amount(status_key)
	var delta = bonus_pwr - last_scaling
	
	if delta == 0: 
		return EffectResult.empty() if is_simulation else null

	# Sync status effect amount silently
	if last_scaling > 0: 
		source.clear_status_effect(status_key)
	if bonus_pwr > 0: 
		source.add_status_effect_silent(status_key, bonus_pwr)
		
	# Apply standard PWR modification (dispatches unit_stat_changed signals to UI)
	source.apply_pwr_delta(delta, {"silent": is_simulation})

	if is_simulation:
		var result = EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Doppleganger scales by %+d PWR (%d copies)" % [delta, copy_count]
		}))
		result.state_applied = true
		return result
		
	return delta
