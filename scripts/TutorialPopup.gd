# res://scripts/TutorialPopup.gd
extends Control
class_name TutorialPopup

## Modal tutorial popup with multi-page support and pointer arrows
## Supports dynamic positioning relative to anchors (e.g. "display above")
## Automatically handles platform-specific text (.mouse vs .touch suffixes)

const BUTTON_FONT = preload("res://assets/fonts/static/NotoSansJP-Bold.ttf")
const WINDOW_MARGIN: float = 30.0 # Distance from screen edges or anchor
const ORDER_MARKER_SIZE: float = 38.0

@onready var background_blocker: Control = $BackgroundBlocker
@onready var popup_panel: PanelContainer = %PopupPanel
@onready var title_label: Label = %TitleLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var page_indicator: HBoxContainer = %PageIndicator
@onready var button_container: HBoxContainer = $PopupPanel/VBoxContainer/ContentMargin/VBoxContainer/ButtonContainer
@onready var next_button: Button = %NextButton
@onready var got_it_button: Button = %GotItButton
@onready var pointer_line: Line2D = $PointerLine

var _tutorial_id: StringName = &""
var _pages: Array = []
var _current_page: int = 0
var _anchor: Control = null
var _extra_lines: Array[Line2D] = []
var _numbered_anchor_markers: Array[Label] = []
var _interaction_enabled: bool = false
var _pause_tree_while_open: bool = false
var _tree_was_paused: bool = false
var _run_timer_was_running: bool = false
var _default_panel_minimum_size: Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_panel_minimum_size = popup_panel.custom_minimum_size
	next_button.pressed.connect(_on_next_pressed)
	got_it_button.pressed.connect(_on_got_it_pressed)
	next_button.disabled = true
	got_it_button.disabled = true
	
	# Initial hide of pointer line
	pointer_line.hide()


func populate(context: Dictionary) -> void:
	_tutorial_id = context.get("tutorial_id", &"")
	_pages = context.get("pages", [])
	_anchor = context.get("anchor", null)
	_current_page = 0
	for page_value in _pages:
		var page: Dictionary = page_value
		if bool(page.get("pause_game", false)):
			_pause_tree_while_open = true
			break
	if _pause_tree_while_open:
		_tree_was_paused = get_tree().paused
		_run_timer_was_running = ActionQueue.is_timer_running()
		if _run_timer_was_running:
			ActionQueue.pause_timer()
		get_tree().paused = true
		SignalBus.emit_signal("tutorial_pause_changed", _tutorial_id, true)
	
	if _pages.is_empty():
		_close_popup()
		return
	
	_update_page_display()
	
	# Wait for layout to settle sizes before repositioning
	await get_tree().process_frame
	if not is_inside_tree():
		return
		
	_reposition_window()
	_update_pointer()





func _reposition_window(reset_panel_size: bool = true) -> void:
	if not is_inside_tree(): return
	var page: Dictionary = {}
	if _current_page < _pages.size():
		page = _pages[_current_page]
	if reset_panel_size:
		popup_panel.custom_minimum_size = _default_panel_minimum_size
		popup_panel.custom_minimum_size.x = float(page.get("panel_width", _default_panel_minimum_size.x))
		popup_panel.reset_size()

	var viewport_size := get_viewport_rect().size
	var panel_size := popup_panel.size
	
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
	if anchor_side == "BOTTOM_LEFT":
		popup_panel.global_position = Vector2(WINDOW_MARGIN, viewport_size.y - panel_size.y - WINDOW_MARGIN)
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
			"AUTO_HORIZONTAL":
				target_y = anchor_rect.get_center().y - (panel_size.y / 2.0)
				var left_x = anchor_rect.position.x - panel_size.x - WINDOW_MARGIN
				var right_x = anchor_rect.end.x + WINDOW_MARGIN
				
				# If left fits on screen, use it. Otherwise, use right.
				if left_x >= WINDOW_MARGIN:
					target_x = left_x
				else:
					target_x = right_x
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
		var platform_suffix := ".touch" if _uses_touch_tutorials() else ".mouse"
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
	
	var font = Database.get_current_locale_font()
	var text_font_size: int = int(page.get("text_font_size", 22))
	var title_font_size: int = int(page.get("title_font_size", 26))
	var button_width: float = float(page.get("button_width", 250.0))
	var button_height: float = float(page.get("button_height", 80.0))
	var button_font_size: int = int(page.get("button_font_size", 36))
	text_label.add_theme_font_override("normal_font", font)
	text_label.add_theme_font_override("bold_font", font)
	text_label.add_theme_font_size_override("normal_font_size", text_font_size)
	text_label.add_theme_font_size_override("bold_font_size", text_font_size)
	text_label.add_theme_constant_override("line_separation", 3)
	text_label.add_theme_constant_override("p_separation", 6)
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", title_font_size)
	next_button.custom_minimum_size = Vector2(button_width, button_height)
	got_it_button.custom_minimum_size = Vector2(button_width, button_height)
	next_button.add_theme_font_size_override("font_size", button_font_size)
	got_it_button.add_theme_font_size_override("font_size", button_font_size)
	
	text_label.text = collapsed_text
	
	# Handle per-page anchors if anchor_path is provided
	if page.has("anchor_path") and not page.get("anchor_path", "").is_empty():
		var new_anchor = get_node_or_null(page["anchor_path"])
		if is_instance_valid(new_anchor) and new_anchor is Control:
			_anchor = new_anchor
	
	# Update page indicator dots
	_update_page_indicator()
	
	# Show appropriate buttons
	var is_last_page := _current_page >= _pages.size() - 1
	next_button.visible = not is_last_page
	next_button.text = tr("tutorial.btn.next")
	got_it_button.visible = is_last_page
	got_it_button.text = tr("tutorial.btn.got_it")

	_reposition_window()
	_update_pointer()
	if bool(page.get("fit_to_button", false)):
		call_deferred("_fit_panel_to_button")


