class_name StatusEffectAnimation
extends BattleAnimation

## StatusEffectAnimation handles status effect stack changes.
## Provides simple visual feedback: colored flash + floating stack number.
## NO projectiles - just immediate effect application.
## Handles: burn_stacks, armor_stacks, and generic *_stacks

func execute(animator: Node, targets: Array[String], payload: Dictionary) -> void:
	var amount = int(payload.get("amount", 0))
	var stat = String(payload.get("stat", ""))
	
	if OS.is_debug_build():
		print("[StatusEffectAnimation] execute() called - stat='%s' amount=%d targets=%d" % [stat, amount, targets.size()])
	
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Get stack values from payload
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
		var number_color: Color
		
		if stat == "burn_stacks":
			flash_color = Color(1.0, 0.4, 0.0) # Orange
			number_color = Color(1.0, 0.5, 0.1) # Bright orange
			animator.apply_burn_stack(target_uuid, new_val)
		elif stat == "armor_stacks":
			flash_color = Color(0.5, 0.5, 0.5) # Pure Grey (Opaque)
			number_color = Color(0.6, 0.6, 0.6) # Grey
			animator.apply_armor_stack(target_uuid, new_val)
		else:
			# Generic status effect
			flash_color = Color(0.7, 0.7, 0.7)
			number_color = Color(0.6, 0.6, 0.6)
			var status_id = stat.trim_suffix("_stacks")
			animator.apply_status_stack(target_uuid, StringName(status_id), new_val)
		
		# 1. Color flash (immediate)
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		
		# 2. Small squish deformation (subtle feedback)
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", target_uuid, &"SQUISH_BOUNCE")
		
		# 3. Spawn floating stack number (like damage numbers but colored)
		_spawn_floating_stack_number(animator, target_uuid, amount, number_color)

	# Brief wait for visual effect completion
	await animator.get_tree().create_timer(0.3).timeout

## Spawn a colored floating number showing stack change (like damage numbers)
func _spawn_floating_stack_number(animator: Node, target_uuid: String, amount: int, color: Color) -> void:
	# Get target position from visual registry (current position)
	var target_view = animator._visual_registry.get(target_uuid)
	var spawn_pos = Vector2.ZERO
	var found_pos = false
	
	if is_instance_valid(target_view) and target_view.is_inside_tree():
		# Offset slightly up and to the side to not overlap damage numbers
		spawn_pos = target_view.global_position + (target_view.size * Vector2(0.6, 0.2))
		found_pos = true
	else:
		# Fallback: Use snapshot
		var tgt_snap = animator.get_snapshot_position(target_uuid)
		if not tgt_snap.is_empty():
			spawn_pos = Vector2(tgt_snap.position.x + tgt_snap.size.x * 0.6, tgt_snap.position.y + tgt_snap.size.y * 0.2)
			found_pos = true
	
	if found_pos and amount != 0:
		# Spawn the floating number with custom color
		var damage_number = VFXFactory.create_damage_number()
		var effects_layer = VFXFactory.get_effects_layer()
		
		if is_instance_valid(effects_layer):
			var offset = VFXFactory.get_viewport_offset()
			effects_layer.add_child(damage_number)
			damage_number.setup(abs(amount), spawn_pos + offset, color)
			damage_number.play()
		elif is_instance_valid(animator):
			var battle_view = animator.get_tree().get_first_node_in_group("battle_view")
			if is_instance_valid(battle_view):
				battle_view.add_child(damage_number)
				damage_number.setup(abs(amount), spawn_pos, color)
				damage_number.play()
			else:
				damage_number.queue_free()
		else:
			damage_number.queue_free()
