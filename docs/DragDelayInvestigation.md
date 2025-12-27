# Drag-and-Drop Delay Investigation Report

> **IMPORTANT**: This document captures all findings from a debugging session investigating a ~1 second visual delay between releasing a gachaball during drag-and-drop and seeing the landing animation. The user will roll back all code changes and use this document to continue in a new session.

## The Problem

**User's Original Prompt**: "great! is there a delay between releasing the gachaball with the drag and drop and the animation starting? why can't it be immediate like with the click and click actions?"

**Symptom**: After releasing the mouse during a drag-and-drop operation, there's approximately a 1-second delay before:
1. The drop indicators disappear
2. The gachaball "pops" into existence in the target slot
3. The landing bounce animation plays

**Critical Observation**: Click-and-click interactions are **instant**. Only drag-and-drop has this delay.

---

## Key Finding #1: CODE EXECUTES INSTANTLY

**Log analysis proves ALL code execution is instant (<30ms total)**:

```
SlotView._drop_data called at 98248
InventoryManager._move start at 98248        ← Same millisecond!
BattleView._redraw_board start at 98248      ← Same millisecond!
SlotView.set_content at 98248-98272          ← All views updated in ~25ms
InventoryManager._move emitting completion at 98273
GachaBallView._play_landing_bounce START at 98273, visible: true
NOTIFICATION_DRAG_END received at 98273      ← Within 1ms of drop!
```

**This proves the delay is NOT in:**
- Signal processing
- InventoryManager logic
- View creation/population
- Animation triggering

---

## Key Finding #2: NOTIFICATION_DRAG_END Fires Instantly (For Successful Drops)

We added debug traces and confirmed:
- For **successful drops**: `NOTIFICATION_DRAG_END` fires within 1-2ms of `_drop_data`
- For **failed/cancelled drops**: `NOTIFICATION_DRAG_END` may fire ~3 seconds later (when drag is cancelled by dropping on nothing)

**This rules out**: Godot delaying the NOTIFICATION_DRAG_END notification for valid drops.

---

## Key Finding #3: Intermittent Fast Drops

The user observed that **sometimes** the drop is nearly instantaneous (no delay). This happened rarely but suggests:
1. The delay is NOT deterministic
2. Something intermittent causes it
3. Possibly related to animation cycles (indicator pulse = 1 second total cycle)

**User observation**: "the last drop was instantaneous but without bounce"

This is a critical clue - the fast path somehow bypasses the normal flow.

---

## Dead Ends (DO NOT TRY AGAIN)

### 1. Custom Manual Drag System ❌
**What we tried**: Completely bypassing Godot's native drag-and-drop by:
- Returning `null` from `_get_drag_data()` 
- Creating a CanvasLayer-based preview manually
- Using `_input()` to detect global mouse release
- Implementing `process_manual_drop()` for hit-testing

**Result**: 
- Broke click-and-click interactions
- Delay still present
- Added complexity without benefit

**Why it failed**: The delay wasn't in Godot's drag system - code was already executing instantly.

### 2. Removing NOTIFICATION_DRAG_END Handler ❌
**What we tried**: Commenting out the entire `_notification(NOTIFICATION_DRAG_END)` handler.

**Result**: Delay still present.

**Why it failed**: The notification fires at the right time; removing its handler doesn't change when the visual update happens.

### 3. Disabling VSync ❌
**What we tried**: User disabled VSync in project settings.

**Result**: No change.

### 4. Searching for Explicit Delays ❌
**What we searched for**:
- `Timer` nodes
- `await get_tree().process_frame`
- `call_deferred` calls
- Explicit `await` statements in the drop path

**Result**: Found a 420ms suppression in GIR for window closure (unrelated). No delays in the actual drop path.

### 5. Suspecting Drag Preview Cleanup ❌
**What we tried**: 
- Adding `_reset_drag_deformation()` call to `_end_drag_visuals()`
- Cleaning up CanvasLayer previews

**Result**: Delay still present.

**Why it failed**: Godot manages its own preview cleanup after `set_drag_preview()`.

---

## Hypotheses Still Unexplored

### 1. Frame/Rendering Timing
The code executes instantly but the visual update might be deferred to a future frame. Godot's rendering pipeline might batch certain updates.

**Test**: Add `get_tree().process_frame` timing logs to see if there's a gap between code execution and actual render.

