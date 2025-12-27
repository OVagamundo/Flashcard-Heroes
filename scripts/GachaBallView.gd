# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

# Size scale constants for different contexts
const BATTLE_SCALE: float = 2.0 # 2x size for battle scene
const WINDOW_SCALE: float = 1.0 # 1x size for inventory windows, discard pile

# Gachaball overlay texture path for inventory items
const GACHABALL_OVERLAY_PATH = "res://assets/ui/textures/gachaball.png"
const GACHABALL_SELECTION_PATH = "res://assets/ui/textures/gachaballselected.png"

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

# Drag deformation state (rubber toy physics)
var _is_dragging: bool = false
var _drag_first_frame: bool = true # Skip velocity calc on first frame after drag start
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _original_icon_scale: Vector2 = Vector2.ONE
var _original_icon_rotation: float = 0.0
var _drag_preview: Control = null # Reference to the drag preview for deformation

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
		bus.connect("inventory_action_completed", _on_inventory_action_completed)
		
		# unit_visual_stat_update is still handled here for puppet mode updates
		if bus.has_signal("unit_visual_stat_update"):
			bus.connect("unit_visual_stat_update", _on_unit_visual_stat_update)
			
		if bus.has_signal("drag_ended"):
			bus.drag_ended.connect(_on_drag_ended)
		# NOTE: Animation signals (flash, bump, death, summon, melee, lethal_save)
		# are now handled by UnitAnimationController child node

func _process(delta: float) -> void:
	# Drag deformation: Apply rubber-toy physics to drag preview based on velocity
	if not _is_dragging: return
	if not is_instance_valid(_drag_preview): return
	
	var mouse_pos = get_global_mouse_position()
	
	# Skip velocity calculation on first frame to prevent initial spike
	if _drag_first_frame:
		_drag_first_frame = false
		_last_mouse_pos = mouse_pos
		return
	
	var velocity = (mouse_pos - _last_mouse_pos) / max(delta, 0.001)
	_last_mouse_pos = mouse_pos
	
	# Smooth velocity for less jittery deformation
	_drag_velocity = _drag_velocity.lerp(velocity, 0.25)
	
	# --- Pendulum swing (realistic momentum-based) ---
	var target_rotation = clamp(_drag_velocity.x * 0.0001, -0.12, 0.12)
	_drag_preview.rotation = lerp(_drag_preview.rotation, target_rotation, 0.15)
	
	# --- Stretch only when moving UP (sag effect) ---
	var stretch_factor := 0.0
	# Clamp velocity to prevent infinite stretch on potential spikes
	var clamped_velocity_y = max(_drag_velocity.y, -2000.0)
	
	if clamped_velocity_y < -100: # Only when moving up fast enough
		# Limit max stretch to 20% (0.2) to prevent "spaghetti" effect
		stretch_factor = clamp(-clamped_velocity_y * 0.00005, 0.0, 0.2)
	
	# Target scale - return to 1.0 when not stretching
	var target_scale = Vector2(1.0 - stretch_factor * 0.15, 1.0 + stretch_factor)
	
	# Quick return to normal scale (faster lerp when near 1.0)
	var lerp_speed = 0.3 if stretch_factor < 0.01 else 0.15
	_drag_preview.scale = _drag_preview.scale.lerp(target_scale, lerp_speed)

func _exit_tree() -> void:
	# Reset drag deformation state if still dragging
	_reset_drag_deformation()
	
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

var _logical_drag_success: bool = false

