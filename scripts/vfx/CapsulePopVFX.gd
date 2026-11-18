# scripts/vfx/CapsulePopVFX.gd
class_name CapsulePopVFX
extends Node2D

## Visual effect when a gacha capsule lands on the shelf.
## - Spawns already halfway open and launches in a pronounced outward parabolic arc.
## - Left half arcs up and out to the left; Right half arcs up and out to the right.
## - Rotates continuously outward across the entire arc until the very end.
## - First frame is tinted 100% solid white for an impactful hit flash.
## - At half lifespan (as the arc turns downward), 3 damage blinks trigger with fading opacity.
## - Disappears cleanly at the end of the arc after the 3rd blink finishes.

const TOP_TEXTURE_PATH := "res://assets/PixelArt/ui/textures/GachaCapsuletop.png"
const BOTTOM_TEXTURE_PATH := "res://assets/PixelArt/ui/textures/GachaCapsuleBottom.png"
const BOTTOM_TEXTURE_FALLBACK_PATH := "res://assets/PixelArt/ui/textures/GachaCapsulebottom.png"

const DEFAULT_SCALE := 1.5

# Timing constants
const MOTION_DURATION := 0.35 # Pop-arc phase before blinking begins
const BLINK_PHASE_DURATION := 0.06 # Cadence per blink phase (~3.6 frames at 60fps)
const BLINK_PHASES := 6 # 3 distinct blinks: OFF, ON, OFF, ON, OFF, ON -> disappear

# Kinematics constants
const BASE_ROTATION: float = -PI / 2.0 # -90° turns top dome into left half, bottom cup into right half
const HALFWAY_POP_DISTANCE_X: float = 50.0 # Starts already halfway open with clear outward spacing
const FULL_POP_DISTANCE_X: float = 165.0 # Full outward arc extension
const HALFWAY_OPEN_ROTATION: float = 0.35 # ~20° open at start
const FULL_OPEN_ROTATION: float = 1.40 # ~80° fully open at end

# Outward Parabolic Arc curve: Y(u) = A*u^2 + B*u + C
# Starts at -20px, reaches upward apex of -60px at u = 0.30, and curves down to +156px at u = 1.0
const ARC_A: float = 440.0
const ARC_B: float = -264.0
const ARC_C: float = -20.0

const FLASH_SHADER_CODE := """
shader_type canvas_item;
uniform float flash_white : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash_white), tex.a * COLOR.a);
}
"""

@onready var top_sprite: Sprite2D = $TopSprite
@onready var bottom_sprite: Sprite2D = $BottomSprite

var _base_scale: float = DEFAULT_SCALE
var _is_playing: bool = false
var _elapsed_time: float = 0.0
var _frame_count: int = 0
var _scaled_motion_dur: float = MOTION_DURATION
var _scaled_blink_dur: float = BLINK_PHASE_DURATION
var _total_duration: float = MOTION_DURATION + (BLINK_PHASE_DURATION * BLINK_PHASES)
var _flash_material: ShaderMaterial = null

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 1 # In front of slot platforms (z=0) but behind units (z=2) and HUD machines (layer=60)
	_ensure_sprites()
	_load_textures()
	_init_shader()

func _init_shader() -> void:
	if _flash_material == null:
		var shader = Shader.new()
		shader.code = FLASH_SHADER_CODE
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = shader
		_flash_material.set_shader_parameter("flash_white", 1.0)
	
	if is_instance_valid(top_sprite):
		top_sprite.material = _flash_material
	if is_instance_valid(bottom_sprite):
		bottom_sprite.material = _flash_material

func _ensure_sprites() -> void:
	if not is_instance_valid(top_sprite):
		top_sprite = get_node_or_null("TopSprite")
		if not is_instance_valid(top_sprite):
			top_sprite = Sprite2D.new()
			top_sprite.name = "TopSprite"
			add_child(top_sprite)
	
	if not is_instance_valid(bottom_sprite):
		bottom_sprite = get_node_or_null("BottomSprite")
		if not is_instance_valid(bottom_sprite):
			bottom_sprite = Sprite2D.new()
			bottom_sprite.name = "BottomSprite"
			add_child(bottom_sprite)

func _load_textures() -> void:
	if is_instance_valid(top_sprite) and not top_sprite.texture:
		if ResourceLoader.exists(TOP_TEXTURE_PATH):
			top_sprite.texture = load(TOP_TEXTURE_PATH)
	
	if is_instance_valid(bottom_sprite) and not bottom_sprite.texture:
		var bottom_path := BOTTOM_TEXTURE_PATH
		if not ResourceLoader.exists(bottom_path) and ResourceLoader.exists(BOTTOM_TEXTURE_FALLBACK_PATH):
			bottom_path = BOTTOM_TEXTURE_FALLBACK_PATH
		
		if ResourceLoader.exists(bottom_path):
			bottom_sprite.texture = load(bottom_path)

