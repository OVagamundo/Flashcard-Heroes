# res://scripts/UnitLabelOverlay.gd
class_name UnitLabelOverlay
extends Control

## Decoupled label overlay system for unit stats
## Renders stat labels (HP, PWR, status effects) independently from unit layout
## Labels anchor to unit positions but don't affect unit sizing

# Larger, bolder fonts per user request
const STAT_FONT_SIZE := 32
const STATUS_FONT_SIZE := 28
const OUTLINE_SIZE := 6

# Icon sizes
const STAT_ICON_SIZE := Vector2(48, 48)
const STATUS_ICON_SIZE := Vector2(40, 40)

# Label positioning offsets (relative to unit center)
const TOP_LABEL_OFFSET := Vector2(0, -40) # HP/PWR above unit
const BOTTOM_LABEL_OFFSET := Vector2(0, 40) # Status effects below unit

# Z-index below animated units (which use z=100)
const OVERLAY_Z_INDEX := 50

# Tracked units: uuid -> { view: GachaBallView, top_container: HBoxContainer, bottom_container: HBoxContainer, labels: Dictionary }
var _tracked_units: Dictionary = {}

# Font for labels - use the same pixel font as the game
var _stat_font: Font = preload("res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf")

# Icon textures
var _hp_icon: Texture2D = preload("res://assets/ui/textures/icon_heart_pixel.png")
var _pwr_icon: Texture2D = preload("res://assets/ui/textures/icon_fist_pixel.png")
var _burn_icon: Texture2D = preload("res://assets/ui/textures/icon_burn_pixel.png")
var _armor_icon: Texture2D = preload("res://assets/ui/textures/icon_armor_pixel.png")

func _ready() -> void:
	z_index = OVERLAY_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to group so GachaBallView can detect battle context
	add_to_group("unit_label_overlay")
	
	# Full rect anchoring
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Connect to label overlay signals
	SignalBus.unit_view_registered.connect(_on_unit_view_registered)
	SignalBus.unit_view_unregistered.connect(_on_unit_view_unregistered)
	SignalBus.unit_label_update.connect(_on_unit_label_update)
	# Also listen to unit_stat_changed for real-time updates
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)

