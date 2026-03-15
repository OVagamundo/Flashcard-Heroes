# Implementation Plan: Discard Pile Physics Refactor

This document contains the step-by-step implementation instructions for converting the current static `DiscardGrid` in `DiscardPileWindow` into a physics simulation matching the `Battle Inventory`. Read `ZeroAssumptionBlueprint_DiscardPile.md` first.

---

## Step 1: Modify `DiscardPileWindow.tscn`

**Goal:** Replace the static grid structure with a `Control` root + fixed-size panel + `PhysicsTierContainer` instance.

1. Open `res://scenes/DiscardPileWindow.tscn` in Godot editor.
2. **Delete** the entire existing node tree below the root and rebuild as follows.
3. Set root `DiscardPileWindow (Control)` properties:
   - `layout_mode = 3`
   - `anchors_preset = 15` (full rect, fills parent viewport)
   - `anchor_right = 1.0, anchor_bottom = 1.0`
   - `mouse_filter = MOUSE_FILTER_IGNORE (2)`
   - `position = Vector2(1920, 0)` — starts hidden off-screen right

4. Add child `DiscardPilePanel (Control)`:
   - `layout_mode = 1` (anchors)
   - `anchor_left = 1.0, anchor_right = 1.0` — pinned to parent's right edge
   - `anchor_top = 0.0, anchor_bottom = 0.0`
   - `offset_left = -1280.0` — panel is 1280px wide
   - `offset_right = 0.0`
   - `offset_top = [Y at which panel top should appear, aligned to DiscardPileButton top edge — measure at runtime and set as a constant]`
   - `offset_bottom = offset_top + 680.0` — container height is 680px
   - `mouse_filter = MOUSE_FILTER_STOP (1)` — catches clicks on the panel

5. Add child of `DiscardPilePanel`: `ContainerBG (TextureRect)`:
   - `layout_mode = 1, anchors_preset = 15` — fills parent
   - `texture = res://assets/ui/textures/DiscardPileContainer.png`
   - `expand_mode = 0 (KEEP_SIZE)`
   - `stretch_mode = 3 (SCALE)`
   - `mouse_filter = MOUSE_FILTER_IGNORE (2)`

6. Add child of `DiscardPilePanel`: `DiscardPhysicsContainer`, instanced from `res://scenes/PhysicsTierContainer.tscn`:
   - `layout_mode = 1, anchors_preset = 15` — fills parent panel
   - Set `tier = 4` **in the Inspector panel** (this is critical — do NOT set it in code)
   - Set `left_wall_padding`, `right_wall_padding`, `bottom_wall_padding` in Inspector after measuring `DiscardPileContainer.png` border thickness
   - `mouse_filter = MOUSE_FILTER_IGNORE (2)`

7. Assign script `res://scripts/DiscardPileWindow.gd` to root node.

> **Measuring padding:** Open `DiscardPileContainer.png` in an image editor. Measure the pixel width of the painted border on the left, right, and bottom edges (the solid wall that contains the balls). The `left_wall_padding` should be the negative of the left border pixel width so the physics wall ends at the inner edge of the painted wall. Same for right. `bottom_wall_padding` should be the positive distance from the bottom edge at which the floor should sit. Start with guess values `left = -14, right = -14, bottom = 15` (same as inventory) and adjust during testing.

---

## Step 2: Rewrite `DiscardPileWindow.gd`

Replace the entire script:

```gdscript
class_name DiscardPileWindow
extends Control

@onready var physics_container: PhysicsTierContainer = $DiscardPilePanel/DiscardPhysicsContainer

func _ready() -> void:
    $DiscardPilePanel.gui_input.connect(_on_panel_gui_input)

func _on_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        WindowManager.handle_inspection_background_click(self)
        get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
    var instances: Array = context.get("inventory", [])
    var valid_instances: Array = []
    for inst in instances:
        if is_instance_valid(inst):
            valid_instances.append(inst)
    if is_instance_valid(physics_container):
        physics_container.sync_state(valid_instances)

func get_window_to_animate() -> Control:
    return self  # Root Control is the animation target (position.x is tweened)
```

---

## Step 3: Modify `WindowManager.gd`

### 3a. Add persistent window variable

At the top of the file, alongside `var _persistent_inventory_window: Control = null`, add:

```gdscript
var _persistent_discard_pile_window: Control = null
```

### 3b. Add to `_ready()`

Immediately after `call_deferred("_setup_persistent_inventory")`, add:

```gdscript
call_deferred("_setup_persistent_discard_pile")
```

### 3c. Add `_setup_persistent_discard_pile()`

