Inventory & Gacha Systems - V2.4 (Unified)
Version: 2.4
Status: Canonical
This document describes the architecture and definitive rules for all GachaBall manipulation systems, including inventory actions (Move, Swap, Equip, Merge), the Gacha draw mechanism, and the Discard Pile lifecycle. The InventoryManager is the central, stateless logic controller that executes the logic described herein.
1. Purpose & Core Philosophy
The InventoryManager is a stateless logic controller. It is the "verb" system for all GachaBall instances. Its sole purpose is to execute commands and signals related to GachaBall manipulation, validate them against a strict set of gameplay rules, and instruct the appropriate data owner (RunState or BattleManager) to perform the state change via a unified polymorphic API.
Core Principles:
Stateless Operation: The manager never stores its own state between actions. It always queries the current game state from the data owners.
Authoritative Validation: The manager is the final authority on whether a gameplay action is legal.
Command-Driven: Its primary entry point for player-initiated actions is the `try_inventory_action` signal, which is emitted by the GlobalInteractionRouter (GIR) when it executes a `REQUEST_ACTION` command.
Signal Contract (from GIR): `SignalBus.try_inventory_action(source_loc: LocationIdentifier, target_loc: LocationIdentifier)` — GIR extracts `.location` from its stored `source_context` and the current `target_context` (see `GlobalInteractionRouter._execute_request_action`).
The Golden Rule of State Synchronization: All state change instructions sent to data owners must be atomic. This means any operation that moves an instance must update both the DataContainer (the index) and the GachaBallInstance's properties (the truth) in a single, indivisible operation.

> [!NOTE]
> **In-Battle Inventory Logic:** During combat, `InventoryOperations.gd` provides the core implementation for gacha draws, moves, swaps, and equips. `BattleManager` delegates to these static methods.

## v2.4 Addendum: ChoiceWindow-Driven Swap/Merge and Close Suppression

This addendum documents the finalized flow for ambiguous actions (Swap/Merge) prompted via `ChoiceWindow` and the suppression required to prevent premature closing of inspection windows during these actions.

### Flow Summary

- __Ambiguity detection__: In `InventoryManager._on_try_inventory_action`, if `MergeManager.find_recipe(...)` returns a valid recipe, the manager opens the `ChoiceWindow` via `WindowManager.open_choice_window(context)` and returns without taking action.
- __User decision__: `ChoiceWindow` emits `SignalBus.choice_made(choice, source_loc, target_loc, recipe_id)`.
- __Suppression before action__: In `InventoryManager._on_choice_made(...)`, before calling `_swap` or `_merge`, suppression is explicitly activated for the relevant inspection window:
  1) Resolve `anchor_view` using `WindowManager.find_view_for_location(target_loc)` with fallback to `source_loc`.
  2) Resolve `parent_window` via `WindowManager.find_ancestor_window_for_view(anchor_view)`.
  3) Call `GlobalInteractionRouter.activate_close_suppression_for_window_id(parent_window.get_instance_id(), duration_msec)`.
  4) Choose duration to cover deferred anchor checks (currently ~420ms for unit-context actions such as `equipped_item`, `PlayerLineup`, `PlayerBench`; ~320ms otherwise).
- __Execute__: Perform `_merge(source_loc, target_loc, recipe_id)` or `_swap(source_loc, target_loc)`, emit selection/data-change signals as usual. No direct window-close is performed here.

### Rationale

- Inspection windows can schedule deferred self-closes when their anchor view is freed or reparented. Without suppression active at the exact moment of Swap/Merge, those defers can close windows prematurely.
- Activating suppression tied to the target window ID ensures `WindowManager.request_close_inspection_window(...)` and any deferred close paths consult GIR and defer/skip closure.

### APIs Involved

- `WindowManager.find_view_for_location(loc: LocationIdentifier) -> Control`
- `WindowManager.find_ancestor_window_for_view(view: Control) -> Control`
- `GlobalInteractionRouter.activate_close_suppression_for_window_id(window_id: int, duration_msec: int)`

