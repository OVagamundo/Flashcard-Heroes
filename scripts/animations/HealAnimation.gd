class_name HealAnimation
extends BattleAnimation

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var targets_new_hp = payload.get("targets_new_hp", [])
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles (Parallel)
	# For heals, we might want to wait for projectile impact before flashing
	var projectiles = []
	for target_uuid in targets:
		var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), "hp", "green")
		if proj: projectiles.append(proj)
	
	# Wait for projectiles to land (Juicy feel: heal happens on impact)
	# If no projectiles (missing snapshots), wait a simulated duration
	if projectiles.is_empty():
		await animator.get_tree().create_timer(0.5).timeout
	else:
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
			
	# 2. Apply Heal (Flash + Label Update)
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# Skip targets not in visual registry (may have died during animation)
		if not animator._visual_registry.has(target_uuid):
			continue
		
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		
		animator.apply_hp_delta(target_uuid, amount, new_hp)
		
		# Composable Effects: Color flash, hop deform, hop movement
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", target_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
		
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
		
		if SignalBus.has_signal("unit_move"):
			SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		
		# Wait for movement completion
		await animator.wait_for_animation_completion("move", target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, _stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, "hp")
