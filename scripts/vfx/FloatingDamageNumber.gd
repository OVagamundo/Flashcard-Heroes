class_name FloatingDamageNumber
extends Node2D

## Displays large bold damage numbers on impact with an animated float-up + fade-out.
## Used by melee attack animations to show damage at the target location.

signal animation_finished

@onready var label: Label = $Label

const FLOAT_DISTANCE := 50.0
const FLOAT_DURATION := 0.6
const SCALE_IMPACT := Vector2(1.3, 1.3)
const SCALE_NORMAL := Vector2(1.0, 1.0)

var _start_position: Vector2

func setup(damage: int, spawn_position: Vector2, color: Color = Color(1.0, 0.3, 0.3)) -> void:
	position = spawn_position
	_start_position = spawn_position
	
	# Set the damage text - no sign, just the number
	label.text = str(damage)
	
	# Override font color directly (scene has red default, modulate would multiply)
	label.add_theme_color_override("font_color", color)
	
	# Start invisible for the impact scale-up
	scale = Vector2(0.5, 0.5)
	modulate.a = 1.0

## Helper for armor damage popups (grey color)
func setup_armor(damage: int, spawn_position: Vector2) -> void:
	setup(damage, spawn_position, Color(0.55, 0.55, 0.55)) # Darker grey for armor

func play() -> void:
	# Impact animation: scale up quickly
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale up on impact
	tween.tween_property(self, "scale", SCALE_IMPACT, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Then scale down slightly and float up while fading
	tween.set_parallel(false)
	tween.tween_property(self, "scale", SCALE_NORMAL, 0.15).set_trans(Tween.TRANS_SINE)
	
	tween.set_parallel(true)
	# Float upward
	tween.tween_property(self, "position:y", _start_position.y - FLOAT_DISTANCE, FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Fade out near the end
	tween.tween_property(self, "modulate:a", 0.0, FLOAT_DURATION * 0.5).set_delay(FLOAT_DURATION * 0.5)
	
	tween.set_parallel(false)
	tween.tween_callback(_on_animation_complete)

func _on_animation_complete() -> void:
	animation_finished.emit()
	queue_free()
