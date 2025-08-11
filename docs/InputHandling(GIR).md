Input Handling & Selection - V3.3 (Definitive Blueprint)
Version: 3.3
Status: Canonical & Final
This document describes the definitive, centralized architecture for handling all user input, selection, and drag-and-drop state in Flashcard Heroes. It supersedes all previous documents on this topic. The Global Interaction Router (GIR) is the single, indivisible source of truth for this entire system.
1. Core Philosophy & Architecture
The system is built on a Centralized, Command-Driven Architecture to eliminate state conflicts and ensure a predictable, robust user experience.
The GIR as the Central Nervous System: The GlobalInteractionRouter.gd autoload singleton is the sole interpreter of user intent AND the sole holder of all transient interaction state. It receives standardized information packets from the UI, analyzes them against a strict set of rules, and produces a clear, ordered set of instructions.
The Command Queue as the Voice: The GIR's only output is a Command Queue—an ordered array of commands. It dispatches these commands to specialist "service" managers (WindowManager, InventoryManager) who are responsible for execution.

## v3.4 Addendum: Suppression Windows & REQUEST_ACTION Execution Details

This addendum clarifies how GIR activates close‑suppression during request actions and how that integrates with ChoiceWindow‑driven inventory actions.

### Suppression Model

- __Purpose__: Prevent premature closure of inspection windows due to deferred anchor checks or transient reparenting while actions execute.
- __Activation__: During `REQUEST_ACTION` execution, GIR determines a target parent window ID (via source/target contexts or explicit `target_parent_window_id` in the command context) and calls `_activate_close_suppression_for_window_id(window_id, duration_ms)`.
- __Duration__: Short by default; may be extended for actions within unit inspection contexts. Durations should exceed any known deferred close windows.
- __Query__: WindowManager consults GIR via `is_close_suppressed_for_window_id(id)` and `is_close_suppressed_now()` before closing.

### REQUEST_ACTION Emission and Handling

- __Generation__: GIR generates `REQUEST_ACTION` when selection + target contexts are compatible for an inventory action.
- __Execution__: On execution, GIR emits `SignalBus.try_inventory_action(source_loc, target_loc)` and activates suppression around the relevant window. InventoryManager performs early equip/swap/merge detection and may open `ChoiceWindow` if ambiguous.

### ChoiceWindow Integration (Swap/Merge)

- __Prompt__: Opened by InventoryManager through `WindowManager.open_choice_window(context)`; designed as a non‑exclusive contextual window that does not close existing inspection windows.
- __Decision__: On `choice_made`, InventoryManager must ensure suppression is active for the affected parent window just before executing `_swap`/`_merge`. It resolves the window via `WindowManager.find_view_for_location(...)` and `find_ancestor_window_for_view(...)`, then calls GIR suppression activation.
- __Why in InventoryManager__: Routing the choice back through GIR `REQUEST_ACTION` would duplicate prompts and complicate suppression timing. Keeping execution local with explicit suppression preserves determinism.

### Diagnostics & Logging

- GIR logs suppression activations with window IDs and expiry times when `_activate_close_suppression_for_window_id(...)` is called.
- WindowManager logs suppression state on every `request_close_inspection_window(...)` attempt, enabling cross‑correlation.

## v3.5 Addendum: COMBAT Phase Interaction Policy (2025-08-11)

Purpose
- Ensure player input does not disrupt animator‑driven, per‑effect combat pacing.

Rules
- During `Phases.COMBAT`, GIR must not emit `REQUEST_ACTION`. Click‑to‑click and drag‑drop inventory operations are disabled.
- Background/Escape inputs still apply per Section 5.1, but must not interrupt the animator; they only close windows or clear selection.
- Selection/inspection inside windows remains allowed where appropriate (inspection‑only), but actions are gated until combat ends.

Implementation Notes
- GIR should gate `REQUEST_ACTION` generation with a phase check against `BattleManager`'s current phase (COMBAT) and instead emit `INVALID_ACTION` when in COMBAT.
- Visual feedback: views should reflect non‑interactive state (e.g., dim highlights) while COMBAT is active.
- No blocking: signal handlers must return immediately; the animator yields one frame after each event to allow UI to render.