func _exit_tree() -> void:
	if SignalBus.unit_view_registered.is_connected(_on_unit_view_registered):
		SignalBus.unit_view_registered.disconnect(_on_unit_view_registered)
	if SignalBus.unit_view_unregistered.is_connected(_on_unit_view_unregistered):
		SignalBus.unit_view_unregistered.disconnect(_on_unit_view_unregistered)
	if SignalBus.unit_label_update.is_connected(_on_unit_label_update):
		SignalBus.unit_label_update.disconnect(_on_unit_label_update)
	if SignalBus.unit_stat_changed.is_connected(_on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(_on_unit_stat_changed)

func _process(_delta: float) -> void:
	# Update label positions to track unit views
	for uuid in _tracked_units:
		_update_label_positions(uuid)


## Register a unit view for label tracking
func _on_unit_view_registered(uuid: String, view: GachaBallView) -> void:
	if _tracked_units.has(uuid):
		# Already tracked - update view reference and refresh label values
		_tracked_units[uuid].view = view
		# Update label values from new view's visual state
		_on_unit_label_update(uuid, &"hp", view._visual_hp)
		_on_unit_label_update(uuid, &"pwr", view._visual_pwr)
		_on_unit_label_update(uuid, &"burn_stacks", view._visual_burn_stacks)
		_on_unit_label_update(uuid, &"armor_stacks", view._visual_armor_stacks)
		return
	
	# Create label containers for this unit
	var data := {
		"view": view,
		"entity_type": view._entity_type,
		"top_container": _create_label_container(),
		"bottom_container": _create_label_container(),
		"labels": {}
	}
	
	# Add containers to overlay
	add_child(data.top_container)
	add_child(data.bottom_container)
	
	# Create HP and PWR stat displays (top position) - only for units
	if view._entity_type == &"UNIT":
		data.labels["hp"] = _create_stat_display(_hp_icon, view._visual_hp, Color.WHITE)
		data.labels["pwr"] = _create_stat_display(_pwr_icon, view._visual_pwr, Color.WHITE)
		data.top_container.add_child(data.labels["hp"])
		data.top_container.add_child(data.labels["pwr"])
		
		# Create status effect displays (bottom position) if they have stacks
		if view._visual_burn_stacks > 0:
			data.labels["burn_stacks"] = _create_status_display(_burn_icon, view._visual_burn_stacks, Color(1.0, 0.5, 0.0))
			data.bottom_container.add_child(data.labels["burn_stacks"])
		if view._visual_armor_stacks > 0:
			data.labels["armor_stacks"] = _create_status_display(_armor_icon, view._visual_armor_stacks, Color(0.6, 0.6, 0.7))
			data.bottom_container.add_child(data.labels["armor_stacks"])
	
	_tracked_units[uuid] = data
	
	# Initial position update
	_update_label_positions(uuid)


## Unregister a unit view from label tracking
## Only nullifies the view reference - labels are preserved for re-registration
## Labels are only destroyed via clear_all() or remove_unit_labels()
func _on_unit_view_unregistered(uuid: String) -> void:
	if not _tracked_units.has(uuid):
		return
	
	# Just nullify the view reference - preserve labels for re-registration
	# This handles the case where views are destroyed and recreated on redraw
	_tracked_units[uuid].view = null


## Remove unit labels completely (call when unit dies or leaves battle)
func remove_unit_labels(uuid: String) -> void:
	if not _tracked_units.has(uuid):
		return
	
	var data = _tracked_units[uuid]
	
	# Remove containers and their children
	if is_instance_valid(data.top_container):
		data.top_container.queue_free()
	if is_instance_valid(data.bottom_container):
		data.bottom_container.queue_free()
	
	_tracked_units.erase(uuid)


## Update a single label value
func _on_unit_label_update(uuid: String, stat_name: StringName, value: int) -> void:
	if not _tracked_units.has(uuid):
		return
	
	var data = _tracked_units[uuid]
	var stat_key = String(stat_name)
	
	# Handle HP and PWR
	if stat_name in [&"hp", &"pwr"]:
		if data.labels.has(stat_key):
			var display = data.labels[stat_key]
			if is_instance_valid(display):
				var label = display.get_node_or_null("Label")
				if is_instance_valid(label):
					label.text = str(max(0, value))
		return
	
	# Handle status effects (burn_stacks, armor_stacks)
	if stat_name in [&"burn_stacks", &"armor_stacks"]:
		if not data.labels.has(stat_key):
			# Create new status display if needed
			var icon = _burn_icon if stat_name == &"burn_stacks" else _armor_icon
			var color = Color(1.0, 0.5, 0.0) if stat_name == &"burn_stacks" else Color(0.6, 0.6, 0.7)
			var new_display = _create_status_display(icon, value, color)
			data.labels[stat_key] = new_display
			data.bottom_container.add_child(new_display)
		
		# Update value
		var display = data.labels.get(stat_key)
		if is_instance_valid(display):
			var label = display.get_node_or_null("Label")
			if is_instance_valid(label):
				label.text = str(value)
			display.visible = value > 0


## Handle stat changes from the main stat system
func _on_unit_stat_changed(unit_uuid: String, stat_name: StringName, _old_value: int, new_value: int) -> void:
	_on_unit_label_update(unit_uuid, stat_name, new_value)


## Update label positions to match unit view positions
func _update_label_positions(uuid: String) -> void:
	if not _tracked_units.has(uuid):
		return
	
	var data = _tracked_units[uuid]
	var view: GachaBallView = data.view
	
	if not is_instance_valid(view) or not view.is_inside_tree():
		return
	
	# Get unit center position in overlay coordinate space
	var unit_global_center = view.global_position + view.size / 2.0
	var local_center = unit_global_center - global_position
	
	# Position top labels (HP/PWR) above unit
	var top_container: Control = data.top_container
	if is_instance_valid(top_container):
		var top_pos = local_center + TOP_LABEL_OFFSET - Vector2(top_container.size.x / 2.0, top_container.size.y)
		top_container.position = top_pos
	
	# Position bottom labels (status effects) below unit
	var bottom_container: Control = data.bottom_container
	if is_instance_valid(bottom_container):
		var bottom_offset = Vector2(0, view.size.y / 2.0 + BOTTOM_LABEL_OFFSET.y)
		bottom_container.position = local_center + bottom_offset - bottom_container.size / 2.0


## Create a horizontal container for labels
func _create_label_container() -> HBoxContainer:
	var container = HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)
	return container


## Create a stat display with icon and label (HP/PWR)
func _create_stat_display(icon_texture: Texture2D, initial_value: int, color: Color) -> Control:
	# Container for icon + label
	var container = TextureRect.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = STAT_ICON_SIZE
	container.texture = icon_texture
	container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Label centered on icon
	var label = Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(max(0, initial_value))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Larger, bolder styling
	label.add_theme_font_override("font", _stat_font)
	label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	
	container.add_child(label)
	return container


## Create a status effect display with icon and label (burn, armor)
func _create_status_display(icon_texture: Texture2D, initial_value: int, color: Color) -> Control:
	# Container for icon + label
	var container = TextureRect.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.custom_minimum_size = STATUS_ICON_SIZE
	container.texture = icon_texture
	container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.visible = initial_value > 0
	
	# Label centered on icon
	var label = Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(initial_value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Styling
	label.add_theme_font_override("font", _stat_font)
	label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	
	container.add_child(label)
	return container


## Clear all tracked units (called when battle ends)
func clear_all() -> void:
	for uuid in _tracked_units.keys():
		_on_unit_view_unregistered(uuid)
	_tracked_units.clear()
