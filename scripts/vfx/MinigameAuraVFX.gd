extends Control
class_name MinigameAuraVFX

@onready var top_particles: GPUParticles2D = $TopParticles
@onready var bottom_particles: GPUParticles2D = $BottomParticles
@onready var left_particles: GPUParticles2D = $LeftParticles
@onready var right_particles: GPUParticles2D = $RightParticles

func _ready() -> void:
	# Hide all initially
	set_intensity(0, Color.WHITE)
	
	# Connect to resize signal so it automatically adjusts
	resized.connect(_on_resized)
	
	# Wait one frame for sizes to settle then adjust
	call_deferred("_on_resized")

func _on_resized() -> void:
	if not is_instance_valid(top_particles): return
	
	var w = size.x
	var h = size.y
	
	# Position at the center of the respective edges
	top_particles.position = Vector2(w / 2.0, 0)
	bottom_particles.position = Vector2(w / 2.0, h)
	left_particles.position = Vector2(0, h / 2.0)
	right_particles.position = Vector2(w, h / 2.0)
	
	# Set emission box extents to match the length of the edge
	_set_emission_extents(top_particles, w / 2.0, 10.0)
	_set_emission_extents(bottom_particles, w / 2.0, 10.0)
	_set_emission_extents(left_particles, 10.0, h / 2.0)
	_set_emission_extents(right_particles, 10.0, h / 2.0)

func _set_emission_extents(p: GPUParticles2D, ext_x: float, ext_y: float) -> void:
	if p.process_material is ParticleProcessMaterial:
		var mat = p.process_material as ParticleProcessMaterial
		# Clone material so they don't all share the exact same shape size
		if not mat.resource_local_to_scene:
			mat = mat.duplicate()
			p.process_material = mat
			mat.resource_local_to_scene = true
		mat.emission_box_extents = Vector3(ext_x, ext_y, 1)

func set_intensity(streak: int, base_color: Color) -> void:
	var emitters = [top_particles, bottom_particles, left_particles, right_particles]
	
	if streak <= 0:
		for p in emitters:
			if is_instance_valid(p): p.emitting = false
		return
		
	# Smoothly scale intensity up with every single correct answer
	var amount = 15 + (streak * 30)
	var speed_scale = minf(0.5 + (streak * 0.15), 2.5)
	var scale_min = minf(0.5 + (streak * 0.2), 3.0)
	var scale_max = minf(1.0 + (streak * 0.3), 5.0)
	
	var glow_color = Color(0.2, 0.8, 0.2, 1.0) # Green (Base)
	
	if streak >= 9:
		glow_color = Color(1.0, 0.4, 0.9, 1.0) # Magenta/Pink
	elif streak >= 7:
		glow_color = Color(1.0, 0.8, 0.2, 1.0) # Gold
	elif streak >= 5:
		glow_color = Color(0.4, 0.8, 1.0, 1.0) # Cyan
	elif streak >= 3:
		glow_color = Color(0.2, 1.0, 0.8, 1.0) # Light Green/Cyan
		
	for p in emitters:
		if not is_instance_valid(p): continue
		p.emitting = true
		
		# Since we have 4 emitters now, we divide the amount so it's not overwhelming, 
		# but keep the edges dense.
		p.amount = max(amount / 2, 10)
		p.speed_scale = speed_scale
		
		if p.process_material is ParticleProcessMaterial:
			var mat = p.process_material as ParticleProcessMaterial
			mat.scale_min = scale_min
			mat.scale_max = scale_max
			mat.color = glow_color
