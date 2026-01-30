# res://scripts/EffectBossDrawDrain.gd
@tool
extends EffectDefinition

## Boss passive effect: Gain HP when player draws from gacha machines.
## Used by Boss 1 (The Awakened Guardian) to grow stronger as player draws units/items.
## Expected parameters:
##   - hp_amount: int (default 1) - HP to gain per draw

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
	
	# Get HP amount from parameters
	var hp_amount: int = int(parameters.get("hp_amount", 1))
	if hp_amount <= 0:
		return EffectResult.empty() if is_simulation else null
	
	if is_simulation:
		var result := EffectResult.new()
		
		# Capture old HP
		var old_hp: int = boss.current_hp
		var boss_def = boss.get_definition()
		var max_hp: int = boss_def.base_hp if is_instance_valid(boss_def) else 0
		
		# Apply HP gain
		var new_hp = battle_manager.apply_stat_delta(boss, "hp", hp_amount)
		
		# Get display names
		var boss_name := BattleHelpers.get_instance_display_name(boss)
		
		# Log message
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "%s drains energy from your draw (+%d HP)" % [boss_name, hp_amount]
		}))
		
		# HEAL event
		result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
			"source_uuid": _source_uuid,
			"target_uuids": [_source_uuid],
			"ability_id": context.get("ability_id", &"ability_boss_1_draw_drain"),
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
		
		result.mark_healed(_source_uuid)
		result.state_applied = true
		return result
	else:
		# Non-simulation: apply immediately
		boss.set_current_hp(boss.current_hp + hp_amount)
		return hp_amount

# Helper to determine team from container
func _get_team_from_container(container: StringName) -> String:
	if container == &"PlayerLineup" or container == &"PlayerBench":
		return "PLAYER"
	elif container == &"EnemyLineup":
		return "ENEMY"
	return ""
