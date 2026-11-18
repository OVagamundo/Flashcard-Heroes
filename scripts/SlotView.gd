class_name SlotView
extends PanelContainer

signal shelf_slot_purchase_requested(slot_index: int)

const InputUtils = preload("res://scripts/InputUtils.gd")
const AnimationConstants = preload("res://scripts/animations/AnimationConstants.gd")
const InspectionTrigger = preload("res://scripts/ui/InspectionTrigger.gd")
const SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/slot.png")
const BATTLE_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/slotBattle.png")
const BATTLE_SPRING_PLATFORM_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattlePlatformSlot.png")
const BATTLE_SHELF_PLATFORM_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattleShelfPlatformSlot.png")
const BATTLE_BURN_PLATFORM_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattleBurnPlatformSlot.png")
const BATTLE_STATIC_PLATFORM_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattleStaticPlatformSlot.png")
const BATTLE_SLOT_SELECTION_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattleSlotSelection.png")
const RUN_INVENTORY_SLOT_SELECTION_TEXTURE = preload("res://assets/PixelArt/ui/textures/SlotSelection.png")
const BATTLE_TRINKET_SLOT_TEXTURE = preload("res://assets/PixelArt/ui/textures/BattleTrinketSlot.png")
const PLAYER_LINEUP_LIGHT: Color = Color(1.12, 1.02, 0.79, 1.0)
const ENEMY_LINEUP_SHADE: Color = Color(0.68, 0.79, 0.95, 1.0)

var _location: LocationIdentifier

# InteractionContext properties
var _interaction_mode: StringName = &"FULLY_INTERACTIVE"
var _window_group_id: int = 0

# Size scale for gachaball views (2.0 for battle, 1.0 for windows)
var _size_scale: float = 2.0 # Default to battle scale
var _shelf_slot_locked: bool = false
var _shelf_slot_purchasable: bool = false
var _shelf_lock_overlay: Control = null
var _shelf_hover_outline: TextureRect = null
var _shelf_lock_plus_label: Label = null
var _shelf_purchase_inspection_trigger: InspectionTrigger = null

# Indicator overlay for valid drop targets
var _indicator: TextureRect = null
var _indicator_tween: Tween = null
const INDICATOR_TEXTURE = preload("res://assets/PixelArt/ui/textures/Indicator.png")
var _slot_background_transition_overlay: TextureRect = null
var _slot_background_transition_tween: Tween = null
# Base slot size at 1x scale
const BASE_SLOT_SIZE: int = 96

# Slot background stylebox
var _background_style: StyleBoxTexture

## Whether the slot draws a background pedestal texture. Set to false for preview / inspection windows.
var show_background: bool = true:
	set(value):
		show_background = value
		if not is_node_ready():
			return
		if not show_background:
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			if is_instance_valid(_background_style):
				_background_style.texture = null
		else:
			if is_instance_valid(_background_style):
				add_theme_stylebox_override("panel", _background_style)

## Whether to show empty trinket slots (only during trinket acquisition states like RewardElite)
var show_empty_trinket_slot: bool = false:
	set(value):
		show_empty_trinket_slot = value
		if is_node_ready():
			_update_slot_appearance()

var is_trinket_slot: bool:
	get:
		return _container_name == &"EnemyTrinkets" or _container_name == &"PlayerTrinkets"

## Check if this slot currently has an active GachaBallView content item
func has_content() -> bool:
	for child in get_children():
		if child.has_meta("slot_persistent_child"):
			continue
		if child is GachaBallView and not child.is_queued_for_deletion():
			return true
	return false

## Set size scale for gachaball views in this slot
## NOTE: This only sets internal scale for GachaBallView. Caller is responsible for slot size.
func set_size_scale(size_scale: float) -> void:
	_size_scale = size_scale

