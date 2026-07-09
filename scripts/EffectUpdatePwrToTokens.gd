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
	var multiplier: float = self.parameters.get("multiplier", 1.0)
	var target_pwr = maxi(1, int(current_tokens * multiplier)) # Min PWR 1
	
	var base_pwr = source.get_definition_base_pwr()
	var required_bonus = max(0, target_pwr - base_pwr)
	
	var previous_bonus = source.get_meta("token_pwr_bonus", 0)
	var delta = required_bonus - previous_bonus
	
	if delta == 0:
		return EffectResult.new()
		
	source.set_meta("token_pwr_bonus", required_bonus)
	
	# Apply change via BattleManager for consistency and signals
	var new_pwr = battle_manager.apply_stat_delta(source, "pwr", delta)
	
	# Create visual event
	var event = CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": context.get("ability_id", ""),
		"visual_payload": {
			"stat": "pwr",
			"amount": delta,
			"targets_old_pwr": [source.current_pwr - delta],
			"targets_new_pwr": [new_pwr]
		}
	})
	
	var result = EffectResult.new()
	result.add_event(event)
	result.state_applied = true
	return result
