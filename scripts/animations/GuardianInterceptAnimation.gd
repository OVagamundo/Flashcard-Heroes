class_name GuardianInterceptAnimation
extends BattleAnimation

## Animation for Guardian Sentinel intercepting lethal damage.
## Guardian leaps to the target's position to shield them.
## After damage is dealt, the guardian returns (handled by DamageAnimation's post-damage logic).

func execute(animator: Node, _targets: Array[String], payload: Dictionary) -> void:
	var guardian_uuid: String = String(payload.get("guardian_uuid", ""))
	var original_target_uuid: String = String(payload.get("original_target_uuid", ""))
	
	if guardian_uuid.is_empty() or original_target_uuid.is_empty():
		push_warning("[GuardianInterceptAnimation] Missing guardian_uuid or original_target_uuid")
		return
	
	# Ensure this is a coroutine
	await animator.get_tree().process_frame
	
	if OS.is_debug_build():
		print("[GuardianInterceptAnimation] Guardian %s leaping to protect %s" % [guardian_uuid.substr(0, 20), original_target_uuid.substr(0, 20)])
	
	# Get view from visual registry
	var guardian_view = animator._visual_registry.get(guardian_uuid)
	var target_pos = animator.get_snapshot_position(original_target_uuid)
	
	if not is_instance_valid(guardian_view):
		push_warning("[GuardianInterceptAnimation] Guardian view not found in registry")
		return
	
	if target_pos.is_empty():
		push_warning("[GuardianInterceptAnimation] Target position snapshot not found")
		return
	
	# Leap to target's position
	if guardian_view.has_method("animate_leap_to"):
		await guardian_view.animate_leap_to(target_pos.center)
	else:
		# Fallback: instant move
		guardian_view.global_position = Vector2(
			target_pos.center.x - guardian_view.size.x / 2,
			target_pos.center.y - guardian_view.size.y / 2
		)
	
	# Mark guardian for return after damage animation completes
	# BattleAnimator checks _pending_guardian_return after DAMAGE events
	animator._pending_guardian_return = guardian_uuid
	if OS.is_debug_build():
		print("[GuardianInterceptAnimation] Leap complete, pending return after damage")
