class_name EnemyBannerView
extends Control

## An encounter landmark, independent of the enemy trinket bar.
## Populated from presentation snapshots; hover uses the normal inspection controller.
const DISPLAY_SIZE: Vector2 = Vector2(112.0, 240.0)
const POLE_X: float = 0.0

var _texture_rect: TextureRect
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
	_inspection_trigger.setup(self, _inspection_request)
	mouse_entered.connect(_inspection_trigger.on_mouse_entered)
	mouse_exited.connect(_inspection_trigger.on_mouse_exited)
	gui_input.connect(_on_gui_input)
	hide()

func populate(data: Dictionary) -> void:
	if data.is_empty():
		_inspection_trigger.cancel()
		_instance_uuid = ""
		_definition_id = &""
		hide()
		return
	var texture: Texture2D = data["battlefield_banner_texture"] as Texture2D
	assert(texture != null, "Enemy banner %s has no battlefield artwork" % data["definition_id"])
	_instance_uuid = data["uuid"]
	_definition_id = data["definition_id"]
	_texture_rect.texture = texture
	show()

func _inspection_request() -> Dictionary:
	return {} if _instance_uuid.is_empty() else {"location": _location}

func _on_gui_input(event: InputEvent) -> void:
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
