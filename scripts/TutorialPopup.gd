# res://scripts/TutorialPopup.gd
extends Control
class_name TutorialPopup

## Modal tutorial popup with multi-page support and pointer arrows
## Supports dynamic positioning relative to anchors (e.g. "display above")
## Automatically handles platform-specific text (.mouse vs .touch suffixes)

const BUTTON_FONT = preload("res://assets/fonts/static/NotoSansJP-Bold.ttf")
const WINDOW_MARGIN: float = 30.0 # Distance from screen edges or anchor

@onready var background_blocker: Control = $BackgroundBlocker
@onready var popup_panel: PanelContainer = %PopupPanel
@onready var title_label: Label = %TitleLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var page_indicator: HBoxContainer = %PageIndicator
@onready var next_button: Button = %NextButton
@onready var got_it_button: Button = %GotItButton
@onready var pointer_line: Line2D = $PointerLine

var _tutorial_id: StringName = &""
var _pages: Array = []
var _current_page: int = 0
var _anchor: Control = null
var _extra_lines: Array[Line2D] = []


func _ready() -> void:
	# Ensure popup handles input while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initial state for animation
	modulate.a = 0.0
	popup_panel.scale = Vector2(0.9, 0.9)
	
	# Pause the game
	get_tree().paused = true
	
	next_button.pressed.connect(_on_next_pressed)
	got_it_button.pressed.connect(_on_got_it_pressed)
	
	# Initial hide of pointer line
	pointer_line.hide()
	
	_play_open_animation()


func populate(context: Dictionary) -> void:
	_tutorial_id = context.get("tutorial_id", &"")
	_pages = context.get("pages", [])
	_anchor = context.get("anchor", null)
	_current_page = 0
	
	if _pages.is_empty():
		_close_popup()
		return
	
	_update_page_display()
	_reposition_window()
	_update_pointer()
	_update_pointer()


