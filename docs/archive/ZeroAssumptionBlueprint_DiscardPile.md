# Zero Assumption Blueprint: Physics-Based Discard Pile

## 1. Goal

Replace the static `DiscardGrid` in `DiscardPileWindow` with a physics simulation identical in mechanics to the Battle Inventory's `PhysicsTierContainer`. The Discard Pile drawer slides **horizontally** from off-screen right, while the Battle Inventory slides **vertically** from below. Everything else about the physics balls (scale, physics parameters, visual appearance, sound) is **identical**.

---

## 2. Source of Truth: The Battle Inventory (Study Before Touching Anything)

Before implementing anything for the Discard Pile, you must understand the already-working Battle Inventory pipeline. All key behaviors are defined across these files:

| File | Role |
|---|---|
| `res://scenes/InventoryWindow.tscn` | Scene tree: `PanelContainer` with `offset_top=162, offset_bottom=-238` anchored to full rect. Three `PhysicsTierContainer` instances (`Tier1Physics`, `Tier2Physics`, `Tier3Physics`) are siblings of `ScrollContainer` inside each `Tier#Column > VBoxContainer`. |
| `res://scripts/InventoryWindow.gd` | `get_window_to_animate()` returns `%PanelContainer`. In `_ready()`, calls `_sync_physics_layout()` which copies `size_flags` and `custom_minimum_size` from the `ScrollContainer` sibling onto each `PhysicsTierContainer`. Physics population happens via `bm.get_inventory_tier_instances(tier)` → `tier_#_physics.sync_state(...)`. |
| `res://scripts/WindowManager.gd` | `_animate_inventory_window_open()` tweens `%PanelContainer`'s `offset_top/offset_bottom` from `start_delta = viewport_height` down to `0` in 0.45s, `TRANS_QUART, EASE_OUT`. At tween completion, calls `apply_jolt(Vector2(0, -500))` on all three physics containers. Close animation tweens offsets back to `viewport_height` in 0.35s, `EASE_IN`, then hides and calls `apply_jolt(Vector2(0, 400))`. |
| `res://scenes/PhysicsTierContainer.tscn` | Minimal scene: root `Control` (anchors_preset=15, full rect, mouse_filter=IGNORE), children: `SpawnPoint (Marker2D)`, `Bounds (StaticBody2D)`, `DropTimer (Timer, wait_time=0.15)`, `LidArea (Area2D + CollisionShape2D)`. **The `tier` export property IS SET IN THE .tscn INSPECTOR** (not in code). `Tier1Physics` has no `tier` override (defaults to 1), `Tier2Physics` has `tier = 2`, `Tier3Physics` has `tier = 3`. |
| `res://scripts/PhysicsTierContainer.gd` | Collision layers computed in `_ready()`: `bound_layer = 10 + ((tier-1)*2)`, `ball_layer = 11 + ((tier-1)*2)`. **Layers are bit-shifted**: `bounds_body.collision_layer = (1 << (bound_layer - 1))`. Bounds are rebuilt in `_on_resized()` (connected to the `resized` signal). `_max_y_seen` prevents the floor from dropping due to layout recalculations. `sync_state()` is the public API for feeding instances. `_spawn_ball()` adds balls as children of the `PhysicsTierContainer` itself (not a sub-container). Ball `position` is set to `spawn_point.position` (local coords of the container). |
| `res://scripts/PhysicsGachaBall.gd` | `RigidBody2D`. Scale is 1x (no resize). Physics properties: mass, bounce, friction are set on the scene itself. Contains `capsule_sprite`, `icon_sprite`, `ui_anchor (Control)`. Interaction uses `ui_anchor.gui_input`. Sound fires on `body_entered` when velocity > 150px/s. |

### Critical Detail: How Balls Stay Inside a Moving Container

This is the most important concept. The `PhysicsTierContainer` is a `Control` node. When the parent window's `PanelContainer` tweens, the `Control` moves with it because it is a **child** node. Since `RigidBody2D` balls are **also children** of `PhysicsTierContainer`, they exist in the **same local coordinate space**. Godot 2D physics processes `RigidBody2D` in **global coordinates**, so when the container moves, the immovable static walls (also children of `PhysicsTierContainer` via `$Bounds`) move with it in global space. This creates a natural inertia effect: the walls move, the balls — governed by physics — lag behind and roll/bounce. **No artificial impulse inject is needed during animation.** `apply_jolt()` is only called at the **end of the animation** to add a "settling bounce" effect.