Note: The GIR suppression helper is now a public API: `activate_close_suppression_for_window_id(...)`. Use it directly.

### Do/Don't

- __Do not__ re-route the `choice_made` decision back through GIR’s `REQUEST_ACTION` (would duplicate prompts and complicate suppression timing).
- On drag start, GIR prunes only the child inspection windows of the anchor (parent) window via `WindowManager.close_children_of(parent_window)`. The parent window remains open.

2. The Definitive Rules of Action & Gameplay
This is the core logic that the InventoryManager enforces. It follows a strict priority checklist to determine and validate the player's intent for any interaction between two locations.
Rule I0: The Context Integrity Rule
Statement: An action can only be attempted between entities that exist within the same functional context group.
Mechanism: The manager's first step is to get the context group for the source and target locations from the GIR (e.g., BATTLE_BOARD, INVENTORY_GRID). If the groups do not match, the action is immediately rejected as invalid, and an inventory_action_invalid signal is emitted.
Rationale: A top-level sanity check that prevents illogical actions, like swapping a tier 1 gachaball with a tier 2 or 3 gachaball or vice versa on the run/battle inventory, that have tier exclusive containers.
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
Statement: A valid Equip action is constrained by the item's origin (InventoryGrid or BattleBoard), the unit's capacity, and cross‑unit restrictions.
Validation Checklist:
The source Item must originate from an InventoryGrid container (`RunInventoryT*`, `BattleInventoryT*`) or the `PlayerBench` (BattleBoard context).
An item already equipped on Unit A cannot be directly moved to Unit B or back to an inventory container. There is no direct player action to un‑equip; items must be removed via explicit unequip flows.
The target must be a UNIT on `PlayerLineup` or `PlayerBench`, or that unit's empty `equipped_item` slot. **Note:** Items equipped on bench units provide stat bonuses but their triggered abilities do not activate until the unit is in the `PlayerLineup` (combat-active).
Mechanism: If these checks pass, the manager performs an early equip path: remove the item from its source container and attach it to the target unit's equipped list, updating both the container index and the instance's location (atomic update).
Rationale: This makes equipping deliberate and predictable while allowing click‑to‑click and drag‑and‑drop equip from bench or inventory.
Rule I4: The Swap/Move Rule
Statement: If an action is not a Merge and not an Equip, it is interpreted as a potential Swap or Move.
Mechanism (Swap): If the target location contains an instance, the manager checks if the source instance can legally occupy the target's slot, AND if the target instance can legally occupy the source's original slot (per Rule I5). If both are true, it's a Swap. The data owner is instructed to exchange their location properties.
Mechanism (Move): If the target location is an empty slot, the manager checks if the source instance can legally occupy that empty slot (per Rule I5). If true, it's a Move. The data owner is instructed to update the source instance's location properties.
Rationale: This is the default fallback action, covering all standard board and inventory repositioning.
Rule I5: The Placement Legality Rules (The Final Gatekeeper)
Statement: All Move and Swap actions are ultimately validated against a final set of hard-coded placement restrictions.
The Definitive Checklist:
Hero Restriction: The Hero instance can only exist in the PlayerLineup container. It cannot be moved to the bench or any inventory.
Container Type Restriction: Items cannot be placed in PlayerLineup. Both units and items can be placed in PlayerBench.
Container Tier Integrity: A GachaBall of Tier X cannot be placed in an inventory container for Tier Y (e.g., RunInventoryT1 cannot hold a Tier 2 item).
Intra-Unit Item Management: An item already equipped on a unit can only be moved or swapped with other slots on that same unit.
Rationale: These rules enforce the fundamental structure of the game's inventories and battle board, preventing game-breaking states.
Rule I6: The Merge Placement Context Rule
Statement: The destination of a newly created merged GachaBall depends on where the merge was performed.
Mechanism (Board Merge): If two units are merged on the PlayerLineup or PlayerBench, the new, higher-tier unit is placed in the target's original slot. Same for items merged in the PlayerBench container.
Mechanism (Inventory Merge): If two Tier 1 gachaballs are merged in the RunInventoryT1 container, the new Tier 2 gachaball is placed in the first available slot of the RunInventoryT2 container, the same is valid for merging tier 2 gachaballs that will be placed in the RunInventoryT3 container.
Rationale: Creates a strategic distinction. Merging on the board is a tactical replacement. Merging in the inventory changes the probabilities of the next draw while in battle, or if done in the Run inventory, it changes your collection (or "deck") permanently for future battles.

