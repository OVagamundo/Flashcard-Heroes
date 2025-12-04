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
		var new_hp = targets_new_hp[i] if i < targets_new_hp.size() else 0
		
		animator.apply_hp_delta(target_uuid, amount, new_hp)
		
		if SignalBus.has_signal("unit_flash_effect"):
			SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(0.6, 1.0, 0.6)) # Green
			
		# TODO: Spawn Floating Hearts here
		
		animator._current_animation_uuid = target_uuid
		await animator.wait_for_animation_completion("flash", target_uuid)

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	var visual_registry = animator._visual_registry
	if not visual_registry.has(target_uuid): return null
	
	var target_view = visual_registry[target_uuid]
	if not is_instance_valid(target_view): return null
	
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
		return projectile
	else:
		projectile.queue_free()
		return null
