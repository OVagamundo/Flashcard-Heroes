Inventory & Gacha Systems - V2.3 (Unified)
Version: 2.3
Status: Canonical
This document describes the architecture and definitive rules for all GachaBall manipulation systems, including inventory actions (Move, Swap, Equip, Merge), the Gacha draw mechanism, and the Discard Pile lifecycle. The InventoryManager is the central, stateless service that executes the logic described herein.
1. Purpose & Core Philosophy
The InventoryManager is a stateless logic controller. It is the "verb" system for all GachaBall instances. Its sole purpose is to execute commands and signals related to GachaBall manipulation, validate them against a strict set of gameplay rules, and instruct the appropriate data owner (RunState or BattleManager) to perform the state change.
Core Principles:
Stateless Operation: The manager never stores its own state between actions. It always queries the current game state from the data owners.
Authoritative Validation: The manager is the final authority on whether a gameplay action is legal.
Command-Driven: Its primary entry point for player-initiated actions is the `try_inventory_action` signal, which is emitted by the GlobalInteractionRouter (GIR) when it executes a `REQUEST_ACTION` command.
Signal Contract (from GIR): `SignalBus.try_inventory_action(source_loc: LocationIdentifier, target_loc: LocationIdentifier)` — GIR extracts `.location` from its stored `source_context` and the current `target_context` (see `GlobalInteractionRouter._execute_request_action`).
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
Statement: A valid Equip action is constrained by the item's origin (InventoryGrid), the unit's capacity, and cross‑unit restrictions.
Validation Checklist:
The source Item must originate from an InventoryGrid container: `RunInventoryT*`, `BattleInventoryT*`, or `ItemInventory`. (GIR maps `ItemInventory` → `InventoryGrid` for gating.)
An item already equipped on Unit A cannot be directly moved to Unit B or back to an inventory container. There is no direct player action to un‑equip; items must be removed via explicit unequip flows, not by equip actions.
The target must be either (a) a UNIT on `PlayerLineup`/`PlayerBench`, or (b) that unit’s empty `equipped_item` slot.
Mechanism: If these checks pass, the manager performs an early equip path: remove the item from its source container and attach it to the target unit’s equipped list, updating both the container index and the instance’s location (atomic update).
Rationale: This makes equipping deliberate and predictable while allowing click‑to‑click and drag‑and‑drop equip from any InventoryGrid.
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