---

## 3. Target: The Discard Pile Implementation

### 3.1 Differences From Battle Inventory

| Property | Battle Inventory | Discard Pile |
|---|---|---|
| **Animation axis** | Vertical (bottom of screen upward) | Horizontal (right of screen leftward) |
| **Animation target node** | `PanelContainer` with `offset_top/offset_bottom` | `DiscardPileWindow` root Control, using `position.x` directly |
| **Hidden position** | Below screen (offset = viewport_height) | Right of screen: `position.x = 1920` |
| **Open position** | At authored offsets (delta = 0) | `position.x = 640` (1280px of texture visible) |
| **Persistent?** | Yes — added to `ModalLayer` by `WindowManager._setup_persistent_inventory()`, never freed | Yes — must be persistent and always physics-simulating in background |
| **Scene location** | Added to `ModalLayer` which is in `Battle.tscn` | Same `ModalLayer` inside `Battle.tscn` |
| **Physics containers** | Three (`Tier1Physics`, `Tier2Physics`, `Tier3Physics`) | One (`DiscardPhysicsContainer`) |
| **Data source** | `bm.get_inventory_tier_instances(tier)` per tier | `bm.get_discard_pile_inventory()` → `Array[GachaBallInstance]` |
| **Tier property** | 1, 2, 3 respectively (set in .tscn inspector) | **4** (set in .tscn inspector — gives collision layers 16/17) |
| **Container texture** | `Tier#GachaBallContainer.png` (640×680 per tier) | `DiscardPileContainer.png` (1280×680) |
| **Base mask** | `TierXGachaBallBase.png` tiles visible below container | None — discard pile has no base; it hides fully off-screen |
| **Padding** | `left_wall_padding = -14, right_wall_padding = -14, bottom_wall_padding = 15` — compensates for transparent alpha halos in artwork | Needs measurement against `DiscardPileContainer.png`. The discard pile container has solid visible borders, not transparent halos. Padding values will differ and must be tuned. |
| **jolt direction** | Open: `Vector2(0, -500)` (upward). Close: `Vector2(0, 400)` (downward) | Open: leftward `Vector2(-500, 0)`. Close: rightward `Vector2(500, 0)` |
| **interaction mode** | `FULLY_INTERACTIVE` | `INSPECTION_ONLY` |
| **WindowManager method** | `_animate_inventory_window_open/close` — checks `_is_inventory_window()` | **New methods** needed: `_animate_discard_pile_open/close` — check `_is_discard_pile_window()` |

### 3.2 Shared With Battle Inventory (No Duplication Needed)

- `PhysicsTierContainer.tscn` — reused as-is (instanced in the new scene)
- `PhysicsTierContainer.gd` — **must not be modified**
- `PhysicsGachaBall.tscn` / `PhysicsGachaBall.gd` — reused as-is
- `VisualDataAdapter` — same `create_visual_data()` call
- `BattleManager.get_discard_pile_inventory()` — existing data API
- `SignalBus.display_discard_pile_requested` — existing signal
- Window lifecycle (persistent, added to `ModalLayer`) — same pattern as inventory

---

## 4. Component Architecture

### 4.1 DiscardPileWindow.tscn (Full Scene Tree)

The root `DiscardPileWindow (Control)` node spans the full viewport (anchors_preset=15). Its `position.x` is what gets tweened.

```
DiscardPileWindow (Control)
├── anchors_preset = 15 (full rect)
├── mouse_filter = IGNORE (root is pass-through)
├── position = Vector2(1920, 0)  ← hidden off-screen right
└── DiscardPilePanel (Control)
    ├── layout_mode = 1
    ├── anchor_left = 1.0
    ├── anchor_right = 1.0
    ├── anchor_top = 0.0
    ├── anchor_bottom = 1.0
    ├── offset_left = -1280.0   ← panel is 1280px wide, pinned to right edge of parent
    ├── offset_right = 0.0
    ├── offset_top = [Y computed to align with GachaBallBase top edge]
    ├── offset_bottom = [Y+680]
    ├── mouse_filter = STOP
    └── ContainerBG (TextureRect)
        ├── texture = res://assets/ui/textures/DiscardPileContainer.png
        ├── expand_mode = 0
        ├── stretch_mode = SCALE (3)
        ├── anchors_preset = 15 (fills panel)
        └── [SIBLING] DiscardPhysicsContainer (PhysicsTierContainer instanced)
            ├── Instance of res://scenes/PhysicsTierContainer.tscn
            ├── layout_mode = 1
            ├── anchors_preset = 15 (fills panel)
            ├── tier = 4  ← SET IN INSPECTOR, gives layers 16 (bounds) / 17 (balls)
            ├── left_wall_padding = [measure from texture]
            ├── right_wall_padding = [measure from texture]
            └── bottom_wall_padding = [measure from texture]
```

