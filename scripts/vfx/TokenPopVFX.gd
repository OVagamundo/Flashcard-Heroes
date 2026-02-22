# res://scripts/vfx/TokenPopVFX.gd
class_name TokenPopVFX
extends Node2D

## Juicy coin pop animation for correct flashcard answers
## Token pops up with a satisfying arc, spins, and flies to the token counter
## Includes scale bounce, gold glow trail, and satisfying landing effects

const TOKEN_TEXTURE = preload("res://assets/ui/textures/token_100yen.png")

# Animation parameters - tuned for satisfying "juice"
const INITIAL_SCALE := 0.75 # Start small for dramatic pop
const MAX_SCALE := 2.25 # Overshoot scale at peak
const FINAL_SCALE := 1.5 # 1.5 * 64px = 96px, matching normal coin size on HUD
const POP_HEIGHT := 180.0 # Height of initial pop
const POP_UP_DURATION := 0.18 # Time to reach peak (slower = more satisfying)
const HANG_TIME := 0.05 # Brief pause at peak
const FLY_TO_TARGET_DURATION := 0.30 # Time to fly to target
const FLIP_COUNT := 3 # More flips = more satisfying
const WOBBLE_AMOUNT := 15.0 # Side-to-side wobble during flight (in pixels)

# Color effects
const GLOW_COLOR := Color(1.0, 0.95, 0.6, 1.0) # Golden glow
const WHITE_FLASH_DURATION := 0.08

signal animation_finished

@onready var token_sprite: Sprite2D = $TokenSprite
@onready var particles: GPUParticles2D = $Particles

var _start_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _flip_tween: Tween = null
var _wobble_tween: Tween = null

func _ready() -> void:
	# Setup token sprite
	if not is_instance_valid(token_sprite):
		token_sprite = Sprite2D.new()
		token_sprite.name = "TokenSprite"
		add_child(token_sprite)
	
	token_sprite.texture = TOKEN_TEXTURE
	token_sprite.scale = Vector2(INITIAL_SCALE, INITIAL_SCALE)

func setup(spawn_position: Vector2, target_pos: Vector2 = Vector2.ZERO) -> void:
	"""Set the spawn position and optional target position for the token"""
	_start_position = spawn_position
	_target_position = target_pos
	global_position = spawn_position

func play(target_pos: Vector2 = Vector2.ZERO) -> void:
	"""Play the juicy coin pop and fly animation"""
	_start_position = global_position
	
	# Use provided target, or fall back to setup target
	var fly_target := target_pos if target_pos != Vector2.ZERO else _target_position
	if fly_target == Vector2.ZERO:
		fly_target = _start_position
	
	# Start with white flash and small scale
	token_sprite.modulate = Color.WHITE
	token_sprite.scale = Vector2(INITIAL_SCALE, INITIAL_SCALE)
	
	# === PHASE 1: POP UP with scale overshoot ===
	var peak_pos = Vector2(_start_position.x, _start_position.y - POP_HEIGHT)
	
	var move_tween = create_tween()
	move_tween.set_parallel(false)
	
	# Pop up with elastic feel
	move_tween.tween_property(self, "global_position", peak_pos, POP_UP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hang at peak briefly
	move_tween.tween_interval(HANG_TIME)
	
	# === PHASE 2: FLY TO TARGET with wobble ===
	move_tween.tween_property(self, "global_position", fly_target, FLY_TO_TARGET_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Scale animation: small -> overshoot big -> settle to normal
	var scale_tween = create_tween()
	# Pop to max size with overshoot
	scale_tween.tween_property(token_sprite, "scale", Vector2(MAX_SCALE, MAX_SCALE), POP_UP_DURATION * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Settle to normal size
	scale_tween.tween_property(token_sprite, "scale", Vector2(FINAL_SCALE, FINAL_SCALE), POP_UP_DURATION * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Shrink as approaching target (absorbed effect)
	scale_tween.tween_property(token_sprite, "scale", Vector2(FINAL_SCALE * 0.6, FINAL_SCALE * 0.6), FLY_TO_TARGET_DURATION).set_delay(HANG_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Color: white flash -> golden glow -> normal
	var color_tween = create_tween()
	color_tween.tween_property(token_sprite, "modulate", GLOW_COLOR, WHITE_FLASH_DURATION).set_trans(Tween.TRANS_SINE)
	color_tween.tween_property(token_sprite, "modulate", Color.WHITE, POP_UP_DURATION - WHITE_FLASH_DURATION)
	
	# Start spinning
	_start_horizontal_flip()
	
	# Add wobble during flight phase
	_start_wobble(POP_UP_DURATION + HANG_TIME)
	
	# Wait for landing
	await move_tween.finished
	
	# Stop animations
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()
	
	# Quick scale squash on "impact"
	var squash_tween = create_tween()
	token_sprite.scale = Vector2(FINAL_SCALE * 0.8, FINAL_SCALE * 0.4) # Squash
	squash_tween.tween_property(token_sprite, "scale", Vector2(0.0, 0.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Bright flash on landing
	token_sprite.modulate = Color(1.5, 1.4, 1.0, 1.0) # Extra bright
	
	# Particle burst at landing
	if is_instance_valid(particles):
		particles.emitting = true
	
	await squash_tween.finished
	token_sprite.visible = false
	
	# Emit signal so counter updates
	animation_finished.emit()
	
	# Wait for particles then cleanup
	await get_tree().create_timer(0.2).timeout
	queue_free()

func _start_horizontal_flip() -> void:
	"""Animate spinning coin effect"""
	_flip_tween = create_tween()
	_flip_tween.set_loops(FLIP_COUNT)
	
	var total_duration = POP_UP_DURATION + HANG_TIME + FLY_TO_TARGET_DURATION
	var flip_duration = total_duration / FLIP_COUNT / 4.0
	
	# Full rotation cycle using scale.x
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(token_sprite, "scale:x", -FINAL_SCALE, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(token_sprite, "scale:x", FINAL_SCALE, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_wobble(delay: float) -> void:
	"""Add a subtle side-to-side wobble during flight"""
	_wobble_tween = create_tween()
	_wobble_tween.set_loops(4)
	
	var wobble_duration = FLY_TO_TARGET_DURATION / 4.0
	
	# Wobble using rotation
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", 15.0, wobble_duration * 0.5).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", -15.0, wobble_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", 0.0, wobble_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
