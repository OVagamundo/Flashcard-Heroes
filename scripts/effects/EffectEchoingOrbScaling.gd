# res://scripts/effects/EffectEchoingOrbScaling.gd
@tool
extends EffectDefinition

## Grants +2 PWR to the holder for every OTHER Echoing Orb in the Battle Pool.
func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator
	var all_instances = battle_manager.get_all_instances()
	var copy_count = 0
	
	# Find the Echoing Orb item instance
	var source_item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_item):
		return EffectResult.empty()

	var source_is_player = _is_player_item(source_item, battle_manager)

	for uuid in all_instances:
		var inst = all_instances[uuid]
		if inst.definition_id == &"item_t2_d": 
			if _is_player_item(inst, battle_manager) == source_is_player:
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
			
		if not is_instance_valid(inst) or battle_manager.is_dead_this_turn(uuid):
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
		return EffectResult.empty()

	var result = EffectResult.new()
	if is_simulation:
		# Generate visual event for the holder if they were updated
		if holder_updated and active_holder_uuid != "":
			var holder_inst = all_instances.get(active_holder_uuid)
			if is_instance_valid(holder_inst):
				var skip_anim = holder_inst.has_meta("skip_initial_scaling_anim")
				# Use BUFF for both positive and negative stat changes to avoid attack/damage animations
				var visual_source_uuid = "" # Omit source_uuid to prevent self-projectile
				var payload = CombatPayload.pwr_change(visual_source_uuid, holder_delta, [], [holder_inst.current_pwr])
				payload.skip_bump = skip_anim # Silently update the UI without hopping or flashing
				
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": visual_source_uuid,
					"target_uuids": [active_holder_uuid],
					"ability_id": context.get("ability_id", &"echoing_orb_scaling"),
					"ability_holder_uuid": source_uuid,
					"visual_payload": payload
				}))
				
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Echoing Orb (%s) scaled by %+d PWR (%d copies)" % [source_uuid, item_delta, copy_count]
		}))
	
	result.state_applied = true
	return result

func _is_player_item(inst: GachaBallInstance, battle_manager: Node) -> bool:
	if not is_instance_valid(inst):
		return false
	if not inst.equipped_on_uuid.is_empty():
		var holder = battle_manager.get_instance_by_uuid(inst.equipped_on_uuid)
		if is_instance_valid(holder):
			return battle_manager._is_player_unit(holder) or battle_manager._is_player_owned(holder)
	return battle_manager._is_player_unit(inst) or battle_manager._is_player_owned(inst)
