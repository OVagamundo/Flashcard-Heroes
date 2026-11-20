class_name EnemyBannerView
extends Control

const SpriteOutline = preload("res://scripts/ui/SpriteOutline.gd")

## An encounter landmark, independent of the enemy trinket bar.
## Populated from presentation snapshots; hover uses the normal inspection controller.
const DISPLAY_SIZE: Vector2 = Vector2(112.0, 240.0)
const POLE_X: float = 0.0

@export var front_enemy_slot: SlotView

var _texture_rect: TextureRect
var _hit_mask: BitMap = BitMap.new()
var _inspection_trigger: InspectionTrigger = InspectionTrigger.new()
var _location: LocationIdentifier = LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER, 0)
var _instance_uuid: String = ""
var _definition_id: StringName = &""
var _activation_tween: Tween

func _ready() -> void:
	add_to_group("enemy_banner_view")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_texture_rect)
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SignalBus.view_inspection_changed.connect(_on_view_inspection_changed)
	_inspection_trigger.setup(self, _inspection_request)
	mouse_entered.connect(_inspection_trigger.on_mouse_entered)
	mouse_exited.connect(_inspection_trigger.on_mouse_exited)
	gui_input.connect(_on_gui_input)
	hide()

func populate(data: Dictionary) -> void:
	if data.is_empty():
		_inspection_trigger.cancel()
		SpriteOutline.set_highlight(_texture_rect, false)
		_instance_uuid = ""
		_definition_id = &""
		hide()
		return
	var texture: Texture2D = data["battlefield_banner_texture"] as Texture2D
	assert(texture != null, "Enemy banner %s has no battlefield artwork" % data["definition_id"])
	assert(front_enemy_slot != null, "EnemyBannerView requires the front enemy slot for input hit testing")
	if _instance_uuid != data["uuid"]:
		SpriteOutline.set_highlight(_texture_rect, false)
	_instance_uuid = data["uuid"]
	_definition_id = data["definition_id"]
	if _texture_rect.texture != texture:
		_hit_mask.create_from_image_alpha(texture.get_image())
		_texture_rect.texture = texture
	show()

func _inspection_request() -> Dictionary:
	return {} if _instance_uuid.is_empty() else {"location": _location}

func create_inspection_context(pointer_position: Vector2) -> InteractionContext:
	var context := InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.event_type = &"SINGLE_CLICK"
	context.location = _location
	context.entity_uuid = _instance_uuid
	context.entity_type = &"TRINKET"
	context.interaction_mode = &"INSPECTION_ONLY"
	context.pointer_position = pointer_position
	return context

func _on_view_inspection_changed(view: Control, active: bool) -> void:
	if view == self:
		SpriteOutline.set_highlight(_texture_rect, active)

func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if GlobalInteractionRouter.is_drag_active():
		return false
	# GUI order puts the banner ahead of slot hit areas. Its artwork still renders behind units.
	var pixel: Vector2i = Vector2i(point / size * Vector2(_hit_mask.get_size()))
	if not _hit_mask.get_bitv(pixel):
		return false
	var canvas_position: Vector2 = get_global_transform() * point
	for child: Node in front_enemy_slot.get_children():
		var unit: GachaBallView = child as GachaBallView
		if unit != null and not unit.is_queued_for_deletion() and unit.is_visible_in_tree():
			return not unit.has_battle_sprite_at(canvas_position)
	return true

func _on_gui_input(event: InputEvent) -> void:
	if GlobalInteractionRouter.is_combat_phase() or GlobalInteractionRouter.is_vcr_playing():
		if InputUtils.is_primary_pointer_press(event):
			_inspection_trigger.cancel()
			var pointer: Vector2 = GlobalInteractionRouter.get_last_pointer_position()
			SignalBus.interaction_context_received.emit(create_inspection_context(pointer))
		accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_inspection_trigger.on_pointer_pressed(mouse_event.position)
			else:
				_inspection_trigger.on_pointer_released()
	elif event is InputEventMouseMotion:
		_inspection_trigger.on_motion((event as InputEventMouseMotion).position)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_inspection_trigger.on_pointer_pressed(touch_event.position)
		else:
			_inspection_trigger.on_pointer_released()
	elif event is InputEventScreenDrag:
		_inspection_trigger.on_motion((event as InputEventScreenDrag).position)
	accept_event()

func get_instance_uuid() -> String:
	return _instance_uuid

func get_definition_id() -> StringName:
	return _definition_id

func play_activation() -> void:
	if _activation_tween != null:
		_activation_tween.kill()
	_texture_rect.self_modulate = Color.WHITE
	_activation_tween = create_tween()
	_activation_tween.tween_property(_texture_rect, "self_modulate", Color(1.35, 1.25, 1.05), AnimationConstants.scaled(0.12))
	_activation_tween.tween_property(_texture_rect, "self_modulate", Color.WHITE, AnimationConstants.scaled(0.2))

func _exit_tree() -> void:
	_inspection_trigger.cancel()
