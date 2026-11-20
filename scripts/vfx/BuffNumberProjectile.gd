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
var has_impacted: bool = false

func setup(value: int, stat: String, start_pos: Vector2, end_pos: Vector2, is_self_cast: bool = false) -> void:
	if label == null:
		label = $Label
	if icon == null:
		icon = $Icon

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
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0)) # Orange
	elif stat == "spikes":
		label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.2)) # Green
	elif stat == "armor":
		label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65)) # Gray
	elif stat == "static":
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Yellow
	elif stat == "gold":
		label.add_theme_color_override("font_color", AnimationConstants.COLOR_GOLD)
	elif stat == "timer":
		if value >= 0:
			label.text = "+%ds" % value
		else:
			label.text = "%ds" % value
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Bright gold/yellow
	else:
		var status_def: CombatEffectDefinition = CombatEffectRegistry.get_definition(StringName(stat))
		if is_instance_valid(status_def):
			label.add_theme_color_override("font_color", status_def.color)
	
	# Apply Black font and matching outline to unit stat labels
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	
	# Apply scale for battle presence: self-cast pops out from unit center, cross-board starts full scale
	if _is_self_cast:
		self.scale = Vector2(0.4, 0.4)
	else:
		self.scale = Vector2(1.5, 1.5)
	
	position = start_pos
	visible = true
	
	if _duration <= 0:
		_duration = AnimationConstants.scaled(0.5 if _is_self_cast else 0.6)
		
	_recalculate_physics()

func launch(custom_duration: float = 0.0) -> void:
	has_impacted = false
	if custom_duration > 0.0:
		_duration = custom_duration
	elif _duration <= 0.0:
		_duration = AnimationConstants.scaled(0.5 if _is_self_cast else 0.6)
		
	_recalculate_physics()
	_time = 0.0
	_is_moving = true

	if _is_self_cast:
		self.scale = Vector2(0.4, 0.4)
		var pop_tween := create_tween()
		pop_tween.tween_property(self, "scale", Vector2(1.5, 1.5), AnimationConstants.scaled(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func wait_for_impact() -> void:
	if has_impacted or not _is_moving:
		return
	await impact

func _recalculate_physics() -> void:
	# Physics Setup: We want to reach end_pos in _duration seconds with a parabolic arc.
	# Self-cast hops neatly right over the unit's head without rocketing into the UI.
	var arc_height: float = 65.0 if _is_self_cast else 150.0
		
	# Calculate peak Y (remember Y is down, so peak is lower value)
	var min_y: float = min(_start_pos.y, _end_pos.y)
	var peak_y: float = min_y - arc_height
	
	# H is the vertical distance from start to peak
	var h: float = _start_pos.y - peak_y
	# DeltaY is the vertical distance from start to end
	var delta_y: float = _end_pos.y - _start_pos.y
	
	# Solve for Gravity (g)
	var term1: float = sqrt(2.0 * h)
	var term2: float = sqrt(2.0 * h + 2.0 * delta_y)
	var sqrt_g: float = (term1 + term2) / _duration
	_gravity = sqrt_g * sqrt_g
	
	# Solve for Initial Vertical Velocity (Vy)
	var vy: float = - sqrt(2.0 * _gravity * h)
	
	# Solve for Horizontal Velocity (Vx) to guarantee all projectiles land in exactly _duration seconds
	var vx: float = (_end_pos.x - _start_pos.x) / _duration
	
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
		has_impacted = true
		impact.emit()
		queue_free()
