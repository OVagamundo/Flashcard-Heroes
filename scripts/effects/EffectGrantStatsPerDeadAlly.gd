@tool
extends EffectDefinition

## Grants +PWR and +HP to the source unit for each ally that died this combat.
## User requested for Storm Herald: "+1 HP and +1 PWR per dead ally".

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return null
		
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit):
		return EffectResult.empty()
		
	var is_player = battle_manager._is_player_unit(source_unit)
	
	# Get dead allies count from BattleState (accumulated over combat)
	# Assuming state has 'dead_allies_history' or similar. 
	# If not, we check total deaths registered this turn as a fallback or check the discard pile.
	var dead_allies_count: int = 0
	
	# Logic: Count units of the same team that are in the Discard Pile and were from this combat.
	# Or, if BattleManager tracks this, use that.
	# For simplicity, we count units of same team in Discard Pile.
	var discard_pile = battle_manager.get_container(&"DiscardPile")
	if is_instance_valid(discard_pile):
		for uuid in discard_pile.get_all_uuids():
			if uuid.is_empty(): continue
			var unit = battle_manager.get_instance_by_uuid(uuid)
			if is_instance_valid(unit) and battle_manager._is_player_unit(unit) == is_player:
				# Only count if it's a UNIT (not item)
				if unit.get_definition().category == &"UNIT" and not unit.get_definition().is_hero:
					dead_allies_count += 1
	
	if dead_allies_count <= 0:
		return EffectResult.empty()
		
	var amount: int = dead_allies_count # +1/+1 per dead ally
	
	var _old_hp = source_unit.current_hp
	var _old_pwr = source_unit.current_pwr
	
	var new_hp = battle_manager.apply_permanent_stat_delta(source_unit, "hp", amount, source_uuid)
	var new_pwr = battle_manager.apply_permanent_stat_delta(source_unit, "pwr", amount, source_uuid)
	
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"storm_herald_scaling")
	
	var log_text = "%s's power rises with the fallen (+%d HP/+%d PWR)" % [BattleHelpers.get_instance_display_name(source_unit), amount, amount]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"visual_payload": {
			"stat": "both",
			"amount": amount,
			"new_hp": new_hp,
			"new_pwr": new_pwr
		}
	}))
	
	result.state_applied = true
	return result