func _ready() -> void:
	# Ensure pixel-art scaling uses nearest-neighbor filtering so low-resolution pixel art does not look blurry
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Reset node modulation to ensure transparency isn't coming from scene state
	self.modulate = Color.WHITE
	self.self_modulate = Color.WHITE
	z_as_relative = false
	z_index = 0
	
	# Configure the slot background using properties to render the texture
	_background_style = StyleBoxTexture.new()
	_background_style.texture = SLOT_TEXTURE
	# Default neutral tint (no alpha changes as requested)
	_background_style.modulate_color = Color(0.5, 0.5, 0.5)
	if show_background:
		add_theme_stylebox_override("panel", _background_style)
	else:
		_background_style.texture = null
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	if _container_name != &"":
		_update_slot_appearance()
	
	# Connect to granular stat change signal for targeted updates
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	
	# Connect to slot indicator signals
	SignalBus.show_slot_indicators.connect(_on_show_slot_indicators)
	SignalBus.hide_slot_indicators.connect(_on_hide_slot_indicators)
	
	_create_slot_background_transition_overlay()
	# Create indicator overlay (initially hidden)
	_create_indicator()

## Set custom color for this slot based on container type
var _slot_effect: StringName = &""
var _container_name: StringName = &""

## Set custom color for this slot based on container type
func set_slot_color(container_name: StringName) -> void:
	_container_name = container_name
	_update_slot_appearance()

func set_shelf_slot_state(is_locked: bool, is_next_purchasable: bool) -> void:
	if _container_name != &"PlayerShelf":
		return
	_shelf_slot_locked = is_locked
	_shelf_slot_purchasable = is_locked and is_next_purchasable
	if not is_node_ready():
		return
	if is_locked:
		_create_shelf_lock_overlay()
		_shelf_lock_overlay.visible = true
		_shelf_lock_plus_label.visible = _shelf_slot_purchasable
		move_child(_shelf_lock_overlay, get_child_count() - 1)
	else:
		if is_instance_valid(_shelf_lock_overlay):
			_shelf_purchase_inspection_trigger.cancel()
			_shelf_lock_overlay.visible = false
			_shelf_lock_plus_label.visible = false
	_update_slot_appearance()
	for child: Node in get_children():
		if child is GachaBallView:
			(child as GachaBallView).modulate = Color(0.25, 0.25, 0.25, 1.0) if is_locked else Color.WHITE

func _create_shelf_lock_overlay() -> void:
	if is_instance_valid(_shelf_lock_overlay):
		return
	_shelf_lock_overlay = Control.new()
	_shelf_lock_overlay.name = "ShelfLockOverlay"
	_shelf_lock_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shelf_lock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelf_lock_overlay.z_index = 100
	_shelf_lock_overlay.set_meta("slot_persistent_child", true)
	_shelf_lock_overlay.gui_input.connect(_on_shelf_lock_overlay_gui_input)
	_shelf_purchase_inspection_trigger = InspectionTrigger.new()
	_shelf_purchase_inspection_trigger.setup(_shelf_lock_overlay, func() -> Dictionary:
		if not _shelf_slot_purchasable:
			return {}
		return {
			"title_key": "ui.shelf_slot_purchase_title",
			"description_key": "ui.shelf_purchase_description"
		}
	)
	_shelf_lock_overlay.mouse_entered.connect(_on_shelf_lock_overlay_mouse_entered)
	_shelf_lock_overlay.mouse_exited.connect(_on_shelf_lock_overlay_mouse_exited)
	add_child(_shelf_lock_overlay)
	_shelf_hover_outline = TextureRect.new()
	_shelf_hover_outline.texture = BATTLE_SHELF_PLATFORM_SLOT_TEXTURE
	_shelf_hover_outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shelf_hover_outline.stretch_mode = TextureRect.STRETCH_SCALE
	_shelf_hover_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf_hover_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outline_material: ShaderMaterial = ShaderMaterial.new()
	outline_material.shader = preload("res://assets/shaders/shelf_slot_outline.gdshader")
	outline_material.set_shader_parameter("asset_texture", BATTLE_SHELF_PLATFORM_SLOT_TEXTURE)
	_shelf_hover_outline.material = outline_material
	_shelf_hover_outline.visible = false
	_shelf_lock_overlay.add_child(_shelf_hover_outline)

	_shelf_lock_plus_label = Label.new()
	_shelf_lock_plus_label.name = "PurchaseShelfSlotPlus"
	_shelf_lock_plus_label.text = "+"
	_shelf_lock_plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shelf_lock_plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shelf_lock_plus_label.add_theme_font_size_override("font_size", 88)
	_shelf_lock_plus_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	_shelf_lock_plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf_lock_plus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelf_lock_overlay.add_child(_shelf_lock_plus_label)

