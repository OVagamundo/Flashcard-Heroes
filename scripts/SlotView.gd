class_name SlotView
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")

var _location: LocationIdentifier

# InteractionContext properties
var _interaction_mode: StringName = &"FULLY_INTERACTIVE"
var _window_group_id: int = 0

# Size scale for gachaball views (2.0 for battle, 1.0 for windows)
var _size_scale: float = 2.0 # Default to battle scale

# Indicator overlay for valid drop targets
var _indicator: TextureRect = null
var _indicator_tween: Tween = null
const INDICATOR_TEXTURE = preload("res://assets/ui/textures/Indicator.png")
# Base slot size at 1x scale
const BASE_SLOT_SIZE: int = 96

# Slot background stylebox
var _background_style: StyleBoxTexture

## Set size scale for gachaball views in this slot
## NOTE: This only sets internal scale for GachaBallView. Caller is responsible for slot size.
func set_size_scale(size_scale: float) -> void:
	_size_scale = size_scale

func _ready() -> void:
	# Configure the slot background using properties to render the texture
	_background_style = StyleBoxTexture.new()
	_background_style.texture = load("res://assets/ui/textures/slot.png")
	# Default neutral tint
	_background_style.modulate_color = Color(0.5, 0.5, 0.5, 0.6)
	add_theme_stylebox_override("panel", _background_style)
	
	# Connect to granular stat change signal for targeted updates
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	
	# Connect to slot indicator signals
	SignalBus.show_slot_indicators.connect(_on_show_slot_indicators)
	SignalBus.hide_slot_indicators.connect(_on_hide_slot_indicators)
	
	# Create indicator overlay (initially hidden)
	_create_indicator()

## Set custom color for this slot based on container type
func set_slot_color(container_name: StringName) -> void:
	if not is_instance_valid(_background_style):
		return
	
	# Determine if this is a battle slot
	var is_battle_slot = (container_name == &"PlayerLineup" or container_name == &"EnemyLineup" or container_name == &"PlayerBench" or container_name == &"EnemyBench" or container_name == &"EnemyTrinkets" or container_name == &"PlayerTrinkets")
	
	if is_battle_slot:
		_background_style.texture = load("res://assets/ui/textures/slotBattle.png")
		# Expand the top margin instead so the base stays at the bottom to touch the unit's feet
		# Shift the slot up by 15px via a negative bottom margin, compensating at the top to preserve ratio
		_background_style.expand_margin_top = (40.0 * _size_scale) + 15.0
		_background_style.expand_margin_bottom = -15.0
	else:
		_background_style.texture = load("res://assets/ui/textures/slot.png")
		_background_style.expand_margin_bottom = 0.0
		
	# Tint the slot background texture based on container type
	match container_name:
		&"PlayerLineup":
			_background_style.modulate_color = Color(0.3, 0.5, 0.8, 0.8)
		&"PlayerBench":
			_background_style.modulate_color = Color(0.3, 0.7, 0.3, 0.8)
		&"EnemyLineup":
			_background_style.modulate_color = Color(0.8, 0.3, 0.3, 0.8)
		_:
			_background_style.modulate_color = Color(0.5, 0.5, 0.5, 0.6)

