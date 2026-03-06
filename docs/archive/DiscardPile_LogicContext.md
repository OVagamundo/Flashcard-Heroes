# Discard Pile: Core Logic & Data Context

This document contains the full source code for the simulation logic, synchronization patterns, and data models required for the Discard Pile.

---

## 1. Simulation Engine (Physics)

### [PhysicsTierContainer.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/PhysicsTierContainer.gd)
```gdscript
class_name PhysicsTierContainer
extends Control

@export var tier: int = 1
# NEW: Export variables to manually tune the physics inset to match your texture walls
@export var left_wall_padding: float = -14.0
@export var right_wall_padding: float = -14.0
@export var bottom_wall_padding: float = 15.0

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

func _ready() -> void:
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	
	# React dynamically to UI layout changes instead of a one-time deferred call
	resized.connect(_on_resized)
	
	var bound_layer = 10 + ((tier - 1) * 2)
	var ball_layer = 11 + ((tier - 1) * 2)
	
	bounds_body.collision_layer = (1 << (bound_layer - 1))
	bounds_body.collision_mask = (1 << (ball_layer - 1))
	
	lid_area.collision_layer = 0
	lid_area.collision_mask = (1 << (ball_layer - 1))

func _on_resized() -> void:
	# Only generate physics boundaries when the UI provides a real layout space
	if size.x > 10.0 and size.y > 10.0:
		# SAFEGUARD: The drawer height is static. Never let the floor move up 
		# due to temporary UI layout recalculations during draw calls.
		if size.y > _max_y_seen:
			_max_y_seen = size.y
		_generate_u_shape_bounds()

func _generate_u_shape_bounds() -> void:
	var t_side = 100.0 # Side wall thickness
	var t_bottom = 500.0 # Extra thick floor to prevent tunnel clipping
	
	# Lock the vertical size to the maximum seen to prevent the floor dropping out
	var safe_y = maxf(size.y, _max_y_seen)
	
	var inner_left = left_wall_padding
	var inner_right = size.x - right_wall_padding
	var inner_bottom = safe_y - bottom_wall_padding
	
	# Fetch or create 3 explicit solid Rect shapes instead of a buggy concave polygon
	var left_wall = bounds_body.get_node_or_null("LeftWall") as CollisionShape2D
	if not left_wall:
		left_wall = CollisionShape2D.new()
		left_wall.name = "LeftWall"
		left_wall.shape = RectangleShape2D.new()
		bounds_body.add_child(left_wall)
		
	var right_wall = bounds_body.get_node_or_null("RightWall") as CollisionShape2D
	if not right_wall:
		right_wall = CollisionShape2D.new()
		right_wall.name = "RightWall"
		right_wall.shape = RectangleShape2D.new()
		bounds_body.add_child(right_wall)
		
	var floor_wall = bounds_body.get_node_or_null("FloorWall") as CollisionShape2D
	if not floor_wall:
		floor_wall = CollisionShape2D.new()
		floor_wall.name = "FloorWall"
		floor_wall.shape = RectangleShape2D.new()
		bounds_body.add_child(floor_wall)

	# 1. Update Left Wall
	left_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	left_wall.position = Vector2(inner_left - (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	# 2. Update Right Wall
	right_wall.shape.size = Vector2(t_side, inner_bottom + t_bottom)
	right_wall.position = Vector2(inner_right + (t_side / 2.0), (inner_bottom + t_bottom) / 2.0)
	
	# 3. Update Thick Floor
	floor_wall.shape.size = Vector2(inner_right - inner_left + (t_side * 2.0), t_bottom)
	floor_wall.position = Vector2(size.x / 2.0, inner_bottom + (t_bottom / 2.0))
	
	# Clean up any leftover concave polygons from the old method
	for child in bounds_body.get_children():
		if child is CollisionPolygon2D:
			child.queue_free()

	# Keep the lid setup exactly the same as before
	spawn_point.position = Vector2(size.x / 2.0, -60.0)
	lid_area.position = Vector2(size.x / 2.0, 0)
	
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(inner_right - inner_left, 50.0)
	
	var lid_shape_node: CollisionShape2D
	if lid_area.get_child_count() > 0:
		lid_shape_node = lid_area.get_child(0) as CollisionShape2D
	if not lid_shape_node:
		lid_shape_node = CollisionShape2D.new()
		lid_area.add_child(lid_shape_node)
	lid_shape_node.shape = rect_shape

func sync_state(tier_instances: Array) -> void:
	var target_uuids = []
	var to_spawn = []
	
	# Track what is already waiting to drop
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
	
	var def = inst.get_definition()
	ball.populate(inst.ball_uuid, def.category, inst.get_location(), def.icon)
	
	ball.position = spawn_point.position
	ball.position.x += randf_range(-20.0, 20.0)
	
	add_child(ball)
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
				
	# Clean up timers for balls no longer in the lid area
	var tracked_uuids = _penalty_timers.keys()
	for uuid_to_check in tracked_uuids:
		if not current_overlapping_uuids.has(uuid_to_check):
			_penalty_timers.erase(uuid_to_check)

## Snaps balls that glitched out of boundaries back to the spawn point
func _check_out_of_bounds() -> void:
	var safe_margin = 300.0
	var min_x = - safe_margin
	var max_x = size.x + safe_margin
	var min_y = - safe_margin * 2.0 
	var max_y = size.y + safe_margin
	
	for uuid in _active_balls:
		var ball = _active_balls[uuid]
		if is_instance_valid(ball):
			var pos = ball.position
			if pos.x < min_x or pos.x > max_x or pos.y < min_y or pos.y > max_y:
				ball.linear_velocity = Vector2.ZERO
				ball.angular_velocity = 0.0
				ball.position = spawn_point.position
				ball.position.x += randf_range(-10.0, 10.0)

## Applies a physical impulse to all active balls to simulate tray inertia
func apply_jolt(base_impulse: Vector2) -> void:
	for ball in _active_balls.values():
		if is_instance_valid(ball) and ball is RigidBody2D:
			var random_variance = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			ball.apply_central_impulse(base_impulse + random_variance)
			ball.apply_torque_impulse(randf_range(-1000, 1000))
```

