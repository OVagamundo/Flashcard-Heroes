# res://scripts/EffectUpdatePwrToTokens.gd
@tool
class_name EffectUpdatePwrToTokens
extends EffectDefinition

## Dynamically scales the source unit's PWR based on current Gacha Tokens.
## Updates dynamically whenever the player's token count changes, and when entering the board.
## Applies to both player and enemy Templars, scaling with the player's current token count.
## Preserves outside-battle training upgrades and existing base stats.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.new()

	var current_tokens: int = battle_manager.get_gacha_tokens()
	var multiplier: float = self.parameters.get("multiplier", 1.0)
	var target_bonus: int = int(current_tokens * multiplier)
	var previous_bonus: int = source.get_meta("token_pwr_bonus", 0)
	var delta: int = target_bonus - previous_bonus

	if delta == 0:
		return EffectResult.new()

	# Update tracked bonus metadata
	source.set_meta("token_pwr_bonus", target_bonus)

	# Update status effect for UI/inspection
	var status_key: StringName = &"templar_token_pwr"
	if previous_bonus > 0:
		source.clear_status_effect(status_key)
	if target_bonus > 0:
		source.add_status_effect_silent(status_key, target_bonus)

	var old_pwr: int = source.current_pwr
	var action_type := C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF
	var new_pwr: int = battle_manager.apply_stat_delta(source, "pwr", delta, source_uuid, action_type, false)

	var visual_source_uuid := source_uuid
	var payload := CombatPayload.pwr_buff(visual_source_uuid, delta, [old_pwr], [new_pwr]) if delta > 0 else CombatPayload.pwr_debuff(visual_source_uuid, delta, [old_pwr], [new_pwr])

	var event := CombatEvent.new(CombatEvent.Type.BUFF if delta > 0 else CombatEvent.Type.DEBUFF, {
		"source_uuid": visual_source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": context.get("ability_id", ""),
		"action_type": action_type,
		"ability_holder_uuid": source_uuid,
		"visual_payload": payload
	})

	var result := EffectResult.new()
	result.add_event(event)
	result.state_applied = true
	return result

