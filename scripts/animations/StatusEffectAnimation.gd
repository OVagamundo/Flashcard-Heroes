class_name StatusEffectAnimation
extends BattleAnimation

## StatusEffectAnimation handles status effect stack changes.
## Provides simple visual feedback: colored flash + floating stack number.
## NO projectiles - just immediate effect application.
## Handles: burn_stacks, armor_stacks, and generic *_stacks

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var amount = int(payload.get("amount", 0))
	var stat = String(payload.get("stat", ""))
	
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# 1. Launch Projectiles (if source is provided)
	var projectiles = []
	var source_uuid = String(payload.get("source_uuid", ""))
	
	# Only use projectiles for positive "buff" style effects when a source exists
	var use_projectiles = not source_uuid.is_empty() and amount > 0
	
	if use_projectiles:
		var color_hint = "white"
		if stat == "armor_stacks": color_hint = "white"
		elif stat == "burn_stacks": color_hint = "orange"
		
		for target_uuid in targets:
			var proj = _launch_projectile(animator, source_uuid, target_uuid, abs(amount), stat, color_hint)
			if proj: projectiles.append(proj)
			
	# Wait for impact if using projectiles
	if use_projectiles and not projectiles.is_empty():
		for proj in projectiles:
			if is_instance_valid(proj):
				await proj.impact
	elif use_projectiles:
		# Fallback for missing snapshots
		await animator.get_tree().create_timer(AnimationConstants.scaled(0.4)).timeout

	# 2. Apply Stat Buff / Status Effect
	var stack_values = payload.get("targets_new_val", [])
	for i in range(targets.size()):
		var target_uuid = targets[i]
		
		# Skip targets not in visual registry
		if not animator._visual_registry.has(target_uuid):
			continue
		
		# Get new stack value
		var new_val = 0
		if not stack_values.is_empty() and i < stack_values.size():
			new_val = int(stack_values[i])
		else:
			new_val = int(payload.get("new_val", 0)) # Fallback
		
		# Determine color and effect based on stat type
		var flash_color: Color
		
		if stat == "burn_stacks":
			flash_color = Color(1.0, 0.4, 0.0) # Orange
			animator.apply_burn_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "burn")
		elif stat == "armor_stacks":
			flash_color = Color(0.5, 0.5, 0.5) # Pure Grey
			animator.apply_armor_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "armor")
		elif stat == "spikes_stacks" or stat == "spikes":
			flash_color = Color(0.8, 0.1, 0.1) # Reddish for spikes
			animator.apply_spikes_stack(target_uuid, new_val)
			_spawn_floating_status(animator, target_uuid, amount, "spikes")
		elif stat == "static_stacks" or stat == "static":
			flash_color = Color(1.0, 0.85, 0.1) # Yellow
			animator.apply_status_stack(target_uuid, &"static", new_val)
			_spawn_floating_status(animator, target_uuid, amount, "static")
		else:
			# Generic status effect
			flash_color = Color(0.7, 0.7, 0.7)
			var status_id = stat.trim_suffix("_stacks")
			animator.apply_status_stack(target_uuid, StringName(status_id), new_val)
		
		# Feedback: Color flash
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		
		# Feedback: Small squish deformation
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", target_uuid, &"SQUISH_BOUNCE")

	# Wait for visual effect completion
	await animator.get_tree().create_timer(AnimationConstants.scaled(0.2)).timeout

func _launch_projectile(animator: Node, source_uuid: String, target_uuid: String, amount: int, stat: String, _color_hint: String) -> Node:
	# Use "buff" style projectiles for status effects
	# Determine projectile type from stat name
	var projectile_stat = "hp" # Fallback
	if stat == "armor_stacks": projectile_stat = "armor"
	elif stat == "burn_stacks": projectile_stat = "burn"
	elif stat == "spikes_stacks" or stat == "spikes": projectile_stat = "spikes"
	
	return VFXFactory.launch_projectile_between(animator, source_uuid, target_uuid, amount, projectile_stat)

func _spawn_floating_status(animator: Node, target_uuid: String, amount: int, type: String) -> void:
	var view = animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(view) and view.is_inside_tree():
		spawn_pos = view.global_position + (view.size * Vector2(0.5, 0.3))
		found_pos = true
	else:
		var snap = animator.get_snapshot_position(target_uuid)
		if not snap.is_empty():
			spawn_pos = Vector2(snap.position.x + snap.size.x / 2, snap.position.y + snap.size.y * 0.3)
			found_pos = true
			
	if found_pos and amount != 0:
		VFXFactory.spawn_status_effect_number_on_layer(abs(amount), type, spawn_pos)
