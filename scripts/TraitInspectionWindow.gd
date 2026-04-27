class_name TraitInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

# TDD Section 11.2: TraitInspectionWindow.gd
# This window displays detailed information about a trait and its active levels.
# It behaves as a standard inspection window (contextual, auto-closing).

@onready var title_label: Label = %TitleLabel
const BOLD_FONT = preload("res://assets/fonts/noto_sans_black_composite.tres")
@onready var icon_rect: TextureRect = %Icon
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var internal_background: ColorRect = $InternalBackground

const C = preload("res://scripts/Constants.gd")

var _source_view: Control
var _trait_id: String
var _long_press_timer: Timer
var _last_meta_at_pointer = null
var _locked_meta = null
var _last_child_window_id: int = -1

func _ready() -> void:
	description_label.meta_clicked.connect(_on_description_meta_clicked)
	description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)
	
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = 0.32
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	
	if WindowManager.has_signal("window_closed"):
		WindowManager.window_closed.connect(_on_window_manager_window_closed)
	
	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

## Recursively set mouse filters to PASS for child controls so clicks bubble to the root
func _configure_mouse_filters() -> void:
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Keep nodes with their own logic at STOP
				if child == internal_background or child == description_label:
					(child as Control).mouse_filter = MOUSE_FILTER_STOP
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, title_label, icon_rect]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(internal_background):
		internal_background.mouse_filter = MOUSE_FILTER_STOP
		internal_background.gui_input.connect(_on_internal_background_gui_input)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants.
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func _on_internal_background_gui_input(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		_locked_meta = null
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_description_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			_long_press_timer.start()
		else:
			_long_press_timer.stop()
	pass

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_trait_id = context.get("trait_id", "")
	var current_count = context.get("count", 0)

	if _trait_id.is_empty() or not C.TRAIT_DEFINITIONS.has(_trait_id):
		WindowManager.request_close_inspection_window(self, &"INVALID_TRAIT")
		return

	var def = C.TRAIT_DEFINITIONS[_trait_id]
	title_label.text = tr(def.display_name_key)
	title_label.add_theme_font_override("font", BOLD_FONT)
	title_label.add_theme_font_size_override("font_size", 32)
	
	# Set icon (reusing internal preload logic or passing texture)
	# For simplicity, we'll try to get it from the source view if it has one, or hardcode mapping
	# ideally Constants would contain icon paths.
	if is_instance_valid(_source_view) and _source_view.get("icon_texture"):
		icon_rect.texture = _source_view.icon_texture
	else:
		match _trait_id:
			"FIRE": icon_rect.texture = preload("res://assets/sprites/trinkets/Trinket7A.png")
			"EARTH": icon_rect.texture = preload("res://assets/sprites/trinkets/Trinket6A.png")
			"WATER": icon_rect.texture = preload("res://assets/sprites/items/WaterEmblem.png")
			"AIR": icon_rect.texture = preload("res://assets/sprites/items/AirEmblem.png")
	
	# Build description text with highlighting
	var text = ""
	for level in def.levels:
		var min_req = level.min
		var is_active = current_count >= min_req
		
		# Formatting
		var color_tag = "[color=#FFFF00]" if is_active else "[color=#888888]" # Yellow if active, Grey if inactive
		var end_tag = "[/color]"
		var prefix = "★ " if is_active else "○ " # Star for active, circle for inactive
		
		var desc_text = tr(level.desc_key)
		
		text += "%s[b]%s%d[/b]: %s%s\n" % [color_tag, prefix, min_req, desc_text, end_tag]
	
	var final_text = text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	description_label.text = DescriptionParser.parse(final_text)
	
	_reset_window_size()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		# Enforce shrinking on EVERY container in the hierarchy
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(480, 0)
		size = Vector2.ZERO # Force immediate recalculation of minimum size
		reset_size()

func _on_description_meta_clicked(meta) -> void:
	if _locked_meta == meta:
		_locked_meta = null
		WindowManager.close_children_of(self )
	else:
		_locked_meta = meta
		_handle_effect_meta_interaction(meta)

func _on_description_meta_hover_started(meta) -> void:
	if _locked_meta != null:
		return
	_last_meta_at_pointer = meta
	_handle_effect_meta_interaction(meta)

func _on_description_meta_hover_ended(_meta) -> void:
	_last_meta_at_pointer = null

func _on_long_press_timeout() -> void:
	var meta = _last_meta_at_pointer
	if meta == null:
		meta = description_label.get_meta_at_point(description_label.get_local_mouse_position())
	
	if meta:
		_handle_effect_meta_interaction(meta)

func _handle_effect_meta_interaction(meta) -> void:
	if str(meta).begins_with("effect_"):
		var effect_type = str(meta).replace("effect_", "")
		var name_key = "STATUS_" + effect_type.to_upper()
		var desc_key = "STATUS_" + effect_type.to_upper() + "_DESC"
		
		# Open EffectInspection as a CHILD contextual window anchored to this window.
		var parent_win: Control = WindowManager.find_ancestor_window_for_view(self )
		var parent_id: int = parent_win.get_instance_id() if is_instance_valid(parent_win) else -1
		
		var win = WindowManager.open_child_contextual_window(
			&"EffectInspection",
			self ,
			{
				"effect_definition": {
					"name_key": name_key,
					"description_key": desc_key
				},
				"is_inside_unit_inspection": false,
				"target_parent_window_id": parent_id
			}
		)
		if win:
			_last_child_window_id = win.get_instance_id()
		get_viewport().set_input_as_handled()
		accept_event()

func _on_window_manager_window_closed(window: Control) -> void:
	if window.get_instance_id() == _last_child_window_id:
		_locked_meta = null
		_last_child_window_id = -1