func _on_drag_ended(was_handled: bool) -> void:
	if _is_dragging:
		_logical_drag_success = was_handled

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
			# For Inventory (where overlay exists), keep icon smaller (1x) centered in 2x slot
			# For Battle, scale icon to 2x
			if _size_scale == WINDOW_SCALE or (_size_scale == BATTLE_SCALE and get_viewport().gui_get_focus_owner() == null): # Fallback heuristic
				pass
			
			# Logic: If we are in inventory (using overlay), we want the icon to stay 1x (64px) 
			# but the container to be 2x (128px).
			# check if overlay was added? No easy way to check here without state.
			# Let's use the fact that we added the overlay in _update_item_slots which is called AFTER this.
			# We'll set the size here assuming standard behavior, and if needed we can adjust.
			
			# ACTUALLY: The user wants units INSIDE the ball.
			# If slot is 128px, ball is 128px.
			# Unit should be 64px (native) centered.
			
			var target_size = icon_rect.texture.get_size() * _size_scale
			
			# Hack: If this is the inventory view (which we can infer or pass via populate options? No...)
			# Let's rely on _create_gachaball_overlay to fix it? No, populate sets min_size.
			
			# Better: Always expand to _size_scale for the CONTAINER, but logic for content:
			icon_rect.custom_minimum_size = target_size
			
			# If we are in inventory (indicated by checking if we are going to add overlay)
			# We can't know for sure easily. 
			# Let's change how we set stretch mode.
			
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Fill the slot with the rect
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # Center texture
			
			# BUT, if we want to scale up for Battle (no overlay), we NEED to scale the texture.
			# STRETCH_KEEP_ASPECT_CENTERED doesn't scale up.
			
			# Dual logic:
			if _size_scale > 1.0 and not _has_overlay_heuristic():
				# Battle Mode: Scale UP
				icon_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = target_size
				
				# Remove unit sprite if present (switching back to Battle)
				var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
				if unit_sprite: unit_sprite.queue_free()
			else:
				# Inventory Mode: Fixed slot size (192), Unit (128) centered inside
				icon_rect.custom_minimum_size = Vector2(192, 192)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.texture = null # Clear main texture, use child sprite
				
				var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
				if not unit_sprite:
					unit_sprite = TextureRect.new()
					unit_sprite.name = "UnitSprite"
					icon_rect.add_child(unit_sprite)
					unit_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
					unit_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					unit_sprite.stretch_mode = TextureRect.STRETCH_SCALE
				
				# Configure unit sprite size and position (no anchor preset, direct positioning)
				unit_sprite.custom_minimum_size = Vector2(128, 128)
				unit_sprite.size = Vector2(128, 128)
				unit_sprite.position = Vector2(32, 32) # (192-128)/2 = 32px margin
				unit_sprite.texture = visual_data.get("icon")
				unit_sprite.visible = true
		else:
			# Fallback for missing textures
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Ensure cleanup if switching contexts (unlikely but safe)
			var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
			if unit_sprite: unit_sprite.queue_free()
	
	_update_stats()
	visible = true

	# Add gachaball overlay for inventory windows
	if _has_overlay_heuristic():
		_create_gachaball_overlay()

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

