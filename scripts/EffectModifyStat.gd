# res://scripts/EffectModifyStat.gd
@tool
extends EffectDefinition

## A generic stat modification effect. 
## For Healing Amulet we use { stat: "hp", base_value: 2 }.
## For PWR-based healing we use { stat: "hp", use_source_pwr: true }.
func execute(_source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var is_simulation: bool = context.get("is_simulation", false)
	
	if targets.is_empty():
		return EffectResult.empty()
	if not parameters is Dictionary:
		return EffectResult.empty()
	var stat: String = String(parameters.get("stat", ""))
	if stat == "":
		return EffectResult.empty()
	
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
		return EffectResult.empty()
	
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
			var damage_type = parameters.get("damage_type", -1)
			if damage_type == -1:
				var src_inst = battle_manager.get_instance_by_uuid(_source_uuid) if _source_uuid != "" else null
				if is_instance_valid(src_inst) and is_instance_valid(src_inst.get_definition()):
					var src_cat = src_inst.get_definition().category
					if src_cat == &"TRINKET":
						damage_type = C.DamageType.MAGIC
					else:
						# Unit or Item on a Unit
						if self.target_type == C.TARGET_FRONTMOST_ENEMY:
							damage_type = C.DamageType.MELEE
						else:
							damage_type = C.DamageType.RANGED
				else:
					damage_type = C.DamageType.MAGIC
			
			damage_result.damage_request = EffectResult.DamageRequest.new(
				abs(amount),
				damage_type,
				valid_targets,
				false,
				C.CAUSE_ABILITY
			)
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
			
			var tgt_stat = stat
			var tgt_amount = amount
			
			# SPECIAL: PWR->HP Conversion (e.g., Templar)
			# Redirect positive PWR buffs to HP if unit has specific tag
			var tgt_def = tgt.get_definition()
			if stat == "pwr" and amount > 0:
				if tgt.has_tag(&"CONVERT_PWR_TO_HP"):
					tgt_stat = "hp"
					# Amount remains the same (1:1 conversion)
					
					# Process this target individually to ensure correct visuals (HP Heal event instead of PWR Buff)
					var old_hp = tgt.current_hp
					var max_hp = tgt_def.base_hp if is_instance_valid(tgt_def) and "base_hp" in tgt_def else tgt.current_hp
					var new_hp = battle_manager.apply_stat_delta(tgt, "hp", tgt_amount)
					
					# Log message for conversion
					var conv_log = "%s converts PWR buff to +%d HP" % [BattleHelpers.get_instance_display_name(tgt), tgt_amount]
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": conv_log}))
					
					# HEAL Event
					var conversion_payload := CombatPayload.hp_change(visual_source_uuid, tgt_amount, [old_hp], [new_hp], [max_hp])
					result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
						"source_uuid": _source_uuid,
						"target_uuids": [target_uuid],
						"ability_id": context.get("ability_id", &"modify_stat"),
						"trigger_type": context.get("trigger_type", ""),
						"visual_payload": conversion_payload
					}))
					result.mark_healed(target_uuid, tgt_amount)
					continue # Skip adding to batched list
			
			# Capture old stat
			var old_val: int = tgt.current_hp if tgt_stat == "hp" else tgt.current_pwr
			var tgt_max_hp: int = tgt_def.base_hp if is_instance_valid(tgt_def) else 0
			
			# Apply stat change
			var new_val = battle_manager.apply_stat_delta(tgt, tgt_stat, tgt_amount)
			
			# Collect data
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
			all_max_hp.append(tgt_max_hp)
			target_names.append(BattleHelpers.get_instance_display_name(tgt))
			
			if tgt_stat == "hp":
				result.mark_healed(target_uuid, tgt_amount)
		
		# Create batched event for all targets at once (enables simultaneous projectiles)
		if not all_target_uuids.is_empty():
			if stat == "hp":
				var log_text: String
				var custom_fmt: String = parameters.get("log_format", "")
				var aid: StringName = StringName(parameters.get("ability_id", "modify_stat"))
				if aid == &"modify_stat": aid = context.get("ability_id", &"modify_stat")
				
				if amount > 0:
					# HEAL
					if not custom_fmt.is_empty():
						log_text = custom_fmt % [source_name, abs(amount)]
					elif target_names.size() == 1:
						log_text = "%s heals %s for %d HP" % [source_name, target_names[0], amount]
					else:
						log_text = "%s heals %s for %d HP" % [source_name, " and ".join(target_names), amount]
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

					var heal_payload := CombatPayload.hp_change(visual_source_uuid, amount, all_old_vals, all_new_vals, all_max_hp)
					heal_payload.skip_bump = parameters.get("skip_bump", false)
					result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
						"source_uuid": _source_uuid,
						"target_uuids": all_target_uuids,
						"ability_id": aid,
						"trigger_type": context.get("trigger_type", ""),
						"ability_holder_uuid": _source_uuid,
						"visual_payload": heal_payload
					}))
				else:
					# DAMAGE
					if not custom_fmt.is_empty():
						log_text = custom_fmt % [source_name, abs(amount)]
					elif target_names.size() == 1:
						log_text = "%s deals %d damage to %s" % [source_name, abs(amount), target_names[0]]
					else:
						log_text = "%s deals %d damage to %s" % [source_name, abs(amount), " and ".join(target_names)]
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

					var damage_payload := CombatPayload.damage(visual_source_uuid, amount, all_old_vals, all_new_vals)
					damage_payload.stat = stat
					damage_payload.attack_type = parameters.get("attack_type", "ranged")
					damage_payload.skip_bump = parameters.get("skip_bump", true)
					var projectile_data: Dictionary = parameters.get("projectile_data", {"stat": "hp", "amount": abs(amount), "color": "red"})
					damage_payload.projectile = CombatProjectile.new(String(projectile_data.get("stat", "hp")), int(projectile_data.get("amount", abs(amount))), String(projectile_data.get("color", "red")))
					result.add_event(CombatEvent.new(CombatEvent.Type.DAMAGE, {
						"source_uuid": _source_uuid,
						"target_uuids": all_target_uuids,
						"ability_id": aid,
						"trigger_type": context.get("trigger_type", ""),
						"ability_holder_uuid": _source_uuid,
						"visual_payload": damage_payload
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
				var pwr_payload := CombatPayload.pwr_change(visual_source_uuid, amount, all_old_vals, all_new_vals)
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": pwr_payload
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
				var status_payload := CombatPayload.status_change(visual_source_uuid, amount, stat, all_old_vals, all_new_vals)
				status_payload.new_val = all_new_vals[0] if not all_new_vals.is_empty() else 0
				result.add_event(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"ability_holder_uuid": _source_uuid,
					"visual_payload": status_payload
				}))
		
		result.state_applied = true
		return result
	# Non-simulation: apply stat changes silently in battle, loudly in shop
	else:
		for t in targets:
			var inst: GachaBallInstance = battle_manager.get_instance_by_uuid(t)
			if not is_instance_valid(inst):
				continue
			battle_manager.apply_stat_delta(inst, stat, amount)
	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

