class_name BuffAnimation
extends BattleAnimation

# NOTE: VFX scene preloads moved to VFXFactory autoload

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var stat = String(payload.get("stat", "pwr"))
	
	if OS.is_debug_build():
		print("[BuffAnimation] execute() called - stat='%s' amount=%d targets=%d" % [stat, amount, targets.size()])
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles
	var projectiles = []
	var color_hint = "black" if stat == "pwr" else "orange"
	
	for target_uuid in targets:
		var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), stat, color_hint)
		if proj: projectiles.append(proj)
		
	# Wait for impact - if we have projectiles, wait for them
	# If no projectiles (missing snapshots), wait a simulated duration
	if projectiles.is_empty():
		# No projectiles - wait for simulated flight time so effects feel right
		await animator.get_tree().create_timer(0.5).timeout
	else:
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
			
	# 2. Apply Buff
	# 2. Apply Buff (Parallel)
	var final_target_uuid = ""
	var pwr_values = payload.get("targets_new_pwr", [])
	var burn_values = payload.get("targets_new_val", [])
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# Skip targets not in visual registry (may have died during animation)
		if not animator._visual_registry.has(target_uuid):
			continue
		
		final_target_uuid = target_uuid
		
		# STAT BUFFS: HP and PWR (core stats)
		if stat == "hp":
			var hp_values = payload.get("targets_new_hp", [])
			var new_hp = 0
			if not hp_values.is_empty() and i < hp_values.size():
				new_hp = int(hp_values[i])
			else:
				new_hp = int(payload.get("new_hp", 0)) # Fallback
			
			animator.apply_hp_delta(target_uuid, amount, new_hp)
			
			# Composable Effects: Color flash + hop deform + hop move (same as PWR buff)
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
			
			# Composable Effects: Color flash + hop deform + hop move (positive buff)
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, AnimationConstants.COLOR_HEAL_BUFF, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
			if SignalBus.has_signal("unit_move"):
				SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		
		# STATUS EFFECTS: burn, armor, and other stacks (separate from core stats)
		elif stat == "burn_stacks":
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
				
			animator.apply_burn_stack(target_uuid, new_val)
			# Composable Effects: Orange flash + hit impact (debuff - no hop)
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, Color(1.0, 0.4, 0.0), AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"HIT_IMPACT")
		
		elif stat == "armor_stacks":
			# Dedicated armor handler - same pattern as burn
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
				
			animator.apply_armor_stack(target_uuid, new_val)
			# Composable Effects: Silver flash + squish bounce (positive buff)
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, Color(0.7, 0.7, 0.8), AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"SQUISH_BOUNCE")
		
		elif stat.ends_with("_stacks"):
			# Generic status effect handling (armor_stacks, etc.)
			var status_id = stat.trim_suffix("_stacks")
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
			
			if OS.is_debug_build():
				print("[BuffAnimation] Applying status '%s' new_val=%d to %s" % [status_id, new_val, target_uuid])
			animator.apply_status_stack(target_uuid, StringName(status_id), new_val)
			# Composable Effects: Grey flash + squish bounce
			var flash_color = Color(0.7, 0.7, 0.7) if status_id == "armor" else Color(0.8, 0.8, 0.8)
			if SignalBus.has_signal("unit_color_flash"):
				SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
			if SignalBus.has_signal("unit_deform"):
				SignalBus.emit_signal("unit_deform", target_uuid, &"SQUISH_BOUNCE")

	# Wait for animation completion (wait for move if we did a hop, otherwise deform)
	if final_target_uuid != "":
		if stat == "pwr":
			await animator.wait_for_animation_completion("move", final_target_uuid)
		else:
			# For non-hop animations, just wait a short duration
			await animator.get_tree().create_timer(AnimationConstants.DEFORM_DURATION * 3).timeout

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, stat)
