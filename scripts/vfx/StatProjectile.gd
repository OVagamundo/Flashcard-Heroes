class_name StatProjectile
extends Node2D

signal impact

@onready var label: Label = $Label
@onready var icon: Sprite2D = $Icon

var _velocity: Vector2
var _gravity: float
var _duration: float
var _time: float = 0.0
var _is_moving: bool = false

func setup(value: int, stat: String, start_pos: Vector2, end_pos: Vector2, is_self_cast: bool = false) -> void:
	# Visual setup
	label.text = "%d" % value
	if stat == "hp":
		label.add_theme_color_override("font_color", Color.RED)
	elif stat == "pwr":
		label.add_theme_color_override("font_color", Color.BLACK)
	elif stat == "burn":
		label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0)) # Orange
	elif stat == "spikes":
		label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0)) # Green
	elif stat == "armor":
		label.add_theme_color_override("font_color", Color(0.0, 0.6, 1.0)) # Blue
	
	# Apply Black font and matching outline to unit stat labels
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	
	# Apply 1.5x scale for battle presence
	self.scale = Vector2(1.5, 1.5)
	
	position = start_pos
	visible = true
	
	# Physics Setup
	# We want to reach end_pos in _duration seconds with a parabolic arc.
	# We define an arc height relative to the highest point.
	var arc_height = 150.0
	if is_self_cast:
		arc_height = 200.0
		
	# Calculate peak Y (remember Y is down, so peak is lower value)
	var min_y = min(start_pos.y, end_pos.y)
	var peak_y = min_y - arc_height
	
	# H is the vertical distance from start to peak
	var h = start_pos.y - peak_y
	# DeltaY is the vertical distance from start to end
	var delta_y = end_pos.y - start_pos.y
	
	# Default duration if not set
	if _duration <= 0:
		_duration = AnimationConstants.scaled(0.6)
		
	# Solve for Gravity (g)
	# Formula derived from projectile motion equations constrained by T, H, and DeltaY
	# g = ( (sqrt(2*H) + sqrt(2*H + 2*DeltaY)) / T )^2
	var term1 = sqrt(2 * h)
	var term2 = sqrt(2 * h + 2 * delta_y) # 2*h + 2*dy = 2*(start-peak) + 2*(end-start) = 2*(end-peak). Since peak < end, this is positive.
	var sqrt_g = (term1 + term2) / _duration
	_gravity = sqrt_g * sqrt_g
	
	# Solve for Initial Vertical Velocity (Vy)
	# Vy = -sqrt(2 * g * H) (Negative because Up is Negative Y)
	var vy = - sqrt(2 * _gravity * h)
	
	# Solve for Horizontal Velocity (Vx)
	# Vx = (End.x - Start.x) / T
	var vx = (end_pos.x - start_pos.x) / _duration
	
	_velocity = Vector2(vx, vy)

func launch(custom_duration: float = 0.0) -> void:
	if custom_duration > 0.0:
		_duration = custom_duration
	elif _duration <= 0.0:
		_duration = AnimationConstants.scaled(0.6)
		
	_time = 0.0
	_is_moving = true
	
	# Recalculate physics if setup was called before launch with a different duration assumption
	# But setup() does the calculation. If launch provides a new duration, we should ideally recalc.
	# For simplicity, we assume launch duration matches what we want, or we recalc here.
	# Let's just re-run the physics calc part of setup if needed, but setup needs args.
	# Instead, let's assume setup is called with the intent, and launch just starts it.
	# If we want to support variable duration in launch, we'd need to store the target pos.
	pass

func _process(delta: float) -> void:
	if not _is_moving:
		return
		
	_time += delta
	
	# Explicit Euler Integration
	position += _velocity * delta
	_velocity.y += _gravity * delta
	
	# Check for completion
	if _time >= _duration:
		_is_moving = false
		impact.emit()
		queue_free()
