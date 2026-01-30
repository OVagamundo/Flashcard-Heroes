# res://scripts/EffectBossAllyDeathGrowth.gd
@tool
extends EffectDefinition

## Boss 3 passive effect: Gain HP and PWR when an ally dies.
## Used by Boss 3 (The Storm Herald) to grow stronger as its allies fall.
## Expected parameters:
##   - hp_amount: int (default 3) - HP to gain per ally death
##   - pwr_amount: int (default 2) - PWR to gain per ally death

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Get the boss instance (source is the boss itself)
	var boss = battle_manager.get_instance_by_uuid(_source_uuid)
	if not is_instance_valid(boss):
		return EffectResult.empty() if is_simulation else null
	
	# Verify boss is on ENEMY team
	var boss_team := _get_team_from_container(boss.location_container_tag)
	if boss_team != "ENEMY":
		return EffectResult.empty() if is_simulation else null
	
	# Don't trigger if the boss itself died (shouldn't happen, but safety check)
	var fainting_uuid = context.get("fainting_ally_uuid", "")
	if fainting_uuid == _source_uuid:
		return EffectResult.empty() if is_simulation else null
	
	# Get amounts from parameters
	var hp_amount: int = int(parameters.get("hp_amount", 3))
	var pwr_amount: int = int(parameters.get("pwr_amount", 2))
	if hp_amount <= 0 and pwr_amount <= 0:
		return EffectResult.empty() if is_simulation else null
	
	if is_simulation:
		var result := EffectResult.new()
		
		# Capture old stats
		var old_hp: int = boss.current_hp
		var old_pwr: int = boss.current_pwr
		var boss_def = boss.get_definition()
		var max_hp: int = boss_def.base_hp if is_instance_valid(boss_def) else 0
		
		# Apply HP gain
		var new_hp := old_hp
		if hp_amount > 0:
			new_hp = battle_manager.apply_stat_delta(boss, "hp", hp_amount)
		
		# Apply PWR gain
		var new_pwr := old_pwr
		if pwr_amount > 0:
			new_pwr = battle_manager.apply_stat_delta(boss, "pwr", pwr_amount)
		
		# Get display names
		var boss_name := BattleHelpers.get_instance_display_name(boss)
		
		# Log message
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s grows stronger from fallen allies (+%d HP, +%d PWR)" % [boss_name, hp_amount, pwr_amount]
		}))
		
		# HEAL event for HP gain
		if hp_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
				"source_uuid": _source_uuid,
				"target_uuids": [_source_uuid],
				"ability_id": context.get("ability_id", &"ability_boss_3_ally_growth"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": _source_uuid,
				"visual_payload": {
					"source_uuid": _source_uuid,
					"amount": hp_amount,
					"stat": "hp",
					"skip_bump": false,
					"targets_old_hp": [old_hp],
					"targets_new_hp": [new_hp],
					"targets_max_hp": [max_hp]
				}
			}))
		
		# BUFF event for PWR gain
		if pwr_amount > 0:
			result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
				"source_uuid": _source_uuid,
				"target_uuids": [_source_uuid],
				"ability_id": context.get("ability_id", &"ability_boss_3_ally_growth"),
				"trigger_type": context.get("trigger_type", ""),
				"ability_holder_uuid": _source_uuid,
				"visual_payload": {
					"source_uuid": _source_uuid,
					"stat": "pwr",
					"amount": pwr_amount,
					"targets_old_pwr": [old_pwr],
					"targets_new_pwr": [new_pwr]
				}
			}))
		
		result.mark_healed(_source_uuid)
		result.state_applied = true
		return result
	else:
		# Non-simulation: apply immediately
		if hp_amount > 0:
			boss.set_current_hp(boss.current_hp + hp_amount)
		if pwr_amount > 0:
			boss.set_current_pwr(boss.current_pwr + pwr_amount)
		return {"hp": hp_amount, "pwr": pwr_amount}

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup":
		return "ENEMY"
	return ""
