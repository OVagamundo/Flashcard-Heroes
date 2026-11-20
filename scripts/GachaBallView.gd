# res://scripts/GachaBallView.gd
class_name GachaBallView
extends PanelContainer

const InputUtils = preload("res://scripts/InputUtils.gd")
const InspectionTrigger = preload("res://scripts/ui/InspectionTrigger.gd")
const SpriteOutline = preload("res://scripts/ui/SpriteOutline.gd")

# Size scale constants for different contexts
const BATTLE_SCALE: float = 2.0 # 2x size for battle scene
const WINDOW_SCALE: float = 1.0 # 1x size for inventory windows and Discard
const LOADOUT_ITEM_SOURCE_SIZE: float = 32.0

# Gachaball overlay texture path for inventory items
const GACHABALL_OVERLAY_PATH = "res://assets/PixelArt/ui/textures/gachaballcapsule.png"
const INCUBATOR_CAPSULE_TINT: Color = Color(1.0, 0.87, 0.42)
const SHADOW_TEXTURE = preload("res://assets/PixelArt/ui/textures/Shadow.png")
const LEVEL_1_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_1_stars.png")
const LEVEL_2_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_2_stars.png")
const LEVEL_3_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_3_stars.png")
const LEVEL_STAR_ICON_SIZE: float = 16.0
const EQUIPPED_ITEM_ICON_SIZE: float = 32.0
const UNIT_CORNER_ICON_INSET: float = 6.0

# Path-choice-style hover motion for selectable gachaballs.
const HOVER_SCALE: float = 0.12
const PRESS_SQUASH: float = 0.10
const INVENTORY_BRIGHTNESS_BOOST: float = 0.18
const INVENTORY_TRANSFORM_FACTOR: float = 0.92
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
@onready var level_stars_rect: TextureRect = %LevelStarsIcon

var _location: LocationIdentifier
var _instance_uuid: String
var _is_selected: bool = false
var _is_inspected: bool = false
var _is_inspectable: bool = true
var _is_interactive: bool = true
var definition_id: StringName = &""
var is_enemy: bool = false

# Recipe unlock highlight constants and state
const RECIPE_LOCKED_OUTLINE_COLOR := Color(0.82, 0.38, 1.0) # Violet / Purple recipe discovery outline
const RECIPE_LOCKED_OUTLINE_WIDTH := 3.0
var _has_locked_recipe: bool = false

# Merge target highlight constants and state
const MERGE_LEVEL_UP_OUTLINE_COLOR := Color(0.0, 0.95, 1.0) # Cyan outline for leveling up
const MERGE_RECIPE_TIER_UP_OUTLINE_COLOR := Color(1.0, 0.1, 0.9) # Magenta outline for recipe tier up / items
const MERGE_TARGET_OUTLINE_WIDTH := 3.0
const EQUIP_TARGET_OUTLINE_COLOR := Color.WHITE # White outline for equipping items to units
const EQUIP_TARGET_OUTLINE_WIDTH := 3.0
var _merge_target_type: StringName = &""

const TRAIT_OUTLINE_COLORS = [
	Color(0.8, 0.5, 0.2), # Bronze
	Color(0.75, 0.75, 0.75), # Silver
	Color(1.0, 0.84, 0.0), # Gold
	Color(0.5, 1.0, 1.0) # Prismatic/Cyan
]
const TRAIT_OUTLINE_WIDTH := 5.0

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
var _hit_test_sprite_texture: Texture2D
var _hit_test_sprite_image: Image

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
var _base_z_index: int = 2
var _slot_view_ref: Control = null
var _slot_base_z_index: int = 0
var _inspection_trigger: InspectionTrigger = null
var _touch_press_active: bool = false
var _touch_press_position: Vector2 = Vector2.ZERO
var _is_landing_bounce_active: bool = false
var _landing_bounce_until_msec: int = 0
var _status_strip: GachaBallStatusStrip = GachaBallStatusStrip.new()
var _drag_controller: GachaBallDragController = GachaBallDragController.new()
var _hover_outline_controller: GachaBallHoverOutlineController = GachaBallHoverOutlineController.new()

func is_landing_bounce_active() -> bool:
	return _is_landing_bounce_active and Time.get_ticks_msec() < _landing_bounce_until_msec

func _on_unit_deform_finished(uuid: String) -> void:
	if uuid == _bound_uuid:
		_is_landing_bounce_active = false
		if _is_hovered and not GlobalInteractionRouter.is_drag_active():
			_animate_hover_to(1.0, 0.16)


func _ready() -> void:
	add_to_group("gachaball_view")
	SignalBus.view_inspection_changed.connect(_on_view_inspection_changed)
	z_as_relative = false
	z_index = 2
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
		bus.selection_changed.connect(_on_selection_changed)
		bus.connect("inventory_action_completed", _on_inventory_action_completed)
		if not bus.unit_deform_finished.is_connected(_on_unit_deform_finished):
			bus.unit_deform_finished.connect(_on_unit_deform_finished)
		if not bus.drag_ended.is_connected(_on_drag_ended):
			bus.drag_ended.connect(_on_drag_ended)
		if not bus.battle_inventory_changed.is_connected(_on_battle_inventory_changed):
			bus.battle_inventory_changed.connect(_on_battle_inventory_changed)

		if not bus.run_data_changed.is_connected(_on_run_data_changed):
			bus.run_data_changed.connect(_on_run_data_changed)

		if not bus.show_merge_target_indicators.is_connected(_on_show_merge_target_indicators):
			bus.show_merge_target_indicators.connect(_on_show_merge_target_indicators)

		if not bus.hide_merge_target_indicators.is_connected(_on_hide_merge_target_indicators):
			bus.hide_merge_target_indicators.connect(_on_hide_merge_target_indicators)
		# NOTE: Animation signals (flash, bump, death, summon, melee, lethal_save)
	
	# Connect click handlers for status effect icons (burn/armor)
	_setup_status_effect_click_handlers()
		# are now handled by UnitAnimationController child node

	_inspection_trigger = InspectionTrigger.new()
	_inspection_trigger.setup(self, func():
		if not _is_inspectable or not is_instance_valid(_location):
			return {}
		return {"location": _location}
	)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)



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
	_drag_controller.update_drag_deformation(self, delta)

