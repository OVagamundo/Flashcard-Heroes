# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var item_grid: GridContainer = %ItemGrid
@onready var hp_container: Control = %HPContainer
@onready var pwr_container: Control = %PWRContainer
@onready var burn_container: Control = %BurnContainer # Renamed from PoisonContainer
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel
@onready var burn_label: Label = %BurnLabel # Renamed from PoisonLabel

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
var _visual_burn_stacks: int = 0 # Renamed from _visual_poison_stacks
var _bound_uuid: String = "" # UUID bound during populate()
var _melee_origin_position: Vector2 = Vector2.ZERO # Stored for return animation
var _flash_tween: Tween = null # Store active flash tween to prevent conflict


func _ready() -> void:
	# Reorder UI: Move StatsContainer (HP/PWR) to the top (index 0)
	var vbox = get_node("VBoxContainer")
	var stats_container = vbox.get_node("StatsContainer")
	vbox.move_child(stats_container, 0)
	
	# IMPORTANT: Duplicate the shader material so each instance has its own
	# Otherwise all GachaBallViews would share the same material and selection state
	if icon_rect and icon_rect.material:
		icon_rect.material = icon_rect.material.duplicate()
	
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
		if bus.has_signal("unit_melee_lunge"):
			bus.connect("unit_melee_lunge", _on_unit_melee_lunge)
		if bus.has_signal("unit_melee_return"):
			bus.connect("unit_melee_return", _on_unit_melee_return)

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
		if bus.has_signal("unit_melee_lunge") and bus.is_connected("unit_melee_lunge", _on_unit_melee_lunge):
			bus.disconnect("unit_melee_lunge", _on_unit_melee_lunge)
		if bus.has_signal("unit_melee_return") and bus.is_connected("unit_melee_return", _on_unit_melee_return):
			bus.disconnect("unit_melee_return", _on_unit_melee_return)

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
	_visual_burn_stacks = visual_data.get("burn_stacks", 0) # Renamed from poison_stacks
	
	if icon_rect:
		icon_rect.texture = visual_data.get("icon")
	
	_update_stats()
	visible = true

	# Units/Items also use Aspect Centered to prevent squished icons
	# The SlotView constrains the size, so we want to fit within it while keeping aspect ratio.
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

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

func _update_stats(animate: bool = false, visual_data: Dictionary = {}) -> void:
	# Always hide by default
	hp_container.visible = false
	pwr_container.visible = false
	burn_container.visible = false # Renamed from poison_container
	
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
	else:
		hp_label.text = str(max(0, _visual_hp))
		pwr_label.text = str(_visual_pwr)
		
		# Update burn label (show only when stacks > 0)
		if _visual_burn_stacks > 0:
			burn_container.visible = true
			burn_label.text = str(_visual_burn_stacks)
		else:
			burn_container.visible = false
	
	# Update internal visual state if visual_data was provided for animation
	if not visual_data.is_empty():
		_visual_hp = visual_data.hp
		_visual_pwr = visual_data.pwr
		_visual_burn_stacks = visual_data.burn_stacks

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

func _on_unit_flash_effect(unit_uuid: String, flash_color: Color) -> void:
	# Only respond if this view represents the unit
	if _instance_uuid == unit_uuid:
		_flash_unit_color(flash_color)

