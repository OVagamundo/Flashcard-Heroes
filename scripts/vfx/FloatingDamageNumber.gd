class_name FloatingDamageNumber
extends Node2D

## Displays large bold damage numbers on impact with an animated float-up + fade-out.
## Used by melee attack animations to show damage at the target location.

signal animation_finished

@onready var label: Label = $Label

const FLOAT_DISTANCE := 60.0
const FLOAT_DURATION := 0.7
const IMPACT_SCALE = Vector2(2.25, 2.25) # 1.5 * 1.5
const TARGET_SCALE = Vector2(1.5, 1.5)  # 50% bigger base scale

var _start_position: Vector2

func setup(damage: int, spawn_position: Vector2, color: Color = Color(1.0, 0.0, 0.0)) -> void:
	position = spawn_position
	_start_position = spawn_position
	
	# Set the damage text - no sign, just the number
	label.text = str(damage)
	
	# Override font color directly
	label.add_theme_color_override("font_color", color)
	
	# Damage is BIG (Size controlled by .tscn, effective 72px via scale)
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	label.add_theme_constant_override("outline_size", 0)
	
	# Start tiny for the pop
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0

## Helper for status effect popups (Burn, Spikes, Armor)
func setup_status_effect(value: int, type: String, spawn_position: Vector2) -> void:
	position = spawn_position
	_start_position = spawn_position
	
	label.text = str(value)
	
	var color = Color.WHITE
	match type:
		"burn": color = Color(1.0, 0.5, 0.0) # Orange
		"spikes": color = Color(0.0, 1.0, 0.0) # Green
		"armor": color = Color(0.0, 0.6, 1.0) # Blue
		"static": color = Color(1.0, 0.85, 0.1) # Yellow for static
	
	label.add_theme_color_override("font_color", color)
	
	# Status effects match unit stats (Effective 48px via scale)
	# Per user request: Remove outlines from stat effects
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_outline_color", Color.BLACK if type != "armor" else Color.WHITE)
	
	# Start tiny for the pop
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0

## Helper for small stat popups (PWR loss, etc.) - 32px Black Font
func setup_stat(value: int, spawn_position: Vector2, color: Color = Color.WHITE) -> void:
	position = spawn_position
	_start_position = spawn_position
	label.text = str(value)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	# Size controlled by .tscn (48px) and scaled to 1.5x by play()
	label.add_theme_constant_override("outline_size", 0)
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0

## Helper for armor damage popups (Blue color) - matches armor application
func setup_armor(damage: int, spawn_position: Vector2) -> void:
	setup_stat(damage, spawn_position, Color(0.0, 0.6, 1.0)) # Blue for armor hits
	# Armor hits are smaller (32px) as they are stat-related, not direct HP damage.

func play() -> void:
	# Juicy Pop Animation: Snap up -> Float up -> Fade out
	var tween = create_tween()
	
	# 1. THE POP (Snappy scale up)
	tween.tween_property(self, "scale", IMPACT_SCALE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", TARGET_SCALE, 0.1).set_trans(Tween.TRANS_SINE)
	
	# 2. THE FLOAT (In parallel with fade)
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	
	# Float upward
	float_tween.tween_property(self, "position:y", _start_position.y - FLOAT_DISTANCE, FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade out near the end
	float_tween.tween_property(self, "modulate:a", 0.0, FLOAT_DURATION * 0.4).set_delay(FLOAT_DURATION * 0.6)
	
	float_tween.finished.connect(_on_animation_complete)

func _on_animation_complete() -> void:
	animation_finished.emit()
	queue_free()
