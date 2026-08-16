# res://scripts/effects/EffectRustyRingPassive.gd
@tool
extends EffectDefinition

## Passive stat scaling effect for Rusty Ring trinket.
## Monitors equipment status for all team units on board changed:
## - Removes buff (-1 HP, -1 PWR) if unit equips any item.
## - Restores buff (+1 HP, +1 PWR) if unit unequips all items.
## - Normalizes stacks and stats from 2 to 1 if two buffed units merge.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation := true # Always true so it generates visual events for animator in management phase
	var all_instances: Dictionary = battle_manager.get_all_instances()
	
	# Resolve the trinket's team
	var trinket_team: String = context.get("team", "")
	if trinket_team.is_empty():
		var trinket_instance = battle_manager.get_instance(source_uuid)
		if is_instance_valid(trinket_instance):
			trinket_team = _get_team_from_container(trinket_instance.location_container_tag)
			
	if trinket_team.is_empty():
		return EffectResult.empty()
		
	var buff_tag := &"rusty_ring_buffed"
	var debuff_tag := &"rusty_ring_debuffed"
	var changed_units := 0
	var total_hp_delta := 0
	var total_pwr_delta := 0
	
	var result := EffectResult.new()

	for uuid in all_instances:
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		
		# Only process UNIT category on the same team
		var definition = inst.get_definition()
		if not is_instance_valid(definition) or definition.category != &"UNIT":
			continue
		if _get_team_from_container(inst.location_container_tag) != trinket_team:
			continue

		# Only process units that have been registered by the active triggers
		if not inst.has_tag(buff_tag):
			continue

		# Check if they have equipment
		var has_equip := false
		for eq_uuid in inst.equipped_item_uuids:
			if not eq_uuid.is_empty():
				has_equip = true
				break
				
		var is_debuffed := inst.has_tag(debuff_tag)
		var delta := 0
		
		if has_equip and not is_debuffed:
			# Just equipped an item -> Apply Debuff
			inst.add_tag(debuff_tag)
			delta = -1
		elif not has_equip and is_debuffed:
			# Just unequipped an item -> Remove Debuff
			inst.remove_tag(debuff_tag)
			delta = 1
			
		if delta != 0:
			var old_hp = inst.current_hp
			var old_pwr = inst.current_pwr
			
			inst.apply_hp_delta(delta, {"silent": is_simulation})
			inst.apply_pwr_delta(delta, {"silent": is_simulation})
			
			if is_simulation:
				var skip_anim = inst.has_meta("skip_initial_scaling_anim")
				
				var multi_payload = CombatPayload.multi_stat_change("", delta, delta, [old_hp], [inst.current_hp], [], [old_pwr], [inst.current_pwr])
				multi_payload.skip_bump = skip_anim
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": "",
					"target_uuids": [uuid],
					"ability_id": context.get("ability_id", &"rusty_ring_passive"),
					"ability_holder_uuid": source_uuid,
					"visual_payload": multi_payload
				}))
			
			changed_units += 1
			total_hp_delta += delta
			total_pwr_delta += delta

	if changed_units == 0:
		return EffectResult.empty()

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Rusty Ring updated %d units (%+d HP, %+d PWR)" % [changed_units, total_hp_delta, total_pwr_delta]
	}))
	result.state_applied = true
	return result



# Helper to determine team from container tag
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
