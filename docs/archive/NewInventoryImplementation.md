# Strict Phased Implementation Guide: Physics-Driven Battle Inventory

**Objective:** Implement a strictly visual, read-only physics simulation (Suika-style) for the `InventoryWindow` specifically during the Battle phase, replacing the manipulatable `InventoryGrid`. 

---

## Phase 1: Engine Determinism & Global Signals
**Context for AI:** This phase establishes the strict physics constraints required to prevent overlapping bodies from "boiling" or exploding, and registers the global signal needed for the 3-second lid penalty.

1. **Update `project.godot` Physics Settings**
   Ensure the physics engine is deterministic and layers are isolated. Add or enforce the following under `[physics]` using the correct Godot 4 configuration keys:
   
   ```ini
   [physics]
   common/physics_ticks_per_second=120
   common/max_physics_steps_per_frame=16
Under [layer_names], add specific 2D physics layers to isolate tiers:

Ini, TOML
2d_physics/layer_10="Tier1_Bounds"
2d_physics/layer_11="Tier1_Balls"
2d_physics/layer_12="Tier2_Bounds"
2d_physics/layer_13="Tier2_Balls"
2d_physics/layer_14="Tier3_Bounds"
2d_physics/layer_15="Tier3_Balls"
Update scripts/SignalBus.gd
Add the penalty signal to the INVENTORY & LOADOUT SIGNALS section:

## Emitted when an item overflows a physics container lid for 3 consecutive seconds
## @param uuid: String - The UUID of the instance to be destroyed
signal inventory_instance_removed_penalty(uuid: String)

## Phase 2: The PhysicsGachaBall Entity
**Context for AI:** Creates the physical counterpart to the GachaBallView. It is strictly 1x scale, read-only, and hooks into GlobalInteractionRouter rules. Crucially, because it is a `RigidBody2D`, it requires a `Control` anchor child so the `WindowManager` can correctly position inspection tooltips over it.

1. **Create `scenes/PhysicsGachaBall.tscn`**
   * **Root Node:** `RigidBody2D` (Name: `PhysicsGachaBall`)
     * `input_pickable` = `true`
     * `mass` = `1.0`
     * `continuous_cd` = 1 (Cast Ray)
     * Add a `PhysicsMaterial`: `friction` = 0.8, `bounce` = 0.0.
   * **Child 1:** `Sprite2D` (Name: `Sprite2D`)
     * *Crucial:* Ensure the scale results in a visual size that precisely fits the 50.0 radius below.
   * **Child 2:** `CollisionShape2D` (Name: `CollisionShape2D`)
     * Shape: `CircleShape2D` with radius = `50.0`
   * **Child 3:** `Control` (Name: `UIAnchor`)
     * *Purpose:* Acts as the spatial reference for UI tooltips.
     * Layout: Set `custom_minimum_size` to `Vector2(96, 96)` and `position` to `Vector2(-48, -48)` to center it perfectly over the ball.
     * `mouse_filter` = `Ignore`

2. **Create `scripts/PhysicsGachaBall.gd`**
   ```gdscript
   class_name PhysicsGachaBall
   extends RigidBody2D

   var instance_uuid: String
   var location: LocationIdentifier
   var entity_type: StringName

   @onready var sprite: Sprite2D = $Sprite2D
   @onready var ui_anchor: Control = $UIAnchor

   func _ready() -> void:
       mouse_entered.connect(_on_mouse_entered)
       mouse_exited.connect(_on_mouse_exited)

   func populate(uuid: String, type: StringName, loc: LocationIdentifier, tex: Texture2D) -> void:
       instance_uuid = uuid
       entity_type = type
       location = loc
       if tex:
           sprite.texture = tex

   func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
       if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
           _emit_interaction(&"SINGLE_CLICK")
           get_viewport().set_input_as_handled()

   func _on_mouse_entered() -> void:
       _emit_interaction(&"HOVER_ENTER")

   func _on_mouse_exited() -> void:
       _emit_interaction(&"HOVER_EXIT")

   func _emit_interaction(event_type: StringName) -> void:
       var context = InteractionContext.new()
       # CRITICAL: Pass the UIAnchor Control ID, not the RigidBody ID, so WindowManager can anchor to it.
       context.source_view_instance_id = ui_anchor.get_instance_id()
       context.event_type = event_type
       context.location = location
       context.entity_uuid = instance_uuid
       context.entity_type = entity_type
       context.interaction_mode = &"INSPECTION_ONLY" # Explicitly read-only via GIR rules
       context.window_group_id = 0
       SignalBus.emit_signal("interaction_context_received", context)

## Phase 3: The PhysicsTierContainer Environment
**Context for AI:** Handles dynamic U-shape bounds generation, staggered spawning, and the 3-second penalty logic. The UI layout engine requires bounds generation to react dynamically to the `resized` signal so the physics environment doesn't freeze at 0x0.

