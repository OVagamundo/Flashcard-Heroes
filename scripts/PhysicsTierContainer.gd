class_name PhysicsTierContainer
extends Control

@export var tier: int = 1
# NEW: Export variables to manually tune the physics inset to match your texture walls
@export var left_wall_padding: float = -14.0
@export var right_wall_padding: float = -14.0
@export var bottom_wall_padding: float = 15.0
@export var side_wall_thickness: float = 100.0
@export var floor_thickness: float = 500.0
@export var spawn_y: float = -60.0
@export var use_static_bounds: bool = false
@export var show_overflow_visual: bool = true

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var drop_timer: Timer = $DropTimer
@onready var bounds_body: StaticBody2D = $Bounds
@onready var lid_area: Area2D = $LidArea

const PhysicsBallScene = preload("res://scenes/PhysicsGachaBall.tscn")

var _active_balls: Dictionary = {}
var _penalty_timers: Dictionary = {}
var _spawn_queue: Array = [] # Holds GachaBallInstances
# Safeguard: remembers the maximum height the drawer has ever reached
var _max_y_seen: float = 0.0

var _global_sleep_timer: Timer
var _bounce_tween: Tween
var _balls_root: Node2D

func _ready() -> void:
	# HIGH-FIDELITY: Enable physics interpolation for smooth movement
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	_balls_root = get_node_or_null("BallsRoot")
	if not _balls_root:
		_balls_root = Node2D.new()
		_balls_root.name = "BallsRoot"
		add_child(_balls_root)
	_balls_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	
	# AUTOMATIC SLEEP: 6s countdown to force-sleep the entire pile after settling
	_global_sleep_timer = Timer.new()
	_global_sleep_timer.one_shot = true
	_global_sleep_timer.wait_time = 6.0
	_global_sleep_timer.timeout.connect(_on_global_sleep_timeout)
	add_child(_global_sleep_timer)
	
	# React dynamically to UI layout changes
	resized.connect(_on_resized)
	
	var bound_layer = 10 + ((tier - 1) * 2)
	var ball_layer = 11 + ((tier - 1) * 2)
	
	bounds_body.collision_layer = (1 << (bound_layer - 1))
	bounds_body.collision_mask = (1 << (ball_layer - 1))
	
	lid_area.collision_layer = 0
	lid_area.collision_mask = (1 << (ball_layer - 1))
	
	# Force an initial bounds generation to set up visuals and safeguards
	_generate_u_shape_bounds()

func refresh_runtime_bounds() -> void:
	# Always allow manual refresh to regenerate boundaries
	_generate_u_shape_bounds()

func _on_resized() -> void:
	if use_static_bounds:
		return
	# Only generate geography when the UI provides a real layout space
	if size.x > 10.0 and size.y > 10.0:
		if size.y > _max_y_seen:
			_max_y_seen = size.y
		_generate_u_shape_bounds()

