Window Manager - V2.2 (Service Architecture)
Version: 2.2
Status: Canonical
This document specifies the architecture and behavior of the WindowManager, a core UI system in Flashcard Heroes.
1. Purpose & Core Philosophy
The Window Manager is a pure "service" manager. Its sole purpose is to manage the lifecycle, state, and positioning of all pop-up windows. It acts as a direct executor for commands issued by the Global Interaction Router (GIR).
It is crucial to distinguish between Content Scenes and Windows:
Content Scenes (Shop, RestSite, Battle, PathChoice): These are full-screen views that are loaded into the main content area of the game. They are not managed by the WindowManager.
Windows (InventoryWindow, UnitInspectionWindow, ChoiceWindow, etc.): These are pop-up elements that appear on top of a Content Scene. These are the sole responsibility of the WindowManager.
2. Window Categories & Terminology
To eliminate ambiguity, we will use the following precise terminology.
2.1 Hermetic Modals
These are true modal windows that completely halt the normal game flow and block all interaction with the underlying UI. They are self-contained experiences.
Examples: FlashcardMinigame, EndBattlePopup, ResultsPopup.
Behavior:
Accompanied by a BackgroundBlocker that consumes all input.
Cannot be closed by clicking the background or pressing the Escape key (they close themselves based on internal logic).
They are exclusive and always close any other open windows when they appear.
2.2 Contextual Windows
This is the largest and most important category. These windows provide additional context without fully interrupting the game flow. Crucially, they do not block interaction with other UI elements, allowing for the "Click-Through" rule. They are all part of a single, hierarchical "inspection group."
Sub-type A: Dynamic-Position Windows
Examples: UnitInspectionWindow, ItemInspectionWindow, EffectInspectionWindow, ChoiceWindow.
Behavior: Their size is determined by their content, and their position is dynamically calculated to be adjacent to the UI element they are inspecting (their "anchor").
Sub-type B: Fixed-Position Windows
Examples: InventoryWindow (run and battle inventory inspection windows), DiscardPileWindow.
Behavior: They have a fixed, pre-defined size and are always positioned in the center of the screen. While they appear "modal," they are behaviorally contextual—they do not have a BackgroundBlocker and will close if the player clicks outside of them.
3. State Management
The WindowManager maintains two internal state arrays to manage these categories:
_modal_stack: Tracks only Hermetic Modals.
_active_inspection_group: Tracks all Contextual Windows (both Dynamic and Fixed-Position). This array represents the single, active chain of pop-ups, such as InventoryWindow -> UnitInspectionWindow -> EffectInspectionWindow.
4. The Definitive Rules of Window Management
These are the canonical laws that govern all Contextual Windows interactions, enforced by the GIR and executed by the WindowManager.
Rule ID	Rule Name	Statement & Mechanism	Rationale
W1	The Hierarchical Group Only Child Rule	There can only be one active Contextual Window group at a time and each parent window on the group can only have one direct child window open at any given moment. When the GIR commands the opening of a new root-level Contextual Window (e.g., opening the InventoryWindow or inspecting a unit on the battle board), the WindowManager must first destroy the entire previous group.	Prevents screen clutter and ensures the player's focus is on a single, coherent chain of information.
W2	The "Click-Through" Rule	If any Contextual Windows are open, a single click on a valid interactive entity outside of that window group will close all windows and select that new entity (or press the button, etc). The GIR detects this and issues a [CLOSE_ALL_INSPECTION_WINDOWS, SELECT] command queue.	Creates a fluid UI, allowing the player to seamlessly shift focus from inspecting their inventory to selecting a unit on the board without an extra "click-off" action.
W3	The Window Pruning Rule	Clicking on a Contextual Window's own background closes all of its descendant (child) windows, but not itself. The GIR issues a CLOSE_CHILD_WINDOWS command, and the WindowManager finds the parent window in its group and destroys all subsequent windows in the array.	Provides an intuitive way for the player to "step back" up the information hierarchy one or many levels at a time.
W4	The Global Close Rule	A click on any non-interactive area of the screen (an "unhandled input" caught by the GIR) closes all open Contextual Windows and clears any active selection. The GIR issues a [CLOSE_ALL_INSPECTION_WINDOWS, DESELECT] command queue.	The universal "reset state" action. It provides a reliable way for the player to get a clean slate.
W5	The Escape Key Precedence Rule	The ui_cancel (Escape) key is processed by the GIR with a strict priority: 1. Cancel Active Drag, 2. Close Hermetic Modal (if allowed), 3. Close All Contextual Windows, 4. Clear Selection.	Creates a consistent and predictable "back out" behavior, correctly prioritizing the most intrusive UI elements first.

