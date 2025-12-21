# res://scripts/EffectGainGold.gd
@tool
extends EffectDefinition

## Effect that grants gold to the player when triggered.
## Primarily used for gold-on-kill abilities.

func execute(_source_uuid: String, _targets: Array[String], _battle_manager: Node, context: Dictionary) -> Variant:
	var amount: int = int(parameters.get("amount", 1))
	var is_simulation: bool = context.get("is_simulation", false)
	
	# During simulation, apply gold and return EffectResult
	if is_simulation:
		# Apply gold during simulation
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.add_gold(amount)
		
		# NEW: Return EffectResult with LOG_MESSAGE event
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Gained %d gold!" % amount
		}))
		result.state_applied = true
		return result
	
	# Non-simulation: actually add gold to RunState
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_gold(amount)
		print("[EffectGainGold] Gained %d gold from kill" % amount)
	
	return amount