## v3.6 Addendum: Full Input Lock During COMBAT (2025-08-11)

Supersedes v3.5 by enforcing a complete input lock while `BattleManager` is in `COMBAT`.

Policy
- All interaction contexts are ignored by GIR during COMBAT. No command queues are generated.
- Unhandled input (ESC/background clicks) is ignored. GIR performs no window/selection operations.
- Drags cannot start; drag visuals are suppressed and placeholders freed if invoked.
- No `REQUEST_ACTION` is emitted, and GIR does not emit `INVALID_ACTION` either; it simply returns.

Rationale
- Prevent any user action from racing or interfering with animator-driven per-event pacing.
- Maintain deterministic state during combat resolution.

UI Guidance
- Views may optionally reflect a dimmed/non-interactive state while COMBAT is active. This is a UI concern and not enforced by GIR.
2. Core Interaction State (Held by GIR)
The GIR is a state machine that tracks the user's current interaction. It holds three key state variables:
Variable	Type	Description
_current_selection	InteractionContext	If not null, the game considers an entity to be selected. This is the truth for all selection.
_is_drag_active	bool	If true, the user is currently in a drag-and-drop operation.
_drag_origin_context	InteractionContext	If _is_drag_active is true, this holds the context of the entity where the drag began.

2.1 Command Types & Emission (Operational)
- Commands generated by GIR (`GlobalInteractionRouter.gd`):
  - `DESELECT`
  - `SELECT`
  - `OPEN_INSPECTION_WINDOW`
  - `CLOSE_ALL_INSPECTION_WINDOWS`
  - `CLOSE_CHILD_WINDOWS`
  - `REQUEST_ACTION`
  - `INVALID_ACTION`
- Execution details:
  - `REQUEST_ACTION` → GIR emits `SignalBus.try_inventory_action(source_loc, target_loc)` using `.location` from its stored `source_context` and the current `target_context`. See `GlobalInteractionRouter._execute_request_action`.
  - All command queues that include `REQUEST_ACTION` must immediately include `DESELECT` (Rule S6).
3. The InteractionContext Packet: The Universal Language
Every interactive UI element (GachaBallView, SlotView, a window background, etc.) is responsible for one task: when a user interacts with it, it must create and emit an InteractionContext packet. This is the standardized language that tells the GIR everything it needs to know.
Field	Type	Description
source_view_instance_id	int	The stable get_instance_id() of the UI node that was interacted with.
event_type	StringName	The gesture: SINGLE_CLICK, DOUBLE_CLICK.
location	LocationIdentifier	The logical game location of the entity (container, index, etc.). Can be null.
entity_type	StringName	The kind of thing interacted with: UNIT, ITEM, EMPTY_SLOT, WINDOW_BACKGROUND, GLOBAL_BACKGROUND.
interaction_mode	StringName	The ruleset for this context: FULLY_INTERACTIVE, SELECTION_ONLY, INSPECTION_ONLY.
window_group_id	int	The ID of the window group this element belongs to (0 = main scene).

3.1 Functional Group Resolution (Deterministic)
GIR owns container→functional group mapping for high-level gating:
- Battle board: `PlayerLineup`, `PlayerBench` → `BattleBoard`
- Inventory tiers: `RunInventoryT*`, `BattleInventoryT*` → `InventoryGrid`
- Non‑tiered item storage: `ItemInventory` → `InventoryGrid` (fix for click‑to‑click equip gating)
- Equipped items: `equipped_item` → `EquippedGrid`
- Selection‑only: `Rewards`, `Shop` → `SelectionOnly`
- Inspection‑only: `EnemyLineup`, `DiscardPile` → `InspectionOnly`