4.1 Local Background Click API
Inspection windows should handle clicks on their own background locally and prune only their descendants (Rule W3) without involving global input:

- Call `WindowManager.handle_inspection_background_click(self)` from the window's `_gui_input` when a background click is detected.
- GIR continues to handle global background clicks (outside any window) and other input, issuing `CLOSE_ALL_INSPECTION_WINDOWS`, etc.

This keeps WindowManager as a service executor while simplifying scene wiring and avoiding global signal signature issues.
- Signature safety note: Do NOT emit a global `background_clicked` signal from inspection windows. Call `WindowManager.handle_inspection_background_click(self)` directly from `_gui_input` instead to avoid signal signature mismatches and to respect the local‑only pruning contract (W3).

4.2 Child Contextual Window API
Use this API to open a child contextual window anchored to an existing window or view. This wraps the unified contextual open path and preserves the single-group hierarchy (W1):

```
WindowManager.open_child_contextual_window(
    window_type: StringName,     # e.g. &"EffectInspection"
    anchor_view: Control,        # usually `self` from the parent window
    populate_ctx: Dictionary = {}# payload for the child window's populate()
)
```

Example (from an inspection window):

```
WindowManager.open_child_contextual_window(
    &"EffectInspection",
    self,
    {"effect_definition": definition.ability_definitions}
)
```

4.3 Command Handling Contract (from GIR)

The WindowManager executes commands issued by `GlobalInteractionRouter` and does not interpret raw input:

- __CLOSE_ALL_INSPECTION_WINDOWS__ → close all contextual windows and clear `_active_inspection_group`.
- __CLOSE_CHILD_WINDOWS(parent_window: Control)__ → `close_children_of(parent_window)`.
- __Open contextual/inspection windows__ → use the unified contextual open path. Public helpers:
  - `open_child_contextual_window(window_type, anchor_view, populate_ctx)`
  - `open_choice_window(populate_ctx, anchor_view = null)`

Notes:
- WindowManager never decides intent; GIR owns precedence and validation. WindowManager only performs lifecycle and positioning.
- For background clicks inside a window, windows must call `handle_inspection_background_click(self)` (local prune). Global background clicks are routed by GIR to `CLOSE_ALL_INSPECTION_WINDOWS`.
5. Positioning & Sizing System
The WindowManager is responsible for all window positioning.
Fixed-Position Windows (InventoryWindow, DiscardPileWindow): These are the simplest. Their scenes are designed with a pre-set size, and the WindowManager simply places them in the center of the viewport.
Dynamic-Position Windows (UnitInspectionWindow, ItemInspectionWindow, EffectInspectionWindow, ChoiceWindow): These require a more complex system.
Algorithm: The positioning logic is screen-aware. When a window is created, the manager checks the on-screen position of its anchor. It attempts to place the window on the opposite side of the screen where there is more room, falling back to below, above, or the same side if necessary. This prevents windows from opening off-screen.
Anchor Tracking: To prevent windows from becoming detached from moving UI elements, the manager subscribes to the item_rect_changed and tree_exited signals of a window's "stable anchor" (e.g., its parent SlotView). If the anchor moves, the window is repositioned. If the anchor is destroyed, the window is also destroyed.