func _uses_touch_tutorials() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _fit_panel_to_button() -> void:
	await get_tree().process_frame
	popup_panel.reset_size()
	await get_tree().process_frame
	var panel_style: StyleBox = popup_panel.get_theme_stylebox("panel")
	assert(panel_style != null, "TutorialPopup: panel theme must provide a panel style")
	var bottom_padding: float = panel_style.get_content_margin(SIDE_BOTTOM)
	var panel_from_canvas: Transform2D = popup_panel.get_global_transform_with_canvas().affine_inverse()
	var button_bottom_local: float = (panel_from_canvas * button_container.get_global_rect().end).y
	var fitted_height: float = button_bottom_local + bottom_padding
	popup_panel.custom_minimum_size.y = fitted_height
	popup_panel.size.y = fitted_height
	_reposition_window(false)
	_update_pointer()


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
	for marker in _numbered_anchor_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_numbered_anchor_markers.clear()
	
	# Current page dictionary
	var page: Dictionary = {}
	if _current_page < _pages.size():
		page = _pages[_current_page]
		
	# Collect all anchors to point to
	var anchors_to_point: Array[Control] = []
	var numbered_targets: Array[Control] = []
	var numbered_anchor_paths: Array = page.get("numbered_anchor_paths", [])
	for path in numbered_anchor_paths:
		var numbered_target := get_node(path) as Control
		assert(is_instance_valid(numbered_target), "TutorialPopup: numbered anchor must be a Control")
		numbered_targets.append(numbered_target)
	
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
	
	if anchors_to_point.is_empty() and numbered_targets.is_empty():
		pointer_line.hide()
		return
	
	# Draw lines for all collected anchors
	pointer_line.hide() # Hide default one as we will treat it as another instance or similar
	
	# Calculate lines after layout
	await get_tree().process_frame
	if not is_instance_valid(popup_panel): return
	
	for i in range(numbered_targets.size()):
		_add_order_marker(numbered_targets[i], i + 1)
	if anchors_to_point.is_empty():
		return

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

func _add_order_marker(target: Control, order: int) -> void:
	var marker := Label.new()
	marker.text = str(order)
	marker.custom_minimum_size = Vector2(ORDER_MARKER_SIZE, ORDER_MARKER_SIZE)
	marker.size = marker.custom_minimum_size
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_override("font", BUTTON_FONT)
	marker.add_theme_font_size_override("font_size", 20)
	marker.add_theme_color_override("font_color", Color.WHITE)
	var marker_style := StyleBoxFlat.new()
	marker_style.bg_color = Color("#18232B")
	marker_style.border_color = Color.WHITE
	marker_style.set_border_width_all(2)
	marker_style.set_corner_radius_all(int(ORDER_MARKER_SIZE / 2.0))
	marker.add_theme_stylebox_override("normal", marker_style)
	marker.z_index = 101
	add_child(marker)
	marker.global_position = target.get_global_rect().get_center() - Vector2.ONE * (ORDER_MARKER_SIZE / 2.0)
	_numbered_anchor_markers.append(marker)

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


func set_page(page: int) -> void:
	_current_page = page
	_update_page_display()


func get_tutorial_id() -> StringName:
	return _tutorial_id


func is_pausing_game() -> bool:
	return _pause_tree_while_open


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	next_button.disabled = not enabled
	got_it_button.disabled = not enabled

func _advance_page() -> void:
	_current_page += 1
	_update_page_display()

func _on_next_pressed() -> void:
	if not _interaction_enabled:
		return
	Audio.play_sfx("ui_click")
	var action := AdvanceTutorialPageAction.new(_tutorial_id, _current_page + 1)
	ActionQueue.request(action)

func _on_got_it_pressed() -> void:
	if not _interaction_enabled:
		return
	Audio.play_sfx("ui_click")
	var action := DismissTutorialAction.new(_tutorial_id)
	ActionQueue.request(action)


func _close_popup() -> void:
	queue_free()


func _exit_tree() -> void:
	if _pause_tree_while_open:
		get_tree().paused = _tree_was_paused
		if _run_timer_was_running:
			ActionQueue.start_timer()
		_pause_tree_while_open = false
		SignalBus.emit_signal("tutorial_pause_changed", _tutorial_id, false)


func get_window_to_animate() -> Control:
	return popup_panel