## Create gachaball overlay for inventory windows
## This adds the gachaball.png texture on top of unit/item sprites
func _create_gachaball_overlay() -> void:
	if not is_instance_valid(icon_rect):
		return
	
	# Check if overlay already exists (prevent duplication on repopulate)
	if get_node_or_null("GachaBallOverlay"):
		return
	
	# Load the overlay texture
	var overlay_texture = load(GACHABALL_OVERLAY_PATH)
	if not is_instance_valid(overlay_texture):
		return
	
	# Create overlay TextureRect
	var overlay = TextureRect.new()
	overlay.name = "GachaBallOverlay"
	overlay.texture = overlay_texture
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE # Scale to fill 192px
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.custom_minimum_size = Vector2(192, 192)
	overlay.size = Vector2(192, 192)
	
	# Add as sibling to VBox (Icon) but before StatsOverlay to ensure correct Z-order:
	# 0: Anim, 1: VBox(Unit), 2: Overlay(Ball), 3: Stats(Labels)
	add_child(overlay)
	move_child(overlay, 2)

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
	
	# --- Drag Deformation: Start tracking ---
	_is_dragging = true
	_drag_first_frame = true # Skip first velocity calc
	_last_mouse_pos = get_global_mouse_position()
	_drag_velocity = Vector2.ZERO
	if is_instance_valid(icon_rect):
		_original_icon_scale = icon_rect.scale
		_original_icon_rotation = icon_rect.rotation
	
	# Get the correct texture for drag preview
	var drag_texture: Texture2D = icon_rect.texture
	var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
	if unit_sprite and unit_sprite.texture:
		drag_texture = unit_sprite.texture
	
	# Create container for drag preview (to show both unit and ball in inventory mode)
	# To center the preview on cursor: use a container twice the size, then offset content by -half
	# Override preview size for battle logic to ensure squareness and prevent "too big" issues
	# Battle views might be stretched by layout, but the drag preview should be a clean square.
	var preview_size: Vector2
	if _has_overlay_heuristic():
		preview_size = Vector2(192, 192)
	else:
		# In Battle (2x scale), usually 64->128. But user reports 128 is "much smaller".
		# Inventory uses 192. Let's match inventory size for consistency and larger visuals.
		var base_size = 192.0
		preview_size = Vector2(base_size, base_size)

	var container_size = preview_size * 2 # Double size to allow centering
	var offset = - preview_size / 2 # Offset to center content on top-left (where cursor is)
	
	var preview_container = Control.new()
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.z_index = RenderingServer.CANVAS_ITEM_Z_MAX # Stay on top
	preview_container.custom_minimum_size = container_size
	
	# Add unit/item texture
	var preview = TextureRect.new()
	preview.texture = drag_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	if _has_overlay_heuristic():
		# In inventory mode: unit is 128 in 192 slot = 2/3 size ratio
		var unit_size = preview_size * (128.0 / 192.0)
		preview.custom_minimum_size = unit_size
		preview.size = unit_size
		preview.position = offset + (preview_size - unit_size) / 2 # Center unit
	else:
		preview.custom_minimum_size = preview_size
		preview.size = preview_size
		preview.position = offset
	preview_container.add_child(preview)
	
	# Add gachaball overlay for inventory mode
	if _has_overlay_heuristic():
		var overlay_texture = load(GACHABALL_OVERLAY_PATH)
		if overlay_texture:
			var overlay_preview = TextureRect.new()
			overlay_preview.texture = overlay_texture
			overlay_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			overlay_preview.stretch_mode = TextureRect.STRETCH_SCALE
			overlay_preview.custom_minimum_size = preview_size
			overlay_preview.size = preview_size
			overlay_preview.position = offset
			preview_container.add_child(overlay_preview)
		
		# Add selection outline circle for drag feedback
		var selection_texture = load(GACHABALL_SELECTION_PATH)
		if selection_texture:
			var selection_ring = TextureRect.new()
			selection_ring.texture = selection_texture
			selection_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			selection_ring.stretch_mode = TextureRect.STRETCH_SCALE
			selection_ring.custom_minimum_size = preview_size
			selection_ring.size = preview_size
			selection_ring.position = offset
			preview_container.add_child(selection_ring)
	else:
		# Battle mode: Apply outline shader to unit preview
		if icon_rect.material:
			var drag_mat = icon_rect.material.duplicate() as ShaderMaterial
			drag_mat.set_shader_parameter("outline_enabled", true)
			preview.material = drag_mat
	
	# Store reference to drag preview for deformation animation
	_drag_preview = preview_container
	# Initialize scale and pivot for deformation
	_drag_preview.scale = Vector2.ONE
	_drag_preview.pivot_offset = Vector2.ZERO
	
	# Skip first frame velocity calc to avoid spike
	_last_mouse_pos = get_global_mouse_position()
	set_drag_preview(preview_container)

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
	
	# In inventory mode, use a white circle outline texture for selection
	var overlay = get_node_or_null("GachaBallOverlay")
	if overlay and _has_overlay_heuristic():
		# Create/show selection ring when selected
		var selection_ring = get_node_or_null("SelectionRing")
		if _is_selected:
			if not selection_ring:
				var selection_texture = load(GACHABALL_SELECTION_PATH)
				if selection_texture:
					selection_ring = TextureRect.new()
					selection_ring.name = "SelectionRing"
					selection_ring.texture = selection_texture
					selection_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					selection_ring.stretch_mode = TextureRect.STRETCH_SCALE
					selection_ring.custom_minimum_size = Vector2(192, 192)
					selection_ring.size = Vector2(192, 192)
					selection_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
					# Add after overlay (on top)
					add_child(selection_ring)
					move_child(selection_ring, 3) # After overlay (2), before stats (4)
			if selection_ring:
				selection_ring.visible = true
			
			# Also apply scale effect
			overlay.scale = Vector2(1.05, 1.05)
			overlay.pivot_offset = overlay.size / 2
		else:
			if selection_ring:
				selection_ring.visible = false
			overlay.scale = Vector2(1.0, 1.0)
	else:
		# Battle mode: Use shader-based outline on icon_rect
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
		var godot_successful = is_drag_successful()
		var was_dragging_me = _is_dragging # Capture local state before reset
		
		# Combine Godot's mechanical success with our logical success (from inventory)
		# If we dropped on a slot (Godot success) but Inventory rejected it (logic fail),
		# we must treat it as a failure and bounce.
		var combined_success = godot_successful and _logical_drag_success
		
		# Reset deformation first so we start animation from a clean state (scale 1.0)
		_reset_drag_deformation()
		
		# If drag was NOT successful (dropped on nothing OR rejected by logic), bounce back
		if was_dragging_me and not combined_success:
			if GlobalInteractionRouter.is_drag_active():
				GlobalInteractionRouter.end_drag(false)
			
			_play_landing_bounce()
		
		# Reset local drag flag
		_drag_initiated_for_click = false
		_logical_drag_success = false # Reset for next time
		
		# Ensure drag signals are cleared if they haven't been already
		if GlobalInteractionRouter.is_drag_active():
			# If it was successful, it's likely already handled by InventoryManager calling end_drag(true)
			# But if we are here and it's still active, it might be a race or unhandled case.
			# Safe default: end it as handled if successful (to keep view hidden/transferred), false if not.
			GlobalInteractionRouter.end_drag(combined_success)
			GlobalInteractionRouter.end_drag_visuals(combined_success)

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

