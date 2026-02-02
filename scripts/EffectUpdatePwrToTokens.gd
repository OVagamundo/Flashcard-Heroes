# res://scripts/EffectUpdatePwrToTokens.gd
@tool
class_name EffectUpdatePwrToTokens
extends EffectDefinition

## Sets the source unit's PWR equal to the current Gacha Token count.
## Used for the Tier 2 unit "Templar".

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.new()

	var current_tokens = battle_manager.get_gacha_tokens()
	var target_pwr = maxi(1, current_tokens) # Min PWR 1
	var old_pwr = source.current_pwr
	
	# Calculate delta to reach target
	var delta = target_pwr - old_pwr
	
	if delta == 0:
		return EffectResult.new()
		
	# Apply change via BattleManager for consistency and signals
	# Note: We are setting it TO a value, so we calculate the delta.
	var new_pwr = battle_manager.apply_stat_delta(source, "pwr", delta)
	
	# Create visual event
	var event = CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": context.get("ability_id", ""),
		"visual_payload": {
			"stat": "pwr",
			"amount": delta,
			"targets_old_pwr": [old_pwr],
			"targets_new_pwr": [new_pwr]
		}
	})
	
	var result = EffectResult.new()
	result.add_event(event)
	result.state_applied = true
	return result
