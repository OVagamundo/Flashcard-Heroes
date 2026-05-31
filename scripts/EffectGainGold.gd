# res://scripts/EffectGainGold.gd
@tool
extends EffectDefinition

## Effect that grants gold to the player when triggered.
## Primarily used for gold-on-kill abilities.

func execute(source_uuid: String, targets: Array[String], _battle_manager: Node, context: Dictionary) -> Variant:
	var amount: int = int(parameters.get("amount", 1))
	var is_simulation: bool = context.get("is_simulation", false)
	
	# During simulation, apply gold and return EffectResult
	if is_simulation:
		# Apply gold during simulation silently so UI doesn't pop instantly
		var target_gold_amount = 0
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.add_gold(amount, true)
			target_gold_amount = GameManager.run_state.gold
		
		var result := EffectResult.new()
		# Add log message for history
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Gained %d gold!" % amount
		}))
		
		# If available, use the killed_uuid from context as the origin.
		var origin_uuid = context.get("killed_uuid", source_uuid)
		if origin_uuid == source_uuid and not targets.is_empty():
			origin_uuid = targets[0]
		
		result.add_event(CombatEvent.new(CombatEvent.Type.GOLD_GAIN, {
			"source_uuid": source_uuid,
			"target_uuids": targets,
			"amount": amount,
			"visual_payload": {
				"amount": amount,
				"origin_uuid": origin_uuid,
				"target_gold_amount": target_gold_amount
			}
		}))
		
		result.state_applied = true
		return result
	
	# Non-simulation: actually add gold to RunState (for legacy/direct calls)
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_gold(amount)
	
	return amount
