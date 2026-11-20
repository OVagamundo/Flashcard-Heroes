extends Control

const TOKEN_SHEET: Texture2D = preload("res://assets/PixelArt/ui/textures/TokenRotationSpriteSheet.png")
const FRAME_COUNT: int = 5
const TOKEN_DIAMETER: float = 36.0
const TOKEN_SCALE: float = TOKEN_DIAMETER / 61.0
# Alternate the edge, tilted, and face views so small piles have a mix of poses.
const RESTING_FRAMES: Array[int] = [2, 1, 3, 2, 4, 1, 2, 0]
const FRAME_WIDTH_SCALES: Array[float] = [1.0, 0.62, 1.0, 0.68, 1.0]
const COLLISION_LAYER: int = 1 << 8
const LIP: float = 10.0
const DROP_INTERVAL: float = 0.065
const MAX_DROP_STAGGER: float = 0.65

var _coins: Array[RigidBody2D] = []
var _frame_size: Vector2i
var _frame_bounds: Array[Rect2i] = []
var _coin_shapes: Array[CapsuleShape2D] = []
var _coin_material: PhysicsMaterial = PhysicsMaterial.new()
var _floor: CollisionShape2D
var _left_wall: CollisionShape2D
var _right_wall: CollisionShape2D
var _front: Control
@onready var _count_display: HBoxContainer = $CountDisplay
@onready var _count: Label = $CountDisplay/Count

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_coin_material.friction = 0.35
	_coin_material.bounce = 0.2
	_prepare_coin_frames()

	var bounds := StaticBody2D.new()
	bounds.collision_layer = COLLISION_LAYER
	bounds.collision_mask = COLLISION_LAYER
	add_child(bounds)
	_floor = _add_wall(bounds)
	_left_wall = _add_wall(bounds)
	_right_wall = _add_wall(bounds)

	_front = Control.new()
	_front.z_index = 1
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	_front.draw.connect(_draw_front)

	resized.connect(_update_geometry)
	_update_geometry()
	set_balance(0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.69, 0.76, 0.25))

func _draw_front() -> void:
	var color := Color(0.65, 0.90, 0.94, 0.92)
	_front.draw_rect(Rect2(0.0, size.y - 14.0, size.x, 14.0), Color(0.47, 0.76, 0.82, 0.32))
	_front.draw_rect(Rect2(Vector2.ZERO, size), color, false, 3.0)
	_front.draw_line(Vector2(0.0, size.y - 4.0), Vector2(size.x, size.y - 4.0), color, 4.0)

func _add_wall(body: StaticBody2D) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	body.add_child(collision)
	return collision

func _update_geometry() -> void:
	_position_wall(_floor, Vector2(size.x * 0.5, size.y - LIP * 0.5), Vector2(size.x, LIP))
	_position_wall(_left_wall, Vector2(LIP * 0.5, 0.0), Vector2(LIP, size.y * 2.0))
	_position_wall(_right_wall, Vector2(size.x - LIP * 0.5, 0.0), Vector2(LIP, size.y * 2.0))
	queue_redraw()
	_front.queue_redraw()

func _position_wall(wall: CollisionShape2D, center: Vector2, extent: Vector2) -> void:
	var shape: RectangleShape2D = wall.shape as RectangleShape2D
	shape.size = extent
	wall.position = center

func get_currency_origin() -> Vector2:
	return get_global_transform() * Vector2(size.x * 0.5, size.y - 50.0)

func get_count_feedback_control() -> Control:
	return _count_display

func set_balance(amount: int) -> void:
	assert(amount >= 0, "Token tray requires a non-negative balance")
	_count.text = str(amount)
	while _coins.size() > amount:
		var coin: RigidBody2D = _coins.pop_back()
		coin.queue_free()
	var first_coin: int = _coins.size()
	var batch_interval: float = MAX_DROP_STAGGER / maxi(1, amount - first_coin - 1)
	var drop_interval: float = AnimationConstants.scaled(minf(DROP_INTERVAL, batch_interval))
	for index: int in range(first_coin, amount):
		_spawn_coin(index, (index - first_coin) * drop_interval)

