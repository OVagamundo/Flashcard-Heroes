# res://scripts/vfx/RejectionFeedback.gd
class_name RejectionFeedback
extends RefCounted

## Static utility class providing rejection feedback animations (shake + red flash)
## Used when player attempts to spend tokens/gold they don't have

const SHAKE_DURATION := 0.4
const SHAKE_INTENSITY := 8.0
const FLASH_COLOR := Color(1.0, 0.3, 0.3, 1.0) # Red flash


## Play rejection feedback on a Control node (shake + red flash)
## @param target: The Control to animate
## @param _tree: Legacy parameter kept for call-site compatibility (tween is bound to target)
static func play_rejection(target: Control, _tree: SceneTree = null) -> void:
	assert(is_instance_valid(target), "RejectionFeedback.play_rejection: target must be valid")
	
	# AUDIO HOOK: Rejection sound
	Audio.play_sfx("ui_rejection")

	# Kill any in-flight rejection tween on this target and restore canonical rest pose
	if target.has_meta(&"_rejection_tween"):
		var prev_tween: Variant = target.get_meta(&"_rejection_tween")
		if prev_tween is Tween and prev_tween.is_valid():
			prev_tween.kill()
	target.rotation = 0.0
	target.modulate = Color.WHITE
	
	# Set pivot for visual effects if the target has size
	if target.size.x > 0 and target.size.y > 0:
		target.pivot_offset = target.size / 2.0
	
	# Node-bound tween: automatically freed if target leaves tree
	var tween: Tween = target.create_tween()
	target.set_meta(&"_rejection_tween", tween)
	tween.set_parallel(true)
	
	# Shake animation around canonical rest rotation (0.0) so rapid clicks never tilt permanently
	_add_shake_keyframes(tween, target, 0.0)
	
	# Red flash on modulate
	tween.tween_property(target, "modulate", FLASH_COLOR, 0.05)
	tween.tween_property(target, "modulate", Color.WHITE, SHAKE_DURATION - 0.05).set_delay(0.05)
	
	# Ensure canonical rest pose at the end
	tween.chain().tween_callback(func() -> void:
		target.rotation = 0.0
		target.modulate = Color.WHITE
	)


## Play rejection feedback on a Control and also flash the related counter
## @param target: The Control to animate (machine or button)
## @param counter_group: The counter group to also flash (TokenGroup or GoldGroup)
## @param tree: SceneTree reference for creating tweens
static func play_rejection_with_counter(target: Control, counter_group: Control, tree: SceneTree) -> void:
	play_rejection(target, tree)
	if is_instance_valid(counter_group):
		play_rejection(counter_group, tree)


## Internal helper to add shake keyframes
static func _add_shake_keyframes(tween: Tween, target: Control, original_rotation: float) -> void:
	var shake_count := 6
	var shake_time := SHAKE_DURATION / shake_count
	var intensity_rad := deg_to_rad(5.0) # 5 degrees shake
	
	for i in range(shake_count):
		var offset := intensity_rad if i % 2 == 0 else -intensity_rad
		# Dampen shake over time
		var dampen := 1.0 - (float(i) / shake_count)
		offset *= dampen
		
		tween.tween_property(target, "rotation", original_rotation + offset, shake_time).set_delay(i * shake_time)
	
	# Final reset to original
	tween.tween_property(target, "rotation", original_rotation, shake_time * 0.5).set_delay(SHAKE_DURATION)
