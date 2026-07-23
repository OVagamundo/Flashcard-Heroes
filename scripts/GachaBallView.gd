# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")

# Size scale constants for different contexts
const BATTLE_SCALE: float = 2.0 # 2x size for battle scene
const WINDOW_SCALE: float = 1.0 # 1x size for inventory windows, discard pile

# Gachaball overlay texture path for inventory items
const GACHABALL_OVERLAY_PATH = "res://assets/Realistic/ui/textures/gachaballcapsule.png"

# Path-choice-style hover motion for selectable gachaballs.
const HOVER_SCALE: float = 0.12
const PRESS_SQUASH: float = 0.10
const INVENTORY_BRIGHTNESS_BOOST: float = 0.18
const INVENTORY_TRANSFORM_FACTOR: float = 0.92
const INVENTORY_OVERLAY_INSET_PX: float = 0.0
const HOVER_RAISED_Z_INDEX: int = 40
const HOVER_RAISED_SLOT_Z_INDEX: int = 20

enum HoverFxMode {
	OFF,
	INVENTORY_SPHERE,
	BATTLE_NO_SHEEN,
}

@onready var icon_rect: TextureRect = %Icon
@onready var hp_container: HBoxContainer = %HPContainer
@onready var pwr_container: HBoxContainer = %PWRContainer
@onready var burn_container: HBoxContainer = %BurnContainer
@onready var hp_label: Label = %HPLabel
@onready var pwr_label: Label = %PWRLabel
@onready var burn_label: Label = %BurnLabel
@onready var armor_container: HBoxContainer = %ArmorContainer
@onready var armor_label: Label = %ArmorLabel
@onready var equipped_item_icon_rect: TextureRect = %EquippedItemIcon
@onready var level_label: Label = %LevelLabel

var _location: LocationIdentifier
var _instance_uuid: String
var _is_selected: bool = false
var _is_inspectable: bool = true
var _is_interactive: bool = true
var definition_id: StringName = &""
var is_enemy: bool = false

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
var _visual_spikes_stacks: int = 0 # Spikes stacks - deals damage back to attacker
var _visual_status_effects: Dictionary = {} # Generic: status_id -> stacks
var _status_icon_nodes: Dictionary = {} # Dynamic icon nodes: status_id -> TextureRect
var _visual_equipped_items: Array = [] # Equipped item data: [{uuid, icon, definition_id}]
var _visual_equipped_item_icon: Texture2D = null
var _visual_level: int = 1
var _visual_tier: int = 1
var _bound_uuid: String = "" # UUID bound during populate()
var _size_scale: float = BATTLE_SCALE # Default to 2x for battle context

var _is_trait_trinket: bool = false
var _trait_name: String = ""
var _last_soul_count: int = -1
var _last_trait_level: int = -1
var _default_material: Material = null

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
var _anim_controller: UnitAnimationController = null

# Hover animation state
var _hover_tween: Tween = null
var _press_tween: Tween = null
var _hover_amount: float = 0.0
var _press_amount: float = 0.0
var _is_hovered: bool = false
var _base_z_index: int = 0
var _slot_view_ref: Control = null
var _slot_base_z_index: int = 0
var _touch_long_press_timer: Timer = null
var _touch_press_active: bool = false
var _touch_long_press_triggered: bool = false
var _touch_hover_override_active: bool = false
var _touch_press_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("gachaball_view")
	_base_z_index = z_index
	_slot_view_ref = get_parent() as Control
	if is_instance_valid(_slot_view_ref):
		_slot_base_z_index = _slot_view_ref.z_index
		_slot_view_ref.clip_contents = false
	# StatsContainer (Top) is already correctly positioned in the scene file
	# BottomStatsContainer is likewise correctly positioned below the icon
	# IMPORTANT: Duplicate the shader material so each instance has its own
	# Otherwise all GachaBallViews would share the same material and selection state
	if icon_rect and icon_rect.material:
		icon_rect.material = icon_rect.material.duplicate()
		_default_material = icon_rect.material

	_anim_controller = get_node_or_null("AnimationController")

	
	var bus = get_node("/root/SignalBus")
	if is_instance_valid(bus):
		bus.connect("view_selected", _on_view_selected)
		bus.connect("view_deselected", _on_view_deselected)
		# Safety fallback: ensure visual state matches global selection truth
		if bus.has_signal("selection_changed"):
			bus.connect("selection_changed", _on_selection_changed)
		bus.connect("inventory_action_completed", _on_inventory_action_completed)
		
		# unit_visual_stat_update is still handled here for puppet mode updates 
		if bus.has_signal("unit_visual_stat_update"):
			if not bus.is_connected("unit_visual_stat_update", _on_unit_visual_stat_update):
				bus.connect("unit_visual_stat_update", _on_unit_visual_stat_update)
			
		if bus.has_signal("drag_ended"):
			if not bus.is_connected("drag_ended", _on_drag_ended):
				bus.drag_ended.connect(_on_drag_ended)
				
		if bus.has_signal("battle_inventory_changed"):
			if not bus.is_connected("battle_inventory_changed", _on_battle_inventory_changed):
				bus.connect("battle_inventory_changed", _on_battle_inventory_changed)
		# NOTE: Animation signals (flash, bump, death, summon, melee, lethal_save)
	
	# Connect click handlers for status effect icons (burn/armor)
	_setup_status_effect_click_handlers()
		# are now handled by UnitAnimationController child node

	# Hover-to-Inspect (PC only): emit HOVER events for GIR
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	

	_touch_long_press_timer = Timer.new()
	_touch_long_press_timer.one_shot = true
	_touch_long_press_timer.wait_time = InputUtils.TOUCH_LONG_PRESS_SEC
	_touch_long_press_timer.timeout.connect(_on_touch_long_press_timeout)
	add_child(_touch_long_press_timer)



func _process(delta: float) -> void:
	if _needs_hover_visual_update():
		_update_hover_animation(delta)
	_update_drag_deformation(delta)

func _needs_hover_visual_update() -> bool:
	if _get_hover_fx_mode() != HoverFxMode.OFF:
		return true
	if _is_hovered:
		return true
	if _hover_amount > 0.001 or _press_amount > 0.001:
		return true
	if absf(rotation) > 0.001:
		return true
	return false

func _update_drag_deformation(delta: float) -> void:
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
	_stop_touch_long_press()
	_touch_hover_override_active = false
	_is_hovered = false
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_set_hover_amount(0.0)
	_set_press_amount(0.0)
	z_index = _base_z_index
	if is_instance_valid(_slot_view_ref):
		_slot_view_ref.z_index = _slot_base_z_index
	scale = Vector2.ONE
	rotation = 0.0
	_apply_inventory_brightness(HoverFxMode.OFF)

	# Reset drag deformation state if still dragging
	_reset_drag_deformation()
	
	# Proactively disconnect signals and end any active drag to prevent leaks
	var bus = get_node_or_null("/root/SignalBus")
	if is_instance_valid(bus):
		if bus.is_connected("view_selected", _on_view_selected):
			bus.disconnect("view_selected", _on_view_selected)
		if bus.is_connected("view_deselected", _on_view_deselected):
			bus.disconnect("view_deselected", _on_view_deselected)
		if bus.is_connected("selection_changed", _on_selection_changed):
			bus.disconnect("selection_changed", _on_selection_changed)
	# NOTE: Animation signals are handled by UnitAnimationController child node

	# Disconnect hover signals
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)

	if is_instance_valid(bus):
		if bus.is_connected("battle_inventory_changed", _on_battle_inventory_changed):
			bus.disconnect("battle_inventory_changed", _on_battle_inventory_changed)

	# If this view is being freed during a drag, centrally end the drag ONLY if it is the source
	if GlobalInteractionRouter.is_drag_active():
		var source_view = GlobalInteractionRouter.get_drag_source_view()
		if is_instance_valid(source_view) and source_view == self:
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

