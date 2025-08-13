# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var tier_label: Label = %TierLabel
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel

var _location: LocationIdentifier
var _instance_uuid: String
var _is_selected: bool = false
var _is_inspectable: bool = true
var _is_interactive: bool = true
var _single_click_inspect: bool = false

# Local input state to disambiguate click vs drag
var _pressed_pending_click: bool = false
var _drag_initiated_for_click: bool = false

# InteractionContext properties
var _interaction_mode: StringName = &"FULLY_INTERACTIVE"
var _entity_type: StringName = &"UNIT"
var _window_group_id: int = 0

func _ready() -> void:
	var bus = get_node("/root/SignalBus")
	if is_instance_valid(bus):
		bus.connect("view_selected", _on_view_selected)
		bus.connect("view_deselected", _on_view_deselected)
		bus.unit_stats_changed.connect(_on_unit_stats_changed)

func _exit_tree() -> void:
	# Proactively disconnect signals and end any active drag to prevent leaks
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		if bus.is_connected("view_selected", _on_view_selected):
			bus.disconnect("view_selected", _on_view_selected)
		if bus.is_connected("view_deselected", _on_view_deselected):
			bus.disconnect("view_deselected", _on_view_deselected)
		if bus.unit_stats_changed.is_connected(_on_unit_stats_changed):
			bus.unit_stats_changed.disconnect(_on_unit_stats_changed)

	# If this view is being freed during a drag, centrally end the drag and visuals
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

func populate(loc: LocationIdentifier, instance: GachaBallInstance, is_inspectable: bool = true, single_click_inspect: bool = false) -> void:
	self._location = loc
	self._instance_uuid = instance.ball_uuid
	self._is_inspectable = is_inspectable
	self._single_click_inspect = single_click_inspect
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

	var definition = instance.get_definition()
	if not is_instance_valid(definition):
		visible = false
		return
	
	# Set entity type based on definition category
	_entity_type = definition.category
	
	visible = true
	icon_rect.texture = definition.icon
	tier_label.text = "T%d" % definition.tier
	tooltip_text = tr(definition.display_name_key)
	
	_update_stats()
	_update_item_slots()
	_apply_selection_feedback()

func set_is_enemy(is_enemy: bool) -> void:
	if is_instance_valid(icon_rect):
		icon_rect.flip_h = is_enemy

func set_is_interactive(is_interactive: bool) -> void:
	self._is_interactive = is_interactive

## Configure the interaction context for this view
func set_interaction_context(interaction_mode: StringName, entity_type: StringName, window_group_id: int = 0) -> void:
	_interaction_mode = interaction_mode
	_entity_type = entity_type
	_window_group_id = window_group_id

## Create and emit InteractionContext for this view
func _create_interaction_context(event_type: StringName) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = _instance_uuid
	context.entity_type = _entity_type
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	return context

func _update_stats() -> void:
	var instance = GameManager.get_instance_by_uuid(_instance_uuid)
	if not is_instance_valid(instance): 
		return
	var definition = instance.get_definition()
	if not definition or definition.category != &"UNIT":
		hp_label.visible = false
		pwr_label.visible = false
		return
	
	hp_label.visible = true
	pwr_label.visible = true
	var new_hp_text = "HP: %d" % instance.current_hp
	var new_pwr_text = "PWR: %d" % instance.current_pwr
	hp_label.text = new_hp_text
	pwr_label.text = new_pwr_text

func _update_item_slots() -> void:
	var instance = GameManager.get_instance_by_uuid(_instance_uuid)
	if not is_instance_valid(instance):
		return
		
	for child in item_grid.get_children():
		child.queue_free()
	
	var definition = instance.get_definition()
	if not is_instance_valid(definition) or definition.item_slot_count == 0:
		return

	for i in range(definition.item_slot_count):
		var slot_panel = Panel.new()
		slot_panel.custom_minimum_size = Vector2(12, 12)
		
		var item_uuid = instance.get_equipped_item_uuid(i)

		if not item_uuid.is_empty():
			var item_instance = GameManager.get_instance_by_uuid(item_uuid)
			if is_instance_valid(item_instance):
				var item_def = item_instance.get_definition()
				if is_instance_valid(item_def):
					var icon = TextureRect.new()
					icon.texture = item_def.icon
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					slot_panel.add_child(icon)
					icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_grid.add_child(slot_panel)

