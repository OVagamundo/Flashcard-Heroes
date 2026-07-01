class_name EffectInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel

var _effect_definition: Variant
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
	
	description_label.gui_input.connect(_on_description_gui_input)
	# Ensure the window root receives clicks for local pruning
	mouse_filter = MOUSE_FILTER_STOP
	# Configure child controls to allow bubbling so the root can prune children on generic clicks
	_configure_mouse_filters()

## Recursively set mouse filters to PASS for child controls so clicks bubble to the root
func _configure_mouse_filters() -> void:
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				# Keep the internal background STOP to capture clicks anywhere in the window
				if child == $InternalBackground:
					(child as Control).mouse_filter = MOUSE_FILTER_STOP
				else:
					(child as Control).mouse_filter = MOUSE_FILTER_PASS
				stack.append(child)

	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [description_label, name_label]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	# Cover the entire window for background clicks inside the window area
	$InternalBackground.gui_input.connect(_on_internal_background_clicked)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants (do not close self)
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()
		accept_event()

func _on_internal_background_clicked(event: InputEvent) -> void:
	if _InputUtils.is_primary_pointer_press(event):
		_locked_meta = null
		# Prune only this window's descendants via WindowManager (preferred local pattern)
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
	var effect_definitions: Variant = context.get("effect_definition")
	# Accept either a single definition or an array of definitions
	var defs: Array = []
	if effect_definitions is Array:
		defs = effect_definitions
	elif effect_definitions != null:
		defs = [effect_definitions]

	# If no abilities, show placeholder instead of closing
	if defs.is_empty():
		name_label.text = tr("ui.effects")
		description_label.text = tr("ui.no_effects")
		return

	# Display the first effect definition; support Dictionary or Object types
	var first = defs[0]
	var name_key := ""
	var desc_key := ""
	if first is Dictionary:
		name_key = first.get("name_key", "")
		desc_key = first.get("description_key", "")
	elif first is Object:
		# Use safe field access via get() to avoid relying on typed properties
		name_key = first.get("name_key") if first.has_method("get") else (first.name_key if "name_key" in first else "")
		desc_key = first.get("description_key") if first.has_method("get") else (first.description_key if "description_key" in first else "")

	if name_key == "" and desc_key == "":
		name_label.text = tr("ui.effects")
		description_label.text = tr("ui.no_effect_details")
		return

	name_label.text = tr(name_key)
	var final_text = tr(desc_key).strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	var current_meta = ""
	if name_key.begins_with("STATUS_"):
		current_meta = "effect_" + name_key.replace("STATUS_", "").to_lower()
		
	description_label.text = DescriptionParser.parse(final_text, current_meta)
	_reset_window_size()

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
				"is_inside_unit_inspection": false, # Might be inside, but this window is the immediate parent
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

func get_location() -> LocationIdentifier:
	return null