This mapping is implemented in `GlobalInteractionRouter._get_container_functional_group()` and is the single source of truth project‑wide.
4. The Definitive Rules of Selection & Deselection
These are the laws governing how selection is acquired, changed, and lost, enforced exclusively by the GIR.
Rule ID	Rule Name	Statement & Mechanism	Rationale
S1	The Singleton Selection Rule	Only one entity can be selected at any time. When selecting a new entity, the GIR's first command is always to DESELECT the old one.	Prevents state conflicts and visual clutter.
S2	The "Change of Focus" Rule	A click on a second entity that is not a valid action target for the first is interpreted as a "change of focus." The selection moves from the first entity to the second.	Creates a fluid UI, eliminating the need for extra "click-off" actions.
S3	The "Selection-Only" Context Rule	In contexts marked SELECTION_ONLY (Shop, Rewards), any click on another selectable item is always a "change of focus."	Enforces the specific game design of these scenes, where the only possible intent is to choose one item from a list.
S4	The Re-Selection Inspects Rule	A single-click on an already-selected entity is interpreted as a request to inspect it. The GIR will generate the same command queue as a double-click.	Provides a more forgiving and accessible way to inspect items. It makes the UI feel more responsive.
S5	The Inspection Request Rule	A double-click on a selectable entity is interpreted as a request to inspect it. The GIR issues a [DESELECT, OPEN_INSPECTION_WINDOW] command queue.	Provides a clear, unambiguous user pattern. Deselection is crucial to prevent a "stuck" selection state.
S6	The Deselection on Action Rule	Any command queue containing a REQUEST_ACTION command must be immediately followed by a DESELECT command. The selection is cleared immediately, regardless of whether the action is ultimately successful.	Decouples the UI state from gameplay logic, preventing "stuck" highlights while waiting for validation.
5. The Definitive Rules of Input Handling & Command Generation
This section details how the GIR translates raw input into command queues. It explicitly covers all interaction models and edge cases.
5.1 High-Priority Interrupts: Scene Transitions, Background Clicks & Escape Key
These inputs have the highest priority and are handled by dedicated functions within the GIR, preempting the main logic flow.
Mechanism 1: Scene Transition Cleanup (Edge Case 4.1)
Trigger: The GIR, as a persistent singleton, subscribes to all major scene change signals (main_scene_requested, path_choice_scene_requested, etc.).
Action: Upon receiving any of these signals, the GIR immediately and synchronously clears all of its internal state. It calls cancel_active_drag() and _execute_deselect().
Rationale: Prevents "ghost" selections where the GIR holds a reference to a UI element that has been destroyed during a scene transition. This guarantees a clean state upon entering any new scene.
Mechanism 2: _unhandled_input Interceptor
Trigger: This engine-level callback fires only when an input event is not consumed by any UI element. This is the 100% reliable way to detect a "true" background click or an unhandled keypress.
The Escape Key Precedence: On a ui_cancel (Escape) key press, the GIR checks its own state and the WindowManager's state in this exact order:
Is a drag-and-drop active? (_is_drag_active == true) -> Immediate Action: The GIR calls its own cancel_active_drag() method.
Else, are any Contextual Windows open? (_window_manager.is_any_inspection_window_open()) -> Command Queue: [CLOSE_ALL_INSPECTION_WINDOWS].
Else, is an entity selected? (_current_selection != null) -> Command Queue: [DESELECT].
The Global Background Click: If _unhandled_input fires due to a mouse click, it represents a click on a non-interactive area.
Command Queue: [CLOSE_ALL_INSPECTION_WINDOWS, DESELECT].
5.2 The Main Interaction Logic Flow: The GIR's Decision Tree
When the GIR's _on_interaction_context_received function fires with an InteractionContext, it executes the following logic tree. This single tree handles all interaction types.
START: InteractionContext Received
1. Is a Drag Active?
Check if self._is_drag_active:.
YES: This incoming context is the destination of a drag-and-drop.
Action: Assemble the action data. The Source is the stored _drag_origin_context. The Target is the context just received.
Command Queue: [REQUEST_ACTION, DESELECT] (per Rule S6).
Cleanup: Call self.end_drag().
END OF FLOW.
NO: This is a standard click event. Proceed to Step 2.
2. Is this an Inspection Request?
Check if context.event_type == DOUBLE_CLICK:.
YES: This is a direct inspection request (Rule S5).
Command Queue: [DESELECT, OPEN_INSPECTION_WINDOW].
END OF FLOW.
NO: This is a single-click. Proceed to Step 3.
3. Are any Contextual Windows Open?
Check if _window_manager.is_any_inspection_window_open():.
YES: At least one inspection window is open. We must now determine the nature of the click.
Sub-Check A: Is the click outside the active window group?
The GIR determines this by checking if the incoming context.window_group_id is different from the ID of the active inspection group (which is typically 1, while the main scene is 0).
YES (Outside): This is a "Click-Through" interaction (Rule W2). The user is ignoring the open windows and focusing on something on the main scene.
Sub-Check B: Is the clicked entity selectable?
The GIR checks if context.entity_type in [UNIT, ITEM, EMPTY_SLOT] and context.interaction_mode != INSPECTION_ONLY.
YES (Selectable): The user clicked a valid new focus target.
Command Queue: [CLOSE_ALL_INSPECTION_WINDOWS, SELECT]. This is the classic "click-through" case.
END OF FLOW.
NO (Not Selectable): The user clicked something outside the windows, but it's not something they can select (e.g., a non-interactive part of the background, a disabled button). This is functionally equivalent to a Global Background Click.
Command Queue: [CLOSE_ALL_INSPECTION_WINDOWS, DESELECT]. Note the crucial difference: we DESELECT because there is no valid new selection.
END OF FLOW.
NO (Inside): The click is within the currently active inspection group. The user is interacting with the windows themselves.
Sub-Check C: What was clicked inside the window group?
The GIR checks context.entity_type.
Case 1: entity_type is WINDOW_BACKGROUND. The user clicked the empty panel space of a window. This triggers the Window Pruning Rule (W3).
Command Queue: [CLOSE_CHILD_WINDOWS], with the parent_window_id from the context.
END OF FLOW.
Case 2: entity_type is UNIT, ITEM, or EMPTY_SLOT. The user clicked on a GachaBall or a slot inside an inspection window (e.g., an item equipped on an inspected unit). This is a standard interaction that should proceed to the selection/action logic.
Action: Proceed to Step 4 of the main logic tree.
Case 3: entity_type is UI_LINK or similar. The user clicked a special interactive element within the window.
Action: Handle as a specific UI interaction (e.g., opening a child "Effects" window). The command queue might be [CLOSE_CHILD_WINDOWS, OPEN_INSPECTION_WINDOW].
END OF FLOW.
NO: No inspection windows are open. The UI is in its base state.
Action: Proceed to Step 4 of the main logic tree.
4. Is an entity currently selected?
Check if self._current_selection != null:.
YES: An entity is already selected. This click represents the target of a potential click-click action.
Sub-Check 1: Is this a re-selection? (Compare context.source_view_instance_id to the ID in _current_selection).
YES: This is a re-selection, which is an implicit inspection request (Rule S4).
Command Queue: [DESELECT, OPEN_INSPECTION_WINDOW].
END OF FLOW.
Sub-Check 2: Is this a valid action target? (The GIR performs a high-level check on the context groups of the source (_current_selection) and target (context)).
YES: The contexts are compatible for a potential action. Allowed cross‑group targets include:
  - `InventoryGrid → EquippedGrid` (equip into unit slot)
  - `InventoryGrid → BattleBoard` (equip item onto unit via unit click)
Command Queue: [REQUEST_ACTION, DESELECT] (Rule S6).
END OF FLOW.
NO: The contexts are incompatible. This is a "Change of Focus" (Rule S2).
Command Queue: [DESELECT, SELECT].
END OF FLOW.
NO: Nothing is currently selected. This click is a primary selection.
Command Queue: [SELECT].
END OF FLOW.
6. Drag-and-Drop Implementation Details
The GIR's management of drag-and-drop state is what enables the unified logic tree above.
start_drag(context): Called by a view's _get_drag_data. It clears any current selection, sets _is_drag_active = true, and stores the context in _drag_origin_context.
end_drag(): Called by the GIR after a successful drop or by a view's _notification on a cancelled drop. It sets _is_drag_active = false, clears _drag_origin_context, and ensures the source view is made visible again if the drag was not handled.
This comprehensive logic tree, with the GIR managing all interaction states, covers every possible user scenario—both click-click and drag-drop—in a deterministic and unified way. It forms the complete blueprint for the game's new, robust, and maximally simplified input handling and selection architecture.