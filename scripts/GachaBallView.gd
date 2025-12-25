# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

# Size scale constants for different contexts
const BATTLE_SCALE: float = 2.0 # 2x size for battle scene
const WINDOW_SCALE: float = 1.0 # 1x size for inventory windows, discard pile

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var hp_container: Control = %HPContainer
@onready var pwr_container: Control = %PWRContainer
@onready var burn_container: Control = %BurnContainer # Renamed from PoisonContainer
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel
@onready var burn_label: Label = %BurnLabel # Renamed from PoisonLabel
@onready var armor_container: Control = %ArmorContainer
@onready var armor_label: Label = %ArmorLabel

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
var _visual_burn_stacks: int = 0 # Legacy - kept for backward compat
var _visual_armor_stacks: int = 0 # Armor stacks - same pattern as burn
var _visual_status_effects: Dictionary = {} # Generic: status_id -> stacks
var _status_icon_nodes: Dictionary = {} # Dynamic icon nodes: status_id -> TextureRect
var _bound_uuid: String = "" # UUID bound during populate()
var _size_scale: float = BATTLE_SCALE # Default to 2x for battle context
var _registered_with_overlay: bool = false # Track if registered with UnitLabelOverlay
# NOTE: Animation state variables (_melee_origin_position, _flash_tween, etc.)
# are now managed by UnitAnimationController child node


func _ready() -> void:
	# StatsContainer (Top) is already correctly positioned in the scene file
	# BottomStatsContainer is likewise correctly positioned below the icon
	# IMPORTANT: Duplicate the shader material so each instance has its own
	# Otherwise all GachaBallViews would share the same material and selection state
	if icon_rect and icon_rect.material:
		icon_rect.material = icon_rect.material.duplicate()
	
	var bus = get_node("/root/SignalBus")
	if is_instance_valid(bus):
		bus.connect("view_selected", _on_view_selected)
		bus.connect("view_deselected", _on_view_deselected)
		
		# unit_visual_stat_update is still handled here for puppet mode updates
		if bus.has_signal("unit_visual_stat_update"):
			bus.connect("unit_visual_stat_update", _on_unit_visual_stat_update)
		# NOTE: Animation signals (flash, bump, death, summon, melee, lethal_save)
		# are now handled by UnitAnimationController child node

func _exit_tree() -> void:
	# Proactively disconnect signals and end any active drag to prevent leaks
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		if bus.is_connected("view_selected", _on_view_selected):
			bus.disconnect("view_selected", _on_view_selected)
		if bus.is_connected("view_deselected", _on_view_deselected):
			bus.disconnect("view_deselected", _on_view_deselected)
		# NOTE: Animation signals are handled by UnitAnimationController child node

	# If this view is being freed during a drag, centrally end the drag and visuals
	if GlobalInteractionRouter.is_drag_active():
		GlobalInteractionRouter.end_drag(false)
		GlobalInteractionRouter.end_drag_visuals(false)

## Helper method for SlotView to check UUID
func get_instance_uuid() -> String:
	return _instance_uuid

## Set the size scale for this view (2.0 for battle, 1.0 for windows)
func set_size_scale(size_scale: float) -> void:
	_size_scale = size_scale

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
	_visual_burn_stacks = visual_data.get("burn_stacks", 0) # Renamed from poison_stacks
	_visual_armor_stacks = visual_data.get("armor_stacks", 0) # Same pattern as burn
	
	if icon_rect:
		icon_rect.texture = visual_data.get("icon")
		# Apply fixed size based on texture and scale factor
		if icon_rect.texture:
			var tex_size = icon_rect.texture.get_size() * _size_scale
			icon_rect.custom_minimum_size = tex_size
			icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			# Fallback for missing textures
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	_update_stats()
	visible = true

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
	_visual_burn_stacks = visual_data.get("burn_stacks", 0) # Renamed from poison_stacks
	_visual_armor_stacks = visual_data.get("armor_stacks", 0) # Same pattern as burn
	_update_stats()

func set_is_enemy(is_enemy: bool, definition_id: StringName = &"") -> void:
	if is_instance_valid(icon_rect):
		# Boss sprites are already facing the player direction, so don't flip them
		var is_boss: bool = String(definition_id).begins_with("boss_")
		icon_rect.flip_h = is_enemy and not is_boss

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

