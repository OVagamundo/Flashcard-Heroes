extends TextureButton
class_name NodeView

signal node_selected(node_def)

const CARD_INTERACTION_SHADER = preload("res://assets/shaders/path_option_card.gdshader")

@onready var label: Label = $Label

var _node_def
var _shader_mat: ShaderMaterial
var _hover_tween: Tween
var _press_tween: Tween
var _flash_tween: Tween
var _pop_tween: Tween

var _hover_amount: float = 0.0
var _press_amount: float = 0.0
var _flash_amount: float = 0.0
var _pop_amount: float = 0.0
var _pointer_uv: Vector2 = Vector2(0.5, 0.5)
var _perspective_tilt: Vector2 = Vector2.ZERO
var _is_hovered: bool = false
var _tilt_degrees: float = 0.0

const HOVER_SCALE: float = 0.16
const PRESS_SQUASH: float = 0.13
const POP_SCALE: float = 0.15
const MAX_TILT_DEGREES: float = 1.45
const MAX_PERSPECTIVE_X: float = 0.24
const MAX_PERSPECTIVE_Y: float = 0.15

# Texture paths
const CARD_TEXTURES = {
	"BATTLE": "res://assets/Realistic/ui/textures/BattlePath.png",
	"SHOP": "res://assets/Realistic/ui/textures/ShopCard.png",
	"BLACK_MARKET": "res://assets/Realistic/ui/textures/BlackMarketPath.png",
	"REST": "res://assets/Realistic/ui/textures/RestSitePath.png",
	"DOJO": "res://assets/Realistic/ui/textures/trainingGroundspath.png",
	"GOLD": "res://assets/Realistic/ui/textures/GamblingDenPath.png",
	"BOSS": "res://assets/Realistic/ui/textures/BossPath.png",
	"ELITE": "res://assets/Realistic/ui/textures/EliteBattlePath.png",
	"SURPRISE": "res://assets/Realistic/ui/textures/SurprisePath.png"
}

func populate(node_def) -> void:
	if not label:
		label = $Label
		
	_node_def = node_def
	# Use translation for the display name
	if node_def.boss_level > 0:
		# Boss node: format with boss level
		label.text = tr(node_def.display_name_key) % node_def.boss_level
	else:
		# Normal node: just translate the key
		label.text = tr(node_def.display_name_key)
	
	# Set placeholder color based on node type
	var bg_color = Color(0.2, 0.2, 0.2) # Default grey
	var type = node_def.node_type
	if type == "BATTLE":
		if node_def.subtype == "BOSS":
			bg_color = Color(0.4, 0.1, 0.4) # Boss Purple
		elif node_def.subtype == "ELITE":
			bg_color = Color(0.5, 0.2, 0.3) # Elite Dark Red/Purple
		else:
			bg_color = Color(0.6, 0.2, 0.2) # Battle Red
	elif type == "SHOP":
		bg_color = Color(0.5, 0.4, 0.2) # Shop Brown/Gold
	elif type == "BLACK_MARKET":
		bg_color = Color(0.12, 0.12, 0.12) # Black Market charcoal
	elif type == "REST":
		bg_color = Color(0.2, 0.3, 0.6) # Rest Blue
	elif type == "DOJO":
		bg_color = Color(0.4, 0.2, 0.6) # Dojo Purple
	elif type == "GOLD":
		bg_color = Color(0.6, 0.5, 0.2) # Gold Yellow/Brown
	elif type == "SURPRISE":
		bg_color = Color(0.2, 0.6, 0.4) # Surprise Green/Teal
	
	var bg_rect = get_node_or_null("BackgroundColor")
	if bg_rect:
		bg_rect.color = bg_color
		bg_rect.visible = true

	# Load texture based on node type
	var tex_path = ""
	if node_def.node_type == "BATTLE":
		if node_def.subtype == "BOSS":
			tex_path = CARD_TEXTURES["BOSS"]
		elif node_def.subtype == "ELITE":
			tex_path = CARD_TEXTURES["ELITE"]
		else:
			tex_path = CARD_TEXTURES["BATTLE"]
	elif CARD_TEXTURES.has(node_def.node_type):
		tex_path = CARD_TEXTURES[node_def.node_type]

	if not tex_path.is_empty():
		var tex = load(tex_path)
		if tex:
			texture_normal = tex
			# Ensure it expands
			ignore_texture_size = true
			stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			# Hide dynamic label as text is baked into the texture
			label.visible = false
			# Hide placeholder background if we have a texture
			if bg_rect:
				bg_rect.visible = false
		else:
			# If texture path defined but loading failed, ensure label is visible
			label.visible = true
	else:
		# No texture path, ensure label is visible
		label.visible = true
	
	# Allow supported path nodes to be enabled.
	disabled = not (node_def.node_type in [&"BATTLE", &"SHOP", &"BLACK_MARKET", &"REST", &"DOJO", &"GOLD", &"SURPRISE"])
	_refresh_interaction_state()

func _on_pressed() -> void:
	if disabled:
		return
	_play_select_juice()
	emit_signal("node_selected", _node_def)

func _ready() -> void:
	clip_contents = false
	_setup_interaction_shader()
	_update_pivot()
	set_process(true)

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_on_resized)

	_refresh_interaction_state()

