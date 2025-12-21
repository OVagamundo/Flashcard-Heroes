# res://scripts/vfx/TokenPopVFX.gd
class_name TokenPopVFX
extends Node2D

## Mario-style coin pop animation for correct flashcard answers
## Token pops up, flips horizontally like a coin, lands back at spawn point
## Starts white and fades to coin texture, particle burst on landing

const TOKEN_TEXTURE = preload("res://assets/ui/textures/token_100yen.png")

# Animation parameters
const POP_HEIGHT := 300.0 # How high the token rises
const POP_UP_DURATION := 0.15 # Time to reach peak
const POP_DOWN_DURATION := 0.12 # Time to land
const FLIP_COUNT := 1 # Number of horizontal flips (less spin)
const WHITE_FADE_DURATION := 0.06 # Time to fade from white to normal
const COIN_SCALE := 0.17 # Coin size

signal animation_finished

@onready var token_sprite: Sprite2D = $TokenSprite
@onready var particles: GPUParticles2D = $Particles

var _start_position: Vector2 = Vector2.ZERO
var _flip_tween: Tween = null

func _ready() -> void:
	# Setup token sprite
	if not is_instance_valid(token_sprite):
		token_sprite = Sprite2D.new()
		token_sprite.name = "TokenSprite"
		add_child(token_sprite)
	
	token_sprite.texture = TOKEN_TEXTURE
	token_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)

func setup(spawn_position: Vector2) -> void:
	"""Set the spawn position for the token"""
	_start_position = spawn_position
	global_position = spawn_position

func play() -> void:
	"""Play the Mario-style coin pop animation"""
	_start_position = global_position
	
	# Start with white tint (pops into existence instantly white)
	token_sprite.modulate = Color.WHITE
	
	# Create main movement tween
	var move_tween = create_tween()
	
	# Pop UP with ease-out (slowing down as it rises - like fighting gravity)
	var peak_pos = Vector2(_start_position.x, _start_position.y - POP_HEIGHT)
	move_tween.tween_property(self, "global_position", peak_pos, POP_UP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fall back DOWN with ease-in (accelerating as it falls - gravity)
	move_tween.tween_property(self, "global_position", _start_position, POP_DOWN_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Start horizontal flip animation (runs in parallel)
	_start_horizontal_flip()
	
	# Fade from white to normal coin color, then fade out at end
	var color_tween = create_tween()
	color_tween.tween_property(token_sprite, "modulate", Color.WHITE, 0.03) # Hold white briefly
	color_tween.tween_property(token_sprite, "modulate", Color(1, 1, 1, 1), WHITE_FADE_DURATION)
	# Fade out near the end
	color_tween.tween_property(token_sprite, "modulate:a", 0.0, 0.08).set_delay(POP_UP_DURATION - 0.02)
	
	# Wait for landing, then burst particles and remove
	await move_tween.finished
	
	# Stop flipping
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	token_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE) # Reset to normal size
	
	# Particle burst on landing
	if is_instance_valid(particles):
		particles.emitting = true
	
	# Wait for particles then cleanup
	await get_tree().create_timer(0.15).timeout
	animation_finished.emit()
	queue_free()

func _start_horizontal_flip() -> void:
	"""Animate horizontal flip like a spinning coin"""
	# Flip by scaling X from 1 -> 0 -> -1 -> 0 -> 1 (one full flip)
	# Do this FLIP_COUNT times
	
	_flip_tween = create_tween()
	_flip_tween.set_loops(FLIP_COUNT)
	
	var flip_duration = (POP_UP_DURATION + POP_DOWN_DURATION) / FLIP_COUNT / 2.0
	
	# Scale X: 1 -> 0 (turning away)
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Scale X: 0 -> -COIN_SCALE (showing back side / continue turn)
	_flip_tween.tween_property(token_sprite, "scale:x", -COIN_SCALE, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Scale X: -COIN_SCALE -> 0 (turning back)
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Scale X: 0 -> COIN_SCALE (back to front)
	_flip_tween.tween_property(token_sprite, "scale:x", COIN_SCALE, flip_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
