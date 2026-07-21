# res://scripts/effects/EffectRustyRingBuff.gd
@tool
extends EffectDefinition

## Effect that buffs all team units with +1 HP, +1 PWR if they have no equipment.
## Used by Rusty Ring trinket on draw, summon, or battle start.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	var all_instances: Dictionary = battle_manager.get_all_instances()
	
	# Resolve the trinket's team
	var trinket_team: String = context.get("team", "")
	if trinket_team.is_empty():
		var trinket_instance = battle_manager.get_instance(_source_uuid)
		if is_instance_valid(trinket_instance):
			trinket_team = _get_team_from_container(trinket_instance.location_container_tag)
			
	if trinket_team.is_empty():
		return EffectResult.empty() if is_simulation else null

	var result := EffectResult.new()
	var state_applied_any := false
	
	var hp_amount := 1
	var pwr_amount := 1
	var buff_tag := &"rusty_ring_buffed"
	var debuff_tag := &"rusty_ring_debuffed"
	
	# Determine target units on the same team
	for target_uuid in all_instances:
		var target_instance: GachaBallInstance = all_instances[target_uuid]
		if not is_instance_valid(target_instance):
			continue
			
		# Team check
		var target_team = _get_team_from_container(target_instance.location_container_tag)
		if target_team != trinket_team:
			continue
			
		# Only process UNIT category
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def) or target_def.category != &"UNIT":
			continue
			
		# Skip if already registered
		if target_instance.has_tag(buff_tag):
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
			
			# Get display names for log
			var trinket_name := "Rusty Ring"
			var trinket_instance = battle_manager.get_instance(_source_uuid)
			if is_instance_valid(trinket_instance):
				var trinket_def = trinket_instance.get_definition()
				if is_instance_valid(trinket_def):
					trinket_name = tr(trinket_def.name_key)
			
			var unit_name := BattleHelpers.get_instance_display_name(target_instance)
			
			# Add log message
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, unit_name, hp_amount, pwr_amount]
			}))
			
			# HP BUFF event
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": [target_uuid],
				"ability_id": context.get("ability_id", &"ability_trinket_rusty_ring"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": _source_uuid,
				"visual_payload": {
					"source_uuid": _source_uuid,
					"amount": hp_amount,
					"stat": "hp",
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp]
				}
			}))
			
			# PWR BUFF event
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": [target_uuid],
				"ability_id": context.get("ability_id", &"ability_trinket_rusty_ring"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": _source_uuid,
				"visual_payload": {
					"source_uuid": _source_uuid,
					"amount": pwr_amount,
					"stat": "pwr",
					"targets_old_pwr": [old_pwr],
					"targets_new_pwr": [new_pwr]
				}
			}))
			state_applied_any = true
		else:
			# Non-simulation: apply immediately
			battle_manager.apply_permanent_stat_delta(target_instance, "hp", hp_amount, _source_uuid)
			battle_manager.apply_permanent_stat_delta(target_instance, "pwr", pwr_amount, _source_uuid)
			state_applied_any = true

	if is_simulation:
		result.state_applied = true
		return result
	else:
		return 1 if state_applied_any else 0

# Helper to determine team from container tag
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
