# res://scripts/EffectDeathTokenRefund.gd
@tool
extends EffectDefinition

## Effect: Returns tokens equivalent to the first dying unit's tier (1 for T1, 2 for T2, 3 for T3).
## Only triggers for the first unit to die that round/turn.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	# Only player team can use or benefit from token refunds
	var trinket_team: String = context.get("team", "PLAYER")
	if trinket_team != "PLAYER":
		return EffectResult.empty()

	# Check if this effect has already triggered this turn/round
	if battle_manager._turn_metadata.get("death_token_refund_done", false):
		return EffectResult.empty()

	# Verify dying unit team is PLAYER
	var dying_team: String = context.get("fainting_ally_team", context.get("dying_team", ""))
	if dying_team != "" and dying_team != "PLAYER":
		return EffectResult.empty()

	# Get the dying unit's UUID from the trigger context (fainting_ally_uuid for on_ally_death, dying_uuid fallback)
	var dying_uuid: String = context.get("fainting_ally_uuid", context.get("dying_uuid", ""))
	if dying_uuid.is_empty():
		return EffectResult.empty()

	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(dying_uuid)
	if not is_instance_valid(unit):
		return EffectResult.empty()

	var unit_def = unit.get_definition()
	if not is_instance_valid(unit_def) or unit_def.is_hero or String(unit_def.id).to_lower() == "hero":
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
		var target_tokens: int = battle_manager.get_gacha_tokens()

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
			"visual_payload": _make_token_payload(tier, dying_uuid, target_tokens)
		}))

		result.state_applied = true
		return result

	# Non-simulation (live/direct call fallback): add tokens directly to live state
	battle_manager.add_gacha_token(tier)
	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

func _make_token_payload(amount: int, origin_uuid: String, target_tokens: int = -1) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	payload.target_token_amount = target_tokens
	return payload
