extends Node

const BASE_CURSOR = preload("res://assets/Realistic/ui/textures/BaseCursor.png")
const CLICKED_CURSOR = preload("res://assets/Realistic/ui/textures/ClickedCursor.png")

var _cursor_sprite: Sprite2D
var _canvas_layer: CanvasLayer
var _is_pressed: bool = false
var _is_waiting_for_animations: bool = false
var _waiting_control: Node2D

func _ready() -> void:
		# Set maximum priority to ensure the cursor is updated as early as possible
	process_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if OS.has_feature("mobile"):
		set_process(false)
		return
	
	# CRITICAL MAINTENANCE RULE:
	# Do NOT enable input accumulation! Disabling it allows the software 
	# cursor to track at the raw OS polling rate (e.g., 1000Hz). 
	# Enabling it will cause the cursor to feel "slow" or "floaty".
	Input.use_accumulated_input = false
	
	# Hide the system hardware cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Create a CanvasLayer to keep the software cursor on top of everything
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1024
	add_child(_canvas_layer)
	
	# Create the Sprite2D for the high-performance software cursor
	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.texture = ArtStyleManager.get_themed_texture(BASE_CURSOR)
	_cursor_sprite.centered = false
	_canvas_layer.add_child(_cursor_sprite)
	
	# Create the waiting indicator Node2D ON TOP of the cursor sprite (z-index / render order)
	_waiting_control = Node2D.new()
	_canvas_layer.add_child(_waiting_control)
	_waiting_control.draw.connect(_on_waiting_draw)
	_waiting_control.visible = false
	
	# Connect to style changes so the cursor updates instantly without waiting for a click
	ArtStyleManager.style_changed.connect(_update_cursor_visuals)

func _input(event: InputEvent) -> void:
	# CRITICAL PERFORMANCE RULE:
	# Update position and visual state in _input, NOT in _process.
	# This avoids the "one-frame lag" typical of software cursors.
	if event is InputEventMouseMotion:
		# RAW INPUT POSITION SYNC:
		# By updating position here (and having accumulation disabled),
		# the software sprite tracks the OS cursor with sub-frame precision.
		_cursor_sprite.global_position = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# INSTANT STATE SWAP:
			# This changes the texture at the exact moment of the OS click event
			# even if the mouse is perfectly stationary.
			_is_pressed = event.pressed
			_update_cursor_visuals()

func _update_cursor_visuals() -> void:
	var target_tex = CLICKED_CURSOR if _is_pressed else BASE_CURSOR
	_cursor_sprite.texture = ArtStyleManager.get_themed_texture(target_tex)

func set_waiting_indicator(active: bool) -> void:
	if _is_waiting_for_animations == active:
		return
	_is_waiting_for_animations = active
	if not is_instance_valid(_waiting_control):
		return
	_waiting_control.visible = active
	if active:
		_waiting_control.queue_redraw()

func _process(_delta: float) -> void:
	if _is_waiting_for_animations and is_instance_valid(_waiting_control) and is_instance_valid(_cursor_sprite):
		_waiting_control.global_position = _cursor_sprite.global_position
		_waiting_control.queue_redraw()

func _on_waiting_draw() -> void:
	if not _is_waiting_for_animations or not is_instance_valid(_waiting_control):
		return
	var step = int((Time.get_ticks_msec() / 350) % 3) + 1
	var radius = 3.5
	var outline_size = 1.5
	# Positioned vertically below the hand cursor (y = 52)
	for i in range(step):
		var pos = Vector2(12 + i * 11, 52)
		_waiting_control.draw_circle(pos, radius + outline_size, Color.BLACK)
		_waiting_control.draw_circle(pos, radius, Color.WHITE)

func _notification(what: int) -> void:
	# Skip hardware cursor management on mobile platforms
	if OS.has_feature("mobile"):
		return
		
	# Ensure the cursor remains hidden when the window is focused
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Optionally reveal it when leaving the app, though Godot handles this
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
