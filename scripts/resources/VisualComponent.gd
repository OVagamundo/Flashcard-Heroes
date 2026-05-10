class_name VisualComponent
extends GachaBallComponent

@export var shader: Shader
@export var shader_path: String = ""
@export var shader_params: Dictionary = {}
@export var modulate: Color = Color.WHITE
@export var overlay_icon: Texture2D
@export var overlay_icon_path: String = ""
@export var vfx_scene: PackedScene
@export var vfx_scene_path: String = ""
@export var layer: int = 0


func get_component_type() -> StringName:
	return &"visual"


func to_save_dict() -> Dictionary:
	var data := _get_base_save_dict()
	data["shader_path"] = shader_path
	data["shader_params"] = shader_params.duplicate(true)
	data["modulate"] = [modulate.r, modulate.g, modulate.b, modulate.a]
	data["overlay_icon_path"] = overlay_icon_path
	data["vfx_scene_path"] = vfx_scene_path
	data["layer"] = layer
	return data


func load_component_save_dict(data: Dictionary) -> void:
	shader_path = data.get("shader_path", "")
	shader_params = data.get("shader_params", {}).duplicate(true)
	var color_data: Array = data.get("modulate", [1.0, 1.0, 1.0, 1.0])
	if color_data.size() >= 4:
		modulate = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))
	overlay_icon_path = data.get("overlay_icon_path", "")
	vfx_scene_path = data.get("vfx_scene_path", "")
	layer = int(data.get("layer", 0))
	_resolve_resources()


func _resolve_resources() -> void:
	if not shader_path.is_empty():
		shader = load(shader_path)
	if not overlay_icon_path.is_empty():
		overlay_icon = load(overlay_icon_path)
	if not vfx_scene_path.is_empty():
		vfx_scene = load(vfx_scene_path)