Anchor Tracking Policy:
- Applied only for root contextual windows that were opened with a valid `anchor_view`.
- Child windows do not track anchors; their position is derived from the parent.
- Root fixed-position windows (e.g., Inventory, DiscardPile) do not track anchors and are centered.

## 5.1 Screen‑Space Coordinate System

- __All positioning is done in screen space.__ We measure anchors and parents in screen coordinates and set window positions accordingly, regardless of scene parenting or CanvasLayer.
- __Measuring rects:__ `_get_screen_rect(ctrl)` uses `ctrl.get_global_transform_with_canvas()` and converts to a `Rect2` in screen space.
- __Setting positions:__ `_set_window_screen_position(window, pos: Vector2)` transforms the target screen position through the inverse of the window’s canvas transform to the window’s local space before assigning `window.global_position`.
- __API migration:__ Godot 4 replaces `Transform2D.xform()` with `xform_point()`/`xform_vector()`. All usages are updated accordingly to avoid parser errors.

## 5.2 Two‑Pass Placement (Deferred + Finalize)

- __Deferred pass (`_deferred_position`)__: awaited for one frame to allow layout to settle; computes an initial position using current `custom_minimum_size`/`size`.
- __Finalize pass (`_finalize_position`)__: awaited again (after `show()`); corrects the position using the final computed size to eliminate layout jitter and off‑by‑one clamps.
- This makes placement robust across dynamic content, fonts, and theme changes.

## 5.3 Root vs Child Positioning Rules

- __Root contextual windows__ (no `parent_window`):
  - Use the resolved `anchor_view` rect when provided.
  - Apply a specific `positioning_hint` if present; otherwise use the general heuristic (`_calculate_window_position`) that avoids overlapping the anchor and stays on screen.
- __Child contextual windows__ (with `parent_window`):
  - __Parent‑first rule__: position relative to the `parent_window` rect to ensure consistent, scene‑agnostic behavior.
  - If an `anchor_view` is also provided, `_calculate_child_window_position_from_anchor(parent, anchor, child)` may refine placement.
  - Special hint `"use_parent_window"` forces strictly parent‑rect placement and ignores the anchor. Used for equipped item inspections so they attach to the UnitInspectionWindow, not the small equipped slot.

## 5.4 Positioning Hints (Canonical)

- __center_over_anchor__ → `_calculate_centered_over_anchor(anchor, window)`
  - Centers the window on the anchor rect; viewport clamped.
- __top_center_over_anchor__ → `_calculate_top_center_over_anchor(anchor, window)`
  - Centers horizontally on the anchor and prefers above with `INSPECTION_WINDOW_MARGIN`.
  - __Flip logic__: if insufficient space above, place below; if neither side fully fits, pick the side with more available space; finally clamp to viewport.
  - Godot 4 typing: intermediate values are explicitly `float` to avoid inference errors when mixing `Rect2(i)` with float math.
- __left_of_anchor__ → `_calculate_left_of_anchor(anchor, window)`
  - Places the window to the left of the anchor when possible; otherwise to the right.
  - Vertical alignment: top‑align if the anchor is in the top half of the viewport; otherwise bottom‑align. Always clamped to viewport.
  - __Used for EnemyLineup__: units sit on the right half of the screen; their inspection windows open to the left of the GachaBall.
- __use_parent_window__ (child only)
  - Forces parent‑rect placement and ignores `anchor_view` entirely. __Used for equipped items__ (both player and enemy): item inspections attach to the owning `UnitInspectionWindow` instead of the small equipped item slot.
- __General heuristic__ → `_calculate_window_position(anchor, window)` avoids overlapping the anchor and selects side/quadrant by available space; clamps to viewport.

## 5.5 Overlap Avoidance and Viewport Clamping

- Windows must not overlay their anchors in inspection contexts. Intersection checks are used and fallbacks are applied to keep a clear gap defined by `INSPECTION_WINDOW_MARGIN`.
- All final positions are clamped within the visible viewport, subtracting the same margin on each edge to avoid edge‑hugging.

