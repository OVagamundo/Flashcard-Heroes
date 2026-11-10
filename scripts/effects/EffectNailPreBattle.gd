# res://scripts/effects/EffectNailPreBattle.gd
@tool
class_name EffectNailPreBattle
extends EffectDefinition

## Pre-Battle, while equipped in the active lineup, holder gains 1 / 2 / 3 Spikes for each Current Token held.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var item: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(item) or item.equipped_on_uuid.is_empty():
		return EffectResult.empty()
	
	var holder: GachaBallInstance = battle_manager.get_instance_by_uuid(item.equipped_on_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return EffectResult.empty()
	
	var container: StringName = holder.location_container_tag
	if container != C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and container != C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		return EffectResult.empty()
	
	var tokens: int = battle_manager.get_gacha_tokens()
	var spikes_per_token: int = item.level
	var total_spikes: int = tokens * spikes_per_token
	
	if total_spikes > 0:
		var old_val: int = holder.get_status_effect_amount(&"spikes")
		var new_val: int = battle_manager.apply_stat_delta(holder, "spikes_stacks", total_spikes)
		var payload := CombatPayload.status_change(holder.ball_uuid, total_spikes, "spikes_stacks", [old_val], [new_val])
		payload.new_val = new_val
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s gains %d Spike(s) from Nail!" % [BattleHelpers.get_instance_display_name(holder), total_spikes]
		}))
		result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": holder.ball_uuid,
			"target_uuids": [holder.ball_uuid],
			"ability_id": context.ability_id if context.ability_id != &"" else &"nail_pre_battle",
			"trigger_type": context.trigger_type,
			"visual_payload": payload
		}))
	
	result.state_applied = true
	return result
