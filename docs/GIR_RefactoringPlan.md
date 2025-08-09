Input Handling & Selection - V3.2 (Definitive Blueprint)
Version: 3.2
Status: Canonical & Final
This document describes the definitive, centralized architecture for handling all user input, selection, and drag-and-drop state in Flashcard Heroes. It supersedes all previous documents on this topic. The Global Interaction Router (GIR) is the single, indivisible source of truth for this entire system.
1. Core Philosophy & Architecture
The system is built on a Centralized, Command-Driven Architecture to eliminate state conflicts and ensure a predictable, robust user experience.
The GIR as the Central Nervous System: The GlobalInteractionRouter.gd autoload singleton is the sole interpreter of user intent AND the sole holder of all transient interaction state. It receives standardized information packets from the UI, analyzes them against a strict set of rules, and produces a clear, ordered set of instructions.
The Command Queue as the Voice: The GIR's only output is a Command Queue—an ordered array of commands. It dispatches these commands to specialist "service" managers (WindowManager, InventoryManager) who are responsible for execution.
2. Core Interaction State (Held by GIR)
The GIR is a state machine that tracks the user's current interaction. It holds three key state variables:
Variable	Type	Description
_current_selection	InteractionContext	If not null, the game considers an entity to be selected. This is the truth for all selection.
_is_drag_active	bool	If true, the user is currently in a drag-and-drop operation.
_drag_origin_context	InteractionContext	If _is_drag_active is true, this holds the context of the entity where the drag began.
3. The InteractionContext Packet: The Universal Language
Every interactive UI element (GachaBallView, SlotView, a window background, etc.) is responsible for one task: when a user interacts with it, it must create and emit an InteractionContext packet. This is the standardized language that tells the GIR everything it needs to know.
Field	Type	Description
source_view_instance_id	int	The stable get_instance_id() of the UI node that was interacted with.
event_type	StringName	The gesture: SINGLE_CLICK, DOUBLE_CLICK.
location	LocationIdentifier	The logical game location of the entity (container, index, etc.). Can be null.
entity_type	StringName	The kind of thing interacted with: UNIT, ITEM, EMPTY_SLOT, WINDOW_BACKGROUND, GLOBAL_BACKGROUND.
interaction_mode	StringName	The ruleset for this context: FULLY_INTERACTIVE, SELECTION_ONLY, INSPECTION_ONLY.
window_group_id	int	The ID of the window group this element belongs to (0 = main scene).
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
YES: The contexts are compatible for a potential action.
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

---

# v6.1 Addendum: ChoiceWindow (Swap/Merge) – Dynamic Anchoring & Closing

This addendum specifies how GIR coordinates the ChoiceWindow prompt so it appears top‑centered over the target GachaBall and closes correctly after a choice.

## When GIR requests ChoiceWindow

- __Trigger__: Rule I1 (Merge Priority). If a merge recipe exists for a source→target interaction, GIR instructs InventoryManager to pause action execution and open the ChoiceWindow.
- __Command__: GIR issues a WindowManager request with a `populate_ctx` payload that MUST include:
  - `target_location` (preferred). Optionally `source_location` as fallback.
  - Any extra metadata (e.g., `recipe_id`).

## Payload and Anchor Resolution Contract

- __Payload__: `{ "target_location": LocationIdentifier, "source_location": LocationIdentifier?, ... }`
- __Resolution Order (in WindowManager)__:
  1) Use an explicit `anchor_view` if the GIR passes one (usually omitted).
  2) Resolve from `populate_ctx.target_location` via `find_view_for_location(loc)`.
  3) Fallback to `populate_ctx.source_location` via `find_view_for_location(loc)`.
- __Positioning__: WindowManager sets `positioning_hint = "top_center_over_anchor"` so the ChoiceWindow is centered horizontally above the anchor and clamped to the viewport.

## Pruning & Parent Resolution

- GIR uses `WindowManager.find_ancestor_window_for_view(node)` when needed to determine the correct parent window for pruning before opening siblings/children (W1/W3).
- If an anchor resolves but no ancestor parent is found, WindowManager assumes the current top of `_active_inspection_group` as parent to avoid collapsing the group. GIR does not need per‑context exceptions.