## 5.6 Godot 4 Compatibility & Style Constraints

- __Typed GDScript__: When combining `Rect2/Rect2i` components with float math, annotate intermediates as `float` and cast with `float(...)` to prevent inference errors.
- __Transforms__: Replace deprecated `xform` with `xform_point`/`xform_vector` everywhere.
- __Timing__: Use `Time.get_ticks_msec()` instead of `OS.get_ticks_msec()`.
- __Indentation__: Tabs‑only in all GDScript files. Mixing spaces causes parser errors ("Used space character for indentation instead of tab").

## 5.7 Diagnostics

- Debug builds print detailed placement logs, including:
  - Parent selection and rects: `[WM] deferred/finalize child pos (...) parent=... pr=Rect2(...)`
  - Anchor rects for root/child: `ar=Rect2(...)`
  - Hint branch taken: `(top_center_over_anchor)`, `(left_of_anchor)`, `(parent‑only by hint)`, etc.
- These logs are essential to debug inconsistent placement across Inventory, Battle Board, and EnemyLineup.

## 5.8 Context‑Specific Rules

- __EnemyLineup (Units)__: root UnitInspectionWindow uses `left_of_anchor` to open left of the GachaBall.
- __Equipped Items (Player & Enemy)__: ItemInspectionWindow is always positioned relative to the parent UnitInspectionWindow (`use_parent_window`), never the item’s small GachaBall slot.
- __ChoiceWindow__: root contextual prompt uses `top_center_over_anchor` and the same screen‑space setter.
6. Implementation & Refactoring Notes
This section highlights the critical discrepancies between the current codebase and this target architecture. The following changes are required to achieve the desired behavior.
Refactoring InventoryWindow and DiscardPileWindow:
Current State: The code in WindowManager.gd opens these windows using open_modal_window(), which incorrectly adds them to the _modal_stack and attaches a BackgroundBlocker.
Required Change: These windows must be re-categorized as Fixed-Position Contextual Windows. The WindowManager must be modified to open them via a method similar to _open_inspection_window. They must be added to the _active_inspection_group, not the modal stack, and must not have a BackgroundBlocker. Their scenes (.tscn files) must have the BackgroundBlocker instance removed.
Refactoring ChoiceWindow:
Current State: Like the inventory, this is currently opened as a modal with a blocker.
Required Change: This must also be re-categorized as a Dynamic-Position Contextual Window. The WindowManager must be modified to open it without a blocker and add it to the _active_inspection_group. The GIR will be responsible for interpreting a click outside this window as a cancellation of the action. The BackgroundBlocker instance must be removed from its scene file.
By implementing these changes, the InventoryWindow and ChoiceWindow will correctly join the inspection hierarchy, allowing for seamless interactions like inspecting a unit within the inventory and having all windows close correctly on a global background click, thus unifying the entire windowing system under a single, consistent set of rules.

Post-Refactor Status (Implemented):
- Inventory, DiscardPile, and Choice are opened via the unified contextual path and added to `_active_inspection_group` (no blockers).
- WindowManager no longer processes raw input; GIR owns input interpretation and issues commands.
- A local background-click API is provided: `handle_inspection_background_click(window)` prunes only the clicked window's descendants (W3). Global background clicks remain under GIR.
- A public child-opening API is provided: `open_child_contextual_window(window_type, anchor_view, populate_ctx)`.
- Contextual windows must NOT include `BackgroundBlocker`. Only Hermetic Modals (e.g., `FlashcardMinigame`, `EndBattlePopup`, `ResultsPopup`) use a blocker.

---

# v6.0 Addendum: Robust Ancestor Lookup and Pruning Contract

## New/Clarified Public APIs
- __[find_ancestor_window_for_view(node: Node) -> Control]__
  - Resolve the owning inspection window for any node. Used by GIR to determine inside/outside and the correct parent for pruning.