func populate(loc: LocationIdentifier, visual_data: Dictionary, is_inspectable: bool = true) -> void:
	self._location = loc
	self._instance_uuid = visual_data.get("uuid", "")
	self._bound_uuid = visual_data.get("uuid", "")
	self._is_inspectable = is_inspectable
	definition_id = StringName(visual_data.get("definition_id", visual_data.get("def_id", &"")))
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_stop_touch_long_press()
	_touch_hover_override_active = false
	_is_selected = false
	_is_hovered = false
	_set_hover_amount(0.0)
	_set_press_amount(0.0)
	z_index = _base_z_index
	if is_instance_valid(_slot_view_ref):
		_slot_view_ref.z_index = _slot_base_z_index
	scale = Vector2.ONE
	rotation = 0.0
	modulate.a = 1.0
	_apply_inventory_brightness(HoverFxMode.OFF)
	var selection_ring = get_node_or_null("SelectionRing")
	if selection_ring:
		selection_ring.visible = false
	set_meta("location_identifier", loc) # For InteractionManager and WindowManager

	if visual_data.is_empty():
		definition_id = &""
		_entity_type = &""
		_update_view_groups()
		visible = false
		return
	
	# Set entity type based on definition category
	var category = visual_data.get("category", "UNIT")
	_entity_type = StringName(category)
	_update_view_groups()
	
	_is_trait_trinket = String(definition_id).begins_with("trinket_trait_")
	if _is_trait_trinket:
		var parts = String(definition_id).split("_")
		if parts.size() >= 3:
			_trait_name = parts[2].to_upper()
	else:
		_trait_name = ""
		_last_soul_count = -1
		_last_trait_level = -1
	
	# Initialize visual state
	_visual_hp = visual_data.get("hp", 0)
	_visual_pwr = visual_data.get("pwr", 0)
	_visual_burn_stacks = visual_data.get("burn_stacks", 0) # Renamed from poison_stacks
	_visual_armor_stacks = visual_data.get("armor_stacks", 0) # Same pattern as burn
	_visual_spikes_stacks = visual_data.get("spikes_stacks", 0) # Spikes status effect
	
	# Clear and synchronize all status effects from visual_data
	_visual_status_effects.clear()
	var raw_effects = visual_data.get("status_effects", {})
	for status_id in raw_effects:
		_visual_status_effects[StringName(status_id)] = int(raw_effects[status_id])
	# Always sync spikes explicitly to match _visual_spikes_stacks
	_visual_status_effects[&"spikes"] = _visual_spikes_stacks
	
	_visual_equipped_items = visual_data.get("equipped_items", []) # Array of {uuid, icon, definition_id}
	_visual_equipped_item_icon = visual_data.get("equipped_item_icon")
	
	var attributes = visual_data.get("attributes", {})
	_visual_level = str(attributes.get(&"level", 1)).to_int()
	_visual_tier = str(attributes.get(&"tier", visual_data.get("tier", 1))).to_int()
	
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
			
			var base_size = Vector2(C.UNIT_SPRITE_SIZE / 2.0, C.UNIT_SPRITE_SIZE / 2.0)
			var target_size = base_size * _size_scale
			
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
				# Battle Mode: Use UnitSprite to enforce 128x128 scale inside 192x192 slot
				icon_rect.custom_minimum_size = target_size # 192x192
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.texture = null # Clear main texture
				
				# Use child sprite for strictly sized unit/item
				var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
				if not unit_sprite:
					unit_sprite = TextureRect.new()
					unit_sprite.name = "UnitSprite"
					icon_rect.add_child(unit_sprite)
					unit_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
					unit_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					unit_sprite.stretch_mode = TextureRect.STRETCH_SCALE
				_match_icon_texture_filter(unit_sprite)
				
				# Configure unit sprite size and position
				unit_sprite.custom_minimum_size = Vector2(C.UNIT_SPRITE_SIZE, C.UNIT_SPRITE_SIZE)
				unit_sprite.size = Vector2(C.UNIT_SPRITE_SIZE, C.UNIT_SPRITE_SIZE)
				# Center in 2x slot
				unit_sprite.position = Vector2(C.SLOT_CENTER_OFFSET, C.SLOT_CENTER_OFFSET)
				unit_sprite.texture = visual_data.get("icon")
				unit_sprite.visible = true
				# CRITICAL: Copy shader material so flash effects work on visible sprite
				if icon_rect.material:
					unit_sprite.material = icon_rect.material.duplicate()
				
				# Setup Battle Layout (Underlay)
				_setup_battle_stats_layout()
			elif _has_overlay_heuristic():
				# Inventory Mode: Fixed slot size based on scale, Unit centered inside
				# Ensure Overlay Layout
				_setup_overlay_stats_layout()
				var current_slot_size = C.SLOT_SIZE_BASE * _size_scale
				var current_unit_size = (C.UNIT_SPRITE_SIZE / 2.0) * _size_scale
				
				icon_rect.custom_minimum_size = Vector2(current_slot_size, current_slot_size)
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
				_match_icon_texture_filter(unit_sprite)
				
				# Configure unit sprite size and position (no anchor preset, direct positioning)
				unit_sprite.custom_minimum_size = Vector2(current_unit_size, current_unit_size)
				unit_sprite.size = Vector2(current_unit_size, current_unit_size)
				var offset = (current_slot_size - current_unit_size) / 2.0
				unit_sprite.position = Vector2(offset, offset)
				unit_sprite.texture = visual_data.get("icon")
				unit_sprite.visible = true
				# CRITICAL: Copy shader material so flash effects work on visible sprite
				if icon_rect.material:
					unit_sprite.material = icon_rect.material.duplicate()
			else:
				# Compact Mode: Native size (1x scale) for TopArea trinkets
				# Ensure Layout (Compact uses overlay usually? or nothing? Assuming overlay/hidden)
				_setup_overlay_stats_layout()
				# Use native texture size and center in the slot
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.custom_minimum_size = target_size
				
				# Remove unit sprite if present (not needed in compact mode)
				var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
				if unit_sprite: unit_sprite.queue_free()
		else:
			# Fallback for missing textures
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Ensure cleanup if switching contexts (unlikely but safe)
			var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
			if unit_sprite: unit_sprite.queue_free()
	
	_update_stats()
	_update_dynamic_status_icons(false) # explicit: do not animate on populate
	
	# Apply visual layers from component system (replaces legacy variant_id check)
	var visual_layers = visual_data.get("visual_layers", [])
	_apply_visual_layers(visual_layers)
	
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
	_apply_inventory_brightness(HoverFxMode.OFF)
	
	_update_trait_trinket_visuals(false)

func _on_battle_inventory_changed() -> void:
	_update_trait_trinket_visuals(true)

func _update_trait_trinket_visuals(animate_if_changed: bool) -> void:
	var trait_label = get_node_or_null("%TraitCountLabel")
	
	if not _is_trait_trinket:
		if trait_label:
			trait_label.visible = false
		return
		
	# Traits only calculate properly in battle
	if not GameManager.is_in_battle:
		if trait_label:
			trait_label.text = "0"
			trait_label.visible = true
		return
		
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not is_instance_valid(bm): 
		return
		
	var is_enemy_team = is_enemy or (is_instance_valid(_location) and _location.container == &"EnemyTrinkets")
	var team = "ENEMY" if is_enemy_team else "PLAYER"
	var active_traits = bm.get_active_traits(team)
	var current_souls = active_traits.get(_trait_name, 0)
	
	if trait_label:
		trait_label.text = str(current_souls)
		trait_label.visible = true
	
	# Determine level
	var level = 0
	var trait_def = C.TRAIT_DEFINITIONS.get(_trait_name, {})
	var levels = trait_def.get("levels", [])
	for i in range(levels.size()):
		if current_souls >= levels[i]["min"]:
			level = i + 1
			
	if animate_if_changed and level != _last_trait_level:
		var bus = get_node_or_null("/root/SignalBus")
		if is_instance_valid(bus) and bus.has_signal("trait_threshold_reached"):
			bus.emit_signal("trait_threshold_reached", _instance_uuid, definition_id, is_enemy)
		
	_last_trait_level = level
	_last_soul_count = current_souls
	
	# Set outline color
	var outline_mat = null
	if icon_rect and icon_rect.material:
		outline_mat = icon_rect.material as ShaderMaterial
		
	var unit_sprite = icon_rect.get_node_or_null("UnitSprite") if icon_rect else null
	var unit_sprite_mat = unit_sprite.material as ShaderMaterial if unit_sprite and unit_sprite.material else null
		
	if level > 0:
		var colors = [
			Color(0.8, 0.5, 0.2), # Bronze
			Color(0.75, 0.75, 0.75), # Silver
			Color(1.0, 0.84, 0.0), # Gold
			Color(0.5, 1.0, 1.0) # Prismatic/Cyan
		]
		var color_idx = min(level - 1, colors.size() - 1)
		var outline_color = colors[color_idx]
		
		if outline_mat:
			outline_mat.set_shader_parameter("outline_enabled", true)
			outline_mat.set_shader_parameter("outline_color", outline_color)
			outline_mat.set_shader_parameter("outline_width", 18.0)
		if unit_sprite_mat:
			unit_sprite_mat.set_shader_parameter("outline_enabled", true)
			unit_sprite_mat.set_shader_parameter("outline_color", outline_color)
			unit_sprite_mat.set_shader_parameter("outline_width", 18.0)
	else:
		if outline_mat:
			outline_mat.set_shader_parameter("outline_enabled", false)
		if unit_sprite_mat:
			unit_sprite_mat.set_shader_parameter("outline_enabled", false)