func _enter_tree() -> void:
	if is_instance_valid(_location):
		WindowManager.register_location_view(_location, self)

func _exit_tree() -> void:
	WindowManager.unregister_location_view(self)
	SignalBus.view_inspection_changed.disconnect(_on_view_inspection_changed)
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.cancel()
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
		if bus.unit_deform_finished.is_connected(_on_unit_deform_finished):
			bus.unit_deform_finished.disconnect(_on_unit_deform_finished)
	# NOTE: Animation signals are handled by UnitAnimationController child node

	# Disconnect hover signals
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)

	if is_instance_valid(bus):
		if bus.is_connected("battle_inventory_changed", _on_battle_inventory_changed):
			bus.disconnect("battle_inventory_changed", _on_battle_inventory_changed)
		if bus.run_data_changed.is_connected(_on_run_data_changed):
			bus.run_data_changed.disconnect(_on_run_data_changed)
		if bus.show_merge_target_indicators.is_connected(_on_show_merge_target_indicators):
			bus.show_merge_target_indicators.disconnect(_on_show_merge_target_indicators)
		if bus.hide_merge_target_indicators.is_connected(_on_hide_merge_target_indicators):
			bus.hide_merge_target_indicators.disconnect(_on_hide_merge_target_indicators)

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

func get_sprite_global_bounds() -> Rect2:
	var sprite: TextureRect = icon_rect.get_node_or_null("UnitSprite") as TextureRect
	if sprite == null:
		sprite = icon_rect
	return sprite.get_global_transform() * Rect2(Vector2.ZERO, sprite.size)

func has_battle_sprite_at(canvas_position: Vector2) -> bool:
	var sprite: TextureRect = _get_active_visual_sprite()
	var local_position: Vector2 = sprite.get_global_transform().affine_inverse() * canvas_position
	if not Rect2(Vector2.ZERO, sprite.size).has_point(local_position):
		return false
	var texture: Texture2D = sprite.texture
	assert(texture != null, "GachaBallView.has_battle_sprite_at requires a rendered unit sprite")
	if _hit_test_sprite_texture != texture:
		_hit_test_sprite_texture = texture
		_hit_test_sprite_image = texture.get_image()
	var pixel: Vector2i = Vector2i(local_position / sprite.size * Vector2(_hit_test_sprite_image.get_size()))
	if sprite.flip_h:
		pixel.x = _hit_test_sprite_image.get_width() - 1 - pixel.x
	return _hit_test_sprite_image.get_pixelv(pixel).a > 0.0

## Set the size scale for this view (2.0 for battle, 1.0 for windows)
func set_size_scale(size_scale: float) -> void:
	_size_scale = size_scale

## Lay out starter units at deployment scale and items at Shelf capsule scale.
func layout_loadout_preview(art_height: float) -> void:
	if _entity_type == &"TRINKET":
		return

	var sprite: TextureRect = icon_rect.get_node("UnitSprite")
	var source_size: Vector2 = Vector2(sprite.texture.get_size())
	var sprite_scale: float = BATTLE_SCALE
	if _entity_type != &"UNIT":
		# Some Emblem textures are larger than the standard item canvas.
		var item_fit: float = minf(1.0, LOADOUT_ITEM_SOURCE_SIZE / maxf(source_size.x, source_size.y))
		sprite_scale = item_fit * C.SHELF_CAPSULE_SCALE
	var sprite_size: Vector2 = (source_size * sprite_scale).round()
	sprite.custom_minimum_size = Vector2.ZERO
	sprite.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sprite.offset_left = -sprite_size.x * 0.5
	sprite.offset_right = sprite_size.x * 0.5
	sprite.offset_top = (art_height - sprite_size.y) * 0.5
	sprite.offset_bottom = sprite.offset_top + sprite_size.y

	if _entity_type == &"UNIT":
		var stats: HBoxContainer = %StatsContainer
		stats.set_anchors_preset(Control.PRESET_TOP_WIDE)
		stats.offset_left = 0.0
		stats.offset_right = 0.0
		stats.offset_top = art_height
		stats.offset_bottom = art_height

func _is_shelf_capsule() -> bool:
	return not force_inventory_mode and _visual_capsule_sealed and _location != null and _location.container in [&"PlayerShelf", &"EnemyShelf"]

static func shelf_capsule_center(slot_size: Vector2) -> Vector2:
	return Vector2(slot_size.x * 0.5, C.SHELF_SURFACE_Y - C.GACHA_CAPSULE_DIAMETER * C.SHELF_CAPSULE_SCALE * 0.5)

func get_capsule_rect() -> Rect2:
	var capsule_scale: float = C.SHELF_CAPSULE_SCALE if _is_shelf_capsule() else (1.0 if force_inventory_mode else _size_scale)
	var capsule_size: Vector2 = Vector2.ONE * C.GACHA_CAPSULE_DIAMETER * capsule_scale
	var center: Vector2 = shelf_capsule_center(Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X)) if _is_shelf_capsule() else capsule_size * 0.5
	return Rect2(center - capsule_size * 0.5, capsule_size)

