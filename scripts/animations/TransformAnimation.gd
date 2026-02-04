class_name TransformAnimation
extends BattleAnimation

const AC = preload("res://scripts/animations/AnimationConstants.gd")

func execute(animator: Node, targets: Array[String], _payload: Dictionary) -> void:
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# SPEED FACTOR: Make transformation faster than standard death (snappier feel)
	var speed_factor = 0.3
	
	for target_uuid in targets:
		var view = animator._visual_registry.get(target_uuid)
		if not is_instance_valid(view):
			continue
			
		# 1. HOP Animation (Keep the hop as pre-transformation anticipation)
		SignalBus.emit_signal("unit_move", target_uuid, &"HOP", Vector2.ZERO)
		SignalBus.emit_signal("unit_deform", target_uuid, &"HOP_DEFORM")
		await animator.wait_for_animation_completion("move", target_uuid)
		
		# 2. TRANSFORM Transition (Golden Death)
		# Replicates standard Death Animation physics (Levitate) but fades to opaque yellow instead of alpha 0
		if is_instance_valid(view):
			var original_position = view.position
			var levitate_target = Vector2(original_position.x, original_position.y - AC.DEATH_LEVITATE_HEIGHT)
			
			var tween = animator.create_tween()
			tween.set_parallel(true)
			
			# Physics: Levitate (Matches DeathAnimation) - FASTER
			tween.tween_property(view, "position", levitate_target, AC.DEATH_DURATION * speed_factor).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
			# Color: Fade to Bright Yellow (Matches user request) - FASTER
			var flash_color = Color(2.5, 2.5, 0.5, 1.0)
			tween.tween_property(view, "modulate", flash_color, AC.DEATH_DURATION * speed_factor).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
			await tween.finished
			
			# 3. Cleanup
			if animator._visual_registry.has(target_uuid):
				animator._visual_registry.erase(target_uuid)
			view.queue_free()
