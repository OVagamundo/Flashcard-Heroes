@tool
class_name EffectDeathDamageHighestEnemy
extends EffectDefinition

## Death's Bargain effect: When holder dies, deal damage equal to half of the
## highest HP enemy's HP to that enemy with a kamikaze attack animation.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# Get the dying unit's UUID (the item holder who just died)
	var dying_uuid: String = context.get("dying_uuid", "")
	if dying_uuid.is_empty():
		return result
	
	# Get the dying unit's location for animation source position
	var dying_location = context.get("dying_location", null)
	
	# Determine team for target resolution
	var dying_team: String = context.get("dying_team", "")
	
	# Resolve target: highest HP enemy
	var target_uuids := TargetResolver.resolve_target(
		source_uuid,
		target_type, # inherited from EffectDefinition
		{"team": dying_team},
		battle_manager
	)
	
	if target_uuids.is_empty():
		return result
	
	var target_uuid: String = target_uuids[0]
	var target_inst = battle_manager.get_instance_by_uuid(target_uuid)
	
	if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
		return result
	
	# Calculate damage: half of target's current HP (rounded down)
	var damage: int = target_inst.current_hp / 2
	
	if damage <= 0:
		return result
	
	# Create kamikaze request for CombatSimulator to handle
	result.kamikaze_request = {
		"source_uuid": dying_uuid, # The dying unit is the source of the kamikaze
		"target_uuid": target_uuid,
		"damage": damage,
		"dying_location": dying_location
	}
	
	return result
