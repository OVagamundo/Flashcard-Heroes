class_name BattleInventoryTrayRig
extends Node2D

const PhysicsBallScene = preload("res://scenes/PhysicsGachaBall.tscn")

@export var tier: int = 1
@export var container_size: Vector2 = Vector2(640, 680)
@export var left_wall_padding: float = 14.0
@export var right_wall_padding: float = 14.0
@export var bottom_wall_padding: float = 15.0
@export var side_wall_thickness: float = 5000.0
@export var floor_thickness: float = 5000.0
@export var spawn_y: float = 250.0
@export var back_texture: Texture2D
@export var overlay_texture: Texture2D

@onready var motion_body: AnimatableBody2D = $MotionBody
@onready var spawn_point: Marker2D = $MotionBody/SpawnPoint
@onready var lid_area: Area2D = $MotionBody/LidArea
@onready var balls_root: Node2D = $BallsRoot
@onready var drop_timer: Timer = $DropTimer
@onready var back_art: Sprite2D = $MotionBody/BackArt
@onready var front_overlay: Sprite2D = $MotionBody/FrontOverlay

var _is_moving: bool = false

var _penalties_active: bool = false
var _active_balls: Dictionary = {}
var _global_sleep_timer: Timer
var _bounce_tween: Tween
var _penalty_timers: Dictionary = {}
var _spawn_queue: Array = []

func _ready() -> void:
	
	motion_body.sync_to_physics = true
	motion_body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	balls_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	drop_timer.wait_time = 0.15
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	
	_global_sleep_timer = Timer.new()
	_global_sleep_timer.one_shot = true
	_global_sleep_timer.wait_time = 6.0
	_global_sleep_timer.timeout.connect(_on_global_sleep_timeout)
	add_child(_global_sleep_timer)
	
	SignalBus.battle_inventory_transition_started.connect(_on_battle_transition_started)
	SignalBus.battle_inventory_transition_finished.connect(_on_battle_transition_finished)
	
	if is_instance_valid(back_texture):
		back_art.texture = back_texture
	if is_instance_valid(overlay_texture):
		front_overlay.texture = overlay_texture
		
	# Offset sprites to treat Node2D origin as top-center of container
	back_art.position = Vector2(container_size.x / 2.0, container_size.y / 2.0)
	front_overlay.position = Vector2(container_size.x / 2.0, container_size.y / 2.0)
	
	_generate_bounds()
	set_overflow_monitoring_active(false)

func set_overflow_monitoring_active(active: bool) -> void:
	_penalties_active = active
	if not active:
		_penalty_timers.clear()
	
	# Sync visual visibility
	if is_instance_valid(lid_area):
		var visual = lid_area.get_node_or_null("OverflowVisual") as ColorRect
		if visual:
			visual.visible = active

