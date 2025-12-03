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

# Visual State (Puppet Mode)
var _visual_hp: int = 0
var _visual_pwr: int = 0
var _visual_poison_stacks: int = 0
var _bound_uuid: String = "" # UUID bound during populate()


func _ready() -> void:
	# Reorder UI: Move StatsContainer (HP/PWR) to the top (index 0)
	var vbox = get_node("VBoxContainer")
	var stats_container = vbox.get_node("StatsContainer")
	vbox.move_child(stats_container, 0)
	
	var bus = get_node("/root/SignalBus")
	if is_instance_valid(bus):
		bus.connect("view_selected", _on_view_selected)
		bus.connect("view_deselected", _on_view_deselected)
		
		# Animation signals (BattleAnimator controls these)
		if bus.has_signal("unit_flash_effect"):
			bus.connect("unit_flash_effect", _on_unit_flash_effect)
		if bus.has_signal("unit_bump_attack"):
			bus.connect("unit_bump_attack", _on_unit_bump_attack)
		if bus.has_signal("unit_death_fade"):
			bus.connect("unit_death_fade", _on_unit_death_fade)
		if bus.has_signal("unit_visual_stat_update"):
			bus.connect("unit_visual_stat_update", _on_unit_visual_stat_update)
		if bus.has_signal("unit_summon_fade"):
			bus.connect("unit_summon_fade", _on_unit_summon_fade)

func _exit_tree() -> void:
	# Proactively disconnect signals and end any active drag to prevent leaks
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		if bus.is_connected("view_selected", _on_view_selected):
			bus.disconnect("view_selected", _on_view_selected)
		if bus.is_connected("view_deselected", _on_view_deselected):
			bus.disconnect("view_deselected", _on_view_deselected)
		if bus.has_signal("unit_flash_effect") and bus.is_connected("unit_flash_effect", _on_unit_flash_effect):
			bus.disconnect("unit_flash_effect", _on_unit_flash_effect)
		if bus.has_signal("unit_bump_attack") and bus.is_connected("unit_bump_attack", _on_unit_bump_attack):
			bus.disconnect("unit_bump_attack", _on_unit_bump_attack)
		if bus.has_signal("unit_death_fade") and bus.is_connected("unit_death_fade", _on_unit_death_fade):
			bus.disconnect("unit_death_fade", _on_unit_death_fade)
		if bus.has_signal("unit_summon_fade") and bus.is_connected("unit_summon_fade", _on_unit_summon_fade):
			bus.disconnect("unit_summon_fade", _on_unit_summon_fade)

	# If this view is being freed during a drag, centrally end the drag and visuals
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

## Helper method for SlotView to check UUID
func get_instance_uuid() -> String:
	return _instance_uuid

func populate(loc: LocationIdentifier, visual_data: Dictionary, is_inspectable: bool = true, single_click_inspect: bool = false) -> void:
	self._location = loc
	self._instance_uuid = visual_data.get("uuid", "")
	self._bound_uuid = visual_data.get("uuid", "")
	self._is_inspectable = is_inspectable
	self._single_click_inspect = single_click_inspect
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

	if visual_data.is_empty():
		visible = false
		return
	
	# Set entity type based on definition category
	var category = visual_data.get("category", "UNIT")
	_entity_type = StringName(category)
	
	# Initialize visual state
	_visual_hp = visual_data.get("hp", 0)
	_visual_pwr = visual_data.get("pwr", 0)
	_visual_poison_stacks = visual_data.get("poison_stacks", 0)
	
	# Set visual elements
	if icon_rect:
		icon_rect.texture = visual_data.get("icon")
	
	if tier_label:
		var tier = visual_data.get("tier", 0)
		tier_label.text = "T%d" % tier
		# Set tier color
		match tier:
			0: tier_label.modulate = Color.WHITE
			1: tier_label.modulate = Color.GREEN
			2: tier_label.modulate = Color.BLUE
			3: tier_label.modulate = Color.ORANGE
	
	_update_stats()
	visible = true

	# Fix for huge trinket icons: Only apply scaling constraint for TRINKETs.
	# Units and Items should use default scaling to preserve their intended size.
	if _entity_type == &"TRINKET":
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		# Restore defaults for Units/Items
		icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_SCALE

	# Set tooltip from localization key
	var loc_key: String = visual_data.get("display_name_key", "")
	if not loc_key.is_empty():
		tooltip_text = tr(loc_key)
	
	_update_item_slots()
	_apply_selection_feedback()


func update_visuals(visual_data: Dictionary) -> void:
	if visual_data.is_empty() or visual_data.get("uuid") != _instance_uuid:
		return
		
	_visual_hp = visual_data.get("hp", 0)
	_visual_pwr = visual_data.get("pwr", 0)
	_visual_poison_stacks = visual_data.get("poison_stacks", 0)
	_update_stats()

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
	# Always hide by default
	hp_label.visible = false
	pwr_label.visible = false
	
	# Only show stats for UNITs (not items or trinkets)
	if _entity_type != &"UNIT":
		return
	
	# DECOUPLED: No instance queries - view is fully self-contained
	# _visual_hp, _visual_pwr are set during populate() and updated via animate_* methods
	# This makes the view a "puppet" that only knows what events tell it
	
	# Show HP and PWR for units
	hp_label.visible = true
	pwr_label.visible = true
	
	# Use visual state directly (never query instances)
	hp_label.text = "HP: %d" % max(0, _visual_hp)
	pwr_label.text = "PWR: %d" % _visual_pwr
	
	# Update status effect displays (poison, etc.)
	_update_item_slots()