func _find_slot_anchor() -> Control:
	# First, try to find a SlotView parent (the most stable anchor)
	var node: Node = self.get_parent()
	while node and node != get_tree().root:
		if "SlotView" in node.get_class():
			return node as Control
		node = node.get_parent()
	
	# If we can't find a SlotView parent, this might be a GachaBallView in an inspection window
	# or some other context. In that case, we should find a stable container.
	# Look for the immediate parent container that holds this view.
	var parent = self.get_parent()
	if is_instance_valid(parent):
		# If the parent is a container type, use it as the anchor
		if parent.get_class() in ["HBoxContainer", "GridContainer", "VBoxContainer", "PanelContainer"]:
			return parent as Control
	
	# Last resort: use the modal layer to prevent crashes
	var modal_layer = get_tree().get_first_node_in_group("modal_layer")
	if is_instance_valid(modal_layer):
		return modal_layer
	
	# If all else fails, return self as Control (this should never happen in normal operation)
	return self

func _on_unit_stats_changed(unit_uuid: String) -> void:
	if _instance_uuid == unit_uuid:
		var instance = GameManager.get_instance_by_uuid(unit_uuid)
		if is_instance_valid(instance):
			_update_stats()

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_location): return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Handle double-click immediately on press for fast inspection
		if event.is_pressed() and event.double_click:
			get_viewport().set_input_as_handled()
			var dc_ctx = _create_interaction_context(&"DOUBLE_CLICK")
			SignalBus.emit_signal("interaction_context_received", dc_ctx)
			_pressed_pending_click = false
			return

		if event.is_pressed():
			# Defer single-click to release; may become a drag
			get_viewport().set_input_as_handled()
			_pressed_pending_click = true
		else:
			# On release: only emit SINGLE_CLICK if no drag was initiated
			if _pressed_pending_click and not _drag_initiated_for_click:
				var sc_ctx = _create_interaction_context(&"SINGLE_CLICK")
				SignalBus.emit_signal("interaction_context_received", sc_ctx)
			# Reset flags regardless
			_pressed_pending_click = false
			_drag_initiated_for_click = false

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Use the new flag to control drag-and-drop.
	if not _is_interactive: return null
	# Full input lock during COMBAT: do not start engine drag or create previews
	if GlobalInteractionRouter and GlobalInteractionRouter.is_combat_locked():
		return null
		
	# TDD 4.3.III.5: Prevent dragging in Inspection-Only contexts
	var context_group = GlobalInteractionRouter.get_context_group(_location.container)
	if context_group == &"InspectionOnly":
		return null

	_drag_initiated_for_click = true
	_pressed_pending_click = false
	# Do NOT close windows on drag start. Closing ancestor windows can free the
	# source view or the engine-managed drag preview and cause errors.
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)

	var placeholder = Control.new()
	placeholder.custom_minimum_size = self.size
	get_parent().add_child(placeholder)
	get_parent().move_child(placeholder, get_index())

	# Delegate drag visuals to GIR helper (replaces InteractionManager)
	GlobalInteractionRouter.start_drag_visuals(self, placeholder)

	# Notify GIR of drag origin so it can interpret the eventual drop
	var origin_ctx = _create_interaction_context(&"DRAG_ORIGIN")
	GlobalInteractionRouter.start_drag(origin_ctx)

	return { "source_loc": _location }

func _can_drop_data(_at_position, data) -> bool:
	# TDD 4.3.III.5: Prevent dropping in Inspection-Only contexts
	var context_group = GlobalInteractionRouter.get_context_group(_location.container)
	if context_group == &"InspectionOnly":
		return false
		
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, data) -> void:
	# For drag and drop, we need to handle this as a direct action
	# since the source location comes from the drag data, not the current view
	# Create a target interaction context and route via GIR
	var target_ctx = _create_interaction_context(&"DROP")
	SignalBus.emit_signal("interaction_context_received", target_ctx)

	# Do not end drag visuals here. The InventoryManager will decide whether the
	# action was handled and call GlobalInteractionRouter.end_drag(true/false)
	# accordingly. This prevents the source from remaining hidden after invalid actions.

func _on_view_selected(view: Control, _loc: LocationIdentifier) -> void:
	if view == self:
		_is_selected = true
		_apply_selection_feedback()

func _on_view_deselected(view: Control) -> void:
	if view == self:
		_is_selected = false
		_apply_selection_feedback()


func _apply_selection_feedback() -> void:
	if not is_inside_tree(): return
	var stylebox: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	if _is_selected:
		stylebox.border_color = Color.GOLD
		stylebox.border_width_left = 3
		stylebox.border_width_top = 3
		stylebox.border_width_right = 3
		stylebox.border_width_bottom = 3
	else:
		stylebox.border_width_left = 0
		stylebox.border_width_top = 0
		stylebox.border_width_right = 0
		stylebox.border_width_bottom = 0
	add_theme_stylebox_override("panel", stylebox)

func _notification(what: int) -> void:
	# Fallback: if a drag ends without any drop target handling it, restore visuals
	if what == NOTIFICATION_DRAG_END:
		# Reset local drag flag
		_drag_initiated_for_click = false
		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(false)
			GlobalInteractionRouter.end_drag_visuals(false)
