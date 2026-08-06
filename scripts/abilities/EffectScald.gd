@tool
class_name EffectScald
extends EffectDefinition

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()
	
	# Only trigger if the unit is in the lineup (Player or Enemy)
	# This prevents the ability from triggering when the unit is on the bench.
	var source_unit = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_unit):
		return result
		
	var container_tag = source_unit.location_container_tag
	if container_tag != &"PlayerLineup" and container_tag != &"EnemyLineup":
		return result
	
	# Get heal amount from context
	var heal_amount: int = context.get("heal_amount", 0)
	if heal_amount <= 0:
		return result
		
	var extra_bounces: int = parameters.get("extra_bounces", 0)
	
	if OS.is_debug_build():
		print("[EffectScald] execute: heal_amount=", heal_amount, ", extra_bounces=", extra_bounces)
	
	var is_player_team = (container_tag == &"PlayerLineup")
	var enemy_container = C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP if is_player_team else C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
	
	var current_source_uuid = source_uuid
	var current_target_uuid = ""
	
	# Initial random target
	var initial_enemies = battle_manager.get_instances_in_container(enemy_container).filter(func(u): return u.current_hp > 0)
	if initial_enemies.is_empty():
		return result
	current_target_uuid = RNGManager.combat_rng.pick_random(initial_enemies).ball_uuid
	
	var current_burn_amount = heal_amount
	
	for bounce_index in range(extra_bounces + 1):
		var target_inst = battle_manager.get_instance_by_uuid(current_target_uuid)
		if not is_instance_valid(target_inst) or target_inst.current_hp <= 0:
			break # Stop bouncing if target is somehow invalid
			
		var old_burn = target_inst.get_status_effect_amount(&"burn")
		var new_burn = battle_manager.apply_stat_delta(target_inst, "burn_stacks", current_burn_amount)
		
		var burn_event = CombatEvent.new(
			CombatEvent.Type.STATUS_EFFECT,
			{
				"target_uuids": [current_target_uuid],
				"is_simulation": context.get("is_simulation", false),
				"visual_payload": CombatPayload.status_change(current_source_uuid, current_burn_amount, "burn_stacks", [old_burn], [new_burn], Color.ORANGE_RED)
			}
		)
		result.events.append(burn_event)
		
		# Prepare next bounce
		if bounce_index < extra_bounces:
			current_source_uuid = current_target_uuid
			current_burn_amount = max(1, int(floor(current_burn_amount / 2.0)))
			
			var enemies = battle_manager.get_instances_in_container(enemy_container).filter(func(u): return u.current_hp > 0)
			if enemies.is_empty():
				break
				
			var possible_next_targets = enemies.filter(func(u): return u.ball_uuid != current_target_uuid)
			if possible_next_targets.is_empty():
				# Bounce back to same target if no one else is alive
				possible_next_targets = enemies
				
			var next_enemy = RNGManager.combat_rng.pick_random(possible_next_targets)
			current_target_uuid = next_enemy.ball_uuid
			
	return result