func _on_shelf_lock_overlay_gui_input(event: InputEvent) -> void:
	if not _shelf_slot_purchasable or not InputUtils.is_primary_pointer_press(event):
		return
	shelf_slot_purchase_requested.emit(_location.index)
	get_viewport().set_input_as_handled()
	_shelf_lock_overlay.accept_event()

func _on_shelf_lock_overlay_mouse_entered() -> void:
	if _shelf_slot_purchasable:
		_shelf_hover_outline.visible = true
		_shelf_purchase_inspection_trigger.on_mouse_entered()

func _on_shelf_lock_overlay_mouse_exited() -> void:
	_shelf_hover_outline.visible = false
	_shelf_purchase_inspection_trigger.on_mouse_exited()

func animate_shelf_unlock() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y * 0.85)
	scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.09, 1.09), AnimationConstants.scaled(0.09)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, AnimationConstants.scaled(0.12)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

func set_slot_effect(effect: StringName) -> void:
	_slot_effect = effect
	_update_slot_appearance()

func _update_slot_appearance() -> void:
	if not show_background or not is_instance_valid(_background_style):
		return
	
	var is_trinket_slot = (_container_name == &"EnemyTrinkets" or _container_name == &"PlayerTrinkets")
	var is_battle_slot = (_container_name == &"PlayerLineup" or _container_name == &"EnemyLineup" or _container_name == &"PlayerShelf" or _container_name == &"EnemyShelf")
	var is_shelf_slot = (_container_name == &"PlayerShelf" or _container_name == &"EnemyShelf")
	
	if is_trinket_slot:
		if has_content():
			# An equipped trinket never shows the slot frame behind it
			_background_style.texture = null
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif show_empty_trinket_slot:
			# Empty trinket slot is only shown when player is acquiring a new trinket
			_background_style.texture = BATTLE_TRINKET_SLOT_TEXTURE
			_background_style.expand_margin_top = 0.0
			_background_style.expand_margin_bottom = 0.0
			_background_style.expand_margin_left = 0.0
			_background_style.expand_margin_right = 0.0
			_background_style.modulate_color = Color.WHITE
			add_theme_stylebox_override("panel", _background_style)
		else:
			# Normal gameplay: empty trinket slots are transparent
			_background_style.texture = null
			add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	elif _slot_effect == &"burn" and is_battle_slot:
		_background_style.texture = BATTLE_BURN_PLATFORM_SLOT_TEXTURE
		_background_style.expand_margin_top = 0.0
		_background_style.expand_margin_bottom = 0.0
		_background_style.expand_margin_left = 0.0
		_background_style.expand_margin_right = 0.0
		_background_style.modulate_color = Color.WHITE
		add_theme_stylebox_override("panel", _background_style)
	elif (_slot_effect == &"lightning" or _slot_effect == &"static") and is_battle_slot:
		_background_style.texture = BATTLE_STATIC_PLATFORM_SLOT_TEXTURE
		_background_style.expand_margin_top = 0.0
		_background_style.expand_margin_bottom = 0.0
		_background_style.expand_margin_left = 0.0
		_background_style.expand_margin_right = 0.0
		_background_style.modulate_color = Color.WHITE
		add_theme_stylebox_override("panel", _background_style)
	else:
		if is_shelf_slot:
			_background_style.texture = BATTLE_SHELF_PLATFORM_SLOT_TEXTURE
			_background_style.expand_margin_top = 0.0
			_background_style.expand_margin_bottom = 0.0
			_background_style.expand_margin_left = 0.0
			_background_style.expand_margin_right = 0.0
			_background_style.modulate_color = Color.WHITE
			add_theme_stylebox_override("panel", _background_style)
		elif is_battle_slot:
			_background_style.texture = BATTLE_SPRING_PLATFORM_SLOT_TEXTURE
			_background_style.expand_margin_top = 0.0
			_background_style.expand_margin_bottom = 0.0
			_background_style.expand_margin_left = 0.0
			_background_style.expand_margin_right = 0.0
			_background_style.modulate_color = Color.WHITE
			add_theme_stylebox_override("panel", _background_style)
		elif _container_name == &"EquippedItem": # C.CONTAINER_EQUIPPED_ITEM
			_background_style.texture = load("res://assets/PixelArt/ui/textures/ItemSlot.png")
			_background_style.expand_margin_bottom = 0.0
		else:
			_background_style.texture = SLOT_TEXTURE
			_background_style.expand_margin_bottom = 0.0
			
		# Tint non-battle slots based on container type
		if not is_battle_slot:
			match _container_name:
				&"EquippedItem":
					_background_style.modulate_color = Color.WHITE
				_:
					_background_style.modulate_color = Color(0.5, 0.5, 0.5)

	if is_instance_valid(_indicator):
		if is_battle_slot:
			_indicator.texture = BATTLE_SLOT_SELECTION_TEXTURE
		elif _container_name.begins_with("RunInventory"):
			_indicator.texture = RUN_INVENTORY_SLOT_SELECTION_TEXTURE
		else:
			_indicator.texture = INDICATOR_TEXTURE
	
	if _container_name == &"PlayerShelf" and _shelf_slot_locked:
		_background_style.modulate_color = Color(0.25, 0.25, 0.25, 1.0)
	match _container_name:
		&"PlayerLineup":
			_background_style.modulate_color = PLAYER_LINEUP_LIGHT
		&"EnemyLineup":
			_background_style.modulate_color = ENEMY_LINEUP_SHADE