func _generate_u_shape_bounds() -> void:
	var t_side = side_wall_thickness
	var t_bottom = floor_thickness
	
	var safe_y = maxf(size.y, _max_y_seen)
	
	var inner_left = left_wall_padding
	var inner_right = size.x - right_wall_padding
	var inner_bottom = safe_y - bottom_wall_padding
	
	var left_wall = _get_or_create_wall("LeftWall")
	left_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	left_wall.position = Vector2(inner_left - (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	var right_wall = _get_or_create_wall("RightWall")
	right_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	right_wall.position = Vector2(inner_right + (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	var floor_wall = _get_or_create_wall("FloorWall")
	floor_wall.shape.size = Vector2(inner_right - inner_left + (t_side * 2.0), t_bottom)
	floor_wall.position = Vector2(size.x / 2.0, inner_bottom + (t_bottom / 2.0))
	
	# HARD LID: Prevent balls flying out during high-energy jolts
	var hard_lid = _get_or_create_wall("HardLid")
	hard_lid.shape.size = Vector2(inner_right - inner_left, 5000.0)
	hard_lid.position = Vector2(size.x / 2.0, -2500.0)
	
	spawn_point.position = Vector2(size.x / 2.0, spawn_y)
	
	# OVERFLOW MECHANISM: 30px detection zone at the lid
	lid_area.position = Vector2(size.x / 2.0, 15.0)
	
	var lid_shape_node = _get_or_create_lid_shape()
	lid_shape_node.shape.size = Vector2(inner_right - inner_left, 30.0)
	
	# VISUAL: Translucent red indicator for the overflow area
	var visual_name = "OverflowVisual"
	var visual = lid_area.get_node_or_null(visual_name) as ColorRect
	if not visual:
		visual = ColorRect.new()
		visual.name = visual_name
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid_area.add_child(visual)
	
	visual.color = Color(1.0, 0.0, 0.0, 0.4)
	visual.size = lid_shape_node.shape.size
	visual.position = -visual.size / 2.0
	visual.visible = show_overflow_visual
	
	# Clean up any leftover concave polygons
	for child in bounds_body.get_children():
		if child is CollisionPolygon2D:
			child.queue_free()

func _get_or_create_wall(wall_name: String) -> CollisionShape2D:
	var wall = bounds_body.get_node_or_null(wall_name) as CollisionShape2D
	if not wall:
		wall = CollisionShape2D.new()
		wall.name = wall_name
		wall.shape = RectangleShape2D.new()
		bounds_body.add_child(wall)
	return wall

func _get_or_create_lid_shape() -> CollisionShape2D:
	var shape_node: CollisionShape2D
	if lid_area.get_child_count() > 0:
		for child in lid_area.get_children():
			if child is CollisionShape2D:
				shape_node = child
				break
	if not shape_node:
		shape_node = CollisionShape2D.new()
		shape_node.shape = RectangleShape2D.new()
		lid_area.add_child(shape_node)
	return shape_node

func sync_state(tier_instances: Array) -> void:
	var target_uuids = []
	var to_spawn = []
	
	var queued_uuids = []
	for item in _spawn_queue:
		if is_instance_valid(item):
			queued_uuids.append(item.ball_uuid)
	
	for inst in tier_instances:
		if not is_instance_valid(inst): continue
		target_uuids.append(inst.ball_uuid)
		
		if not _active_balls.has(inst.ball_uuid) and not queued_uuids.has(inst.ball_uuid):
			to_spawn.append(inst)
			
	for i in range(_spawn_queue.size() - 1, -1, -1):
		var inst = _spawn_queue[i]
		if not is_instance_valid(inst) or not target_uuids.has(inst.ball_uuid):
			_spawn_queue.remove_at(i)
			
	var current_uuids = _active_balls.keys()
	for uuid in current_uuids:
		if not target_uuids.has(uuid):
			if is_instance_valid(_active_balls[uuid]):
				_active_balls[uuid].queue_free()
			_active_balls.erase(uuid)
			_penalty_timers.erase(uuid)
			
	if to_spawn.size() > 0:
		_spawn_queue.append_array(to_spawn)
		if drop_timer.is_stopped():
			drop_timer.start()

func clear() -> void:
	_spawn_queue.clear()
	for uuid in _active_balls:
		if is_instance_valid(_active_balls[uuid]):
			_active_balls[uuid].queue_free()
	_active_balls.clear()
	_penalty_timers.clear()
	drop_timer.stop()

func _on_drop_timer_timeout() -> void:
	if _spawn_queue.is_empty():
		drop_timer.stop()
		return
	_spawn_ball(_spawn_queue.pop_front())

func _spawn_ball(inst) -> void:
	if not is_instance_valid(inst): return
	var ball = PhysicsBallScene.instantiate()
	
	var ball_layer = 11 + ((tier - 1) * 2)
	var bound_layer = 10 + ((tier - 1) * 2)
	
	ball.collision_layer = (1 << (ball_layer - 1))
	ball.collision_mask = (1 << (bound_layer - 1)) | (1 << (ball_layer - 1))
	
	# CCD: Prevent tunneling during high-velocity drops
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	var def = inst.get_definition()
	ball.populate(inst.ball_uuid, def.category, inst.get_location(), def.icon)
	
	# INTERPOLATION: Turn on to smooth RigidBody jitter
	ball.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	ball.position = spawn_point.position
	ball.position.x += randf_range(-150.0, 150.0) # Wider spread for better pile distribution
	
	_balls_root.add_child(ball)
	
	# RESET: Prevent visual streaking from initial teleport
	ball.reset_physics_interpolation()
	
	# SOFT-SPAWN: Gradual collision scaling handles crowded piles gracefully
	ball.spawn_in(0.5)
	
	_active_balls[inst.ball_uuid] = ball

func _physics_process(delta: float) -> void:
	_check_out_of_bounds()
	
	var overlapping = lid_area.get_overlapping_bodies()
	var current_overlapping_uuids = []
	
	for body in overlapping:
		if body is PhysicsGachaBall:
			var uuid = body.instance_uuid
			current_overlapping_uuids.append(uuid)
			if not _penalty_timers.has(uuid):
				_penalty_timers[uuid] = 0.0
			
			_penalty_timers[uuid] += delta
			
			if _penalty_timers[uuid] >= 5.0:
				SignalBus.emit_signal("inventory_instance_removed_penalty", uuid)
				_penalty_timers.erase(uuid)
				
	var tracked_uuids = _penalty_timers.keys()
	for uuid_to_check in tracked_uuids:
		if not current_overlapping_uuids.has(uuid_to_check):
			_penalty_timers.erase(uuid_to_check)

func _check_out_of_bounds() -> void:
	if size.x <= 10.0 or size.y <= 10.0:
		return
		
	var safe_margin = 300.0
	var min_x = - safe_margin
	var max_x = size.x + safe_margin
	var min_y = - safe_margin * 2.0
	
	var safe_y = maxf(size.y, _max_y_seen)
	var max_y = safe_y + safe_margin
	
	var objects_to_recover: Array[PhysicsGachaBall] = []
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			var pos = ball.position
			if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
				objects_to_recover.append(ball)
				
	for ball in objects_to_recover:
		var uuid = ball.instance_uuid
		_active_balls.erase(uuid)
		_penalty_timers.erase(uuid)
		
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			var inst = bm.get_instance(uuid)
			if is_instance_valid(inst):
				_spawn_queue.push_back(inst)
				if drop_timer.is_stopped():
					drop_timer.start()
		
		ball.queue_free()
		if Engine.has_singleton("BattleLogger"):
			BattleLogger.log_message("[color=yellow]SAFEGUARD:[/color] Gachaball recovered and re-spawned.")

func _on_global_sleep_timeout() -> void:
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			ball.sleeping = true

func apply_jolt(base_impulse: Vector2) -> void:
	for ball in _active_balls.values():
		if is_instance_valid(ball) and ball is RigidBody2D:
			var random_variance = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			ball.apply_central_impulse(base_impulse + random_variance)
			ball.apply_torque_impulse(randf_range(-1000, 1000))

func prepare_for_open() -> void:
	_global_sleep_timer.stop()
	
	if _bounce_tween:
		_bounce_tween.kill()
		
	# LIVELY: Set shared material to bouncy during movement
	var mat = preload("res://resources/physics/GachaBallMaterial.tres")
	mat.bounce = 0.8
	
	# Wake all balls
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			ball.sleeping = false

func finish_open() -> void:
	# Start sleep countdown
	_global_sleep_timer.start()
	
	# DEADEN: Smoothly decay bounce to 0.15 over 5.0s
	var mat = preload("res://resources/physics/GachaBallMaterial.tres")
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(mat, "bounce", 0.15, 5.0)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
