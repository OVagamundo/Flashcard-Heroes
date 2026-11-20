# scripts/animations/UnitAnimationController.gd
# Handles all visual animations for a GachaBallView unit.
# Extracted from GachaBallView to separate animation logic from UI/interaction.
class_name UnitAnimationController
extends Node

# Preload constants to ensure availability before class_name registration
const AC = preload("res://scripts/animations/AnimationConstants.gd")

# Parent view reference (set in _ready)
var _view: GachaBallView
var _icon_rect: TextureRect

# Animation state
var _melee_origin_position: Vector2 = Vector2.ZERO
var _flash_tween: Tween = null
var _flash_original_position: Vector2 = Vector2.ZERO
var _original_z_index: int = 0
var _guardian_original_position: Vector2 = Vector2.ZERO

# The actual sprite to animate (UnitSprite in Battle mode, icon_rect otherwise)
# Using this instead of icon_rect prevents child movement during scale
var _sprite: TextureRect = null

# Independent effect tweens (composable animation system)
var _color_tween: Tween = null
var _deform_tween: Tween = null
var _move_tween: Tween = null
var _move_original_position: Vector2 = Vector2.ZERO
var _move_original_local_position: Vector2 = Vector2.ZERO
var _move_original_size: Vector2 = Vector2.ZERO
var _move_original_top_level: bool = false
var _move_original_sprite_y: float = C.SLOT_UNIT_OFFSET_Y
var _is_active: bool = true

# Shadow tracking state
var _shadow_sprite: TextureRect = null
var _is_lunging: bool = false
var _anim_start_pos: Vector2 = Vector2.ZERO
var _anim_target_pos: Vector2 = Vector2.ZERO

func set_active(active: bool) -> void:
	if _is_active == active:
		return
	_is_active = active
	if not _is_active:
		_kill_active_tweens()
		_disconnect_signals()
	else:
		if is_inside_tree():
			_connect_signals()

func _ready() -> void:
	_view = get_parent() as GachaBallView
	assert(_view != null, "UnitAnimationController must be child of GachaBallView")
	
	# Wait one frame to ensure parent is fully initialized
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_icon_rect = _view.icon_rect
	_shadow_sprite = _get_shadow_sprite()
	
	if _is_active:
		_connect_signals()

func _exit_tree() -> void:
	_disconnect_signals()
	_kill_active_tweens()
	# Reset sprite scale on cleanup
	_reset_sprite_scale()
	_reset_shadow()

func _process(_delta: float) -> void:
	if not _is_active or not is_inside_tree() or not is_instance_valid(_view):
		return
	var shadow := _get_shadow_sprite()
	if not is_instance_valid(shadow) or not shadow.visible:
		return
	_update_shadow(shadow)

func _get_shadow_sprite() -> TextureRect:
	if not is_instance_valid(_shadow_sprite) or not _shadow_sprite.is_inside_tree():
		if is_instance_valid(_icon_rect):
			_shadow_sprite = _icon_rect.get_node_or_null("ShadowSprite")
		elif is_instance_valid(_view) and is_instance_valid(_view.icon_rect):
			_shadow_sprite = _view.icon_rect.get_node_or_null("ShadowSprite")
	return _shadow_sprite

func _reset_shadow() -> void:
	var shadow := _get_shadow_sprite()
	if is_instance_valid(shadow):
		shadow.position.y = C.SHADOW_OFFSET_Y
		shadow.scale = Vector2.ONE
		shadow.modulate.a = C.SHADOW_ALPHA

func _update_shadow(shadow: TextureRect) -> void:
	# The shadow remains pinned to the platform surface at the base of the unit.
	shadow.position.y = C.SHADOW_OFFSET_Y
	
	# Track vertical changes of the unit sprite (e.g. jump arc, buff hop, summon drop, death levitate)
	var sprite := _get_sprite()
	var sprite_hop: float = 0.0
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite_hop = maxf(0.0, C.SLOT_UNIT_OFFSET_Y - sprite.position.y)
	
	var t = clampf(sprite_hop / 150.0, 0.0, 1.0)
	shadow.scale.x = lerpf(1.0, 0.25, t)
	shadow.scale.y = 1.0
	shadow.modulate.a = lerpf(C.SHADOW_ALPHA, 0.0, t)

