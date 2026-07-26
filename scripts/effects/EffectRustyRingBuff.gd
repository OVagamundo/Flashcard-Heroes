# res://scripts/effects/EffectRustyRingBuff.gd
@tool
extends EffectDefinition

## Effect that buffs all team units with +1 HP, +1 PWR if they have no equipment.
## Used by Rusty Ring trinket on draw, summon, or battle start.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	var all_instances: Dictionary = battle_manager.get_all_instances()
	
	# Resolve the trinket's team
	var trinket_team: String = context.get("team", "")
	if trinket_team.is_empty():
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		if is_instance_valid(trinket_instance):
			trinket_team = _get_team_from_container(trinket_instance.location_container_tag)
			
	if trinket_team.is_empty():
		return EffectResult.empty()

	var result := EffectResult.new()
	var state_applied_any := false
	
	var hp_amount := 1
	var pwr_amount := 1
	var buff_tag := &"rusty_ring_buffed"
	var debuff_tag := &"rusty_ring_debuffed"
	
	# Determine target units on the same team
	var batched_target_uuids: Array[String] = []
	var batched_target_names: Array[String] = []
	var batched_old_hp: Array[int] = []
	var batched_new_hp: Array[int] = []
	var batched_max_hp: Array[int] = []
	var batched_old_pwr: Array[int] = []
	var batched_new_pwr: Array[int] = []

	var lineup_container = &"PlayerLineup" if trinket_team == "PLAYER" else &"EnemyLineup"

	for target_uuid in all_instances:
		var target_instance: GachaBallInstance = all_instances[target_uuid]
		if not is_instance_valid(target_instance) or target_instance.current_hp <= 0:
			continue
			
		# Must be in the lineup
		if target_instance.location_container_tag != lineup_container:
			continue
			
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def) or target_def.category != &"UNIT":
			continue
			
		# Skip the hero
		if target_def.is_hero:
			continue
			
		# Mark as registered
		target_instance.add_tag(buff_tag)
			
		# Check for equipment
		var has_equip := false
		for eq_uuid in target_instance.equipped_item_uuids:
			if not eq_uuid.is_empty():
				has_equip = true
				break
				
		if has_equip:
			# Unit has equipment: it starts in the debuffed state (no stat change needed now)
			target_instance.add_tag(debuff_tag)
			continue
		
		if is_simulation:
			# Capture old stats for visual events
			var old_hp: int = target_instance.current_hp
			var old_pwr: int = target_instance.current_pwr
			var max_hp: int = target_def.base_hp
			
			# Apply HP buff
			var hp_result = battle_manager.apply_permanent_stat_delta(target_instance, "hp", hp_amount, _source_uuid)
			var new_hp: int = target_instance.current_hp
			if hp_result is Dictionary:
				new_hp = hp_result.get("new_hp", target_instance.current_hp)
			elif hp_result != null:
				new_hp = int(hp_result)
			
			# Apply PWR buff  
			var pwr_result = battle_manager.apply_permanent_stat_delta(target_instance, "pwr", pwr_amount, _source_uuid)
			var new_pwr: int = target_instance.current_pwr
			if pwr_result is Dictionary:
				new_pwr = pwr_result.get("new_pwr", target_instance.current_pwr)
			elif pwr_result != null:
				new_pwr = int(pwr_result)
			
			batched_target_uuids.append(target_uuid)
			batched_target_names.append(BattleHelpers.get_instance_display_name(target_instance))
			batched_old_hp.append(old_hp)
			batched_new_hp.append(new_hp)
			batched_max_hp.append(max_hp)
			batched_old_pwr.append(old_pwr)
			batched_new_pwr.append(new_pwr)
			state_applied_any = true
		else:
			# Non-simulation: apply immediately
			battle_manager.apply_permanent_stat_delta(target_instance, "hp", hp_amount, _source_uuid)
			battle_manager.apply_permanent_stat_delta(target_instance, "pwr", pwr_amount, _source_uuid)
			state_applied_any = true

	if is_simulation and not batched_target_uuids.is_empty():
		var trinket_name := "Rusty Ring"
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		if is_instance_valid(trinket_instance):
			var trinket_def = trinket_instance.get_definition()
			if is_instance_valid(trinket_def):
				trinket_name = tr(trinket_def.name_key)

		# Single Log message for all targets
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, " and ".join(batched_target_names), hp_amount, pwr_amount]
		}))
		
		# Batched HP BUFF event (all projectiles launched simultaneously)
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": batched_target_uuids,
			"ability_id": context.get("ability_id", &"ability_trinket_rusty_ring"),
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, batched_old_hp, batched_new_hp, batched_max_hp)
		}))
		
		# Batched PWR BUFF event (all projectiles launched simultaneously)
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": batched_target_uuids,
			"ability_id": context.get("ability_id", &"ability_trinket_rusty_ring"),
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, batched_old_pwr, batched_new_pwr)
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
