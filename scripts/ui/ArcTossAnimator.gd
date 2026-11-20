# res://scripts/ui/ArcTossAnimator.gd
class_name ArcTossAnimator
extends RefCounted

## Shared node-bound parabolic & quadratic Bezier toss animator.
## Replaces duplicated arc tween boilerplate across Reward, Shop, RestSite,
## Shrine, UnitTrainingGround, MergeAnimator, BattleView, and BattleAnimator.
## Every Tween is strictly bound to the flying CanvasItem node (zero dangling tweens)
## and obeys the single-scaling rule (AnimationConstants.scaled applied at most once).


static func evaluate_bezier(start_pos: Vector2, control_point: Vector2, end_pos: Vector2, eased_t: float) -> Vector2:
	var inv_t: float = 1.0 - eased_t
	return (inv_t * inv_t * start_pos) + (2.0 * inv_t * eased_t * control_point) + (eased_t * eased_t * end_pos)


static func evaluate_parabola(start_pos: Vector2, end_pos: Vector2, arc_height: float, t: float) -> Vector2:
	var curr_x: float = lerpf(start_pos.x, end_pos.x, t)
	var curr_y: float = lerpf(start_pos.y, end_pos.y, t) - (4.0 * arc_height * t * (1.0 - t))
	return Vector2(curr_x, curr_y)


static func _compute_scale_t(t: float, scale_curve: StringName) -> float:
	match scale_curve:
		&"quad_out":
			return 1.0 - pow(1.0 - t, 2.0)
		&"ramp_10x":
			return clampf(t * 10.0, 0.0, 1.0)
		&"linear":
			return t
		_:
			assert(false, "ArcTossAnimator: Unknown scale_curve '%s'" % String(scale_curve))
			return t


static func _apply_transform(node: CanvasItem, pos: Vector2, pivot: Vector2, animate_scale: bool, current_scale: float, scale_pivot_offset: bool) -> void:
	var offset: Vector2 = pivot * current_scale if scale_pivot_offset else pivot
	if node is Control:
		var ctrl := node as Control
		if animate_scale:
			ctrl.scale = Vector2(current_scale, current_scale)
		ctrl.global_position = pos - offset
	elif node is Node2D:
		var n2d := node as Node2D
		if animate_scale:
			n2d.scale = Vector2(current_scale, current_scale)
		n2d.global_position = pos - offset
	else:
		assert(false, "ArcTossAnimator: Expected Control or Node2D, got %s" % node.get_class())


## Animates `node` along a quadratic Bezier arc from `start_center` to `end_center`.
## Options:
## - arc_height (float, default 200.0)
## - duration (float, default 0.45)
## - scale_duration (bool, default false): apply AnimationConstants.scaled(duration) once
## - ease_power (float, default 1.0): pow(t, ease_power)
## - start_scale (float, default 1.0), end_scale (float, default 1.0), animate_scale (bool, default false)
## - scale_curve (StringName, default &"quad_out"): &"quad_out", &"linear", &"ramp_10x"
## - pivot (Vector2, default node.pivot_offset for Control or Vector2.ZERO for Node2D)
## - scale_pivot_offset (bool, default false)
## - on_step (Callable): optional callback invoked with raw t each tick
static func toss_bezier(node: CanvasItem, start_center: Vector2, end_center: Vector2, options: Dictionary = {}) -> Tween:
	assert(is_instance_valid(node), "ArcTossAnimator.toss_bezier: node must be valid")
	var arc_height: float = float(options.get("arc_height", 200.0))
	var raw_duration: float = float(options.get("duration", 0.45))
	var scale_duration: bool = bool(options.get("scale_duration", false))
	var duration: float = AnimationConstants.scaled(raw_duration) if scale_duration else raw_duration
	var ease_power: float = float(options.get("ease_power", 1.0))
	var start_scale: float = float(options.get("start_scale", 1.0))
	var end_scale: float = float(options.get("end_scale", 1.0))
	var animate_scale: bool = bool(options.get("animate_scale", not is_equal_approx(start_scale, end_scale)))
	var scale_curve: StringName = StringName(options.get("scale_curve", &"quad_out"))
	var default_pivot: Vector2 = (node as Control).pivot_offset if node is Control else Vector2.ZERO
	var pivot: Vector2 = options.get("pivot", default_pivot) as Vector2
	var scale_pivot_offset: bool = bool(options.get("scale_pivot_offset", false))
	var on_step: Callable = options.get("on_step", Callable())

	var control_point := Vector2(
		(start_center.x + end_center.x) * 0.5,
		minf(start_center.y, end_center.y) - arc_height
	)

	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(t: float) -> void:
		var eased_t: float = pow(t, ease_power) if not is_equal_approx(ease_power, 1.0) else t
		var current_scale: float = lerpf(start_scale, end_scale, _compute_scale_t(t, scale_curve)) if animate_scale else 1.0
		var pos: Vector2 = evaluate_bezier(start_center, control_point, end_center, eased_t)
		_apply_transform(node, pos, pivot, animate_scale, current_scale, scale_pivot_offset)
		if on_step.is_valid():
			on_step.call(t)
	, 0.0, 1.0, duration)
	return tween


## Animates `node` along a kinematic parabolic arc from `start_center` to `end_center`.
## Options:
## - arc_height (float, default 500.0)
## - duration (float, default 0.7)
## - scale_duration (bool, default true): apply AnimationConstants.scaled(duration) once
## - start_scale (float, default 1.0), end_scale (float, default 1.0), animate_scale (bool, default false)
## - scale_curve (StringName, default &"ramp_10x")
## - pivot (Vector2, default node.pivot_offset for Control or Vector2.ZERO for Node2D)
## - scale_pivot_offset (bool, default false)
## - on_step (Callable): optional callback invoked with raw t each tick
static func toss_parabolic(node: CanvasItem, start_center: Vector2, end_center: Vector2, options: Dictionary = {}) -> Tween:
	assert(is_instance_valid(node), "ArcTossAnimator.toss_parabolic: node must be valid")
	var arc_height: float = float(options.get("arc_height", 500.0))
	var raw_duration: float = float(options.get("duration", 0.7))
	var scale_duration: bool = bool(options.get("scale_duration", true))
	var duration: float = AnimationConstants.scaled(raw_duration) if scale_duration else raw_duration
	var start_scale: float = float(options.get("start_scale", 1.0))
	var end_scale: float = float(options.get("end_scale", 1.0))
	var animate_scale: bool = bool(options.get("animate_scale", not is_equal_approx(start_scale, end_scale)))
	var scale_curve: StringName = StringName(options.get("scale_curve", &"ramp_10x"))
	var default_pivot: Vector2 = (node as Control).pivot_offset if node is Control else Vector2.ZERO
	var pivot: Vector2 = options.get("pivot", default_pivot) as Vector2
	var scale_pivot_offset: bool = bool(options.get("scale_pivot_offset", false))
	var on_step: Callable = options.get("on_step", Callable())

	var tween: Tween = node.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(t: float) -> void:
		var current_scale: float = lerpf(start_scale, end_scale, _compute_scale_t(t, scale_curve)) if animate_scale else 1.0
		var pos: Vector2 = evaluate_parabola(start_center, end_center, arc_height, t)
		_apply_transform(node, pos, pivot, animate_scale, current_scale, scale_pivot_offset)
		if on_step.is_valid():
			on_step.call(t)
	, 0.0, 1.0, duration)
	return tween
