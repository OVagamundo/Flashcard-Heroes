class_name ProjectileAnimation
extends BattleAnimation

const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var stat = String(payload.get("stat", "hp"))
	var amount = int(payload.get("amount", 0))
	var color_hint = String(payload.get("color", "red"))
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Get visual registry from animator
	var source_uuid = String(payload.get("source_uuid", "")) # Passed in payload or context
	
	# If source_uuid is missing from payload, check if it's in the event context (BattleAnimator might need to pass it)
	# For now, we assume payload has it or we can't find source.
	
	# DECOUPLING FIX: Use position snapshots instead of visual_registry
	# Determine start position from snapshot
	var start_pos = Vector2.ZERO
	var is_source_valid = false
	var src_snap = animator.get_snapshot_position(source_uuid)
	if not src_snap.is_empty():
		start_pos = Vector2(src_snap.position.x + src_snap.size.x / 2, src_snap.position.y)
		is_source_valid = true
	
	# Iterate through targets
	for target_uuid in targets:
		var tgt_snap = animator.get_snapshot_position(target_uuid)
		if tgt_snap.is_empty():
			continue
			
		var end_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x / 2, tgt_snap.position.y)
		
		# Handle self-cast or invalid source
		var is_self_cast = false
		var launch_pos = start_pos
		
		if not is_source_valid or source_uuid == target_uuid:
			is_self_cast = true
			launch_pos = end_pos
		
		# Instantiate and launch
		var projectile = StatProjectileScene.instantiate()
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(projectile)
			projectile.setup(abs(amount), stat, launch_pos, end_pos, is_self_cast)
			projectile.launch()
			
			# We await each impact to keep the "one by one" feel if multiple targets
			# Or we can just let them fly. The original logic awaited.
			# Since execute() is async (awaited by animator), we should await here if we want sequential.
			await projectile.impact
		else:
			projectile.queue_free()
