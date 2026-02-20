
📌 IMPLEMENTATION BRIEF
Feature: Unified Hover-to-Inspect + Select-to-Lock System
Project: Existing GIR + WindowManager Architecture
🔴 DO NOT BREAK EXISTING SYSTEM

You are modifying a production interaction system with strict architectural rules.

You MUST preserve:

GlobalInteractionRouter (GIR) as the only interpreter of InteractionContext

WindowManager as the only window lifecycle executor

The Command Queue pattern (GIR generates → WindowManager executes)

Suppression timing logic

Hierarchical window model (W1)

Selection rules (S1–S6)

Window rules (W1–W6)

Drag-and-drop semantics

Combat phase lock

Anchor stability logic

Child window pruning (W3)

Global close rules (W4)

Escape behavior (W5)

Do not bypass the command system.
Do not call WindowManager directly outside commands.
Do not invent new APIs unless absolutely necessary.
Do not assume window ownership hierarchy incorrectly.
Do not infer parent windows without using existing resolution logic.

You must reason from the real codebase provided.

🎯 GOAL

Implement:

1️⃣ Passive Hover-to-Inspect (PC Only)

HOVER_ENTER opens ContextualWindow.

HOVER_EXIT closes it.

Only if no entity is locked.

Only one root inspection chain allowed.

Must respect suppression.

Must not open during drag.

Must not open if in COMBAT.

2️⃣ Select-to-Lock (Unified Click/Tap)

Single click must:

Perform normal selection logic.

Perform normal action resolution logic.

If no REQUEST_ACTION or INVALID_ACTION generated:

Open inspection window.

Lock it (sticky state).

If entity already locked:

Do nothing (no churn).

If different entity:

Replace inspection window safely.

Clicking inside inspection window must NOT replace root.

3️⃣ Drag and Drop Safety

When drag starts:

Clear hover state.

Clear lock state.

DO NOT forcibly close parent window.

DO NOT interfere with suppression.

While dragging:

No hover inspection allowed.

No lock inspection allowed.

On drop:

Preserve existing behavior exactly.

Do NOT auto-open inspection.

Do NOT auto-select drop target.

Do NOT modify REQUEST_ACTION logic.

4️⃣ Inspection-Only Contexts

EnemyLineup, DiscardPile, PlayerTrinkets:

Hover works.

Click locks inspection.

Cannot be selected for actions.

Cannot interfere with selection logic elsewhere.

5️⃣ Selection-Only Contexts

Shop, Rewards:

Click changes focus (S3).

Click again on same item locks inspection.

No breakage of shop purchase flow.

⚠️ KNOWN FAILURE MODES FROM PREVIOUS ATTEMPTS

You must explicitly avoid:

Inventing nonexistent APIs.

Inferring window ownership incorrectly.

Using CLOSE_ALL without suppression awareness.

Using _current_selection as hover discriminator.

Breaking REQUEST_ACTION ordering.

Injecting CLOSE_ALL before action commands.

Ignoring suppression windows during swap/merge.

Closing parent windows during drag.

Inferring root window via ancestor of anchor.

Not guarding duplicate hover events.

Double-triggering via SINGLE_CLICK + LONG_PRESS.

Clearing lock state during deselect events unintentionally.

Conflating selection state with inspection lock state.

Attempting to solve everything inside one handler without respecting window lifecycle ownership.

Breaking hierarchical rule (W1).

Changing behavior in SelectionOnly contexts.

Treating hover as just another inspection event.

Breaking anchor stability during suppression.

Not distinguishing root vs child contextual windows.

Failing to validate against UIInteraction.md rules.

📚 ARCHITECTURE CONTEXT
GlobalInteractionRouter (GIR)

Sole interpreter of InteractionContext.

Generates Command array.

Executes via _execute_command_queue.

WindowManager

Owns inspection window lifecycle.

Enforces hierarchy.

Performs anchor resolution.

Applies suppression.

Suppression System

activate_close_suppression_for_window_id(id, duration)

_is_close_suppressed_now()

_is_close_suppressed_for_context(context)

Suppression prevents CLOSE_ALL during swap/merge timing window.

If CLOSE_ALL is suppressed but OPEN still executes, duplicate root windows can occur.
You must prevent this.

🧠 REQUIRED DESIGN APPROACH

You must:

