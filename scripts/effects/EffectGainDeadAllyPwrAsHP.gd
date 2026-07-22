@tool
extends EffectDefinition

## Effect: Gains HP equal to the current PWR of the first ally that dies each turn.
## Only triggers once per turn per team for the first unit to die.
## Resolves targets independently.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Determine team from context - the fainting ally's team is our team
	var fainting_ally_team: String = context.get("fainting_ally_team", "")
	if fainting_ally_team.is_empty():
		return EffectResult.empty()
		
	var is_player_team := (fainting_ally_team == "PLAYER")
	
	# Check if we already harvested a soul for this team this turn
	var harvest_flag_key := "starter_harvest_done_player" if is_player_team else "starter_harvest_done_enemy"
	if battle_manager._turn_metadata.get(harvest_flag_key, false):
		return EffectResult.empty()
		
	# Verify this is actually the first unit killed for the team
	var first_killed_key := "first_killed_player_unit" if is_player_team else "first_killed_enemy_unit"
	var first_killed_data: Dictionary = battle_manager._turn_metadata.get(first_killed_key, {})
	
	if first_killed_data.is_empty():
		return EffectResult.empty()
		
	var fainting_uuid = context.get("fainting_ally_uuid", "")
	if fainting_uuid != first_killed_data.get("uuid", ""):
		return EffectResult.empty()
		
	# Get source unit (the hero)
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit) or source_unit.current_hp <= 0:
		return EffectResult.empty()
		
	# Read the dead ally's PWR from the context's source_pwr (if available via on_death triggering)
	# Wait, on_ally_death doesn't pass source_pwr directly, but it's triggered during the death check.
	# The dead unit is still in the registry with 0 HP, but retaining its current_pwr!
	var dead_ally = battle_manager.get_instance_by_uuid(fainting_uuid)
	if not is_instance_valid(dead_ally):
		return EffectResult.empty()
		
	var amount: int = dead_ally.current_pwr
	if amount <= 0:
		return EffectResult.empty()
		
	if not is_simulation:
		# Mark harvest as done
		battle_manager._turn_metadata[harvest_flag_key] = true
		
	var new_hp = source_unit.current_hp + amount
	if not is_simulation:
		new_hp = battle_manager.apply_permanent_stat_delta(source_unit, "hp", amount, source_uuid)
		
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"hero_starter_ally_death_absorb")
	
	var hero_name = BattleHelpers.get_instance_display_name(source_unit)
	var dead_name = BattleHelpers.get_instance_display_name(dead_ally)
	var log_text = "%s harvests %s's soul (+%d HP)" % [hero_name, dead_name, amount]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.hp_change("", amount, [], [new_hp])
	}))
	
	result.state_applied = true
	return result
