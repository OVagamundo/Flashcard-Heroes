# res://scripts/effects/EffectGalebloomPreBattle.gd
@tool
class_name EffectGalebloomPreBattle
extends EffectDefinition

## Pre-Battle, while in the active lineup, spend 1 Token to gain 1 / 2 / 3 Armor for each Current Token held
## and 1 / 2 / 3 Spikes for every 2 Current Tokens held before the spend.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(unit) or unit.current_hp <= 0:
		return EffectResult.empty()

	var container: StringName = unit.location_container_tag
	if container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return EffectResult.empty()

	var tokens: int = battle_manager.get_gacha_tokens()
	if tokens < 1:
		return EffectResult.empty()

	var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
	if not spent:
		return EffectResult.empty()

	var scale: int = unit.level
	var total_armor: int = tokens * scale
	var total_spikes: int = int(tokens / 2) * scale

	if total_armor > 0:
		var old_val: int = unit.get_status_effect_amount(&"armor")
		var new_val: int = battle_manager.apply_stat_delta(unit, "armor_stacks", total_armor)
		var payload := CombatPayload.status_change(source_uuid, total_armor, "armor_stacks", [old_val], [new_val])
		payload.new_val = new_val
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"galebloom_pre_battle",
			"trigger_type": context.trigger_type,
			"visual_payload": payload
		}))

	if total_spikes > 0:
		var old_spikes: int = unit.get_status_effect_amount(&"spikes")
		var new_spikes: int = battle_manager.apply_stat_delta(unit, "spikes_stacks", total_spikes)
		var payload_spikes := CombatPayload.status_change(source_uuid, total_spikes, "spikes_stacks", [old_spikes], [new_spikes])
		payload_spikes.new_val = new_spikes
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_uuid,
			"target_uuids": [source_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"galebloom_pre_battle",
			"trigger_type": context.trigger_type,
			"visual_payload": payload_spikes
		}))

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s spends 1 Token: gains %d Armor and %d Spike(s)!" % [
			BattleHelpers.get_instance_display_name(unit), total_armor, total_spikes
		]
	}))

	result.state_applied = true
	return result
