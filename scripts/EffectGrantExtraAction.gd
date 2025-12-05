# res://scripts/EffectGrantExtraAction.gd
@tool
extends EffectDefinition

## Grants the holder an extra action in the current turn.
## Used by the Bloodlust Edge item to allow the unit to act again after a kill.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	if targets.is_empty():
		return null
	
	# Get the first target (should be the HOLDER)
	var holder_uuid: String = targets[0]
	var holder: GachaBallInstance = battle_manager.get_instance_by_uuid(holder_uuid)
	
	if not is_instance_valid(holder):
		return null
	
	# Only grant extra action if the unit is alive
	if holder.current_hp <= 0:
		return null
	
	var is_simulation: bool = context.get("is_simulation", false)
	
	if is_simulation:
		# Grant the extra action via BattleManager
		print("[Bloodlust] Granting extra action to: ", holder_uuid)
		battle_manager.grant_extra_action(holder_uuid)
		
		# Return structured data for event generation
		return {
			"extra_action": true,
			"unit_uuid": holder_uuid
		}
	
	# Non-simulation mode (legacy compatibility)
	return null