var force_inventory_mode: bool = false

## Heuristic to check if we should render in "Inventory Mode" (2x scale, 192px slot, circle outline)
## 1. Checks if parent name contains "InventoryWindow"
## 2. Checks if force_inventory_mode is set
func _has_overlay_heuristic() -> bool:
	if force_inventory_mode:
		return true
	var p = get_parent()
	while p:
		if "InventoryWindow" in p.name: return true
		p = p.get_parent()
	return false

# --- Bounce Animation for Inventory Actions ---

func _on_inventory_action_completed(target_uuids: Array) -> void:
	if _bound_uuid in target_uuids:
		# VISUAL FEEDBACK: Be extremely aggressive about visibility
		if not visible:
			visible = true
			
		# Wait one frame for UI layout and redraw to complete
		await get_tree().process_frame
		_play_landing_bounce()

func _reset_drag_deformation() -> void:
	if not _is_dragging: return
	_is_dragging = false
	_drag_velocity = Vector2.ZERO
	_drag_preview = null
	if is_instance_valid(icon_rect):
		icon_rect.scale = _original_icon_scale
		icon_rect.rotation = _original_icon_rotation

func _play_landing_bounce() -> void:
	if not is_instance_valid(icon_rect): return
	
	# Force visibility: If this view was the drag source, it might still be hidden.
	if not visible:
		visible = true
	if is_instance_valid(get_parent()):
		get_parent().visible = true # Ensure parent slot is visible too
	
	# Store original values before animation
	var original_scale = icon_rect.scale
	var original_pos = icon_rect.position
	icon_rect.pivot_offset = icon_rect.size / 2.0
	
	# Start position: Slightly above (falling from a small height)
	var fall_height := 40.0
	icon_rect.position.y -= fall_height
	
	var bounce_tween = create_tween()
	
	# Phase 0: Fall down quickly (simulates drop from small height)
	bounce_tween.tween_property(icon_rect, "position:y", original_pos.y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Phase 1: Squish on impact (compress vertically, stretch horizontally)
	bounce_tween.tween_property(icon_rect, "scale", Vector2(1.2, 0.8), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 2: Stretch upward (bounce up)
	bounce_tween.tween_property(icon_rect, "scale", Vector2(0.9, 1.15), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 3: Small squish
	bounce_tween.tween_property(icon_rect, "scale", Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Phase 4: Settle to normal
	bounce_tween.tween_property(icon_rect, "scale", original_scale, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
