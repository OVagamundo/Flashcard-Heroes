@tool
class_name EffectStealPower
extends EffectDefinition

## Effect that steals PWR from the target and gives it to the source.
## Used for Soul Siphon (Tier 3 Item F).
## Logic:
## 1. Calculate steal amount = max(1, target.current_pwr / 2)
## 2. Decrease target PWR by amount (min 0)
## 3. Increase source PWR by amount

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	var result := EffectResult.new()
	
	# Determine target (defender) from context
	# on_damage_dealt context: { attacker_uuid, victim_uuid, damage_dealt, ... }
	var target_uuid: String = context.get("victim_uuid", "")
	if target_uuid.is_empty():
		# Fallback: check if targets array has entries (manual targeting)
		if not _targets.is_empty():
			target_uuid = _targets[0]
	
	if target_uuid.is_empty() or source_uuid.is_empty():
		return result
		
	var target_inst = battle_manager.get_instance_by_uuid(target_uuid)
	var source_inst = battle_manager.get_instance_by_uuid(source_uuid)
	
	if not is_instance_valid(target_inst) or not is_instance_valid(source_inst):
		return result
	
	# If source is an item, get the holder (the unit)
	# Item abilities are executed with source_uuid = item_uuid, but the stat buff 
	# should apply to the holder unit
	var holder_inst = source_inst
	var holder_uuid = source_uuid
	if not source_inst.equipped_on_uuid.is_empty():
		holder_uuid = source_inst.equipped_on_uuid
		holder_inst = battle_manager.get_instance_by_uuid(holder_uuid)
		if not is_instance_valid(holder_inst):
			return result
			
	# Check if target is dead (dead units have 0 PWR anyway usually, but good to check)
	# NOTE: on_damage_dealt happens AFTER damage. Target might be dead.
	# Prompt says "this buff happens after the attack". If target died, can we steal?
	# "steals half pwr of that unit". If unit dead, pwr might be irrelevant.
	# Let's assume we can steal from a dying unit (extracting their soul).
	
	var steal_amount: int = max(1, target_inst.current_pwr / 2)
	
	if is_simulation:
		# 1. Apply negative PWR to TARGET
		var target_old_pwr = target_inst.current_pwr
		var target_new_pwr = max(0, target_old_pwr - steal_amount)
		var _actual_lost = target_old_pwr - target_new_pwr
		
		# NOTE: We create visual events manually to show the transfer
		
		# EVENT 1: Target loses PWR (Apply as DAMAGE for visual impact)
		# NOTE: We use DAMAGE type so it triggers shake/bump, but specify 'pwr' stat
		# DamageAnimation will handle the black number and skip HP updates
		result.add_event(CombatEvent.new(CombatEvent.Type.DAMAGE, {
			"source_uuid": holder_uuid,
			"target_uuids": [target_uuid],
			"ability_id": context.get("ability_id", &"steal_power"),
			"visual_payload": {
				"stat": "pwr",
				"amount": - steal_amount,
				"skip_bump": false,
				"targets_old_pwr": [target_old_pwr],
				"targets_new_pwr": [target_new_pwr]
			}
		}))
		
		# 2. Apply positive PWR to SOURCE (HOLDER)
		var source_old_pwr = holder_inst.current_pwr
		var source_new_pwr = source_old_pwr + steal_amount
		
		# EVENT 2: Source gains PWR
		result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
			"source_uuid": holder_uuid,
			"target_uuids": [holder_uuid],
			"ability_id": context.get("ability_id", &"steal_power"),
			"visual_payload": {
				"stat": "pwr",
				"amount": steal_amount,
				"targets_old_pwr": [source_old_pwr],
				"targets_new_pwr": [source_new_pwr]
			}
		}))
		
		# Log message
		var log_text = "%s steals %d PWR from %s" % [
			BattleHelpers.get_instance_display_name(holder_inst),
			steal_amount,
			BattleHelpers.get_instance_display_name(target_inst)
		]
		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
		
		# Mark state applied so CombatSimulator doesn't try to apply default handling
		result.state_applied = true
		
		# Manually apply state changes for simulation consistency if needed?
		# EffectModifyStat sets state_applied = true AND modifies state inside is_simulation block via battle_manager.apply_stat_delta
		# We should do the same to keep simulation state in sync
		battle_manager.apply_stat_delta(target_inst, "pwr", -steal_amount)
		battle_manager.apply_stat_delta(holder_inst, "pwr", steal_amount)
		
	else:
		# Non-simulation: Apply directly
		var old_target = target_inst.current_pwr
		target_inst.current_pwr = max(0, target_inst.current_pwr - steal_amount)
		SignalBus.emit_signal("unit_stat_changed", target_uuid, &"pwr", old_target, target_inst.current_pwr)
		
		var old_source = holder_inst.current_pwr
		holder_inst.current_pwr += steal_amount
		SignalBus.emit_signal("unit_stat_changed", holder_uuid, &"pwr", old_source, holder_inst.current_pwr)
		
	return result