Rule I7: The Merge Stat Inheritance Rule
Statement: When two units are merged, the resulting unit inherits the combined current stats (HP and PWR) of both parent units, minus any item bonuses that will be reapplied.
Mechanism:
1. The MergeManager calculates the merged unit's stats as: `total_hp = parent_a.current_hp + parent_b.current_hp - item_bonuses` and `total_pwr = parent_a.current_pwr + parent_b.current_pwr - item_bonuses`.
2. Item bonuses are subtracted during merge calculation to avoid "double dipping" when items are re-equipped on the new unit.
3. The MergeManager returns a list of items that should be equipped on the new unit, but does not link them directly to avoid state conflicts.
4. The InventoryManager receives the merged unit with correct stats and the list of items, then equips the items using the data owner's atomic equip API.
5. When items are equipped or unequipped, `GachaBallInstance.recalculate_stats` is called, which preserves the unit's current stats without clamping them to base values.

Rationale: This allows merged units to scale indefinitely, creating a strategic progression where units grow more powerful through successive merges. The stat preservation system ensures that a unit's power is never lost due to equipment changes, maintaining the value of merge investments.
3. Gacha Draw & Discard Lifecycle (Battle-Only)
These are system-driven actions that manipulate GachaBalls during the battle phase. They are triggered by signals, not direct player inventory actions.
The Gacha Draw Mechanism
Trigger: The draw_gacha_requested(tier) signal is emitted (typically from a UI button in Main.gd).
Logic: The BattleManager is responsible for executing the draw.
Cost Check: It verifies if the player has enough Gacha Tokens (token cost according to tier).
Pool Check: It checks the appropriate BattleInventoryT<n> container (each draw is associated with one of the tier containers).
Reshuffle Check (Rule G1): If the pool becomes empty with a draw, it triggers the Reshuffle mechanism. If the pool is empty the draw fails and the token is not spent.
Draw & Place: It randomly selects one instance from the pool, removes it from the BattleInventoryT<n> container, and attempts to place it in the first available slot of the PlayerBench (for both Units and Items).
Overflow (Rule G2): If the destination container (PlayerBench) is full, the drawn instance is sent directly to the DiscardPile.
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
## 4. Shop System

The Shop uses **temporary state** stored in GameManager (not a separate ShopManager):
- `_temporary_shop_master_dict`: Actual `GachaBallInstance` objects
- `_temporary_shop_container`: `FixedArrayContainer(3)` with UUIDs
- `_reroll_cost`: Escalates with each reroll (starts at 1)

### Purchase Flow
1. Player selects item → clicks "Buy"
2. Gold coin animation from counter → Buy button
3. `shop_purchase_requested(uuid, cost)` emitted
4. GameManager validates gold + item exists
5. Moves instance from temp dict → `RunState.run_instances`
6. Gachaball animates to tier's gacha machine
7. `shop_stock_refreshed` signal updates UI

### Reroll Flow
1. Player clicks "Reroll" → gold animation
2. GameManager deducts cost, increments `_reroll_cost`
3. `_generate_shop_stock()` creates new items
4. UI refreshes via `shop_stock_refreshed`

### Interaction Mode
Shop uses `SELECTION_ONLY` - items can be selected and inspected but not dragged or moved.