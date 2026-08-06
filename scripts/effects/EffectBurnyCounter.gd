@tool
class_name EffectBurnyCounter
extends EffectDefinition

## Burny's retaliation ability.
## Level 1: Ranged projectile to attacker with PWR damage.
## Level 2: + 1 burn projectile to random enemy (applying PWR as burn).
## Level 3: + 2 burn projectiles to random enemies.

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	var source_instance: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_instance):
		return result
		
	# Attacker UUID should be available in context (from on_hurt trigger)
	var attacker_uuid: String = context.get("attacker_uuid", "")
	if attacker_uuid.is_empty():
		attacker_uuid = context.get("trigger_context", {}).get("attacker_uuid", "")
		
	# Zero-Instance-Query Compliant: Use context data for source stats if possible
	var pwr: int = context.get("source_pwr", source_instance.current_pwr)
	
	if attacker_uuid.is_empty() or pwr <= 0:
		return result
		
	var is_player = battle_manager._is_player_unit(source_instance)
	var target_container = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var extra_bounces: int = parameters.get("extra_bounces", 0)
	var current_source_uuid = source_uuid
	var current_target_uuid = attacker_uuid
	var current_damage = pwr
	
	for bounce_index in range(1 + extra_bounces):
		var target_inst = battle_manager.get_instance_by_uuid(current_target_uuid)
		if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
			# If the target died or is invalid, try to find another one
			var valid_targets = []
			for u in battle_manager.get_instances_in_container(target_container):
				if u.current_hp > 0:
					valid_targets.append(u)
			
			if valid_targets.is_empty():
				break # No one left to bounce to
			else:
				target_inst = RNGManager.combat_rng.pick_random(valid_targets)
				current_target_uuid = target_inst.ball_uuid
				
		var old_hp = target_inst.current_hp
		var old_armor = target_inst.get_status_effect_amount(&"armor")
		
		# GUARDIAN SENTINEL INTERCEPT CHECK
		var hp_damage = max(0, current_damage - old_armor)
		var would_be_lethal: bool = target_inst.current_hp - hp_damage <= 0
		var tgt_is_player_unit: bool = battle_manager._is_player_unit(target_inst)
		var is_ally_damage: bool = (tgt_is_player_unit != is_player)
		
		if would_be_lethal and is_ally_damage:
			var guardian: GachaBallInstance = battle_manager._find_guardian_on_team(tgt_is_player_unit, current_target_uuid)
			if is_instance_valid(guardian):
				result.add_event(CombatEvent.new(CombatEvent.Type.GUARDIAN_INTERCEPT, {
					"source_uuid": guardian.ball_uuid,
					"target_uuids": [current_target_uuid],
					"visual_payload": CombatPayload.guardian_intercept(guardian.ball_uuid, current_target_uuid)
				}))
				current_target_uuid = guardian.ball_uuid
				target_inst = guardian
				old_hp = target_inst.current_hp
				old_armor = target_inst.get_status_effect_amount(&"armor")
		
		# 1. Apply Damage Manually to respect Armor
		var dmg_res = battle_manager.apply_damage(target_inst, current_damage, C.DamageType.RANGED, source_uuid)
		var new_hp = dmg_res["new_hp"]
		var new_armor = dmg_res["new_armor"]
		var armor_consumed = dmg_res["armor_consumed"]
		
		# 1b. Apply Bonus Burn Stacks (Trinket/Trait)
		var bonus_burn = battle_manager.get_bonus_burn_stacks_for_attack(source_instance)
		var old_burn = 0
		var new_burn = 0
		var should_apply_burn = false
		if bonus_burn > 0:
			old_burn = target_inst.get_status_effect_amount(&"burn")
			new_burn = battle_manager.apply_stat_delta(target_inst, "burn_stacks", bonus_burn)
			should_apply_burn = true
		
		# 2. Add Visual Event
		var dmg_event = CombatEvent.new(CombatEvent.Type.DAMAGE, {
			"source_uuid": current_source_uuid,
			"target_uuids": [current_target_uuid],
			"is_simulation": context.get("is_simulation", false)
		})
		var damage_payload := CombatPayload.damage(current_source_uuid, current_damage, [old_hp], [new_hp], [old_armor], [new_armor], [armor_consumed])
		damage_payload.attack_type = "ranged"
		damage_payload.skip_bump = true
		damage_payload.projectile = CombatProjectile.new("hp", current_damage, "red")
		damage_payload.targets_old_burn.assign([old_burn] if should_apply_burn else [])
		damage_payload.targets_new_burn.assign([new_burn] if should_apply_burn else [])
		damage_payload.apply_burn = should_apply_burn
		dmg_event.visual_payload = damage_payload
		result.events.append(dmg_event)
		
		# 3. Trigger Reactions
		battle_manager.trigger_on_hurt(current_target_uuid, dmg_res["hp_damage"], source_uuid, C.CAUSE_ABILITY)
		if new_hp <= 0:
			battle_manager.trigger_on_kill(source_uuid, current_target_uuid)
		
		# 4. Prepare next bounce
		if bounce_index < extra_bounces:
			current_source_uuid = current_target_uuid
			current_damage = max(1, floor(current_damage / 2))
			
			# Find next target
			var valid_targets = []
			for u in battle_manager.get_instances_in_container(target_container):
				if u.current_hp > 0:
					valid_targets.append(u)
			
			if valid_targets.is_empty():
				break
			elif valid_targets.size() == 1:
				current_target_uuid = valid_targets[0].ball_uuid
			else:
				# Pick random that is NOT the current target if possible
				var next_targets = valid_targets.filter(func(u): return u.ball_uuid != current_target_uuid)
				if not next_targets.is_empty():
					current_target_uuid = RNGManager.combat_rng.pick_random(next_targets).ball_uuid
				else:
					current_target_uuid = valid_targets[0].ball_uuid
					
	return result
