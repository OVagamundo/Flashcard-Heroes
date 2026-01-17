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
		
		if stat == "burn_stacks":
			flash_color = Color(1.0, 0.4, 0.0) # Orange
			var _number_color = Color(1.0, 0.5, 0.1) # Bright orange (unused, kept for reference)
			animator.apply_burn_stack(target_uuid, new_val)
		elif stat == "armor_stacks":
			flash_color = Color(0.5, 0.5, 0.5) # Pure Grey (Opaque)
			var _number_color_armor = Color(0.6, 0.6, 0.6) # Grey (unused, kept for reference)
			animator.apply_armor_stack(target_uuid, new_val)
		else:
			# Generic status effect
			flash_color = Color(0.7, 0.7, 0.7)
			# Note: Floating stack numbers removed, values display in container labels
			var status_id = stat.trim_suffix("_stacks")
			animator.apply_status_stack(target_uuid, StringName(status_id), new_val)
		
		# 1. Color flash (immediate)
		if SignalBus.has_signal("unit_color_flash"):
			SignalBus.emit_signal("unit_color_flash", target_uuid, flash_color, AnimationConstants.FLASH_FADE_DURATION)
		
		# 2. Small squish deformation (subtle feedback)
		if SignalBus.has_signal("unit_deform"):
			SignalBus.emit_signal("unit_deform", target_uuid, &"SQUISH_BOUNCE")
		
		# NOTE: Stack numbers now display in the container labels with pop animation
		# (handled by GachaBallView.animate_burn_change / animate_armor_change)

	# Brief wait for visual effect completion
	await animator.get_tree().create_timer(0.3).timeout