func _update_stats(animate: bool = false, visual_data: Dictionary = {}) -> void:
	# Always hide by default
	hp_container.visible = false
	pwr_container.visible = false
	burn_container.visible = false # Renamed from poison_container
	armor_container.visible = false # Added for armor
	
	# Only show stats for UNITs (not items or trinkets)
	if _entity_type != &"UNIT":
		return
	
	# DECOUPLED: No instance queries - view is fully self-contained
	# _visual_hp, _visual_pwr are set during populate() and updated via animate_* methods
	# This makes the view a "puppet" that only knows what events tell it
	
	# Show HP and PWR for units
	hp_container.visible = true
	pwr_container.visible = true
	
	# Use visual state directly (never query instances)
	var old_hp = _visual_hp
	var old_pwr = _visual_pwr
	var old_burn = _visual_burn_stacks # Added for burn animation logic
	var old_armor = _visual_armor_stacks # Added for armor animation logic
	
	if animate and not visual_data.is_empty():
		_animate_number(hp_label, old_hp, visual_data.hp)
		_animate_number(pwr_label, old_pwr, visual_data.pwr)
		
		# Burn animation (stacks)
		if visual_data.burn_stacks != old_burn:
			animate_burn_change(visual_data.burn_stacks)
		elif visual_data.burn_stacks > 0:
			# Even if stacks didn't change (e.g. refresh), pulse if active
			if is_instance_valid(burn_container) and burn_container.visible:
				_flash_label(burn_label)
		
		# Armor animation (stacks) - same pattern as burn
		if visual_data.has("armor_stacks") and visual_data.armor_stacks != old_armor:
			animate_armor_change(visual_data.armor_stacks)
		elif visual_data.has("armor_stacks") and visual_data.armor_stacks > 0:
			if is_instance_valid(armor_container) and armor_container.visible:
				_flash_label(armor_label)
	else:
		hp_label.text = str(max(0, _visual_hp))
		pwr_label.text = str(_visual_pwr)
		
		# Update burn label (show only when stacks > 0)
		if _visual_burn_stacks > 0:
			burn_container.visible = true
			burn_label.text = str(_visual_burn_stacks)
		else:
			burn_container.visible = false
		
		# Update armor label (show only when stacks > 0) - same pattern as burn
		if _visual_armor_stacks > 0:
			armor_container.visible = true
			armor_label.text = str(_visual_armor_stacks)
		else:
			armor_container.visible = false
	
	# Update internal visual state if visual_data was provided for animation
	if not visual_data.is_empty():
		_visual_hp = visual_data.hp
		_visual_pwr = visual_data.pwr
		_visual_burn_stacks = visual_data.burn_stacks
		if visual_data.has("armor_stacks"):
			_visual_armor_stacks = visual_data.armor_stacks

func _animate_number(label: Label, start_val: int, end_val: int) -> void:
	if start_val == end_val:
		label.text = str(end_val)
		return
	
	# Flash label
	_flash_label(label)
	
	var tween = create_tween()
	tween.tween_method(func(val): label.text = str(val), start_val, end_val, 0.5)

# ------------------------------------------------------------------
# Puppet API (Called by BattleAnimator)
# ------------------------------------------------------------------

func set_visual_state(snapshot: Dictionary) -> void:
	# CRITICAL: Update _instance_uuid to match what BattleAnimator registers
	# Without this, animation signals (flash, death, etc.) won't match!
	if snapshot.has("uuid"):
		_instance_uuid = String(snapshot["uuid"])
		_bound_uuid = _instance_uuid
	
	# Snapshot keys: "hp", "pwr", "def_id"
	if snapshot.has("hp"):
		_visual_hp = int(snapshot["hp"])
	if snapshot.has("pwr"):
		_visual_pwr = int(snapshot["pwr"])
	if snapshot.has("burn_stacks"): # Renamed from poison_stacks
		_visual_burn_stacks = int(snapshot["burn_stacks"]) # Renamed from poison_stacks
	if snapshot.has("armor_stacks"): # Added for armor - same pattern as burn
		_visual_armor_stacks = int(snapshot["armor_stacks"])
	
	# Restore generic status effects (armor, etc.)
	if snapshot.has("status_effects"):
		var effects: Dictionary = snapshot["status_effects"]
		for status_id in effects:
			# Skip burn and armor - handled by dedicated systems
			if status_id == &"burn" or status_id == &"armor":
				continue
			_visual_status_effects[status_id] = int(effects[status_id])
			print("[GachaBallView] set_visual_state restored %s=%d for %s" % [status_id, effects[status_id], _instance_uuid])
		_update_dynamic_status_icons()
	
	_update_stats()

