# res://scripts/effects/EffectMirrorSlotAttack.gd
@tool
extends EffectDefinition

## An effect that deals damage to the enemy in the mirrored slot position.
## If no enemy exists at the mirrored slot, falls back to the backmost enemy.
## Parameters:
##   - damage: { pwr_multiplier: 1.0, base_value: 0 } for stat scaling (optional)

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	# Note: We still need source instance for team detection and slot position
	# This is about game state (position/team), not stats
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return null

	# Determine if source is a player or enemy unit
	var is_player_unit = battle_manager._is_player_unit(source_instance)
	
	# Get source's slot index from its own team's container
	var source_container_tag: StringName
	if is_player_unit:
		source_container_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	else:
		source_container_tag = battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	
	var source_container = battle_manager.get_container(source_container_tag)
	if not is_instance_valid(source_container):
		return null
	
	var source_slot = source_container.get_index_of_uuid(source_uuid)
	if source_slot == -1:
		return null

	# Get enemy lineup container
	var enemy_container_tag: StringName
	if is_player_unit:
		enemy_container_tag = battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	else:
		enemy_container_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var enemy_container = battle_manager.get_container(enemy_container_tag)
	if not is_instance_valid(enemy_container):
		return null
	
	var enemy_uuids = enemy_container.get_all_uuids()
	
	# Try to find enemy at mirrored slot position
	var target_instance: GachaBallInstance = null
	
	# Get source lineup size for mirror calculation
	var source_uuids = source_container.get_all_uuids()
	var source_lineup_size = source_uuids.size()
	
	# TRUE MIRROR: Reflect position across the center line
	# Player slot 0 (back) → Enemy slot (size-1) (back)
	# Player slot (size-1) (front) → Enemy slot 0 (front)
	# Formula: mirror_slot = (source_lineup_size - 1) - source_slot
	var mirror_slot = (source_lineup_size - 1) - source_slot
	
	if mirror_slot >= 0 and mirror_slot < enemy_uuids.size():
		var mirror_uuid = enemy_uuids[mirror_slot]
		if not mirror_uuid.is_empty():
			var potential_target = battle_manager.get_instance_by_uuid(mirror_uuid)
			if is_instance_valid(potential_target) and potential_target.current_hp > 0:
				target_instance = potential_target
	
	# Fallback: target the backmost enemy if mirror slot is empty
	if target_instance == null:
		# Backmost enemy for player attacks = HIGHEST slot index (furthest from player)
		# Backmost enemy for enemy attacks = LOWEST slot index (furthest from enemy)
		if is_player_unit:
			# Find HIGHEST index with living enemy (backmost)
			for slot_index in range(enemy_uuids.size() - 1, -1, -1):
				var uuid = enemy_uuids[slot_index]
				if uuid.is_empty():
					continue
				var unit = battle_manager.get_instance_by_uuid(uuid)
				if is_instance_valid(unit) and unit.current_hp > 0:
					target_instance = unit
					break
		else:
			# Find LOWEST index with living enemy (backmost from enemy perspective)
			for slot_index in range(enemy_uuids.size()):
				var uuid = enemy_uuids[slot_index]
				if uuid.is_empty():
					continue
				var unit = battle_manager.get_instance_by_uuid(uuid)
				if is_instance_valid(unit) and unit.current_hp > 0:
					target_instance = unit
					break
	
	if target_instance == null:
		return null # No valid targets
	
	# Zero-Instance-Query Compliant: Use centralized stat calculator
	var damage = StatScaling.calculate(parameters.get("damage"), _context, "EffectMirrorSlotAttack")
	
	# Trigger on_before_damage for the target (defensive abilities like Defensive Stance)
	var is_simulation: bool = _context.get("is_simulation", false)
	
	# Capture the pending reactions queue size BEFORE triggering on_before_damage
	# This ensures we only process the NEW reactions added by on_before_damage, not unrelated ones
	var reactions_before_trigger: int = battle_manager.get_pending_reactions_size()
	
	var before_attack_context: Dictionary = {
		"source_uuid": target_instance.ball_uuid,
		"defender_uuid": target_instance.ball_uuid,
		"attacker_uuid": source_uuid,
		"target_initial_hp": target_instance.current_hp,
		"is_simulation": is_simulation
	}
	AbilityResolver.process_trigger(&"on_before_damage", before_attack_context)
	
	# Drain ONLY the on_before_damage effects that were just added
	# Pass the queue size from before triggering - only process reactions added after that point
	if is_simulation:
		battle_manager.drain_pending_reactions_inline(reactions_before_trigger)
	
	# Apply damage (non-simulation path)
	if not is_simulation:
		var new_hp = max(0, target_instance.current_hp - damage)
		target_instance.set_current_hp(new_hp)
		SignalBus.battle_inventory_changed.emit()
		SignalBus.unit_stats_changed.emit(target_instance.ball_uuid)
	
	# CRITICAL: Return dictionary with explicit "targets" array
	# If we return just an int, BattleManager uses the original resolved targets
	# which for target_type=SELF would be the source itself!
	return {
		"stat": "hp",
		"amount": - damage,
		"targets": [target_instance.ball_uuid]
	}
