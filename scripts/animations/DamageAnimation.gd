class_name DamageAnimation
extends BattleAnimation

const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")
const FloatingDamageNumberScene = preload("res://scenes/vfx/FloatingDamageNumber.tscn")

# Animation timing: Total 1.0s, with travel-to-target being 2x return time
# Breakdown: 0.1 (windup) + 0.6 (lunge to target) + 0.3 (return) = 1.0s total
const BUMP_DURATION = 0.5
const MELEE_LUNGE_DURATION = 0.6 # Travel to target (2x return time)
const MELEE_RETURN_DURATION = 0.3 # Return time (half of travel time)

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var skip_bump = bool(payload.get("skip_bump", false))
	var apply_burn = bool(payload.get("apply_burn", false))
	var is_burn_damage = bool(payload.get("is_burn_damage", false))
	var attack_type = String(payload.get("attack_type", "melee")) # Default to melee
	var main_target_uuid = String(payload.get("main_target_uuid", "")) # For multi-target attacks
	
	# Ensure this is always a coroutine (GDScript quirk)
	await animator.get_tree().process_frame
	
	print("[DamageAnimation] Executing for targets: ", targets, " source: ", source_uuid, " attack_type: ", attack_type)
	
	# Get visual registry
	var visual_registry = animator._visual_registry
	
	# Determine main target (first target if not specified)
	if main_target_uuid.is_empty() and not targets.is_empty():
		main_target_uuid = targets[0]
	
	# ------------------------------------------------------------------
	# MELEE ATTACK ANIMATION
	# ------------------------------------------------------------------
	if attack_type == "melee" and not source_uuid.is_empty() and not skip_bump:
		# Get target position for lunge - attacker stops just before touching target's front
		var target_position = Vector2.ZERO
		var is_attacking_right = true # Default: player attacks right
		var src_width := 0.0 # Track attacker's width for offset
		
		# Determine attack direction and get attacker's size
		if visual_registry.has(source_uuid):
			var src_view = visual_registry[source_uuid]
			if is_instance_valid(src_view):
				var src_rect = src_view.get_global_rect()
				src_width = src_rect.size.x
				# If source is on the right side of screen, they attack left
				if visual_registry.has(main_target_uuid):
					var tgt_view = visual_registry[main_target_uuid]
					if is_instance_valid(tgt_view):
						var tgt_rect = tgt_view.get_global_rect()
						is_attacking_right = src_rect.position.x < tgt_rect.position.x
		
		if visual_registry.has(main_target_uuid):
			var target_view = visual_registry[main_target_uuid]
			if is_instance_valid(target_view):
				var rect = target_view.get_global_rect()
				# Position at front of target's head, offset by attacker's width so they don't overlap
				# global_position is top-left corner, so we need to account for that
				var head_y = rect.position.y # Top of sprite (head area)
				var gap := -10.0 # Negative gap to overlap/touch target
				
				if is_attacking_right:
					# Attacker coming from left: attacker's right edge should stop at target's left edge
					# So attacker's top-left (global_position) = target's left edge - attacker's width - gap
					target_position = Vector2(rect.position.x - src_width - gap, head_y)
				else:
					# Attacker coming from right: attacker's left edge should stop at target's right edge
					# So attacker's top-left (global_position) = target's right edge + gap
					target_position = Vector2(rect.position.x + rect.size.x + gap, head_y)
		
		# 1. Melee Lunge - attacker jumps to target
		if target_position != Vector2.ZERO:
			animator._current_animation_uuid = source_uuid
			SignalBus.emit_signal("unit_melee_lunge", source_uuid, target_position)
			await animator.wait_for_animation_completion("melee_lunge", source_uuid)
		
		# 2. Immediately return - attacker jumps back to original position
		animator._current_animation_uuid = source_uuid
		SignalBus.emit_signal("unit_melee_return", source_uuid)
		await animator.wait_for_animation_completion("melee_return", source_uuid)
		
		# 3. AFTER return - spawn floating damage numbers and apply effects
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)
	
	# ------------------------------------------------------------------
	# RANGED ATTACK ANIMATION (Future - uses projectiles)
	# ------------------------------------------------------------------
	elif attack_type == "ranged":
		# Trigger Bump (if applicable)
		var should_bump = (not skip_bump) and (not source_uuid.is_empty())
		if should_bump:
			var bump_dir = payload.get("bump_direction", Vector2.ZERO)
			if bump_dir != Vector2.ZERO:
				SignalBus.emit_signal("unit_bump_attack", source_uuid, bump_dir)
		
		# Launch Projectile (Parallel)
		var proj_data = payload.get("projectile_data", {})
		if not proj_data.is_empty():
			var p_stat = String(proj_data.get("stat", "hp"))
			var p_amount = int(proj_data.get("amount", 0))
			var p_color = String(proj_data.get("color", "red"))
			
			for target_uuid in targets:
				_launch_projectile(animator, source_uuid, target_uuid, abs(p_amount), p_stat, p_color)
		
		# Wait for Bump Impact
		if should_bump:
			await animator.get_tree().create_timer(BUMP_DURATION).timeout
		
		# Apply Damage
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)
		
		# Wait for bump to fully return
		if should_bump:
			await animator.wait_for_animation_completion("bump", source_uuid)
	
	# ------------------------------------------------------------------
	# NO SOURCE (Burn damage, environmental) - just flash
	# ------------------------------------------------------------------
	else:
		await _apply_damage_effects(animator, targets, payload, apply_burn, is_burn_damage, amount)