func update_visuals(visual_data: Dictionary) -> void:
	if visual_data.is_empty() or visual_data.get("uuid") != _instance_uuid:
		return
		
	_visual_hp = visual_data.get("hp", 0)
	_visual_pwr = visual_data.get("pwr", 0)
	_visual_burn_stacks = visual_data.get("burn_stacks", 0) # Renamed from poison_stacks
	_visual_armor_stacks = visual_data.get("armor_stacks", 0) # Same pattern as burn
	_visual_spikes_stacks = visual_data.get("spikes_stacks", 0) # Spikes status effect
	
	# Clear and synchronize all status effects from visual_data
	_visual_status_effects.clear()
	var raw_effects = visual_data.get("status_effects", {})
	for status_id in raw_effects:
		_visual_status_effects[StringName(status_id)] = int(raw_effects[status_id])
	# Always sync spikes explicitly to match _visual_spikes_stacks
	_visual_status_effects[&"spikes"] = _visual_spikes_stacks
	
	_visual_equipped_items = visual_data.get("equipped_items", _visual_equipped_items)
	_visual_equipped_item_icon = visual_data.get("equipped_item_icon", _visual_equipped_item_icon)
	
	var attributes = visual_data.get("attributes", {})
	_visual_level = int(attributes.get(&"level", _visual_level))
	_visual_tier = int(attributes.get(&"tier", visual_data.get("tier", _visual_tier)))
	_update_stats()
	_update_dynamic_status_icons(false) # explicit: do not animate on hard refresh
	_update_item_slots()
	# Re-apply visual layers on refresh (e.g. mid-battle prismatic change)
	var refresh_layers = visual_data.get("visual_layers", [])
	_apply_visual_layers(refresh_layers)

## Apply visual component layers (shader effects, modulate) from the component system.
## This replaces the legacy variant_id == "prismatic" check.
func _apply_visual_layers(layers: Array) -> void:
	if not is_instance_valid(icon_rect):
		return

	var unit_sprite = icon_rect.get_node_or_null("UnitSprite")

	if layers.is_empty():
		# No visual layers — reset to clean state (important for recycled UI slots)
		icon_rect.material = _default_material
		icon_rect.modulate = Color.WHITE
		if unit_sprite:
			unit_sprite.material = _default_material
		return

	# Apply the first shader layer found (currently only one shader layer is expected)
	var shader_applied := false
	for layer in layers:
		var shader_res: Shader = layer.get("shader")
		var shader_path: String = layer.get("shader_path", "")
		var shader_params: Dictionary = layer.get("shader_params", {})
		var modulate_color: Color = layer.get("modulate", Color.WHITE)

		# Resolve shader from path if not preloaded
		if not is_instance_valid(shader_res) and not shader_path.is_empty():
			shader_res = load(shader_path)

		if is_instance_valid(shader_res) and not shader_applied:
			var mat = ShaderMaterial.new()
			mat.shader = shader_res
			for param_name in shader_params:
				mat.set_shader_parameter(param_name, shader_params[param_name])
			icon_rect.material = mat
			icon_rect.modulate = modulate_color
			if unit_sprite:
				unit_sprite.material = mat
			shader_applied = true

	if not shader_applied:
		# Layers exist but none had shaders — reset material
		icon_rect.material = _default_material
		icon_rect.modulate = Color.WHITE
		if unit_sprite:
			unit_sprite.material = _default_material

func set_is_enemy(p_is_enemy: bool, _definition_id: StringName = &"") -> void:
	is_enemy = p_is_enemy
	if is_instance_valid(icon_rect):
		if _entity_type == &"TRINKET":
			return
		# All textures face right by default, so flip horizontally for enemy team
		icon_rect.flip_h = p_is_enemy
		
		# Also flip the UnitSprite child if it exists (Battle Mode scaling)
		var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
		if unit_sprite:
			unit_sprite.flip_h = p_is_enemy

func get_definition_id() -> StringName:
	return definition_id

func is_enemy_view() -> bool:
	return is_enemy

func _update_view_groups() -> void:
	if _entity_type == &"TRINKET":
		add_to_group("trinket_view")
	else:
		remove_from_group("trinket_view")

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

func _get_hover_fx_mode() -> int:
	if not _is_inspectable:
		return HoverFxMode.OFF
	if not is_instance_valid(_location):
		return HoverFxMode.OFF
	if InputUtils.prefers_touch_input() and not _touch_hover_override_active:
		return HoverFxMode.OFF

	var context_group = GlobalInteractionRouter.get_context_group(_location.container)
	if context_group == &"InventoryGrid":
		return HoverFxMode.OFF
	if context_group == &"BattleBoard":
		return HoverFxMode.BATTLE_NO_SHEEN
	return HoverFxMode.OFF

func _set_hover_state(active: bool, play_sound: bool = false) -> void:
	if active and _get_hover_fx_mode() == HoverFxMode.OFF:
		active = false
	if _is_hovered == active:
		return
	_is_hovered = active
	_update_hover_draw_priority()

	if active and play_sound:
		Audio.play_sfx("ui_hover", randf_range(1.05, 1.12))

	_animate_hover_to(1.0 if active else 0.0, 0.16 if active else 0.12)
	if not active:
		_animate_press_to(0.0, 0.08)

func _start_touch_long_press(local_pos: Vector2) -> void:
	if not _is_inspectable:
		return
	if not is_instance_valid(_location):
		return
	_touch_press_active = true
	_touch_long_press_triggered = false
	_touch_press_position = local_pos
	if is_instance_valid(_touch_long_press_timer):
		_touch_long_press_timer.start()

func _stop_touch_long_press() -> void:
	_touch_press_active = false
	_touch_long_press_triggered = false
	_touch_press_position = Vector2.ZERO
	if is_instance_valid(_touch_long_press_timer):
		_touch_long_press_timer.stop()

func _emit_hover_enter() -> void:
	if not _is_inspectable:
		return
	if not is_instance_valid(_location):
		return
	var ctx = _create_interaction_context(&"HOVER_ENTER")
	SignalBus.emit_signal("interaction_context_received", ctx)

func _emit_hover_exit() -> void:
	if not is_instance_valid(_location):
		return
	var ctx = _create_interaction_context(&"HOVER_EXIT")
	SignalBus.emit_signal("interaction_context_received", ctx)

func _begin_touch_hover_peek() -> void:
	if _touch_long_press_triggered:
		return
	if not _touch_press_active:
		return
	_touch_long_press_triggered = true
	_touch_hover_override_active = true
	_set_hover_state(true, true)
	_emit_hover_enter()

func _end_touch_hover_peek() -> void:
	if not _touch_hover_override_active:
		return
	_touch_hover_override_active = false
	_set_hover_state(false, false)
	_emit_hover_exit()

func _on_touch_long_press_timeout() -> void:
	_begin_touch_hover_peek()

func _can_begin_drag() -> bool:
	if not _is_interactive:
		return false
	if GlobalInteractionRouter and GlobalInteractionRouter.is_combat_locked():
		return false
	if GlobalInteractionRouter and GlobalInteractionRouter.is_vcr_playing():
		return false
	if is_instance_valid(_location):
		var context_group = GlobalInteractionRouter.get_context_group(_location.container)
		if context_group == &"InspectionOnly":
			return false
	return true

func _begin_touch_drag() -> void:
	var drag_payload := _prepare_drag_payload()
	if drag_payload.is_empty():
		return
	_animate_press_to(0.0, 0.05)
	force_drag(drag_payload["data"], drag_payload["preview"])

