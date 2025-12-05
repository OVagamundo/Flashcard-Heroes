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

	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return null

	var base_damage = _calculate_damage(source_instance)
	var falloff: float = parameters.get("cascade_falloff", 0.5)
	var cascade_depth: int = parameters.get("cascade_depth", 2) # 2 slots behind frontmost
	
	# Get enemy lineup container
	var is_player_unit = battle_manager._is_player_unit(source_instance)
	var container_tag: StringName
	if is_player_unit:
		container_tag = battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
	else:
		container_tag = battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var container = battle_manager.get_container(container_tag)
	if not is_instance_valid(container):
		return null
	
	# Step 1: Find the frontmost LIVING enemy (like basic attack does)
	var frontmost_slot: int = -1
	var all_uuids = container.get_all_uuids()
	for slot_index in range(all_uuids.size()):
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
	# NOTE: We do NOT trigger on_before_attack or on_hurt here.
	# BattleManager handles triggering on_hurt after applying damage from cascade_damage.
	# on_before_attack was already triggered when _enqueue_attack_for was called.
	var damage_data: Array = []
	var current_damage = base_damage
	var damage_index: int = 0 # For skip_bump logic
	
	for offset in range(cascade_depth + 1): # 0, 1, 2 = frontmost + 2 behind
		var target_slot = frontmost_slot + offset
		if target_slot >= all_uuids.size():
			break # Beyond lineup size
		
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


## Calculate base damage using stat-scaling parameters
func _calculate_damage(source_instance: GachaBallInstance) -> int:
	if not parameters.has("damage"):
		return source_instance.current_pwr
	
	var damage_param = parameters["damage"]
	
	if damage_param is int:
		return damage_param
	
	if damage_param is Dictionary:
		var base_value: int = damage_param.get("base_value", 0)
		var pwr_multiplier: float = damage_param.get("pwr_multiplier", 0.0)
		var final_value = base_value + (source_instance.current_pwr * pwr_multiplier)
		return floor(final_value)
	
	return source_instance.current_pwr
