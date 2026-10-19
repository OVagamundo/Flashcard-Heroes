# res://scripts/EffectBuffHighLevelUnit.gd
@tool
extends EffectDefinition

## Effect that buffs a selected unit level or tier when it enters the board.
## Expected parameters:
##   - hp_amount: int (default 1) - HP buff amount
##   - pwr_amount: int (default 1) - PWR buff amount
##   - target_level: int (default 2) - Matching unit level when target_tier is unset
##   - target_tier: int (default 0) - Matching unit tier; bypasses the level filter when positive
##   - target_trait: String (default empty) - Matching unit trait; takes precedence over level and tier

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the target unit UUID from context
	# Context key depends on trigger:
	# - on_draw: "drawn_uuid"
	# - on_ally_summon: "summoned_uuid"
	# - on_merge: "merged_uuid"
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
			ctx_uuid = context.get("merged_uuid", "")
		if ctx_uuid.is_empty():
			ctx_uuid = context.get("source_uuid", "")
		if not ctx_uuid.is_empty():
			targets_to_process.append(ctx_uuid)
	
	if targets_to_process.is_empty():
		return EffectResult.empty()
	
	var result := EffectResult.new()
	var state_applied_any := false
	
	# TEAM CHECK: Ensure targets are on same team as trinket owner
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

	var raw_hp = parameters.get("hp_amount", 1)
	var hp_amount: int = int(raw_hp) if raw_hp != null else 1
	
	var raw_pwr = parameters.get("pwr_amount", 1)
	var pwr_amount: int = int(raw_pwr) if raw_pwr != null else 1
	
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
		
		# Get definition to check category and hero status
		var target_def = target_instance.get_definition()
		if not is_instance_valid(target_def):
			continue
		
		# Only buff UNIT category
		if target_def.category != &"UNIT":
			continue
		
		# Heroes do not have levels or tiers and are not affected by this trinket
		if target_def.is_hero:
			continue
		
		var raw_tier = parameters.get("target_tier", 0)
		var target_tier: int = int(raw_tier) if raw_tier != null else 0
		var target_trait := String(parameters.get("target_trait", "")).to_upper()
		var raw_level = parameters.get("target_level", 2)
		var target_level: int = int(raw_level) if raw_level != null else 2
		if not target_trait.is_empty():
			if not battle_manager.has_trait(target_instance, target_trait):
				continue
		elif target_tier > 0:
			if not ("tier" in target_def) or int(target_def.tier) != target_tier:
				continue
		else:
			if target_instance.level != target_level:
				continue
		
		var buff_tag: StringName
		if not target_trait.is_empty():
			buff_tag = StringName("trait_insignia_buffed_%s_%s" % [_source_uuid, target_trait.to_lower()])
		elif target_tier > 0:
			buff_tag = StringName("tier_insignia_buffed_%s_%s" % [_source_uuid, target_tier])
		elif target_level == 2:
			buff_tag = StringName("veteran_insignia_buffed_%s" % _source_uuid)
		else:
			buff_tag = StringName("insignia_buffed_%s_%s" % [_source_uuid, target_level])
		# Check recursion prevention tag
		if target_instance.has_tag(buff_tag):
			continue
		
		# Mark as buffed to prevent recursion
		target_instance.add_tag(buff_tag)
		
		if is_simulation:
			# Capture old stats
			var old_hp: int = target_instance.current_hp
			var old_pwr: int = target_instance.current_pwr
			var max_hp: int = target_def.base_hp
			
			# Apply HP & PWR buff as conditional trinket bonus
			battle_manager.set_conditional_trinket_bonus(target_instance, _source_uuid, hp_amount, pwr_amount, true, true)
			var new_hp: int = target_instance.current_hp
			var new_pwr: int = target_instance.current_pwr
			
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
			battle_manager.set_conditional_trinket_bonus(target_instance, _source_uuid, hp_amount, pwr_amount, true, false)
			state_applied_any = true

	var trinket_name: String = ""
	if is_instance_valid(trinket_instance):
		var trinket_def = trinket_instance.get_definition()
		if is_instance_valid(trinket_def):
			trinket_name = tr(trinket_def.name_key)
	var effect_target_tier := int(parameters.get("target_tier", 0))
	var effect_target_level := int(parameters.get("target_level", 2))
	var effect_target_trait := String(parameters.get("target_trait", "")).to_lower()
	var effect_ability_id: StringName = &"ability_trinket_veteran_insignia"
	if not effect_target_trait.is_empty():
		trinket_name = trinket_name if not trinket_name.is_empty() else "%s Insignia" % effect_target_trait.capitalize()
		effect_ability_id = StringName("ability_%s_insignia_draw" % effect_target_trait)
	elif effect_target_tier > 0:
		trinket_name = trinket_name if not trinket_name.is_empty() else "Tier %d Insignia" % effect_target_tier
		effect_ability_id = StringName("ability_tier%d_insignia_draw" % effect_target_tier)
	elif effect_target_level == 3:
		trinket_name = trinket_name if not trinket_name.is_empty() else "Master Insignia"
		effect_ability_id = &"ability_level3_insignia_draw"
	elif trinket_name.is_empty():
		trinket_name = "Veteran Insignia"

	if is_simulation and not batched_target_uuids.is_empty():
		# Single Log message for all targets
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grants %s +%d HP, +%d PWR" % [trinket_name, " and ".join(batched_target_names), hp_amount, pwr_amount]
		}))
		
		# Unified BUFF event
		if hp_amount > 0 and pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": context.get("ability_id", effect_ability_id),
				"trigger_type": context.get("trigger_type", ""),
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.both_stats_change(
					_source_uuid, hp_amount, pwr_amount,
					batched_old_hp, batched_new_hp,
					batched_old_pwr, batched_new_pwr,
					batched_max_hp
				)
			}))
		elif hp_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": context.get("ability_id", effect_ability_id),
				"trigger_type": context.get("trigger_type", ""),
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.hp_change(_source_uuid, hp_amount, batched_old_hp, batched_new_hp, batched_max_hp)
			}))
		elif pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": batched_target_uuids,
				"ability_id": context.get("ability_id", effect_ability_id),
				"trigger_type": context.get("trigger_type", ""),
				"action_type": C.ACTION_BUFF,
				"ability_holder_uuid": _source_uuid,
				"visual_payload": CombatPayload.pwr_change(_source_uuid, pwr_amount, batched_old_pwr, batched_new_pwr)
			}))

	result.state_applied = state_applied_any
	return result

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup" or container == &"EnemyTrinkets":
		return "ENEMY"
	return ""