func animate_slot_effect_change(effect: StringName) -> void:
	var previous_effect: StringName = _slot_effect
	var previous_texture: Texture2D = _background_style.texture
	var previous_tint: Color = _background_style.modulate_color
	var is_lineup_slot: bool = _container_name == &"PlayerLineup" or _container_name == &"EnemyLineup"
	var should_crossfade_to_burn: bool = previous_effect == &"" and effect == &"burn" and is_lineup_slot and show_background
	_slot_effect = effect
	_update_slot_appearance()
	if should_crossfade_to_burn:
		assert(previous_texture == BATTLE_SPRING_PLATFORM_SLOT_TEXTURE, "SlotView.animate_slot_effect_change: regular lineup slot must use the spring platform texture")
		_play_slot_background_crossfade(previous_texture, previous_tint)
		await _slot_background_transition_tween.finished
	else:
		await get_tree().process_frame

func _play_slot_background_crossfade(previous_texture: Texture2D, previous_tint: Color) -> void:
	assert(is_instance_valid(_slot_background_transition_overlay), "SlotView._play_slot_background_crossfade: transition overlay must be initialized")
	if is_instance_valid(_slot_background_transition_tween):
		_slot_background_transition_tween.kill()

	_slot_background_transition_overlay.texture = previous_texture
	_slot_background_transition_overlay.self_modulate = previous_tint
	_slot_background_transition_overlay.modulate = Color.WHITE
	_slot_background_transition_overlay.visible = true
	_slot_background_transition_tween = create_tween()
	_slot_background_transition_tween.tween_property(_slot_background_transition_overlay, "modulate:a", 0.0, AnimationConstants.scaled(0.24)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_slot_background_transition_tween.finished.connect(_finish_slot_background_crossfade, CONNECT_ONE_SHOT)

func _finish_slot_background_crossfade() -> void:
	_slot_background_transition_overlay.visible = false
	_slot_background_transition_overlay.texture = null
	_slot_background_transition_overlay.modulate = Color.WHITE
	_slot_background_transition_overlay.self_modulate = Color.WHITE

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
	if is_instance_valid(_slot_background_transition_tween):
		_slot_background_transition_tween.kill()

func _notification(_what) -> void:
	pass

# --- Indicator Overlay Methods ---

## Create the indicator overlay (called in _ready)
func _create_indicator() -> void:
	_indicator = TextureRect.new()
	_indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_indicator.texture = INDICATOR_TEXTURE
	_indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.set_meta("slot_persistent_child", true)
	_indicator.visible = false
	_indicator.z_index = 10 # Ensure it's on top
	
	# Set anchors to fill parent
	_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	_indicator.set_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(_indicator)

func _create_slot_background_transition_overlay() -> void:
	_slot_background_transition_overlay = TextureRect.new()
	_slot_background_transition_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot_background_transition_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slot_background_transition_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_slot_background_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_background_transition_overlay.set_meta("slot_persistent_child", true)
	_slot_background_transition_overlay.visible = false
	_slot_background_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_background_transition_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_slot_background_transition_overlay)
	move_child(_slot_background_transition_overlay, 0)

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
	if is_instance_valid(loc) and loc.container != &"":
		set_slot_color(loc.container)

