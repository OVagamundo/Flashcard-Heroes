# res://scripts/EffectModifyStat.gd
@tool
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

## A generic stat modification effect. 
## Explicitly classifies modifications by semantic action_type:
## - "HEAL": Restorative healing (+HP).
## - "BUFF": Stat enhancement (+HP or +PWR).
## - "DAMAGE": Direct combat damage (-HP).
## - "DEBUFF": Stat penalty (-HP or -PWR).
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
	
	var action_type_str: String = String(parameters.get("action_type", ""))
	var action_type: StringName = StringName(action_type_str)
	if stat in ["hp", "pwr"]:
		assert(not action_type_str.is_empty(), "EffectModifyStat: stat '%s' requires explicit 'action_type' in parameters ('HEAL', 'BUFF', 'DAMAGE', or 'DEBUFF')" % stat)

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
		
		# DIRECT DAMAGE (negative HP with ACTION_DAMAGE) - use EffectResult with damage_request marker
		if action_type == C.ACTION_DAMAGE:
			assert(stat == "hp" and amount < 0, "EffectModifyStat: ACTION_DAMAGE requires stat 'hp' and negative amount")
			var damage_result := EffectResult.new()
			var damage_type = parameters.get("damage_type", -1)
			var cause = C.CAUSE_ABILITY
			if damage_type == -1:
				var src_inst = battle_manager.get_instance_by_uuid(_source_uuid) if _source_uuid != "" else null
				if is_instance_valid(src_inst) and is_instance_valid(src_inst.get_definition()):
					var src_cat = src_inst.get_definition().category
					if src_cat == &"TRINKET":
						damage_type = C.DamageType.TRINKET
						cause = C.CAUSE_TRINKET
					else:
						# Unit or Item on a Unit
						if self.target_type == C.TARGET_FRONTMOST_ENEMY:
							damage_type = C.DamageType.MELEE
							cause = C.CAUSE_ATTACK
						else:
							damage_type = C.DamageType.RANGED
							cause = C.CAUSE_ATTACK
				else:
					damage_type = C.DamageType.RANGED
			elif damage_type == C.DamageType.TRINKET:
				cause = C.CAUSE_TRINKET
			
			damage_result.damage_request = EffectResult.DamageRequest.new(
				abs(amount),
				damage_type,
				valid_targets,
				false,
				cause
			)
			return damage_result
		
		# HEALS, BUFFS, DEBUFFS, and STATUS EFFECTS
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
			var tgt_action_type = action_type
			
			# SPECIAL: PWR->HP Conversion (e.g., Templar)
			# Redirect positive PWR buffs to HP if unit has specific tag
			var tgt_def = tgt.get_definition()
			if stat == "pwr" and amount > 0:
				if tgt.has_tag(&"CONVERT_PWR_TO_HP"):
					tgt_stat = "hp"
					tgt_action_type = C.ACTION_BUFF # Converted PWR buff is an HP BUFF, not a Heal!
					
					var old_hp = tgt.current_hp
					var max_hp = tgt_def.base_hp if is_instance_valid(tgt_def) and "base_hp" in tgt_def else tgt.current_hp
					var new_hp = battle_manager.apply_stat_delta(tgt, "hp", tgt_amount, _source_uuid, tgt_action_type, true)
					
					# Log message for conversion
					var conv_log = "%s converts PWR buff to +%d HP" % [BattleHelpers.get_instance_display_name(tgt), tgt_amount]
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": conv_log}))
					
					# BUFF Event (not HEAL)
					var conversion_payload := CombatPayload.hp_buff(visual_source_uuid, tgt_amount, [old_hp], [new_hp], [max_hp])
					result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
						"source_uuid": _source_uuid,
						"target_uuids": [target_uuid],
						"ability_id": context.get("ability_id", &"modify_stat"),
						"trigger_type": context.get("trigger_type", ""),
						"action_type": tgt_action_type,
						"visual_payload": conversion_payload
					}))
					continue # Skip adding to batched list
			
			# Capture old stat
			var old_val: int = tgt.current_hp if tgt_stat == "hp" else tgt.current_pwr
			var tgt_max_hp: int = tgt_def.base_hp if is_instance_valid(tgt_def) else 0
			
			# Apply stat change
			var new_val = battle_manager.apply_stat_delta(tgt, tgt_stat, tgt_amount, _source_uuid, tgt_action_type, true)
			
			# Collect data
			all_target_uuids.append(target_uuid)
			all_old_vals.append(old_val)
			all_new_vals.append(new_val)
			all_max_hp.append(tgt_max_hp)
			target_names.append(BattleHelpers.get_instance_display_name(tgt))
		
		# Create batched event for all targets at once
		if not all_target_uuids.is_empty():
			var custom_fmt: String = parameters.get("log_format", "")
			var aid: StringName = StringName(parameters.get("ability_id", "modify_stat"))
			if aid == &"modify_stat": aid = context.get("ability_id", &"modify_stat")
			var targets_label: String = target_names[0] if target_names.size() == 1 else " and ".join(target_names)
			
			if action_type == C.ACTION_HEAL:
				var log_text: String
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				else:
					log_text = "%s heals %s for %d HP" % [source_name, targets_label, amount]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

				var heal_payload := CombatPayload.heal(visual_source_uuid, amount, all_old_vals, all_new_vals, all_max_hp)
				heal_payload.skip_bump = parameters.get("skip_bump", false)
				result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"action_type": C.ACTION_HEAL,
					"ability_holder_uuid": _source_uuid,
					"visual_payload": heal_payload
				}))
				
			elif action_type == C.ACTION_BUFF:
				var stat_label: String = "HP" if stat == "hp" else "PWR"
				var log_text: String
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				else:
					log_text = "%s grants %s +%d %s" % [source_name, targets_label, amount, stat_label]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
				
				var buff_payload: CombatPayload
				if stat == "hp":
					buff_payload = CombatPayload.hp_buff(visual_source_uuid, amount, all_old_vals, all_new_vals, all_max_hp)
				else:
					buff_payload = CombatPayload.pwr_buff(visual_source_uuid, amount, all_old_vals, all_new_vals)
				buff_payload.skip_bump = parameters.get("skip_bump", false)
				
				result.add_event(CombatEvent.new(CombatEvent.Type.BUFF, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"action_type": C.ACTION_BUFF,
					"ability_holder_uuid": _source_uuid,
					"visual_payload": buff_payload
				}))
				
			elif action_type == C.ACTION_DEBUFF:
				var stat_label: String = "HP" if stat == "hp" else "PWR"
				var log_text: String
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				else:
					log_text = "%s reduces %s's %s by %d" % [source_name, targets_label, stat_label, abs(amount)]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))
				
				var debuff_payload: CombatPayload
				if stat == "hp":
					debuff_payload = CombatPayload.hp_debuff(visual_source_uuid, amount, all_old_vals, all_new_vals)
				else:
					debuff_payload = CombatPayload.pwr_debuff(visual_source_uuid, amount, all_old_vals, all_new_vals)
				debuff_payload.skip_bump = parameters.get("skip_bump", true)
				
				result.add_event(CombatEvent.new(CombatEvent.Type.DEBUFF, {
					"source_uuid": _source_uuid,
					"target_uuids": all_target_uuids,
					"ability_id": aid,
					"trigger_type": context.get("trigger_type", ""),
					"action_type": C.ACTION_DEBUFF,
					"ability_holder_uuid": _source_uuid,
					"visual_payload": debuff_payload
				}))
				
			else:
				# Generic Stat / Status Effect (e.g. armor_stacks)
				var log_text: String
				if not custom_fmt.is_empty():
					log_text = custom_fmt % [source_name, abs(amount)]
				else:
					log_text = "%s grants %s +%d %s" % [source_name, targets_label, amount, stat]
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {"text": log_text}))

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
			if action_type == C.ACTION_DAMAGE:
				var damage_type = parameters.get("damage_type", C.DamageType.RANGED)
				battle_manager.apply_damage(inst, abs(amount), damage_type, _source_uuid)
			else:
				battle_manager.apply_stat_delta(inst, stat, amount, _source_uuid, action_type, true)
	var non_sim_result := EffectResult.new()
	non_sim_result.state_applied = true
	return non_sim_result

