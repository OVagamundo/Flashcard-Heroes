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
	
	# Mapping: Normalize stat names
	if stat == "hp" or stat == "health" or stat == "current_hp":
		stat = "hp"
	elif stat == "pwr" or stat == "power" or stat == "current_pwr":
		stat = "pwr"
	elif stat == "burn" or stat == "spikes" or stat == "armor":
		stat = stat + "_stacks"
	
	# Use centralized stat-scaling utility
	# Supports: base_value, pwr_multiplier, hp_multiplier, use_source_pwr, context_multiplier_key
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
		# MULTI-TARGET BATCHING: Collect all target data first, then create ONE event
		# This enables simultaneous projectile animations for multi-target abilities
		var result := EffectResult.new()
		
		# Collect data for all targets
		var all_target_uuids: Array[String] = []
		var all_old_vals: Array[int] = []
		var all_new_vals: Array[int] = []
		var all_max_hp: Array[int] = []
		var target_names: Array[String] = []
		
		# Get source name once
		var source_name: String = ""
		# Resolve visual source (items shoot from their holder)
		var visual_source_uuid = _source_uuid
		
		if not _source_uuid.is_empty():
			var src = battle_manager.get_instance_by_uuid(_source_uuid)
			if is_instance_valid(src):
				source_name = BattleHelpers.get_instance_display_name(src)
				# If source is an equipped item, use the holder's UUID for visual origin
				if not src.equipped_on_uuid.is_empty():
					visual_source_uuid = src.equipped_on_uuid
					
		if source_name == "":
			source_name = String(context.get("ability_id", "effect"))
		
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
			
			# Collect data
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
			all_max_hp.append(max_hp)
			target_names.append(BattleHelpers.get_instance_display_name(tgt))
			
			if stat == "hp":
				result.mark_healed(target_uuid, amount)
		
		# Create batched event for all targets at once (enables simultaneous projectiles)
		if not all_target_uuids.is_empty():
			if stat == "hp":
				# Log message with all target names
				var log_text: String
				var custom_fmt: String = parameters.get("log_format", "")
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				elif target_names.size() == 1:
					log_text = "%s heals %s for %d HP" % [source_name, target_names[0], amount]
				else:
					log_text = "%s heals %s for %d HP" % [source_name, " and ".join(target_names), amount]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
				
				var aid: StringName = StringName(parameters.get("ability_id", "modify_stat"))
				if aid == &"modify_stat": aid = context.get("ability_id", &"modify_stat")

				# Single HEAL event with all targets batched
				result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": {
						"source_uuid": visual_source_uuid,
						"amount": amount,
						"stat": stat,
						"skip_bump": parameters.get("skip_bump", false),
						"targets_old_hp": all_old_vals,
						"targets_new_hp": all_new_vals,
						"targets_max_hp": all_max_hp
					}
				}))
			elif stat == "pwr":
				# Log message with all target names
				var log_text: String
				var custom_fmt: String = parameters.get("log_format", "")
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				elif target_names.size() == 1:
					log_text = "%s grants %s +%d PWR" % [source_name, target_names[0], amount]
				else:
					log_text = "%s grants %s +%d PWR" % [source_name, " and ".join(target_names), amount]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
				
				var aid: StringName = StringName(parameters.get("ability_id", "modify_stat"))
				if aid == &"modify_stat": aid = context.get("ability_id", &"modify_stat")

				# Single BUFF event with all targets batched
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": {
						"source_uuid": visual_source_uuid,
						"amount": amount,
						"stat": stat,
						"targets_old_pwr": all_old_vals,
						"targets_new_pwr": all_new_vals
					}
				}))
			else:
				# Generic Stat / Status Effect (e.g. armor_stacks)
				var log_text: String
				var custom_fmt: String = parameters.get("log_format", "")
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				elif target_names.size() == 1:
					log_text = "%s grants %s +%d %s" % [source_name, target_names[0], amount, stat]
				else:
					log_text = "%s grants %s +%d %s" % [source_name, " and ".join(target_names), amount, stat]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
				
				var aid: StringName = StringName(parameters.get("ability_id", "modify_stat"))
				if aid == &"modify_stat": aid = context.get("ability_id", &"modify_stat")

				# STATUS_EFFECT event
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": {
						"source_uuid": visual_source_uuid,
						"amount": amount,
						"stat": stat,
						"targets_old_val": all_old_vals,
						"targets_new_val": all_new_vals,
						"new_val": all_new_vals[0] if not all_new_vals.is_empty() else 0
					}
				}))
		
		result.state_applied = true
		return result
	# Non-simulation: apply stat changes silenty in battle, loudly in shop
	else:
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if not is_instance_valid(inst):
				continue
			battle_manager.apply_stat_delta(inst, stat, amount)
	# Non-simulation return (legacy compatibility)
	return amount
