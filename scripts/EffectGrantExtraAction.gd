# res://scripts/EffectGrantExtraAction.gd
@tool
extends EffectDefinition

## Grants the holder an extra action in the current turn.
## Used by the Bloodlust Edge item to allow the unit to act again after a kill (max 1 per turn).
func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty()
	
	# Get the first target (should be the HOLDER)
	var holder_uuid: String = targets[0]
	var holder: GachaBallInstance = battle_manager.get_instance_by_uuid(holder_uuid)
	
	if not is_instance_valid(holder):
		return EffectResult.empty()
	
	# Only grant extra action if the unit is alive
	if holder.current_hp <= 0:
		return EffectResult.empty()
	
	if is_simulation:
		# Check per-turn limit: max 1 extra attack per turn per item and per holder
		var item_key := "bloodlust_extra_action_" + source_uuid if not source_uuid.is_empty() else ""
		var holder_key := "bloodlust_holder_action_" + holder_uuid
		if (not item_key.is_empty() and battle_manager._turn_metadata.get(item_key, false)) or battle_manager._turn_metadata.get(holder_key, false):
			return EffectResult.empty()

		if not item_key.is_empty():
			battle_manager._turn_metadata[item_key] = true
		battle_manager._turn_metadata[holder_key] = true

		# Grant the extra action via BattleManager
		var unit_name = BattleLogger.get_unit_name(holder_uuid)
		BattleLogger.log_extra_action(unit_name)
		# Granting extra action
		battle_manager.grant_extra_action(holder_uuid)
		
		# Return EffectResult with LOG_MESSAGE event
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s triggers Bloodlust!" % unit_name
		}))
		result.state_applied = true # Extra action already granted
		return result
	
	# Non-simulation mode (legacy compatibility)
	return EffectResult.empty()