func _apply_damage_effects(animator: Node, targets: Array[String], payload: Dictionary, apply_burn: bool, is_burn_damage: bool, amount: int) -> void:
	var targets_new_hp = payload.get("targets_new_hp", [])
	var targets_new_burn = payload.get("targets_new_burn", [])
	
	# Trigger screen shake based on total damage dealt
	# Intensity scales from 0.0 to 1.0, where 5+ damage = max shake
	var shake_intensity = minf(float(abs(amount)) / 5.0, 1.0)
	if shake_intensity > 0.0:
		SignalBus.screen_shake_requested.emit(shake_intensity)
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		
		# Spawn floating damage number at target
		_spawn_floating_damage(animator, target_uuid, abs(amount))
		
		# Update Label (Puppet Mode)
		animator.apply_hp_delta(target_uuid, amount, new_hp)
		
		# Apply Burn if needed
		if apply_burn:
			var new_burn = targets_new_burn[i] if i < targets_new_burn.size() else 0
			animator.apply_burn_stack(target_uuid, new_burn)
			
		# Trigger Flash
		var flash_color = Color(1.0, 0.6, 0.6) # Red
		if is_burn_damage:
			flash_color = Color(1.0, 0.3, 0.0) # Orange for Burn
		
		if SignalBus.has_signal("unit_flash_effect"):
			SignalBus.emit_signal("unit_flash_effect", target_uuid, flash_color)
		
		# Wait for flash completion before moving to next target
		animator._current_animation_uuid = target_uuid
		await animator.wait_for_animation_completion("flash", target_uuid)

func _spawn_floating_damage(animator: Node, target_uuid: String, damage: int) -> void:
	var visual_registry = animator._visual_registry
	if not visual_registry.has(target_uuid): return
	
	var target_view = visual_registry[target_uuid]
	if not is_instance_valid(target_view): return
	
	var rect = target_view.get_global_rect()
	var spawn_pos = Vector2(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y * 0.3)
	
	var damage_number = FloatingDamageNumberScene.instantiate()
	# POOLING/LAYERING FIX: Use EffectsLayer so it renders above TopBar
	var effects_layer = animator.get_tree().get_first_node_in_group("effects_layer")
	if is_instance_valid(effects_layer):
		# Calculate Viewport Offset (TopArea height)
		var viewport_offset = Vector2.ZERO
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			var viewport = battle_view.get_viewport()
			if viewport and viewport.get_parent() is Control:
				viewport_offset = viewport.get_parent().global_position
				
		effects_layer.add_child(damage_number)
		damage_number.setup(damage, spawn_pos + viewport_offset)
		damage_number.play()
	else:
		# Fallback to battle view if layer missing
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(damage_number)
			damage_number.setup(damage, spawn_pos)
			damage_number.play()
		else:
			damage_number.queue_free()

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> void:
	# Reusing the logic from ProjectileAnimation, but non-blocking
	var visual_registry = animator._visual_registry
	if not visual_registry.has(target_uuid): return
	
	var target_view = visual_registry[target_uuid]
	if not is_instance_valid(target_view): return
	
	var start_pos = Vector2.ZERO
	var is_source_valid = false
	if visual_registry.has(source_uuid):
		var src_view = visual_registry[source_uuid]
		if is_instance_valid(src_view):
			var rect = src_view.get_global_rect()
			start_pos = Vector2(rect.position.x + rect.size.x / 2, rect.position.y)
			is_source_valid = true
			
	var target_rect = target_view.get_global_rect()
	var end_pos = Vector2(target_rect.position.x + target_rect.size.x / 2, target_rect.position.y)
	
	var is_self_cast = (not is_source_valid) or (source_uuid == target_uuid)
	var launch_pos = end_pos if is_self_cast else start_pos
	
	var projectile = StatProjectileScene.instantiate()
	# POOLING/LAYERING FIX: Use EffectsLayer so it renders above TopBar
	var effects_layer = animator.get_tree().get_first_node_in_group("effects_layer")
	if is_instance_valid(effects_layer):
		# Calculate Viewport Offset (TopArea height)
		var viewport_offset = Vector2.ZERO
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			var viewport = battle_view.get_viewport()
			if viewport and viewport.get_parent() is Control:
				viewport_offset = viewport.get_parent().global_position
		
		effects_layer.add_child(projectile)
		projectile.setup(amount, stat, launch_pos + viewport_offset, end_pos + viewport_offset, is_self_cast)
		projectile.launch()
	else:
		# Fallback
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(projectile)
			projectile.setup(amount, stat, launch_pos, end_pos, is_self_cast)
			projectile.launch()
		else:
			projectile.queue_free()