func _connect_signals() -> void:
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		bus.unit_bump_attack.connect(_on_unit_bump_attack)
		bus.unit_death_fade.connect(_on_unit_death_fade)
		bus.unit_summon_fade.connect(_on_unit_summon_fade)
		bus.unit_melee_lunge.connect(_on_unit_melee_lunge)
		bus.unit_melee_return.connect(_on_unit_melee_return)
		bus.unit_lethal_save.connect(_on_unit_lethal_save)
		# Composable animation effects
		bus.unit_color_flash.connect(_on_unit_color_flash)
		bus.unit_deform.connect(_on_unit_deform)
		bus.unit_move.connect(_on_unit_move)

func _disconnect_signals() -> void:
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		if bus.unit_bump_attack.is_connected(_on_unit_bump_attack):
			bus.unit_bump_attack.disconnect(_on_unit_bump_attack)
		if bus.unit_death_fade.is_connected(_on_unit_death_fade):
			bus.unit_death_fade.disconnect(_on_unit_death_fade)
		if bus.unit_summon_fade.is_connected(_on_unit_summon_fade):
			bus.unit_summon_fade.disconnect(_on_unit_summon_fade)
		if bus.unit_melee_lunge.is_connected(_on_unit_melee_lunge):
			bus.unit_melee_lunge.disconnect(_on_unit_melee_lunge)
		if bus.unit_melee_return.is_connected(_on_unit_melee_return):
			bus.unit_melee_return.disconnect(_on_unit_melee_return)
		if bus.unit_lethal_save.is_connected(_on_unit_lethal_save):
			bus.unit_lethal_save.disconnect(_on_unit_lethal_save)
		# Composable animation effects
		if bus.unit_color_flash.is_connected(_on_unit_color_flash):
			bus.unit_color_flash.disconnect(_on_unit_color_flash)
		if bus.unit_deform.is_connected(_on_unit_deform):
			bus.unit_deform.disconnect(_on_unit_deform)
		if bus.unit_move.is_connected(_on_unit_move):
			bus.unit_move.disconnect(_on_unit_move)

# =============================================================================
# Helper to get parent's UUID
# =============================================================================
func _get_uuid() -> String:
	return _view._instance_uuid if is_instance_valid(_view) else ""

# =============================================================================
# Helper to get the active shader material (from UnitSprite if visible, else icon_rect)
# =============================================================================
func _get_active_material() -> ShaderMaterial:
	if not is_instance_valid(_icon_rect):
		return null
	# Check if UnitSprite exists and is visible (used for scaled icons)
	var unit_sprite = _icon_rect.get_node_or_null("UnitSprite")
	if is_instance_valid(unit_sprite) and unit_sprite.visible and unit_sprite.material:
		return unit_sprite.material as ShaderMaterial
	# Fallback to icon_rect material
	return _icon_rect.material as ShaderMaterial

# =============================================================================
# Helper to get the animatable sprite
# In Battle mode, this is UnitSprite child; otherwise icon_rect itself
# =============================================================================
func _get_sprite() -> TextureRect:
	if not is_instance_valid(_icon_rect) and is_instance_valid(_view):
		_icon_rect = _view.icon_rect
	if not is_instance_valid(_icon_rect):
		return null
	if is_instance_valid(_sprite) and _sprite != _icon_rect:
		return _sprite
	# Try UnitSprite child first (Battle mode has sprite at (32,32), inventory mode has centered child)
	var unit_sprite = _icon_rect.get_node_or_null("UnitSprite")
	if is_instance_valid(unit_sprite):
		_sprite = unit_sprite
	else:
		_sprite = _icon_rect # Fallback for non-battle mode
	return _sprite

# =============================================================================
# Helper to reset sprite scale to (1, 1)
# =============================================================================
func _reset_sprite_scale() -> void:
	var sprite := _get_sprite()
	if is_instance_valid(sprite):
		sprite.scale = Vector2.ONE

func _restore_move_layout_state() -> void:
	if not is_instance_valid(_view):
		return

	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = _move_original_sprite_y

	_view.top_level = _move_original_top_level
	if _move_original_top_level:
		_view.global_position = _move_original_position
	else:
		# Restore the original local layout state so container-managed slots do not
		# accumulate offsets after temporary top-level animations.
		_view.position = _move_original_local_position
		if _move_original_size != Vector2.ZERO:
			_view.size = _move_original_size
	_reset_shadow()

# Legacy alias for compatibility
func _reset_icon_scale() -> void:
	_reset_sprite_scale()

