# res://scripts/effects/EffectRootguardPreBattle.gd
@tool
class_name EffectRootguardPreBattle
extends EffectDefinition

## Pre-Battle, gain 1 / 2 / 3 Armor for every 2 Current Tokens held.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return EffectResult.empty()
	
	var tokens: int = battle_manager.get_gacha_tokens()
	var armor_scale: int = unit.level
	var total_armor: int = int(tokens / 2) * armor_scale
	
	if total_armor > 0:
		var old_val: int = unit.get_status_effect_amount(&"armor")
		var new_val: int = battle_manager.apply_stat_delta(unit, "armor_stacks", total_armor)
		var payload := CombatPayload.status_change(source_uuid, total_armor, "armor_stacks", [old_val], [new_val])
		payload.new_val = new_val
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"rootguard_pre_battle",
			"trigger_type": context.trigger_type,
			"visual_payload": payload
		}))
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s gains %d Armor!" % [BattleHelpers.get_instance_display_name(unit), total_armor]
		}))
	
	result.state_applied = true
	return result