func populate(loc: LocationIdentifier, visual_data: Dictionary, is_inspectable: bool = true) -> void:
	tooltip_text = ""
	_visual_capsule_sealed = bool(visual_data.get("capsule_sealed", false))
	_visual_incubating = bool(visual_data.get("incubating", false))
	self._location = loc
	if _instance_uuid != visual_data.get("uuid", ""):
		_is_inspected = false
	self._instance_uuid = visual_data.get("uuid", "")
	self._bound_uuid = visual_data.get("uuid", "")
	self._is_inspectable = is_inspectable
	definition_id = StringName(visual_data.get("definition_id", visual_data.get("def_id", &"")))
	if is_instance_valid(_hover_tween):
		_hover_tween.kill()
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.cancel()
	_is_selected = false
	_merge_target_type = &""
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
	WindowManager.register_location_view(loc, self)

	if visual_data.is_empty():
		definition_id = &""
		_entity_type = &""
		_has_locked_recipe = false
		_update_recipe_unlock_outline()
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
	_has_locked_recipe = visual_data.get("has_locked_recipe", false)
	
	if icon_rect:
		var icon_texture: Texture2D = visual_data.get("icon")
		icon_rect.texture = icon_texture
		# The context scale is shared with units. Smaller authored item icons
		# stay smaller and are centered in the unit's 64x64 source-art footprint.
		if icon_rect.texture:
			var base_size: Vector2 = Vector2(C.UNIT_SPRITE_SIZE / 2.0, C.UNIT_SPRITE_SIZE / 2.0)
			var target_size: Vector2 = base_size * _size_scale
			var sprite_display_size: Vector2 = Vector2(icon_texture.get_size()) * _size_scale

			icon_rect.custom_minimum_size = target_size
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
			if visual_data.get("category", &"") == &"TRINKET":
				# Trinkets fit their HUD cell; authored pixel sizing is for units/items.
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				var old_sprite: Node = icon_rect.get_node_or_null("UnitSprite")
				if old_sprite != null:
					old_sprite.queue_free()
				_setup_overlay_stats_layout()
			elif _size_scale > 1.0 and not _has_overlay_heuristic():
				# Battle Mode: Use UnitSprite to enforce 128x128 scale inside 192x192 slot
				icon_rect.custom_minimum_size = target_size # 192x192
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.texture = null # Clear main texture
				
				# Setup shadow on platform surface behind unit/item
				_setup_shadow_sprite()
				
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
				
				# Ensure UnitSprite is drawn on top of ShadowSprite
				var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
				if shadow_sprite:
					icon_rect.move_child(shadow_sprite, 0)
				
				# Keep each icon at its authored pixel scale. Smaller item art is
				# centered in the same 64x64 source-art footprint as a unit.
				var unit_display_area: Vector2 = Vector2(C.UNIT_SPRITE_SIZE, C.UNIT_SPRITE_SIZE)
				unit_sprite.custom_minimum_size = sprite_display_size
				unit_sprite.size = sprite_display_size
				# Position the sprite in the unit area standing on the platform surface.
				unit_sprite.position = Vector2(C.SLOT_CENTER_OFFSET, C.SLOT_UNIT_OFFSET_Y) + (unit_display_area - sprite_display_size) / 2.0
				unit_sprite.texture = icon_texture
				unit_sprite.visible = true
				# CRITICAL: Copy shader material so flash effects work on visible sprite
				if icon_rect.material:
					unit_sprite.material = icon_rect.material.duplicate()
				
				# Setup Battle Layout (Underlay)
				_setup_battle_stats_layout()
			elif _has_overlay_heuristic():
				# Inventory Mode: Fixed slot size based on scale, Unit centered inside
				var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
				if shadow_sprite: shadow_sprite.visible = false
				
				# Ensure Overlay Layout
				_setup_overlay_stats_layout()
				var capsule_rect: Rect2 = get_capsule_rect()
				var capsule_scale: float = capsule_rect.size.x / C.GACHA_CAPSULE_DIAMETER
				sprite_display_size = Vector2(icon_texture.get_size()) * capsule_scale
				var footprint: Vector2 = Vector2(C.SLOT_SIZE_2X, C.SLOT_SIZE_2X) if _is_shelf_capsule() else capsule_rect.size
				
				icon_rect.custom_minimum_size = footprint
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
				
				# Center the authored-size icon inside the unit's 64x64 source-art footprint.
				unit_sprite.custom_minimum_size = sprite_display_size
				unit_sprite.size = sprite_display_size
				var offset: Vector2 = capsule_rect.get_center() - sprite_display_size * 0.5
				unit_sprite.position = offset
				unit_sprite.texture = icon_texture
				unit_sprite.visible = true
				# CRITICAL: Copy shader material so flash effects work on visible sprite
				if icon_rect.material:
					unit_sprite.material = icon_rect.material.duplicate()
			else:
				# Compact Mode: keep the icon at its authored pixel scale, centered
				# in the same footprint used by a 64x64 unit sprite.
				var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
				if shadow_sprite: shadow_sprite.visible = false
				
				_setup_overlay_stats_layout()
				var compact_footprint_size: Vector2 = target_size
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
				icon_rect.custom_minimum_size = compact_footprint_size
				icon_rect.texture = null
				var unit_sprite = icon_rect.get_node_or_null("UnitSprite")
				if not unit_sprite:
					unit_sprite = TextureRect.new()
					unit_sprite.name = "UnitSprite"
					icon_rect.add_child(unit_sprite)
					unit_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
					unit_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					unit_sprite.stretch_mode = TextureRect.STRETCH_SCALE
				_match_icon_texture_filter(unit_sprite)
				unit_sprite.custom_minimum_size = sprite_display_size
				unit_sprite.size = sprite_display_size
				unit_sprite.position = (compact_footprint_size - sprite_display_size) / 2.0
				unit_sprite.texture = icon_texture
				unit_sprite.visible = true
				if icon_rect.material:
					unit_sprite.material = icon_rect.material.duplicate()
		else:
			# Fallback for missing textures
			var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
			if shadow_sprite: shadow_sprite.visible = false
			
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

	_update_item_slots()
	_apply_selection_feedback()
	_update_recipe_unlock_outline()
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
		
	var current_souls: int = 0
	if not GameManager.is_in_battle:
		current_souls = _get_run_trait_count_for_view(_trait_name)
	else:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if not is_instance_valid(bm):
			return
		var is_enemy_team = is_enemy or (is_instance_valid(_location) and _location.container == &"EnemyTrinkets")
		var team = "ENEMY" if is_enemy_team else "PLAYER"
		var active_traits = bm.get_active_traits(team)
		current_souls = active_traits.get(_trait_name, 0)
	
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
		SignalBus.trait_threshold_reached.emit(_instance_uuid, definition_id, is_enemy)
		
	_last_trait_level = level
	_last_soul_count = current_souls
	
	_update_outline_visuals()