## Centralize tween cleanup to prevent engine-level list corruption
## CRITICAL: When killing flash/move tweens, also restore layout state that
## would have been restored by their finished callbacks. Without this,
## top_level remains true and position stays at (0,0).
func _kill_active_tweens() -> void:
	_is_lunging = false
	_reset_shadow()
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
		sprite.modulate.a = 1.0
	if is_instance_valid(_view):
		var stats_overlay = _view.get_node_or_null("%StatsOverlay") as Control
		var stats_underlay = _view.get_node_or_null("%StatsUnderlay") as Control
		var unit_overlay = _view.get_node_or_null("UnitOverlay") as Control
		if is_instance_valid(stats_overlay): stats_overlay.modulate.a = 1.0
		if is_instance_valid(stats_underlay): stats_underlay.modulate.a = 1.0
		if is_instance_valid(unit_overlay): unit_overlay.modulate.a = 1.0
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		_flash_tween = null
		# Restore flash layout state (normally done in _on_flash_tween_finished)
		if is_instance_valid(_view):
			_view.top_level = false
			if _flash_original_position != Vector2.ZERO:
				_view.global_position = _flash_original_position
				_flash_original_position = Vector2.ZERO
			_reset_sprite_scale()
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
		_color_tween = null
	if _deform_tween and _deform_tween.is_valid():
		_deform_tween.kill()
		_deform_tween = null
		_reset_sprite_scale()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
		# Restore move layout state (normally done in _on_unit_move finished callback)
		_restore_move_layout_state()


# =============================================================================
# Helper to ensure pivot is set correctly before animation
# Uses BOTTOM-CENTER pivot so squish/stretch appears grounded at feet
# =============================================================================
func _ensure_pivot() -> void:
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite.size != Vector2.ZERO:
		# Bottom-center pivot: scaling appears grounded at unit's feet
		sprite.pivot_offset = Vector2(sprite.size.x / 2.0, sprite.size.y)