func _exit_tree() -> void:
	if SignalBus.unit_stat_changed.is_connected(_on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(_on_unit_stat_changed)
	if SignalBus.show_slot_indicators.is_connected(_on_show_slot_indicators):
		SignalBus.show_slot_indicators.disconnect(_on_show_slot_indicators)
	if SignalBus.hide_slot_indicators.is_connected(_on_hide_slot_indicators):
		SignalBus.hide_slot_indicators.disconnect(_on_hide_slot_indicators)

	# If a drag is active while this slot is being freed, end it ONLY if we are the source.
	# This prevents closing windows (which frees their slots) from killing unrelated drags.
	if GlobalInteractionRouter.is_drag_active():
		var context = GlobalInteractionRouter.get_drag_origin_context()
		if context and context.source_view_instance_id:
			# Check if the drag source is one of our children
			for child in get_children():
				if child.get_instance_id() == context.source_view_instance_id:
					GlobalInteractionRouter.end_drag(false)
					GlobalInteractionRouter.end_drag_visuals(false)
					break
	
	# Stop any running indicator tween
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()

func _notification(_what) -> void:
	pass

# --- Indicator Overlay Methods ---

## Create the indicator overlay (called in _ready)
func _create_indicator() -> void:
	_indicator = TextureRect.new()
	_indicator.texture = INDICATOR_TEXTURE
	_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.visible = false
	_indicator.z_index = 10 # Ensure it's on top
	
	# Set anchors to fill parent
	_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	_indicator.set_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(_indicator)

## Show indicator if this slot is in the valid locations list
func _on_show_slot_indicators(locations: Array) -> void:
	if not is_instance_valid(_location) or not is_instance_valid(_indicator):
		return
	
	# Check if this slot's location is in the valid targets
	var should_show = false
	for loc in locations:
		if loc is LocationIdentifier:
			if loc.container == _location.container and loc.index == _location.index:
				should_show = true
				break
	
	if should_show:
		_show_indicator()
	else:
		_hide_indicator()

## Hide indicator
func _on_hide_slot_indicators() -> void:
	_hide_indicator()

## Show the indicator with pulse animation
func _show_indicator() -> void:
	if not is_instance_valid(_indicator):
		return
	
	_indicator.visible = true
	_indicator.modulate.a = 0.8
	_indicator.pivot_offset = _indicator.size / 2.0
	
	# Start pulse animation
	_start_pulse_animation()

## Hide the indicator and stop animation
func _hide_indicator() -> void:
	if not is_instance_valid(_indicator):
		return
	
	_indicator.visible = false
	
	# Stop pulse animation
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
		_indicator_tween = null

## Pulse animation - scale oscillates between 0.9 and 1.1
func _start_pulse_animation() -> void:
	if is_instance_valid(_indicator_tween):
		_indicator_tween.kill()
	
	_indicator.scale = Vector2.ONE
	
	_indicator_tween = create_tween()
	_indicator_tween.set_loops()
	_indicator_tween.tween_property(_indicator, "scale", Vector2(1.08, 1.08), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_indicator_tween.tween_property(_indicator, "scale", Vector2(0.95, 0.95), 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func populate(loc: LocationIdentifier) -> void:
	self._location = loc
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

## Set the content of this slot using VisualData
func set_content(visual_data: Dictionary, is_inspectable: bool = true, single_click_inspect: bool = false, is_enemy: bool = false) -> void:
	# Clear existing content (preserve indicator and background)
	# Clear existing content (preserve indicator)
	for child in get_children():
		if child == _indicator:
			continue
		child.queue_free()
	
	if visual_data.is_empty():
		return
	
	
	var gacha_ball_view_scene = load("res://scenes/GachaBallView.tscn")
	
	if not is_instance_valid(gacha_ball_view_scene):
		push_error("[SlotView] GachaBallViewScene failed to load!")
		return
		
	var view = gacha_ball_view_scene.instantiate()
	
	if not is_instance_valid(view):
		push_error("[SlotView] Failed to instantiate GachaBallView!")
		return
	
	# Set size scale before adding to tree (so populate uses correct scale)
	if view.has_method("set_size_scale"):
		view.set_size_scale(_size_scale)
	
	add_child(view)
	
	# Populate the view with visual data
	view.populate(_location, visual_data, is_inspectable, single_click_inspect)
	var def_id: StringName = visual_data.get("definition_id", &"")
	view.set_is_enemy(is_enemy, def_id)
	
	# Propagate interaction context from SlotView to child GachaBallView
	# Entity type is derived from the visual data category
	var category: StringName = visual_data.get("category", &"UNIT")
	var entity_type: StringName = category # UNIT, ITEM, or TRINKET
	var effective_mode = _interaction_mode
	
	# Force inspection only for enemies unless in specific contexts (handled by slot mode usually)
	# But trusting _interaction_mode from the slot is the correct architectural approach.
	view.set_interaction_context(effective_mode, entity_type, _window_group_id)
	
	# If inspection only, disable dragging functionality (interactive flag controls drag in GachaBallView)
	if effective_mode == &"INSPECTION_ONLY":
		view.set_is_interactive(false)
	else:
		view.set_is_interactive(true)
	
	view.set_meta("location_identifier", _location)
	
	# If this slot has no location (e.g. Rest Site visual balls), 
	# it shouldn't consume clicks at all. Pass them to the parent.
	if not is_instance_valid(_location):
		_recursively_set_mouse_filter_ignore(view)

## Helper to recursively set mouse filter to ignore
func _recursively_set_mouse_filter_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_recursively_set_mouse_filter_ignore(child)


## Granular stat change handler - updates only the specific stat that changed
func _on_unit_stat_changed(unit_uuid: String, stat_name: StringName, old_value: int, new_value: int) -> void:
	# Check if we have a child view that matches this UUID
	if get_child_count() > 0:
		var view = get_child(0)
		if view is GachaBallView and view.get_instance_uuid() == unit_uuid:
			# Delegate to view's granular handler
			if is_instance_valid(view) and view.has_method("_on_unit_stat_changed"):
				view._on_unit_stat_changed(unit_uuid, stat_name, old_value, new_value)


## Configure the interaction context for this slot
func set_interaction_context(interaction_mode: StringName, window_group_id: int = 0) -> void:
	_interaction_mode = interaction_mode
	_window_group_id = window_group_id

## Create and emit InteractionContext for this slot
func _create_interaction_context(event_type: StringName) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = "" # Empty slots have no entity
	context.entity_type = &"EMPTY_SLOT"
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	return context

func _has_point(point: Vector2) -> bool:
	var radius = size.x / 2.0
	var center = Vector2(radius, size.y / 2.0)
	return point.distance_to(center) <= radius

func _gui_input(event: InputEvent) -> void:
	# Ignore input entirely if we don't have a location (e.g. visual-only slots in RestSite)
	if not is_instance_valid(_location):
		return

	if InputUtils.is_primary_pointer_press(event):
		# Do NOT consume the event here; allow child views to initiate drag
		# Check for actual content (GachaBallView), ignoring the indicator
		var has_content = false
		for child in get_children():
			if child is GachaBallView:
				has_content = true
				break
		
		# If this is an empty slot (no content), handle the click as EMPTY_SLOT interaction
		if not has_content:
			print("DEBUG_INPUT: SlotView Pressed (Empty).")
			var context = _create_interaction_context(&"SINGLE_CLICK")
			SignalBus.emit_signal("interaction_context_received", context)
			get_viewport().set_input_as_handled() # Stop propagation to Main/Battle
			accept_event() # Explicitly stop control bubbling
		else:
			print("DEBUG_INPUT: SlotView Bubbled (Has Content). Ignoring.")
		
		# If we have a child (Unit), we do NOTHING. 
		# The child (GachaBallView) will handle the input itself (emit UNIT context).
		# We must ensure GachaBallView consumes the event (BLOCK/STOP) so it doesn't bubble here.

func _can_drop_data(_at_position, data) -> bool:
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return false
		
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, _data) -> void:
	# Check if this is an inspection-only context
	if _interaction_mode == &"INSPECTION_ONLY":
		return

	# Create a target interaction context and route via GIR
	var target_ctx = _create_interaction_context(&"DROP")
	
	# IMMEDIATE VISUAL FEEDBACK: Hide indicator now.
	_hide_indicator()
	
	SignalBus.emit_signal("interaction_context_received", target_ctx)
	
	# Do not end drag here; InventoryManager will decide handled/unhandled and
	# call GlobalInteractionRouter.end_drag(true/false) centrally.
