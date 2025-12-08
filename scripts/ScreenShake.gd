# res://scripts/ScreenShake.gd
extends Node

## Screen shake controller for damage feedback
## Attach to the Main scene to enable screen shake effects

@export var max_shake_offset: float = 12.0 # Maximum pixel offset at full intensity
@export var shake_duration: float = 0.12 # Duration of shake in seconds
@export var shake_frequency: float = 30.0 # How many shakes per second

var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _original_position: Vector2 = Vector2.ZERO
var _target_node: Control = null

func _ready() -> void:
	# Connect to the screen shake signal
	SignalBus.screen_shake_requested.connect(_on_screen_shake_requested)
	
	# Find VBoxContainer to shake (contains all game content)
	await get_tree().process_frame
	_find_target_node()

func _find_target_node() -> void:
	# Look for VBoxContainer in parent (Main scene)
	var parent = get_parent()
	if is_instance_valid(parent):
		_target_node = parent.get_node_or_null("VBoxContainer")
		if is_instance_valid(_target_node):
			_original_position = _target_node.position

func _process(delta: float) -> void:
	if _shake_intensity <= 0.0:
		return
	
	if not is_instance_valid(_target_node):
		return
	
	# Update shake timer
	_shake_timer -= delta
	
	if _shake_timer <= 0:
		# Shake finished, reset position
		_shake_intensity = 0.0
		_target_node.position = _original_position
		return
	
	# Calculate decay factor (eases out)
	var decay = _shake_timer / shake_duration
	var current_intensity = _shake_intensity * decay
	
	# Apply random offset based on intensity
	var offset = Vector2(
		randf_range(-1.0, 1.0) * max_shake_offset * current_intensity,
		randf_range(-1.0, 1.0) * max_shake_offset * current_intensity
	)
	
	_target_node.position = _original_position + offset

func _on_screen_shake_requested(intensity: float) -> void:
	# Clamp intensity to 0.0 - 1.0 range
	intensity = clampf(intensity, 0.0, 1.0)
	
	# Only update if new shake is stronger than current (don't interrupt strong shakes)
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_timer = shake_duration
		
		# Store original position if not already shaking
		if is_instance_valid(_target_node) and _shake_intensity <= 0.0:
			_original_position = _target_node.position
