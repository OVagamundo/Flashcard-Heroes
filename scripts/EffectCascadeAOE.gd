# res://scripts/EffectCascadeAOE.gd
@tool
extends EffectDefinition
const C = preload("res://scripts/Constants.gd")

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

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> EffectResult:
	if targets.is_empty():
		return EffectResult.empty()

	# Zero-Instance-Query Compliant: Use centralized stat calculator
	var base_damage = StatScaling.calculate(parameters.get("damage"), _context, "EffectCascadeAOE")
	var falloff: float = parameters.get("cascade_falloff", 0.5)
	var cascade_depth: int = parameters.get("cascade_depth", 2) # 2 slots behind frontmost
	
	# Get enemy lineup container
	# Note: We still need to query source instance for team detection (is_player_unit)
	# This is acceptable since it's about team membership, not stats
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		push_warning("[EffectCascadeAOE] source instance not found for team detection")
		return EffectResult.empty()
	
	var is_player_unit = battle_manager._is_player_unit(source_instance)
	var container_tag: StringName
	if is_player_unit:
		container_tag = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	else:
		container_tag = C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var container = battle_manager.get_container(container_tag)
	if not is_instance_valid(container):
		return EffectResult.empty()
	
	# Step 1: Start cascade from the resolved target
	var frontmost_slot: int = -1
	var all_uuids = container.get_all_uuids()
	var target_uuid = targets[0]
	
	for slot_index in range(all_uuids.size()):
		if all_uuids[slot_index] == target_uuid:
			frontmost_slot = slot_index
			break
	
	if frontmost_slot == -1:
		return EffectResult.empty() # No living enemies
	
	# Step 2: Calculate damage for frontmost slot + cascade_depth slots behind
	# on_before_damage is triggered for each target in the loop below.
	# on_hurt is triggered by CombatSimulator after applying damage from cascade_request.
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
		
		# Trigger on_before_damage for this target (defensive abilities like Defensive Stance)
		var before_attack_context: Dictionary = {
			"source_uuid": target.ball_uuid,
			"defender_uuid": target.ball_uuid,
			"attacker_uuid": source_uuid,
			"target_initial_hp": target.current_hp,
			"is_simulation": true
		}
		AbilityResolver.process_trigger(&"on_before_damage", before_attack_context)
		
		# Drain the on_before_damage reactions immediately (like BasicAttackEffect does)
		battle_manager.drain_pending_reactions_inline(0)
		
		# Add to damage data - CombatSimulator will handle applying damage and triggering on_hurt
		damage_data.append({
			"target": target.ball_uuid,
			"amount": damage_amount,
			"skip_bump": (damage_index > 0) # Only bump for the first actual hit
		})
		
		damage_index += 1
		current_damage = current_damage * falloff

	if damage_data.is_empty():
		return EffectResult.empty()

	# Return EffectResult with cascade_request for CombatSimulator to process
	var result := EffectResult.new()
	result.cascade_request = damage_data
	return result
