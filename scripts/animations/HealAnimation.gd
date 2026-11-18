class_name HealAnimation
extends BattleAnimation

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: CombatPayload) -> void:
	var source_uuid = payload.source_uuid
	var amount = payload.amount
	var targets_new_hp = payload.targets_new_hp
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles (Parallel)
	# VFXFactory handles self-casts by sending the projectile over the target itself.
	var projectiles: Array[Node] = []
	for target_uuid in targets:
		var proj: Node = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), "hp", "green")
		if proj != null:
			projectiles.append(proj)
	
	# Wait for projectiles to land (heal happens on impact for ally heals)
	if not projectiles.is_empty():
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.wait_for_impact()
	elif targets.any(func(t: String): return t != source_uuid):
		await AnimationConstants.create_pausable_timer(animator.get_tree(), AnimationConstants.scaled(0.5)).timeout
			
	# 2. Apply Heal (Flash + Label Update)
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# Skip targets not in visual registry (may have died during animation)
		if not animator._visual_registry.has(target_uuid):
			continue
		
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		
		# HealAnimation owns the sprite feedback for healing. Suppress the duplicate
		# reactions normally started by animate_stat_change, then wait for every
		# composable channel below before advancing to the next combat event.
		animator.apply_hp_delta(target_uuid, amount, new_hp, false)
		
		# Composable Effects: Color flash, hop deform, hop movement
		SignalBus.emit_signal("unit_color_flash", target_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
		SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
		SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)

		var animation_types: Array[AnimationCompletionTracker.AnimationType] = [
			AnimationCompletionTracker.AnimationType.COLOR_FLASH,
			AnimationCompletionTracker.AnimationType.DEFORM,
			AnimationCompletionTracker.AnimationType.MOVE
		]
		await animator.wait_for_animation_channels(target_uuid, animation_types)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, _stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, "hp")
