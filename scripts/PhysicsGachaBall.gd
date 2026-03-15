class_name PhysicsGachaBall
extends RigidBody2D

const InputUtils = preload("res://scripts/InputUtils.gd")
const GachaBallCapsuleGlow = preload("res://scripts/GachaBallCapsuleGlow.gd")

# Shared across all balls
static var next_allowed_clack_time: int = 0

var instance_uuid: String
var location: LocationIdentifier
var entity_type: StringName
var _pending_texture: Texture2D

@onready var capsule_sprite: Sprite2D = $CapsuleSprite
@onready var icon_sprite: Sprite2D = $IconSprite
@onready var ui_anchor: Control = $UIAnchor
@onready var impact_audio: AudioStreamPlayer = $AudioStreamPlayer

var _orig_capsule_scale: Vector2
var _orig_icon_scale: Vector2
var _touch_long_press_timer: Timer = null
var _touch_press_active: bool = false
var _touch_long_press_triggered: bool = false
var _touch_press_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Shift interaction detection from the physics body to the UI node
	ui_anchor.mouse_entered.connect(_on_mouse_entered)
	ui_anchor.mouse_exited.connect(_on_mouse_exited)
	ui_anchor.gui_input.connect(_on_gui_input)
	
	# Hook into global selection state for visual highlighting
	SignalBus.view_selected.connect(_on_view_selected)
	SignalBus.view_deselected.connect(_on_view_deselected)
	
	# Add the collision listener for sound
	body_entered.connect(_on_body_entered)
	
	_orig_capsule_scale = capsule_sprite.scale
	_orig_icon_scale = icon_sprite.scale
	GachaBallCapsuleGlow.apply_to_sprite(capsule_sprite)

	_touch_long_press_timer = Timer.new()
	_touch_long_press_timer.one_shot = true
	_touch_long_press_timer.wait_time = InputUtils.TOUCH_LONG_PRESS_SEC
	_touch_long_press_timer.timeout.connect(_on_touch_long_press_timeout)
	add_child(_touch_long_press_timer)

	if not CRTEffect.glow_toggled.is_connected(_on_global_glow_toggled):
		CRTEffect.glow_toggled.connect(_on_global_glow_toggled)
	_refresh_capsule_local_glow()
	
	if _pending_texture and is_instance_valid(icon_sprite):
		icon_sprite.texture = _pending_texture
		_pending_texture = null

func _exit_tree() -> void:
	_stop_touch_long_press()
	if CRTEffect.glow_toggled.is_connected(_on_global_glow_toggled):
		CRTEffect.glow_toggled.disconnect(_on_global_glow_toggled)

func populate(uuid: String, type: StringName, loc: LocationIdentifier, tex: Texture2D) -> void:
	instance_uuid = uuid
	entity_type = type
	location = loc
	if tex:
		if is_node_ready() and is_instance_valid(icon_sprite):
			icon_sprite.texture = tex
		else:
			_pending_texture = tex

func _refresh_capsule_local_glow(enabled: bool = CRTEffect.is_glow_enabled()) -> void:
	GachaBallCapsuleGlow.set_sprite_glow_enabled(capsule_sprite, enabled)

func _on_global_glow_toggled(enabled: bool) -> void:
	_refresh_capsule_local_glow(enabled)

# Replaced physics _input_event with the standard Control gui_input
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_press_active = true
			_touch_long_press_triggered = false
			_touch_press_position = event.position
			if is_instance_valid(_touch_long_press_timer):
				_touch_long_press_timer.start()
			ui_anchor.accept_event()
		else:
			var long_press_was_triggered := _touch_long_press_triggered
			_stop_touch_long_press()
			if long_press_was_triggered:
				_emit_interaction(&"HOVER_EXIT")
			else:
				_emit_interaction(&"SINGLE_CLICK")
			ui_anchor.accept_event()
		return

	if event is InputEventScreenDrag and _touch_press_active and not _touch_long_press_triggered:
		if event.position.distance_to(_touch_press_position) > InputUtils.TOUCH_DRAG_THRESHOLD_PX:
			_stop_touch_long_press()
		ui_anchor.accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if InputUtils.should_ignore_mouse_pointer_event(event):
			return
		_emit_interaction(&"SINGLE_CLICK")
		ui_anchor.accept_event()

