# res://scripts/EffectCascadeAOE.gd
@tool
extends EffectDefinition

## An effect that deals cascading damage to the frontmost enemy and adjacent slots behind.
## 1. Finds the frontmost LIVING enemy (like basic attack)
## 2. Hits that enemy's slot
## 3. Hits the slot directly BEHIND it (slot_index + 1)
## 4. Hits the slot behind THAT (slot_index + 2)
## Empty slots are skipped. Damage halves for each subsequent target.
## Parameters:
##   - damage: { pwr_multiplier: 1.0, base_value: 0 } for stat scaling
##   - cascade_falloff: float (default 0.5) - multiplier applied per slot behind
##   - cascade_depth: int (default 2) - how many slots BEHIND the frontmost to check

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	if targets.is_empty():
		return null

	# Zero-Instance-Query Compliant: Use context data for source stats
	var base_damage = _calculate_damage_from_context(_context)
	var falloff: float = parameters.get("cascade_falloff", 0.5)
	var cascade_depth: int = parameters.get("cascade_depth", 2) # 2 slots behind frontmost
	
	# Get enemy lineup container
	# Note: We still need to query source instance for team detection (is_player_unit)
	# This is acceptable since it's about team membership, not stats
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		push_warning("[EffectCascadeAOE] source instance not found for team detection")
		return null
	
	var is_player_unit = battle_manager._is_player_unit(source_instance)
	var container_tag: StringName
	if is_player_unit:
		container_tag = battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	else:
		container_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var container = battle_manager.get_container(container_tag)
	if not is_instance_valid(container):
		return null
	
	# Step 1: Find the frontmost LIVING enemy (respecting attack direction)
	# Player attacks from left to right (finds index 0 first)
	# Enemy attacks from right to left (finds highest index first)
	var frontmost_slot: int = -1
	var all_uuids = container.get_all_uuids()
	
	if is_player_unit:
		# Player attacks: frontmost is lowest index
		for slot_index in range(all_uuids.size()):
			var uuid = all_uuids[slot_index]
			if uuid.is_empty():
				continue
			var unit = battle_manager.get_instance_by_uuid(uuid)
			if is_instance_valid(unit) and unit.current_hp > 0:
				frontmost_slot = slot_index
				break
	else:
		# Enemy attacks: frontmost is HIGHEST index (closest to enemy on right)
		for slot_index in range(all_uuids.size() - 1, -1, -1):
			var uuid = all_uuids[slot_index]
			if uuid.is_empty():
				continue
			var unit = battle_manager.get_instance_by_uuid(uuid)
			if is_instance_valid(unit) and unit.current_hp > 0:
				frontmost_slot = slot_index
				break
	
	if frontmost_slot == -1:
		return null # No living enemies
	
	# Step 2: Calculate damage for frontmost slot + cascade_depth slots behind
	# on_before_attack is triggered for each target in the loop below.
	# on_hurt is triggered by BattleManager after applying damage from cascade_damage.
	var damage_data: Array = []
	var current_damage = base_damage
	var damage_index: int = 0 # For skip_bump logic
	
	# Cascade direction depends on who is attacking:
	# - Player attacks: cascade from frontmost (index 0) toward back (higher indices) = +1
	# - Enemy attacks: cascade from frontmost (highest index) toward back (lower indices) = -1
	var cascade_direction: int = 1 if is_player_unit else -1
	
	for offset in range(cascade_depth + 1): # 0, 1, 2 = frontmost + 2 behind
		var target_slot = frontmost_slot + (offset * cascade_direction)
		if target_slot < 0 or target_slot >= all_uuids.size():
			break # Beyond lineup bounds
		
		if current_damage < 1:
			break
		
		var uuid = container.get_uuid(target_slot)
		if uuid.is_empty():
			# Empty slot - damage still decays, but nothing to hit
			current_damage = current_damage * falloff
			continue
		
		var target = battle_manager.get_instance_by_uuid(uuid)
		if not is_instance_valid(target) or target.current_hp <= 0:
			# Dead unit or invalid - damage still decays
			current_damage = current_damage * falloff
			continue
		
		var damage_amount = int(current_damage)
		
		# Trigger on_before_attack for this target (defensive abilities like Defensive Stance)
		var is_simulation: bool = _context.get("is_simulation", false)
		var before_attack_context: Dictionary = {
			"source_uuid": target.ball_uuid,
			"defender_uuid": target.ball_uuid,
			"attacker_uuid": source_uuid,
			"target_initial_hp": target.current_hp,
			"is_simulation": is_simulation
		}
		AbilityResolver.process_trigger(&"on_before_attack", before_attack_context)
		
		# Drain the on_before_attack reactions immediately (like BasicAttackEffect does)
		if is_simulation:
			battle_manager.drain_pending_reactions_inline(0)
		
		# Add to damage data - BattleManager will handle applying damage and triggering on_hurt
		damage_data.append({
			"target": target.ball_uuid,
			"amount": damage_amount,
			"skip_bump": (damage_index > 0) # Only bump for the first actual hit
		})
		
		damage_index += 1
		current_damage = current_damage * falloff

	if damage_data.is_empty():
		return null

	# Return structured data for BattleManager to process
	var target_uuids: Array[String] = []
	for d in damage_data:
		target_uuids.append(d.target)

	return {
		"stat": "hp",
		"cascade_damage": damage_data,
		"targets": target_uuids
	}


## Calculate base damage using context data (Zero-Instance-Query Compliant)
func _calculate_damage_from_context(context: Dictionary) -> int:
	var source_pwr: int = context.get("source_pwr", 0)
	
	if source_pwr == 0:
		push_warning("[EffectCascadeAOE] source_pwr missing from context, damage will be 0")
	
	if not parameters.has("damage"):
		return source_pwr
	
	var damage_param = parameters["damage"]
	
	if damage_param is int:
		return damage_param
	
	if damage_param is Dictionary:
		var base_value: int = damage_param.get("base_value", 0)
		var pwr_multiplier: float = damage_param.get("pwr_multiplier", 0.0)
		var final_value = base_value + (source_pwr * pwr_multiplier)
		return floor(final_value)
	
	return source_pwr
