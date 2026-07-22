# res://scripts/EffectGrantExtraAction.gd
@tool
extends EffectDefinition

## Grants the holder an extra action in the current turn.
## Used by the Bloodlust Edge item to allow the unit to act again after a kill.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
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
		# Grant the extra action via BattleManager
		var unit_name = BattleLogger.get_unit_name(holder_uuid)
		BattleLogger.log_extra_action(unit_name, "Bloodlust")
		# Granting extra action
		battle_manager.grant_extra_action(holder_uuid)
		
		# NEW: Return EffectResult with LOG_MESSAGE event
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s triggers Bloodlust!" % unit_name
		}))
		result.state_applied = true # Extra action already granted
		return result
	
	# Non-simulation mode (legacy compatibility)
	return EffectResult.empty()