func _on_resized() -> void:
	_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func _refresh_interaction_state() -> void:
	if disabled:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		focus_mode = Control.FOCUS_NONE
		_is_hovered = false
		_set_hover_amount(0.0)
		_set_press_amount(0.0)
		_set_perspective_tilt(Vector2.ZERO)
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL

func _setup_interaction_shader() -> void:
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = CARD_INTERACTION_SHADER
	_shader_mat.set_shader_parameter("hover_amount", 0.0)
	_shader_mat.set_shader_parameter("press_amount", 0.0)
	_shader_mat.set_shader_parameter("selection_flash", 0.0)
	_shader_mat.set_shader_parameter("pointer_uv", Vector2(0.5, 0.5))
	_shader_mat.set_shader_parameter("perspective_tilt", Vector2.ZERO)
	material = _shader_mat

func _on_mouse_entered() -> void:
	_set_hover_state(true, true)

func _on_mouse_exited() -> void:
	_set_hover_state(false, false)

func _on_focus_entered() -> void:
	_set_hover_state(true, false)

func _on_focus_exited() -> void:
	_set_hover_state(false, false)

func _on_button_down() -> void:
	if disabled:
		return
	if not _is_hovered:
		_set_hover_state(true, false) # Touch fallback where hover events may not fire.
	_animate_press_to(1.0, 0.05)
	Audio.play_sfx("ui_click", 0.93)

func _on_button_up() -> void:
	if disabled:
		return
	_animate_press_to(0.0, 0.14)
	if not get_global_rect().has_point(get_global_mouse_position()):
		_set_hover_state(false, false)

func _set_hover_state(active: bool, play_sound: bool) -> void:
	if disabled and active:
		return
	if _is_hovered == active:
		return
	_is_hovered = active
	if play_sound and active:
		Audio.play_sfx("ui_hover", randf_range(1.06, 1.14))
	_animate_hover_to(1.0 if active else 0.0, 0.16 if active else 0.12)

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

func _play_select_juice() -> void:
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, _flash_amount, 1.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_set_flash_amount, 1.0, 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if is_instance_valid(_pop_tween):
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_pop_amount, _pop_amount, 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_method(_set_pop_amount, 1.0, 0.0, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	Audio.play_sfx("ui_drag_start", 1.08)

func _set_hover_amount(value: float) -> void:
	_hover_amount = clampf(value, 0.0, 1.0)
	if _shader_mat:
		_shader_mat.set_shader_parameter("hover_amount", _hover_amount)

func _set_press_amount(value: float) -> void:
	_press_amount = clampf(value, 0.0, 1.0)
	if _shader_mat:
		_shader_mat.set_shader_parameter("press_amount", _press_amount)

func _set_flash_amount(value: float) -> void:
	_flash_amount = clampf(value, 0.0, 1.0)
	if _shader_mat:
		_shader_mat.set_shader_parameter("selection_flash", _flash_amount)

func _set_pop_amount(value: float) -> void:
	_pop_amount = clampf(value, 0.0, 1.0)

func _set_perspective_tilt(value: Vector2) -> void:
	_perspective_tilt = value
	if _shader_mat:
		_shader_mat.set_shader_parameter("perspective_tilt", _perspective_tilt)

func _update_pointer_uv(local_pos: Vector2) -> void:
	var safe_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	_pointer_uv = Vector2(
		clampf(local_pos.x / safe_size.x, 0.0, 1.0),
		clampf(local_pos.y / safe_size.y, 0.0, 1.0)
	)
	if _shader_mat:
		_shader_mat.set_shader_parameter("pointer_uv", _pointer_uv)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_pointer_uv(event.position)

func _process(delta: float) -> void:
	var blend: float = min(1.0, delta * 12.0)
	var target_pointer := Vector2(0.5, 0.5)
	if _is_hovered:
		target_pointer = Vector2(
			clampf(get_local_mouse_position().x / maxf(size.x, 1.0), 0.0, 1.0),
			clampf(get_local_mouse_position().y / maxf(size.y, 1.0), 0.0, 1.0)
		)

	_pointer_uv = _pointer_uv.lerp(target_pointer, blend)
	if _shader_mat:
		_shader_mat.set_shader_parameter("pointer_uv", _pointer_uv)

	var pointer_x = (_pointer_uv.x - 0.5) * 2.0
	var pointer_y = (_pointer_uv.y - 0.5) * 2.0
	var target_perspective = Vector2(
		pointer_x * MAX_PERSPECTIVE_X * _hover_amount,
		-pointer_y * MAX_PERSPECTIVE_Y * _hover_amount
	)
	_set_perspective_tilt(_perspective_tilt.lerp(target_perspective, blend))

	var target_tilt = (_pointer_uv.x - 0.5) * MAX_TILT_DEGREES * _hover_amount
	_tilt_degrees = lerpf(_tilt_degrees, target_tilt, blend)
	rotation = lerp_angle(rotation, deg_to_rad(_tilt_degrees), blend)

	var hover_scale = 1.0 + (HOVER_SCALE * _hover_amount)
	var press_scale = 1.0 - (PRESS_SQUASH * _press_amount)
	var pop_scale = 1.0 + (POP_SCALE * _pop_amount)
	var stretch_x = 1.0 + (_press_amount * 0.05)
	var stretch_y = 1.0 - (_press_amount * 0.07)
	var final_scale = hover_scale * press_scale * pop_scale
	scale = Vector2(final_scale * stretch_x, final_scale * stretch_y)
