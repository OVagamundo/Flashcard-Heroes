# res://scripts/vfx/TokenSpendVFX.gd
class_name TokenSpendVFX
extends Node2D

## Token spend animation - token is TOSSED from counter to gacha machine
## Natural parabolic arc like throwing a coin into a machine slot

const TOKEN_TEXTURE = preload("res://assets/Realistic/ui/textures/token_100yen.png")

# Animation parameters - tuned for satisfying "toss" feel
const COIN_SCALE := 0.375 # 0.375 * 256px = 96px, matching top bar icon perfectly (texture is 4x original)
const TOSS_DURATION := 0.45 # Total flight time
const SPIN_COUNT := 3 # Number of full spins during flight
const GRAVITY_FACTOR := 1.8 # How much the arc curves down
const WOBBLE_DEGREES := 20.0 # Slight rotation wobble

signal animation_finished
signal coin_landed(target_pos: Vector2) # Emitted when coin reaches destination

@onready var token_sprite: Sprite2D = $TokenSprite

var _flip_tween: Tween = null
var _wobble_tween: Tween = null
var _start_pos: Vector2
var _target_pos: Vector2
var _elapsed: float = 0.0
var _flight_active: bool = false

func _ready() -> void:
	if not is_instance_valid(token_sprite):
		token_sprite = Sprite2D.new()
		token_sprite.name = "TokenSprite"
		add_child(token_sprite)
	
	token_sprite.texture = TOKEN_TEXTURE
	token_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)

func play(start_pos: Vector2, target_pos: Vector2, delay: float = 0.0) -> void:
	"""Toss a coin from start to target with a natural parabolic arc"""
	_start_pos = start_pos
	_target_pos = target_pos
	global_position = start_pos
	
	token_sprite.modulate = Color.WHITE
	token_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)
	token_sprite.rotation = 0
	
	# Wait for stagger delay
	if delay > 0:
		token_sprite.visible = false
		await get_tree().create_timer(delay).timeout
		token_sprite.visible = true
	
	# Start the spinning
	_start_spin()
	
	# Start wobble rotation
	_start_wobble()
	
	# Begin physics-style arc movement
	_elapsed = 0.0
	_flight_active = true
	set_process(true)

func _process(delta: float) -> void:
	if not _flight_active:
		return
	
	_elapsed += delta
	var t = _elapsed / TOSS_DURATION
	
	if t >= 1.0:
		# Arrived at destination
		t = 1.0
		_flight_active = false
		set_process(false)
		global_position = _target_pos
		_on_landing()
		return
	
	# Calculate position along parabolic arc
	# Horizontal: linear interpolation
	var x = lerp(_start_pos.x, _target_pos.x, t)
	
	# Vertical: parabolic arc
	# y = start_y + (linear progress) + (parabola for arc)
	var linear_y = lerp(_start_pos.y, _target_pos.y, t)
	
	# Parabola that peaks in the middle: -4 * t * (t - 1) gives peak of 1 at t=0.5
	# Reduced arc height to keep coins on screen (since counter is near top)
	var arc_height = min(80.0, (_target_pos - _start_pos).length() * 0.15)
	var arc_offset = -4.0 * t * (t - 1.0) * arc_height
	
	# Apply slight upward toss at start, then gravity takes over
	var y = linear_y - arc_offset
	
	global_position = Vector2(x, y)

func _on_landing() -> void:
	"""Called when coin reaches destination"""
	# Stop animations
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()
	
	# Quick flash on impact
	token_sprite.modulate = Color(1.5, 1.4, 1.0, 1.0)
	
	# Emit landing signal BEFORE disappearing (for machine reaction)
	coin_landed.emit(_target_pos)
	
	# Brief visible moment, then vanish (absorbed into machine)
	var vanish_tween = create_tween()
	vanish_tween.tween_interval(0.05)
	vanish_tween.tween_property(token_sprite, "modulate:a", 0.0, 0.08)
	
	await vanish_tween.finished
	
	animation_finished.emit()
	queue_free()

func _start_spin() -> void:
	"""Spin the coin during flight - like a flipping coin"""
	_flip_tween = create_tween()
	
	var spin_duration = TOSS_DURATION / SPIN_COUNT / 4.0
	
	# Full rotation cycle using scale.x (creates flip illusion)
	_flip_tween.set_loops(SPIN_COUNT)
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, spin_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(token_sprite, "scale:x", -COIN_SCALE, spin_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(token_sprite, "scale:x", 0.0, spin_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(token_sprite, "scale:x", COIN_SCALE, spin_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _start_wobble() -> void:
	"""Add a slight rotation wobble for natural tumbling feel"""
	_wobble_tween = create_tween()
	_wobble_tween.set_loops(int(TOSS_DURATION / 0.12))
	
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", WOBBLE_DEGREES, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", -WOBBLE_DEGREES, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(token_sprite, "rotation_degrees", 0.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
