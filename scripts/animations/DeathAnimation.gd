class_name DeathAnimation
extends BattleAnimation

func execute(animator: Node, targets: Array[String], _payload: Dictionary) -> void:
	# Ensure coroutine
	await animator.get_tree().process_frame
	
	for target_uuid in targets:
		if SignalBus.has_signal("unit_death_fade"):
			SignalBus.emit_signal("unit_death_fade", target_uuid, false)
			
		await animator.wait_for_animation_completion("death_fade", target_uuid)
		
		# Cleanup from registry
		if animator._visual_registry.has(target_uuid):
			animator._visual_registry.erase(target_uuid)