func _get_run_trait_count_for_view(trait_id: String) -> int:
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return 0

	var counts: Dictionary = {}
	for t in C.TRAIT_SORT_ORDER:
		counts[t] = 0

	var lineup = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_LINEUP)
	if not is_instance_valid(lineup):
		return 0

	var all_inst = GameManager.run_state.get_all_instances()
	for unit_uuid in lineup.get_all_non_empty_uuids():
		var unit = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if not is_instance_valid(unit):
			continue
		var soul_counts = unit.get_trait_soul_counts(all_inst)
		for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
			if counts.has(soul_type):
				counts[soul_type] += soul_counts.get(soul_type, 0)
		for tag in unit.get_active_tags(all_inst):
			var upper = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] += 1

	return int(counts.get(trait_id, 0))


func update_visuals(visual_data: Dictionary) -> void:
	if visual_data.is_empty() or visual_data.get("uuid") != _instance_uuid:
		return
		
	_visual_hp = visual_data.get("hp", _visual_hp)
	_visual_pwr = visual_data.get("pwr", _visual_pwr)
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
	if visual_data.has("has_locked_recipe"):
		_has_locked_recipe = visual_data.get("has_locked_recipe", _has_locked_recipe)
		_update_recipe_unlock_outline()
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
	_apply_unit_corner_icon_layout()
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

func set_animation_controller_active(active: bool) -> void:
	if is_instance_valid(_anim_controller):
		_anim_controller.set_active(active)

## Configure the interaction context for this view
func set_interaction_context(interaction_mode: StringName, entity_type: StringName, window_group_id: int = 0) -> void:
	_interaction_mode = interaction_mode
	_entity_type = entity_type
	_window_group_id = window_group_id

## Create and emit InteractionContext for this view
func _create_interaction_context(event_type: StringName, pointer_pos: Vector2 = Vector2.ZERO) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = _instance_uuid
	context.entity_type = _entity_type
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	if not pointer_pos.is_zero_approx():
		context.pointer_position = pointer_pos
	elif is_instance_valid(GlobalInteractionRouter):
		context.pointer_position = GlobalInteractionRouter.get_last_pointer_position()
	return context

func _get_hover_fx_mode() -> int:
	return _hover_outline_controller.get_hover_fx_mode(self)

func _set_hover_state(active: bool, play_sound: bool = false) -> void:
	_hover_outline_controller.set_hover_state(self, active, play_sound)

# Inspection peek and long-press are handled centrally via InspectionTrigger.

func _can_begin_drag() -> bool:
	return _drag_controller.can_begin_drag(self)

func _begin_touch_drag() -> void:
	var drag_payload := _prepare_drag_payload()
	if drag_payload.is_empty():
		return
	_animate_press_to(0.0, 0.05)
	force_drag(drag_payload["data"], drag_payload["preview"])

func _prepare_drag_payload() -> Dictionary:
	return _drag_controller.prepare_drag_payload(self)

func _build_drag_preview_visual() -> Control:
	return _drag_controller.build_drag_preview_visual(self)

func _animate_hover_to(target: float, duration: float) -> void:
	_hover_outline_controller.animate_hover_to(self, target, duration)

func _animate_press_to(target: float, duration: float) -> void:
	_hover_outline_controller.animate_press_to(self, target, duration)

func _set_hover_amount(value: float) -> void:
	_hover_amount = clampf(value, 0.0, 1.0)

func _set_press_amount(value: float) -> void:
	_press_amount = clampf(value, 0.0, 1.0)

func _update_hover_animation(_delta: float) -> void:
	_hover_outline_controller.update_hover_animation(self)

func _apply_hover_visuals(mode: int) -> void:
	_hover_outline_controller.apply_hover_visuals(self, mode)

func _apply_inventory_brightness(mode: int) -> void:
	_hover_outline_controller.apply_inventory_brightness(self, mode)

func _get_active_visual_sprite() -> TextureRect:
	if not is_instance_valid(icon_rect):
		return null
	var unit_sprite: TextureRect = icon_rect.get_node_or_null("UnitSprite") as TextureRect
	if is_instance_valid(unit_sprite) and unit_sprite.visible:
		return unit_sprite
	return icon_rect

