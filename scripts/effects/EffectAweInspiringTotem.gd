# res://scripts/effects/EffectAweInspiringTotem.gd
@tool
extends EffectDefinition

## Effect that triggers at turn start: if there are any tier 3 or level 3 units
## in the lineup, gives +1 HP and +1 PWR to all units in the lineup that are
## lower tier AND lower level (tier < 3 and level < 3), excluding the Hero.
## Used by Awe Inspiring Totem trinket.

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

	var lineup_container: StringName = &"PlayerLineup" if trinket_team == "PLAYER" else &"EnemyLineup"

	# First pass: check if a tier 3 or level 3 unit exists in the lineup
	var has_mentor := false
	for target_uuid in all_instances:
		var target_instance: GachaBallInstance = all_instances[target_uuid]
		if not is_instance_valid(target_instance):
			continue
			
		# Must be in the lineup
		if target_instance.location_container_tag != lineup_container:
			continue
			
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def) or target_def.category != &"UNIT":
			continue
			
		# Check if it's tier 3 or level 3
		if target_def.tier >= 3 or target_def.level >= 3:
			has_mentor = true
			break

	if not has_mentor:
		return EffectResult.empty() if is_simulation else null

	var result := EffectResult.new()
	var state_applied_any := false
	
	var hp_amount := 1
	var pwr_amount := 1
	var status_key := &"awe_inspiring_totem_stacks"
	
	# Second pass: buff lower tier/level units
	for target_uuid in all_instances:
		var target_instance: GachaBallInstance = all_instances[target_uuid]
		if not is_instance_valid(target_instance):
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
			
		# Target must NOT be tier 3 and NOT level 3
		if target_def.tier >= 3 or target_def.level >= 3:
			continue
		
		if is_simulation:
			# Capture old stats for visual events
			var old_hp: int = target_instance.current_hp
			var old_pwr: int = target_instance.current_pwr
			var max_hp: int = target_def.base_hp
			
			# Apply HP buff
			var hp_result = battle_manager.apply_stat_delta(target_instance, "hp", hp_amount)
			var new_hp: int = target_instance.current_hp
			if hp_result is Dictionary:
				new_hp = hp_result.get("new_hp", target_instance.current_hp)
			elif hp_result != null:
				new_hp = int(hp_result)
			
			# Apply PWR buff  
			var pwr_result = battle_manager.apply_stat_delta(target_instance, "pwr", pwr_amount)
			var new_pwr: int = target_instance.current_pwr
			if pwr_result is Dictionary:
				new_pwr = pwr_result.get("new_pwr", target_instance.current_pwr)
			elif pwr_result != null:
				new_pwr = int(pwr_result)
			
			# Increment status stacks silently
			target_instance.add_status_effect_silent(status_key, 1)
			
			# Get display names for log
			var trinket_name := "Awe Inspiring Totem"
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
				"ability_id": context.get("ability_id", &"ability_trinket_awe_inspiring_totem"),
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
				"ability_id": context.get("ability_id", &"ability_trinket_awe_inspiring_totem"),
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
			battle_manager.apply_stat_delta(target_instance, "hp", hp_amount)
			battle_manager.apply_stat_delta(target_instance, "pwr", pwr_amount)
			target_instance.add_status_effect(status_key, 1)
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