# ------------------------------------------------------------------
# Puppet API (Called by BattleAnimator)
# ------------------------------------------------------------------

func set_visual_state(snapshot: Dictionary) -> void:
	# Snapshot keys: "hp", "pwr", "def_id"
	if snapshot.has("hp"):
		_visual_hp = int(snapshot["hp"])
	if snapshot.has("pwr"):
		_visual_pwr = int(snapshot["pwr"])
	if snapshot.has("poison_stacks"):
		_visual_poison_stacks = int(snapshot["poison_stacks"])
	_update_stats()

func animate_poison_change(target_stacks: int) -> void:
	_visual_poison_stacks = target_stacks
	_update_stats()

func animate_stat_change(target_val: int, _delta: int, type: String) -> void:
	# type: "hp" or "pwr"
	var label = hp_label if type == "hp" else pwr_label
	var start_val = _visual_hp if type == "hp" else _visual_pwr
	
	# Update internal visual state immediately so subsequent calls are correct
	if type == "hp": _visual_hp = target_val
	else: _visual_pwr = target_val
	
	# Tween the number
	var tween = create_tween()
	tween.tween_method(func(val): label.text = "%s: %d" % [type.to_upper(), val], start_val, target_val, 0.5)

func _update_item_slots() -> void:
	# REDESIGNED: Now shows status effects instead of item icons
	# Clear existing displays
	for child in item_grid.get_children():
		child.queue_free()
	
	# Only show status effects for units
	if _entity_type != &"UNIT":
		return
	
	# Display status effects as large numbers
	# Show poison stacks if present (as purple number)
	var poison_stacks = _visual_poison_stacks
	
	if poison_stacks > 0:
		var poison_label = Label.new()
		poison_label.text = str(poison_stacks)
		poison_label.add_theme_font_size_override("font_size", 24)
		poison_label.modulate = Color.MEDIUM_PURPLE
		poison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poison_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_grid.add_child(poison_label)

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
			_update_item_slots() # Update poison display when status effects change

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

	return {"source_loc": _location}

func _can_drop_data(_at_position, data) -> bool:
	# TDD 4.3.III.5: Prevent dropping in Inspection-Only contexts
	var context_group = GlobalInteractionRouter.get_context_group(_location.container)
	if context_group == &"InspectionOnly":
		return false
		
	return data is Dictionary and data.has("source_loc")

func _drop_data(_at_position, _data) -> void:
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

func _on_unit_flash_effect(unit_uuid: String, flash_color: Color) -> void:
	# Only respond if this view represents the unit
	if _instance_uuid == unit_uuid:
		_flash_unit_color(flash_color)

func _flash_unit_color(flash_color: Color) -> void:
	# Briefly flash the panel to the given color and back
	var original_modulate: Color = modulate
	modulate = flash_color
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, 1.0)
	# Emit completion signal when flash finishes
	tween.finished.connect(_on_flash_tween_finished)

func _on_unit_visual_stat_update(uuid: String, stat: String, value: int) -> void:
	if uuid == _instance_uuid:
		if stat == "hp":
			_visual_hp = value
		elif stat == "pwr":
			_visual_pwr = value
		_update_stats()

func _on_unit_bump_attack(unit_uuid: String, direction: Vector2) -> void:
	# Only respond if this view represents the attacker
	if _instance_uuid != unit_uuid:
		return
	# Small bump distance to avoid overlapping allies
	var distance := 10.0
	var start_pos: Vector2 = position
	var bump_target := start_pos + (direction.normalized() * distance)
	# Kill any existing position tweens by setting immediately to start
	position = start_pos
	var tween = create_tween()
	# Move forward (half the duration)
	tween.tween_property(self, "position", bump_target, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Then return (half the duration)
	tween.tween_property(self, "position", start_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Emit completion signal when bump finishes
	tween.finished.connect(_on_bump_tween_finished)

func _on_unit_death_fade(unit_uuid: String) -> void:
	# Only respond if this view represents the dying unit
	if _instance_uuid != unit_uuid:
		return
	# Flash red if not already, then fade out alpha for visual clarity
	var _start_modulate: Color = modulate # Store starting modulate for potential future use
	var fade_tween = create_tween()
	# Ensure we are visible, then fade to 0 alpha
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(_on_death_fade_tween_finished)

func _on_unit_summon_fade(unit_uuid: String) -> void:
	# Only respond if this view represents the summoned unit
	if _instance_uuid != unit_uuid:
		return
	# Start invisible and fade in
	modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Emit completion signal when summon fade finishes
	fade_tween.finished.connect(_on_summon_fade_tween_finished)


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

# Animation completion callbacks that emit global signals
func _on_flash_tween_finished() -> void:
	SignalBus.emit_signal("unit_flash_finished", _instance_uuid)

func _on_bump_tween_finished() -> void:
	SignalBus.emit_signal("unit_bump_finished", _instance_uuid)

func _on_death_fade_tween_finished() -> void:
	SignalBus.emit_signal("unit_death_fade_finished", _instance_uuid)

func _on_summon_fade_tween_finished() -> void:
	SignalBus.emit_signal("unit_summon_fade_finished", _instance_uuid)