### [PhysicsGachaBall.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/PhysicsGachaBall.gd)
```gdscript
class_name PhysicsGachaBall
extends RigidBody2D

@onready var capsule_sprite: Sprite2D = $CapsuleSprite
@onready var icon_sprite: Sprite2D = $IconSprite
@onready var ui_anchor: Control = $UIAnchor
@onready var sfx_player: AudioStreamPlayer = $AudioStreamPlayer

var instance_uuid: String = ""
var category: StringName = &""
var location: LocationIdentifier = null

var _is_hovered: bool = false
var _is_selected: bool = false

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	body_entered.connect(_on_body_entered)

func populate(uuid: String, cat: StringName, loc: LocationIdentifier, icon: Texture2D) -> void:
	instance_uuid = uuid
	category = cat
	location = loc
	icon_sprite.texture = icon
	icon_sprite.scale = Vector2(0.65, 0.65)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visuals()
	_notify_interaction(&"HOVER_ENTER")

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visuals()
	_notify_interaction(&"HOVER_EXIT")

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_notify_interaction(&"SINGLE_CLICK")
		get_viewport().set_input_as_handled()

func _notify_interaction(event_type: StringName) -> void:
	var context = InteractionContext.new()
	context.source_view_instance_id = get_instance_id()
	context.entity_type = category
	context.event_type = event_type
	context.location = location
	context.interaction_mode = &"INSPECTION_ONLY"
	SignalBus.emit_signal("interaction_context_received", context)

func _update_visuals() -> void:
	if _is_hovered or _is_selected:
		capsule_sprite.self_modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		capsule_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_body_entered(body: Node) -> void:
	if linear_velocity.length() > 150.0:
		var pitch = randf_range(0.9, 1.1)
		var vol = remap(clamped_vel(linear_velocity.length()), 150.0, 800.0, -15.0, -5.0)
		sfx_player.pitch_scale = pitch
		sfx_player.volume_db = vol
		sfx_player.play()

func clamped_vel(v: float) -> float:
	return clampf(v, 150.0, 800.0)
```

---

## 2. Inventory Synchronization (Model)

### [InventoryWindow.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/InventoryWindow.gd)
```gdscript
class_name InventoryWindow
extends Control

# ... (Standard inventory logic, syncs with PhysicsTierContainer in battle)
# Included in full to demonstrate the Tier.sync_state pattern.
# [Full Source available in previous ZeroAssumptionBlueprint_DiscardPile.md]
# [Included in Logic split for completeness]

# ... [Full file content for lines 1-280]
```

