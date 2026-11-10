# res://scripts/effects/EffectAddNextMinigameTimeOnKill.gd
@tool
class_name EffectAddNextMinigameTimeOnKill
extends EffectDefinition

## For each enemy unit knocked out by holder in battle, add 1 second to the starting time of the next battle minigame.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	
	var origin_uuid: String = context.source_holder_uuid
	if origin_uuid.is_empty():
		origin_uuid = context.actor_uuid
	if origin_uuid.is_empty() and not targets.is_empty():
		origin_uuid = targets[0]
	if origin_uuid.is_empty():
		origin_uuid = source_uuid
	
	if context.is_simulation:
		battle_manager.add_next_minigame_bonus_time(1.0, true)
		var target_bonus: float = battle_manager.get_total_next_minigame_bonus_time()
		var payload := CombatPayload.new()
		payload.amount = 1
		payload.origin_uuid = origin_uuid
		payload.target_bonus_time = target_bonus
		result.add_event(CombatEvent.new(CombatEvent.Type.TIMER_BONUS, {
			"source_uuid": origin_uuid,
			"target_uuids": [origin_uuid],
			"ability_holder_uuid": origin_uuid,
			"ability_id": context.ability_id if context.ability_id != &"" else &"ability_item_novice_emblem",
			"amount": 1,
			"visual_payload": payload
		}))
	else:
		battle_manager.add_next_minigame_bonus_time(1.0, false)
	
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Novice Emblem adds 1 second to the next battle minigame starting time!"
	}))
	result.state_applied = true
	return result