- __[handle_inspection_background_click(clicked_window: Control)]__
  - Called by a window on local background clicks to prune only its descendants (W3).
- __[close_children_of(parent_window: Control)]__
  - Public executor for GIR’s `CLOSE_CHILD_WINDOWS` command when a parent is already known.
- __[open_child_contextual_window(type, anchor_view, populate_ctx)]__
  - Opens a child window anchored to the given parent view, enforcing W1 Single‑Child policy.

## GIR ↔ WindowManager Contract (Operational)
- __GIR responsibilities__
  - Interpret clicks and links; resolve `parent_window` via `find_ancestor_window_for_view`.
  - Issue `CLOSE_CHILD_WINDOWS`, `CLOSE_ALL_INSPECTION_WINDOWS`, and open commands with clear precedence.
- __WindowManager responsibilities__
  - Execute lifecycle: open/close windows; maintain `_active_inspection_group` order; position/track anchors.
  - Provide reliable ancestor resolution without relying on scene assumptions.

---

# v6.1 Addendum: ChoiceWindow Dynamic Top-Center Anchoring

This addendum documents the final implementation for the ChoiceWindow (Swap/Merge prompt) as a dynamic-position contextual window that appears top-centered over the target GachaBall.

## Public API: open_choice_window

```
WindowManager.open_choice_window(populate_ctx: Dictionary, anchor_view: Control = null)
```

- __populate_ctx requirements__
  - Must include at least `target_location` (preferred). Optionally `source_location`.
  - Example from `InventoryManager` when a merge recipe exists:
    - `{ "source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id }`
- __anchor resolution order__
  1. Use provided `anchor_view` if valid.
  2. Resolve from `populate_ctx.target_location` via `find_view_for_location(loc)`.
  3. Fallback to `populate_ctx.source_location` via `find_view_for_location(loc)`.
- __positioning hint__
  - The call sets `positioning_hint = "top_center_over_anchor"` in the contextual `context` passed to `_open_contextual_window()`.

## New/Clarified Helpers

- __find_view_for_location(loc: LocationIdentifier) -> Control__
  - BFS over the scene tree to find a `Control` with `meta["location_identifier"]` equal to `loc`.
  - Views set this metadata in their `populate()` (e.g., `GachaBallView.set_meta("location_identifier", loc)`).
- ___locations_equal(a, b) -> bool__
  - Field-wise compare via `Object.get()` for `container`, `index`, and `unit_uuid`; avoids reference-equality pitfalls.

## Positioning Behavior

- `_deferred_position(window, anchor, parent_window, pos_hint)` now honors:
  - `top_center_over_anchor` → `_calculate_top_center_over_anchor(anchor, window)`
  - `center_over_anchor` → `_calculate_centered_over_anchor(anchor, window)`
  - default → `_calculate_window_position(anchor, window)` (side/below/above heuristic)
- __Top-center placement__ (`_calculate_top_center_over_anchor`):
  - Center horizontally on `anchor_rect.get_center().x`.
  - Position above anchor by `INSPECTION_WINDOW_MARGIN`.
  - Clamp within viewport with the same margin.

## Parenting Fallback for Child Requests

- When an `anchor_view` is valid but `_find_ancestor_inspection_window(anchor_view)` returns null, we assume the top of `_active_inspection_group` is the intended parent and prune children of that parent instead of closing the entire group.
- Rationale: Inventory/board hosting may not be direct ancestors of the anchor view; this retains the active group and preserves the anchor.

## v6.2 Addendum: Suppression‑Aware Closures & Deferred Anchor Handling

This addendum documents how the WindowManager cooperates with the GIR’s close‑suppression to prevent premature closure of inspection windows when anchors are freed or reparented during inventory actions (swap/merge/equip).

### Principles