func _match_icon_texture_filter(item: CanvasItem) -> void:
	if not is_instance_valid(item):
		return
	if is_instance_valid(icon_rect):
		item.texture_filter = icon_rect.texture_filter

func _update_hover_draw_priority() -> void:
	_hover_outline_controller.update_hover_draw_priority(self)

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
	_update_dynamic_status_icons(false)
	
	if snapshot.has("equipped_item_icon"):
		_visual_equipped_item_icon = snapshot["equipped_item_icon"]
		_update_equipped_item_icon()
	elif snapshot.has("equipped_items"):
		if snapshot["equipped_items"].is_empty():
			_visual_equipped_item_icon = null
			_update_equipped_item_icon()
	
	_update_stats()

func animate_burn_change(target_stacks: int) -> void:
	_status_strip.animate_burn_change(self, target_stacks)

func animate_armor_change(target_stacks: int) -> void:
	_status_strip.animate_armor_change(self, target_stacks)

func animate_armor_stat_change(target_stacks: int, _amount: int) -> void:
	_status_strip.animate_armor_stat_change(self, target_stacks)

func _update_dynamic_status_icons(animate: bool = true) -> void:
	_status_strip.update_dynamic_status_icons(self, animate)

func animate_status_change(status_id: StringName, new_stacks: int) -> void:
	_status_strip.animate_status_change(self, status_id, new_stacks)

func animate_stat_change(target_val: int, _delta: int, type: String, trigger_reactions: bool = true) -> void:
	_status_strip.animate_stat_change(self, target_val, type, trigger_reactions)

func _flash_label(label: Label) -> void:
	_status_strip.flash_label(self, label)

func _pop_container(container: Control) -> void:
	_status_strip.pop_container(self, container)

func _update_item_slots() -> void:
	_apply_unit_corner_icon_layout()
	_update_level_display()
	_update_equipped_item_icon()

func _setup_status_effect_click_handlers() -> void:
	_status_strip.setup_status_effect_click_handlers(self)

