@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## Effect: Gains HP equal to half of the dead ally's current combat PWR (min 1).
## Triggers on_ally_death for the Starter Hero.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var fainting_uuid: String = context.get("fainting_ally_uuid", "")
	if fainting_uuid.is_empty() or fainting_uuid == source_uuid:
		return EffectResult.empty()
		
	# Get source unit (the hero)
	var source_unit: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit) or source_unit.current_hp <= 0:
		return EffectResult.empty()
		
	var dead_ally: GachaBallInstance = battle_manager.get_instance_by_uuid(fainting_uuid)
	if not is_instance_valid(dead_ally):
		return EffectResult.empty()
		
	# Query the dying unit's dynamic combat Power at the moment of death
	var current_pwr: int = dead_ally.current_pwr
	if context.has("fainting_ally_pwr"):
		current_pwr = int(context.get("fainting_ally_pwr"))
		
	# Formula: max(1, floor(current_pwr / 2.0))
	var amount: int = maxi(1, int(floor(float(current_pwr) / 2.0)))
	
	var old_hp: int = source_unit.current_hp
	var res = battle_manager.apply_permanent_stat_delta(source_unit, "hp", amount, source_uuid)
	var new_hp: int = old_hp + amount
	if res is Dictionary:
		new_hp = res.get("new_hp", new_hp)
	elif res != null:
		new_hp = int(res)
		
	var result := EffectResult.new()
	var ability_id: StringName = context.get("ability_id", &"hero_starter_ally_death_absorb")
	
	var hero_name = BattleHelpers.get_instance_display_name(source_unit)
	var dead_name = BattleHelpers.get_instance_display_name(dead_ally)
	var log_text = "%s harvests %s's soul (+%d HP)" % [hero_name, dead_name, amount]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", &"on_ally_death"),
		"action_type": C.ACTION_BUFF,
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.hp_buff(source_uuid, amount, [old_hp], [new_hp])
	}))
	
	result.state_applied = true
	return result
