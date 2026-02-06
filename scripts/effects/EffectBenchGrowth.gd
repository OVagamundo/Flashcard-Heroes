@tool
extends EffectDefinition

## Grants +3 HP and +3 PWR if the unit is on the Player Bench.
## Triggered on_turn_start.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Only execute logic in simulation
	if not is_simulation:
		return null
		
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit):
		return EffectResult.empty()
		
	# Check if unit is on the Player Bench
	# location_container_tag is updated by BattleManager during initialization
	if source_unit.location_container_tag != &"PlayerBench":
		return EffectResult.empty()
		
	# Apply Stats
	var hp_amount: int = 3
	var pwr_amount: int = 3
	
	var old_hp = source_unit.current_hp
	var old_pwr = source_unit.current_pwr
	
	var new_hp = battle_manager.apply_stat_delta(source_unit, "hp", hp_amount)
	var new_pwr = battle_manager.apply_stat_delta(source_unit, "pwr", pwr_amount)
	
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"bench_growth")
	
	# LOG Message
	var log_text = "%s meditates on the bench (+%d HP/+%d PWR)" % [BattleHelpers.get_instance_display_name(source_unit), hp_amount, pwr_amount]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	# Event 1: HP Gain (Heal visual)
	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": {
			"source_uuid": source_uuid,
			"amount": hp_amount,
			"stat": "hp",
			"targets_old_hp": [old_hp],
			"targets_new_hp": [new_hp]
		}
	}))
	
	# Event 2: PWR Gain (Buff visual)
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": {
			"source_uuid": source_uuid,
			"amount": pwr_amount,
			"stat": "pwr",
			"targets_old_pwr": [old_pwr],
			"targets_new_pwr": [new_pwr]
		}
	}))
	
	result.state_applied = true
	return result