### 2. Indicator Pulse Animation Interference
The indicator pulse has a 1-second total cycle (0.5s up, 0.5s down). This matches the delay duration.

**Theory**: The indicator pulse tween might somehow be affecting the rendering pipeline or event processing. When the drop happens at a specific phase of the pulse cycle, it might be faster.

**Test**: Temporarily disable the indicator pulse animation and test if delay disappears.

### 3. View Recreation Race Condition
When a gachaball is dropped:
1. Source view is hidden (during drag)
2. `_redraw_board()` recreates ALL views
3. New views are populated
4. Signal triggers bounce on new views

**Theory**: The old hidden view and new visible view might be racing. The visual might show the old position until something triggers a refresh.

**Test**: Add a `queue_redraw()` or `update()` call after `_redraw_board()`.

### 4. Mouse Capture/Release Timing
Godot might be holding some visual state while the mouse button is pressed.

**Test**: Check if `Input.is_mouse_button_pressed()` returns true during the delay period.

### 5. Drag Preview Z-Index Conflict
The drag preview created by `set_drag_preview()` might still be visible briefly, occluding the dropped view.

**Test**: Make the drag preview semi-transparent and watch what happens during the delay.

---

## Critical Code Paths

### Successful Drop Flow:
```
User releases mouse
  ↓
Godot calls _drop_data() on target
  ↓
SlotView/GachaBallView._drop_data() 
  → Creates InteractionContext(&"DROP")
  → Emits interaction_context_received
  ↓
GlobalInteractionRouter._on_interaction_context_received()
  → Identifies DROP type
  → Emits try_inventory_action
  ↓
InventoryManager._on_try_inventory_action()
  → Calls _move() / _swap()
  → Emits battle_inventory_changed (triggers _redraw_board)
  → Calls GlobalInteractionRouter.end_drag(true)
  → Emits inventory_action_completed
  ↓
GachaBallView._on_inventory_action_completed()
  → Calls _play_landing_bounce() if visible
  ↓
Godot fires NOTIFICATION_DRAG_END to all Controls
```

### Key Files:
- `scripts/GachaBallView.gd` - Drag source, bounce animation
- `scripts/SlotView.gd` - Drop target  
- `scripts/GlobalInteractionRouter.gd` - Drag state management
- `scripts/InventoryManager.gd` - Move/swap logic
- `scripts/BattleView.gd` - `_redraw_board()` recreates views
- `scripts/SlotIndicatorController.gd` - Indicator show/hide

---

## Features That WERE Working (Before This Session)

1. **Click-and-click** - Instant and working
2. **Drag preview** - Visible during drag (using Godot's `set_drag_preview`)
3. **Bounce animation** - Plays after drops (on new visible view)
4. **Slot indicators** - Show during drag, hide on drop

---

## Features Added This Session (MAY NEED ROLLBACK)

1. **Gachaball overlay** - Ball texture overlay for inventory views
2. **`_reset_drag_deformation()` cleanup call** in GIR
3. **Debug print statements** - Many added for timing analysis
4. **Same-slot bounce fix** - Order of `end_drag` vs `inventory_action_completed`
5. **`drop_targets` group** - Added to SlotView (for manual drag - should be removed)

---

## Recommended Next Steps

1. **Roll back all changes** from this session
2. **Add timing logs** at these specific points:
   - `_get_drag_data()` start
   - `_drop_data()` called
   - `NOTIFICATION_DRAG_END` received
   - First frame after drop (use `await get_tree().process_frame`)
3. **Disable indicator pulse** temporarily to test if it affects delay
4. **Try calling `queue_redraw()`** on the target slot after drop
5. **Check mouse button state** during the delay period

---

## Log Snippets for Reference

### Normal Drop (with delay):
```
SlotView._drop_data called at 160576
InventoryManager._move start at 160577
InventoryManager._move emitting completion at 160583
_play_landing_bounce START at 160583, visible: true
NOTIFICATION_DRAG_END received at 160583, _is_dragging=false
```

### Failed/Cancelled Drag (dropped on nothing):
```
NOTIFICATION_DRAG_END received at 166794, _is_dragging=false
(~3 seconds after last successful drop)
```

---

## Summary

**The Mystery**: Code execution is instant, but visual update is delayed by ~1 second. Click-and-click is instant. Intermittently, drag-drop is also instant but without bounce animation. The cause is likely in Godot's rendering/frame update pipeline or related to the indicator pulse animation cycle, NOT in the game's code logic.
