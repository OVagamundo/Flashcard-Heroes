# res://scripts/effects/EffectStormshroudHealOnHurt.gd
@tool
class_name EffectStormshroudHealOnHurt
extends EffectDefinition

## When hurt by an attack, spend 1 Token to heal self for 1 / 2 / 3 HP for each Current Token held before the spend.
## Can activate more than once as long as tokens are available.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return EffectResult.empty()

	var tokens: int = battle_manager.get_gacha_tokens()
	if tokens < 1:
		return EffectResult.empty()

	var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
	if not spent:
		return EffectResult.empty()

	var heal_per_token: int = unit.level
	var total_heal: int = tokens * heal_per_token

	if total_heal > 0:
		var old_hp: int = unit.current_hp
		var new_hp: int = battle_manager.apply_stat_delta(unit, "hp", total_heal, source_uuid, C.ACTION_HEAL)
		var u_def: GachaBallDefinition = unit.get_definition()
		var u_max_hp: int = u_def.base_hp if is_instance_valid(u_def) else unit.current_hp
		var payload := CombatPayload.hp_change(source_uuid, total_heal, [old_hp], [new_hp], [u_max_hp])
		payload.new_val = new_hp
		payload.action_type = C.ACTION_HEAL
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s spends 1 Token to heal for %d HP!" % [
				BattleHelpers.get_instance_display_name(unit), total_heal
			]
		}))
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"stormshroud_heal_on_hurt",
			"trigger_type": context.trigger_type,
			"action_type": C.ACTION_HEAL,
			"visual_payload": payload
		}))

	result.state_applied = true
	return result
