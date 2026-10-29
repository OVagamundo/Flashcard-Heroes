# res://scripts/vfx/GoldCoinVFX.gd
class_name GoldCoinVFX
extends Node2D

## Gold coin animation - for spending gold in the shop
## Natural parabolic arc like tossing a coin

const ROTATION_STEPS: Array[Dictionary] = [
	{"frame": 0, "flip_h": false},
	{"frame": 1, "flip_h": false},
	{"frame": 2, "flip_h": false},
	{"frame": 3, "flip_h": false},
	{"frame": 4, "flip_h": false},
	{"frame": 3, "flip_h": true},
	{"frame": 2, "flip_h": true},
	{"frame": 1, "flip_h": true},
]

# Animation parameters
const COIN_SCALE := 1.5 # 1.5 * 64px = 96px, matching target coin visual size
const TOSS_DURATION := 0.45
const SPIN_COUNT := 3
const WOBBLE_DEGREES := 20.0

signal animation_finished
signal coin_landed(target_pos: Vector2)

var _coin_sprite: Sprite2D
var _flip_tween: Tween = null
var _wobble_tween: Tween = null
var _start_pos: Vector2
var _target_pos: Vector2
var _elapsed: float = 0.0
var _flight_active: bool = false
var _effective_toss_duration: float = TOSS_DURATION

func _ready() -> void:
	# Create gold coin sprite
	_coin_sprite = Sprite2D.new()
	_coin_sprite.name = "GoldCoinSprite"
	add_child(_coin_sprite)
	
	# Use the gold coin spritesheet
	var texture = load("res://assets/PixelArt/ui/textures/GoldRotationSpriteSheet.png")
	if texture:
		_coin_sprite.texture = texture
	_coin_sprite.hframes = 5
	_coin_sprite.vframes = 1
	_coin_sprite.frame = 0
	_coin_sprite.flip_h = false
	_coin_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)

func play(start_pos: Vector2, target_pos: Vector2, delay: float = 0.0) -> void:
	"""Toss a gold coin from start to target with a natural parabolic arc"""
	_start_pos = start_pos
	_target_pos = target_pos
	global_position = start_pos
	_effective_toss_duration = AnimationConstants.scaled(TOSS_DURATION)
	
	_coin_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) # Ensure it has no tint
	_coin_sprite.scale = Vector2(COIN_SCALE, COIN_SCALE)
	_coin_sprite.rotation = 0
	_coin_sprite.frame = 0
	_coin_sprite.flip_h = false
	
	if delay > 0:
		_coin_sprite.visible = false
		await AnimationConstants.create_pausable_timer(get_tree(), AnimationConstants.scaled(delay)).timeout
		_coin_sprite.visible = true
	
	_start_spin()
	_start_wobble()
	
	_elapsed = 0.0
	_flight_active = true
	set_process(true)

func _process(delta: float) -> void:
	if not _flight_active:
		return
	
	_elapsed += delta
	var t = _elapsed / _effective_toss_duration
	
	if t >= 1.0:
		t = 1.0
		_flight_active = false
		set_process(false)
		global_position = _target_pos
		_on_landing()
		return
	
	# Calculate position along parabolic arc
	var x = lerp(_start_pos.x, _target_pos.x, t)
	var linear_y = lerp(_start_pos.y, _target_pos.y, t)
	
	# Reduced arc height for screen constraints
	var arc_height = min(80.0, (_target_pos - _start_pos).length() * 0.15)
	var arc_offset = -4.0 * t * (t - 1.0) * arc_height
	
	var y = linear_y - arc_offset
	global_position = Vector2(x, y)

func _on_landing() -> void:
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()
	
	_coin_sprite.frame = 0
	_coin_sprite.flip_h = false
	_coin_sprite.rotation = 0.0
	
	# Flash on impact
	_coin_sprite.modulate = Color(1.5, 1.3, 0.5, 1.0)
	
	coin_landed.emit(_target_pos)
	
	# Quick vanish
	var vanish_tween = create_tween()
	vanish_tween.tween_interval(AnimationConstants.scaled(0.04))
	vanish_tween.tween_property(_coin_sprite, "modulate:a", 0.0, AnimationConstants.scaled(0.06))
	
	await vanish_tween.finished
	animation_finished.emit()
	queue_free()

func _start_spin() -> void:
	_flip_tween = create_tween()
	_flip_tween.tween_method(_apply_spin_step, 0.0, float(SPIN_COUNT), _effective_toss_duration).set_trans(Tween.TRANS_LINEAR)

func _apply_spin_step(progress: float) -> void:
	var total_steps: int = ROTATION_STEPS.size()
	var step_idx: int = int(fposmod(progress, 1.0) * float(total_steps)) % total_steps
	var step: Dictionary = ROTATION_STEPS[step_idx]
	_coin_sprite.frame = step["frame"]
	_coin_sprite.flip_h = step["flip_h"]

func _start_wobble() -> void:
	_wobble_tween = create_tween()
	_wobble_tween.set_loops(maxi(1, int(_effective_toss_duration / AnimationConstants.scaled(0.12))))
	
	_wobble_tween.tween_property(_coin_sprite, "rotation_degrees", WOBBLE_DEGREES, AnimationConstants.scaled(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(_coin_sprite, "rotation_degrees", -WOBBLE_DEGREES, AnimationConstants.scaled(0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble_tween.tween_property(_coin_sprite, "rotation_degrees", 0.0, AnimationConstants.scaled(0.06)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
