# res://scripts/BasicAttackEffect.gd
@tool
extends EffectDefinition

## An effect that deals damage equal to the source's power to the first target.
## This is the default attack effect used when no special abilities are triggered.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: Dictionary) -> Variant:
	if targets.is_empty():
		return null

	# Get the target unit UUID from context
	var target_instance: GachaBallInstance = battle_manager.get_instance_by_uuid(targets[0])
	assert(is_instance_valid(target_instance), "BasicAttackEffect: target_instance is null")

	# Zero-Instance-Query Compliant: Use context data for source stats
	# Context is pre-populated by BattleManager with: source_pwr, source_hp, source_category, source_holder_uuid
	var damage = StatScaling.calculate(parameters.get("damage"), _context, "BasicAttackEffect")
	
	# Apply damage
	var is_simulation: bool = _context.get("is_simulation", false)
	
	# Determine the actual attacker (for items, this is the holder)
	# Use context data instead of querying the source instance
	var attacker_uuid: String = source_uuid
	var source_category: StringName = _context.get("source_category", &"")
	if source_category == &"ITEM":
		var holder_uuid: String = _context.get("source_holder_uuid", "")
		if not holder_uuid.is_empty():
			attacker_uuid = holder_uuid
	
	# Capture the pending reactions queue size BEFORE triggering on_attack
	# This ensures we only process the NEW reactions added by these triggers, not unrelated ones
	# Determine trigger cause:
	# 1. Inherit from context (e.g. CAUSE_TURN from BattleManager)
	# 2. If this is an ABILITY (like Extra Attack), it overrides the cause to CAUSE_ABILITY
	#    This prevents "Extra Attack" (Cause: ABILITY) from triggering another "Extra Attack" (Requires: CAUSE_TURN)
	var trigger_cause = _context.get("trigger_cause", &"")
	var ability_id = _context.get("ability_id", &"")
	if ability_id != &"basic_attack":
		trigger_cause = &"CAUSE_ABILITY"
	
	# WIND-UP PHASE
	var windup_start: int = battle_manager.get_pending_reactions_size()
	if not _context.get("on_attack_already_triggered", false):
		var attack_context: Dictionary = {
			"attacker_uuid": attacker_uuid,
			"target_uuid": target_instance.ball_uuid,
			"target_initial_hp": target_instance.current_hp,
			"is_simulation": is_simulation,
			"trigger_cause": trigger_cause,
			"cause_id": ability_id
		}
		AbilityResolver.process_trigger(&"on_attack", attack_context)
		
	var windup_events: Array[CombatEvent] = []
	if is_simulation:
		windup_events = battle_manager.drain_and_capture_reactions_inline(windup_start)

	# PRE-IMPACT PHASE
	var pre_impact_start: int = battle_manager.get_pending_reactions_size()
	var before_attack_context: Dictionary = {
		"source_uuid": target_instance.ball_uuid,
		"defender_uuid": target_instance.ball_uuid,
		"attacker_uuid": attacker_uuid,
		"target_initial_hp": target_instance.current_hp,
		"is_simulation": is_simulation
	}
	AbilityResolver.process_trigger(&"on_before_damage", before_attack_context)
	
	var pre_impact_events: Array[CombatEvent] = []
	if is_simulation:
		pre_impact_events = battle_manager.drain_and_capture_reactions_inline(pre_impact_start)

	# -------------------------------------------------------------------------
	# TRAIT & TRINKET LOGIC
	# -------------------------------------------------------------------------
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	var is_player_source = false
	if is_instance_valid(source_instance):
		is_player_source = battle_manager._is_player_unit(source_instance)
	
	var active_traits = battle_manager.get_active_traits("PLAYER" if is_player_source else "ENEMY")
	var fire_level = active_traits.get("FIRE", 0)
	
	var burn_amount := 0
	if is_instance_valid(source_instance):
		burn_amount = battle_manager.get_bonus_burn_stacks_for_attack(source_instance)
	
	var should_apply_burn = burn_amount > 0
	
	# Fire 9 Bonus Damage
	if fire_level >= 9:
		if is_instance_valid(source_instance) and battle_manager._has_trait_soul(source_instance, "FIRE"):
			var burn_count = target_instance.get_status_effect_amount(&"burn")
			if burn_count > 0:
				damage += burn_count
				
	# Guardian Sentinel Intercept
	var target_armor = target_instance.get_status_effect_amount(&"armor")
	var hp_damage = max(0, damage - target_armor)
	var would_be_lethal = target_instance.current_hp - hp_damage <= 0
	var tgt_is_player_unit = battle_manager._is_player_unit(target_instance)
	var is_ally_damage = (tgt_is_player_unit != is_player_source)
	
	var final_target_uuid = target_instance.ball_uuid
	var final_target = target_instance
	
	if would_be_lethal and is_ally_damage:
		var guardian: GachaBallInstance = battle_manager._find_guardian_on_team(tgt_is_player_unit, final_target_uuid)
		if is_instance_valid(guardian):
			pre_impact_events.append(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
				"source_uuid": guardian.ball_uuid,
				"target_uuids": [final_target_uuid],
				"visual_payload": {
					"guardian_uuid": guardian.ball_uuid,
					"original_target_uuid": final_target_uuid,
					"damage": damage
				}
			}))
			final_target_uuid = guardian.ball_uuid
			final_target = guardian
			
			# Trigger Guardian passive effects (e.g., gain Armor)
			var combat_sim = battle_manager._combat
			var intercept_start = combat_sim._pending_reactions.size()
			
			AbilityResolver.process_trigger(&"passive_intercept", {
				"source_uuid": guardian.ball_uuid,
				"is_simulation": true
			})
			
			combat_sim.drain_reactions_inline(intercept_start, battle_manager)
			var guardian_results = combat_sim.collect_and_clear_inline_events()
			pre_impact_events.append_array(guardian_results)

	# IMPACT PHASE (Damage Application)
	var old_hp = final_target.current_hp
	var old_armor = final_target.get_status_effect_amount(&"armor")
	var old_burn = final_target.get_status_effect_amount(&"burn")
	
	var attack_type = parameters.get("attack_type", "melee")
	
	# Sniper Aim override
	if is_instance_valid(source_instance):
		for item_uuid in source_instance.equipped_item_uuids:
			if not item_uuid.is_empty():
				var item = battle_manager.get_instance_by_uuid(item_uuid)
				if is_instance_valid(item) and item.definition_id == &"item_t3_g":
					attack_type = "ranged"
					break
	var damage_type = C.DamageType.MELEE if attack_type == "melee" else C.DamageType.RANGED
	var damage_result = battle_manager.apply_damage(final_target, damage, damage_type, attacker_uuid)
	
	var new_hp = damage_result.get("new_hp", final_target.current_hp) if not damage_result.is_empty() else final_target.current_hp
	var armor_consumed = damage_result.get("armor_consumed", 0) if not damage_result.is_empty() else 0
	var new_armor = damage_result.get("new_armor", old_armor) if not damage_result.is_empty() else old_armor
	
	var burn_val = old_burn
	if should_apply_burn:
		burn_val = battle_manager.apply_stat_delta(final_target, "burn_stacks", burn_amount)
	
	var spikes_data_list: Array[Dictionary] = []
	if not damage_result.is_empty() and damage_result.has("spikes_data"):
		spikes_data_list.append(damage_result["spikes_data"])
		
	var impact_start: int = battle_manager.get_pending_reactions_size()
	battle_manager.trigger_on_hurt(final_target_uuid, damage, attacker_uuid)
	
	if new_hp <= 0:
		battle_manager.trigger_on_kill(attacker_uuid, final_target_uuid)
		
	var impact_events: Array[CombatEvent] = []
	if is_simulation:
		impact_events = battle_manager.drain_and_capture_reactions_inline(impact_start)
		
	# PACKAGE EVENTS INTO PAYLOAD
	var visual_payload: Dictionary = {
		"source_uuid": attacker_uuid,
		"amount": damage,
		"targets_old_hp": [old_hp],
		"targets_new_hp": [new_hp],
		"targets_old_armor": [old_armor],
		"targets_new_armor": [new_armor],
		"targets_old_burn": [old_burn],
		"targets_new_burn": [burn_val],
		"apply_burn": should_apply_burn,
		"armor_consumed": [armor_consumed],
		"attack_type": attack_type,
		"projectile_data": {"stat": "hp", "amount": abs(damage), "color": "red"} if attack_type == "ranged" else {},
		"original_target_uuids": [target_instance.ball_uuid], # The original target the attack aimed for
		"spikes_data_list": spikes_data_list,
		"windup_events": windup_events,
		"pre_impact_events": pre_impact_events,
		"impact_events": impact_events
	}
	
	var damage_event = CombatEvent.new(CombatEvent.Type.DAMAGE, {
		"source_uuid": attacker_uuid,
		"target_uuids": [final_target_uuid],
		"visual_payload": visual_payload
	})
	
	var effect_result = EffectResult.from_event(damage_event)
	effect_result.skip_death_check = false # Allow CombatSimulator to finalize deaths
	
	if not is_simulation:
		SignalBus.battle_inventory_changed.emit()

	return effect_result