func _stop_touch_long_press() -> void:
	_touch_press_active = false
	_touch_long_press_triggered = false
	_touch_press_position = Vector2.ZERO
	if is_instance_valid(_touch_long_press_timer):
		_touch_long_press_timer.stop()

func _on_touch_long_press_timeout() -> void:
	if not _touch_press_active:
		return
	_touch_long_press_triggered = true
	_emit_interaction(&"HOVER_ENTER")

func _on_mouse_entered() -> void:
	if InputUtils.prefers_touch_input():
		return
	_emit_interaction(&"HOVER_ENTER")

func _on_mouse_exited() -> void:
	if InputUtils.prefers_touch_input():
		return
	_emit_interaction(&"HOVER_EXIT")

func _emit_interaction(event_type: StringName) -> void:
	var context = InteractionContext.new()
	# CRITICAL: Pass the UIAnchor Control ID, not the RigidBody ID, so WindowManager can anchor to it.
	context.source_view_instance_id = ui_anchor.get_instance_id()
	context.event_type = event_type
	context.location = location
	context.entity_uuid = instance_uuid
	context.entity_type = entity_type
	context.interaction_mode = &"FULLY_INTERACTIVE" # FIX: enables standard selection behavior
	context.window_group_id = 0
	SignalBus.emit_signal("interaction_context_received", context)

func _on_view_selected(view: Control, _loc: LocationIdentifier) -> void:
	if view == ui_anchor:
		capsule_sprite.modulate = Color(1.3, 1.3, 1.3) # Brighten to highlight
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(capsule_sprite, "scale", _orig_capsule_scale * 1.08, 0.1)
		tween.tween_property(icon_sprite, "scale", _orig_icon_scale * 1.08, 0.1)

func _on_view_deselected(view: Control) -> void:
	if view == ui_anchor:
		capsule_sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(capsule_sprite, "scale", _orig_capsule_scale, 0.1)
		tween.tween_property(icon_sprite, "scale", _orig_icon_scale, 0.1)

func _on_body_entered(body: Node) -> void:
	var impact_velocity: float = linear_velocity.length()
	if body is RigidBody2D:
		impact_velocity = (linear_velocity - body.linear_velocity).length()
		
	# Ignore very soft settling micro-bounces
	if impact_velocity > 150.0:
		var current_time = Time.get_ticks_msec()
		
		if current_time >= next_allowed_clack_time:
			# 1. RANDOMIZED COOLDOWN: Break the "machine gun" rhythm
			# The next sound is allowed anywhere from 30ms to 100ms from now
			next_allowed_clack_time = current_time + randi_range(30, 100)
			
			# 2. CALCULATE IMPACT INTENSITY (0.0 to 1.0)
			# We subtract the 150 threshold so the lowest valid hit starts at 0 intensity.
			# Assume 1000.0 is a very hard slam (adjust if your balls move faster/slower).
			var intensity = clamp((impact_velocity - 150.0) / 1000.0, 0.0, 1.0)
			
			# 3. DYNAMIC VOLUME & PITCH
			# Map intensity to decibels (-24dB is very quiet, 0dB is full volume)
			var volume_db = lerp(-24.0, 0.0, intensity)
			
			# Harder hits get a slightly higher base pitch, plus a random variance
			var base_pitch = lerp(0.85, 1.1, intensity)
			var final_pitch = base_pitch + randf_range(-0.1, 0.15)
			
			# 4. PLAY THE SOUND
			_play_impact_sound(final_pitch, volume_db)

func _play_impact_sound(pitch: float, volume: float) -> void:
	impact_audio.pitch_scale = pitch
	impact_audio.volume_db = volume
	impact_audio.play()