## Scene/UI Requirements (enforced by GIR contract)

- __ChoiceWindow scene__: Root is a `PanelContainer` with top‑left anchors; no inner auto‑centering containers. This ensures pixel positioning works.
- __Anchorable views__: `GachaBallView`/`SlotView` set `meta["location_identifier"] = loc` during `populate()`. This is how WindowManager’s `find_view_for_location()` resolves an anchor reliably at runtime.

## Closing Behavior

- After the user chooses Merge/Swap, ChoiceWindow emits `close_modal_requested`.
- WindowManager’s `_close_top_modal()` now closes the top contextual window if no true modals exist, allowing ChoiceWindow to close itself cleanly while remaining a contextual window.

## Verification Checklist

- ChoiceWindow opens top‑centered above the target GachaBall in Inventory and Battle contexts.
- On choice, the prompt closes immediately; the inspection group remains consistent (parent intact, children pruned as needed).
- Outside clicks still follow W2/W4: click‑through or global close as determined by GIR.

Inventory & Gacha Systems - V2.0 (Unified)
Version: 2.0
Status: Canonical
This document describes the architecture and definitive rules for all GachaBall manipulation systems, including inventory actions (Move, Swap, Equip, Merge), the Gacha draw mechanism, and the Discard Pile lifecycle. The InventoryManager is the central, stateless service that executes the logic described herein.
1. Purpose & Core Philosophy
The InventoryManager is a stateless logic controller. It is the "verb" system for all GachaBall instances. Its sole purpose is to execute commands and signals related to GachaBall manipulation, validate them against a strict set of gameplay rules, and instruct the appropriate data owner (RunState or BattleManager) to perform the state change.
Core Principles:
Stateless Operation: The manager never stores its own state between actions. It always queries the current game state from the data owners.
Authoritative Validation: The manager is the final authority on whether a gameplay action is legal.
Command-Driven: Its primary entry point for player-initiated actions is the try_inventory_action signal, which is the final consequence of a REQUEST_ACTION command generated by the Global Interaction Router (GIR).
The Golden Rule of State Synchronization: All state change instructions sent to data owners must be atomic. This means any operation that moves an instance must update both the DataContainer (the index) and the GachaBallInstance's properties (the truth) in a single, indivisible operation.
2. The Definitive Rules of Action & Gameplay
This is the core logic that the InventoryManager enforces. It follows a strict priority checklist to determine and validate the player's intent for any interaction between two locations.
Rule I0: The Context Integrity Rule
Statement: An action can only be attempted between entities that exist within the same functional context group.
Mechanism: The manager's first step is to get the context group for the source and target locations from the GIR (e.g., BATTLE_BOARD, INVENTORY_GRID). If the groups do not match, the action is immediately rejected as invalid, and an inventory_action_invalid signal is emitted.
Rationale: A top-level sanity check that prevents illogical actions, like swapping an unit from the bench with a item on the item inventory or a tier 1 gachaball with a tier 2 or 3 gachaball or vice versa, on the run/battle inventory, that have tier exclusive containers.
Rule I1: The Merge Priority Rule
Statement: If an interaction between two GachaBalls could possibly be a merge (and is not in conflict with The Context Integrity Rule 0), that possibility must be resolved before any other action is considered.
Mechanism:
The manager's first gameplay check is to query the MergeManager service to see if a valid MergeRecipe exists for the source and target instances.
If a recipe exists: The action is ambiguous. The InventoryManager halts and commands the WindowManager to open the ChoiceWindow (Merge/Swap). It will take no further action until it receives a choice_made signal.
If no recipe exists: The action is unambiguously not a merge. The manager proceeds to the next rule in the priority list.
Rationale: Merging is a powerful, transformative action. This rule ensures the player is always offered the chance to perform an upgrade if one is available.
Rule I2: The Equip Intent Rule
Statement: An action is interpreted as an "Equip" if and only if a source GachaBallInstance with category: ITEM is interacting with a target GachaBallInstance with category: UNIT as it's target, not the other way around.
Mechanism: If no merge is possible, the manager checks the categories of the source and target instances. If they match the criteria, it proceeds to validate the action against the specific equip rules (I3).
Rationale: Provides a clear, type-based definition for the equip action.
Rule I3: The Equip Legality Rule
Statement: A valid Equip action is constrained by the item's origin and the unit's capacity.
Validation Checklist:
The source Item must originate from the ItemInventory container. The only exceptions are the enemy units that are equipped using a different method.
An item already equipped on Unit A cannot be directly moved to Unit B or back to the ItemInventory container. There is no way to directly unnequip items with player inventory actions.
The target Unit must have at least one empty item slot.
Mechanism: If these checks pass, the data owner is instructed to perform the equip operation: the Item's UUID is moved from its source DataContainer into the Unit's equipped_item_uuids array, and the Item's own location properties are updated to reflect its new "equipped" state.
Rationale: This makes equipping a deliberate choice and prevents chaotic item-swapping between units, adding strategic weight to item placement.
Rule I4: The Swap/Move Rule
Statement: If an action is not a Merge and not an Equip, it is interpreted as a potential Swap or Move.
Mechanism (Swap): If the target location contains an instance, the manager checks if the source instance can legally occupy the target's slot, AND if the target instance can legally occupy the source's original slot (per Rule I5). If both are true, it's a Swap. The data owner is instructed to exchange their location properties.
Mechanism (Move): If the target location is an empty slot, the manager checks if the source instance can legally occupy that empty slot (per Rule I5). If true, it's a Move. The data owner is instructed to update the source instance's location properties.
Rationale: This is the default fallback action, covering all standard board and inventory repositioning.
Rule I5: The Placement Legality Rules (The Final Gatekeeper)
Statement: All Move and Swap actions are ultimately validated against a final set of hard-coded placement restrictions.
The Definitive Checklist:
Hero Restriction: The Hero instance can only exist in the PlayerLineup container. It cannot be moved to the bench or any inventory.
Container Type Restriction: Units cannot be placed in ItemInventory. Items cannot be placed in PlayerLineup or PlayerBench.
Container Tier Integrity: A GachaBall of Tier X cannot be placed in an inventory container for Tier Y (e.g., RunInventoryT1 cannot hold a Tier 2 item).
Intra-Unit Item Management: An item already equipped on a unit can only be moved or swapped with other slots on that same unit.
Rationale: These rules enforce the fundamental structure of the game's inventories and battle board, preventing game-breaking states.
Rule I6: The Merge Placement Context Rule
Statement: The destination of a newly created merged GachaBall depends on where the merge was performed.
Mechanism (Board Merge): If two units are merged on the PlayerLineup or PlayerBench, the new, higher-tier unit is placed in the target's original slot. Same for items merged in the ItemInventory container.
Mechanism (Inventory Merge): If two Tier 1 gachaballs are merged in the RunInventoryT1 container, the new Tier 2 gachaball is placed in the first available slot of the RunInventoryT2 container, the same is valid for merging tier 2 gachaballs that will be placed in the RunInventoryT3 container.
Rationale: Creates a strategic distinction. Merging on the board is a tactical replacement. Merging in the inventory changes the probabilities of the next draw while in battle, or if done in the Run inventory, it changes your collection (or "deck") permanently for future battles.
3. Gacha Draw & Discard Lifecycle (Battle-Only)
These are system-driven actions that manipulate GachaBalls during the battle phase. They are triggered by signals, not direct player inventory actions.
The Gacha Draw Mechanism
Trigger: The draw_gacha_requested(tier) signal is emitted (typically from a UI button in Main.gd).
Logic: The BattleManager is responsible for executing the draw.
Cost Check: It verifies if the player has enough Gacha Tokens (token cost according to tier).
Pool Check: It checks the appropriate BattleInventoryT<n> container (each draw is associated with one of the tier containers).
Reshuffle Check (Rule G1): If the pool becomes empty with a draw, it triggers the Reshuffle mechanism. If the pool is empty the draw fails and the token is not spent.
Draw & Place: It randomly selects one instance from the pool, removes it from the BattleInventoryT<n> container, and attempts to place it in the first available slot of the PlayerBench (for Units) or ItemInventory (for Items).
Overflow (Rule G2): If the destination container (PlayerBench or ItemInventory) is full, the drawn instance is sent directly to the DiscardPile.
The Discard Pile & Reshuffle Mechanism
What Goes to the Discard Pile:
Drawn GachaBalls when the bench/inventory is full (Rule G2).
Items that were equipped on a Unit that is defeated in combat.
The defeated Unit instance itself.
Rule G1: The Automatic Reshuffle Rule:
Statement: When a Gacha draw makes the BattleInventoryT<n> pool empty (last gachaball on that tier container is drawn), the system automatically moves all GachaBalls of that same tier from the DiscardPile back into that pool.
Stat Reset: When an instance is sent to the discard pile, its current_hp and current_pwr are reset to their base definition values. This ensures it is drawn in a fresh, undamaged state.
Rationale: This creates a closed-loop economy within each battle. It ensures the player can never have no gachaballs, but the state of those units (which ones are active, available vs. defeated) creates a dynamic and evolving tactical puzzle throughout the encounter.
End of Battle Cleanup
Mechanism: When a battle concludes, the BattleManager and all of its temporary data are destroyed. This includes all battle_copy instances, the entire DiscardPile, and all BattleInventoryT* containers.
State Preservation: The original RunState and its RunInventory remain completely untouched and unmodified by the events of the battle. This ensures a clean state for the next encounter.
4. Implementation & Refactoring Notes
This section details the specific, actionable changes required to refactor the current codebase to align with this V2.0 document and the new Global Interaction Router (GIR) architecture. The goal is to make the code more efficient, clear, and robust while preserving the correct, validated game behavior.
Refactoring Item 1: Centralize Context Logic in the GIR
Objective: To establish the GlobalInteractionRouter as the single source of truth for determining the "functional context group" of any given container.
Current State: This logic currently resides in InteractionManager.gd, which is being deprecated.
Required Changes:
Migrate Function: In scripts/InteractionManager.gd, find the function _get_container_functional_group. Copy its entire contents.
In scripts/GlobalInteractionRouter.gd, paste this function and rename it to get_context_group (making it public).
Update Dependencies: Perform a project-wide search for any calls to InteractionManager.get_context_group and change them to GlobalInteractionRouter.get_context_group. This will primarily affect GachaBallView.gd and InventoryManager.gd.
Refactoring Item 2: Decouple and Refine the Gacha Reshuffle Mechanism
Objective: To make the reshuffle logic an explicit part of the Gacha draw action, improving efficiency and code clarity.
Current State: The reshuffle is inefficiently triggered by the generic battle_inventory_changed signal, which fires on every single inventory manipulation.
Required Changes (in scripts/BattleManager.gd):
Delete Obsolete Function: Delete the entire _check_and_trigger_reshuffles() function.
Disconnect Signal: In the _ready() or _connect_signals() function, delete the line that connects EventBus.battle_inventory_changed to the now-deleted function.
Refactor Draw Logic: Replace the entire _on_draw_gacha_requested(tier: int) function with the new, architecturally compliant implementation. The new version will contain the following critical logic flow:
Check for tokens and if the pool is empty.
Spend tokens and pick a random instance.
Remove the instance from its draw pool FIRST.
Place the instance in its destination (PlayerBench/ItemInventory) or discard it if the destination is full.
Immediately after removing the instance, check if the draw pool is now empty. If it is, call _reshuffle_discard_pile(tier) directly.
Finally, emit battle_inventory_changed once to update the UI.
Refactoring Item 3: Make Equip Logic More Explicit
Objective: To make the code for Rule I3 (Equip Legality) a direct 1-to-1 match with the document's explicit wording.
Current State: The code uses an indirect check (target_loc.container in [&"PlayerLineup", &"PlayerBench"]) to validate an equip action.
Required Changes (in scripts/InventoryManager.gd):
Navigate to the _on_try_inventory_action function.
Locate the "Item on Unit (Equip)" logic block.
Modify the if condition to explicitly check that the source item's location container is &"ItemInventory". This makes the code a direct implementation of the rule, improving readability and future-proofing the logic.
Refactoring Item 4: Ensure Atomic State Updates During Reshuffle
Objective: To ensure the "Golden Rule" is followed during the reshuffle process, where an instance's location "truth" and the container "index" are updated together.
Current State: The current _reshuffle_discard_pile function in BattleManager.gd has a mix of logic that could be better organized. It calls _remove_instance_from_container and then manually sets the new location.
Required Changes (in scripts/BattleManager.gd):
Create a new, private helper function: _place_in_container_slot(instance, container_tag, slot_index). This function's sole responsibility will be to perform the two atomic steps: updating the DataContainer (the index) and updating the GachaBallInstance's location properties (the truth).
Modify the _reshuffle_discard_pile function to use this new helper. After removing the instance from the discard pile, it will simply call _place_in_container_slot() to correctly place it in the draw pool.
Modify the _on_draw_gacha_requested function to also use this new helper, ensuring consistent and atomic state changes for all GachaBall movements.