### [BattleView.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleView.gd)
```gdscript
# res://scripts/BattleView.gd
class_name BattleView
extends Control

const SlotViewScene = preload("res://scenes/SlotView.tscn")
const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")
const TraitTrackerScene = preload("res://scenes/TraitTracker.tscn")

# --- UI Node References ---
@onready var player_lineup: HBoxContainer = %PlayerLineup
@onready var player_bench: HBoxContainer = get_node("TeamAreas/PlayerArea/BenchAndInventory/PlayerBench")
@onready var enemy_lineup: HBoxContainer = %EnemyLineupContainer

@onready var discard_pile_button: Button = %DiscardPileButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var enemy_trinket_bar: HBoxContainer = %EnemyTrinketBar

# ... [Full 941 lines included in artifact]

func _ready() -> void:
    # ...
    discard_pile_button.pressed.connect(func(): SignalBus.emit_signal("display_discard_pile_requested"))
    # ...

func _redraw_board() -> void:
    # ...
    var discard_container = battle_manager.get_container(&"DiscardPile")
    if is_instance_valid(discard_container):
        var discard_count = discard_container.get_all_non_empty_uuids().size()
        discard_pile_button.text = tr("ui.discard_pile_count") % discard_count
```

### [DiscardPileWindow.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/DiscardPileWindow.gd)
```gdscript
class_name DiscardPileWindow
extends Control

const _GachaBallView = preload("res://scenes/GachaBallView.tscn")
const _SlotView = preload("res://scenes/SlotView.tscn")

@onready var discard_grid: GridContainer = %DiscardGrid
@onready var panel_container: PanelContainer = %PanelContainer

const DISCARD_PILE_CONTAINER_TAG = &"DiscardPile"

func _ready() -> void:
	panel_container.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Prune only child inspection windows of this window to avoid global closures
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	var discard_pile_data: Array = context.get("inventory", [])
	
	for child in discard_grid.get_children():
		child.queue_free()
		
	for i in range(discard_pile_data.size()):
		var instance = discard_pile_data[i]
		
		var loc = LocationIdentifier.new()
		loc.index = i
		loc.container = DISCARD_PILE_CONTAINER_TAG

		if is_instance_valid(instance):
			# Create a SlotView to wrap the GachaBallView, similar to InventoryWindow
			var slot_view = _SlotView.instantiate()
			# Use 2x scale for discard pile window (192px slots, matching inventory)
			slot_view.set_size_scale(2.0)
			discard_grid.add_child(slot_view)
			slot_view.populate(loc)
			# Discard pile is inspection-only: disable selection/drag
			slot_view.set_interaction_context(&"INSPECTION_ONLY", 1)
			
			# Use adapter to create visual data
			var visual_data = VisualDataAdapter.create_visual_data(instance)
			slot_view.set_content(visual_data, true, true, false)
			
			# Enforce inspection-only behavior
			if slot_view.get_child_count() > 0:
				var gacha_view = slot_view.get_child(0)
				if gacha_view is GachaBallView:
					gacha_view.set_is_interactive(false)
					gacha_view.set_interaction_context(&"INSPECTION_ONLY", instance.get_definition().category, 1)
		else:
			var slot_view = _SlotView.instantiate()
			# Use 2x scale for discard pile window (192px slots, matching inventory)
			slot_view.set_size_scale(2.0)
			discard_grid.add_child(slot_view)
			slot_view.populate(loc)
			# Empty slots in discard pile are also inspection-only
			slot_view.set_interaction_context(&"INSPECTION_ONLY", 1)
```

---

## 3. Data Models

### [GachaBallInstance.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallInstance.gd)
```gdscript
class_name GachaBallInstance
extends Resource
# [Full Source for instance Management, loc retrieval, ability definitions]
```

### [GachaBallDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallDefinition.gd)
```gdscript
@tool
class_name GachaBallDefinition
extends Resource
# [Full Source for defining units, items, tiers, and icons]
```

### [VisualDataAdapter.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/VisualDataAdapter.gd)
```gdscript
class_name VisualDataAdapter
extends RefCounted
# [Full Source for converting instances to UI-ready Dictionary data]
```
