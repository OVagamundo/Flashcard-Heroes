# res://scripts/effects/EffectGoldenSealScaling.gd
@tool
class_name EffectGoldenSealScaling
extends EffectDefinition

## Dynamically scales the holder's HP and PWR by +1 per full 10 Gold currently held.
## Recalculates whenever Gold is earned or board state updates.

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	var item = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(item):
		return EffectResult.empty()

	var holder_uuid: String = item.equipped_on_uuid
	if holder_uuid.is_empty():
		return EffectResult.empty()

	var holder = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return EffectResult.empty()

	var gold: int = 0
	if is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold

	var target_bonus: int = int(gold / 10)
	var prev_bonus: int = int(item.get_meta("golden_seal_bonus", 0))
	var delta: int = target_bonus - prev_bonus

	if delta == 0:
		return EffectResult.empty()

	item.set_meta("golden_seal_bonus", target_bonus)

	var old_hp: int = holder.current_hp
	var old_pwr: int = holder.current_pwr
	var action_type = C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF

	var new_hp = battle_manager.apply_stat_delta(holder, "hp", delta, source_uuid, action_type)
	var new_pwr = battle_manager.apply_stat_delta(holder, "pwr", delta, source_uuid, action_type)

	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"golden_seal_scaling")
	var holder_name = BattleHelpers.get_instance_display_name(holder)

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "Golden Seal adjusts %s: %+d HP / %+d PWR (%d Gold held)" % [holder_name, delta, delta, gold]
	}))
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [holder_uuid],
		"ability_id": ability_id,
		"visual_payload": CombatPayload.both_stats_change(
			source_uuid, delta, delta,
			[old_hp], [new_hp],
			[old_pwr], [new_pwr]
		)
	}))

	result.state_applied = true
	return result
