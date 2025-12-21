# res://scripts/EffectModifyStat.gd
@tool
extends EffectDefinition

## A generic stat modification effect. 
## For Healing Amulet we use { stat: "hp", base_value: 2 }.
## For PWR-based healing we use { stat: "hp", use_source_pwr: true }.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null
	if not parameters is Dictionary:
		return EffectResult.empty() if is_simulation else null
	var stat: String = String(parameters.get("stat", ""))
	if stat == "":
		return EffectResult.empty() if is_simulation else null
	
	# Use centralized stat-scaling utility
	# Supports: base_value, pwr_multiplier, hp_multiplier, use_source_pwr
	var amount: int = StatScaling.calculate(parameters, context, "EffectModifyStat")
	if amount == 0:
		return EffectResult.empty() if is_simulation else null
	
	# During simulation, validate targets and return EffectResult
	if is_simulation:
		# Filter out invalid targets
		var valid_targets: Array[String] = []
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if is_instance_valid(inst):
				valid_targets.append(t)
		if valid_targets.is_empty():
			return EffectResult.empty()
		
		# DAMAGE (negative HP) - use EffectResult with damage_request marker
		# The on_hurt/on_kill trigger logic is handled by CombatSimulator via EffectHandlers
		if stat == "hp" and amount < 0:
			var damage_result := EffectResult.new()
			damage_result.damage_request = {
				"stat": stat,
				"amount": amount,
				"targets": valid_targets
			}
			return damage_result
		
		# HEALS (positive HP) and BUFFS (positive PWR) use new EffectResult path
		var result := EffectResult.new()
		
		for target_uuid in valid_targets:
			var tgt = battle_manager.get_instance_by_uuid(target_uuid)
			if not is_instance_valid(tgt):
				continue
			
			# Capture old stat
			var old_val: int = tgt.current_hp if stat == "hp" else tgt.current_pwr
			var tgt_def = tgt.get_definition()
			var max_hp: int = tgt_def.base_hp if is_instance_valid(tgt_def) else 0
			
			# Apply stat change
			var new_val = battle_manager.apply_stat_delta(tgt, stat, amount)
			
			# Get source name for log
			var source_name: String = ""
			if not _source_uuid.is_empty():
				var src = battle_manager.get_instance_by_uuid(_source_uuid)
				source_name = BattleHelpers.get_instance_display_name(src)
			if source_name == "":
				source_name = String(context.get("ability_id", "effect"))
			
			var target_name: String = BattleHelpers.get_instance_display_name(tgt)
			
			if stat == "hp":
				# HEAL event
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s heals %s for %d HP" % [source_name, target_name, amount]
				}))
				result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
					"source_uuid": _source_uuid,
					"target_uuids": [target_uuid],
					"ability_id": context.get("ability_id", &"modify_stat"),
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": {
						"source_uuid": _source_uuid,
						"amount": amount,
						"stat": stat,
						"skip_bump": false,
						"targets_old_hp": [old_val],
						"targets_new_hp": [new_val],
						"targets_max_hp": [max_hp]
					}
				}))
				result.mark_healed(target_uuid)
			elif stat == "pwr":
				# BUFF event
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s grants %s +%d PWR" % [source_name, target_name, amount]
				}))
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": _source_uuid,
					"target_uuids": [target_uuid],
					"ability_id": context.get("ability_id", &"modify_stat"),
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": {
						"source_uuid": _source_uuid,
						"amount": amount,
						"stat": stat,
						"targets_old_pwr": [old_val],
						"targets_new_pwr": [new_val]
					}
				}))
		
		result.state_applied = true
		return result
	# Non-simulation: apply stat changes immediately
	else:
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if not is_instance_valid(inst):
				continue
			match stat:
				"hp":
					var new_hp = max(0, inst.current_hp + amount)
					inst.set_current_hp(new_hp)
					# NOTE: set_current_hp() emits granular unit_stat_changed signal
				"pwr":
					var old_pwr = inst.current_pwr
					inst.current_pwr = max(0, inst.current_pwr + amount)
					SignalBus.emit_signal("unit_stat_changed", inst.ball_uuid, &"pwr", old_pwr, inst.current_pwr)
				_:
					pass
	# Non-simulation return (legacy compatibility)
	return amount
