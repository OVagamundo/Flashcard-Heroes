# res://scripts/EffectUpdatePwrToTokens.gd
@tool
class_name EffectUpdatePwrToTokens
extends EffectDefinition

## Dynamically scales the source unit's PWR based on current Gacha Tokens.
## Updates dynamically whenever the player's token count changes, and when entering the board.
## Applies to both player and enemy Templars, scaling with the player's current token count.
## Preserves outside-battle training upgrades and existing base stats.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source) or source.current_hp <= 0:
		return EffectResult.new()

	var current_tokens: int = battle_manager.get_gacha_tokens()
	var multiplier: float = float(self.parameters.get("multiplier", 1.0))
	var target_bonus: int = int(current_tokens * multiplier)

	var rec_res: AuraEvaluator.ReconcileResult = AuraEvaluator.reconcile_aura(
		source, &"templar_tokens", 0, target_bonus,
		source_uuid, AuraEvaluator.KIND_TEMPLAR_TOKENS,
		{"silent": true, "emit_stat_triggers": true},
		battle_manager
	)
	if not rec_res.changed:
		return EffectResult.new()

	var delta: int = rec_res.delta_pwr
	var action_type: StringName = C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF
	var visual_source_uuid: String = source_uuid
	var payload: CombatPayload = CombatPayload.pwr_buff(visual_source_uuid, delta, [rec_res.old_pwr], [rec_res.new_pwr]) if delta > 0 else CombatPayload.pwr_debuff(visual_source_uuid, delta, [rec_res.old_pwr], [rec_res.new_pwr])

	var event := CombatEvent.new(CombatEvent.Type.BUFF if delta > 0 else CombatEvent.Type.DEBUFF, {
		"source_uuid": visual_source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": (context.ability_id if context.ability_id != &"" else ""),
		"action_type": action_type,
		"ability_holder_uuid": source_uuid,
		"visual_payload": payload
	})

	var result := EffectResult.new()
	result.add_event(event)
	result.state_applied = true
	return result

