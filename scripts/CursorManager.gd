extends Node

const BASE_CURSOR = preload("res://assets/ui/textures/BaseCursor.png")
const CLICKED_CURSOR = preload("res://assets/ui/textures/ClickedCursor.png")

var _cursor_sprite: Sprite2D
var _canvas_layer: CanvasLayer
var _is_pressed: bool = false

func _ready() -> void:
	# Process during pauses and high-priority
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide the system hardware cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Create a CanvasLayer to keep the cursor on top of everything
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 1024 # Above everything: HUD, Modals, and Post-processing
	add_child(_canvas_layer)
	
	# Create the Sprite2D for the software cursor
	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.texture = BASE_CURSOR
	_cursor_sprite.centered = false # Most cursor hot-spots are top-left (0,0)
	_canvas_layer.add_child(_cursor_sprite)

func _process(_delta: float) -> void:
	# Software cursor position update
	# Using viewport mouse position to correctly map to the screen/window
	var mouse_pos = get_viewport().get_mouse_position()
	_cursor_sprite.global_position = mouse_pos
	
	# Instant texture swap based on mouse state polling
	var current_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if current_pressed != _is_pressed:
		_is_pressed = current_pressed
		_cursor_sprite.texture = CLICKED_CURSOR if _is_pressed else BASE_CURSOR

func _notification(what: int) -> void:
	# Ensure the cursor remains hidden when the window is focused
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Optionally reveal it when leaving the app, though Godot handles this
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
