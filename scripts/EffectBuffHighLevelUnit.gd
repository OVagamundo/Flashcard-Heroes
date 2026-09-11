# res://scripts/EffectBuffHighLevelUnit.gd
@tool
extends EffectDefinition

## Effect that buffs the drawn/summoned/merged/battle-started unit if it is level 2 or 3.
## Used by Veteran Insignia trinket to grant +1 HP, +1 PWR to units with level > 1.
## Expected parameters:
##   - hp_amount: int (default 1) - HP buff amount
##   - pwr_amount: int (default 1) - PWR buff amount  

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Determine targets: Use _targets if provided, otherwise infer from context based on trigger
	var targets_to_process: Array[String] = []
	if not _targets.is_empty():
		targets_to_process = _targets.duplicate()
	else:
		var ctx_uuid: String = context.get("drawn_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("summoned_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("merged_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("source_uuid", "")
		if not ctx_uuid.is_empty():
			targets_to_process.append(ctx_uuid)
	
	if targets_to_process.is_empty():
		return EffectResult.empty()
	
	var result := EffectResult.new()
	var state_applied_any := false
	
	# TEAM CHECK: Ensure targets are on the same team as the trinket owner
	var trinket_instance = battle_manager.get_instance(_source_uuid)
	var source_team := ""
	if is_instance_valid(trinket_instance):
		source_team = _get_team_from_container(trinket_instance.location_container_tag)
	
	var batched_target_uuids: Array[String] = []
	var batched_target_names: Array[String] = []
	var batched_old_hp: Array[int] = []
	var batched_new_hp: Array[int] = []
	var batched_max_hp: Array[int] = []
	var batched_old_pwr: Array[int] = []
	var batched_new_pwr: Array[int] = []
	
	for target_uuid in targets_to_process:
		var target_instance = battle_manager.get_instance(target_uuid)
		if not is_instance_valid(target_instance):
			continue
		
		# Team check
		if not source_team.is_empty():
			var target_team = _get_team_from_container(target_instance.location_container_tag)
			if target_team != source_team:
				continue
		
		# Get definition to check category
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def):
			continue
		
		# Only buff UNIT category
		if target_def.category != &"UNIT":
			continue
		
		# Check if Level is > 1 OR Tier is > 1 (i.e., Level 2+ or Tier 2+ units)
		var target_tier = int(target_def.tier) if "tier" in target_def else 1
		if target_instance.level <= 1 and target_tier <= 1:
			continue
		
		# Check recursion prevention tag
		var buff_tag := StringName("veteran_insignia_buffed_%s" % _source_uuid)
		if target_instance.has_tag(buff_tag):
			continue
		
		# Mark as buffed to prevent recursion
		target_instance.add_tag(buff_tag)
		
		# Get buff amounts from parameters
		var raw_hp = parameters.get("hp_amount", 1)
		var hp_amount: int = int(raw_hp) if raw_hp != null else 1
		
		var raw_pwr = parameters.get("pwr_amount", 1)
		var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 1
		
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
			battle_manager.apply_stat_delta(target_instance, "hp", hp_amount)
			battle_manager.apply_stat_delta(target_instance, "pwr", pwr_amount)
			state_applied_any = true

	if is_simulation and not batched_target_uuids.is_empty():
		var trinket_name: String = ""
		if is_instance_valid(trinket_instance):
			var trinket_def = trinket_instance.get_definition()
			if is_instance_valid(trinket_def):
				trinket_name = tr(trinket_def.name_key)
		if trinket_name.is_empty():
			trinket_name = "Veteran Insignia"

		var raw_hp = parameters.get("hp_amount", 1)
		var hp_amount: int = int(raw_hp) if raw_hp != null else 1
		var raw_pwr = parameters.get("pwr_amount", 1)
		var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 1

		# Single Log message for all targets
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, " and ".join(batched_target_names), hp_amount, pwr_amount]
		}))
		
		# Batched HP BUFF event
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": batched_target_uuids,
			"ability_id": &"ability_trinket_veteran_insignia",
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, batched_old_hp, batched_new_hp, batched_max_hp)
		}))
		
		# Batched PWR BUFF event
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": _source_uuid,
			"target_uuids": batched_target_uuids,
			"ability_id": &"ability_trinket_veteran_insignia",
			"trigger_type": context.get("trigger_type", ""),
			"ability_holder_uuid": _source_uuid,
			"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, batched_old_pwr, batched_new_pwr)
		}))

	result.state_applied = true
	return result

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