func animate_burn_change(target_stacks: int) -> void: # Renamed from animate_poison_change
	var old_stacks = _visual_burn_stacks
	_visual_burn_stacks = target_stacks
	
	if target_stacks > 0:
		burn_container.visible = true
		# Update number
		burn_label.text = str(target_stacks)
		
		if old_stacks == 0:
			# Pop in - need animation
			burn_container.scale = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(burn_container, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Flash label
		if is_instance_valid(burn_container) and burn_container.visible:
			_flash_label(burn_label) # Renamed from poison_label
			
	else:
		# Fade out - need animation
		var tween = create_tween()
		tween.tween_property(burn_container, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): burn_container.visible = false)

## Animate armor change - same pattern as burn
func animate_armor_change(target_stacks: int) -> void:
	var old_stacks = _visual_armor_stacks
	_visual_armor_stacks = target_stacks
	
	if target_stacks > 0:
		armor_container.visible = true
		# Update number
		armor_label.text = str(target_stacks)
		
		if old_stacks == 0:
			# Pop in - need animation
			armor_container.scale = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(armor_container, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Flash label
		if is_instance_valid(armor_container) and armor_container.visible:
			_flash_label(armor_label)
			
	else:
		# Fade out - need animation
		var tween = create_tween()
		tween.tween_property(armor_container, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): armor_container.visible = false)

## Animate armor stat change with countdown (for damage visualization)
## Similar to animate_stat_change but for armor - counts down from current to new value
func animate_armor_stat_change(target_stacks: int, _amount: int) -> void:
	var start_val = _visual_armor_stacks
	_visual_armor_stacks = target_stacks
	
	if target_stacks > 0:
		armor_container.visible = true
		# Flash the label
		_flash_label(armor_label)
		# Tween the number countdown
		var tween = create_tween()
		tween.tween_method(func(val): armor_label.text = str(val), start_val, target_stacks, 0.3)
	elif start_val > 0:
		# Armor depleted: count down to 0, then fade out
		armor_container.visible = true
		_flash_label(armor_label)
		var tween = create_tween()
		# Count down to 0
		tween.tween_method(func(val): armor_label.text = str(maxi(0, val)), start_val, 0, 0.3)
		# Then fade out
		tween.tween_property(armor_container, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): armor_container.visible = false)

## Update dynamic status icons for any status effect tracked in _visual_status_effects.
## Creates icons on-the-fly using StatusEffectRegistry if they don't exist.
func _update_dynamic_status_icons() -> void:
	# Get the bottom stats container to add icons to (below the unit)
	var stats_container = get_node_or_null("StatsOverlay/BottomStatsContainer")
	if not is_instance_valid(stats_container):
		return
	
	# Update or create icons for each status effect
	for status_id in _visual_status_effects:
		var stacks: int = _visual_status_effects[status_id]
		
		# Skip burn and armor - handled by dedicated systems
		if status_id == &"burn" or status_id == &"armor":
			continue
		
		if stacks > 0:
			# Create icon if doesn't exist
			if not _status_icon_nodes.has(status_id):
				_create_status_icon(status_id, stats_container)
			
			# Update label and ensure visible
			var icon_node = _status_icon_nodes.get(status_id)
			if is_instance_valid(icon_node):
				icon_node.visible = true
				var label = icon_node.get_node_or_null("Label")
				if is_instance_valid(label):
					label.text = str(stacks)
		else:
			# Hide icon (don't destroy - prevents flickering from async queue_free)
			if _status_icon_nodes.has(status_id):
				var icon_node = _status_icon_nodes[status_id]
				if is_instance_valid(icon_node):
					icon_node.visible = false