Introduce a separate UI lock state that does NOT depend on _current_selection.

Track hover state separately.

Inject hover logic early in _generate_command_queue.

Inject lock logic after entity-specific handlers.

Detect REQUEST_ACTION and INVALID_ACTION before applying lock logic.

Respect suppression in BOTH hover and click paths.

Avoid modifying existing selection or action logic unless strictly necessary.

Preserve existing _is_inspection_event behavior where appropriate.

Remove DOUBLE_CLICK dependency safely if replaced.

Validate every change against:

Selection Rules S1–S6

Window Rules W1–W6

Combat Phase Lock

Drag lifecycle

Suppression behavior

Window hierarchy

🧪 I WILL TEST THESE SCENARIOS

The implementation must pass all:

Hover Tests

Hover A → opens.

Hover B → replaces.

Hover exit → closes.

Hover while locked → ignored.

Hover during suppression → ignored.

Hover during drag → ignored.

Click Tests

Click A → select + lock.

Click A again → no churn.

Click B → replace.

Click B valid action → no inspection change.

Click invalid target → close + no reopen.

Click inside inspection child → prune only.

Drag Tests

Drag A with locked window → window remains.

Drag A clears lock state.

Drop B → no auto-open.

Drop B valid action → action only.

Suppression Tests

Swap via ChoiceWindow → suppression active.

During suppression click C → no duplicate root.

During suppression hover D → no duplicate root.

SelectionOnly Tests

Shop click A → select only.

Shop click A again → lock.

Shop purchase → no interference.

InspectionOnly Tests

EnemyLineup hover → open.

Click → lock.

No selection for move/swap.

🛑 STRICT RULES

Do not alter WindowManager behavior unless absolutely necessary.

Do not create parallel inspection tracking.

Do not bypass suppression.

Do not alter drag resolution logic.

Do not alter action resolution order.

Do not close windows outside suppression guard.

Do not break anchor stability.

🧩 EXPECTED OUTPUT

The implementation must:

Provide a minimal diff.

Modify only necessary parts.

Be compatible with the provided codebase.

Avoid introducing compile errors.

Avoid modifying unrelated systems.

Before finalizing, you must produce a short reasoning summary explaining:

Why suppression cannot cause duplicate roots.

Why action flow is preserved.

Why drag semantics remain intact.

Why hierarchy rules remain intact.

📎 REFERENCE DOCUMENTS

Use:

AllProjectFiles.md

UIInteraction.md

as authoritative system documentation.

🎯 FINAL OBJECTIVE

Implement the new behavior without changing any other existing system behavior, preserving the integrity of:

Interaction routing

Window lifecycle

Suppression timing

Selection model

Drag system

Combat lock

Hierarchy enforcement

If a design choice risks breaking any of the above, you must redesign before coding.

---

## 🧠 AGENT SELF-NOTES (Added During Planning)

### Code Locations Map
- **GachaBallView._gui_input → L996-1019** — Click/double-click emission, modify here
- **GachaBallView._ready → L67** — Connect mouse_entered/mouse_exited here
- **GachaBallView._exit_tree → L138** — Disconnect hover signals here
- **GIR._on_interaction_context_received → L79-90** — Intercept HOVER events BEFORE command queue
- **GIR._generate_command_queue → L146** — Normal click path, NOT for hover
- **GIR._handle_fully_interactive → L251-298** — Lock on first click (L294), no-churn on re-click (L258)
- **GIR._handle_selection_only → L301-322** — Lock on S4 re-select
- **GIR._handle_gachaball_interaction → L222** — INSPECTION_ONLY lock at L241
- **GIR._is_inspection_event → L387** — Deprecated to return false
- **GIR.start_drag → L714** — Clear lock + hover state here
- **GIR._unhandled_input → L93-119** — Clear lock on ESC and background click
- **GIR._on_battle_phase_changed → L134** — Clear lock on COMBAT entry
- **GIR._on_selection_clear_requested → L122** — Clear lock on scene transitions

