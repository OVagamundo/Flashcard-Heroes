# res://scripts/EffectDeathTokenRefund.gd
@tool
extends EffectDefinition

## Effect: Returns tokens equivalent to the first dying unit's tier (1 for T1, 2 for T2, 3 for T3).
## Only triggers for the first unit to die that round/turn.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	# Check if this effect has already triggered this turn/round
	if battle_manager._turn_metadata.get("death_token_refund_done", false):
		return EffectResult.empty()

	# Get the dying unit's UUID from the trigger context
	var dying_uuid: String = context.get("dying_uuid", "")
	if dying_uuid.is_empty():
		return EffectResult.empty()

	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(dying_uuid)
	if not is_instance_valid(unit):
		return EffectResult.empty()

	var unit_def = unit.get_definition()
	if not is_instance_valid(unit_def) or unit_def.is_hero:
		return EffectResult.empty()

	var tier: int = int(unit_def.tier)
	if tier <= 0:
		return EffectResult.empty()

	# Mark the effect as completed for this turn
	battle_manager._turn_metadata["death_token_refund_done"] = true

	var is_simulation: bool = context.get("is_simulation", false)

	if is_simulation:
		# Update simulated gacha tokens
		battle_manager._state.add_gacha_tokens(tier)

		var result := EffectResult.new()
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Token Return Charm: Gained %d tokens!" % tier
		}))

		result.add_event(CombatEvent.new(CombatEvent.Type.TOKEN_GAIN, {
			"source_uuid": dying_uuid,
			"target_uuids": [dying_uuid],
			"ability_holder_uuid": _source_uuid,
			"ability_id": "ability_trinket_token_return_charm",
			"amount": tier,
			"visual_payload": _make_token_payload(tier, dying_uuid)
		}))

		result.state_applied = true
		return result

	# Non-simulation (live/direct call fallback): add tokens directly to live state
	battle_manager.add_gacha_token(tier)
	return tier

func _make_token_payload(amount: int, origin_uuid: String) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	return payload