**Alternative simpler structure**: The root `Control` (full viewport) holds a child `DiscardPilePanel` whose size is exactly 1280×680 and is positioned at the right edge of the full-viewport root. When we tween the root's `position.x`, the panel (being a child with a right-edge anchor) moves with it naturally.

> **Note on vertical alignment:** The DiscardPileButton is in `TeamAreas/EnemyArea/EnemyBenchComposite/ButtonMargins/DiscardArea`. At runtime, query `%DiscardPileButton.get_global_rect().position.y` to determine the Y coordinate of the base. The `DiscardPilePanel`'s top edge should align with that Y. This can be established as a single constant position once measured, since the battle layout does not change during gameplay.

### 4.2 Physics Container: Tier 4 collision layers

`PhysicsTierContainer._ready()` computes:
- `bound_layer = 10 + ((4-1)*2) = 16`
- `ball_layer = 11 + ((4-1)*2) = 17`
- `bounds_body.collision_layer = (1 << 15)` = bit 15 (layer 16)
- `bounds_body.collision_mask = (1 << 16)` = bit 16 (layer 17)
- Each ball: `collision_layer = (1 << 16)`, `collision_mask = (1 << 15) | (1 << 16)` (collides with walls and other balls)

These layers are **separate** from the inventory tiers (layers 10-15) so discard pile balls never interact with inventory balls.

---

## 5. Window Lifecycle (Persistent Background Simulation)

### 5.1 Setup (mirrors `_setup_persistent_inventory`)

In `WindowManager._ready()`, after `_setup_persistent_inventory()` is called, add a deferred call to `_setup_persistent_discard_pile()`:

```gdscript
func _setup_persistent_discard_pile() -> void:
    if not _window_scenes.has(&"DiscardPile"):
        return
    _persistent_discard_pile_window = _window_scenes[&"DiscardPile"].instantiate()
    _persistent_discard_pile_window.name = "PersistentDiscardPileWindow"
    _persistent_discard_pile_window.set_meta("window_type", &"DiscardPile")
    _get_modal_layer().add_child(_persistent_discard_pile_window)
    _persistent_discard_pile_window.hide()
    # Root is positioned at x=1920 in the scene, so it starts hidden off-screen right
    _persistent_discard_pile_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

Add the variable declaration: `var _persistent_discard_pile_window: Control = null`

### 5.2 Open / Close

`open_discard_pile_window()` (already exists) needs to be restructured to mirror `open_inventory_window()` — using the persistent instance, populating it, and calling `_animate_discard_pile_open()`.

### 5.3 The Critical Point: Physics Simulates While Hidden

Because the persistent window is added to the scene tree and never freed (just hidden/moved off-screen), `PhysicsTierContainer._physics_process()` continues running. Balls will settle to a realistic resting state **before** the player ever opens the drawer. This is the desired "pre-settled" behavior.

When `hide()` is called, physics pauses for hidden nodes in Godot 4 (by default). **Monitor this**: if balls freeze and then "teleport" when shown, the physics container may need `process_mode = ALWAYS` to simulate while hidden. Compare behavior to inventory when it hides.

---

## 6. Animation Pipeline

### 6.1 How the Inventory Vertical Tween Works (Reference)

The `InventoryWindow` root spans full viewport (anchors_preset=15). Its inner `PanelContainer` uses anchors_preset=15 too, but with `offset_top = 162` and `offset_bottom = -238` as its resting position (authored in the .tscn). WindowManager stores `base_top = 162.0, base_bottom = -238.0` as constants. The tween starts at `start_delta = viewport_height` (panel below screen) and eases to `delta = 0` (panel at authored position). The panel moves, and all children (including physics containers and their child balls) move with it.

### 6.2 Discard Pile Horizontal Tween

The root `DiscardPileWindow` Control starts at `position.x = 1920` (off screen right). Opening tweens `position.x` to `640`. This means the full viewport-sized root slides 1280 pixels leftward, bringing the `DiscardPilePanel` child (pinned to parent's right edge) into view from `x=1920` to `x=640+1280 = x=1920` — wait, this doesn't work directly.

**Correct approach — two options:**

**Option A: Tween the Root Position**
- Root `DiscardPileWindow` is full-viewport (1920×1080), `position = Vector2(1920, 0)` when hidden.
- `DiscardPilePanel` is a **fixed-size** (1280×680) child at `position = Vector2(0, Y_offset)` inside the root.
- When root's `position.x = 1920`, the panel appears at screen x=1920 (off right edge).
- When root's `position.x = 640`, the panel appears at screen x=640 (visible from x=640 to x=1920).
- ✅ Simple. Ball coordinates relative to parent are unchanged. Physics "just works."

**Option B: Tween the Panel's `offset_left`**
- Root spans full viewport, fixed `position = Vector2.ZERO`.
- `DiscardPilePanel` is anchor-based, `offset_left` starts at `0` (fully off right) and tweens to `-1280` (fully on screen, aligned to right edge).
- Works like inventory's offset approach, but horizontal.

**Option A is recommended** as it mirrors the root-level approach without anchor math complexity, and ensures balls stay correctly positioned since only the root's `position` changes, not any internal layout values.

### 6.3 Tween Parameters

```gdscript
const DISCARD_PILE_HIDDEN_X: float = 1920.0
const DISCARD_PILE_OPEN_X: float = 640.0

