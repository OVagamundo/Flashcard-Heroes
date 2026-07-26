class_name BuffNumberProjectile
extends Node2D

signal impact

@onready var label: Label = $Label
@onready var icon: Sprite2D = $Icon

var _velocity: Vector2
var _gravity: float
var _duration: float
var _time: float = 0.0
var _is_moving: bool = false

var _start_pos: Vector2
var _end_pos: Vector2
var _is_self_cast: bool

func setup(value: int, stat: String, start_pos: Vector2, end_pos: Vector2, is_self_cast: bool = false) -> void:
	_start_pos = start_pos
	_end_pos = end_pos
	_is_self_cast = is_self_cast

	# Visual setup
	if value >= 0:
		label.text = "+%d" % value
	else:
		label.text = "%d" % value  # Negative sign included automatically
	icon.visible = false # Buff numbers never show an icon
	label.visible = true
	
	# Handle specific stat visuals
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
	
	if _duration <= 0:
		_duration = AnimationConstants.scaled(0.6)
		
	_recalculate_physics()

func launch(custom_duration: float = 0.0) -> void:
	if custom_duration > 0.0:
		_duration = custom_duration
	elif _duration <= 0.0:
		_duration = AnimationConstants.scaled(0.6)
		
	_recalculate_physics()
	_time = 0.0
	_is_moving = true

func _recalculate_physics() -> void:
	# Physics Setup: We want to reach end_pos in _duration seconds with a parabolic arc.
	var arc_height = 150.0
	if _is_self_cast:
		arc_height = 200.0
		
	# Calculate peak Y (remember Y is down, so peak is lower value)
	var min_y = min(_start_pos.y, _end_pos.y)
	var peak_y = min_y - arc_height
	
	# H is the vertical distance from start to peak
	var h = _start_pos.y - peak_y
	# DeltaY is the vertical distance from start to end
	var delta_y = _end_pos.y - _start_pos.y
	
	# Solve for Gravity (g)
	var term1 = sqrt(2 * h)
	var term2 = sqrt(2 * h + 2 * delta_y)
	var sqrt_g = (term1 + term2) / _duration
	_gravity = sqrt_g * sqrt_g
	
	# Solve for Initial Vertical Velocity (Vy)
	var vy = - sqrt(2 * _gravity * h)
	
	# Solve for Horizontal Velocity (Vx) to guarantee all projectiles land in exactly _duration seconds
	var vx = (_end_pos.x - _start_pos.x) / _duration
	
	_velocity = Vector2(vx, vy)

func _process(delta: float) -> void:
	if not _is_moving:
		return
		
	_time += delta
	
	# Explicit Euler Integration
	position += _velocity * delta
	_velocity.y += _gravity * delta
	
	# Rotate to face direction of travel (only if using an icon like the fireball)
	if icon.visible:
		rotation = _velocity.angle()
	else:
		rotation = 0.0
	
	# Check for completion
	if _time >= _duration:
		_is_moving = false
		impact.emit()
		queue_free()
