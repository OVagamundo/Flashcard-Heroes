# res://scripts/EffectGainGold.gd
@tool
extends EffectDefinition

## Effect that grants gold to the player when triggered.
## Primarily used for gold-on-kill abilities.

func execute(source_uuid: String, targets: Array[String], _battle_manager: Node, context: Dictionary) -> EffectResult:
	var amount: int = int(parameters.get("amount", 1))
	var is_simulation: bool = context.get("is_simulation", false)
	
	# During simulation, apply gold and return EffectResult
	if is_simulation:
		# Resolve origin_uuid for visual animation trajectory:
		# Priority: killed_uuid (e.g. Bounty on_kill) -> dying_uuid (e.g. on_death) -> source_holder_uuid (equipped item) -> targets[0] -> source_uuid
		var origin_uuid: String = context.get("killed_uuid", "")
		if origin_uuid.is_empty():
			origin_uuid = context.get("dying_uuid", "")
		if origin_uuid.is_empty():
			origin_uuid = context.get("source_holder_uuid", "")
		if origin_uuid.is_empty() and not targets.is_empty():
			origin_uuid = targets[0]
		if origin_uuid.is_empty():
			origin_uuid = source_uuid

		if is_instance_valid(_battle_manager) and _battle_manager.has_method("earn_gold"):
			_battle_manager.earn_gold(amount, origin_uuid)
			var result := EffectResult.new()
			result.state_applied = true
			return result

		# Fallback if battle_manager is not provided
		var target_gold_amount = 0
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.add_gold(amount, true)
			target_gold_amount = GameManager.run_state.gold
		
		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Gained %d gold!" % amount
		}))
		result.add_event(CombatEvent.new(CombatEvent.Type.GOLD_GAIN, {
			"source_uuid": source_uuid,
			"target_uuids": targets,
			"amount": amount,
			"visual_payload": _make_gold_payload(amount, origin_uuid, target_gold_amount)
		}))
		
		result.state_applied = true
		return result
	
	# Non-simulation: actually add gold to RunState (for legacy/direct calls)
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.add_gold(amount)
	
	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

func _make_gold_payload(amount: int, origin_uuid: String, target_gold_amount: int) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	payload.target_gold_amount = target_gold_amount
	return payload
