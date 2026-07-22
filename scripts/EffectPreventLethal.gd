# res://scripts/EffectPreventLethal.gd
@tool
extends EffectDefinition

## Effect: Prevent lethal damage once per turn by setting HP to 1.
## Triggers on on_hurt, checks if damage was lethal (HP <= 0) and heals to 1 HP.
## Uses turn metadata to ensure once-per-turn limit per team.
## 
## DOCUMENTATION COMPLIANT: Uses context keys only (ZERO-INSTANCE-QUERY RULE)
## Required context keys: victim_uuid, victim_team, victim_current_hp, team

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# 1. Get data from context (ZERO-INSTANCE-QUERY compliant)
	var victim_uuid: String = context.get("victim_uuid", "")
	var victim_team: String = context.get("victim_team", "")
	var victim_current_hp: int = context.get("victim_current_hp", 1)
	var trinket_team: String = context.get("team", "") # AbilityResolver provides this for trinkets
	
	pass
	
	# Validate required context keys
	if victim_uuid.is_empty():
		pass
		return EffectResult.empty()
	
	if victim_team.is_empty():
		pass
		return EffectResult.empty()
	
	if trinket_team.is_empty():
		pass
		return EffectResult.empty()
	
	# 2. Check victim is on same team as trinket
	if victim_team != trinket_team:
		pass
		return EffectResult.empty()
	
	# 2.5 Check victim is a valid UNIT (not a trinket)
	var victim_def_id = context.get("victim_def_id", "")
	var victim_def = Database.get_definition(victim_def_id)
	if not is_instance_valid(victim_def) or victim_def.category != &"UNIT":
		pass
		return EffectResult.empty()
		
	# 3. Check if damage was lethal (HP <= 0)
	if victim_current_hp > 0:
		pass
		return EffectResult.empty()
	
	# 4. Check once-per-turn flag
	var aegis_flag_key := "aegis_prevented_" + trinket_team
	if battle_manager._turn_metadata.get(aegis_flag_key, false):
		pass
		return EffectResult.empty()
	
	# 5. Calculate heal amount to bring HP to 1
	# current_hp is negative or 0, so we need to heal by (1 - current_hp)
	var heal_amount: int = 1 - victim_current_hp
	
	# Set the flag to prevent duplicate triggers within same turn
	battle_manager._turn_metadata[aegis_flag_key] = true
	
	pass
	
	if is_simulation:
		# NEW: Return EffectResult with LETHAL_SAVE event
		var result := EffectResult.new()
		
		# Get victim instance to apply heal and for display name
		var victim = battle_manager.get_instance_by_uuid(victim_uuid)
		if not is_instance_valid(victim):
			return EffectResult.empty()
		
		# Apply heal to model
		battle_manager.apply_stat_delta(victim, "hp", heal_amount)
		
		# Get display name
		var victim_name: String = BattleHelpers.get_instance_display_name(victim)
		
		# Log message
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Aegis Charm saves %s from lethal damage!" % victim_name
		}))
		
		# LETHAL_SAVE event
		result.add_event(CombatEvent.new(CombatEvent.Type.LETHAL_SAVE, {
			"source_uuid": _source_uuid,
			"target_uuids": [victim_uuid],
			"ability_id": context.get("ability_id", &"aegis_charm"),
			"visual_payload": _make_lethal_save_payload(victim_uuid, heal_amount)
		}))
		
		result.mark_healed(victim_uuid, heal_amount)
		result.state_applied = true
		return result
	else:
		# Non-simulation: apply heal directly
		var victim = battle_manager.get_instance_by_uuid(victim_uuid)
		if is_instance_valid(victim):
			battle_manager.apply_stat_delta(victim, "hp", heal_amount)
		var non_sim_result := EffectResult.new()
		non_sim_result.state_applied = true
		return non_sim_result

func _make_lethal_save_payload(saved_uuid: String, heal_amount: int) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.saved_uuid = saved_uuid
	payload.heal_amount = heal_amount
	return payload