func _generate_bounds() -> void:
	var bound_layer = 10 + ((tier - 1) * 2)
	var ball_layer = 11 + ((tier - 1) * 2)
	
	motion_body.collision_layer = (1 << (bound_layer - 1))
	motion_body.collision_mask = (1 << (ball_layer - 1))
	
	lid_area.collision_layer = 0
	lid_area.collision_mask = (1 << (ball_layer - 1))
	
	var safe_y = container_size.y
	var inner_left = left_wall_padding
	var inner_right = container_size.x - right_wall_padding
	var inner_bottom = safe_y - bottom_wall_padding
	
	var t_side = side_wall_thickness
	var t_bottom = floor_thickness
	
	var left_wall = _get_or_create_wall("LeftWall")
	left_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	left_wall.position = Vector2(inner_left - (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	var right_wall = _get_or_create_wall("RightWall")
	right_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	right_wall.position = Vector2(inner_right + (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	var floor_wall = _get_or_create_wall("FloorWall")
	floor_wall.shape.size = Vector2(inner_right - inner_left + (t_side * 2.0), t_bottom)
	floor_wall.position = Vector2(container_size.x / 2.0, inner_bottom + (t_bottom / 2.0))
	
	var hard_lid = _get_or_create_wall("HardLid")
	hard_lid.shape.size = Vector2(inner_right - inner_left, 5000.0)
	hard_lid.position = Vector2(container_size.x / 2.0, -2500.0) # Massive buffer blocks balls from flying out top
	
	spawn_point.position = Vector2(container_size.x / 2.0, spawn_y)
	
	# OVERFLOW MECHANISM: 30px detection area positioned below the lid (y=0)
	# Position at y=15.0 with height=30.0 covers from y=0 to y=30
	lid_area.position = Vector2(container_size.x / 2.0, 15.0)
	
	var lid_shape_node = _get_or_create_area_shape(lid_area)
	lid_shape_node.shape.size = Vector2(inner_right - inner_left, 30.0)
	
	# VISUAL: Translucent red rectangle for the overflow area
	var visual_name = "OverflowVisual"
	var visual = lid_area.get_node_or_null(visual_name) as ColorRect
	if not visual:
		visual = ColorRect.new()
		visual.name = visual_name
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid_area.add_child(visual)
	
	visual.color = Color(1.0, 0.0, 0.0, 0.4) # Translucent red
	visual.size = lid_shape_node.shape.size
	visual.position = -visual.size / 2.0
	
	# Only show visual if penalties are active
	visual.visible = _penalties_active

func _get_or_create_wall(wall_name: String) -> CollisionShape2D:
	var wall = motion_body.get_node_or_null(wall_name) as CollisionShape2D
	if not wall:
		wall = CollisionShape2D.new()
		wall.name = wall_name
		wall.shape = RectangleShape2D.new()
		motion_body.add_child(wall)
	return wall

func _get_or_create_area_shape(area: Area2D) -> CollisionShape2D:
	var shape_node: CollisionShape2D
	if area.get_child_count() > 0:
		shape_node = area.get_child(0) as CollisionShape2D
	if not shape_node:
		shape_node = CollisionShape2D.new()
		shape_node.shape = RectangleShape2D.new()
		area.add_child(shape_node)
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
		
		# Only spawn if it isn't active AND isn't already queued
		if not _active_balls.has(inst.ball_uuid) and not queued_uuids.has(inst.ball_uuid):
			to_spawn.append(inst)
			
	# Prune obsolete items that were removed while waiting in the spawn queue
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
	ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	
	var def = inst.get_definition()
	ball.populate(inst.ball_uuid, def.category, inst.get_location(), def.icon, inst.variant_id)
	
	# Turn interpolation on to smooth Godot rigid jitter
	ball.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	# SUIKA STYLE PHYSICS SPREAD:
	# Keep horizontal offset extremely tight to the center so they never safely overlap
	# the side walls upon spawning, which completely prevents them from falling out.
	var random_offset = Vector2(randf_range(-150.0, 150.0), randf_range(-20.0, 20.0))
	
	# Use direct local relative offsets to ensure the ball is placed correctly 
	# regardless of the tray's global position or stale transform updates.
	ball.position = motion_body.position + spawn_point.position + random_offset
	
	balls_root.add_child(ball)
	
	# Reset physics interpolation AFTER positional teleport/add_child to prevent visual streaking/jitter
	ball.reset_physics_interpolation()
	
	# SOFT-SPAWN: Use Gradual Collision Scaling to allow balls to handle crowded spawning gracefully.
	ball.spawn_in(0.5)
	
	_active_balls[inst.ball_uuid] = ball

func _physics_process(delta: float) -> void:
	_check_out_of_bounds()
	
	if not is_instance_valid(lid_area):
		return
		
	var overlapping = lid_area.get_overlapping_bodies()
	var current_overlapping_uuids = []
	
	for body in overlapping:
		if body is PhysicsGachaBall:
			if not _penalties_active: continue
				
			var uuid = body.instance_uuid
			current_overlapping_uuids.append(uuid)
			if not _penalty_timers.has(uuid):
				_penalty_timers[uuid] = 0.0
			
			_penalty_timers[uuid] += delta
			
			if _penalty_timers[uuid] >= 5.0:
				var bm = get_tree().get_first_node_in_group("battle_manager")
				if is_instance_valid(bm) and bm.has_method("_on_battle_inventory_penalty"):
					bm._on_battle_inventory_penalty(uuid)
				elif SignalBus.has_signal("inventory_instance_removed_penalty"):
					SignalBus.emit_signal("inventory_instance_removed_penalty", uuid)
				_penalty_timers.erase(uuid)
				
	if _penalties_active:
		var tracked_uuids = _penalty_timers.keys()
		for uuid_to_check in tracked_uuids:
			if not current_overlapping_uuids.has(uuid_to_check):
				_penalty_timers.erase(uuid_to_check)

func _check_out_of_bounds() -> void:
	var safe_margin = 300.0
	var mb_pos = motion_body.global_position
	var min_x = global_position.x - safe_margin
	var max_x = global_position.x + container_size.x + safe_margin
	var min_y = mb_pos.y - safe_margin * 2.0
	var max_y = mb_pos.y + container_size.y + safe_margin
	
	var objects_to_recover: Array[PhysicsGachaBall] = []
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			var pos = ball.global_position
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

func _on_battle_transition_started(_is_opening: bool) -> void:
	_global_sleep_timer.stop()
	
	# Kill any ongoing decay
	if _bounce_tween:
		_bounce_tween.kill()
	
	# LIVELY: Set shared material to be bouncy during container motion
	var mat = preload("res://resources/physics/GachaBallMaterial.tres")
	mat.bounce = 0.8
	
	# Wake all balls so they react to the container's elevator motion
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			ball.sleeping = false

func _on_battle_transition_finished() -> void:
	# Start the 6s countdown to force-sleep the entire pile after movement stops
	_global_sleep_timer.start()
	
	# DEADEN: Smoothly decay bounce to 0.15 over 5 seconds (Fast at start, Slow at end)
	# Finishes at 5.0s so balls are 'dead' for 1s before the 6.0s Sleep Sweep locks them.
	var mat = preload("res://resources/physics/GachaBallMaterial.tres")
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(mat, "bounce", 0.15, 5.0)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
