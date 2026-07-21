# res://scripts/EffectGrantStatsPerEmptySlot.gd
@tool
extends EffectDefinition

## Grants +HP and +PWR to the source unit equal to (Current PWR * Empty Slots in Lineup).
## Triggered on_pre_combat.

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	# Only meaningful in simulation
	if not is_simulation:
		return null
		
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit):
		# If source is dead or invalid, nothing happens
		return EffectResult.empty()
		
	# Determine container (must be in lineup)
	var container_tag = source_unit.location_container_tag
	
	# FIX: Only trigger if the unit is in the lineup (Player or Enemy)
	# This prevents the ability from triggering when the unit is on the bench.
	if container_tag != "PlayerLineup" and container_tag != "EnemyLineup":
		return EffectResult.empty()

	var container = battle_manager.get_container(container_tag)
	if not is_instance_valid(container):
		return EffectResult.empty()
		
	# Count empty slots
	var uuids = container.get_all_uuids()
	var empty_slots_count: int = 0
	for uuid in uuids:
		if uuid.is_empty():
			empty_slots_count += 1
			
	if empty_slots_count <= 0:
		return EffectResult.empty()
		
	var amount_per_slot: int = self.parameters.get("amount", 1)
	var total_amount: int = amount_per_slot * empty_slots_count
	
	if total_amount <= 0:
		return EffectResult.empty()
		
	# Apply Stat Deltas
	var old_hp = source_unit.current_hp
	var old_pwr = source_unit.current_pwr
	var max_hp = source_unit.get_definition().base_hp # Approximate max HP for visualization
	
	var new_hp = battle_manager.apply_stat_delta(source_unit, "hp", total_amount)
	var new_pwr = battle_manager.apply_stat_delta(source_unit, "pwr", total_amount)
	
	var result := EffectResult.new()
	var ability_id = context.get("ability_id", &"grant_stats_per_empty")
	
	# LOG Message
	var log_text = "%s gains +%d HP/PWR (%d empty slots)" % [BattleHelpers.get_instance_display_name(source_unit), total_amount, empty_slots_count]
	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
	
	# Event 1: HP Gain (Heal)
	result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.hp_change(source_uuid, total_amount, [old_hp], [new_hp], [max_hp])
	}))
	result.mark_healed(source_uuid, total_amount)
	
	# Event 2: PWR Gain (Buff)
	result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
		"source_uuid": source_uuid,
		"target_uuids": [source_uuid],
		"ability_id": ability_id,
		"trigger_type": context.get("trigger_type", ""),
		"ability_holder_uuid": source_uuid,
		"visual_payload": CombatPayload.pwr_change(source_uuid, total_amount, [old_pwr], [new_pwr])
	}))
	
	result.state_applied = true
	return result