## Configure initial spawn position and scale (incoming_velocity kept for API compatibility)
func setup(spawn_pos: Vector2, scale_factor: float = DEFAULT_SCALE, _incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	top_level = true
	z_as_relative = false
	z_index = 1
	global_position = spawn_pos
	_base_scale = scale_factor
	_ensure_sprites()
	_load_textures()
	_init_shader()
	_reset_sprites()

func _reset_sprites() -> void:
	var size_mult: float = _base_scale / DEFAULT_SCALE
	
	if _flash_material != null:
		_flash_material.set_shader_parameter("flash_white", 1.0)
	
	# Start ALREADY halfway open to the sides, with outward spacing
	if is_instance_valid(top_sprite):
		top_sprite.position = Vector2(-HALFWAY_POP_DISTANCE_X * size_mult, ARC_C * size_mult)
		top_sprite.rotation = BASE_ROTATION - HALFWAY_OPEN_ROTATION
		top_sprite.scale = Vector2(_base_scale, _base_scale)
		top_sprite.modulate = Color.WHITE
		top_sprite.visible = true
		top_sprite.centered = true
		top_sprite.z_as_relative = true
		top_sprite.z_index = 0
		if _flash_material != null:
			top_sprite.material = _flash_material
		
	if is_instance_valid(bottom_sprite):
		bottom_sprite.position = Vector2(HALFWAY_POP_DISTANCE_X * size_mult, ARC_C * size_mult)
		bottom_sprite.rotation = BASE_ROTATION + HALFWAY_OPEN_ROTATION
		bottom_sprite.scale = Vector2(_base_scale, _base_scale)
		bottom_sprite.modulate = Color.WHITE
		bottom_sprite.visible = true
		bottom_sprite.centered = true
		bottom_sprite.z_as_relative = true
		bottom_sprite.z_index = 0
		if _flash_material != null:
			bottom_sprite.material = _flash_material

## Play the outward parabolic arc, continuous rotation, and 3 fading damage blinks
func play() -> void:
	_ensure_sprites()
	_init_shader()
	_reset_sprites()
	
	_scaled_motion_dur = AnimationConstants.scaled(MOTION_DURATION)
	_scaled_blink_dur = AnimationConstants.scaled(BLINK_PHASE_DURATION)
	_total_duration = _scaled_motion_dur + (_scaled_blink_dur * BLINK_PHASES)
	_elapsed_time = 0.0
	_frame_count = 0
	_is_playing = true
	set_process(true)

func _process(delta: float) -> void:
	if not _is_playing:
		return
	
	_elapsed_time += delta
	_frame_count += 1
	
	# Turn off 100% solid white hit flash after the first frame
	if _frame_count > 1 and _flash_material != null:
		_flash_material.set_shader_parameter("flash_white", 0.0)
	
	# Check if total lifespan has completed (after 3 blinks)
	if _elapsed_time >= _total_duration:
		_is_playing = false
		if is_instance_valid(top_sprite):
			top_sprite.visible = false
		if is_instance_valid(bottom_sprite):
			bottom_sprite.visible = false
		queue_free()
		return
	
	# Visibility and Fading Blinks:
	# First half of lifespan: Solid opaque ON as motion arcs up and out
	# Second half of lifespan: 3 damage blinks (OFF, ON, OFF, ON, OFF, ON) fading progressively
	var is_visible: bool = true
	var current_alpha: float = 1.0
	
	if _elapsed_time >= _scaled_motion_dur:
		var blink_time: float = _elapsed_time - _scaled_motion_dur
		var phase_idx: int = int(floor(blink_time / _scaled_blink_dur))
		var is_on: bool = (phase_idx % 2 == 1) # phase 0=OFF, phase 1=ON (Blink 1), etc.
		
		# Fade alpha smoothly from 0.85 down to 0.20 across the 3 blinks
		var blink_progress: float = clampf(blink_time / (_scaled_blink_dur * BLINK_PHASES), 0.0, 1.0)
		var fade_alpha: float = lerp(0.85, 0.20, blink_progress)
		
		is_visible = is_on
		current_alpha = fade_alpha if is_on else 0.0
	
	for s in [top_sprite, bottom_sprite]:
		if is_instance_valid(s):
			s.visible = is_visible
			s.modulate.a = current_alpha
	
	# Normalized lifetime [0.0, 1.0]
	var u: float = clampf(_elapsed_time / _total_duration, 0.0, 1.0)
	var size_mult: float = _base_scale / DEFAULT_SCALE
	
	# Vertical Arc: parabolic curve peaking at u = 0.30 and arcing down to +156px
	var current_y: float = (ARC_A * u * u + ARC_B * u + ARC_C) * size_mult
	
	# Horizontal Outward Arc: maintains continuous outward momentum all the way to the very end
	var current_x: float = lerp(HALFWAY_POP_DISTANCE_X * size_mult, FULL_POP_DISTANCE_X * size_mult, u)
	
	# Rotation: maintains continuous outward angular velocity all the way through the fall to the very end
	var current_rot_delta: float = lerp(HALFWAY_OPEN_ROTATION, FULL_OPEN_ROTATION, u)
	
	# Left Half: pops left in outward arc, rotates open counter-clockwise
	if is_instance_valid(top_sprite):
		top_sprite.position = Vector2(-current_x, current_y)
		top_sprite.rotation = BASE_ROTATION - current_rot_delta
	
	# Right Half: pops right in outward arc, rotates open clockwise
	if is_instance_valid(bottom_sprite):
		bottom_sprite.position = Vector2(current_x, current_y)
		bottom_sprite.rotation = BASE_ROTATION + current_rot_delta
