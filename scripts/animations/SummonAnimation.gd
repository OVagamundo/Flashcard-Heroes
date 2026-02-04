class_name SummonAnimation
extends BattleAnimation

const AC = preload("res://scripts/animations/AnimationConstants.gd")

func execute(animator: Node, targets: Array[String], _payload: Dictionary) -> void:
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Units are already registered and visible - just trigger fade-in animation
	var style = _payload.get("visual_style", "")
	
	for target_uuid in targets:
		if style == "yellow_flash":
			var view = animator._visual_registry.get(target_uuid)
			if is_instance_valid(view):
				# Standard Summon Physics Calculation
				var original_position = view.position
				var start_position = Vector2(original_position.x, original_position.y - AC.SUMMON_DROP_HEIGHT)
				
				# Set Initial State: Floating, Bright Yellow (opaque)
				view.position = start_position
				view.modulate = Color(2.5, 2.5, 0.5, 1.0)
				
				# SPEED FACTOR: 0.3x duration
				var speed_factor = 0.3
				
				var tween = animator.create_tween()
				
				# Phase 1: Drop + Color Fade (to normal)
				tween.set_parallel(true)
				tween.tween_property(view, "position", original_position, AC.SUMMON_DROP_DURATION * speed_factor).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.tween_property(view, "modulate", Color.WHITE, AC.SUMMON_FADE_DURATION * speed_factor).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.set_parallel(false)
				
				# Simplified landing bounce (scale entire view slightly)
				tween.tween_property(view, "scale", Vector2(1.2, 0.8), AC.DEFORM_DURATION * speed_factor).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(view, "scale", Vector2.ONE, AC.DEFORM_DURATION * 2 * speed_factor).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				
				await tween.finished
		else:
			# Standard Fade-In
			if SignalBus.has_signal("unit_summon_fade"):
				SignalBus.emit_signal("unit_summon_fade", target_uuid)
				
			# Wait for appear animation
			await animator.wait_for_animation_completion("summon_fade", target_uuid)
