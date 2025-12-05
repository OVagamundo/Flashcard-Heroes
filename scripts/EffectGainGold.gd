# res://scripts/EffectGainGold.gd
@tool
extends EffectDefinition

## Effect that grants gold to the player when triggered.
## Primarily used for gold-on-kill abilities.

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, context: Dictionary) -> Variant:
	var amount: int = int(parameters.get("amount", 1))
	var is_simulation: bool = context.get("is_simulation", false)
	
	# During simulation, just return the effect data without applying it
	if is_simulation:
		return {
			"gold_amount": amount
		}
	
	# Non-simulation: actually add gold to RunState
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_gold(amount)
		print("[EffectGainGold] Gained %d gold from kill" % amount)
	
	return amount