func _prepare_coin_frames() -> void:
	var sheet: Image = TOKEN_SHEET.get_image()
	var frame_width: int = floori(float(sheet.get_width()) / FRAME_COUNT)
	_frame_size = Vector2i(frame_width, sheet.get_height())
	for frame: int in range(FRAME_COUNT):
		var tile: Image = sheet.get_region(Rect2i(Vector2i(frame * _frame_size.x, 0), _frame_size))
		var bounds: Rect2i = tile.get_used_rect()
		_frame_bounds.append(bounds)
		var shape := CapsuleShape2D.new()
		shape.radius = bounds.size.x * TOKEN_SCALE * FRAME_WIDTH_SCALES[frame] * 0.5
		shape.height = bounds.size.y * TOKEN_SCALE
		_coin_shapes.append(shape)

func _spawn_coin(index: int, delay: float) -> void:
	var coin := RigidBody2D.new()
	coin.collision_layer = COLLISION_LAYER
	coin.collision_mask = COLLISION_LAYER
	coin.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	coin.physics_material_override = _coin_material
	coin.linear_damp = 1.3
	coin.angular_damp = 4.0
	coin.freeze = true
	coin.hide()
	add_child(coin)
	_coins.append(coin)

	var sprite := Sprite2D.new()
	sprite.texture = TOKEN_SHEET
	sprite.hframes = FRAME_COUNT
	sprite.rotation = PI * 0.5
	coin.add_child(sprite)

	var drop: Tween = coin.create_tween()
	drop.tween_callback(_drop_coin.bind(coin, sprite, index)).set_delay(delay)

func _drop_coin(coin: RigidBody2D, sprite: Sprite2D, index: int) -> void:
	if coin.is_queued_for_deletion():
		return
	var rng: SeededRNG = RNGManager.cosmetic_rng
	var inset: float = LIP + TOKEN_DIAMETER * 0.5 + 2.0
	var drift: float = rng.randf_range(-75.0, 75.0)
	var drop_x: float = rng.randf_range(inset, size.x - inset)
	if index > 0:
		var target: RigidBody2D = _coins[rng.randi_range(0, index - 1)]
		if not target.freeze:
			drop_x = clampf(target.position.x - drift * 0.12, inset, size.x - inset)
	var drop_y: float = size.y * 0.38 + rng.randf_range(-9.0, 9.0)
	# Keep room above the moving pile so the incoming coin can hit it mid-fall.
	for other: RigidBody2D in _coins:
		if not other.freeze and absf(drop_x - other.position.x) < TOKEN_DIAMETER:
			drop_y = minf(drop_y, other.position.y - TOKEN_DIAMETER - 8.0)
			other.sleeping = false

	var resting_frame: int = RESTING_FRAMES[index % RESTING_FRAMES.size()]
	coin.position = Vector2(drop_x, drop_y)
	coin.rotation = rng.randf_range(-0.95, 0.95)
	var collider := CollisionShape2D.new()
	collider.shape = _coin_shapes[resting_frame]
	collider.rotation = PI * 0.5
	coin.add_child(collider)
	coin.reset_physics_interpolation()
	coin.freeze = false
	coin.linear_velocity = Vector2(drift, rng.randf_range(140.0, 215.0))
	coin.angular_velocity = rng.randf_range(-8.0, 8.0)
	_set_coin_frame(resting_frame + 1, sprite)
	coin.show()

	var spin: Tween = coin.create_tween()
	spin.tween_method(_set_coin_frame.bind(sprite), resting_frame + 1, resting_frame + FRAME_COUNT, AnimationConstants.scaled(0.16))

func _set_coin_frame(step: int, sprite: Sprite2D) -> void:
	var frame: int = step % FRAME_COUNT
	var bounds: Rect2i = _frame_bounds[frame]
	sprite.frame = frame
	sprite.offset = Vector2(_frame_size - bounds.size) * 0.5 - Vector2(bounds.position)
	sprite.scale = Vector2(FRAME_WIDTH_SCALES[frame], 1.0) * TOKEN_SCALE
