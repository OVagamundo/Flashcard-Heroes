# res://scripts/effects/EffectSpendGold.gd
@tool
class_name EffectSpendGold
extends EffectDefinition

## Spends Gold via BattleManager.
## Parameters:
## - amount: int - Amount of Gold to spend (default 1)

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	if not is_simulation:
		return EffectResult.empty()

	var amount: int = int(parameters.get("amount", 1))
	var origin_uuid = _source_uuid
	if context.has("source_holder_uuid") and not str(context["source_holder_uuid"]).is_empty():
		origin_uuid = str(context["source_holder_uuid"])
	var spent = battle_manager.spend_gold(amount, origin_uuid)
	if not spent:
		return EffectResult.empty()

	var result := EffectResult.new()
	var src_inst = battle_manager.get_instance_by_uuid(origin_uuid)
	var unit_name = BattleHelpers.get_instance_display_name(src_inst) if is_instance_valid(src_inst) else "Unit"
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s spends %d Gold!" % [unit_name, amount]
	}))
	result.state_applied = true
	return result
