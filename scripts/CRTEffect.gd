extends CanvasLayer

## Global CRT post-process overlay and persistent toggle state.

signal crt_toggled(enabled: bool)
signal glow_toggled(enabled: bool)
signal glow_debug_view_changed(view: int)

const SETTINGS_PATH := "user://display_settings.save"
const CRT_SHADER_PATH := "res://assets/shaders/crt_display.gdshader"
const CRT_LAYER := 200
const GLOW_DEBUG_VIEW_NORMAL := 0
const GLOW_DEBUG_VIEW_SOURCE_MASK := 1
const GLOW_DEBUG_VIEW_WEIGHT_MASK := 2

var _crt_enabled: bool = true
var _glow_enabled: bool = true
var _glow_debug_view: int = GLOW_DEBUG_VIEW_NORMAL
var _overlay: ColorRect = null


func _enter_tree() -> void:
	layer = CRT_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()


func _ready() -> void:
	_create_overlay_if_missing()
	_apply_overlay_state()


func is_enabled() -> bool:
	return _crt_enabled

func is_glow_enabled() -> bool:
	return _glow_enabled

func get_glow_debug_view() -> int:
	return _glow_debug_view


func set_enabled(enabled: bool, save_setting: bool = true) -> void:
	if _crt_enabled == enabled:
		_apply_overlay_state()
		return
	
	_crt_enabled = enabled
	_apply_overlay_state()
	if save_setting:
		_save_settings()
	crt_toggled.emit(_crt_enabled)

func set_glow_enabled(enabled: bool, save_setting: bool = true) -> void:
	if _glow_enabled == enabled:
		return
	
	_glow_enabled = enabled
	if save_setting:
		_save_settings()
	glow_toggled.emit(_glow_enabled)

func toggle() -> void:
	set_enabled(not _crt_enabled)

func toggle_glow() -> void:
	set_glow_enabled(not _glow_enabled)

func set_glow_debug_view(view: int, save_setting: bool = true) -> void:
	view = clampi(view, GLOW_DEBUG_VIEW_NORMAL, GLOW_DEBUG_VIEW_WEIGHT_MASK)
	if _glow_debug_view == view:
		_apply_overlay_state()
		glow_debug_view_changed.emit(_glow_debug_view)
		return

	_glow_debug_view = view
	_apply_overlay_state()
	if save_setting:
		_save_settings()
	glow_debug_view_changed.emit(_glow_debug_view)


func _create_overlay_if_missing() -> void:
	if is_instance_valid(_overlay):
		return
	
	var shader: Shader = load(CRT_SHADER_PATH)
	if shader == null:
		push_error("[CRTEffect] Missing shader at %s" % CRT_SHADER_PATH)
		return
	
	var material := ShaderMaterial.new()
	material.shader = shader
	
	_overlay = ColorRect.new()
	_overlay.name = "CRTEffectOverlay"
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	_overlay.material = material
	_overlay.z_index = 4096
	add_child(_overlay)


func _apply_overlay_state() -> void:
	if is_instance_valid(_overlay):
		# Glow debug views need the raw glow pass. Leaving CRT enabled makes the
		# diagnostic unreadable because the CRT shader reprocesses the debug mask.
		_overlay.visible = _crt_enabled and _glow_debug_view == GLOW_DEBUG_VIEW_NORMAL


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[CRTEffect] Failed to write settings file: %s" % SETTINGS_PATH)
		return
	file.store_var({
		"crt_enabled": _crt_enabled,
		"glow_enabled": _glow_enabled,
		"glow_debug_view": _glow_debug_view
	})
	file.close()


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("[CRTEffect] Failed to read settings file: %s" % SETTINGS_PATH)
		return
	
	var data: Variant = file.get_var()
	file.close()
	
	if data is Dictionary:
		_crt_enabled = bool(data.get("crt_enabled", true))
		_glow_enabled = bool(data.get("glow_enabled", true))
		_glow_debug_view = clampi(int(data.get("glow_debug_view", GLOW_DEBUG_VIEW_NORMAL)), GLOW_DEBUG_VIEW_NORMAL, GLOW_DEBUG_VIEW_WEIGHT_MASK)