1. **Create `scenes/PhysicsTierContainer.tscn`**
   * **Root Node:** `Control` (Name: `PhysicsTierContainer`)
     * Set `clip_contents` = `true`
     * Set `anchors_preset` = `Full Rect`
   * **Child 1:** `Marker2D` (Name: `SpawnPoint`)
   * **Child 2:** `StaticBody2D` (Name: `Bounds`)
   * **Child 3:** `Timer` (Name: `DropTimer`, `wait_time` = 0.15)
   * **Child 4:** `Area2D` (Name: `LidArea`)
     * Add `CollisionShape2D` (RectangleShape).

2. **Create `scripts/PhysicsTierContainer.gd`**
   ```gdscript
   class_name PhysicsTierContainer
   extends Control

   @export var tier: int = 1
   @onready var spawn_point: Marker2D = $SpawnPoint
   @onready var drop_timer: Timer = $DropTimer
   @onready var bounds_body: StaticBody2D = $Bounds
   @onready var lid_area: Area2D = $LidArea

   const PhysicsBallScene = preload("res://scenes/PhysicsGachaBall.tscn")

   var _active_balls: Dictionary = {}
   var _penalty_timers: Dictionary = {}
   var _spawn_queue: Array = [] # Holds GachaBallInstances

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
           _generate_u_shape_bounds()

   func _generate_u_shape_bounds() -> void:
       # Safely wipe old collision boundaries if the UI resized
       for child in bounds_body.get_children():
           child.queue_free()
           
       var t = 100.0 # thickness
       var s = size
       var poly = PackedVector2Array([
           Vector2(0, 0), Vector2(-t, 0), Vector2(-t, s.y + t),
           Vector2(s.x + t, s.y + t), Vector2(s.x + t, 0), Vector2(s.x, 0),
           Vector2(s.x, s.y), Vector2(0, s.y)
       ])
       var shape = CollisionPolygon2D.new()
       shape.polygon = poly
       bounds_body.add_child(shape)
       
       spawn_point.position = Vector2(s.x / 2.0, -60.0)
       lid_area.position = Vector2(s.x / 2.0, 0)
       var rect_shape = RectangleShape2D.new()
       rect_shape.size = Vector2(s.x, 50.0)
       
       # Safe fallback in case the lid area child wasn't strictly configured in editor
       if lid_area.get_child_count() > 0:
           lid_area.get_child(0).shape = rect_shape
       else:
           var col = CollisionShape2D.new()
           col.shape = rect_shape
           lid_area.add_child(col)

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
       var overlapping = lid_area.get_overlapping_bodies()
       var current_overlapping_uuids = []
       
       for body in overlapping:
           if body is PhysicsGachaBall:
               var uuid = body.instance_uuid
               current_overlapping_uuids.append(uuid)
               if not _penalty_timers.has(uuid):
                   _penalty_timers[uuid] = 0.0
               
               _penalty_timers[uuid] += delta
               
               if _penalty_timers[uuid] >= 3.0:
                   SignalBus.emit_signal("inventory_instance_removed_penalty", uuid)
                   _penalty_timers.erase(uuid)
                   
       var tracked_uuids = _penalty_timers.keys()
       for uuid in tracked_uuids:
           if not current_overlapping_uuids.has(uuid):
               _penalty_timers.erase(uuid)


## Phase 4: `InventoryWindow` Dual-Mode Adapter
**Context for AI:** The UI utilizes `_is_battle_context`. We safely declare variables for the `ScrollContainers` natively used by the grids, hiding them to mask the manipulatable UI and showing the read-only physics siblings. Crucially, we force the physics containers to inherit their exact layout flags so they don't collapse inside `VBoxContainers`.

1. **Modify `scenes/InventoryWindow.tscn`:**
   Add three instances of `PhysicsTierContainer.tscn` as siblings to the `ScrollContainer` nodes located inside `%Tier1Panel`, `%Tier2Panel`, and `%Tier3Panel`. Name them `Tier1Physics`, `Tier2Physics`, and `Tier3Physics`. Set their `tier` exports respectively to 1, 2, and 3. Set their `anchors_preset` to `Full Rect`.

2. **Modify `scripts/InventoryWindow.gd`:**
   At the top of the file, explicitly define the new physics nodes AND the scroll container parents:
   ```gdscript
   # Bulletproof relative pathing utilizing the Unique Names of the grids
   @onready var tier_1_scroll: ScrollContainer = %Tier1Grid.get_parent()
   @onready var tier_1_physics: PhysicsTierContainer = tier_1_scroll.get_parent().get_node("Tier1Physics")
   
   @onready var tier_2_scroll: ScrollContainer = %Tier2Grid.get_parent()
   @onready var tier_2_physics: PhysicsTierContainer = tier_2_scroll.get_parent().get_node("Tier2Physics")
   
   @onready var tier_3_scroll: ScrollContainer = %Tier3Grid.get_parent()
   @onready var tier_3_physics: PhysicsTierContainer = tier_3_scroll.get_parent().get_node("Tier3Physics")
