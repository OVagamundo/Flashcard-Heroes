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
## @param tree: SceneTree reference for creating tweens
static func play_rejection(target: Control, tree: SceneTree) -> void:
	if not is_instance_valid(target) or not is_instance_valid(tree):
		return
	
	# Store original position
	var original_pos := target.position
	
	# Set pivot for visual effects if the target has size
	if target.size.x > 0 and target.size.y > 0:
		target.pivot_offset = target.size / 2.0
	
	# Create combined shake and flash animation
	var tween := tree.create_tween()
	tween.set_parallel(true)
	
	# Shake animation - rapid left-right oscillation
	_add_shake_keyframes(tween, target, original_pos)
	
	# Red flash on modulate
	tween.tween_property(target, "modulate", FLASH_COLOR, 0.05)
	tween.tween_property(target, "modulate", Color.WHITE, SHAKE_DURATION - 0.05).set_delay(0.05)
	
	# Ensure position resets at the end
	tween.chain().tween_callback(func():
		target.position = original_pos
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
static func _add_shake_keyframes(tween: Tween, target: Control, original_pos: Vector2) -> void:
	var shake_count := 6
	var shake_time := SHAKE_DURATION / shake_count
	
	for i in range(shake_count):
		var offset := SHAKE_INTENSITY if i % 2 == 0 else -SHAKE_INTENSITY
		# Dampen shake over time
		var dampen := 1.0 - (float(i) / shake_count)
		offset *= dampen
		
		tween.tween_property(target, "position:x", original_pos.x + offset, shake_time).set_delay(i * shake_time)
	
	# Final reset to original
	tween.tween_property(target, "position:x", original_pos.x, shake_time * 0.5).set_delay(SHAKE_DURATION)
