extends RefCounted

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/sprite_outline.gdshader")
const PADDING: int = 5
const FOCUS_WIDTH: float = 2.0
static var _padded_textures: Dictionary[Texture2D, Texture2D] = {}
static var _focus_material: ShaderMaterial

static func set_highlight(art: CanvasItem, enabled: bool) -> void:
	var outline: Node2D = art.get_node_or_null("FocusOutline") as Node2D
	if enabled and outline == null:
		outline = Node2D.new()
		outline.name = "FocusOutline"
		outline.show_behind_parent = true
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _focus_material == null:
			_focus_material = ShaderMaterial.new()
			_focus_material.shader = OUTLINE_SHADER
			_focus_material.set_shader_parameter("outline_enabled", true)
			_focus_material.set_shader_parameter("outline_width", FOCUS_WIDTH)
			_focus_material.set_shader_parameter("outline_only", true)
		outline.material = _focus_material
		outline.draw.connect(_draw_outline.bind(outline, art))
		art.add_child(outline)
		art.draw.connect(outline.queue_redraw)
	if outline != null:
		outline.visible = enabled
		outline.queue_redraw()

static func padded_texture(source: Texture2D) -> Texture2D:
	if not _padded_textures.has(source):
		var image: Image = source.get_image()
		assert(not image.is_empty(), "SpriteOutline requires a readable source texture")
		image.convert(Image.FORMAT_RGBA8)
		var padding := Vector2i(PADDING, PADDING)
		var padded_size: Vector2i = image.get_size() + padding * 2
		var padded: Image = Image.create(padded_size.x, padded_size.y, false, Image.FORMAT_RGBA8)
		padded.fill(Color.TRANSPARENT)
		padded.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), padding)
		_padded_textures[source] = ImageTexture.create_from_image(padded)
	return _padded_textures[source]

static func _draw_outline(outline: Node2D, art: CanvasItem) -> void:
	var texture: Texture2D
	var rect: Rect2
	var flip: Vector2
	if art is TextureRect:
		texture = art.texture
		if texture == null or art.size.x <= 0.0 or art.size.y <= 0.0:
			return
		rect = Rect2(Vector2.ZERO, art.size)
		if art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			var source_size: Vector2 = texture.get_size()
			var fitted: Vector2 = source_size * minf(art.size.x / source_size.x, art.size.y / source_size.y)
			rect = Rect2((art.size - fitted) * 0.5, fitted)
		else:
			assert(art.stretch_mode == TextureRect.STRETCH_SCALE, "Unsupported TextureRect stretch mode for SpriteOutline")
		flip = Vector2(-1.0 if art.flip_h else 1.0, -1.0 if art.flip_v else 1.0)
	else:
		var sprite: Sprite2D = art as Sprite2D
		assert(sprite != null, "SpriteOutline must be attached to a TextureRect or Sprite2D")
		texture = sprite.texture
		if texture == null:
			return
		rect = sprite.get_rect()
		flip = Vector2(-1.0 if sprite.flip_h else 1.0, -1.0 if sprite.flip_v else 1.0)
	var padding: Vector2 = rect.size / texture.get_size() * float(PADDING)
	var padded_size: Vector2 = rect.size + padding * 2.0
	outline.draw_set_transform(rect.get_center(), 0.0, flip)
	outline.draw_texture_rect(padded_texture(texture), Rect2(-padded_size * 0.5, padded_size), false)
