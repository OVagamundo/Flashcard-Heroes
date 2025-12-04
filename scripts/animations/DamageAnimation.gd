class_name DamageAnimation
extends BattleAnimation

const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")
const BUMP_DURATION = 0.5

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var skip_bump = bool(payload.get("skip_bump", false))
	var apply_poison = bool(payload.get("apply_poison", false))
	var is_poison_damage = bool(payload.get("is_poison_damage", false))
	
	# Ensure this is always a coroutine (GDScript quirk)
	await animator.get_tree().process_frame
	
	print("[DamageAnimation] Executing for targets: ", targets, " source: ", source_uuid)
	
	# 1. Trigger Bump (if applicable)
	var should_bump = (not skip_bump) and (not source_uuid.is_empty())
	if should_bump:
		var bump_dir = payload.get("bump_direction", Vector2.ZERO)
		if bump_dir != Vector2.ZERO:
			SignalBus.emit_signal("unit_bump_attack", source_uuid, bump_dir)
		else:
			# Fallback logic if direction missing (though BM provides it now)
			pass
	
	# 2. Launch Projectile (Parallel)
	var proj_data = payload.get("projectile_data", {})
	if not proj_data.is_empty():
		var p_stat = String(proj_data.get("stat", "hp"))
		var p_amount = int(proj_data.get("amount", 0))
		var p_color = String(proj_data.get("color", "red"))
		
		# Launch for each target
		for target_uuid in targets:
			_launch_projectile(animator, source_uuid, target_uuid, abs(p_amount), p_stat, p_color)

	# 3. Wait for Bump Impact (approx mid-bump)
	if should_bump:
		await animator.get_tree().create_timer(BUMP_DURATION).timeout
		
	# 4. Apply Damage (Flash + Shake + Label Update)
	var targets_new_hp = payload.get("targets_new_hp", [])
	var targets_new_poison = payload.get("targets_new_poison", [])
	
	for i in range(targets.size()):
		var target_uuid = targets[i]
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		
		# Update Label (Puppet Mode)
		animator.apply_hp_delta(target_uuid, amount, new_hp)
		
		# Apply Poison if needed
		if apply_poison:
			var new_poison = targets_new_poison[i] if i < targets_new_poison.size() else 0
			animator.apply_poison_stack(target_uuid, new_poison)
			
		# Trigger Flash
		var flash_color = Color(1.0, 0.6, 0.6) # Red
		if is_poison_damage:
			flash_color = Color(0.6, 0.2, 0.8) # Purple
		
		if SignalBus.has_signal("unit_flash_effect"):
			SignalBus.emit_signal("unit_flash_effect", target_uuid, flash_color)
			
		# Trigger Shake (New Juice!)
		# Assuming BattleView or SlotView listens for this or we add it to SignalBus
		# For now, let's assume flash implies a shake in the view, or we add a specific signal later.
		
		# Wait for flash completion
		animator._current_animation_uuid = target_uuid
		await animator.wait_for_animation_completion("flash", target_uuid)

	# Wait for bump to fully return (if we didn't wait enough)
	if should_bump:
		await animator.wait_for_animation_completion("bump", source_uuid)

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
	var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
	if is_instance_valid(battle_view):
		battle_view.add_child(projectile)
		projectile.setup(amount, stat, launch_pos, end_pos, is_self_cast)
		projectile.launch()
	else:
		projectile.queue_free()
