class_name SummonAnimation
extends BattleAnimation

func execute(animator: Node, targets: Array[String], _payload: Dictionary) -> void:
	# Summons are handled by BattleAnimator pre-registration
	# This animation only triggers the fade-in visual effect
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	# Units are already registered and visible - just trigger fade-in animation
	for target_uuid in targets:
		if SignalBus.has_signal("unit_summon_fade"):
			SignalBus.emit_signal("unit_summon_fade", target_uuid)
			
		# Wait for appear animation
		await animator.wait_for_animation_completion("summon_fade", target_uuid)