func _play_open_animation() -> void:
	# Instant visibility
	modulate.a = 1.0
	popup_panel.scale = Vector2.ONE
	show()

	# Ensure pivot is centered for bounce effect
	# Wait for layout to settle sizes
	await get_tree().process_frame
	_reposition_window()
	popup_panel.pivot_offset = popup_panel.size / 2.0
	
	# Tween: Subtle bouncy overshoot AFTER it's open
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Subtle overshoot (1.0 -> 1.04 -> 1.0)
	# 0.1s up, 0.15s back to neutral
	tween.tween_property(popup_panel, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reposition_window() -> void:
	if not is_inside_tree(): return
	
	# Force layout update to get accurate size
	popup_panel.reset_size()
	
	var viewport_size := get_viewport_rect().size
	var panel_size := popup_panel.size
	
	var page: Dictionary = {}
	if _current_page < _pages.size():
		page = _pages[_current_page]
	
	var anchor_side: String = page.get("anchor_side", "").to_upper()
	
	# Priority 1: Centering
	if page.get("center", false):
		var centered_position := (viewport_size - panel_size) / 2.0
		if is_instance_valid(_anchor):
			var popup_rect := Rect2(centered_position, panel_size)
			var anchor_rect := _anchor.get_global_rect()
			if popup_rect.intersects(anchor_rect):
				var below_y := anchor_rect.end.y + WINDOW_MARGIN
				var above_y := anchor_rect.position.y - panel_size.y - WINDOW_MARGIN
				if below_y <= viewport_size.y - panel_size.y - WINDOW_MARGIN:
					centered_position.y = below_y
				elif above_y >= WINDOW_MARGIN:
					centered_position.y = above_y
				else:
					centered_position.y = clampf(centered_position.y, WINDOW_MARGIN, viewport_size.y - panel_size.y - WINDOW_MARGIN)
		popup_panel.global_position = centered_position
		return
	
	# Priority 2: Corner cases (independent of anchor)
	if anchor_side == "TOP_LEFT":
		popup_panel.global_position = Vector2(WINDOW_MARGIN, WINDOW_MARGIN)
		return
	if anchor_side == "TOP_RIGHT":
		popup_panel.global_position = Vector2(viewport_size.x - panel_size.x - WINDOW_MARGIN, WINDOW_MARGIN)
		return
	
	# Priority 3: Relative to Anchor
	if is_instance_valid(_anchor):
		var anchor_rect := _anchor.get_global_rect()
		var target_x: float
		var target_y: float
		
		match anchor_side:
			"LEFT":
				target_x = anchor_rect.position.x - panel_size.x - WINDOW_MARGIN
				target_y = anchor_rect.get_center().y - (panel_size.y / 2.0)
			"RIGHT":
				target_x = anchor_rect.end.x + WINDOW_MARGIN
				target_y = anchor_rect.get_center().y - (panel_size.y / 2.0)
			"BELOW":
				target_x = anchor_rect.get_center().x - (panel_size.x / 2.0)
				target_y = anchor_rect.end.y + WINDOW_MARGIN
			_: # Default to ABOVE (or if side is unknown)
				target_x = anchor_rect.get_center().x - (panel_size.x / 2.0)
				target_y = anchor_rect.position.y - panel_size.y - WINDOW_MARGIN
		
		# Clamp to screen bounds with margin
		target_x = clamp(target_x, WINDOW_MARGIN, viewport_size.x - panel_size.x - WINDOW_MARGIN)
		target_y = clamp(target_y, WINDOW_MARGIN, viewport_size.y - panel_size.y - WINDOW_MARGIN)
		
		popup_panel.global_position = Vector2(target_x, target_y)
	else:
		# Fallback to centering if no anchor is valid
		popup_panel.global_position = (viewport_size - panel_size) / 2.0


func _update_page_display() -> void:
	if _current_page >= _pages.size():
		_close_popup()
		return
	
	var page: Dictionary = _pages[_current_page]
	var page_text: String = page.get("text", "")
	
	# Handle per-page titles if 'title' key is provided in the page dictionary
	var current_title: String = ""
	if page.has("title"):
		current_title = page.get("title", "")
	else:
		# Fallback to the tutorial's default title (tutorial.[id].title)
		var title_key = "tutorial." + String(_tutorial_id) + ".title"
		var translated_title = tr(title_key)
		if translated_title != title_key:
			current_title = translated_title
		else:
			current_title = tr("ui.tutorial_title") if tr("ui.tutorial_title") != "ui.tutorial_title" else "TUTORIAL"
	
	title_label.text = current_title

	# Platform-specific text logic:
	# If text is a translation key (starting with 'tutorial.'), check for variants
	if page_text.begins_with("tutorial."):
		var platform_suffix = ".touch" if DisplayServer.is_touchscreen_available() else ".mouse"
		var platform_key = page_text + platform_suffix
		var platform_text = tr(platform_key)
		
		# If variant exists, use it. Otherwise fallback to the base key.
		if platform_text != platform_key:
			page_text = platform_text
		else:
			page_text = tr(page_text)
	
	# Parse BBCode for rich text formatting
	# Collapse multiple newlines to remove empty lines between paragraphs as requested
	var collapsed_text = page_text
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	collapsed_text = regex.sub(collapsed_text, "\n", true)
	text_label.text = collapsed_text
	
	# Handle per-page anchors if anchor_path is provided
	if page.has("anchor_path") and not page.get("anchor_path", "").is_empty():
		var new_anchor = get_node_or_null(page["anchor_path"])
		if is_instance_valid(new_anchor) and new_anchor is Control:
			_anchor = new_anchor
	
	# Update page indicator dots
	_update_page_indicator()
	
	_reposition_window()
	_update_pointer()
	
	# Show appropriate buttons
	var is_last_page := _current_page >= _pages.size() - 1
	next_button.visible = not is_last_page
	next_button.text = tr("tutorial.btn.next")
	got_it_button.visible = is_last_page
	got_it_button.text = tr("tutorial.btn.got_it")


func _update_page_indicator() -> void:
	# Clear existing dots
	for child in page_indicator.get_children():
		child.queue_free()
	
	# Only show dots if multiple pages
	if _pages.size() <= 1:
		return
	
	# Create dot for each page
	for i in range(_pages.size()):
		var dot := Label.new()
		dot.text = "●" if i == _current_page else "○"
		dot.add_theme_font_size_override("font_size", 16)
		page_indicator.add_child(dot)


func _update_pointer() -> void:
	# Clean up previous extra lines
	for line in _extra_lines:
		if is_instance_valid(line):
			line.queue_free()
	_extra_lines.clear()
	
	# Current page dictionary
	var page: Dictionary = {}
	if _current_page < _pages.size():
		page = _pages[_current_page]
		
	# Collect all anchors to point to
	var anchors_to_point: Array[Control] = []
	
	# 1. Check for 'anchor_paths' (plural array)
	var anchor_paths = page.get("anchor_paths", [])
	if anchor_paths is Array:
		for path in anchor_paths:
			var node = get_node_or_null(path)
			if is_instance_valid(node) and node is Control:
				anchors_to_point.append(node)
	
	# 2. Falling back to single 'anchor_path' or the initial '_anchor'
	if anchors_to_point.is_empty():
		var page_anchor: Control = _anchor
		var single_path: String = page.get("anchor_path", "")
		if not single_path.is_empty():
			var node = get_node_or_null(single_path)
			if is_instance_valid(node) and node is Control:
				page_anchor = node
		
		if is_instance_valid(page_anchor):
			anchors_to_point.append(page_anchor)
	
	if anchors_to_point.is_empty():
		pointer_line.hide()
		return
	
	# Draw lines for all collected anchors
	pointer_line.hide() # Hide default one as we will treat it as another instance or similar
	
	# Calculate lines after layout
	await get_tree().process_frame
	if not is_instance_valid(popup_panel): return
	
	var popup_rect := popup_panel.get_global_rect()
	var popup_center := popup_rect.get_center()
	
	for i in range(anchors_to_point.size()):
		var target = anchors_to_point[i]
		if not is_instance_valid(target): continue
		
		var target_rect := target.get_global_rect()
		var target_center := target_rect.get_center()
		
		# Skip if popup overlaps target significantly
		if popup_rect.has_point(target_center): continue
		
		# Use the built-in pointer_line as the first one, spawn others
		var line: Line2D
		if i == 0:
			line = pointer_line
		else:
			line = pointer_line.duplicate()
			add_child(line)
			_extra_lines.append(line)
			
		_draw_line_to_target(line, popup_rect, popup_center, target_center)
		line.show()

func _draw_line_to_target(line: Line2D, popup_rect: Rect2, popup_center: Vector2, target_center: Vector2) -> void:
	var start_point: Vector2
	
	# Basic edge-snapping for the starting point
	if target_center.y > popup_rect.end.y:
		start_point = Vector2(popup_center.x, popup_rect.end.y)
	elif target_center.y < popup_rect.position.y:
		start_point = Vector2(popup_center.x, popup_rect.position.y)
	elif target_center.x > popup_rect.end.x:
		start_point = Vector2(popup_rect.end.x, popup_center.y)
	else:
		start_point = Vector2(popup_rect.position.x, popup_center.y)
	
	line.clear_points()
	line.add_point(start_point)
	line.add_point(target_center)


func _on_next_pressed() -> void:
	Audio.play_sfx("ui_button_click")
	_current_page += 1
	_update_page_display()
	_update_pointer()


func _on_got_it_pressed() -> void:
	if modulate.a < 1.0: return # Prevent early clicks during animation
	Audio.play_sfx("ui_button_click")
	TutorialManager.mark_completed(_tutorial_id)
	SignalBus.emit_signal("tutorial_dismissed", _tutorial_id)
	_close_popup()


func _close_popup() -> void:
	queue_free()


func _exit_tree() -> void:
	# Ensure game unpauses when popup is removed (closed or scene change)
	if get_tree():
		get_tree().paused = false


func get_window_to_animate() -> Control:
	return popup_panel