```gdscript
func _setup_persistent_discard_pile() -> void:
    if not _window_scenes.has(&"DiscardPile"):
        return
    _persistent_discard_pile_window = _window_scenes[&"DiscardPile"].instantiate()
    _persistent_discard_pile_window.name = "PersistentDiscardPileWindow"
    _persistent_discard_pile_window.set_meta("window_type", &"DiscardPile")
    _get_modal_layer().add_child(_persistent_discard_pile_window)
    _persistent_discard_pile_window.hide()
    _persistent_discard_pile_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

### 3d. Add public accessor

```gdscript
func get_persistent_discard_pile_window() -> Control:
    return _persistent_discard_pile_window
```

### 3e. Rewrite `open_discard_pile_window()`

Replace the existing `open_discard_pile_window()` method:

```gdscript
func open_discard_pile_window() -> void:
    var win = _persistent_discard_pile_window
    if not is_instance_valid(win):
        return

    # Toggle: if already open, close it
    if win in _active_inspection_group:
        stop_tracking_window(win.get_instance_id())
        _active_inspection_group.erase(win)
        _animate_discard_pile_close(win)
        return

    # Populate with current discard pile data
    var ctx = _get_discard_pile_populate_context()
    if win.has_method("populate"):
        win.populate(ctx)

    if not _active_inspection_group.has(win):
        _active_inspection_group.push_back(win)

    _animate_discard_pile_open(win)
```

### 3f. Add `_is_discard_pile_window()`

```gdscript
func _is_discard_pile_window(window: Control) -> bool:
    if not is_instance_valid(window):
        return false
    if window.has_meta("window_type") and window.get_meta("window_type") == &"DiscardPile":
        return true
    return false
```

### 3g. Add animation methods

```gdscript
const DISCARD_PILE_HIDDEN_X: float = 1920.0
const DISCARD_PILE_OPEN_X: float = 640.0

func _animate_discard_pile_open(window: Control) -> void:
    if not is_instance_valid(window): return
    if window.has_meta(_WM_META_OPENING) and bool(window.get_meta(_WM_META_OPENING)): return

    window.set_meta(_WM_META_OPENING, true)
    window.set_meta(_WM_META_CLOSING, false)

    # Start off-screen right
    window.position.x = DISCARD_PILE_HIDDEN_X
    window.show()
    window.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _kill_inventory_motion_tween(window)
    Audio.play_sfx("ui_window_open")

    var tween: Tween = window.create_tween()
    window.set_meta(_WM_META_ANIM_TWEEN, tween)
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

    tween.tween_property(window, "position:x", DISCARD_PILE_OPEN_X, 0.45
        ).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

    tween.chain().tween_callback(func():
        if is_instance_valid(window):
            window.set_meta(_WM_META_OPENING, false)
            # Jolt balls leftward (simulating drawer hitting its stop)
            if window is DiscardPileWindow:
                window.physics_container.apply_jolt(Vector2(-500, 0))
            window.mouse_filter = Control.MOUSE_FILTER_PASS
            if window.has_meta(_WM_META_ANIM_TWEEN):
                window.remove_meta(_WM_META_ANIM_TWEEN)
    )

func _animate_discard_pile_close(window: Control) -> void:
    if not is_instance_valid(window): return
    if window.has_meta(_WM_META_CLOSING) and bool(window.get_meta(_WM_META_CLOSING)): return

    window.set_meta(_WM_META_OPENING, false)
    window.set_meta(_WM_META_CLOSING, true)
    window.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _kill_inventory_motion_tween(window)

    var tween: Tween = window.create_tween()
    window.set_meta(_WM_META_ANIM_TWEEN, tween)
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

    tween.tween_property(window, "position:x", DISCARD_PILE_HIDDEN_X, 0.35
        ).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

    tween.chain().tween_callback(func():
        if is_instance_valid(window):
            window.set_meta(_WM_META_CLOSING, false)
            if window.has_meta(_WM_META_ANIM_TWEEN):
                window.remove_meta(_WM_META_ANIM_TWEEN)
            window.hide()
            # Jolt balls rightward (simulating drawer hitting the wall as it closes)
            if window is DiscardPileWindow:
                window.physics_container.apply_jolt(Vector2(500, 0))
    )
```

### 3h. Update `_queue_free_with_optional_inventory_animation()`

Currently this only checks for inventory windows and calls `_animate_inventory_window_close`. Add discard pile handling:

```gdscript
func _queue_free_with_optional_inventory_animation(window: Control) -> void:
    if not is_instance_valid(window):
        return
    if window == _persistent_inventory_window:
        _animate_inventory_window_close(window)
        return
    if window == _persistent_discard_pile_window:
        _active_inspection_group.erase(window)
        _animate_discard_pile_close(window)
        return
    if _animate_inventory_window_close(window):
        return
    window.queue_free()