func _animate_discard_pile_open(window: Control) -> void:
    # Set to hidden position
    window.position.x = DISCARD_PILE_HIDDEN_X
    window.show()
    window.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var tween = window.create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(window, "position:x", DISCARD_PILE_OPEN_X, 0.45
        ).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
    
    tween.chain().tween_callback(func():
        if is_instance_valid(window):
            # Jolt balls leftward (simulating the drawer slamming to a stop)
            var jolt = Vector2(-500, 0)
            window.get_node("DiscardPilePanel/DiscardPhysicsContainer").apply_jolt(jolt)
            window.mouse_filter = Control.MOUSE_FILTER_PASS
    )

func _animate_discard_pile_close(window: Control) -> void:
    window.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var tween = window.create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(window, "position:x", DISCARD_PILE_HIDDEN_X, 0.35
        ).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
    
    tween.chain().tween_callback(func():
        if is_instance_valid(window):
            window.hide()
            # Jolt rightward (simulating the drawer bouncing as it hits the wall)
            var jolt = Vector2(500, 0)
            window.get_node("DiscardPilePanel/DiscardPhysicsContainer").apply_jolt(jolt)
    )
```

---

## 7. Data Synchronization

### 7.1 The Data Path (Existing, Tested)

`BattleManager.get_discard_pile_inventory()` already exists and returns `Array[GachaBallInstance]` (min size 16, padded with nulls). It queries `C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE`.

`BattleView._redraw_board()` already updates the discard count on `%DiscardPileButton`. The new `DiscardPileWindow.populate()` must be called in this same redraw loop. Example:

```gdscript
# In BattleView._redraw_board() after discard_pile_button.text update:
var discard_window = WindowManager.get_persistent_discard_pile_window()
if is_instance_valid(discard_window):
    discard_window.populate({"inventory": bm.get_discard_pile_inventory()})
```

Or expose via a method added to `WindowManager`: `func get_persistent_discard_pile_window() -> Control: return _persistent_discard_pile_window`

### 7.2 DiscardPileWindow.gd: Simplified populate()

Unlike the old implementation, there is no need for a `DiscardInstanceWrapper` inner class. `PhysicsTierContainer.sync_state()` accepts anything with `ball_uuid` and `get_definition()` and `get_location()` — the real `GachaBallInstance` objects returned by `get_discard_pile_inventory()` already have these. Simply pass them directly:

```gdscript
class_name DiscardPileWindow
extends Control

@onready var physics_container: PhysicsTierContainer = $DiscardPilePanel/DiscardPhysicsContainer

func populate(context: Dictionary) -> void:
    var instances: Array = context.get("inventory", [])
    var valid_instances = []
    for inst in instances:
        if is_instance_valid(inst):
            valid_instances.append(inst)
    physics_container.sync_state(valid_instances)

func get_window_to_animate() -> Control:
    return self  # Root is the animation target