func _on_burn_container_clicked(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		_open_status_effect_tooltip(&"burn", burn_container)
		get_viewport().set_input_as_handled()

func _on_armor_container_clicked(event: InputEvent) -> void:
	if InputUtils.is_primary_pointer_press(event):
		_open_status_effect_tooltip(&"armor", armor_container)
		get_viewport().set_input_as_handled()

func _open_status_effect_tooltip(status_id: StringName, _anchor: Control) -> void:
	_status_strip.open_status_effect_tooltip(_location, status_id)

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
	_apply_unit_corner_icon_layout()

func _update_level_display() -> void:
	if _entity_type != &"UNIT":
		level_stars_rect.visible = false
		return
	assert(_visual_level >= 1 and _visual_level <= 3, "GachaBallView: unit level must be between 1 and 3")
	match _visual_level:
		1:
			level_stars_rect.texture = LEVEL_1_STARS_TEXTURE
		2:
			level_stars_rect.texture = LEVEL_2_STARS_TEXTURE
		3:
			level_stars_rect.texture = LEVEL_3_STARS_TEXTURE
	level_stars_rect.visible = true

func _apply_unit_corner_icon_layout() -> void:
	# Player units face right: item left, level right. Enemy units mirror both.
	var item_on_left: bool = not is_enemy
	var item_icon_size: Vector2 = Vector2(EQUIPPED_ITEM_ICON_SIZE, EQUIPPED_ITEM_ICON_SIZE)
	var level_icon_size: Vector2 = Vector2(LEVEL_STAR_ICON_SIZE, LEVEL_STAR_ICON_SIZE)
	_set_unit_corner_icon(equipped_item_icon_rect, item_on_left, item_icon_size)
	_set_unit_corner_icon(level_stars_rect, not item_on_left, level_icon_size)

func _set_unit_corner_icon(icon_rect_to_position: TextureRect, align_left: bool, icon_size: Vector2) -> void:
	icon_rect_to_position.custom_minimum_size = icon_size
	icon_rect_to_position.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect_to_position.stretch_mode = TextureRect.STRETCH_SCALE
	if _is_shelf_capsule():
		var capsule_rect: Rect2 = get_capsule_rect()
		var icon_left: float = capsule_rect.position.x + UNIT_CORNER_ICON_INSET if align_left else capsule_rect.end.x - UNIT_CORNER_ICON_INSET - icon_size.x
		icon_rect_to_position.set_anchors_preset(Control.PRESET_TOP_LEFT)
		icon_rect_to_position.position = Vector2(icon_left, capsule_rect.position.y + UNIT_CORNER_ICON_INSET)
		icon_rect_to_position.size = icon_size
		return
	var scaled_inset: float = UNIT_CORNER_ICON_INSET * _size_scale
	if align_left:
		icon_rect_to_position.set_anchors_preset(Control.PRESET_TOP_LEFT)
		icon_rect_to_position.offset_left = scaled_inset
		icon_rect_to_position.offset_right = scaled_inset + icon_size.x
	else:
		icon_rect_to_position.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		icon_rect_to_position.offset_left = -scaled_inset - icon_size.x
		icon_rect_to_position.offset_right = -scaled_inset
	icon_rect_to_position.offset_top = scaled_inset
	icon_rect_to_position.offset_bottom = scaled_inset + icon_size.y

## Handle click on an equipped item icon
func _on_equipped_item_clicked(event: InputEvent, _anchor: Control, item_uuid: String) -> void:
	if InputUtils.is_primary_pointer_press(event):
		var item_loc := LocationIdentifier.new()
		item_loc.container = C.CONTAINER_EQUIPPED_ITEM
		item_loc.unit_uuid = _instance_uuid
		ActionQueue.request(InspectEntityAction.new(item_loc, false, &"ItemInspection", &"", item_uuid))
		get_viewport().set_input_as_handled()

## Get all instances database from the appropriate game state
func _get_all_instances_db() -> Dictionary:
	var battle_manager: Node = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(battle_manager):
		return battle_manager.get_all_instances()
	if is_instance_valid(GameManager.run_state):
		return GameManager.run_state.run_instances
	return {}

## Create gachaball overlay for inventory windows
## Match the physics inventory composition: capsule behind the unit sprite.
func _create_gachaball_overlay() -> void:
	if not show_capsule_overlay or not is_instance_valid(icon_rect):
		return
	
	var p = get_parent()
	while p:
		if "InspectionWindow" in p.name or "ChoiceWindow" in p.name:
			return
		p = p.get_parent()
	
	# Check if overlay already exists (prevent duplication on repopulate)
	var existing_overlay = get_node_or_null("GachaBallOverlay") as Sprite2D
	if is_instance_valid(existing_overlay):
		_update_incubator_glow(existing_overlay)
		return
	
	# Load the overlay texture
	var overlay_texture: Texture2D = load(GACHABALL_OVERLAY_PATH)
	if not is_instance_valid(overlay_texture):
		return
	
	# Use Sprite2D so the run inventory capsule is rendered the same way as PhysicsGachaBall.
	var overlay = Sprite2D.new()
	overlay.name = "GachaBallOverlay"
	overlay.texture = overlay_texture
	var capsule_rect: Rect2 = get_capsule_rect()
	var overlay_size: float = capsule_rect.size.x
	var overlay_texture_size: Vector2 = overlay_texture.get_size()
	var base_scale: Vector2 = Vector2(
		overlay_size / maxf(overlay_texture_size.x, 1.0),
		overlay_size / maxf(overlay_texture_size.y, 1.0)
	)
	overlay.centered = true
	overlay.position = capsule_rect.get_center()
	overlay.scale = base_scale
	overlay.set_meta("base_scale", base_scale)
	
	# Add as a sibling behind VBox so the capsule matches PhysicsGachaBall:
	# capsule under the icon/unit, selection ring above it.
	add_child(overlay)
	move_child(overlay, 1)
	_update_incubator_glow(overlay)
	
	# Ensure clipping is disabled so glow can spill outside the bounding box
	clip_contents = false
	if get_parent() is Control:
		get_parent().clip_contents = false

func _update_incubator_glow(capsule: Sprite2D) -> void:
	capsule.modulate = INCUBATOR_CAPSULE_TINT if _visual_incubating else Color.WHITE
	var glow: Sprite2D = capsule.get_node_or_null("IncubatorGlow") as Sprite2D
	if _visual_incubating and glow == null:
		var falloff := Gradient.new()
		falloff.offsets = PackedFloat32Array([0.0, 0.64, 1.0])
		falloff.colors = PackedColorArray([Color(1.0, 0.79, 0.19, 0.72), Color(1.0, 0.69, 0.1, 0.32), Color(1.0, 0.69, 0.1, 0.0)])
		var light_texture := GradientTexture2D.new()
		light_texture.gradient = falloff
		light_texture.fill = GradientTexture2D.FILL_RADIAL
		light_texture.fill_from = Vector2(0.5, 0.5)
		light_texture.fill_to = Vector2(1.0, 0.5)
		glow = Sprite2D.new()
		glow.name = "IncubatorGlow"
		glow.texture = light_texture
		glow.scale = Vector2(capsule.texture.get_size()) / float(light_texture.width) * 1.5
		glow.show_behind_parent = true
		capsule.add_child(glow)
	if glow != null:
		glow.visible = _visual_incubating



## Setup platform shadow sprite for battle slots
func _setup_shadow_sprite() -> TextureRect:
	if not icon_rect:
		return null
	var shadow_sprite = icon_rect.get_node_or_null("ShadowSprite")
	if not shadow_sprite:
		shadow_sprite = TextureRect.new()
		shadow_sprite.name = "ShadowSprite"
		icon_rect.add_child(shadow_sprite)
		shadow_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_match_icon_texture_filter(shadow_sprite)
	shadow_sprite.texture = SHADOW_TEXTURE
	shadow_sprite.custom_minimum_size = Vector2(C.SHADOW_WIDTH_2X, C.SHADOW_HEIGHT_2X)
	shadow_sprite.size = Vector2(C.SHADOW_WIDTH_2X, C.SHADOW_HEIGHT_2X)
	shadow_sprite.position = Vector2(C.SLOT_CENTER_OFFSET, C.SHADOW_OFFSET_Y)
	shadow_sprite.pivot_offset = Vector2(C.SHADOW_WIDTH_2X / 2.0, C.SHADOW_HEIGHT_2X / 2.0)
	shadow_sprite.modulate = Color(1.0, 1.0, 1.0, C.SHADOW_ALPHA)
	shadow_sprite.scale = Vector2.ONE
	shadow_sprite.visible = true
	icon_rect.move_child(shadow_sprite, 0)
	return shadow_sprite

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
	# If BattleManager or BattleAnimator is playing a sequence, views are pure puppets.
	# Visual updates are driven strictly by animation events at their exact impact beat.
	var bm: Node = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.is_animations_playing():
		return
	if BattleAnimator.is_playing_sequence():
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
	if is_instance_valid(GlobalInteractionRouter) and (GlobalInteractionRouter.is_combat_phase() or GlobalInteractionRouter.is_vcr_playing()):
		return
	# Drag guard: never emit hover during ANY drag (self or global)
	if _is_dragging: return
	if GlobalInteractionRouter.is_drag_active(): return
	_set_hover_state(true, true)
	if not _is_inspectable: return
	if not is_instance_valid(_location): return
	# Touch guard: only emit on desktop
	if InputUtils.prefers_touch_input(): return
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.on_mouse_entered()

func _on_mouse_exited() -> void:
	_set_hover_state(false, false)
	if not is_instance_valid(_location): return
	if is_instance_valid(GlobalInteractionRouter) and (GlobalInteractionRouter.is_combat_phase() or GlobalInteractionRouter.is_vcr_playing()):
		return
	if InputUtils.prefers_touch_input(): return
	# Drag guard: never emit hover during ANY drag (self or global)
	if _is_dragging: return
	if GlobalInteractionRouter.is_drag_active(): return
	if is_instance_valid(_inspection_trigger):
		_inspection_trigger.on_mouse_exited()

func refresh_hover_state_from_pointer() -> void:
	assert(is_inside_tree(), "GachaBallView.refresh_hover_state_from_pointer requires a live view")
	if InputUtils.prefers_touch_input():
		return
	# A view spawned beneath a stationary pointer may still report an ancestor
	# as the GUI target. Unrelated controls above it must retain mouse priority.
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	var pointer_is_over_view: bool = hovered_control == null
	if hovered_control != null:
		pointer_is_over_view = (
			hovered_control == self
			or is_ancestor_of(hovered_control)
			or hovered_control.is_ancestor_of(self)
		)
	if pointer_is_over_view and _has_point(get_local_mouse_position()):
		_on_mouse_entered()

func _has_point(point: Vector2) -> bool:
	var radius = size.x / 2.0
	var center = Vector2(radius, size.y / 2.0)
	return point.distance_to(center) <= radius

func _gui_input(event: InputEvent) -> void:
	# Ignore input entirely if we don't have a location (e.g. visual-only balls in RestSite)
	# This allows the click to bubble up to the Rest Site's prize slot gui_input handler
	if not is_instance_valid(_location):
		return

	var is_combat_or_vcr: bool = is_instance_valid(GlobalInteractionRouter) and (GlobalInteractionRouter.is_combat_phase() or GlobalInteractionRouter.is_vcr_playing())
	if is_combat_or_vcr:
		if InputUtils.is_primary_pointer_press(event):
			# Instant pause and inspect window during VCR / combat playback.
			# Do NOT play press squash animation (_animate_press_to) and do not defer to release.
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.cancel()
			var pointer_pos: Vector2 = InputUtils.get_event_global_position(event)
			var sc_ctx = _create_interaction_context(&"SINGLE_CLICK", pointer_pos)
			SignalBus.emit_signal("interaction_context_received", sc_ctx)
			get_viewport().set_input_as_handled()
			accept_event()
			return
		elif InputUtils.is_primary_pointer_release(event) or InputUtils.is_primary_pointer_motion(event):
			get_viewport().set_input_as_handled()
			accept_event()
			return

	if InputUtils.is_primary_pointer_motion(event):
		var pointer_pos = InputUtils.get_event_position(event)
		if event is InputEventScreenDrag and _touch_press_active:
			if pointer_pos.distance_to(_touch_press_position) > InputUtils.TOUCH_DRAG_THRESHOLD_PX:
				if is_instance_valid(_inspection_trigger):
					_inspection_trigger.cancel()
				_touch_press_active = false
				_pressed_pending_click = false
				if not _drag_initiated_for_click:
					_begin_touch_drag()
					get_viewport().set_input_as_handled()
					accept_event()
					return
			get_viewport().set_input_as_handled()
			accept_event()
			return
		elif is_instance_valid(_inspection_trigger):
			_inspection_trigger.on_motion(pointer_pos)

	if event is InputEventScreenTouch:
		if event.pressed:
			if _interaction_mode != &"INSPECTION_ONLY":
				_animate_press_to(1.0, 0.05)
			get_viewport().set_input_as_handled()
			accept_event()
			_pressed_pending_click = true
			_drag_initiated_for_click = false
			_touch_press_active = true
			_touch_press_position = event.position
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_pressed(event.position)
		else:
			if _interaction_mode != &"INSPECTION_ONLY":
				_animate_press_to(0.0, 0.14)
			_touch_press_active = false
			var peek_handled = false
			if is_instance_valid(_inspection_trigger):
				peek_handled = _inspection_trigger.on_pointer_released()
			if not peek_handled and _pressed_pending_click and not _drag_initiated_for_click:
				var pointer_pos: Vector2 = InputUtils.get_event_global_position(event)
				var sc_ctx = _create_interaction_context(&"SINGLE_CLICK", pointer_pos)
				SignalBus.emit_signal("interaction_context_received", sc_ctx)
			_pressed_pending_click = false
			_drag_initiated_for_click = false
			get_viewport().set_input_as_handled()
			accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if InputUtils.should_ignore_mouse_pointer_event(event):
			return
		if event.is_pressed():
			if _interaction_mode != &"INSPECTION_ONLY":
				_animate_press_to(1.0, 0.05)
				if not _is_hovered:
					_set_hover_state(true, false)
			# Defer single-click to release; may become a drag
			get_viewport().set_input_as_handled()
			_pressed_pending_click = true
			if is_instance_valid(_inspection_trigger):
				_inspection_trigger.on_pointer_pressed(event.position)
		else:
			if _interaction_mode != &"INSPECTION_ONLY":
				_animate_press_to(0.0, 0.14)
			var peek_handled = false
			if is_instance_valid(_inspection_trigger):
				peek_handled = _inspection_trigger.on_pointer_released()
			# On release: only emit SINGLE_CLICK if no drag was initiated and peek didn't handle release
			if not peek_handled and _pressed_pending_click and not _drag_initiated_for_click:
				var pointer_pos: Vector2 = InputUtils.get_event_global_position(event)
				var sc_ctx = _create_interaction_context(&"SINGLE_CLICK", pointer_pos)
				SignalBus.emit_signal("interaction_context_received", sc_ctx)
			if _interaction_mode != &"INSPECTION_ONLY" and not get_global_rect().has_point(get_global_mouse_position()):
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
	var drop_pos: Vector2 = get_global_transform() * _at_position
	var target_ctx = _create_interaction_context(&"DROP", drop_pos)
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

func _on_view_inspection_changed(view: Control, active: bool) -> void:
	if view == self:
		_is_inspected = active
		_update_outline_visuals()

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
	var bm: Node = get_tree().get_first_node_in_group("battle_manager")
	if is_instance_valid(bm) and bm.is_animations_playing():
		return
	if BattleAnimator.is_playing_sequence():
		return
		
	if stat == "hp":
		_visual_hp = value
	elif stat == "pwr":
		_visual_pwr = value
	_update_stats()

# NOTE: Animation methods (bump, death, summon, melee, lethal_save, guardian leap)
# moved to UnitAnimationController child node

func _apply_selection_feedback() -> void:
	_hover_outline_controller.apply_selection_feedback(self)

func _is_reward_or_shop_context() -> bool:
	if is_instance_valid(_location):
		if _location.container == C.CONTAINER_REWARDS or _location.container == C.CONTAINER_SHOP:
			return true
	var p = get_parent()
	while is_instance_valid(p):
		if p.name.begins_with("Reward") or p.is_in_group("reward_scene") or p.name.begins_with("Shop"):
			return true
		p = p.get_parent()
	return false

func _on_show_merge_target_indicators(merge_targets: Dictionary) -> void:
	var my_uuid := get_instance_uuid()
	var new_type: StringName = merge_targets.get(my_uuid, &"")
	if new_type != _merge_target_type:
		_merge_target_type = new_type
		_update_outline_visuals()

func _on_hide_merge_target_indicators() -> void:
	if not _merge_target_type.is_empty():
		_merge_target_type = &""
		_update_outline_visuals()

func _set_shader_outline(mat: ShaderMaterial, enabled: bool, color: Color = Color.WHITE, width: float = 3.0) -> void:
	GachaBallHoverOutlineController.set_shader_outline(mat, enabled, color, width)

func _update_outline_visuals() -> void:
	_hover_outline_controller.update_outline_visuals(self)

func _update_recipe_unlock_outline() -> void:
	_update_outline_visuals()

func _on_run_data_changed() -> void:
	if _is_trait_trinket:
		_update_trait_trinket_visuals(true)
	if not definition_id.is_empty() and _is_reward_or_shop_context():
		var run_state = GameManager.run_state if is_instance_valid(GameManager) else null
		if is_instance_valid(run_state):
			var new_locked = run_state.has_locked_recipe_for_result(definition_id)
			if new_locked != _has_locked_recipe:
				_has_locked_recipe = new_locked
				_update_recipe_unlock_outline()

func _notification(what: int) -> void:
	_drag_controller.handle_drag_notification(self, what)

# -----------------------------------------------------------------------------
# Guardian Leap (Forwarding to UnitAnimationController)
# Called by BattleAnimator for GUARDIAN_INTERCEPT events
# -----------------------------------------------------------------------------
func animate_leap_to(target_center: Vector2) -> void:
	var controller: UnitAnimationController = get_node_or_null("AnimationController") as UnitAnimationController
	if is_instance_valid(controller):
		await controller.animate_leap_to(target_center)

func animate_leap_return() -> void:
	var controller: UnitAnimationController = get_node_or_null("AnimationController") as UnitAnimationController
	if is_instance_valid(controller):
		await controller.animate_leap_return()

var force_inventory_mode: bool = false
var show_capsule_overlay: bool = true
var _visual_capsule_sealed: bool = false
var _visual_incubating: bool = false

## Heuristic to check if we should render in "Inventory Mode" (2x scale, 192px slot, circle outline)
## 1. Checks if parent name contains "InventoryWindow"
## 2. Checks if force_inventory_mode is set
func _has_overlay_heuristic() -> bool:
	if _visual_capsule_sealed:
		return true
	if force_inventory_mode:
		return true
	var p = get_parent()
	while p:
		# Check for inventory, shop, reward, or Discard parent contexts
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
	_drag_controller.reset_drag_deformation(self)

func play_trinket_activation_bounce() -> void:
	await _drag_controller.play_trinket_activation_bounce(self)

func play_snap_back_from(origin_pos: Vector2) -> void:
	_drag_controller.play_snap_back_from(self, origin_pos)

func play_landing_bounce() -> void:
	_drag_controller.play_landing_bounce(self)

# ------------------------------------------------------------------
# Layout Helpers (Delegated to GachaBallStatusStrip)

func _setup_battle_stats_layout() -> void:
	_status_strip.setup_battle_stats_layout(self)

func _apply_plastic_pill_style(container: HBoxContainer) -> void:
	GachaBallStatusStrip.apply_plastic_pill_style(container, _size_scale)

func _setup_overlay_stats_layout() -> void:
	_status_strip.setup_overlay_stats_layout(self, _is_shelf_capsule())
