# res://scripts/effects/EffectGainTokensOnDeathByTier.gd
@tool
class_name EffectGainTokensOnDeathByTier
extends EffectDefinition

## When holder is knocked out, gain Tokens equal to holder's Tier (1 / 2 / 3 Tokens).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	
	# Only player team units grant tokens to player wallet
	var dying_team: String = context.knocked_out_team
	if dying_team != "" and dying_team != "PLAYER":
		return EffectResult.empty()
		
	var holder_uuid: String = context.knocked_out_uuid
	if holder_uuid.is_empty():
		var item: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
		if is_instance_valid(item):
			holder_uuid = item.equipped_on_uuid
	
	var holder_tier: int = 1
	if context.knocked_out_tier > 0:
		holder_tier = context.knocked_out_tier
	elif not holder_uuid.is_empty():
		var holder: GachaBallInstance = battle_manager.get_instance_by_uuid(holder_uuid)
		if is_instance_valid(holder):
			var holder_def = holder.get_definition()
			if is_instance_valid(holder_def) and "tier" in holder_def:
				holder_tier = maxi(1, holder_def.tier)
	
	var is_simulation: bool = context.is_simulation
	if is_simulation:
		battle_manager._state.add_gacha_tokens(holder_tier)
		var target_tokens: int = battle_manager.get_gacha_tokens()
		
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Token grants %d Token(s) on holder knockout!" % holder_tier
		}))
		
		result.add_event(CombatEvent.new(CombatEvent.Type.TOKEN_GAIN, {
			"source_uuid": holder_uuid,
			"target_uuids": [holder_uuid],
			"ability_holder_uuid": source_uuid,
			"ability_id": "ability_item_study_pouch",
			"amount": holder_tier,
			"visual_payload": _make_token_payload(holder_tier, holder_uuid, target_tokens)
		}))
	else:
		battle_manager.add_gacha_tokens(holder_tier)
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Token grants %d Token(s) on holder knockout!" % holder_tier
		}))
	
	result.state_applied = true
	return result

func _make_token_payload(amount: int, origin_uuid: String, target_tokens: int = -1) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	payload.target_token_amount = target_tokens
	return payload
