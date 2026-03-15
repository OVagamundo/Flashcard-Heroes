class_name GachaBallCapsuleGlow
extends RefCounted

const GLOW_SHADER := preload("res://assets/shaders/gachaball_capsule_glow.gdshader")
const GLOW_RADIUS_PX := 14.0
const GLOW_INTENSITY := 0.6
const GLOW_FALLOFF_POWER := 3.0

static func apply_to_sprite(sprite: Sprite2D) -> void:
	if not _should_use_local_capsule_glow():
		return
	if not is_instance_valid(sprite) or not is_instance_valid(sprite.texture):
		return

	var material := _ensure_glow_material(sprite)
	_configure_material(material, sprite.texture.get_size(), _abs_vec2(sprite.scale), CRTEffect.is_glow_enabled())
	_remove_legacy_glow_child(sprite)

static func apply_to_texture_rect(rect: TextureRect) -> void:
	if not _should_use_local_capsule_glow():
		return
	if not is_instance_valid(rect) or not is_instance_valid(rect.texture):
		return

	var material := _ensure_glow_material(rect)
	_configure_material(material, _get_rect_source_size(rect), Vector2.ONE, CRTEffect.is_glow_enabled())
	_remove_legacy_glow_child(rect)

static func set_sprite_glow_enabled(sprite: Sprite2D, enabled: bool) -> void:
	if not _should_use_local_capsule_glow():
		return
	if not is_instance_valid(sprite):
		return
	var material := _ensure_glow_material(sprite)
	_configure_material(material, sprite.texture.get_size(), _abs_vec2(sprite.scale), enabled)

static func set_texture_glow_enabled(rect: TextureRect, enabled: bool) -> void:
	if not _should_use_local_capsule_glow():
		return
	if not is_instance_valid(rect):
		return
	var material := _ensure_glow_material(rect)
	_configure_material(material, _get_rect_source_size(rect), Vector2.ONE, enabled)

static func _ensure_glow_material(item: CanvasItem) -> ShaderMaterial:
	var material = item.material as ShaderMaterial
	if material != null and material.shader == GLOW_SHADER:
		return material

	material = ShaderMaterial.new()
	material.shader = GLOW_SHADER
	item.material = material
	return material

static func _configure_material(material: ShaderMaterial, source_size: Vector2, source_scale: Vector2, glow_enabled: bool) -> void:
	var safe_size = Vector2(maxf(source_size.x, 1.0), maxf(source_size.y, 1.0))
	var safe_scale = Vector2(maxf(source_scale.x, 0.0001), maxf(source_scale.y, 0.0001))
	var expansion = Vector2(GLOW_RADIUS_PX / safe_scale.x, GLOW_RADIUS_PX / safe_scale.y)

	material.set_shader_parameter("source_pixel_size", Vector2(1.0 / safe_size.x, 1.0 / safe_size.y))
	material.set_shader_parameter("expansion", expansion)
	material.set_shader_parameter("glow_intensity", GLOW_INTENSITY if glow_enabled else 0.0)
	material.set_shader_parameter("falloff_power", GLOW_FALLOFF_POWER)

static func _get_rect_source_size(rect: TextureRect) -> Vector2:
	var base_size = rect.size
	if base_size == Vector2.ZERO:
		base_size = rect.custom_minimum_size
	if base_size == Vector2.ZERO and is_instance_valid(rect.texture):
		base_size = rect.texture.get_size()
	return base_size

static func _remove_legacy_glow_child(item: Node) -> void:
	var legacy_child = item.get_node_or_null("_CapsuleGlowLayer")
	if is_instance_valid(legacy_child):
		legacy_child.queue_free()

static func _abs_vec2(value: Vector2) -> Vector2:
	return Vector2(absf(value.x), absf(value.y))

static func _should_use_local_capsule_glow() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
