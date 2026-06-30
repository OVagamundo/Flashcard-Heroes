class_name BuffAnimation
extends BattleAnimation

## BuffAnimation handles core stat buffs: HP and PWR only.
## Status effects (burn_stacks, armor_stacks) are handled by StatusEffectAnimation.

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var stat = String(payload.get("stat", "pwr"))
	
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles
	var projectiles = []
	var color_hint = "green" if stat == "hp" else "blue"
	
	for target_uuid in targets:
		var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), stat, color_hint)
		if proj: projectiles.append(proj)
		
	# Wait for impact
	if projectiles.is_empty():
		await animator.get_tree().create_timer(AnimationConstants.scaled(0.5)).timeout
	else:
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
				
	# 2. Apply Stat Buff (HP or PWR only)
	var final_target_uuid = ""
	var pwr_values = payload.get("targets_new_pwr", [])
	var hp_values = payload.get("targets_new_hp", [])
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# In parallel mode, the target might not be in the visual registry initially.
		# The animator's apply_hp_delta / apply_pwr_delta will safely handle missing views.
		final_target_uuid = target_uuid
		
		if stat == "hp":
			var new_hp = 0
			if not hp_values.is_empty() and i < hp_values.size():
				new_hp = int(hp_values[i])
			else:
				new_hp = int(payload.get("new_hp", 0)) # Fallback
			
			animator.apply_hp_delta(target_uuid, amount, new_hp)
			
			# Composable Effects: Color flash + hop deform + hop move
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
			if SignalBus.has_signal("unit_move"):
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		
		elif stat == "pwr":
			var new_pwr = 0
			if not pwr_values.is_empty() and i < pwr_values.size():
				new_pwr = int(pwr_values[i])
			else:
				new_pwr = int(payload.get("new_pwr", 0)) # Fallback
				
			animator.apply_pwr_delta(target_uuid, amount, new_pwr)
			
			# Composable Effects: Color flash + hop deform + hop move
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
			if SignalBus.has_signal("unit_move"):
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)

	# Wait for hop animation completion
	if final_target_uuid != "":
		await animator.wait_for_animation_completion("move", final_target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat)
