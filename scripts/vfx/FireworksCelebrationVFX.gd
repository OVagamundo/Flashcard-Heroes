# res://scripts/vfx/FireworksCelebrationVFX.gd
class_name FireworksCelebrationVFX
extends Control

## Celebratory fireworks effect for mid-game flashcard unlocks.
## Bursts multiple vibrant firework sparks with additive blending around the target area.

const FIRE_TEXTURE = preload("res://assets/Realistic/ui/textures/FireBall.png")

const PALETTES: Array[Color] = [
	Color(1.0, 0.85, 0.2),  # Gold
	Color(0.2, 0.9, 1.0),   # Cyan
	Color(1.0, 0.2, 0.85),  # Magenta
	Color(0.4, 1.0, 0.3),   # Lime
	Color(1.0, 0.55, 0.1),  # Orange
	Color(0.6, 0.3, 1.0),   # Purple
	Color(1.0, 1.0, 1.0),   # Pure White
]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func play(target_global_rect: Rect2) -> void:
	"""Triggers staggered firework bursts around and over the target rect"""
	var center = target_global_rect.get_center()
	var half_w = target_global_rect.size.x * 0.45
	var half_h = target_global_rect.size.y * 0.4

	# Define burst positions relative to the target rect
	var burst_positions: Array[Vector2] = [
		center + Vector2(-half_w, -half_h * 0.8), # Top-Left
		center + Vector2(half_w, -half_h * 0.8),  # Top-Right
		center + Vector2(0.0, -half_h * 1.1),     # Top-Center High
		center + Vector2(-half_w * 0.6, half_h * 0.5), # Bottom-Left
		center + Vector2(half_w * 0.6, half_h * 0.5),  # Bottom-Right
		center                                    # Center Burst
	]

	var delay: float = 0.0
	for pos in burst_positions:
		_spawn_burst(pos, delay)
		delay += 0.08

	# Automatically cleanup after all bursts expire
	var cleanup_timer = get_tree().create_timer(delay + 1.2)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

func _spawn_burst(global_pos: Vector2, delay: float) -> void:
	var tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		if not is_instance_valid(self):
			return
		_create_particle_burst(global_pos)
	)

func _create_particle_burst(global_pos: Vector2) -> void:
	var particles := GPUParticles2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = mat
	particles.texture = FIRE_TEXTURE
	particles.amount = 32
	particles.lifetime = 0.75
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.global_position = global_pos

	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc_mat.emission_sphere_radius = 8.0
	proc_mat.direction = Vector3(0, -1, 0)
	proc_mat.spread = 180.0 # Full 360-degree radial explosion
	proc_mat.initial_velocity_min = 160.0
	proc_mat.initial_velocity_max = 340.0
	proc_mat.gravity = Vector3(0, 220, 0)
	proc_mat.damping_min = 40.0
	proc_mat.damping_max = 70.0
	proc_mat.scale_min = 0.25
	proc_mat.scale_max = 0.6

	# Pick random vibrant color from palette
	var color = PALETTES.pick_random()
	proc_mat.color = color

	particles.process_material = proc_mat
	add_child(particles)
	particles.emitting = true

	# Expanding center flash flare
	var flash := Sprite2D.new()
	flash.texture = FIRE_TEXTURE
	flash.material = mat
	flash.global_position = global_pos
	flash.modulate = color.lightened(0.5)
	flash.scale = Vector2(0.2, 0.2)
	add_child(flash)

	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flash_tween.chain().tween_callback(flash.queue_free)