### Scene Structure Differences (CRITICAL)
- **Battle Board**: SlotView → GachaBallView, mode=FULLY_INTERACTIVE, parent=BattleView
- **Inventory Window**: SlotView → GachaBallView, mode=FULLY_INTERACTIVE, parent=InventoryWindow
- **Enemy Lineup**: SlotView → GachaBallView, mode=INSPECTION_ONLY, parent=BattleView
- **Shop/Rewards**: SlotView → GachaBallView, mode=SELECTION_ONLY, parent=Shop/Reward
- **DiscardPile/Trinkets**: SlotView → GachaBallView, mode=INSPECTION_ONLY

### 🔴 BATTLE BOARD vs INVENTORY WINDOW: Command Flow Divergence

The same user action (hover/click a GachaBall) follows DIFFERENT paths through the TDD close
section of `_generate_command_queue` depending on whether the anchor is in the battle board or
inside an existing inspection window like InventoryWindow.

**Battle Board (anchor NOT inside any tracked window):**
1. `find_ancestor_window_for_view(anchor)` → returns `null`
2. L224 condition is false → **NO child-pruning command**
3. `_is_click_inside_inspection_group(context)` → returns `false` (click is outside windows)
4. Reaches CLOSE_ALL check → locked-entity guard suppresses it
5. Handler generates SELECT only → ✅ window stays open

**Inventory Window (anchor IS inside a tracked window):**
1. `find_ancestor_window_for_view(anchor)` → returns **InventoryWindow**
2. L224 condition is true → **CLOSE_CHILD_WINDOWS(InventoryWindow) fires**
3. This kills ALL children of InventoryWindow, INCLUDING the hover/locked inspection child
4. `_is_click_inside_inspection_group(context)` → returns `true` → CLOSE_ALL skipped
5. Handler sees `_is_inspection_locked == true` → skips OPEN (thinks window is still there)
6. **Result: window destroyed but lock state says "still open" → broken invisible state**

**The fix** must guard TDD child-pruning (L220-227) so that when clicking a
GachaBall whose inspection window is currently locked/promoted, the prune does NOT
destroy that window. Specifically:
- If `_is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id`,
  skip the `CLOSE_CHILD_WINDOWS` command at L225.
- This preserves the locked child while still allowing OTHER child pruning rules to work
  (e.g., effects sub-windows get pruned by the handler, not the TDD pre-pass).

### Key Invariant
**Lock state ≠ Selection state**. They are SEPARATE variables with SEPARATE lifecycles.
- Lock: `_is_inspection_locked`, `_locked_entity_view_id` → cleared on drag, ESC, background, COMBAT
- Selection: `_current_selection` → cleared on DESELECT command, action completion
- Lock SURVIVES focus changes and valid actions
- Lock does NOT survive drag, ESC, background click, or COMBAT entry

### Dependencies to NOT Miss
1. **GachaBallView._is_inspectable** — gate hover emission on this flag
2. **GachaBallView._is_interactive** — does NOT gate hover (hover works even on non-interactive)
3. **DisplayServer.is_touchscreen_available()** — gate hover on PC only
4. **WindowManager._open_contextual_window** — already enforces W1 (no duplicate roots)
5. **Suppression check** — _is_close_suppressed_now() must gate BOTH hover-open AND hover-close
6. **_is_click_inside_inspection_group** — already prevents CLOSE_ALL from inside-window clicks

### 🔴 LESSONS LEARNED (Bugs Encountered During Implementation)

1. **HOVER-EXIT MUST USE `close_top_contextual_window()`, NEVER `CLOSE_ALL_INSPECTION_WINDOWS`.**
   - When a GachaBall lives inside an InventoryWindow (which is itself an inspection window),
     using CLOSE_ALL on hover-exit destroys the parent InventoryWindow along with the
     hover-opened child. This breaks the "root vs child" distinction (brief L179).
   - `close_top_contextual_window()` removes ONLY `_active_inspection_group.back()` — the
     topmost window — preserving all parents.
   - This bug recurred 3+ times despite being warned in the brief under:
     - L147: "Using CLOSE_ALL without suppression awareness"
     - L179: "Not distinguishing root vs child contextual windows"
     - L175: "Treating hover as just another inspection event"

2. **HOVER-EXIT MUST RESPECT SUPPRESSION.**
   - The brief (L329) says "Do not close windows outside suppression guard."
   - Hover-exit must check `_is_close_suppressed_now()` before closing.

