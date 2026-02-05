@tool
class_name EffectScald
extends EffectDefinition

func execute(_source_uuid: String, targets: Array[String], _battle_manager: Node, context: Dictionary) -> Variant:
	var result := EffectResult.new()
	
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