Update the _ready() function and add the new layout sync helper method:

GDScript
func _ready() -> void:
    panel_container.gui_input.connect(_on_panel_gui_input)
    SignalBus.inventory_ui_refresh_requested.connect(_on_ui_refresh)
    tier_1_grid.gui_input.connect(_on_grid_gui_input)
    tier_2_grid.gui_input.connect(_on_grid_gui_input)
    tier_3_grid.gui_input.connect(_on_grid_gui_input)
    
    # Force the physics containers to inherit the explicit layout space
    _sync_physics_layout(tier_1_scroll, tier_1_physics)
    _sync_physics_layout(tier_2_scroll, tier_2_physics)
    _sync_physics_layout(tier_3_scroll, tier_3_physics)
    
    _configure_scroll_navigation()
    set_process(true)

func _sync_physics_layout(scroll: ScrollContainer, physics: PhysicsTierContainer) -> void:
    physics.size_flags_horizontal = scroll.size_flags_horizontal
    physics.size_flags_vertical = scroll.size_flags_vertical
    physics.custom_minimum_size = scroll.custom_minimum_size
Replace the logic at the beginning of _populate_grids():

GDScript
func _populate_grids() -> void:
    if not _data_source: return
    
    # Toggle UI Visibilities - operate on the scroll containers to hide grids and scrollbars
    tier_1_scroll.visible = not _is_battle_context
    tier_2_scroll.visible = not _is_battle_context
    tier_3_scroll.visible = not _is_battle_context
    
    tier_1_physics.visible = _is_battle_context
    tier_2_physics.visible = _is_battle_context
    tier_3_physics.visible = _is_battle_context
    
    if _is_battle_context:
        var bm = get_tree().get_first_node_in_group("battle_manager")
        if is_instance_valid(bm):
            tier_1_physics.sync_state(bm.get_inventory_tier_instances(1))
            tier_2_physics.sync_state(bm.get_inventory_tier_instances(2))
            tier_3_physics.sync_state(bm.get_inventory_tier_instances(3))
    else:
        # (Keep existing standard grid initialization logic here, unmodified)
        _initialize_grids_if_needed()
        # ... standard population loop ...

## Phase 5: The Penalty Enforcer (`BattleManager`)
**Context for AI:** The physical overflow penalty is strictly scoped to the `BattleManager`. Items within the `BattleInventory` containers are volatile gacha draws instantiated solely for the current encounter. They do not persist in the master `RunState`, so no global cleanup is required outside of the `BattleManager`.

1. **Modify `scripts/BattleManager.gd`**
   In the `_connect_signals()` method, append the listener for the active battle board:
   ```gdscript
   if SignalBus.has_signal("inventory_instance_removed_penalty"):
       if not SignalBus.inventory_instance_removed_penalty.is_connected(_on_battle_inventory_penalty):
           SignalBus.inventory_instance_removed_penalty.connect(_on_battle_inventory_penalty)
Add the handler at the bottom of the script using the correct atomic API (bm_remove_instance):

GDScript
func _on_battle_inventory_penalty(uuid: String) -> void:
    if _battle_instances.has(uuid):
        var instance = _battle_instances.get(uuid)
        var name_str = "Item"
        
        if is_instance_valid(instance):
            var def = instance.get_definition()
            if def and "display_name_key" in def:
                name_str = tr(def.display_name_key)
                
        # The precise BattleManager API for atomic runtime destruction
        bm_remove_instance(uuid) 
        
        if Engine.has_singleton("BattleLogger"):
            BattleLogger.log_message("[color=red]OVERFLOW PENALTY:[/color] %s was destroyed." % name_str)

## 6. Implementation Verification Checklist
**Context for AI:** Before concluding your task, verify the following constraints have been met exactly as written:

[ ] `project.godot` possesses the explicit custom physics layers (10 through 15) and deterministic simulation steps utilizing the Godot 4 `common/` path keys.

[ ] `PhysicsGachaBall.tscn` contains an invisible `Control` node (`UIAnchor`) to properly route spatial coordinates for the `WindowManager` tooltips.

[ ] `PhysicsGachaBall.gd` hardcodes `&"INSPECTION_ONLY"` in its `InteractionContext`.

[ ] `PhysicsTierContainer.gd` dynamically generates its `CollisionPolygon2D` via a `call_deferred` based on the UI Control rect size.

[ ] The penalty timer perfectly resets if an item drops back out of the `LidArea`.

[ ] `InventoryWindow.gd` securely hides the manipulatable `ScrollContainer` grids when `_is_battle_context` is true.

[ ] `BattleManager.gd` is hooked into the destruction signal, and `GameManager` is NOT touched for this process.