3. **HOVER HANDLERS BYPASS THE COMMAND QUEUE BY DESIGN.**
   - Hover events are intercepted in `_on_interaction_context_received` BEFORE
     `_generate_command_queue` is called. They call WindowManager directly
     (for close_top) or via a mini-command-queue (for open).
   - This is intentional: hover should never participate in the click→command flow.

4. **CLICK ON HOVERED ENTITY MUST PROMOTE HOVER TO LOCK, NOT CLOSE→REOPEN.**
   - When click arrives for the same entity as `_hover_entity_view_id`, we MUST:
     1. Promote: set `_is_inspection_locked = true`, `_locked_entity_view_id = _hover_entity_view_id`
     2. Clear hover: `_hover_entity_view_id = -1`
     3. Let the rest of the flow see the window as "already locked"
   - The TDD close section in `_generate_command_queue` must also check:
     if `_is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id`,
     treat as suppressed (skip CLOSE_ALL).
   - Handler else-branches must check: if already locked on this entity, skip OPEN command.
   - Without all THREE guards, the sequence is:
     clear hover → TDD fires CLOSE_ALL → handler fires OPEN → visible flicker (brief L271-273 violation).

5. **TDD CHILD-PRUNING FIRES DIFFERENTLY IN INVENTORY vs BATTLE BOARD.**
   - The TDD pre-pass in `_generate_command_queue` calls `CLOSE_CHILD_WINDOWS(parent)` whenever
     `find_ancestor_window_for_view(anchor)` finds a tracked parent window.
   - **Battle board**: anchor is NOT inside any tracked window → no child-pruning → no problem.
   - **Inventory**: anchor IS inside InventoryWindow → child-pruning fires → DESTROYS the
     locked inspection child → handler sees `_is_inspection_locked = true` → skips OPEN →
     broken invisible state.
   - **Fix**: guard child-pruning with `_is_inspection_locked and _locked_entity_view_id == context.source_view_instance_id`.

6. **HOVER EVENTS MUST BE GUARDED AT THE SOURCE (GachaBallView), NOT JUST GIR.**
   - During Godot's built-in drag (`_get_drag_data`/`set_drag_preview`), `mouse_entered`/
     `mouse_exited` still fire on controls the drag preview passes over.
   - GIR's `_handle_hover_enter` checks `_is_drag_active`, but the events still get emitted
     and processed through SignalBus, potentially reaching GIR before `_is_drag_active` is set
     (timing gap between `_get_drag_data` and `start_drag`).
   - **Fix**: GachaBallView's `_on_mouse_entered` and `_on_mouse_exited` must check BOTH:
     - `_is_dragging` (local flag, true for the ball being dragged)
     - `GlobalInteractionRouter.is_drag_active()` (global flag, true for ANY drag in progress)
   - This defense-in-depth stops hover events at the source, preventing any interaction
     during drag regardless of timing.

7. **`end_drag` MUST CALL `_execute_deselect()` TO CLEAR DRAG-SELECTION.**
   - `start_drag` calls `_execute_select(origin_context)` at L851 for visual feedback.
   - On handled drops, the command queue (REQUEST_ACTION → DESELECT) already clears selection.
   - On FAILED drops, `end_drag` was called without deselecting → `_current_selection`
     stayed stuck pointing at the dragged entity → "ghost selection" corruption.
   - This ghost selection broke ALL subsequent interactions: hover-to-lock promotion saw
     a stale selection, click handlers treated it as "re-select same entity", and the
     window system got into inconsistent states.

8. **UNIT vs ITEM DRAG VISUAL DIVERGENCE — UNRESOLVED (Partial Fix).**
    - **Resolution 1 (Visual Logic):** `UnitAnimationController`'s `top_level = true` bypasses visibility inheritance.
      **Fix:** `GachaBallView._process` now enforces `visible=false` while `_is_dragging` is true. This solved the "Ghost" visual.
    - **Resolution 2 (Logical Failure - Current Bug):** Reordering `start_drag` DID NOT prevent accidental deselection.
      **Current State:** Dragging a unit with the inspection window open immediately deselects it (`sel=false`). This causes:
        a) Drop to fail (activates "Select Target" instead of "Swap/Merge").
        b) Unit to disappear (end_drag fails to cleanup or restore visibility because the drag was "invalidated").
      **Plan:** Investigating the source of the deselection using stack traces in `_execute_deselect`. Suspect `UnitInspectionWindow` closure or input fall-through.
