# res://scripts/effects/EffectEchoingOrbScaling.gd
@tool
extends EffectDefinition

## Grants +2 PWR to the holder for every OTHER Echoing Orb in the Battle Pool.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation = context.get("is_simulation", false)
	var all_instances = battle_manager.get_all_instances()
	var copy_count = 0
	
	# Find the Echoing Orb item instance
	var source_item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_item):
		return EffectResult.empty() if is_simulation else null

	for uuid in all_instances:
		if uuid == source_uuid: 
			continue
		var inst = all_instances[uuid]
		if inst.definition_id == &"item_t2_d": 
			copy_count += 1
	
	var bonus_pwr = copy_count * 2
	var status_key = StringName("echoing_orb_scaling_" + source_uuid)
	
	# 1. Update the ITEM's stats so it shows correctly in the UI (bench or equipped)
	var item_last_scaling = source_item.get_status_effect_amount(status_key)
	var item_delta = bonus_pwr - item_last_scaling
	
	if item_delta != 0:
		if item_last_scaling > 0: 
			source_item.clear_status_effect(status_key)
		if bonus_pwr > 0: 
			source_item.add_status_effect_silent(status_key, bonus_pwr)
		source_item.apply_pwr_delta(item_delta, {"silent": is_simulation})

	# 2. Update the HOLDER's stats (and clean up any old holders)
	var active_holder_uuid = source_item.equipped_on_uuid
	var holder_updated = false
	var holder_delta = 0
	
	for uuid in all_instances:
		var inst = all_instances[uuid]
		var inst_last_scaling = inst.get_status_effect_amount(status_key)
		
		# Skip updating the source item itself in this loop (already done above)
		if uuid == source_uuid:
			continue
			
		if uuid == active_holder_uuid:
			# This is the current holder, apply the target scaling
			holder_delta = bonus_pwr - inst_last_scaling
			if holder_delta != 0:
				if inst_last_scaling > 0: 
					inst.clear_status_effect(status_key)
				if bonus_pwr > 0: 
					inst.add_status_effect_silent(status_key, bonus_pwr)
				inst.apply_pwr_delta(holder_delta, {"silent": is_simulation})
				holder_updated = true
		elif inst_last_scaling > 0:
			# This unit is NOT the holder, but has the scaling buff (orphaned)
			inst.clear_status_effect(status_key)
			inst.apply_pwr_delta(-inst_last_scaling, {"silent": is_simulation})
	
	if item_delta == 0 and not holder_updated: 
		return EffectResult.empty() if is_simulation else null

	if is_simulation:
		var result = EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Echoing Orb (%s) scaled by %+d PWR (%d copies)" % [source_uuid, item_delta, copy_count]
		}))
		result.state_applied = true
		return result
		
	return item_delta
