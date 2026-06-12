@tool
class_name EffectScald
extends EffectDefinition

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var result := EffectResult.new()
	
	# Only trigger if the unit is in the lineup (Player or Enemy)
	# This prevents the ability from triggering when the unit is on the bench.
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit):
		return result
		
	var container_tag = source_unit.location_container_tag
	if container_tag != &"PlayerLineup" and container_tag != &"EnemyLineup":
		return result
	
	# Get heal amount from context
	var heal_amount: int = context.get("heal_amount", 0)
	if heal_amount <= 0:
		return result
	
	# Apply damage to all targets (usually just FRONT_ENEMY)
	if not targets.is_empty():
		result.damage_request = {
			"stat": "hp",
			"amount": - heal_amount,
			"targets": targets
		}
		
	return result