func _prepare_drag_payload() -> Dictionary:
	if not _can_begin_drag():
		return {}

	_drag_initiated_for_click = true
	_pressed_pending_click = false
	_stop_touch_long_press()
	_touch_hover_override_active = false

	# --- Drag Deformation: Start tracking ---
	_is_dragging = true
	_drag_first_frame = true
	_last_mouse_pos = get_global_mouse_position()
	_drag_velocity = Vector2.ZERO
	if is_instance_valid(icon_rect):
		_original_icon_scale = icon_rect.scale
		_original_icon_rotation = icon_rect.rotation

	var drag_visual := _build_drag_preview_visual()
	var engine_preview := _build_drag_engine_preview_stub()

	_drag_preview = drag_visual
	_drag_preview.scale = Vector2.ONE
	_drag_preview.pivot_offset = Vector2.ZERO
	_last_mouse_pos = get_global_mouse_position()

	var placeholder = Control.new()
	placeholder.custom_minimum_size = self.size
	get_parent().add_child(placeholder)
	get_parent().move_child(placeholder, get_index())

	GlobalInteractionRouter.start_drag_visuals(self, placeholder)
	GlobalInteractionRouter.set_drag_overlay_preview(drag_visual)
	var origin_ctx = _create_interaction_context(&"DRAG_ORIGIN")
	GlobalInteractionRouter.start_drag(origin_ctx)

	return {
		"data": {"source_loc": _location},
		"preview": engine_preview,
	}

func _build_drag_preview_visual() -> Control:
	var drag_texture: Texture2D = icon_rect.texture
	var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
	if unit_sprite and unit_sprite.texture:
		drag_texture = unit_sprite.texture

	var current_slot_size = float(C.SLOT_SIZE_BASE) * _size_scale
	var preview_size = Vector2(current_slot_size, current_slot_size)
	var container_size = preview_size * 2.0
	var offset = -preview_size / 2.0

	var preview_container = Control.new()
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	preview_container.custom_minimum_size = container_size
	preview_container.size = container_size

	var preview = TextureRect.new()
	preview.texture = drag_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	_match_icon_texture_filter(preview)
	if _has_overlay_heuristic():
		var current_unit_size = (float(C.UNIT_SPRITE_SIZE) / 2.0) * _size_scale
		var unit_size = Vector2(current_unit_size, current_unit_size)
		preview.custom_minimum_size = unit_size
		preview.size = unit_size
		preview.position = offset + (preview_size - unit_size) / 2.0
	else:
		preview.custom_minimum_size = preview_size
		preview.size = preview_size
		preview.position = offset
	preview_container.add_child(preview)

	if _has_overlay_heuristic():
		var overlay_texture = ArtStyleManager.get_themed_texture(load(GACHABALL_OVERLAY_PATH))
		if overlay_texture:
			var overlay_preview = TextureRect.new()
			overlay_preview.texture = overlay_texture
			overlay_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			overlay_preview.stretch_mode = TextureRect.STRETCH_SCALE
			overlay_preview.custom_minimum_size = preview_size
			overlay_preview.size = preview_size
			overlay_preview.position = offset
			preview_container.add_child(overlay_preview)
			preview_container.move_child(overlay_preview, 0)

		if _is_selected and icon_rect.material:
			var drag_mat = icon_rect.material.duplicate() as ShaderMaterial
			drag_mat.set_shader_parameter("outline_enabled", true)
			preview.material = drag_mat
	else:
		if icon_rect.material:
			var drag_mat = icon_rect.material.duplicate() as ShaderMaterial
			drag_mat.set_shader_parameter("outline_enabled", true)
			preview.material = drag_mat

	_set_preview_tree_mouse_ignore(preview_container)
	return preview_container

func _build_drag_engine_preview_stub() -> Control:
	var preview_stub := Control.new()
	preview_stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stub.custom_minimum_size = Vector2.ONE
	preview_stub.size = Vector2.ONE
	preview_stub.modulate.a = 0.0
	return preview_stub

func _set_preview_tree_mouse_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_preview_tree_mouse_ignore(child)