## Create a dynamic status icon for a status effect
func _create_status_icon(status_id: StringName, parent: Node) -> void:
	# Get definition from registry
	var status_def = StatusEffectRegistry.get_definition(status_id)
	if not is_instance_valid(status_def):
		return
	
	# Create TextureRect for icon
	var status_icon_rect = TextureRect.new()
	status_icon_rect.custom_minimum_size = Vector2(48, 48)
	status_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon_rect.texture = status_def.icon
	status_icon_rect.scale = Vector2.ZERO # Start scaled down for animation
	
	# Create label for stack count
	var label = Label.new()
	label.name = "Label"
	label.layout_mode = 1
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 24)
	
	status_icon_rect.add_child(label)
	parent.add_child(status_icon_rect)
	
	# Store reference
	_status_icon_nodes[status_id] = status_icon_rect
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(status_icon_rect, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Animate a status effect change (for non-burn effects)
func animate_status_change(status_id: StringName, new_stacks: int) -> void:
	_visual_status_effects[status_id] = new_stacks
	_update_dynamic_status_icons()

func animate_stat_change(target_val: int, _delta: int, type: String) -> void:
	# type: "hp" or "pwr"
	var label = hp_label if type == "hp" else pwr_label
	var start_val = _visual_hp if type == "hp" else _visual_pwr
	
	# Update internal visual state immediately so subsequent calls are correct
	if type == "hp": _visual_hp = target_val
	else: _visual_pwr = target_val
	
	# Flash the label white
	_flash_label(label)
	
	# Tween the number
	var tween = create_tween()
	tween.tween_method(func(val): label.text = str(val), start_val, target_val, 0.5)

func _flash_label(label: Label) -> void:
	# Quick white flash on the label when its value changes
	if not is_instance_valid(label):
		return
	
	var original_modulate: Color = label.modulate
	label.modulate = Color(2.0, 2.0, 2.0, 1.0) # Bright white flash
	
	var tween = create_tween()
	tween.tween_property(label, "modulate", original_modulate, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_item_slots() -> void:
	# REDESIGNED: Now shows status effects instead of item icons
	# Clear existing displays
	for child in item_grid.get_children():
		child.queue_free()
	
	# Only show status effects for units
	if _entity_type != &"UNIT":
		return
	
	# Status effects are now displayed via permanent labels (poison_label)
	# Item slots can be used for other purposes if needed
	pass

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

## Granular stat change handler - updates only the specific stat that changed
## This is the clean pattern: HP changes only update HP, armor changes only update armor
func _on_unit_stat_changed(unit_uuid: String, stat_name: StringName, _old_value: int, new_value: int) -> void:
	if _instance_uuid != unit_uuid:
		return
	
	# Update ONLY the specific stat that changed
	match stat_name:
		&"hp":
			_visual_hp = new_value
			if is_instance_valid(hp_label):
				hp_label.text = str(max(0, new_value))
			if is_instance_valid(hp_container):
				hp_container.visible = true
		&"pwr":
			_visual_pwr = new_value
			if is_instance_valid(pwr_label):
				pwr_label.text = str(new_value)
			if is_instance_valid(pwr_container):
				pwr_container.visible = true
		&"burn_stacks":
			animate_burn_change(new_value)
		&"armor_stacks":
			animate_armor_change(new_value)
		_:
			# Handle other generic status effects
			if String(stat_name).ends_with("_stacks"):
				var status_id = StringName(String(stat_name).trim_suffix("_stacks"))
				_visual_status_effects[status_id] = new_value
				_update_dynamic_status_icons()

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
	# Make drag preview 20% larger than the actual icon
	preview.custom_minimum_size = icon_rect.size * 1.2
	
	# Apply outline shader to drag preview
	if icon_rect.material:
		var drag_mat = icon_rect.material.duplicate() as ShaderMaterial
		drag_mat.set_shader_parameter("outline_enabled", true)
		preview.material = drag_mat
	
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

# NOTE: Animation handlers (_on_unit_flash_effect, _on_unit_bump_attack, etc.)
# are now handled by UnitAnimationController child node

func _on_unit_visual_stat_update(uuid: String, stat: String, value: int) -> void:
	if uuid == _instance_uuid:
		if stat == "hp":
			_visual_hp = value
		elif stat == "pwr":
			_visual_pwr = value
		_update_stats()

# NOTE: Animation methods (bump, death, summon, melee, lethal_save, guardian leap)
# moved to UnitAnimationController child node

func _apply_selection_feedback() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(icon_rect): return
	
	# Use shader-based outline that follows sprite contour
	var mat = icon_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_enabled", _is_selected)
	
	# Scale the icon slightly larger when selected for a "pop" effect
	if _is_selected:
		icon_rect.scale = Vector2(1.1, 1.1)
		icon_rect.pivot_offset = icon_rect.size / 2 # Scale from center
	else:
		icon_rect.scale = Vector2(1.0, 1.0)

func _notification(what: int) -> void:
	# Fallback: if a drag ends without any drop target handling it, restore visuals
	if what == NOTIFICATION_DRAG_END:
		# Reset local drag flag
		_drag_initiated_for_click = false
		if GlobalInteractionRouter.is_drag_active():
			GlobalInteractionRouter.end_drag(false)
			GlobalInteractionRouter.end_drag_visuals(false)

# -----------------------------------------------------------------------------
# Guardian Leap (Forwarding to UnitAnimationController)
# Called by BattleAnimator for GUARDIAN_INTERCEPT events
# -----------------------------------------------------------------------------
func animate_leap_to(target_center: Vector2) -> void:
	var controller = get_node_or_null("AnimationController")
	if is_instance_valid(controller) and controller.has_method("animate_leap_to"):
		await controller.animate_leap_to(target_center)

func animate_leap_return() -> void:
	var controller = get_node_or_null("AnimationController")
	if is_instance_valid(controller) and controller.has_method("animate_leap_return"):
		await controller.animate_leap_return()