func _flash_unit_color(flash_color: Color) -> void:
	# Flash the icon using shader parameter with the given color
	# For damage (white/red): recoil backward
	# For heal (green): hop up
	var mat = icon_rect.material as ShaderMaterial if is_instance_valid(icon_rect) else null
	
	if not mat:
		# Fallback: just flash the parent
		var original_modulate: Color = modulate
		modulate = flash_color
		var fallback_tween = create_tween()
		fallback_tween.tween_property(self, "modulate", original_modulate, 0.3)
		fallback_tween.finished.connect(_on_flash_tween_finished)
		return
	
	var original_position: Vector2 = Vector2.ZERO
	# Default to current modulation if we need to reset
	var base_modulate: Color = modulate
	
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		# Snap back to "ground" before starting new hop
		# Since we don't store exact original position, we rely on the fact that
		# for a hop/recoil, we generally want to start from the layout's intended pos.
		# A quick hack: Reset modulation immediately.
		modulate = base_modulate
		if is_instance_valid(icon_rect) and icon_rect.material:
			(icon_rect.material as ShaderMaterial).set_shader_parameter("flash_intensity", 0.0)
			
		# Ideally we'd reset position too, but to what?
		# Let's trust that small errors are better than blocking the animation.
		original_position = position # Capture current (might be slightly off if interrupted)
	else:
		original_position = position
	
	# Detect if this is a heal flash (green-ish color) OR Buff (Yellow-ish)
	# Heal: Green clearly dominates Red (e.g., Color(0.3, 1.0, 0.3))
	# Buff: Yellow-ish (R and G both high, similar values, e.g., Color(1.0, 0.9, 0.0))
	# Damage: Red-dominant or pinkish (e.g., Color(1.0, 0.6, 0.6) - red much higher than green)
	# Burn: Orange (e.g., Color(1.0, 0.3, 0.0) - red high, green low)
	
	# A color is heal/buff if green >= red (green dominant or equal for yellow)
	# Damage colors have red significantly higher than green
	var is_heal_or_buff := flash_color.g >= flash_color.r
	
	var motion_target: Vector2
	if is_heal_or_buff:
		# Heal/Buff: hop up
		var hop_height := 12.0
		motion_target = Vector2(original_position.x, original_position.y - hop_height)
	else:
		# Damage/Burn: recoil backward opposite attack direction
		var recoil_distance := 8.0
		var recoil_direction := Vector2.RIGHT if icon_rect.flip_h else Vector2.LEFT
		motion_target = original_position + (recoil_direction * recoil_distance)
	
	# Set flash color and intensity to 1 (fully flashed)
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("flash_intensity", 1.0)
	
	# Also flash parent for stat labels
	var original_parent_modulate: Color = modulate
	modulate = Color(flash_color.r * 1.3, flash_color.g * 1.3, flash_color.b * 1.3, 1.0)
	
	# Create animation
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	
	if is_heal_or_buff:
		# Heal: hop up quickly, then land with small bounce
		_flash_tween.tween_property(self, "position", motion_target, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Damage: recoil back quickly
		_flash_tween.tween_property(self, "position", motion_target, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Then return and fade flash
	_flash_tween.set_parallel(false)
	if is_heal_or_buff:
		_flash_tween.tween_property(self, "position", original_position, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		_flash_tween.tween_property(self, "position", original_position, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_flash_tween.set_parallel(true)
	# Fade flash_intensity back to 0 (no flash)
	_flash_tween.tween_method(func(v): mat.set_shader_parameter("flash_intensity", v), 1.0, 0.0, 0.25)
	_flash_tween.tween_property(self, "modulate", original_parent_modulate, 0.25)
	
	_flash_tween.set_parallel(false)
	_flash_tween.finished.connect(_on_flash_tween_finished)

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
	tween.tween_property(self, "position", bump_target, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Then return (half the duration)
	tween.tween_property(self, "position", start_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Emit completion signal when bump finishes
	tween.finished.connect(_on_bump_tween_finished)

func _on_unit_death_fade(unit_uuid: String) -> void:
	# Only respond if this view represents the dying unit
	if _instance_uuid != unit_uuid:
		return
	
	var original_position: Vector2 = position
	var levitate_height := 40.0
	var levitate_target := Vector2(original_position.x, original_position.y - levitate_height)
	
	# Fade out and levitate upward
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Levitate upward
	fade_tween.tween_property(self, "position", levitate_target, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade parent (affects labels and background)
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Fade icon via shader parameter (shader ignores modulate)
	var mat = icon_rect.material as ShaderMaterial if is_instance_valid(icon_rect) else null
	if mat:
		fade_tween.tween_method(func(v): mat.set_shader_parameter("alpha_multiplier", v), 1.0, 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	fade_tween.set_parallel(false)
	fade_tween.finished.connect(_on_death_fade_tween_finished)

func _on_unit_summon_fade(unit_uuid: String) -> void:
	# Only respond if this view represents the summoned unit
	if _instance_uuid != unit_uuid:
		return
	
	var original_position: Vector2 = position
	var drop_height := 50.0
	var start_position := Vector2(original_position.x, original_position.y - drop_height)
	
	# Start invisible and above, then drop in and fade in
	modulate.a = 0.0
	position = start_position
	
	# Also set shader alpha to 0 for icon
	var mat = icon_rect.material as ShaderMaterial if is_instance_valid(icon_rect) else null
	if mat:
		mat.set_shader_parameter("alpha_multiplier", 0.0)
	
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Drop down to original position
	fade_tween.tween_property(self, "position", original_position, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Fade in parent
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade in icon via shader
	if mat:
		fade_tween.tween_method(func(v): mat.set_shader_parameter("alpha_multiplier", v), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	fade_tween.set_parallel(false)
	fade_tween.finished.connect(_on_summon_fade_tween_finished)


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

# Animation completion callbacks that emit global signals
func _on_flash_tween_finished() -> void:
	SignalBus.emit_signal("unit_flash_finished", _instance_uuid)

func _on_bump_tween_finished() -> void:
	SignalBus.emit_signal("unit_bump_finished", _instance_uuid)

func _on_death_fade_tween_finished() -> void:
	SignalBus.emit_signal("unit_death_fade_finished", _instance_uuid)

func _on_summon_fade_tween_finished() -> void:
	SignalBus.emit_signal("unit_summon_fade_finished", _instance_uuid)

# ------------------------------------------------------------------
# Melee Lunge Animation (Attacker jumps to target)
# ------------------------------------------------------------------

# Animation timing: Total 1.0s, with travel-to-target being 2x return time
# Breakdown: 0.1 (windup) + 0.6 (lunge to target) + 0.3 (return) = 1.0s total
const MELEE_LUNGE_DURATION := 0.6 # Travel to target (2x return time)
const MELEE_WINDUP_DURATION := 0.1 # Windup time (anticipation before lunge)
const MELEE_RETURN_DURATION := 0.3 # Return time (half of travel time)
const MELEE_ARC_HEIGHT := 120.0 # Higher arc for the longer jump
const MELEE_WINDUP_DISTANCE := 30.0 # Pixel distance to wind back

var _original_z_index: int = 0 # Store original z_index for restoration

func _on_unit_melee_lunge(unit_uuid: String, target_position: Vector2) -> void:
	# Only respond if this view represents the attacking unit
	if _instance_uuid != unit_uuid:
		return
	
	# Store original position for return animation
	_melee_origin_position = global_position
	
	# Raise z_index so we appear in front of other units during animation
	_original_z_index = z_index
	z_index = 100
	
	# Calculate arc control point (peak height)
	var mid_y = min(_melee_origin_position.y, target_position.y) - MELEE_ARC_HEIGHT
	
	# 1. Wind up backwards (anticipation)
	# Vector pointing away from target
	var direction_to_target = (target_position - _melee_origin_position).normalized()
	var windup_pos = _melee_origin_position - (direction_to_target * MELEE_WINDUP_DISTANCE)
	
	var tween = create_tween()
	
	# Windup: move back slightly
	tween.tween_property(self, "global_position", windup_pos, MELEE_WINDUP_DURATION) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	
	# 2. Lunge forward with arc
	# We'll use a custom method to interpolate along an arc
	tween.tween_method(
		func(t: float):
			# Quadratic bezier curve for arc motion
			# Start from windup position
			var p0 = windup_pos
			# Control point needs to be adjusted since we start from windup
			# Recalculate mid point based on windup start
			var current_mid_x = (p0.x + target_position.x) / 2.0
			var p1 = Vector2(current_mid_x, mid_y)
			var p2 = target_position
			
			# B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
			var one_minus_t = 1.0 - t
			global_position = (one_minus_t * one_minus_t * p0) + (2.0 * one_minus_t * t * p1) + (t * t * p2),
		0.0,
		1.0,
		MELEE_LUNGE_DURATION
	).set_trans(Tween.TRANS_LINEAR) # Linear time allows Bezier math to handle gravity naturally (slows at top, speeds up down)
	
	tween.finished.connect(_on_melee_lunge_tween_finished)

func _on_melee_lunge_tween_finished() -> void:
	SignalBus.emit_signal("unit_melee_lunge_finished", _instance_uuid)

func _on_unit_melee_return(unit_uuid: String) -> void:
	# Only respond if this view represents the unit
	if _instance_uuid != unit_uuid:
		return
	
	# Super fast snap-back animation
	var tween = create_tween()
	tween.tween_property(self, "global_position", _melee_origin_position, MELEE_RETURN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_melee_return_tween_finished)

func _on_melee_return_tween_finished() -> void:
	# Restore original z_index
	z_index = _original_z_index
	SignalBus.emit_signal("unit_melee_return_finished", _instance_uuid)
