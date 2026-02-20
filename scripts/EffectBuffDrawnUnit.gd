# res://scripts/EffectBuffDrawnUnit.gd
@tool
extends EffectDefinition

## Effect that buffs the drawn unit based on tier filtering.
## Used by Royal Insignia trinket to grant +2 HP, +2 PWR to Tier 1 units on draw.
## Expected parameters:
##   - hp_amount: int (default 2) - HP buff amount
##   - pwr_amount: int (default 2) - PWR buff amount  
##   - tier_filter: int (default 1) - Only buff units of this tier (0 = any)

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the target unit UUID from context
	# Context key depends on trigger:
	# - on_draw: "drawn_uuid"
	# - on_ally_summon: "summoned_uuid"
	# - on_battle_start: "source_uuid" (the unit starting battle)
	# Determine targets: Use _targets if provided, otherwise infer from context
	var targets_to_process: Array[String] = []
	if not _targets.is_empty():
		targets_to_process = _targets.duplicate()
	else:
		var ctx_uuid: String = context.get("drawn_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("summoned_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("source_uuid", "")
		if not ctx_uuid.is_empty():
			targets_to_process.append(ctx_uuid)
	
	if targets_to_process.is_empty():
		return EffectResult.empty() if is_simulation else null
	
	var result := EffectResult.new()
	var state_applied_any := false
	
	# TEAM CHECK: Ensure targets are on same team as trinket owner
	var trinket_instance = battle_manager.get_instance(_source_uuid)
	var source_team := ""
	if is_instance_valid(trinket_instance):
		source_team = _get_team_from_container(trinket_instance.location_container_tag)
	
	for target_uuid in targets_to_process:
		# Get the target instance
		var target_instance = battle_manager.get_instance(target_uuid)
		if not is_instance_valid(target_instance):
			continue
		
		# Team check
		if not source_team.is_empty():
			var target_team = _get_team_from_container(target_instance.location_container_tag)
			if target_team != source_team:
				continue
		
		# Get definition to check tier and category
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def):
			continue
		
		# Only buff UNIT category
		if target_def.category != &"UNIT":
			continue
		
		# Check tier filter
		var raw_tier = parameters.get("tier_filter", 1)
		var tier_filter: int = int(raw_tier) if raw_tier != null else 1
		if tier_filter > 0 and target_def.tier != tier_filter:
			continue
		
		# Check recursion prevention tag
		var buff_tag := StringName("royal_insignia_buffed_%s" % _source_uuid)
		if target_instance.has_tag(buff_tag):
			continue
		
		# Mark as buffed to prevent recursion
		target_instance.add_tag(buff_tag)
		
		# Get buff amounts from parameters
		var raw_hp = parameters.get("hp_amount", 2)
		var hp_amount: int = int(raw_hp) if raw_hp != null else 2
		
		var raw_pwr = parameters.get("pwr_amount", 2)
		var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 2
		
		if is_simulation:
			# Capture old stats
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
			
			# Get display names for log
			var trinket_name: String = ""
			if is_instance_valid(trinket_instance):
				var trinket_def = trinket_instance.get_definition()
				if is_instance_valid(trinket_def):
					trinket_name = tr(trinket_def.name_key)
			if trinket_name.is_empty():
				trinket_name = "Royal Insignia"
			
			var unit_name := BattleHelpers.get_instance_display_name(target_instance)
			
			# Log message
			result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
				"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, unit_name, hp_amount, pwr_amount]
			}))
			
			# HP BUFF event
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": [target_uuid], # Single target per event for clarity or batch? Batching is better but payload structure varies.
				"ability_id": &"ability_trinket_royal_insignia",
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
				"ability_id": &"ability_trinket_royal_insignia",
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
			state_applied_any = true

	if is_simulation:
		result.state_applied = true
		return result
	else:
		return 1 if state_applied_any else 0

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
