@tool
extends EffectDefinition

## Deals 1 damage to a unit due to Static discharge.
## Triggered when a unit with Static suffers a stat change.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Only execute logic in simulation
	if not is_simulation:
		return null
		
	if targets.is_empty():
		return EffectResult.empty()
		
	var target_uuid = targets[0]
	var target_unit = battle_manager.get_instance_by_uuid(target_uuid)
	if not is_instance_valid(target_unit) or target_unit.current_hp <= 0:
		return EffectResult.empty()
		
	# Deal 1 damage bypassing armor
	var old_hp = target_unit.current_hp
	var old_armor = target_unit.get_status_effect_amount(&"armor")
	
	# Set re-entrancy guard in battle_manager to avoid infinite loops
	battle_manager._is_applying_static_damage = true
	var hp_res = battle_manager.apply_damage(target_unit, 1, C.DamageType.RANGED, source_uuid)
	battle_manager._is_applying_static_damage = false
	
	var new_hp = target_unit.current_hp
	var armor_consumed = 0
	var new_armor = old_armor
	
	if hp_res is Dictionary:
		new_hp = hp_res.get("new_hp", target_unit.current_hp)
		armor_consumed = hp_res.get("armor_consumed", 0)
		new_armor = hp_res.get("new_armor", old_armor)
	
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"static_discharge")
	
	# Event 1: LOG_MESSAGE (Text log)
	var target_name = BattleHelpers.get_instance_display_name(target_unit)
	var log_text = "%s suffers static discharge (1 damage)" % [target_name]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	# Event 2: DAMAGE (Visual pop-up)
	result.add_event(CombatEvent.new(CombatEvent.Type.DAMAGE, {
		"source_uuid": source_uuid,
		"target_uuids": [target_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.damage(source_uuid, 1, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
	}))
	
	result.state_applied = true
	return result