```

> **Note:** `PhysicsGachaBall.gd` calls `_emit_interaction()` with `interaction_mode = &"FULLY_INTERACTIVE"`. For the discard pile (inspect-only), this needs adjustment. Either: (a) set the appropriate interaction context on the ball after spawning, or (b) check if `PhysicsTierContainer` has a way to configure ball interaction mode. **Study `PhysicsGachaBall._emit_interaction()`** — it always emits `FULLY_INTERACTIVE`. For the discard pile, the `GlobalInteractionRouter` may need to handle this differently, or the ball's context needs to be set post-spawn. This must be researched during implementation.

---

## 8. Physics Container Padding Values

The `PhysicsTierContainer` uses padding exports:
- `left_wall_padding: float = -14.0` (outward = negative)
- `right_wall_padding: float = -14.0` (outward = negative)
- `bottom_wall_padding: float = 15.0`

These `-14px` values exist because the inventory container textures have **transparent alpha halos** around their borders. The physics walls need to extend 14px outward past the visual edge to align with the visible painted border.

`DiscardPileContainer.png` (1280×680) has **solid opaque borders** (no alpha halos). Its usable interior area must be measured visually in an image editor. The padding values for the discard pile container will need to be set to match its specific solid border thickness. **Measure the texture before setting these values.**

---

## 9. Known Failure Modes (Do Not Repeat)

These are the specific failure patterns documented from previous implementation attempts. They are included here so the implementer knows what to watch for, not as solutions to pre-implement.

### A. Collision Layer Timing Bug
**Symptom:** Balls fall through walls. **Cause:** Setting `tier` in `_ready()` via code runs AFTER `_ready()` of parent nodes, meaning walls are built on wrong layers before being corrected. **Prevention:** **Never set `tier` in code.** Set it only in the `.tscn` inspector export. `PhysicsTierContainer._ready()` reads the export and computes layers before any children run.

### B. Local vs. Global Coordinate Bug
**Symptom:** Balls clump inside a wall. **Cause:** `ball.position = spawn_point.position` uses local coordinates of the `PhysicsTierContainer`. If the spawning logic accidentally uses global coordinates, balls spawn at wrong global positions. **Prevention:** Read `_spawn_ball()` in `PhysicsTierContainer.gd` — it already uses `spawn_point.position` (local). Do not change this.

### C. Floor Offset Bug via `_max_y_seen` Deletion
**Symptom:** Physics floor appears 300px below visual container. **Cause:** `_max_y_seen` in `PhysicsTierContainer.gd` protects against the floor dropping due to temporary Size changes during UI layout. **Prevention:** Do NOT modify `PhysicsTierContainer.gd`. If the floor is misaligned, the error is in the scene layout, not the engine.

### D. Momentum Bug
**Symptom:** Balls don't react to the drawer moving. **Cause:** The drawer movement naturally pushes balls via Godot's built-in physics (walls move in global space, balls lag). If this doesn't happen, the physics container is not a proper child of the moving node. **Prevention:** Ensure the `PhysicsTierContainer` IS a descendant of `DiscardPileWindow` (the node being tweened). Check the scene tree structure.

### E. Wall Clipping
**Symptom:** Balls clip through visual edges. **Cause:** Wrong padding values. **Prevention:** Measure `DiscardPileContainer.png` border thickness and set correct `left_wall_padding`, `right_wall_padding`, `bottom_wall_padding` values in the .tscn inspector.

---

## 10. File Change Summary

| File | Type | Change |
|---|---|---|
| `res://scenes/DiscardPileWindow.tscn` | MODIFY | Replace static grid layout with new physics-based structure |
| `res://scripts/DiscardPileWindow.gd` | MODIFY | Simplify to populate physics container only |
| `res://scripts/WindowManager.gd` | MODIFY | Add `_persistent_discard_pile_window`, `_setup_persistent_discard_pile()`, `_animate_discard_pile_open/close()`, `_is_discard_pile_window()`, update `open_discard_pile_window()` to use persistent instance |
| `res://scripts/BattleView.gd` | MODIFY | In `_redraw_board()`, call `discard_window.populate(...)` after updating button text |
| `res://scenes/PhysicsTierContainer.tscn` | NO CHANGE | Reused as-is via instancing |
| `res://scripts/PhysicsTierContainer.gd` | NO CHANGE | Must not be modified |
| `res://scripts/PhysicsGachaBall.gd` | POSSIBLY MODIFY | Research whether inspection-only mode requires a change to `_emit_interaction()` or if this is handled at the `GlobalInteractionRouter` level |