func _animate_hover_to(target: float, duration: float) -> void:
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover_amount, _hover_amount, target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_press_to(target: float, duration: float) -> void:
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_method(_set_press_amount, _press_amount, target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_hover_amount(value: float) -> void:
	_hover_amount = clampf(value, 0.0, 1.0)

func _set_press_amount(value: float) -> void:
	_press_amount = clampf(value, 0.0, 1.0)

func _update_hover_animation(delta: float) -> void:
	var mode: int = _get_hover_fx_mode()
	if _is_dragging or GlobalInteractionRouter.is_drag_active():
		mode = HoverFxMode.OFF

	if mode == HoverFxMode.OFF and _is_hovered:
		_set_hover_state(false, false)

	_apply_hover_visuals(mode)

func _apply_hover_visuals(mode: int) -> void:
	pivot_offset = size / 2.0
	var transform_factor: float = INVENTORY_TRANSFORM_FACTOR if mode == HoverFxMode.INVENTORY_SPHERE else 1.0

	var hover_scale = 1.0 + (HOVER_SCALE * _hover_amount * transform_factor)
	var press_scale = 1.0 - (PRESS_SQUASH * _press_amount * transform_factor)
	var stretch_x = 1.0 + (_press_amount * 0.04 * transform_factor)
	var stretch_y = 1.0 - (_press_amount * 0.06 * transform_factor)
	var final_scale = hover_scale * press_scale
	scale = Vector2(final_scale * stretch_x, final_scale * stretch_y)
	rotation = 0.0

	_apply_inventory_brightness(mode)

func _apply_inventory_brightness(mode: int) -> void:
	var sprite = _get_active_visual_sprite()
	if not is_instance_valid(sprite):
		return

	if mode == HoverFxMode.INVENTORY_SPHERE:
		var effective_hover = _hover_amount
		if _is_selected:
			effective_hover = maxf(effective_hover, 1.0)
			
		var brightness = 1.0 + (INVENTORY_BRIGHTNESS_BOOST * effective_hover)
		sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	else:
		sprite.modulate = Color.WHITE

func _get_active_visual_sprite() -> TextureRect:
	if not is_instance_valid(icon_rect):
		return null

	var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
	if is_instance_valid(unit_sprite) and unit_sprite.visible:
		return unit_sprite

	return icon_rect

func _match_icon_texture_filter(item: CanvasItem) -> void:
	if not is_instance_valid(item):
		return
	if is_instance_valid(icon_rect):
		item.texture_filter = icon_rect.texture_filter

func _update_hover_draw_priority() -> void:
	var raise_priority: bool = _is_hovered and _get_hover_fx_mode() != HoverFxMode.OFF
	# Keep selected inventory balls above neighbors too, so the selection ring is not occluded.
	if _is_selected and _has_overlay_heuristic():
		raise_priority = true
	z_index = HOVER_RAISED_Z_INDEX if raise_priority else _base_z_index
	if is_instance_valid(_slot_view_ref):
		_slot_view_ref.z_index = HOVER_RAISED_SLOT_Z_INDEX if raise_priority else _slot_base_z_index

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
	if snapshot.has("hp") and snapshot["hp"] != null:
		_visual_hp = int(snapshot["hp"])
	if snapshot.has("pwr") and snapshot["pwr"] != null:
		_visual_pwr = int(snapshot["pwr"])
	if snapshot.has("burn_stacks") and snapshot["burn_stacks"] != null: # Renamed from poison_stacks
		_visual_burn_stacks = int(snapshot["burn_stacks"]) # Renamed from poison_stacks
	if snapshot.has("armor_stacks") and snapshot["armor_stacks"] != null: # Added for armor - same pattern as burn
		_visual_armor_stacks = int(snapshot["armor_stacks"])
	if snapshot.has("spikes_stacks") and snapshot["spikes_stacks"] != null: # Added for spikes
		_visual_spikes_stacks = int(snapshot["spikes_stacks"])
	
	# Restore generic status effects (armor, etc.)
	_visual_status_effects.clear()
	if snapshot.has("status_effects"):
		var effects: Dictionary = snapshot["status_effects"]
		for status_id in effects:
			# Skip burn and armor - handled by dedicated systems
			if status_id == &"burn" or status_id == &"armor":
				continue
			_visual_status_effects[StringName(status_id)] = int(effects[status_id])
			
	# Always sync spikes explicitly to match _visual_spikes_stacks
	_visual_status_effects[&"spikes"] = _visual_spikes_stacks
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
			# Initial appearance: scale from zero then pop
			burn_container.scale = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(burn_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func(): 
				_pop_container(burn_container)
				Audio.play_sfx("status_burn", randf_range(0.95, 1.05))
			)
		elif target_stacks > old_stacks:
			# Stacks increased: pop the container
			_pop_container(burn_container)
			Audio.play_sfx("status_burn", randf_range(0.95, 1.05))
		
		# Always flash label on change
		_flash_label(burn_label)
			
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
			# Initial appearance: scale from zero then pop
			armor_container.scale = Vector2.ZERO
			var tween = create_tween()
			tween.tween_property(armor_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_callback(func():
				_pop_container(armor_container)
				Audio.play_sfx("status_armor", randf_range(0.95, 1.05))
			)
		elif target_stacks > old_stacks:
			# Stacks increased: pop the container
			_pop_container(armor_container)
			Audio.play_sfx("status_armor", randf_range(0.95, 1.05))
		
		# Always flash label on change
		_flash_label(armor_label)
		
		# Tween the number (Counting up/down)
		_animate_number(armor_label, old_stacks, target_stacks)
			
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
func _update_dynamic_status_icons(animate: bool = true) -> void:
	# Get the bottom stats container to add icons to (below the unit)
	var stats_container = get_node_or_null("StatsOverlay/BottomStatsContainer")
	if %StatsUnderlay.visible and %Row2:
		stats_container = %Row2
		
	if not is_instance_valid(stats_container):
		return
	
	# Proactively hide all dynamic status icon nodes to ensure anything no longer active is hidden
	for status_id in _status_icon_nodes:
		var node = _status_icon_nodes[status_id]
		if is_instance_valid(node):
			node.visible = false
	
	# Update or create icons for each active status effect
	for status_id in _visual_status_effects:
		var stacks: int = _visual_status_effects[status_id]
		
		# Skip burn and armor - handled by dedicated systems
		if status_id == &"burn" or status_id == &"armor":
			continue
		
		if stacks > 0:
			# Create icon if doesn't exist
			if not _status_icon_nodes.has(status_id):
				_create_status_icon(status_id, stats_container, animate)
			
			# Update label and ensure visible
			var icon_node = _status_icon_nodes.get(status_id)
			if is_instance_valid(icon_node):
				icon_node.visible = true
				var label = icon_node.get_node_or_null("Label")
				if is_instance_valid(label):
					# Tween the status number (counting up)
					# CRITICAL: We just updated _visual_status_effects[status_id] to the NEW value
					# So querying it gets the NEW value. We must use the current label text as the visual "old" value.
					var visual_current = label.text.to_int()
					
					if animate and visual_current != stacks:
						_animate_number(label, visual_current, stacks)
						# Add visual feedback
						if stacks > visual_current:
							_pop_container(icon_node)
							if status_id == &"spikes":
								Audio.play_sfx("status_spikes", randf_range(0.95, 1.05))
						_flash_label(label)
					else:
						label.text = str(stacks)

## Create a dynamic status icon for a status effect
func _create_status_icon(status_id: StringName, parent: Node, animate: bool = true) -> void:
	# Get definition from registry
	var status_def = StatusEffectRegistry.get_definition(status_id)
	if not is_instance_valid(status_def):
		return
	
	# Unified Scaling Math
	# Battle (2.0 scale): Icon=32, Font=32, Outline=8
	# Window (1.0 scale): Icon=24, Font=14, Outline=4
	var container_size = 8.0 * _size_scale + 16.0
	var font_size = int(18.0 * _size_scale - 4.0)
	var outline_size = int(4.0 * _size_scale)
	
	# Create HBoxContainer for Icon + Label
	var hbox = HBoxContainer.new()
	hbox.name = str(status_id) + "Container"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	
	# Apply plastic pill background
	_apply_plastic_pill_style(hbox)
	
	# Create TextureRect for icon
	var status_icon_rect = TextureRect.new()
	status_icon_rect.name = "Icon"
	status_icon_rect.custom_minimum_size = Vector2(container_size, container_size)
	status_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon_rect.texture = status_def.icon
	
	# Create label for stack count
	var label = Label.new()
	label.name = "Label"
	label.layout_mode = 2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	
	hbox.add_child(status_icon_rect)
	hbox.add_child(label)
	parent.add_child(hbox)
	
	# Store reference
	_status_icon_nodes[status_id] = hbox
	
	# Animate in
	hbox.scale = Vector2.ONE # default
	if animate:
		hbox.scale = Vector2.ZERO # Start scaled down for animation
		var tween = create_tween()
		tween.tween_property(hbox, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Animate a status effect change (for non-burn effects)
func animate_status_change(status_id: StringName, new_stacks: int) -> void:
	var old_stacks = _visual_status_effects.get(status_id, 0)
	_visual_status_effects[status_id] = new_stacks
	_update_dynamic_status_icons()
	
	if new_stacks > old_stacks:
		var icon_node = _status_icon_nodes.get(status_id)
		if is_instance_valid(icon_node):
			_pop_container(icon_node)

func animate_stat_change(target_val: int, _delta: int, type: String) -> void:
	# type: "hp" or "pwr"
	var label = hp_label if type == "hp" else pwr_label
	var container = hp_container if type == "hp" else pwr_container
	var start_val = _visual_hp if type == "hp" else _visual_pwr
	
	# Update internal visual state immediately so subsequent calls are correct
	if type == "hp": _visual_hp = target_val
	else: _visual_pwr = target_val
	
	# If value increased (buff), pop the container like tokens/gold
	if target_val > start_val:
		_pop_container(container)
	
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

## Pop animation for stat containers - scales up then bounces back (like token/gold)
## Includes color flash just like the token counter animation
func _pop_container(container: Control) -> void:
	if not is_instance_valid(container):
		return
	
	# Kill any existing pop tween on this container
	if container.has_meta("_pop_tween"):
		var existing = container.get_meta("_pop_tween")
		if existing is Tween and existing.is_valid():
			existing.kill()
	
	# Set pivot to center for proper scaling
	# Set pivot to center for proper scaling
	# Since HBoxContainers may have zero size before first draw, ensure we use a fallback
	if container.size == Vector2.ZERO:
		container.pivot_offset = container.custom_minimum_size / 2
	else:
		container.pivot_offset = container.size / 2
	
	# Create pop tween (same pattern as token/gold: scale 2.0x then elastic back + color flash)
	var pop_tween = create_tween()
	container.set_meta("_pop_tween", pop_tween)
	
	# Flash color - bright gold like tokens
	var flash_color = Color(1.0, 0.9, 0.2, 1.0) # Same bright gold as token counter
	
	pop_tween.set_parallel(true)
	
	# Scale: pop big then bounce back (1.4x like token counter)
	pop_tween.tween_property(container, "scale", Vector2(1.4, 1.4), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Color flash - modulate the container (icon + label together)
	pop_tween.tween_property(container, "modulate", flash_color, 0.05)
	pop_tween.tween_property(container, "modulate", Color.WHITE, 0.2).set_delay(0.05)

func _update_item_slots() -> void:
	_update_level_display()
	_update_equipped_item_icon()

## Setup click handlers for status effect icons (burn/armor)
## Opens a tooltip window when clicked
func _setup_status_effect_click_handlers() -> void:
	# Ensure burn container is clickable
	if is_instance_valid(burn_container):
		burn_container.mouse_filter = Control.MOUSE_FILTER_STOP
		burn_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not burn_container.is_connected("gui_input", _on_burn_container_clicked):
			burn_container.gui_input.connect(_on_burn_container_clicked)
	
	# Ensure armor container is clickable
	if is_instance_valid(armor_container):
		armor_container.mouse_filter = Control.MOUSE_FILTER_STOP
		armor_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not armor_container.is_connected("gui_input", _on_armor_container_clicked):
			armor_container.gui_input.connect(_on_armor_container_clicked)

## Handle click on burn container to show status effect tooltip
func _on_burn_container_clicked(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		_open_status_effect_tooltip(&"burn", burn_container)
		get_viewport().set_input_as_handled()

## Handle click on armor container to show status effect tooltip
func _on_armor_container_clicked(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		_open_status_effect_tooltip(&"armor", armor_container)
		get_viewport().set_input_as_handled()

## Open a tooltip window for a status effect
func _open_status_effect_tooltip(status_id: StringName, anchor: Control) -> void:
	var status_def = StatusEffectRegistry.get_definition(status_id)
	if not is_instance_valid(status_def):
		return
	
	# Create a context dictionary matching EffectInspectionWindow expectations
	var effect_context = {
		"name_key": status_def.display_name_key,
		"description_key": status_def.description_key
	}
	
	var populate_ctx = {
		"effect_definition": [effect_context],
		"source_view": anchor
	}
	
	WindowManager.open_child_contextual_window(&"EffectInspection", anchor, populate_ctx)

func set_visual_equipped_item_icon(texture: Texture2D) -> void:
	_visual_equipped_item_icon = texture
	_update_equipped_item_icon()

## Update the equipped items display showing icons on the left side (behind the unit)
func _update_equipped_item_icon() -> void:
	if not is_instance_valid(equipped_item_icon_rect):
		return
	if _entity_type != &"UNIT" or not is_instance_valid(_visual_equipped_item_icon):
		equipped_item_icon_rect.texture = null
		equipped_item_icon_rect.visible = false
		return
	equipped_item_icon_rect.texture = _visual_equipped_item_icon
	equipped_item_icon_rect.visible = true

func _update_level_display() -> void:
	if not is_instance_valid(level_label):
		return
	if _entity_type != &"UNIT":
		level_label.visible = false
		return
	_apply_level_label_style()
	level_label.text = "LV. %d" % maxi(_visual_level, 1)
	level_label.visible = true

func _apply_level_label_style() -> void:
	if not is_instance_valid(level_label):
		return
	if _is_run_inventory_context():
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_constant_override("outline_size", 2)
		level_label.offset_left = -40.0
		level_label.offset_top = 5.0
		level_label.offset_right = -4.0
		level_label.offset_bottom = 20.0
	else:
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.add_theme_constant_override("outline_size", 3)
		level_label.offset_left = -54.0
		level_label.offset_top = 6.0
		level_label.offset_right = -6.0
		level_label.offset_bottom = 24.0

## Handle click on an equipped item icon
func _on_equipped_item_clicked(event: InputEvent, anchor: Control, item_uuid: String) -> void:
	if InputUtils.is_primary_pointer_press(event):
		# Find the item instance and open its inspection window
		var all_instances = _get_all_instances_db()
		if all_instances.has(item_uuid):
			var item_instance = all_instances[item_uuid]
			var item_loc = LocationIdentifier.new()
			item_loc.container = C.CONTAINER_EQUIPPED_ITEM
			item_loc.unit_uuid = _instance_uuid
			
			var populate_ctx = {
				"source_view": anchor,
				"instance": item_instance,
				"location": item_loc
			}
			
			WindowManager.open_child_contextual_window(&"ItemInspection", anchor, populate_ctx)
		get_viewport().set_input_as_handled()

## Get all instances database from the appropriate game state
func _get_all_instances_db() -> Dictionary:
	# Try BattleManager first (during battle)
	var battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(battle_manager) and battle_manager.has_method("get_all_instances"):
		return battle_manager.get_all_instances()
	
	# Fall back to RunState (outside battle)
	var game_manager = get_node_or_null("/root/GameManager")
	if is_instance_valid(game_manager) and "run_state" in game_manager and is_instance_valid(game_manager.run_state):
		return game_manager.run_state.run_instances
	
	return {}

## Create gachaball overlay for inventory windows
## Match the physics inventory composition: capsule behind the unit sprite.
func _create_gachaball_overlay() -> void:
	if not is_instance_valid(icon_rect):
		return
	
	# Check if overlay already exists (prevent duplication on repopulate)
	var existing_overlay = get_node_or_null("GachaBallOverlay") as Sprite2D
	if is_instance_valid(existing_overlay):
		return
	
	# Load the overlay texture
	var overlay_texture: Texture2D = ArtStyleManager.get_themed_texture(load(GACHABALL_OVERLAY_PATH))
	if not is_instance_valid(overlay_texture):
		return
	
	# Use Sprite2D so the run inventory capsule is rendered the same way as PhysicsGachaBall.
	var overlay = Sprite2D.new()
	overlay.name = "GachaBallOverlay"
	overlay.texture = overlay_texture
	var current_slot_size = float(C.SLOT_SIZE_BASE) * _size_scale
	var overlay_size: float = current_slot_size - (INVENTORY_OVERLAY_INSET_PX * 2.0 * _size_scale)
	var overlay_texture_size: Vector2 = overlay_texture.get_size()
	var base_scale: Vector2 = Vector2(
		overlay_size / maxf(overlay_texture_size.x, 1.0),
		overlay_size / maxf(overlay_texture_size.y, 1.0)
	)
	overlay.centered = true
	overlay.position = Vector2(current_slot_size / 2.0, current_slot_size / 2.0)
	overlay.scale = base_scale
	overlay.set_meta("base_scale", base_scale)
	
	# Add as a sibling behind VBox so the capsule matches PhysicsGachaBall:
	# capsule under the icon/unit, selection ring above it.
	add_child(overlay)
	move_child(overlay, 1)
	
	# Ensure clipping is disabled so glow can spill outside the bounding box
	clip_contents = false
	if get_parent() is Control:
		get_parent().clip_contents = false



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
	
	# ARCHITECTURE: Puppet Mode Guard
	# If BattleManager is playing a VCR sequence, we MUST ignore "Truth" signals.
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.has_method("is_processing_effect") and bm.is_processing_effect():
		return
	
	# Update ONLY the specific stat that changed
	match stat_name:
		&"hp":
			animate_stat_change(new_value, new_value - _visual_hp, "hp")
		&"pwr":
			animate_stat_change(new_value, new_value - _visual_pwr, "pwr")
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

# ---------------------------------------------------------------------------
# Hover-to-Inspect (PC Only)
# ---------------------------------------------------------------------------

func _on_mouse_entered() -> void:
	# Drag guard: never emit hover during ANY drag (self or global)
	if _is_dragging: return
	if GlobalInteractionRouter.is_drag_active(): return
	_set_hover_state(true, true)
	if not _is_inspectable: return
	if not is_instance_valid(_location): return
	# Touch guard: only emit on desktop
	if InputUtils.prefers_touch_input(): return
	_emit_hover_enter()

func _on_mouse_exited() -> void:
	_set_hover_state(false, false)
	if not is_instance_valid(_location): return
	if InputUtils.prefers_touch_input(): return
	# Drag guard: never emit hover during ANY drag (self or global)
	if _is_dragging: return
	if GlobalInteractionRouter.is_drag_active(): return
	_emit_hover_exit()

func _has_point(point: Vector2) -> bool:
	var radius = size.x / 2.0
	var center = Vector2(radius, size.y / 2.0)
	return point.distance_to(center) <= radius

func _gui_input(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_motion(event):
		var pointer_pos = InputUtils.get_event_position(event)
		if event is InputEventScreenDrag and _touch_press_active and not _touch_long_press_triggered:
			if pointer_pos.distance_to(_touch_press_position) > InputUtils.TOUCH_DRAG_THRESHOLD_PX:
				_stop_touch_long_press()
				_pressed_pending_click = false
				if not _drag_initiated_for_click:
					_begin_touch_drag()
					get_viewport().set_input_as_handled()
					accept_event()
					return
			get_viewport().set_input_as_handled()
			accept_event()
			return

	# Ignore input entirely if we don't have a location (e.g. visual-only balls in RestSite)
	# This allows the click to bubble up to the Rest Site's prize slot gui_input handler
	if not is_instance_valid(_location):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_animate_press_to(1.0, 0.05)
			get_viewport().set_input_as_handled()
			accept_event()
			_pressed_pending_click = true
			_drag_initiated_for_click = false
			_start_touch_long_press(event.position)
		else:
			_animate_press_to(0.0, 0.14)
			var long_press_was_triggered := _touch_long_press_triggered
			_stop_touch_long_press()
			if long_press_was_triggered:
				_end_touch_hover_peek()
			elif _pressed_pending_click and not _drag_initiated_for_click:
				var sc_ctx = _create_interaction_context(&"SINGLE_CLICK")
				SignalBus.emit_signal("interaction_context_received", sc_ctx)
			_pressed_pending_click = false
			_drag_initiated_for_click = false
			get_viewport().set_input_as_handled()
			accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if InputUtils.should_ignore_mouse_pointer_event(event):
			return
		# DOUBLE_CLICK is no longer needed — hover replaces inspect, click locks
		if event.is_pressed():
			_animate_press_to(1.0, 0.05)
			if not _is_hovered:
				_set_hover_state(true, false)
			# Defer single-click to release; may become a drag
			get_viewport().set_input_as_handled()
			_pressed_pending_click = true
		else:
			_animate_press_to(0.0, 0.14)
			# On release: only emit SINGLE_CLICK if no drag was initiated
			if _pressed_pending_click and not _drag_initiated_for_click:
				var sc_ctx = _create_interaction_context(&"SINGLE_CLICK")
				SignalBus.emit_signal("interaction_context_received", sc_ctx)
			if not get_global_rect().has_point(get_global_mouse_position()):
				_set_hover_state(false, false)
			# Reset flags regardless
			_pressed_pending_click = false
			_drag_initiated_for_click = false
			get_viewport().set_input_as_handled()


func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_payload := _prepare_drag_payload()
	if drag_payload.is_empty():
		return null
	# We omit calling set_drag_preview() here because we use a custom
	# drag overlay layer in GlobalInteractionRouter. 
	# Passing an engine preview stub often causes a harmless but annoying 
	# Godot Engine C++ error: "Don't free the control set as drag preview"
	return drag_payload["data"]

func _can_drop_data(_at_position, data) -> bool:
	# TDD 4.3.III.5: Prevent dropping in Inspection-Only contexts
	if is_instance_valid(_location):
		var context_group = GlobalInteractionRouter.get_context_group(_location.container)
		if context_group == &"InspectionOnly":
			# EXCEPTION: Allow Consumables to be used on InspectionOnly targets (e.g. Enemies)
			var allowed = false
			if data is Dictionary and data.has("source_loc"):
				var source_instance = GameManager.get_instance_from_location(data.source_loc)
				if is_instance_valid(source_instance):
					var def = source_instance.get_definition()
					if def and def.category == &"CONSUMABLE":
						allowed = true
			
			if not allowed:
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
		if is_instance_valid(_anim_controller):
			_anim_controller.play_selection_bounce()

func _on_view_deselected(view: Control) -> void:
	if view == self:
		_is_selected = false
		_apply_selection_feedback()

## Fail-safe handler for global selection changes
## Ensures this view deselects even if the instance ID lookup failed in GIR
func _on_selection_changed(new_loc: LocationIdentifier) -> void:
	if not _is_selected:
		return
		
	# If selection cleared (null) or changed to a different location, deselect self
	if not is_instance_valid(new_loc) or not _locations_match(new_loc, _location):
		_is_selected = false
		_apply_selection_feedback()

## Helper to compare location identifiers by value
func _locations_match(a: LocationIdentifier, b: LocationIdentifier) -> bool:
	if a == b: return true
	if not is_instance_valid(a) or not is_instance_valid(b): return false
	return a.container == b.container and a.index == b.index and a.unit_uuid == b.unit_uuid

# NOTE: Animation handlers (_on_unit_flash_effect, _on_unit_bump_attack, etc.)
# are now handled by UnitAnimationController child node

func _on_unit_visual_stat_update(uuid: String, stat: String, value: int) -> void:
	if uuid != _instance_uuid:
		return

	# ARCHITECTURE: Puppet Mode Guard
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.has_method("is_processing_effect") and bm.is_processing_effect():
		return
		
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
	_update_hover_draw_priority()

	var overlay = get_node_or_null("GachaBallOverlay")
	var use_inventory_capsule_feedback := is_instance_valid(overlay) and _has_overlay_heuristic()

	if is_instance_valid(_anim_controller):
		_anim_controller.set_selection_outline(_is_selected)

	if use_inventory_capsule_feedback:
		var selection_ring = get_node_or_null("SelectionRing")
		if is_instance_valid(selection_ring):
			selection_ring.queue_free()
		var overlay_base_scale: Vector2 = overlay.get_meta("base_scale", Vector2.ONE)
		overlay.scale = overlay_base_scale * (1.05 if _is_selected else 1.0)
		overlay.modulate = Color(1.3, 1.3, 1.3) if _is_selected else Color.WHITE
	else:
		# Battle mode: Use shader-based outline on icon_rect
		# NOTE: Do NOT modify icon_rect.scale here - it conflicts with animations
		var mat = icon_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("outline_enabled", _is_selected)

func _notification(what: int) -> void:
	# Signal Drag Start to GIR (Critical for State Management)
	if what == NOTIFICATION_DRAG_BEGIN:
		if _drag_initiated_for_click:
			_stop_touch_long_press()
			_touch_hover_override_active = false
			pass
			_set_hover_state(false, false)
			_animate_press_to(0.0, 0.05)
			var context = _create_interaction_context(&"DRAG_START")
			SignalBus.emit_signal("interaction_context_received", context)
			
			# Visuals: Hide self during drag (standard drag behavior)
			# We use modulate instead of visible to keep layout size if needed,
			# but for GridContainers, visible=false is usually better to collapse hole?
			# No, we want the hole to stay. Modulate is safer for layout stability.
			modulate.a = 0.0

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
		
		# Restore visibility ONLY if the drag failed.
		# If it was successful, the state refresh will handle the view's ultimate fate.
		if not combined_success:
			modulate.a = 1.0
		
		# If drag was NOT successful (dropped on nothing OR rejected by logic), bounce back
		if was_dragging_me and not combined_success:
			if GlobalInteractionRouter.is_drag_active():
				GlobalInteractionRouter.end_drag(false)
			
			play_landing_bounce()
		
		# Reset local drag flag
		_drag_initiated_for_click = false
		_animate_press_to(0.0, 0.08)
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
		# Check for inventory, shop, reward, or discard pile parent contexts
		if "InventoryWindow" in p.name: return true
		if "Shop" in p.name: return true
		if "Reward" in p.name: return true
		if "DiscardPile" in p.name: return true
		p = p.get_parent()
	return false

func _is_run_inventory_context() -> bool:
	var p: Node = self
	while p:
		if p.name == "PersistentInventoryWindow":
			return true
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
		play_landing_bounce()

func _reset_drag_deformation() -> void:
	if not _is_dragging: return
	_is_dragging = false
	_drag_velocity = Vector2.ZERO
	_drag_preview = null
	if is_instance_valid(icon_rect):
		icon_rect.scale = _original_icon_scale
		icon_rect.rotation = _original_icon_rotation

func play_trinket_activation_bounce() -> void:
	if not is_instance_valid(icon_rect): return
	
	Audio.play_sfx("unit_hop")
	
	if not visible:
		visible = true
	if is_instance_valid(get_parent()):
		get_parent().visible = true
	
	# Trinkets live inside HBoxContainer layouts — position-based animations
	# (unit_move HOP) get immediately overridden by the container.
	# Always use inline scale tween which is layout-safe.
	if icon_rect.size == Vector2.ZERO:
		await get_tree().process_frame
		if not is_instance_valid(icon_rect): return
		
	icon_rect.pivot_offset = icon_rect.size / 2.0
	var original_scale := icon_rect.scale
	var tween := create_tween()
	tween.tween_property(icon_rect, "scale", Vector2(0.85, 1.15), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_rect, "scale", Vector2(1.1, 0.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_rect, "scale", original_scale, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func play_landing_bounce() -> void:
	if not is_instance_valid(icon_rect): return
	
	# AUDIO HOOK: Play hop sound for all landing bounces
	Audio.play_sfx("unit_hop")
	
	# Force visibility
	if not visible:
		visible = true
	if is_instance_valid(get_parent()):
		get_parent().visible = true
	
	# For battle units with AnimationController, delegate to composable system
	# This uses proper tween management (kill existing, restore state) built into controller
	var controller = get_node_or_null("AnimationController")
	if is_instance_valid(controller) and not _bound_uuid.is_empty():
		SignalBus.emit_signal("unit_deform", _bound_uuid, &"LANDING_BOUNCE")
		return
	
	# For non-battle units (inventory window, shop, reward), use simple inline tween
	# These don't have AnimationController and pivot is center-based
	if icon_rect.size == Vector2.ZERO:
		return # Layout not ready
	
	icon_rect.pivot_offset = icon_rect.size / 2.0
	var original_scale := icon_rect.scale
	
	var tween := create_tween()
	tween.tween_property(icon_rect, "scale", Vector2(1.2, 0.8), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_rect, "scale", Vector2(0.9, 1.15), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon_rect, "scale", Vector2(1.05, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon_rect, "scale", original_scale, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
# ------------------------------------------------------------------
# Layout Helpers

func _setup_battle_stats_layout() -> void:
	if not %StatsUnderlay: return
	
	%StatsOverlay.visible = false
	%StatsUnderlay.visible = true
	
	# Move Main Stats to Row1
	if hp_container.get_parent() != %Row1:
		hp_container.reparent(%Row1)
		pwr_container.reparent(%Row1)
		
	# Apply plastic pill style to main stat containers
	_apply_plastic_pill_style(hp_container)
	_apply_plastic_pill_style(pwr_container)
		
	# Apply bold colored styles for battle
	# Battle (2.0 scale): Icon=32, Font=32, Outline=8
	var standard_font_size = 32
	var standard_outline_size = 8
	var standard_icon_size = Vector2(32, 32)

	hp_label.add_theme_color_override("font_color", Color.RED)
	hp_label.add_theme_color_override("font_outline_color", Color.WHITE)
	hp_label.add_theme_constant_override("outline_size", standard_outline_size)
	hp_label.add_theme_font_size_override("font_size", standard_font_size)
	
	pwr_label.add_theme_color_override("font_color", Color.BLACK)
	pwr_label.add_theme_color_override("font_outline_color", Color.WHITE)
	pwr_label.add_theme_constant_override("outline_size", standard_outline_size)
	pwr_label.add_theme_font_size_override("font_size", standard_font_size)

	# Position much closer to unit base (5px gap)
	# Increased offset slightly to account for thicker font height
	%StatsUnderlay.offset_top = -28
	%StatsUnderlay.offset_bottom = -28
	
	# Standardize all icons
	var hp_icon = %HPIcon
	var pwr_icon = %PWRIcon
	if hp_icon: hp_icon.custom_minimum_size = standard_icon_size
	if pwr_icon: pwr_icon.custom_minimum_size = standard_icon_size

	# Move Secondary Stats to Row2
	if burn_container.get_parent() != %Row2:
		burn_container.reparent(%Row2)
		armor_container.reparent(%Row2)
	
	# Apply plastic pill style to status containers
	_apply_plastic_pill_style(burn_container)
	_apply_plastic_pill_style(armor_container)
	
	burn_container.custom_minimum_size = Vector2.ZERO
	armor_container.custom_minimum_size = Vector2.ZERO
	
	var burn_icon = %BurnIcon
	var armor_icon = %ArmorIcon
	if burn_icon: burn_icon.custom_minimum_size = standard_icon_size
	if armor_icon: armor_icon.custom_minimum_size = standard_icon_size
	
	burn_label.add_theme_color_override("font_color", Color.WHITE)
	burn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	burn_label.add_theme_constant_override("outline_size", standard_outline_size)
	burn_label.add_theme_font_size_override("font_size", standard_font_size)
	burn_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	
	armor_label.add_theme_color_override("font_color", Color.WHITE)
	armor_label.add_theme_color_override("font_outline_color", Color.BLACK)
	armor_label.add_theme_constant_override("outline_size", standard_outline_size)
	armor_label.add_theme_font_size_override("font_size", standard_font_size)
	armor_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))

## Apply a realistic rounded "plastic pill" background to a container
func _apply_plastic_pill_style(container: HBoxContainer) -> void:
	if not is_instance_valid(container): return
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45) # Semi-transparent dark
	
	# Scale aesthetics based on _size_scale
	var radius = int(6.0 * _size_scale) # 12 in battle, 6 in inventory
	var h_margin = int(4.0 * _size_scale)
	var v_margin = int(1.0 * _size_scale)
	
	style.set_corner_radius_all(radius)
	style.content_margin_left = h_margin + 2
	style.content_margin_right = h_margin + 4
	style.content_margin_top = v_margin
	style.content_margin_bottom = v_margin
	
	# Subtle inner glow/border for the plastic look
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_color = Color(1, 1, 1, 0.15) # Barely visible white shine
	
	container.add_theme_stylebox_override("panel", style)
	
	# Update separation for uniform look
	var separation = int(3.0 * _size_scale)
	container.add_theme_constant_override("separation", separation)

func _setup_overlay_stats_layout() -> void:
	if not %StatsOverlay: return
	
	# In overlay/inventory mode, we also want the new styling but scaled
	%StatsUnderlay.visible = false
	%StatsOverlay.visible = true
	
	var top_container = %StatsContainer
	var bottom_container = %BottomStatsContainer
	
	if not top_container or not bottom_container: return
	
	# Unified Scaling Math
	# Battle (2.0 scale): Icon=32, Font=32, Outline=8
	# Window (1.0 scale): Icon=24, Font=14, Outline=4
	var container_size = 8.0 * _size_scale + 16.0
	var font_size = int(18.0 * _size_scale - 4.0)
	var outline_size = int(4.0 * _size_scale)
	
	# Positioning in Overlay: closer to base
	# Slot is SLOT_SIZE_BASE * _size_scale.
	# Unit bottom is (SLOT_SIZE_BASE/2 + UNIT_SPRITE_SIZE/4) * _size_scale = (48+32) * _size_scale = 80 * _size_scale
	# 5px gap -> 85 * _size_scale
	top_container.anchors_preset = Control.PRESET_CENTER_TOP
	top_container.offset_top = 85 * _size_scale
	
	# Move Main Stats back to Top Container and scale
	if hp_container.get_parent() != top_container:
		hp_container.reparent(top_container)
		pwr_container.reparent(top_container)
		
	# Apply plastic pill style
	_apply_plastic_pill_style(hp_container)
	_apply_plastic_pill_style(pwr_container)
	
	hp_container.custom_minimum_size = Vector2.ZERO
	pwr_container.custom_minimum_size = Vector2.ZERO
	
	var hp_icon = %HPIcon
	var pwr_icon = %PWRIcon
	if hp_icon: hp_icon.custom_minimum_size = Vector2(container_size, container_size)
	if pwr_icon: pwr_icon.custom_minimum_size = Vector2(container_size, container_size)
	
	hp_label.add_theme_color_override("font_color", Color.RED)
	hp_label.add_theme_color_override("font_outline_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", font_size)
	hp_label.add_theme_constant_override("outline_size", outline_size)
	hp_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	
	pwr_label.add_theme_color_override("font_color", Color.BLACK)
	pwr_label.add_theme_color_override("font_outline_color", Color.WHITE)
	pwr_label.add_theme_font_size_override("font_size", font_size)
	pwr_label.add_theme_constant_override("outline_size", outline_size)
	pwr_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))

	# Apply to bottom row (Burn, Armor) as well
	burn_label.add_theme_font_size_override("font_size", font_size)
	burn_label.add_theme_constant_override("outline_size", outline_size)
	burn_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	_apply_plastic_pill_style(burn_container)
	
	armor_label.add_theme_font_size_override("font_size", font_size)
	armor_label.add_theme_constant_override("outline_size", outline_size)
	armor_label.add_theme_font_override("font", load("res://assets/fonts/static/NotoSansJP-Black.ttf"))
	_apply_plastic_pill_style(armor_container)

	# Move Secondary Stats back to Bottom Container and scale
	if burn_container.get_parent() != bottom_container:
		burn_container.reparent(bottom_container)
		armor_container.reparent(bottom_container)
	
	# Apply plastic pill style
	_apply_plastic_pill_style(burn_container)
	_apply_plastic_pill_style(armor_container)
	
	burn_container.custom_minimum_size = Vector2.ZERO
	armor_container.custom_minimum_size = Vector2.ZERO
	
	var burn_icon = %BurnIcon
	var armor_icon = %ArmorIcon
	if burn_icon: burn_icon.custom_minimum_size = Vector2(container_size, container_size)
	if armor_icon: armor_icon.custom_minimum_size = Vector2(container_size, container_size)
	
	burn_label.add_theme_font_size_override("font_size", font_size)
	burn_label.add_theme_constant_override("outline_size", outline_size)
	armor_label.add_theme_font_size_override("font_size", font_size)
	armor_label.add_theme_constant_override("outline_size", outline_size)
