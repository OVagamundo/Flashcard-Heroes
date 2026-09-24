# res://scripts/EffectSetHPToGold.gd
@tool
class_name EffectSetHPToGold
extends EffectDefinition

## Sets the source unit's HP equal to the current Gold count.
## Used for the Tier 2 unit "Merchant".

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.new()

	var gold = 0
	if is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold
	
	var current_hp = source.current_hp
	
	# Calculate delta to reach target
	var delta = gold - current_hp
	
	if delta == 0:
		return EffectResult.new()
		
	var action_type := C.ACTION_BUFF if delta > 0 else C.ACTION_DEBUFF
	
	# Apply change via BattleManager
	var hp_result = battle_manager.apply_stat_delta(source, "hp", delta, source_uuid, action_type, false)
	var new_hp: int = current_hp
	if hp_result is Dictionary:
		new_hp = hp_result.get("new_hp", current_hp)
	elif hp_result != null:
		new_hp = int(hp_result)
		
	var result = EffectResult.new()
	
	var base_hp = source.get_definition().base_hp if is_instance_valid(source.get_definition()) else current_hp
	var payload: CombatPayload
	if delta > 0:
		payload = CombatPayload.hp_buff(source_uuid, delta, [current_hp], [new_hp], [base_hp])
	else:
		payload = CombatPayload.hp_debuff(source_uuid, delta, [current_hp], [new_hp])
	
	# Create visual event
	var event = CombatEvent.new(CombatEvent.Type.BUFF if delta > 0 else CombatEvent.Type.DEBUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": context.get("ability_id", ""),
		"action_type": action_type,
		"visual_payload": payload
	})
	
	result.add_event(event)
	result.state_applied = true
	return result