Window Manager - V2.0 (Service Architecture)
Version: 2.0
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
5. Positioning & Sizing System
The WindowManager is responsible for all window positioning.
Fixed-Position Windows (InventoryWindow, ChoiceWindow): These are the simplest. Their scenes are designed with a pre-set size, and the WindowManager simply places them in the center of the viewport.
Dynamic-Position Windows (UnitInspectionWindow, etc.): These require a more complex system.
Algorithm: The positioning logic is screen-aware. When a window is created, the manager checks the on-screen position of its anchor. It attempts to place the window on the opposite side of the screen where there is more room, falling back to below, above, or the same side if necessary. This prevents windows from opening off-screen.
Anchor Tracking: To prevent windows from becoming detached from moving UI elements, the manager subscribes to the item_rect_changed and tree_exited signals of a window's "stable anchor" (e.g., its parent SlotView). If the anchor moves, the window is repositioned. If the anchor is destroyed, the window is also destroyed.
6. Implementation & Refactoring Notes
This section highlights the critical discrepancies between the current codebase and this target architecture. The following changes are required to achieve the desired behavior.
Refactoring InventoryWindow and DiscardPileWindow:
Current State: The code in WindowManager.gd opens these windows using open_modal_window(), which incorrectly adds them to the _modal_stack and attaches a BackgroundBlocker.
Required Change: These windows must be re-categorized as Fixed-Position Contextual Windows. The WindowManager must be modified to open them via a method similar to _open_inspection_window. They must be added to the _active_inspection_group, not the modal stack, and must not have a BackgroundBlocker. Their scenes (.tscn files) must have the BackgroundBlocker instance removed.
Refactoring ChoiceWindow:
Current State: Like the inventory, this is currently opened as a modal with a blocker.
Required Change: This must also be re-categorized as a Dynamic-Position Contextual Window. The WindowManager must be modified to open it without a blocker and add it to the _active_inspection_group. The GIR will be responsible for interpreting a click outside this window as a cancellation of the action. The BackgroundBlocker instance must be removed from its scene file.
By implementing these changes, the InventoryWindow and ChoiceWindow will correctly join the inspection hierarchy, allowing for seamless interactions like inspecting a unit within the inventory and having all windows close correctly on a global background click, thus unifying the entire windowing system under a single, consistent set of rules.

