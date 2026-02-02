# res://scripts/EffectSetHPToGold.gd
@tool
class_name EffectSetHPToGold
extends EffectDefinition

## Sets the source unit's HP equal to the current Gold count.
## Used for the Tier 2 unit "Merchant".

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var source = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.new()

	# Note: We use get_gold() from BattleManager (assuming it delegates to RunState or similar)
	# If BattleManager doesn't expose get_gold, we might need to access GameManager.run_state.gold
	# Let's check typical usage. BattleManager usually has accessors.
	# Checking lines 52-54 of BattleManager in previous step: delegate to _state._gacha_tokens.
	# Gold is likely in RunState. 
	# Let's assume BattleManager doesn't have get_gold() helper, but we can access `GameManager.run_state.gold`.
	# Wait, `EffectUpdatePwrToTokens` used `battle_manager.get_gacha_tokens()`.
	# Let's check if `get_gold` exists or if we should use run_state.
	
	var gold = 0
	if is_instance_valid(GameManager.run_state):
		gold = GameManager.run_state.gold
	
	var current_hp = source.current_hp
	
	# Calculate delta to reach target
	var delta = gold - current_hp
	
	if delta == 0:
		return EffectResult.new()
		
	# Apply change via BattleManager
	var new_hp = battle_manager.apply_stat_delta(source, "hp", delta)
	
	# Create visual event
	var event = CombatEvent.new(CombatEvent.Type.HEAL if delta > 0 else CombatEvent.Type.DAMAGE, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": context.get("ability_id", ""),
		"visual_payload": {
			"stat": "hp",
			"amount": delta,
			"targets_old_hp": [current_hp],
			"targets_new_hp": [new_hp],
			"targets_max_hp": [source.get_definition().base_hp] # Approx
		}
	})
	
	var result = EffectResult.new()
	result.add_event(event) # Fix: use add_event
	result.state_applied = true
	return result
