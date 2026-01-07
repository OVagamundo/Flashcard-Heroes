# res://scripts/TutorialPopup.gd
extends Control
class_name TutorialPopup

## Modal tutorial popup with multi-page support and pointer arrows

const BUTTON_FONT = preload("res://assets/fonts/Press_Start_2P/PressStart2P-Regular.ttf")

@onready var background_blocker: Control = $BackgroundBlocker
@onready var popup_panel: PanelContainer = $CenterContainer/PopupPanel
@onready var text_label: RichTextLabel = %TextLabel
@onready var page_indicator: HBoxContainer = %PageIndicator
@onready var next_button: Button = %NextButton
@onready var got_it_button: Button = %GotItButton
@onready var pointer_line: Line2D = $PointerLine

var _tutorial_id: StringName = &""
var _pages: Array = []
var _current_page: int = 0
var _anchor: Control = null


func _ready() -> void:
	# Ensure popup handles input while game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pause the game
	get_tree().paused = true
	
	next_button.pressed.connect(_on_next_pressed)
	got_it_button.pressed.connect(_on_got_it_pressed)
	
	# Initial hide of pointer line
	pointer_line.hide()


func populate(context: Dictionary) -> void:
	_tutorial_id = context.get("tutorial_id", &"")
	_pages = context.get("pages", [])
	_anchor = context.get("anchor", null)
	_current_page = 0
	
	if _pages.is_empty():
		_close_popup()
		return
	
	_update_page_display()
	_update_pointer()


func _update_page_display() -> void:
	if _current_page >= _pages.size():
		_close_popup()
		return
	
	var page: Dictionary = _pages[_current_page]
	var page_text: String = page.get("text", "")
	
	# Parse BBCode for rich text formatting
	text_label.text = page_text
	
	# Update page indicator dots
	_update_page_indicator()
	
	# Show appropriate buttons
	var is_last_page := _current_page >= _pages.size() - 1
	next_button.visible = not is_last_page
	got_it_button.visible = is_last_page


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
	# Check if current page has a specific anchor
	var page_anchor: Control = _anchor
	if _current_page < _pages.size():
		var page: Dictionary = _pages[_current_page]
		var anchor_path: String = page.get("anchor_path", "")
		if not anchor_path.is_empty():
			# Try to find the node by path from scene root
			var root := get_tree().current_scene
			if is_instance_valid(root):
				page_anchor = root.get_node_or_null(anchor_path)
	
	if not is_instance_valid(page_anchor):
		pointer_line.hide()
		return
	
	# Calculate line from popup edge to anchor center
	await get_tree().process_frame # Wait for layout to settle
	
	if not is_instance_valid(popup_panel) or not is_instance_valid(page_anchor):
		pointer_line.hide()
		return
	
	var popup_rect := popup_panel.get_global_rect()
	var anchor_rect := page_anchor.get_global_rect()
	var anchor_center := anchor_rect.get_center()
	
	# Determine which edge of popup is closest to anchor
	var popup_center := popup_rect.get_center()
	var start_point: Vector2
	
	if anchor_center.y > popup_rect.end.y:
		# Anchor is below popup
		start_point = Vector2(popup_center.x, popup_rect.end.y)
	elif anchor_center.y < popup_rect.position.y:
		# Anchor is above popup
		start_point = Vector2(popup_center.x, popup_rect.position.y)
	elif anchor_center.x > popup_rect.end.x:
		# Anchor is to the right
		start_point = Vector2(popup_rect.end.x, popup_center.y)
	else:
		# Anchor is to the left
		start_point = Vector2(popup_rect.position.x, popup_center.y)
	
	pointer_line.clear_points()
	pointer_line.add_point(start_point)
	pointer_line.add_point(anchor_center)
	pointer_line.show()


func _on_next_pressed() -> void:
	Audio.play_sfx("ui_button_click")
	_current_page += 1
	_update_page_display()
	_update_pointer()


func _on_got_it_pressed() -> void:
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
