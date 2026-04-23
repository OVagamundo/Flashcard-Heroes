class_name TraitInspectionWindow
extends "res://scripts/InspectionWindow.gd"

const _InputUtils = preload("res://scripts/InputUtils.gd")

# TDD Section 11.2: TraitInspectionWindow.gd
# This window displays detailed information about a trait and its active levels.
# It behaves as a standard inspection window (contextual, auto-closing).

@onready var title_label: Label = %TitleLabel
@onready var icon_rect: TextureRect = %Icon
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var internal_background: ColorRect = $InternalBackground

const C = preload("res://scripts/Constants.gd")

var _source_view: Control
var _trait_id: String
var _stable_anchor: Control

func _ready() -> void:
	# Ensure the window root receives clicks for local pruning (Rule W3)
	mouse_filter = MOUSE_FILTER_STOP
	# Allow rich text interactions
	description_label.mouse_filter = MOUSE_FILTER_PASS
	
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
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_trait_id = context.get("trait_id", "")
	var current_count = context.get("count", 0)

	if _trait_id.is_empty() or not C.TRAIT_DEFINITIONS.has(_trait_id):
		WindowManager.request_close_inspection_window(self, &"INVALID_TRAIT")
		return

	var def = C.TRAIT_DEFINITIONS[_trait_id]
	title_label.text = tr(def.display_name_key)
	
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
		
		text += "%s%s%d: %s%s\n" % [color_tag, prefix, min_req, desc_text, end_tag]
	
	var final_text = text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	description_label.text = final_text
	
	_reset_window_size()
	
	_setup_stable_anchor()

func _reset_window_size() -> void:
	# Defer for TWO frames to ensure Godot's layout engine has settled all queue_free and fit_content operations
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO

## Set up stable anchor pattern for robust positioning (copied from ItemInspectionWindow)
func _setup_stable_anchor() -> void:
	if is_instance_valid(_source_view):
		_stable_anchor = _source_view
		if is_instance_valid(_stable_anchor):
			_stable_anchor.item_rect_changed.connect(_on_anchor_moved)
			_stable_anchor.tree_exited.connect(_on_anchor_freed)

func _on_anchor_moved() -> void:
	# TraitTracker is likely moving due to screen resize or HUD logic
	# We rely on WindowManager or manual updates.
	# But WindowManager tracks "tracked windows".
	# If we are using child window logic, WindowManager handles it?
	# WindowManager's _track_inspection_anchor is ONLY for root windows that have an anchor view.
	# TraitWindow IS a root window (no parent window).
	# So WindowManager WILL track it if we pass anchor_view in _open_contextual_window.
	pass

func _on_anchor_freed() -> void:
	WindowManager.request_close_inspection_window(self, &"ANCHOR_FREED")
