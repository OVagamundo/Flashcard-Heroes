class_name HealAnimation
extends BattleAnimation

const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")

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
		
		if SignalBus.has_signal("unit_flash_effect"):
			SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(0.6, 1.0, 0.6)) # Green
			
		# TODO: Spawn Floating Hearts here
		
		animator._current_animation_uuid = target_uuid
		await animator.wait_for_animation_completion("flash", target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	# DECOUPLING FIX: Use position snapshots instead of visual_registry
	var tgt_snap = animator.get_snapshot_position(target_uuid)
	if tgt_snap.is_empty(): return null
	
	var start_pos = Vector2.ZERO
	var is_source_valid = false
	var src_snap = animator.get_snapshot_position(source_uuid)
	if not src_snap.is_empty():
		start_pos = Vector2(src_snap.position.x + src_snap.size.x / 2, src_snap.position.y)
		is_source_valid = true
	
	var end_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y)
	
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
		projectile.setup(amount, "hp", launch_pos + viewport_offset, end_pos + viewport_offset, is_self_cast)
		projectile.launch()
		return projectile
	else:
		# Fallback
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(projectile)
			projectile.setup(amount, "hp", launch_pos, end_pos, is_self_cast)
			projectile.launch()
			return projectile
		else:
			projectile.queue_free()
			return null
