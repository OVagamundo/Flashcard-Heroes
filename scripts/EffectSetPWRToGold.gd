# res://scripts/EffectSetPWRToGold.gd
@tool
class_name EffectSetPWRToGold
extends EffectDefinition

## Sets the source unit's PWR equal to the current Gold count.
## Used for the Tier 2 unit "Merchant".

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.new()

	var trigger = context.get("trigger_type", "")
	var drawn_uuid = context.get("drawn_uuid", "")
	
	# The on_board_enter trigger handles filtering the target, so we don't need a guard clause here.
	var gold = 0
	if is_instance_valid(GameManager.run_state):
		var multiplier: float = self.parameters.get("multiplier", 1.0)
		gold = maxi(1, int(GameManager.run_state.gold * multiplier))
	
	# Delta-safe scaling logic: calculate the required bonus relative to base stats
	var base_pwr = source.get_definition_base_pwr()
	var required_bonus = max(0, gold - base_pwr)
	
	# Fetch previously applied bonus
	var previous_bonus = source.get_meta("gold_pwr_bonus", 0)
	var delta = required_bonus - previous_bonus
	
	if delta == 0:
		return EffectResult.new()
		
	# Store the new total bonus applied
	source.set_meta("gold_pwr_bonus", required_bonus)
	
	# Apply change via BattleManager
	var pwr_result = battle_manager.apply_stat_delta(source, "pwr", delta)
	var _new_pwr: int = source.current_pwr
	if pwr_result is Dictionary:
		_new_pwr = pwr_result.get("new_pwr", source.current_pwr)
	elif pwr_result != null:
		_new_pwr = int(pwr_result)
	
	var unit_name = BattleHelpers.get_instance_display_name(source)
	
	var result = EffectResult.new()
	# Only log if it's a significant change to prevent spamming logs on every board event
	if abs(delta) >= 1:
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s's investments mature! PWR set to %d (current Gold)" % [unit_name, gold]
		}))
	
	result.state_applied = true
	return result
