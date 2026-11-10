# res://scripts/effects/EffectAddNextMinigameTimeOnDeath.gd
@tool
class_name EffectAddNextMinigameTimeOnDeath
extends EffectDefinition

## When knocked out, adds seconds equal to this unit's level (1/2/3s) to the next battle minigame.
## Optionally grants tokens equal to level if add_tokens_equal_to_level is true.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	var level: int = unit.level if is_instance_valid(unit) else (context.source_level if context.source_level > 0 else 1)
	
	if context.is_simulation:
		battle_manager.add_next_minigame_bonus_time(float(level), true)
		var target_bonus: float = battle_manager.get_total_next_minigame_bonus_time()
		result.add_event(CombatEvent.new(CombatEvent.Type.TIMER_BONUS, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_holder_uuid": source_uuid,
			"ability_id": context.ability_id if context.ability_id != &"" else &"ability_nov_pla",
			"amount": level,
			"visual_payload": _make_timer_payload(level, source_uuid, target_bonus)
		}))
	else:
		battle_manager.add_next_minigame_bonus_time(float(level), false)
	
	var add_tokens: bool = parameters.get("add_tokens_equal_to_level", false)
	if add_tokens:
		if context.is_simulation:
			battle_manager._state.add_gacha_tokens(level)
			var target_tokens: int = battle_manager.get_gacha_tokens()
			result.add_event(CombatEvent.new(CombatEvent.Type.TOKEN_GAIN, {
				"source_uuid": source_uuid,
				"target_uuids": [source_uuid],
				"ability_holder_uuid": source_uuid,
				"ability_id": context.ability_id if context.ability_id != &"" else &"ability_fw_nov_ani",
				"amount": level,
				"visual_payload": _make_token_payload(level, source_uuid, target_tokens)
			}))
		else:
			battle_manager.add_gacha_tokens(level)
	
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s adds %d second(s) to the next battle minigame starting time!" % [
			unit.get_definition().id if is_instance_valid(unit) else "Unit",
			level
		]
	}))
	result.state_applied = true
	return result

func _make_timer_payload(amount: int, origin_uuid: String, target_bonus: float = -1.0) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	payload.target_bonus_time = target_bonus
	return payload

func _make_token_payload(amount: int, origin_uuid: String, target_tokens: int = -1) -> CombatPayload:
	var payload := CombatPayload.new()
	payload.amount = amount
	payload.origin_uuid = origin_uuid
	payload.target_token_amount = target_tokens
	return payload
