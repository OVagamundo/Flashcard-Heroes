# res://scripts/EffectSetPWRToGold.gd
@tool
class_name EffectSetPWRToGold
extends EffectDefinition

## Sets the source unit's PWR equal to the current Gold count.
## Used for the Tier 2 unit "Merchant".

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.new()

	var trigger = context.get("trigger_type", "")
	var drawn_uuid = context.get("drawn_uuid", "")
	
	# Logic check: If this is an 'on_draw' trigger, only proceed if we are the ones being drawn.
	# This prevents enemy/lineup Merchants from scaling every time the player draws (intended for boss_1 only).
	if trigger == "on_draw" and source_uuid != drawn_uuid:
		return EffectResult.new()

	var gold = 0
	if is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold
	
	var current_pwr = source.current_pwr
	
	# Calculate delta to reach target
	var delta = gold - current_pwr
	
	if delta == 0:
		return EffectResult.new()
		
	# Apply change via BattleManager
	# Note: We apply this as bonus_pwr so it's additive to base stats
	var pwr_result = battle_manager.apply_stat_delta(source, "pwr", delta)
	var _new_pwr: int = current_pwr
	if pwr_result is Dictionary:
		_new_pwr = pwr_result.get("new_pwr", current_pwr)
	elif pwr_result != null:
		_new_pwr = int(pwr_result)
	
	# Create visual event - Use LOG_MESSAGE for quiet initialization if it's draw/spawn
	# Or just a BUFF event if we want the visual. User mentioned "taking damage" was weird.
	# We'll use a LOG_MESSAGE to explain the stat jump.
	var unit_name = BattleHelpers.get_instance_display_name(source)
	
	var result = EffectResult.new()
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "%s's investments mature! PWR set to %d (current Gold)" % [unit_name, gold]
	}))
	
	# Still send a BUFF event for the UI to update, but maybe with 0 delta or use state_applied
	# SignalBus will handle the visual if we emit stat_changed.
	
	result.state_applied = true
	return result