```

### 3i. Update `_close_all_windows()`

Currently `_close_all_windows()` calls `close_all_inspection_windows()`. Make sure `close_all_inspection_windows()` properly handles the persistent discard pile: since it's in `_active_inspection_group`, it will be processed. The existing `_queue_free_with_optional_inventory_animation()` will be called on it after the 3h change, triggering a close animation instead of `queue_free()`. This should work without additional changes.

---

## Step 4: Modify `BattleView.gd`

### 4a. Feed discard data to the persistent window on every `_redraw_board()`

In `_redraw_board()`, immediately after the lines that update `discard_pile_button.text`, add:

```gdscript
# Feed discard pile data to the always-running physics simulation
var discard_window = WindowManager.get_persistent_discard_pile_window()
if is_instance_valid(discard_window):
    var bm_ref = battle_manager  # Already referenced in BattleView
    discard_window.populate({"inventory": bm_ref.get_discard_pile_inventory()})
```

---

## Step 5: Vertical Position Alignment

The `DiscardPilePanel` must align vertically so its top edge matches the top edge of `%DiscardPileButton` (or aesthetically works with the battle layout). The button lives deep in the node tree — its Y position in screen space depends on the HBoxContainer layout at runtime.

**Approach:** In `DiscardPileWindow._ready()`, after the window is added to the scene tree, calculate and store the correct Y position. OR, set a hard-coded constant based on the known battle layout. The battle layout is fixed (1920×1080), so once you measure the Y position of the button region, encode it as a constant.

The `EnemyArea` row starts at the bottom, with the bench composite below lineup. A reasonable initial estimate: the discard area container (80px tall) and the battery of 192px trinket slots places the DiscardArea near the bottom of the screen. **Measure in editor** and set `offset_top` accordingly in the .tscn.

---

## Step 6: Verify Physics Simulation While Hidden

After implementing, test that:
1. When the game starts a battle, physics are running in the background (balls settle).
2. When the player opens the drawer, the balls are already settled (not all at the top).
3. While the drawer is open, moving it back and forth causes balls to react realistically.
4. After closing, physics continues and balls re-settle.

If balls freeze when hidden: Set `_persistent_discard_pile_window.process_mode = Node.PROCESS_MODE_ALWAYS`. This allows physics processing even when the node is hidden.

---

## Step 7: Interaction Mode for Discard Pile Balls

`PhysicsGachaBall._emit_interaction()` currently hardcodes `interaction_mode = &"FULLY_INTERACTIVE"`. In the discard pile, balls should be `INSPECTION_ONLY`.

Research how to best solve this:
- Option A: Add an `interaction_mode` export to `PhysicsGachaBall` and check it in `_emit_interaction()`.
- Option B: Have `PhysicsTierContainer` set a property on each spawned ball post-creation.
- Option C: Let `GlobalInteractionRouter` determine interaction rights based on the container the ball is in.

This is a design decision to make during implementation based on what approach fits the existing `GlobalInteractionRouter` architecture best. The existing static discard pile already used `INSPECTION_ONLY` — study how `SlotView.set_interaction_context(&"INSPECTION_ONLY", 1)` worked before to understand what the GIR checks.

---

## Verification Checklist

- [ ] `DiscardPileContainer.png` container texture fills `DiscardPilePanel` at 1x (1280×680)
- [ ] Balls appear inside container at 1x scale matching inventory balls
- [ ] Balls fall, bounce, and settle with realistic physics while drawer is hidden
- [ ] Opening the drawer: smooth horizontal slide from x=1920 to x=640 in 0.45s
- [ ] On open complete: balls visibly react to the jolt (bounce leftward)
- [ ] Closing the drawer: smooth horizontal slide back to x=1920 in 0.35s
- [ ] On close complete: balls react to the jolt (bounce rightward) while hidden
- [ ] Balls stay inside the visual container borders (no clipping)
- [ ] Collision layers are correct (balls don't interact with inventory tiers)
- [ ] Adding items to discard pile (during battle) syncs immediately to physics container
- [ ] Clicking a ball opens inspection window (or hover-inspect, matching existing behavior)
- [ ] No ball can be dragged, swapped, or moved from the discard pile
- [ ] No changes to `PhysicsTierContainer.gd` or `PhysicsGachaBall.gd` core physics logic (only interface changes)