## Set the content of this slot using VisualData
func set_content(visual_data: Dictionary, is_inspectable: bool = true, is_enemy: bool = false) -> GachaBallView:
	# Clear existing content (preserve indicator and background)
	# Clear existing content (preserve indicator)
	for child in get_children():
		if child.has_meta("slot_persistent_child"):
			continue
		child.queue_free()
	
	if visual_data.is_empty():
		_update_slot_appearance()
		return null
	
	
	var gacha_ball_view_scene = load("res://scenes/GachaBallView.tscn")
	
	if not is_instance_valid(gacha_ball_view_scene):
		push_error("[SlotView] GachaBallViewScene failed to load!")
		return null
		
	var view = gacha_ball_view_scene.instantiate()
	
	if not is_instance_valid(view):
		push_error("[SlotView] Failed to instantiate GachaBallView!")
		return null
	
	# Set size scale before adding to tree (so populate uses correct scale)
	if view.has_method("set_size_scale"):
		view.set_size_scale(_size_scale)
	
	add_child(view)
	
	# Populate the view with visual data
	view.populate(_location, visual_data, is_inspectable)
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
	
	# If inspection or selection only, disable dragging functionality (interactive flag controls drag in GachaBallView)
	if effective_mode in [&"INSPECTION_ONLY", &"SELECTION_ONLY"]:
		view.set_is_interactive(false)
	else:
		view.set_is_interactive(true)
	
	view.set_meta("location_identifier", _location)
	
	# If this slot has no location (e.g. Rest Site visual balls), 
	# it shouldn't consume clicks at all. Pass them to the parent.
	if not is_instance_valid(_location):
		_recursively_set_mouse_filter_ignore(view)
	
	_update_slot_appearance()
	return view

## Helper to recursively set mouse filter to ignore
func _recursively_set_mouse_filter_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_recursively_set_mouse_filter_ignore(child)


## Granular stat change handler - updates only the specific stat that changed
func _on_unit_stat_changed(unit_uuid: String, stat_name: StringName, old_value: int, new_value: int) -> void:
	# Check if we have a child view that matches this UUID
	for child in get_children():
		if child is GachaBallView and child.get_instance_uuid() == unit_uuid:
			# Delegate to view's granular handler
			if is_instance_valid(child) and child.has_method("_on_unit_stat_changed"):
				child._on_unit_stat_changed(unit_uuid, stat_name, old_value, new_value)
			break


## Configure the interaction context for this slot
func set_interaction_context(interaction_mode: StringName, window_group_id: int = 0) -> void:
	_interaction_mode = interaction_mode
	_window_group_id = window_group_id

## Create and emit InteractionContext for this slot
func _create_interaction_context(event_type: StringName, pointer_pos: Vector2 = Vector2.ZERO) -> InteractionContext:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = event_type
	context.location = _location
	context.entity_uuid = "" # Empty slots have no entity
	context.entity_type = &"EMPTY_SLOT"
	context.interaction_mode = _interaction_mode
	context.window_group_id = _window_group_id
	if not pointer_pos.is_zero_approx():
		context.pointer_position = pointer_pos
	elif is_instance_valid(GlobalInteractionRouter):
		context.pointer_position = GlobalInteractionRouter.get_last_pointer_position()
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
			var pointer_pos: Vector2 = InputUtils.get_event_global_position(event)
			var context = _create_interaction_context(&"SINGLE_CLICK", pointer_pos)
			SignalBus.emit_signal("interaction_context_received", context)
			get_viewport().set_input_as_handled() # Stop propagation to Main/Battle
			accept_event() # Explicitly stop control bubbling
		else:
			pass
		
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

	# Create a target interaction context with drop coordinates and route via GIR
	var drop_pos: Vector2 = get_global_transform() * _at_position
	var target_ctx = _create_interaction_context(&"DROP", drop_pos)
	
	# IMMEDIATE VISUAL FEEDBACK: Hide indicator now.
	_hide_indicator()
	
	SignalBus.emit_signal("interaction_context_received", target_ctx)
	
	# Do not end drag here; InventoryManager will decide handled/unhandled and
	# call GlobalInteractionRouter.end_drag(true/false) centrally.
