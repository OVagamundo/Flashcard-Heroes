class_name BuffAnimation
extends BattleAnimation

const StatProjectileScene = preload("res://scenes/vfx/StatProjectile.tscn")

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var source_uuid = String(payload.get("source_uuid", ""))
	var amount = int(payload.get("amount", 0))
	var stat = String(payload.get("stat", "pwr"))
	
	print("[BuffAnimation] execute() called - stat='%s' amount=%d targets=%d" % [stat, amount, targets.size()])
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles
	var projectiles = []
	var color_hint = "black" if stat == "pwr" else "orange"
	
	for target_uuid in targets:
		var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), stat, color_hint)
		if proj: projectiles.append(proj)
		
	# Wait for impact
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
		
		if stat == "pwr":
			var new_pwr = 0
			if not pwr_values.is_empty() and i < pwr_values.size():
				new_pwr = int(pwr_values[i])
			else:
				new_pwr = int(payload.get("new_pwr", 0)) # Fallback
				
			animator.apply_pwr_delta(target_uuid, amount, new_pwr)
			
			if SignalBus.has_signal("unit_flash_effect"):
				# Use Pure Yellow (1, 1, 0) so G >= R is true -> Triggers HOP animation
				SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(1.0, 1.0, 0.4))
				
		elif stat == "burn_stacks":
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
				
			animator.apply_burn_stack(target_uuid, new_val)
			if SignalBus.has_signal("unit_flash_effect"):
				SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(1.0, 0.4, 0.0)) # Orange
		
		elif stat == "armor_stacks":
			# Dedicated armor handler - same pattern as burn
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
				
			animator.apply_armor_stack(target_uuid, new_val)
			if SignalBus.has_signal("unit_flash_effect"):
				SignalBus.emit_signal("unit_flash_effect", target_uuid, Color(0.7, 0.7, 0.8)) # Silver/grey for armor
		
		elif stat.ends_with("_stacks"):
			# Generic status effect handling (armor_stacks, etc.)
			var status_id = stat.trim_suffix("_stacks")
			var new_val = 0
			if not burn_values.is_empty() and i < burn_values.size():
				new_val = int(burn_values[i])
			else:
				new_val = int(payload.get("new_val", 0)) # Fallback
			
			print("[BuffAnimation] Applying status '%s' new_val=%d to %s" % [status_id, new_val, target_uuid])
			animator.apply_status_stack(target_uuid, StringName(status_id), new_val)
			if SignalBus.has_signal("unit_flash_effect"):
				# Use grey flash for armor, default for others
				var flash_color = Color(0.7, 0.7, 0.7) if status_id == "armor" else Color(0.8, 0.8, 0.8)
				SignalBus.emit_signal("unit_flash_effect", target_uuid, flash_color)

	# Wait for animation completion (just wait for the last one, as they run in parallel)
	if final_target_uuid != "":
		animator._current_animation_uuid = final_target_uuid
		await animator.wait_for_animation_completion("flash", final_target_uuid)

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
		projectile.setup(amount, stat, launch_pos + viewport_offset, end_pos + viewport_offset, is_self_cast)
		projectile.launch()
		return projectile
	else:
		# Fallback
		var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
		if is_instance_valid(battle_view):
			battle_view.add_child(projectile)
			projectile.setup(amount, stat, launch_pos, end_pos, is_self_cast)
			projectile.launch()
			return projectile
		else:
			projectile.queue_free()
			return null