---

# v6.0 Addendum: Robust Ancestor Resolution, Pruning Precedence, and GIR/WindowManager Contract

This addendum documents the hard‑won refinements introduced in GIR v6.0 to make inspection window pruning and click interpretation generic, robust, and context‑agnostic.

## Summary of Problems Fixed
- __[brittle ancestry assumptions]__ Prior logic assumed the clicked node (emitter) always lived directly under a window instance or that instance_id checks alone could resolve the parent. This failed for some `GachaBallView`, empty slots, and in‑window surfaces.
- __[incomplete pruning propagation]__ Clicks inside `UnitInspectionWindow`/`ItemInspectionWindow` did not consistently prune child `EffectInspection` windows because events were either eaten by children or not resolved to the correct ancestor window.

## Core Solution
- __[Single source of truth for ancestry]__ GIR now calls `WindowManager.find_ancestor_window_for_view(node: Node) -> Control` to resolve the owning inspection window for any clicked node.
  - This delegates to an internal parent walk that checks membership in `_active_inspection_group`.
  - No assumptions about scene structure or emitter placement.

- __[Unified pruning in GIR command generation]__
  - In `GlobalInteractionRouter.gd` `
    - `_generate_command_queue(...)`: when a click occurs on any in‑group surface (excluding true window backgrounds), enqueue `CLOSE_CHILD_WINDOWS` for the resolved parent window via ancestor lookup.
    - `_handle_ui_link_interaction(...)`: resolve the parent window for the link source and prune its children before opening the new child window.
    - `_is_click_inside_inspection_group(...)`: determines inside/outside solely by ancestor window resolution.

## Local Background Clicks vs Global Background Clicks
- __[Local background clicks]__ Windows must directly call `WindowManager.handle_inspection_background_click(self)` from their `_gui_input` when detecting a left click on themselves/background surfaces. This prunes only their descendants (Rule W3).
- __[Global background clicks]__ GIR interprets true outside clicks and issues `CLOSE_ALL_INSPECTION_WINDOWS` (Rule W4). WindowManager executes.

## UI Contract for Inspection Windows (Critical)
- __[Parenting contract]__ All interactive elements inside an inspection window must be parented under that window instance in the scene tree. This guarantees ancestor resolution works at runtime.
- __[Mouse filter contract]__
  - Root window node: `mouse_filter = MOUSE_FILTER_STOP` so `_gui_input` reliably receives non‑link clicks.
  - Known backgrounds/grids that represent local background: `MOUSE_FILTER_STOP` and call `handle_inspection_background_click(self)`.
  - Text areas (`RichTextLabel`) with UI links: set `mouse_filter = MOUSE_FILTER_PASS` so non‑link clicks bubble to the root; consume link clicks in `meta_clicked` and call `get_viewport().set_input_as_handled()`/`accept_event()` there.
  - Other child controls: prefer `MOUSE_FILTER_PASS` so clicks bubble to the root unless they implement a specific interaction.

## UI_LINK Handling
- Links inside windows (e.g., “EFFECTS”) are treated as UI_LINK interactions.
- GIR resolves the link source’s ancestor window; enqueues `CLOSE_CHILD_WINDOWS` for that parent; then WindowManager opens the requested child via `open_child_contextual_window`.

## Runtime Verification Checklist
- __[Ancestor resolution]__ For any click source, `find_ancestor_window_for_view` returns the correct window or null.
- __[Local prune]__ Clicking anywhere on the parent window (non‑link) prunes only its `EffectInspection` child.
- __[Inside prune]__ Clicking on any interactive element inside an inspection window prunes that window’s children prior to handling the click.
- __[Global close]__ Clicking outside all windows closes the entire group.

## Test Matrix (Contexts)
- __Inventory (Run/Battle)__: clicking `GachaBallView`, empty slots, and backgrounds.
- __Battle Board__: clicks on units/slots with windows open.
- __Shop/Rewards (Selection‑Only)__: UI_LINK and background behaviors without per‑context rules.
- __Unit/Item Windows__: ensure description areas bubble non‑link clicks; link clicks open `EffectInspection` as a child after pruning.

## Design Principles Reinforced
- __[Separation of concerns]__ GIR interprets intent and issues commands; WindowManager executes lifecycle and positioning.
- __[No per‑element programming]__ Generic ancestor lookup + consistent mouse_filter/parenting contract cover all contexts.
- __[Deterministic precedence]__ Local prune (W3) < Inside prune (within group) < Global close (W4), governed by GIR with WindowManager as executor.

---

# Phase 2: Intent Rules & Action Validation (I1–I6)

This phase completes the core gameplay interpretation in GIR by implementing deterministic gating and routing for action intent (Equip / Merge / Swap / Move) for both click-to-act and drag-and-drop, while deferring authoritative priority and legality decisions to InventoryManager.

## Scope

- __[Implement intent gating in GIR]__
  - Complete `GlobalInteractionRouter.gd` coarse checks so interactions produce the correct command queue without enforcing final intent priority:
    - Move when target is `EMPTY_SLOT` and placement appears valid (handled in `_handle_empty_slot_interaction`).
    - For non-empty targets, if locations are in compatible functional groups and the pairing is plausibly actionable (e.g., ITEM→UNIT, UNIT↔UNIT, ITEM↔ITEM within same group), emit a generic `REQUEST_ACTION` and let `InventoryManager` decide Equip/Merge/Swap.
  - Emit `REQUEST_ACTION` with `{ "source_context": InteractionContext, "target_context": InteractionContext }`.
  - Emit `INVALID_ACTION` when rules fail (clears UI via `InteractionManager`).

- __[Unify drag and click pathways]__
  - Ensure click-to-act path mirrors drag-to-act decisions so both feed the same InventoryManager logic.
  - Drag state can remain in `InteractionManager`; GIR should not store drag state unless needed later.

## Code Changes

- __GlobalInteractionRouter (`scripts/GlobalInteractionRouter.gd`)__
  - __Complete__ `._is_valid_action_target(selection, target) -> bool`.
    - Enforce I1–I6 from TDD v6.0 at a coarse level and do NOT encode action priority (that is owned by `InventoryManager`).
  - __Complete__ `._is_valid_move_target(selection, target) -> bool` for EMPTY_SLOT targets using container constraints.
  - __Route actions in__ `._handle_fully_interactive(context)`:
    - If `_current_selection != null`:
      - If `_is_inspection_event(context)`: open inspection (already implemented).
      - Else if `_is_valid_action_target(_current_selection, context)`: `REQUEST_ACTION` with `{ source_context, target_context }`.
      - Else: `INVALID_ACTION`.
    - If no selection: `SELECT` default path (already implemented).
  - __UI_LINK path__ `._handle_ui_link_interaction(...)` is already pruning children; no change needed.

- __InventoryManager (`scripts/InventoryManager.gd`)__
  - Already consumes `try_inventory_action(source_loc, target_loc)` and performs Merge/Equip/Swap/Move.
  - GIR’s `REQUEST_ACTION` executor `_execute_request_action(..)` already bridges to `SignalBus.try_inventory_action`.
  - No code changes expected here for Phase 2, but add a verification pass (see Acceptance below).

- __InteractionManager (`scripts/InteractionManager.gd`)__
  - Continues to manage selection and drag state, and to clear state on invalid actions via `_resolve_and_clear_invalid_interaction()`.
  - No structural change required in Phase 2.

## TDD Rules (I1–I6) Mapping (aligned with current code)

- __I1 Equip Intent Priority__: For non-empty targets, `InventoryManager` prioritizes ITEM→UNIT equip on board containers (`PlayerLineup`, `PlayerBench`).
  - GIR: If in same functional group and pairing is ITEM→UNIT, allow by emitting `REQUEST_ACTION`; do not enforce priority in GIR.

- __I2 Merge Rule__: If a valid recipe exists, `InventoryManager` opens `ChoiceWindow` and proceeds with merge.
  - GIR: Treat UNIT↔UNIT and ITEM↔ITEM within the same group as plausible; emit `REQUEST_ACTION` and let `InventoryManager` ask `MergeManager`.

- __I3 Equip Constraints__: Equipped grid semantics apply (equipped items move only within the same unit; equipping onto a unit from non-equipped is allowed).
  - GIR: rely on `InventoryManager._is_valid_placement` for enforcement; only perform obvious category/container gating.

- __I4 Swap/Move Rule__: `InventoryManager` falls back to Swap when both placements are valid, or Move when target is EMPTY_SLOT and placement valid.
  - GIR: For EMPTY_SLOT use `_is_valid_move_target`; for non-empty targets, just emit `REQUEST_ACTION` if within same group and plausibly actionable.

- __I5 Cross-Context Restrictions__: Prevent actions across incompatible functional groups (Inventory vs Battle Board vs Selection-Only).
  - GIR: Use `InteractionManager.get_context_group(container_name)` (public wrapper) or own light checks to avoid emitting invalid actions.

- __I6 Merge Placement Context__: Context-specific merge allowances (e.g., equipped_item exceptions) are ultimately validated by InventoryManager and MergeManager; GIR should not special-case beyond category/container checks.

## Function-level TODOs (GIR)

- __`_is_valid_action_target(selection, target)`__
  - Fast-fail when either context/location missing.
  - Disallow when groups differ (use `InteractionManager.get_context_group` for containers).
  - If both resolve to concrete instances:
    - If categories match and not UNIT->ITEM, consider MERGE candidate; return true (InventoryManager re-validates via MergeManager).
    - If ITEM -> UNIT and target in board containers, return true (equip or swap will be chosen later).
    - Else if both placements appear valid for swap (coarse check), return true.
  - Else if target is `EMPTY_SLOT` and placement appears valid, return true.
  - Otherwise return false.

- __`_is_valid_move_target(selection, target)`__
  - Fast-fail missing selection/locations.
  - Disallow cross functional groups.
  - Allow only when target is `EMPTY_SLOT` and high-level placement constraints pass (category/container tier sanity).

- __`_handle_fully_interactive(context)`__
  - After pruning logic, when selection exists and event is single-click:
    - If `_is_valid_action_target(_current_selection, context)`: enqueue `REQUEST_ACTION`.
    - Else: `INVALID_ACTION`.

## Acceptance Criteria

- __Click-to-act parity__
  - Single-click with a selection performs Merge/Equip/Swap/Move using the same legality as drag-and-drop.

- __Drag remains authoritative__
  - Drag interactions are unaffected and still end in the same `try_inventory_action` path.

- __No cross-group actions__
  - GIR does not emit `REQUEST_ACTION` when containers are in different functional groups.

- __Invalid actions resolve state__
  - Emitting `INVALID_ACTION` triggers `InteractionManager._resolve_and_clear_invalid_interaction()` and clears selection.

- __No regression to window system__
  - Inside/prune/global close behavior remains intact during action attempts.

## Test Matrix (Expanded)

- __Inventory Grid (Run/Battle)__
  - Unit -> Unit: valid merge recipe shows ChoiceWindow then merge; invalid falls back to swap if placements valid, else invalid.
  - Item -> Unit: equips into valid slot; invalid container is rejected.
  - Unit/Item -> EMPTY_SLOT: moves when legal; otherwise invalid.

- __Board Containers__
  - PlayerLineup/PlayerBench swaps and merges as applicable; items cannot be placed directly unless equipping via unit.

- __Equipped Grid__
  - Moving equipped items only within same unit; merge exceptions per rules validated by InventoryManager/MergeManager.

## Implementation Notes

- GIR should prefer coarse validation and defer authoritative checks to InventoryManager/MergeManager to avoid duplication.
- Keep logging at key decision points in GIR to assist debugging (entity types, groups, coarse decisions, emitted command).
- Use existing helper `_find_view_by_instance_id` when needed, but prefer operating purely on `InteractionContext` for action decisions.

## Checklist

- [ ] Complete `_is_valid_action_target` in `GlobalInteractionRouter.gd`.
- [ ] Complete `_is_valid_move_target` in `GlobalInteractionRouter.gd`.
- [ ] Update `_handle_fully_interactive` to emit `REQUEST_ACTION`/`INVALID_ACTION` as per rules.
- [ ] Verify `InventoryManager._on_try_inventory_action` paths for Merge/Equip/Swap/Move still align with TDD v6.0.
- [ ] Run manual tests across Inventory, Board, and Equipped contexts; confirm no regressions in window pruning.