- __Never close blindly__: Always use `WindowManager.request_close_inspection_window(window, cause)` for closing contextual windows. This API checks GIR suppression before performing any close.
- __ID‑targeted suppression__: GIR activates suppression for a specific parent window ID. While suppression is active, close requests for that window are deferred or ignored.
- __Deferred anchors__: When a window’s anchor is freed/replaced, WindowManager emits a deferred close via `request_close_inspection_window(window, "ANCHOR_FREED")`. GIR suppression must be active during this window to avoid premature closure.

### Relevant Public Helpers

- `find_view_for_location(loc: LocationIdentifier) -> Control`
- `find_ancestor_window_for_view(view: Control) -> Control`
- `request_close_inspection_window(window: Control, cause: StringName = &"")`
- `close_children_of(parent_window: Control)` / `CLOSE_CHILD_WINDOWS(parent)` (command from GIR)

### ChoiceWindow Interaction

- `open_choice_window(populate_ctx, anchor_view?)` opens a non‑exclusive contextual prompt without closing existing inspection windows.
- After the user makes a choice, `ChoiceWindow` emits `choice_made` then `close_modal_requested`. The actual swap/merge must ensure GIR suppression is active for the affected inspection window.
- Implementation reference: `InventoryManager._on_choice_made` resolves the affected `parent_window` via `find_view_for_location` and `find_ancestor_window_for_view`, then asks GIR to activate suppression for that window ID before executing the action.

### Diagnostics

- WindowManager logs all suppression‑aware close attempts:
  - `WindowManager: request_close_inspection_window window=... (...) cause=... suppressed_for_id=... suppressed_now=...`
- Use alongside GIR logs (suppression activation/expiry) to trace any premature closure.

## Scene Requirements for ChoiceWindow

- Root node is a `PanelContainer` (not fullscreen `Control`).
  - Anchors set to top-left (0,0,0,0) with `custom_minimum_size` (e.g., 300×150).
  - No inner auto-centering container that would override `global_position`.
  - This ensures WindowManager’s pixel positioning is respected.

## Closing Behavior

- ChoiceWindow emits `SignalBus.close_modal_requested` after `choice_made`.
- `WindowManager._close_top_modal()` was extended to also close the top contextual window when the modal stack is empty. This allows contextual prompts like ChoiceWindow to close themselves cleanly without being true modals.

## Summary

- ChoiceWindow is fully integrated as a dynamic-position contextual window.
- It appears top-centered above the target GachaBall, tracks the active inspection group correctly, and closes on choice.

## Scene Parenting and Mouse Filter Requirements
- __Parenting:__ interactive nodes inside a window must be children of that window in the scene tree to enable correct ancestor resolution.
- __Mouse filters:__
  - Root window Control: `mouse_filter = MOUSE_FILTER_STOP` to ensure `_gui_input` receives non‑link clicks.
  - Background/Grids that represent local background: `MOUSE_FILTER_STOP` and call `handle_inspection_background_click(self)`.
  - RichTextLabel with UI links: `MOUSE_FILTER_PASS`; consume link clicks in `meta_clicked` with `accept_event()` and `get_viewport().set_input_as_handled()`.
  - Other child Controls: prefer `MOUSE_FILTER_PASS` unless they implement specific interactions.

## Pruning Precedence and Flow
- __Local prune (W3):__ window background click → window calls `handle_inspection_background_click(self)` → close only descendants.
- __Inside‑window interaction:__ GIR resolves ancestor and issues `CLOSE_CHILD_WINDOWS(parent)` before handling the new action.
- __Global close (W4):__ GIR detects true outside click and issues `CLOSE_ALL_INSPECTION_WINDOWS`.

## Quick Integration Checklist
- Windows anchor correctly and are parented under the window instance.
- Root window `_gui_input` wired; background surfaces call local prune API.
- RichText labels pass non‑link clicks; link clicks consumed locally; GIR handles UI_LINK by pruning parent children first.
- Verified in: Inventory, Battle Board, Shop, Rewards, Unit/Item/Effect windows.