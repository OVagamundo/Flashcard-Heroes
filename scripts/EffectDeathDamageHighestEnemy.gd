@tool
class_name EffectDeathDamageHighestEnemy
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Death's Bargain effect: When holder dies, deal damage equal to half of the
## highest HP enemy's HP to that enemy with a kamikaze attack animation.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	
	# Get the knocked out unit's UUID (the item holder who just died)
	var ko_uuid: String = context.knocked_out_uuid
	if ko_uuid.is_empty():
		return result
	
	# Get the dying unit's location for animation source position
	var dying_location: LocationIdentifier = context.knocked_out_location
	
	# Determine team for target resolution
	var dying_team: String = context.knocked_out_team
	
	# Resolve target: highest HP enemy
	var target_ctx := TriggerContext.new()
	target_ctx.team = dying_team
	var target_uuids := TargetResolver.resolve_target(
		source_uuid,
		target_type, # inherited from EffectDefinition
		target_ctx,
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
	
	# Create pre-knockout attack request for CombatSimulator to handle
	result.pre_knockout_attack_request = EffectResult.PreKnockoutAttackRequest.new(
		ko_uuid,
		target_uuid,
		damage,
		C.DamageType.KAMIKAZE,
		target_inst.current_hp
	)
	
	return result
