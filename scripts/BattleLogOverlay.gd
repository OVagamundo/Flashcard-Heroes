# scripts/BattleLogOverlay.gd
class_name BattleLogOverlay
extends CanvasLayer

## A draggable, collapsible battle log window that displays combat events in real-time.

@onready var window_container: Control = $WindowContainer
@onready var log_text: RichTextLabel = %LogText
@onready var log_scroll: ScrollContainer = %LogScrollContainer
@onready var header: PanelContainer = %Header
@onready var drag_handle: Label = %DragHandle
@onready var collapse_button: Button = %CollapseButton
@onready var clear_button: Button = %ClearButton
@onready var resize_handle: Control = $WindowContainer/ResizeHandle

var _is_collapsed: bool = false
var _is_dragging: bool = false
var _is_resizing: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _min_size: Vector2 = Vector2(300, 150)
var _expanded_size: Vector2 = Vector2(500, 350)
var _collapsed_height: float = 120.0 # Reserved for future mini-mode

func _ready() -> void:
	# Start hidden by default, toggle with F1
	self.visible = false
	
	# Connect to BattleLogger signals
	BattleLogger.log_entry_added.connect(_on_log_entry_added)
	BattleLogger.log_cleared.connect(_on_log_cleared)
	
	# Connect button signals
	collapse_button.pressed.connect(_toggle_collapse)
	clear_button.pressed.connect(_on_clear_pressed)
	
	# Set initial size
	window_container.size = _expanded_size
	
	# Initial log message
	log_text.clear()
	log_text.append_text("[color=gray]Press B to toggle battle log visibility[/color]\n")

func _unhandled_input(event: InputEvent) -> void:
	# Toggle visibility with B
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		self.visible = not self.visible
		get_viewport().set_input_as_handled()

func _gui_input(_event: InputEvent) -> void:
	pass # Handled by child nodes

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Handle dragging
	if _is_dragging:
		if event is InputEventMouseMotion:
			window_container.position = get_viewport().get_mouse_position() - _drag_offset
		elif event is InputEventMouseButton and not event.pressed:
			_is_dragging = false
	
	# Handle resizing
	if _is_resizing:
		if event is InputEventMouseMotion:
			var mouse_pos = get_viewport().get_mouse_position()
			var new_size = mouse_pos - window_container.position
			new_size.x = max(_min_size.x, new_size.x)
			new_size.y = max(_min_size.y, new_size.y)
			window_container.size = new_size
			if not _is_collapsed:
				_expanded_size = new_size
		elif event is InputEventMouseButton and not event.pressed:
			_is_resizing = false

func _on_Header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = get_viewport().get_mouse_position() - window_container.position
		else:
			_is_dragging = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Connect header GUI input
		header.gui_input.connect(_on_Header_gui_input)
		resize_handle.gui_input.connect(_on_ResizeHandle_gui_input)

func _on_ResizeHandle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_resizing = true
		else:
			_is_resizing = false

func _toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	
	if _is_collapsed:
		log_scroll.visible = false
		collapse_button.text = "▶ Show"
		window_container.size.y = header.size.y + 10
	else:
		log_scroll.visible = true
		collapse_button.text = "▼ Hide"
		window_container.size = _expanded_size

func _on_clear_pressed() -> void:
	BattleLogger.clear_log()

func _on_log_entry_added(entry: Dictionary) -> void:
	var indent = "  ".repeat(entry.indent_level)
	if entry.indent_level > 0:
		indent = "    └─ "
	
	var turn_prefix = ""
	if entry.type != "turn":
		turn_prefix = "[color=gray][%d:%d][/color] " % [entry.turn, entry.event_index]
	
	var details = ""
	if entry.details != "":
		details = " [color=gray]%s[/color]" % entry.details
	
	var line = "%s%s%s%s\n" % [turn_prefix, indent, entry.message, details]
	log_text.append_text(line)
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func _on_log_cleared() -> void:
	log_text.clear()
	log_text.append_text("[color=gray]Log cleared[/color]\n")
