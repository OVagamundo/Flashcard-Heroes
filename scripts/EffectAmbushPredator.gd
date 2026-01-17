# res://scripts/EffectAmbushPredator.gd
@tool
class_name EffectAmbushPredator
extends EffectDefinition

## Effect that attacks a newly summoned enemy unit for a portion of the source's PWR.
## Used by the Dreadnought unit's "Ambush Predator" ability.
##
## Parameters:
##   - damage_ratio: float - Multiplier for source PWR (default 0.5 = half PWR)
##
## Context expected:
##   - summoned_uuid: String - UUID of the newly summoned unit
##   - source_pwr: int - PWR of the source unit (populated by CombatSimulator)

func execute(_source_uuid: String, _resolved_targets: Array[String], _battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# Get the summoned unit from context
	var summoned_uuid: String = context.get("summoned_uuid", "")
	if summoned_uuid.is_empty():
		return result
	
	# Get damage ratio from parameters (default 0.5 = half PWR)
	var damage_ratio: float = parameters.get("damage_ratio", 0.5)
	
	# Calculate damage: source_pwr comes from context (populated by CombatSimulator)
	var source_pwr: int = context.get("source_pwr", 0)
	var damage_amount: int = int(floor(source_pwr * damage_ratio))
	
	if damage_amount <= 0:
		return result
	
	# Return damage request for CombatSimulator to process
	# This routes through the proper damage pipeline with armor/burn/guardian handling
	result.damage_request = {
		"stat": "hp",
		"amount": - damage_amount,
		"targets": [summoned_uuid]
	}
	
	return result
