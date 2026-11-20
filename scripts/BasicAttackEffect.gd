# res://scripts/BasicAttackEffect.gd
@tool
extends EffectDefinition

## An effect that deals damage equal to the source's power to the first target.
## This is the default attack effect used when no special abilities are triggered.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, _context: TriggerContext) -> EffectResult:
	if targets.is_empty():
		return EffectResult.empty()
	# Get the target unit UUID from context
	var target_instance: GachaBallInstance = battle_manager.get_instance_by_uuid(targets[0])
	assert(is_instance_valid(target_instance), "BasicAttackEffect: target_instance is null")

	# Zero-Instance-Query Compliant: Use context data for source stats
	# Context is pre-populated by BattleManager with: source_pwr, source_hp, source_category, source_holder_uuid
	var damage = StatScaling.calculate(parameters.get("damage"), _context, "BasicAttackEffect")
	
	# Apply damage
	var is_simulation: bool = _context.is_simulation
	
	# Determine the actual attacker (for items, this is the holder)
	# Use context data instead of querying the source instance
	var attacker_uuid: String = source_uuid
	var source_category: StringName = _context.source_category
	if source_category == &"ITEM":
		var holder_uuid: String = _context.source_holder_uuid
		if not holder_uuid.is_empty():
			attacker_uuid = holder_uuid
	
	# Capture the pending reactions queue size BEFORE triggering on_attack
	# This ensures we only process the NEW reactions added by these triggers, not unrelated ones
	# Determine trigger cause:
	# 1. Inherit from context (e.g. CAUSE_TURN from BattleManager)
	# 2. If this is an ABILITY (like Extra Attack), it overrides the cause to CAUSE_ABILITY
	#    This prevents "Extra Attack" (Cause: ABILITY) from triggering another "Extra Attack" (Requires: CAUSE_TURN)
	var trigger_cause: StringName = _context.trigger_cause
	var ability_id: StringName = _context.ability_id
	if ability_id != &"basic_attack" and not String(ability_id).begins_with("basic_attack"):
		trigger_cause = &"CAUSE_ABILITY"
	
	# WIND-UP PHASE
	var windup_scope: int = battle_manager.begin_reaction_scope()
	if not _context.on_attack_already_triggered:
		var attack_context := TriggerContext.new()
		attack_context.attacker_uuid = attacker_uuid
		attack_context.target_uuid = target_instance.ball_uuid
		attack_context.target_initial_hp = target_instance.current_hp
		attack_context.is_simulation = is_simulation
		attack_context.trigger_cause = trigger_cause
		attack_context.cause_id = ability_id
		AbilityResolver.process_trigger(C.TRIGGER_WHEN_ATTACKING, attack_context)
		
	var windup_events: Array[CombatEvent] = []
	if is_simulation:
		windup_events = battle_manager.drain_reaction_scope(windup_scope)
	else:
		battle_manager.drain_reaction_scope(windup_scope)

	# PRE-IMPACT PHASE
	var pre_impact_scope: int = battle_manager.begin_reaction_scope()
	var before_attack_context := TriggerContext.new()
	before_attack_context.source_uuid = target_instance.ball_uuid
	before_attack_context.defender_uuid = target_instance.ball_uuid
	before_attack_context.attacker_uuid = attacker_uuid
	before_attack_context.target_initial_hp = target_instance.current_hp
	before_attack_context.is_simulation = is_simulation
	AbilityResolver.process_trigger(C.TRIGGER_BEFORE_TAKING_DAMAGE, before_attack_context)
	
	var pre_impact_events: Array[CombatEvent] = []
	if is_simulation:
		pre_impact_events = battle_manager.drain_reaction_scope(pre_impact_scope)
	else:
		battle_manager.drain_reaction_scope(pre_impact_scope)

	# -------------------------------------------------------------------------
	# TRAIT & TRINKET LOGIC
	# -------------------------------------------------------------------------
	var source_instance = battle_manager.get_instance_by_uuid(attacker_uuid)
	var is_player_source = false
	if is_instance_valid(source_instance):
		is_player_source = battle_manager._is_player_unit(source_instance)
	
	var active_traits: Dictionary = battle_manager.get_active_traits("PLAYER" if is_player_source else "ENEMY")
	
	# Burn stacks (Burn Vial + Fire L1/L2 + Appliance L2)
	var burn_amount: int = TraitRulesEngine.get_bonus_burn_stacks_for_attack(source_instance, target_instance, battle_manager)
	var should_apply_burn: bool = burn_amount > 0
	
	# Fire L4 / Burnie Combustion Strike bonus damage
	damage += TraitRulesEngine.get_fire_burn_bonus_damage(source_instance, target_instance, battle_manager, true)

	# Earth L5: Earth units deal bonus attack damage equal to current Spikes.
	# Decays 1 stack per attack damage instance at impact.
	var earth_spikes_applied := false
	var earth_spikes_old := 0
	if TraitRulesEngine.has_tier(active_traits, "EARTH", 5) and is_instance_valid(source_instance) and battle_manager.has_trait(source_instance, "EARTH"):
		var earth_spikes = source_instance.get_status_effect_amount(&"spikes")
		if earth_spikes > 0:
			damage += earth_spikes
			earth_spikes_applied = true
			earth_spikes_old = earth_spikes

	# Fighter L1: If target HP > Fighter HP, attacks deal +1 damage
	if TraitRulesEngine.has_tier(active_traits, "FIGHTER", 1) and is_instance_valid(source_instance) and battle_manager.has_trait(source_instance, "FIGHTER"):
		if target_instance.current_hp > source_instance.current_hp:
			damage += 1

	# Static stacks (Air L1/L2/L5 + Mecha L2 + Appliance L1)
	var static_amount: int = TraitRulesEngine.get_bonus_static_stacks_for_attack(source_instance, battle_manager)

	# Consume Charged Empowered Attack if present
	if is_instance_valid(source_instance) and not source_instance.charged_empowered_attack.is_empty():
		var charged: Dictionary = source_instance.charged_empowered_attack
		damage += int(charged.get("bonus_damage", 0))
		burn_amount += int(charged.get("burn_stacks", 0))
		static_amount += int(charged.get("static_stacks", 0))
		var spend_tokens: int = int(charged.get("spend_tokens", 0))
		if spend_tokens > 0:
			battle_manager.spend_gacha_tokens(spend_tokens, source_instance.ball_uuid)
		source_instance.charged_empowered_attack = {}
		should_apply_burn = burn_amount > 0
				
	var attack_type = parameters.get("attack_type", "melee")
	
	var damage_type = C.DamageType.MELEE if attack_type == "melee" else C.DamageType.RANGED

	# Guardian Intercept
	var final_target_uuid = target_instance.ball_uuid
	var final_target = target_instance
	var intercept_res = BattleHelpers.resolve_guardian_intercept(
		target_instance, damage, damage_type, is_player_source, battle_manager
	)
	if intercept_res.intercepted:
		final_target = intercept_res.interceptor
		final_target_uuid = final_target.ball_uuid
		CombatCommand.append_unified_events(pre_impact_events, intercept_res.events)

	# Attack-impact abilities resolve when the attack reaches its final target. Keep
	# their events separate so presentation can play them at contact, not wind-up.
	var contact_scope: int = battle_manager.begin_reaction_scope()
	var attack_impact_context: TriggerContext = TriggerContext.new()
	attack_impact_context.source_uuid = attacker_uuid
	attack_impact_context.attacker_uuid = attacker_uuid
	attack_impact_context.defender_uuid = final_target_uuid
	attack_impact_context.target_uuid = final_target_uuid
	attack_impact_context.target_initial_hp = final_target.current_hp
	attack_impact_context.trigger_cause = C.CAUSE_ATTACK
	attack_impact_context.cause_id = ability_id
	attack_impact_context.is_simulation = is_simulation
	AbilityResolver.process_trigger(C.TRIGGER_ON_ATTACK_IMPACT, attack_impact_context)
	var contact_events: Array[CombatEvent] = []
	if is_simulation:
		contact_events = battle_manager.drain_reaction_scope(contact_scope)
	else:
		battle_manager.drain_reaction_scope(contact_scope)

	# IMPACT PHASE (Damage Application)
	var old_hp = final_target.current_hp
	var old_armor = final_target.get_status_effect_amount(&"armor")
	var old_burn = final_target.get_status_effect_amount(&"burn")
	
	var damage_result = battle_manager.apply_damage(final_target, damage, damage_type, attacker_uuid)
	
	var new_hp = damage_result.get("new_hp", final_target.current_hp) if not damage_result.is_empty() else final_target.current_hp
	var armor_consumed = damage_result.get("armor_consumed", 0) if not damage_result.is_empty() else 0
	var new_armor = damage_result.get("new_armor", old_armor) if not damage_result.is_empty() else old_armor
	
	var burn_val = old_burn
	if should_apply_burn:
		burn_val = battle_manager.apply_stat_delta(final_target, "burn_stacks", burn_amount, attacker_uuid)
	
	var spikes_data_list: Array[Dictionary] = []
	if not damage_result.is_empty() and damage_result.has("spikes_data"):
		spikes_data_list.append(damage_result["spikes_data"])
		
	var impact_scope: int = battle_manager.begin_reaction_scope()
	battle_manager.trigger_on_hurt(final_target_uuid, damage, attacker_uuid)
		
	var impact_events: Array[CombatEvent] = []
	if is_simulation:
		impact_events = battle_manager.drain_reaction_scope(impact_scope)
	else:
		battle_manager.drain_reaction_scope(impact_scope)

	# Earth L5 Spikes Decay (1 stack per damage instance)
	if earth_spikes_applied and is_instance_valid(source_instance) and source_instance.current_hp > 0:
		var new_sp = battle_manager.apply_stat_delta(source_instance, "spikes_stacks", -1, attacker_uuid)
		var spikes_payload := CombatPayload.status_change(source_instance.ball_uuid, -1, "spikes_stacks", [earth_spikes_old], [new_sp])
		impact_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
			"source_uuid": source_instance.ball_uuid,
			"target_uuids": [source_instance.ball_uuid],
			"visual_payload": spikes_payload
		}))

	# Pyre Strike (Post-Impact Slot Ignition for Burnie)
	if is_instance_valid(source_instance) and source_instance.definition_id == &"elite_burnie" and is_instance_valid(final_target):
		var target_loc = battle_manager.get_location_for_uuid(final_target.ball_uuid)
		if is_instance_valid(target_loc):
			var slot_array: Array[StringName] = []
			if target_loc.container == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
				slot_array = battle_manager._state.player_slot_effects
			elif target_loc.container == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
				slot_array = battle_manager._state.enemy_slot_effects
			if not slot_array.is_empty() and target_loc.index >= 0 and target_loc.index < slot_array.size():
				if slot_array[target_loc.index] != &"burn":
					var prev_eff = slot_array[target_loc.index]
					slot_array[target_loc.index] = &"burn"
					impact_events.append(CombatEvent.new(CombatEvent.Type.SLOT_EFFECT_CHANGE, {
						"visual_payload": CombatPayload.slot_effect_change(target_loc.container, target_loc.index, prev_eff, &"burn")
					}))

	# Static Application & Splash (Air L1, L2, L3, L5, Mecha L2 & Appliance L1)
	var old_static: int = 0
	var new_static: int = 0
	var should_apply_static := false
	if static_amount > 0 and is_instance_valid(final_target):
		old_static = final_target.get_status_effect_amount(&"static")
		new_static = battle_manager.apply_stat_delta(final_target, "static_stacks", static_amount, attacker_uuid)
		should_apply_static = true
		
		# Air L3 (12 Souls): Attacks splash half of applied Static (min 1) to adjacent enemies
		if TraitRulesEngine.has_tier(active_traits, "AIR", 3) and is_instance_valid(source_instance) and battle_manager.has_trait(source_instance, "AIR"):
			var splash_static = max(1, int(floor(static_amount / 2.0)))
			var target_loc = battle_manager.get_location_for_uuid(final_target.ball_uuid)
			if is_instance_valid(target_loc):
				var opp_container = target_loc.container
				var opp_lineup = battle_manager.get_instances_in_container(opp_container)
				var target_slot: int = target_loc.index
				for enemy in opp_lineup:
					if not is_instance_valid(enemy) or enemy.current_hp <= 0 or enemy.ball_uuid == final_target.ball_uuid:
						continue
					if enemy.location_slot_index == target_slot - 1 or enemy.location_slot_index == target_slot + 1:
						var enemy_old_st = enemy.get_status_effect_amount(&"static")
						var enemy_new_st = battle_manager.apply_stat_delta(enemy, "static_stacks", splash_static, attacker_uuid)
						var splash_payload := CombatPayload.status_change(attacker_uuid, splash_static, "static_stacks", [enemy_old_st], [enemy_new_st])
						impact_events.append(CombatEvent.new(CombatEvent.Type.STATUS_EFFECT, {
							"source_uuid": attacker_uuid,
							"target_uuids": [enemy.ball_uuid],
							"visual_payload": splash_payload
						}))

	# Toy L1-L3 Melee Static Reflection (Resolved at point of contact)
	var static_reflection_list: Array[CombatStaticReflectionData] = []
	if damage_type == C.DamageType.MELEE:
		var toy_refl: CombatStaticReflectionData = TraitRulesEngine.apply_melee_defender_toy_reflection(source_instance, final_target, battle_manager)
		if is_instance_valid(toy_refl):
			static_reflection_list.append(toy_refl)

	# Animal L1-L4 Heal on Attack
	TraitRulesEngine.apply_animal_attack_heal(source_instance, battle_manager, impact_events)

	# Fighter L3: Cleave damage to enemy directly behind target
	if TraitRulesEngine.has_tier(active_traits, "FIGHTER", 3) and is_instance_valid(source_instance) and battle_manager.has_trait(source_instance, "FIGHTER"):
		var cleave_damage = max(1, int(floor(source_instance.current_pwr / 2.0)))
		var target_behind = battle_manager._get_ally_behind(final_target)
		if is_instance_valid(target_behind) and target_behind.current_hp > 0:
			var cleave_old_hp = target_behind.current_hp
			var cleave_old_armor = target_behind.get_status_effect_amount(&"armor")
			var cleave_res = battle_manager.apply_damage(target_behind, cleave_damage, C.DamageType.RANGED, attacker_uuid)
			var cleave_new_hp = cleave_res.get("new_hp", target_behind.current_hp)
			var cleave_armor_consumed = cleave_res.get("armor_consumed", 0)
			var cleave_new_armor = cleave_res.get("new_armor", cleave_old_armor)
			var cleave_max_hp := 0
			var tb_def = target_behind.get_definition()
			if is_instance_valid(tb_def):
				cleave_max_hp = tb_def.base_hp
			var cleave_payload := CombatPayload.damage(attacker_uuid, cleave_damage, [cleave_old_hp], [cleave_new_hp], [cleave_old_armor], [cleave_new_armor], [cleave_armor_consumed])
			cleave_payload.targets_max_hp = [cleave_max_hp] as Array[int]
			cleave_payload.attack_type = "cleave"
			impact_events.append(CombatEvent.new(CombatEvent.Type.DAMAGE, {
				"source_uuid": attacker_uuid,
				"target_uuids": [target_behind.ball_uuid],
				"visual_payload": cleave_payload
			}))
			if cleave_new_hp <= 0:
				battle_manager.trigger_on_kill(attacker_uuid, target_behind.ball_uuid)

	# A lethal save resolves in the on_hurt reaction window, so determine kills only
	# after that window closes.
	if final_target.current_hp <= 0:
		battle_manager.trigger_on_kill(attacker_uuid, final_target_uuid)
	if damage_result.has("spikes_data"):
		var spikes = damage_result["spikes_data"]
		var reflected_target = battle_manager.get_instance_by_uuid(String(spikes["attacker_uuid"]))
		if is_instance_valid(reflected_target) and reflected_target.current_hp <= 0:
			battle_manager.trigger_on_kill(String(spikes["defender_uuid"]), reflected_target.ball_uuid)
		
	var visual_payload := CombatPayload.damage(attacker_uuid, damage, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
	visual_payload.targets_old_burn.assign([old_burn])
	visual_payload.targets_new_burn.assign([burn_val])
	visual_payload.apply_burn = should_apply_burn
	visual_payload.targets_old_static.assign([old_static] if should_apply_static else [])
	visual_payload.targets_new_static.assign([new_static] if should_apply_static else [])
	visual_payload.apply_static = should_apply_static
	visual_payload.attack_type = attack_type
	visual_payload.projectile = CombatProjectile.new("hp", abs(damage), "red") if attack_type == "ranged" else null
	visual_payload.original_target_uuids = [target_instance.ball_uuid]
	visual_payload.spikes_data_list = _make_spikes_payloads(spikes_data_list)
	visual_payload.static_reflection_data_list = static_reflection_list
	visual_payload.windup_events = windup_events
	visual_payload.pre_impact_events = pre_impact_events
	visual_payload.contact_events = contact_events
	visual_payload.impact_events = impact_events
	
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

func _make_spikes_payloads(raw_spikes_data: Array[Dictionary]) -> Array[CombatSpikesData]:
	var result: Array[CombatSpikesData] = []
	for raw_data in raw_spikes_data:
		var spikes_data := CombatSpikesData.new()
		spikes_data.attacker_uuid = String(raw_data.get("attacker_uuid", ""))
		spikes_data.defender_uuid = String(raw_data.get("defender_uuid", ""))
		spikes_data.spikes_damage = int(raw_data.get("spikes_damage", 0))
		spikes_data.attacker_old_hp = int(raw_data.get("attacker_old_hp", 0))
		spikes_data.attacker_new_hp = int(raw_data.get("attacker_new_hp", 0))
		spikes_data.attacker_max_hp = int(raw_data.get("attacker_max_hp", 0))
		spikes_data.old_spikes = int(raw_data.get("old_spikes", 0))
		spikes_data.new_spikes = int(raw_data.get("new_spikes", 0))
		spikes_data.armor_consumed = int(raw_data.get("armor_consumed", 0))
		spikes_data.new_armor = int(raw_data.get("new_armor", 0))
		result.append(spikes_data)
	return result