# =============================================================================
# BUMP ATTACK ANIMATION
# =============================================================================
func _on_unit_bump_attack(unit_uuid: String, direction: Vector2) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	var start_pos: Vector2 = _view.position
	var bump_target := start_pos + (direction.normalized() * AC.BUMP_DISTANCE)
	
	_view.position = start_pos
	var tween = _view.create_tween()
	# Assign to _move_tween so it can be tracked/killed
	_move_tween = tween 
	tween.tween_property(_view, "position", bump_target, AC.scaled(AC.BUMP_FORWARD_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_view, "position", start_pos, AC.scaled(AC.BUMP_RETURN_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_bump_tween_finished)

func _on_bump_tween_finished() -> void:
	_reset_shadow()
	SignalBus.emit_signal("unit_bump_finished", _get_uuid())

# =============================================================================
# DEATH FADE ANIMATION
# =============================================================================
func _on_unit_death_fade(unit_uuid: String, stay_in_place: bool = false) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	# GUARDIAN SENTINEL FIX: Force reset of view layout to the actual slot
	# so that no matter what tweens were running (leap, recoil, etc),
	# it is visually detached and floating exactly from its slot.
	if is_instance_valid(_view):
		if not stay_in_place:
			_view.top_level = false
			_view.position = Vector2.ZERO
		else:
			var gp = _view.global_position
			_view.top_level = true
			_view.global_position = gp
	_reset_sprite_scale()
	
	var sprite := _get_sprite()
	var sprite_start_y: float = sprite.position.y if (is_instance_valid(sprite) and sprite != _icon_rect) else float(C.SLOT_UNIT_OFFSET_Y)
	var levitate_target_y = sprite_start_y - AC.DEATH_LEVITATE_HEIGHT
	
	var fade_tween = _view.create_tween()
	_move_tween = fade_tween
	fade_tween.set_parallel(true)
	
	if is_instance_valid(sprite) and sprite != _icon_rect:
		fade_tween.tween_property(sprite, "position:y", levitate_target_y, AC.scaled(AC.DEATH_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(_view, "modulate:a", 0.0, AC.scaled(AC.DEATH_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	var mat = _get_active_material()
	if mat:
		fade_tween.tween_method(func(v): mat.set_shader_parameter("alpha_multiplier", v), 1.0, 0.0, AC.scaled(AC.DEATH_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	fade_tween.set_parallel(false)
	fade_tween.finished.connect(_on_death_fade_tween_finished)

func _on_death_fade_tween_finished() -> void:
	_reset_shadow()
	SignalBus.emit_signal("unit_death_fade_finished", _get_uuid())

# =============================================================================
# SUMMON FADE ANIMATION
# =============================================================================
func _on_unit_summon_fade(unit_uuid: String) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	var sprite := _get_sprite()
	_ensure_pivot() # Set bottom-center pivot on sprite
	
	var sprite_target_y := float(C.SLOT_UNIT_OFFSET_Y)
	var sprite_start_y := sprite_target_y - AC.SUMMON_DROP_HEIGHT
	
	_view.modulate.a = 0.0
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = sprite_start_y
		sprite.scale = AC.SQUISH_SCALE # Start narrow & tall (stretched in direction of fall)
	
	var mat = _get_active_material()
	if mat:
		mat.set_shader_parameter("alpha_multiplier", 0.0)
	
	var fade_tween = _view.create_tween()
	_move_tween = fade_tween
	
	# Phase 1: Drop sprite + fade in _view (parallel)
	fade_tween.set_parallel(true)
	fade_tween.tween_property(_view, "modulate:a", 1.0, AC.scaled(AC.SUMMON_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(sprite) and sprite != _icon_rect:
		fade_tween.tween_property(sprite, "position:y", sprite_target_y, AC.scaled(AC.SUMMON_DROP_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if mat:
		fade_tween.tween_method(func(v): mat.set_shader_parameter("alpha_multiplier", v), 0.0, 1.0, AC.scaled(AC.SUMMON_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	fade_tween.set_parallel(false)
	
	# Phase 2: Landing bounce upon impact (grounded at unit's feet)
	if is_instance_valid(sprite):
		fade_tween.tween_callback(func(): Audio.play_sfx("unit_hop"))
		AC.append_landing_bounce(fade_tween, sprite, Vector2.ONE)
	
	fade_tween.finished.connect(_on_summon_fade_tween_finished)

func _on_summon_fade_tween_finished() -> void:
	if is_instance_valid(_view):
		_view.modulate.a = 1.0
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
		sprite.modulate.a = 1.0
	_reset_sprite_scale()
	_reset_shadow()
	SignalBus.emit_signal("unit_summon_fade_finished", _get_uuid())

# =============================================================================
# MELEE LUNGE ANIMATION
# =============================================================================
func _on_unit_melee_lunge(unit_uuid: String, target_position: Vector2) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	var sprite := _get_sprite()
	_melee_origin_position = _view.global_position
	_original_z_index = _view.z_index
	_view.z_index = 100
	_anim_start_pos = _melee_origin_position
	_anim_target_pos = target_position
	_is_lunging = true
	
	_ensure_pivot() # Set bottom-center pivot on sprite
	
	var dir_x = signf(target_position.x - _melee_origin_position.x)
	if is_zero_approx(dir_x): dir_x = 1.0
	var windup_x = _melee_origin_position.x - (dir_x * AC.MELEE_WINDUP_DISTANCE)
	
	var tween = _view.create_tween()
	_move_tween = tween
	
	# Windup: Move back horizontally + SQUISH sprite (narrow & tall)
	tween.set_parallel(true)
	tween.tween_property(_view, "global_position:x", windup_x, AC.scaled(AC.MELEE_WINDUP_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.MELEE_WINDUP_DURATION)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	
	# Lunge: Horizontal movement on _view, vertical parabolic jump arc on sprite
	var lunge_duration = AC.scaled(AC.MELEE_LUNGE_DURATION - AC.DEFORM_DURATION)
	tween.set_parallel(true)
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if sprite != _icon_rect:
			tween.tween_method(
				func(t: float):
					var hop = 4.0 * AC.MELEE_ARC_HEIGHT * t * (1.0 - t)
					sprite.position.y = C.SLOT_UNIT_OFFSET_Y - hop,
				0.0, 1.0, lunge_duration
			)
	tween.tween_property(_view, "global_position:x", target_position.x, lunge_duration).set_trans(Tween.TRANS_LINEAR)
	tween.set_parallel(false)
	
	# Impact: Quick SQUISH on hit
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(_on_melee_lunge_tween_finished)

# =============================================================================
# SELECTION FEEDBACK
# =============================================================================
func play_selection_bounce() -> void:
	if not is_inside_tree():
		return
		
	var uuid = _get_uuid()
	var loc: LocationIdentifier = _view.get_meta("location_identifier", null)
	if is_instance_valid(loc) and GlobalInteractionRouter.get_context_group(loc.container) == &"SelectionOnly":
		# Selection-only rows like Shop/Rewards live inside container-managed slots.
		# Keep their feedback local so the scene layout never accumulates drift.
		_on_unit_deform(uuid, &"LANDING_BOUNCE")
		return

	# Reuse standard HOP animation (Move + Deform)
	# This ensures correct pivot handling (_ensure_pivot called in deform)
	# and consistent physics with other hop/bounce effects.
	_on_unit_move(uuid, &"HOP", Vector2.ZERO)
	_on_unit_deform(uuid, &"HOP_DEFORM")

func _on_melee_lunge_tween_finished() -> void:
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	SignalBus.emit_signal("unit_melee_lunge_finished", _get_uuid())

func _on_unit_melee_return(unit_uuid: String) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	var sprite := _get_sprite()
	_ensure_pivot() # Set bottom-center pivot on sprite
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	_anim_start_pos = _view.global_position
	_anim_target_pos = _melee_origin_position
	_is_lunging = true
	
	var tween = _view.create_tween()
	_move_tween = tween
	
	# Return: STRETCH sprite during jump back
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Move back to origin X
	tween.tween_property(_view, "global_position:x", _melee_origin_position.x, AC.scaled(AC.MELEE_RETURN_DURATION)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Land: SQUISH then normalize with elastic
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION * 2)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(_on_melee_return_tween_finished)

func _on_melee_return_tween_finished() -> void:
	_view.z_index = _original_z_index
	_view.global_position = _melee_origin_position
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	_reset_sprite_scale()
	_is_lunging = false
	_reset_shadow()
	SignalBus.emit_signal("unit_melee_return_finished", _get_uuid())

# =============================================================================
# FLASH EFFECT ANIMATION
# =============================================================================
func _on_unit_flash_effect(unit_uuid: String, flash_color: Color) -> void:
	if _get_uuid() != unit_uuid:
		return
	_flash_unit_color(flash_color)

func _flash_unit_color(flash_color: Color) -> void:
	var mat = _get_active_material()
	var sprite := _get_sprite()
	
	if not mat:
		var original_modulate: Color = _view.modulate
		_view.modulate = flash_color
		var fallback_tween = _view.create_tween()
		fallback_tween.tween_property(_view, "modulate", original_modulate, AC.scaled(0.3))
		fallback_tween.finished.connect(_on_flash_tween_finished)
		return
	
	# CRITICAL: Kill ALL tweens that modify scale to prevent conflicts
	_kill_active_tweens()
	_reset_sprite_scale()
	
	# Re-attach to parent first
	_view.top_level = false 
	
	var is_heal_or_buff := flash_color.g >= flash_color.r
	var is_gold_flash := flash_color.r > 0.9 and flash_color.g > 0.7 and flash_color.g < 0.95 and flash_color.b < 0.2
	var flash_fade_duration := AC.FLASH_GOLD_FADE_DURATION if is_gold_flash else AC.FLASH_FADE_DURATION
	
	var original_position: Vector2 = _view.global_position
	
	# Only detach and save position if we are doing a position recoil (hurt)
	if not is_heal_or_buff:
		_flash_original_position = original_position
		_view.top_level = true
		_view.global_position = _flash_original_position
	else:
		_flash_original_position = Vector2.ZERO
	
	# Set up flash color
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("flash_intensity", 1.0)
	var original_parent_modulate: Color = _view.modulate
	_view.modulate = Color(flash_color.r * 1.3, flash_color.g * 1.3, flash_color.b * 1.3, 1.0)
	
	_flash_tween = _view.create_tween()
	
	if is_heal_or_buff:
		_ensure_pivot() # Set bottom-center pivot on sprite
		var sprite_start_y: float = sprite.position.y if is_instance_valid(sprite) else float(C.SLOT_UNIT_OFFSET_Y)
		var hop_target_y = sprite_start_y - AC.FLASH_HOP_HEIGHT
		
		# HOP: Squish anticipation -> Stretch up -> Squish land -> Normalize
		if is_instance_valid(sprite):
			# Step 1: Squish down (anticipation)
			_flash_tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Step 2: Stretch and jump up (in parallel, chained after anticipation)
			_flash_tween.chain().tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.FLASH_HOP_UP_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_flash_tween.parallel().tween_property(sprite, "position:y", hop_target_y, AC.scaled(AC.FLASH_HOP_UP_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			# Step 3: Fall and squish on landing (in parallel, chained after jump up)
			_flash_tween.chain().tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.FLASH_HOP_DOWN_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_flash_tween.parallel().tween_property(sprite, "position:y", sprite_start_y, AC.scaled(AC.FLASH_HOP_DOWN_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# Step 4: Return to normal scale (chained after landing)
			_flash_tween.chain().tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION * 2)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		# HURT: Instant recoil + stretch -> return to normal
		var recoil_direction := Vector2.RIGHT if _icon_rect.flip_h else Vector2.LEFT
		var recoil_target = original_position + (recoil_direction * AC.HURT_RECOIL_DISTANCE)
		
		# Instant recoil + stretch (hit by impact)
		_flash_tween.set_parallel(true)
		_flash_tween.tween_property(_view, "global_position", recoil_target, AC.scaled(AC.FLASH_RECOIL_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if is_instance_valid(sprite):
			_flash_tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.FLASH_RECOIL_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flash_tween.set_parallel(false)
		
		# Return to normal position and scale
		_flash_tween.set_parallel(true)
		_flash_tween.tween_property(_view, "global_position", original_position, AC.scaled(AC.FLASH_RETURN_DURATION)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if is_instance_valid(sprite):
			_flash_tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.FLASH_RETURN_DURATION)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_flash_tween.set_parallel(false)
	
	# Flash fade happens independently in parallel
	_flash_tween.set_parallel(true)
	_flash_tween.tween_method(func(v): mat.set_shader_parameter("flash_intensity", v), 1.0, 0.0, flash_fade_duration)
	_flash_tween.tween_property(_view, "modulate", original_parent_modulate, flash_fade_duration)
	_flash_tween.set_parallel(false)
	
	_flash_tween.finished.connect(_on_flash_tween_finished)

func _on_flash_tween_finished() -> void:
	if _flash_original_position != Vector2.ZERO:
		_view.top_level = false # Re-attach to parent layout
		_view.global_position = _flash_original_position
		_flash_original_position = Vector2.ZERO
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	_reset_sprite_scale()
	SignalBus.emit_signal("unit_flash_finished", _get_uuid())

# =============================================================================
# LETHAL SAVE ANIMATION (Aegis Charm)
# =============================================================================
func _on_unit_lethal_save(unit_uuid: String) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	_kill_active_tweens()
	
	# If this unit is a Guardian that was mid-leap or hadn't returned,
	# snap it back to its original slot before playing the lethal save animation.
	if _guardian_original_position != Vector2.ZERO and is_instance_valid(_view):
		_view.global_position = _guardian_original_position
		_guardian_original_position = Vector2.ZERO
		_view.top_level = false
		_view.position = Vector2.ZERO
		_move_original_local_position = Vector2.ZERO
		_move_original_top_level = false
	
	var sprite := _get_sprite()
	var sprite_start_y: float = sprite.position.y if (is_instance_valid(sprite) and sprite != _icon_rect) else float(C.SLOT_UNIT_OFFSET_Y)
	var levitate_target_y = sprite_start_y - AC.LETHAL_SAVE_LEVITATE_HEIGHT
	
	var mat = _get_active_material()
	
	var save_tween = _view.create_tween()
	_move_tween = save_tween
	
	# Phase 1: Float up while turning golden
	save_tween.set_parallel(true)
	if is_instance_valid(sprite) and sprite != _icon_rect:
		save_tween.tween_property(sprite, "position:y", levitate_target_y, AC.scaled(AC.LETHAL_SAVE_RISE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if mat:
		mat.set_shader_parameter("flash_color", AC.COLOR_GOLD)
		save_tween.tween_method(func(v): mat.set_shader_parameter("flash_intensity", v), 0.0, 1.0, AC.scaled(AC.LETHAL_SAVE_RISE_DURATION))
	save_tween.tween_property(_view, "modulate", AC.COLOR_GOLD_GLOW, AC.scaled(AC.LETHAL_SAVE_RISE_DURATION))
	
	# Hold at peak
	save_tween.set_parallel(false)
	save_tween.tween_interval(AC.scaled(AC.LETHAL_SAVE_HOLD_DURATION))
	
	# Phase 2: Land back down
	save_tween.set_parallel(true)
	if is_instance_valid(sprite) and sprite != _icon_rect:
		save_tween.tween_property(sprite, "position:y", sprite_start_y, AC.scaled(AC.LETHAL_SAVE_LAND_DURATION)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if mat:
		save_tween.tween_method(func(v): mat.set_shader_parameter("flash_intensity", v), 1.0, 0.0, AC.scaled(AC.LETHAL_SAVE_LAND_DURATION))
	save_tween.tween_property(_view, "modulate", Color.WHITE, AC.scaled(AC.LETHAL_SAVE_LAND_DURATION))
	
	save_tween.set_parallel(false)
	save_tween.finished.connect(_on_lethal_save_tween_finished)

func _on_lethal_save_tween_finished() -> void:
	var sprite := _get_sprite()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	_reset_shadow()
	_move_tween = null
	SignalBus.emit_signal("unit_lethal_save_finished", _get_uuid())

# =============================================================================
# GUARDIAN LEAP ANIMATION
# =============================================================================
func animate_leap_to(target_center: Vector2) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		_restore_move_layout_state()
		
	_guardian_original_position = _view.global_position
	_original_z_index = _view.z_index
	_view.z_index = 100
	
	var target_pos = Vector2(
		target_center.x - _view.size.x / 2,
		target_center.y - _view.size.y / 2
	)
	
	_anim_start_pos = _guardian_original_position
	_anim_target_pos = target_pos
	_is_lunging = true
	
	var sprite := _get_sprite()
	_ensure_pivot() # Recalculate pivot with current size
	
	var tween = _view.create_tween()
	_move_tween = tween
	
	# Phase 1: Squish sprite before leap (anticipation)
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 2: Stretch sprite and leap
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 3: Move horizontally to target position, parabolic arc vertically on sprite
	var leap_duration = AC.scaled(AC.GUARDIAN_LEAP_DURATION - AC.DEFORM_DURATION * 2)
	tween.set_parallel(true)
	tween.tween_property(_view, "global_position:x", target_pos.x, leap_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(sprite) and sprite != _icon_rect:
		tween.tween_method(
			func(t: float):
				var hop = 4.0 * AC.GUARDIAN_ARC_HEIGHT * t * (1.0 - t)
				sprite.position.y = C.SLOT_UNIT_OFFSET_Y - hop,
			0.0, 1.0, leap_duration
		)
	tween.set_parallel(false)
	
	# Phase 4: Squish sprite on landing
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 5: Return sprite to normal scale
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y

func animate_leap_return() -> void:
	if _guardian_original_position == Vector2.ZERO:
		return
		
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		_restore_move_layout_state()
	
	_anim_start_pos = _view.global_position
	_anim_target_pos = _guardian_original_position
	_is_lunging = true
	
	var sprite := _get_sprite()
	_ensure_pivot() # Recalculate pivot with current size
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	
	var tween = _view.create_tween()
	_move_tween = tween
	
	# Phase 1: Stretch sprite for return jump
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 2: Return to origin position X
	var return_duration = AC.scaled(AC.GUARDIAN_RETURN_DURATION - AC.DEFORM_DURATION * 2)
	tween.tween_property(_view, "global_position:x", _guardian_original_position.x, return_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Phase 3: Squish sprite on landing
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Phase 4: Return sprite to normal scale
	if is_instance_valid(sprite):
		tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	_view.z_index = _original_z_index
	_reset_sprite_scale()
	if is_instance_valid(sprite) and sprite != _icon_rect:
		sprite.position.y = C.SLOT_UNIT_OFFSET_Y
	_guardian_original_position = Vector2.ZERO
	if is_instance_valid(_view):
		_view.top_level = false
		_view.position = Vector2.ZERO
		_move_original_local_position = Vector2.ZERO
		_move_original_position = _view.global_position
		_move_original_top_level = false
	_is_lunging = false
	_reset_shadow()
	_move_tween = null

# =============================================================================
# COMPOSABLE ANIMATION EFFECTS (Independent, parallel)
# =============================================================================

# --- COLOR FLASH (shader-based tint that fades) ---
func _on_unit_color_flash(unit_uuid: String, flash_color: Color, duration: float) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	var mat = _get_active_material()
	if not mat:
		return
	
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	
	# Set flash
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("flash_intensity", 1.0)
	var original_modulate: Color = _view.modulate
	_view.modulate = Color(flash_color.r * 1.3, flash_color.g * 1.3, flash_color.b * 1.3, 1.0)
	
	# Fade out
	_color_tween = _view.create_tween()
	_color_tween.set_parallel(true)
	_color_tween.tween_method(func(v): mat.set_shader_parameter("flash_intensity", v), 1.0, 0.0, AC.scaled(duration))
	_color_tween.tween_property(_view, "modulate", original_modulate, AC.scaled(duration))
	_color_tween.set_parallel(false)
	
	_color_tween.finished.connect(func(): SignalBus.emit_signal("unit_color_flash_finished", _get_uuid()))

# --- DEFORMATION (squish/stretch on sprite scale) ---
func _on_unit_deform(unit_uuid: String, deform_type: StringName) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	var sprite := _get_sprite()
	if not is_instance_valid(sprite):
		return
	
	if _deform_tween and _deform_tween.is_valid():
		_deform_tween.kill()
	
	_deform_tween = _view.create_tween()
	
	_ensure_pivot() # Set center pivot on sprite
	
	match deform_type:
		&"SQUISH_BOUNCE":
			# Squish (narrow/tall) → return with elastic
			_deform_tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_deform_tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION * 2)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		&"STRETCH_BOUNCE":
			# Stretch (wide/short) → return with elastic
			_deform_tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(AC.DEFORM_DURATION)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_deform_tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(AC.DEFORM_DURATION * 2)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		&"HIT_IMPACT":
			# Impact: Quick stretch then elastic return
			_deform_tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(0.04)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_deform_tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(0.24)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		&"HOP_DEFORM":
			# Synced with HOP movement (0.12s up + 0.18s down = 0.3s total)
			_deform_tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(0.03)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_deform_tween.tween_property(sprite, "scale", AC.STRETCH_SCALE, AC.scaled(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_deform_tween.tween_property(sprite, "scale", AC.SQUISH_SCALE, AC.scaled(0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_deform_tween.tween_property(sprite, "scale", Vector2.ONE, AC.scaled(0.12)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		&"LANDING_BOUNCE":
			# Inventory action landing feedback (bounce the WHOLE ball: capsule + unit + stats)
			# We animate the sprite to prevent breaking container layouts when in HBox/VBox.
			if is_instance_valid(sprite):
				sprite.pivot_offset = Vector2(sprite.size.x / 2.0, sprite.size.y)
				AC.append_landing_bounce(_deform_tween, sprite, Vector2.ONE)
	
	_deform_tween.finished.connect(func():
		_reset_sprite_scale()
		SignalBus.emit_signal("unit_deform_finished", _get_uuid())
	)

# --- MOVEMENT (position animation) ---
func _on_unit_move(unit_uuid: String, move_type: StringName, direction: Vector2) -> void:
	if _get_uuid() != unit_uuid:
		return
	
	# Kill existing move tween
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		_restore_move_layout_state()
	
	if move_type == &"HOP":
		var sprite := _get_sprite()
		if not is_instance_valid(sprite):
			SignalBus.emit_signal("unit_move_finished", _get_uuid())
			return
		
		_move_original_sprite_y = sprite.position.y
		var hop_target_y = _move_original_sprite_y - AC.FLASH_HOP_HEIGHT
		
		_move_tween = _view.create_tween()
		_move_tween.tween_property(sprite, "position:y", hop_target_y, AC.scaled(AC.FLASH_HOP_UP_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_move_tween.tween_property(sprite, "position:y", _move_original_sprite_y, AC.scaled(AC.FLASH_HOP_DOWN_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		_move_tween.finished.connect(func():
			if is_instance_valid(sprite):
				sprite.position.y = _move_original_sprite_y
			_move_tween = null
			SignalBus.emit_signal("unit_move_finished", _get_uuid())
		)
		return
	
	# CRITICAL: Capture global position BEFORE detaching from parent
	_move_original_position = _view.global_position
	_move_original_local_position = _view.position
	_move_original_size = _view.size
	_move_original_top_level = _view.top_level
	
	# Detach from parent layout - this changes coordinate space!
	_view.top_level = true
	
	# IMMEDIATELY restore global position to prevent visual jump
	# Without this, the node jumps to (local coords interpreted as global)
	_view.global_position = _move_original_position
	_move_tween = _view.create_tween()
	
	match move_type:
		&"RECOIL":
			var recoil_target = _move_original_position + (direction.normalized() * AC.HURT_RECOIL_DISTANCE)
			_move_tween.tween_property(_view, "global_position", recoil_target, AC.scaled(AC.FLASH_RECOIL_DURATION)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_move_tween.tween_property(_view, "global_position", _move_original_position, AC.scaled(AC.FLASH_RETURN_DURATION)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		&"BUMP":
			var bump_target = _move_original_position + (direction.normalized() * AC.BUMP_DISTANCE)
			_move_tween.tween_property(_view, "global_position", bump_target, AC.scaled(AC.BUMP_FORWARD_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_move_tween.tween_property(_view, "global_position", _move_original_position, AC.scaled(AC.BUMP_RETURN_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	_move_tween.finished.connect(func():
		_restore_move_layout_state()
		SignalBus.emit_signal("unit_move_finished", _get_uuid())
	)
