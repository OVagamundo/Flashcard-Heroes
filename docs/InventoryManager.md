# Inventory & Gacha Systems
This document describes the architecture and definitive rules for all GachaBall manipulation systems, including inventory actions (Move, Swap, Equip, Merge), the Gacha draw mechanism, and the Discard lifecycle. The InventoryManager is the central, stateless logic controller that executes the logic described herein.
1. Purpose & Core Philosophy
The InventoryManager is a stateless logic controller. It is the "verb" system for all GachaBall instances. Its sole purpose is to execute commands and signals related to GachaBall manipulation, validate them against a strict set of gameplay rules, and instruct the appropriate data owner (RunState or BattleManager) to perform the state change via a unified polymorphic API.
Core Principles:
Stateless Operation: The manager never stores its own state between actions. It always queries the current game state from the data owners.
Authoritative Validation: The manager is the final authority on whether a gameplay action is legal.
Command-Driven: Its primary entry points for player-initiated actions are `execute_drag_action` and `execute_choice_action`, invoked by validated `GameAction` command objects (`InventoryDragAction`, `ChoiceAction`) processed sequentially by `ActionQueue`.
Command Pipeline Contract: `InventoryDragAction.execute()` -> `InventoryManager.execute_drag_action(source_loc, target_loc)`. `ChoiceAction.execute()` -> `InventoryManager.execute_choice_action(choice, source_loc, target_loc, recipe_id)`.
The Golden Rule of State Synchronization: All state change instructions sent to data owners must be atomic. This means any operation that moves an instance must update both the DataContainer (the index) and the GachaBallInstance's properties (the truth) in a single, indivisible operation.

> [!NOTE]
> **In-Battle Inventory Logic:** During combat, `InventoryOperations.gd` provides the core implementation for gacha draws, moves, swaps, and equips. `BattleManager` delegates to these static methods.

## ChoiceWindow-Driven Swap/Merge and Close Suppression

This addendum documents the finalized flow for ambiguous actions (Swap/Merge) prompted via `ChoiceWindow` and the suppression required to prevent premature closing of inspection windows during these actions.

### Flow Summary

- __Ambiguity detection__: In `InventoryManager._on_try_inventory_action`, if `MergeManager.find_recipe(...)` returns a valid recipe, the manager opens the `ChoiceWindow` via `WindowManager.open_choice_window(context)` and returns without taking action.
- __User decision__: `ChoiceWindow` emits `SignalBus.choice_made(choice, source_loc, target_loc, recipe_id)`.
- __Suppression before action__: In `InventoryManager._on_choice_made(...)`, before calling `_swap` or `_merge`, suppression is explicitly activated for the relevant inspection window:
  1) Resolve `anchor_view` using `WindowManager.find_view_for_location(target_loc)` with fallback to `source_loc`.
  2) Resolve `parent_window` via `WindowManager.find_ancestor_window_for_view(anchor_view)`.
  3) Call `GlobalInteractionRouter.activate_close_suppression_for_window_id(parent_window.get_instance_id(), duration_msec)`.
  4) Choose duration to cover deferred anchor checks (currently ~420ms for unit-context actions such as `equipped_item`, `PlayerLineup`, `PlayerShelf`; ~320ms otherwise).
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
- **Strict Shelf Origin**: The source Item must strictly originate from the `PlayerShelf` during battle. Items cannot be equipped directly from inventory grid drawers (which are read-only) and cannot be equipped outside of battle.
- **No Manual Unequipping**: An item already equipped on Unit A cannot be directly moved to Unit B or back to the shelf. Outside of specific item-stripping consumables (such as *Potion of Plunder*, which removes an equipped item from a unit and sends it directly to the player's matching tier Gacha Machine (`BattleInventoryT{tier}`) so it can be drawn in the future), equipment cannot be unequipped without being replaced.
- **Target Legality**: The target must be a UNIT on `PlayerLineup`, or that Lineup unit's `equipped_item` slot. A Shelf item capsule opens when equipped or merged into equipment on a Lineup holder. Shelf residents cannot receive equipment, merges, or consumables.
- **Consumable Item Rules**: Consumables are distinct from standard items. Their sealed capsules can be used from `PlayerShelf` on eligible **Player or Enemy Lineup units**, opening the capsule and executing their effects without occupying an item slot. They disappear from the active battle pool upon consumption **without** going to the Discard. *Potion of Plunder* is an explicit exception to Discard-first recycling: it sends stripped equipment directly to the player's matching tier machine. Its next draw returns the item sealed to the Shelf.
  - **Buff Granular Tagging & Merge Inheritance**: Unlike equipped item buffs (`source_type = &"EQUIPMENT"`), which are conditional on holding the item and re-evaluated fresh upon merge (with only one item retained), consumable buffs (healing potions, stat potions, scrolls, elixirs) are **stackable regular buffs** tagged with granular origin `source_type = &"CONSUMABLE"` (`allow_stacking = true`).
  - **Additive Consolidation on Merge**: When units merge (both Evolutionary Level-ups and Recipe Tier-ups), all consumable buffs from both parent units are fully conserved and added together into the resulting unit's stats and merge inheritance surplus (`MERGE_INHERITANCE`).
- **Single Item Capacity & Item Replacement**: All units possess strictly **one** item slot. If the target unit already holds an equipped item, equipping a new item executes as an **Item Replacement**.
  - **Discard Destination**: The existing equipped item is immediately removed and sent directly to the **Battle Discard** (`DiscardPile`). It does **NOT** return to the player shelf or inventory.
  - **Discard Animation**: The replaced item triggers a `CombatEvent.Type.ITEM_DISCARD` event, animating a parabolic arc toss from the unit's position into the Discard UI button (`discard_pile_button`) using the full GachaBall capsule (`GachaBallView.tscn` in inventory mode, scaling from `0.3` to `1.0` over a 500px arc) with `coin_land` audio feedback and button bump. This visualizes to the player exactly where the item was sent, precisely matching the death departure animation.
  - **Sequential Resolution & Net Delta Evaluation**: The item discard animation resolves first sequentially. Afterwards, the unit's item slot updates to the new item and the system evaluates the net stat delta between the old and new item (`delta_hp = new_item.bonus_hp - old_item.bonus_hp`, `delta_pwr = new_item.bonus_pwr - old_item.bonus_pwr`). Positive stat increases launch a parabolic self-cast projectile onto the unit, while negative stat reductions display floating debuff text (`-X` in red for HP, black for PWR).
  - **Equip Pipeline Parity**: In-game equip and transfer effects (such as the Standard Bearer's *Standard's Legacy*) route through this exact same `InventoryOperations.equip_item` logic, ensuring replaced items are consistently discarded and animated regardless of whether equipping occurred manually or via an ability.
Mechanism: If these checks pass, the manager performs an atomic equip transaction:
1. If replacing an existing item, the old item is removed from the unit and moved directly to the `BattleDiscardPile` via `move_instance_to_discard()`, recording replaced item metadata.
2. An `ITEM_DISCARD` event is enqueued ahead of the equip inventory change to ensure sequential presentation.
3. The new item is removed from its source container and attached to the target unit's `equipped_item_uuids[0]`.
4. The unit's effective stats are updated, emitting unified stat delta events for presentation.
Rationale: This makes equipping deliberate and predictable while sending replaced equipment to Discard for potential recovery through a tier machine.
Rule I4: The Swap/Move Rule
Statement: If an action is not a Merge and not an Equip, it is interpreted as a potential Swap or Move.
Mechanism (Swap): If the target location contains an instance, the manager checks if the source instance can legally occupy the target's slot, AND if the target instance can legally occupy the source's original slot (per Rule I5). If both are true, it's a Swap. The data owner is instructed to exchange their location properties.
Mechanism (Move): If the target location is an empty slot, the manager checks if the source instance can legally occupy that empty slot (per Rule I5). If true, it's a Move. The data owner is instructed to update the source instance's location properties.
Rationale: This is the default fallback action, covering all standard board and inventory repositioning.
Rule I5: The Placement Legality Rules (The Final Gatekeeper)
Statement: All Move and Swap actions are ultimately validated against a final set of hard-coded placement restrictions.
The Definitive Checklist:
Hero Restriction: The Hero normally stays in the Player Lineup. The Incubator provides the same temporary Shelf placement for living allied units, including the Hero.
Container Type Restriction: Items cannot be placed in PlayerLineup. Both units and items can be placed in PlayerShelf.
Container Tier Integrity: A GachaBall of Tier X cannot be placed in an inventory container for Tier Y (e.g., RunInventoryT1 cannot hold a Tier 2 item).
Single Item Slot Constraint: Units are constrained to a single item slot. Equipping an item onto a unit that already has an equipped item triggers an Item Replacement (the existing item is moved directly to the Battle Discard).
Rationale: These rules enforce the fundamental structure of the game's inventories and battle board, preventing game-breaking states.
Rule I6: The Merge Placement Context Rule
Statement: The destination of a newly created merged GachaBall depends on where the merge was performed.
Mechanism (Board Merge): The target must be a Lineup unit or an equipped item on a Lineup unit. The source may be a sealed Shelf capsule. The result occupies the target's slot and is opened. Shelf-to-Shelf drops rearrange capsules and never merge them.
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
## 3. Gacha Draw & Discard Lifecycle

`RunState` owns the permanent inventory. `BattleState` owns encounter copies, capacity checks, and storage transfers. `InventoryOperations` resolves draws, and `BattleManager` applies the associated cost and emits the resulting combat events.

| Storage | Capacity | Admission at capacity |
| --- | --- | --- |
| Run inventory | 25 per tier | The incoming capsule replaces a seeded random capsule of the same tier. The replaced capsule is removed from the run. |
| Battle tier machine | 25 per tier | The incoming capsule goes to Battle Discard. |
| Battle Discard | 80 total | The incoming capsule replaces a seeded random capsule already in Discard. Ejection affects the battle copy. |
| Player Shelf | 3 unlocked at battle start, 7 maximum | Each additional slot costs 1 Token for the current battle. A tier draw with no empty unlocked Shelf slot goes to Discard. |

### Tier draws and deployment

- A tier draw selects one instance from that battle tier with `gacha_rng`. The base Token cost is the tier number. An empty tier rejects the draw without spending Tokens.
- Tier draws and Shelf summons remain sealed. An eligible Lineup deployment, merge, equip, or consumable use opens the capsule. Shelf copies count for pool-based abilities. Wind-up-kun and Incubator growth can resolve on the Shelf. Draw and Token-spend reactions resolve when the draw or spend occurs.
- The Incubator takes a living allied Lineup unit into the capsule's former Shelf slot and occupies its equipment slot. It grants the holder +1 HP and +1 PWR at each Turn Start on the Shelf. Redeployment keeps that growth and sends the Incubator to Discard. Outside incubation, deployed units return to a sealed Shelf capsule by first recycling through a machine.

### Discard recovery

Discard receives defeated player units, replaced or detached equipment routed there, and overflow. Recovery is a player action during preparation and costs 1 Token when accepted.

| Condition | Outcome |
| --- | --- |
| At least one Discard capsule has room in its own tier | Draw a seeded random capsule among the matching candidates, reset its battle stats for recycling, and move it to that tier machine. |
| A tier has room but no Discard capsule matches it | Charge the Token, show the selected capsule returning to Discard, and keep the count steady. |
| All tiers are full, Discard is empty, or the player lacks a Token | Reject the draw without spending a Token. |

The inventory drawers are read-only views of battle data. Simulated capsule positions can change presentation only. Overflow, ejection, and recovery resolve against container membership before playback. Losing a battle copy to ejection leaves its run original available in future encounters.

## 4. Shop System

The Shop uses **temporary state** stored in GameManager (not a separate ShopManager):
- `_temporary_shop_master_dict`: Actual `GachaBallInstance` objects
- `_temporary_shop_container`: `FixedArrayContainer(3)` with UUIDs
- `_reroll_cost`: Escalates with each reroll (starts at 1)

Shop stock and rerolls draw three eligible unit or item capsules using the weighting rules in [EncounterSystem.md](EncounterSystem.md#6-player-shop-and-reward-pools).

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
Shop uses `FULLY_INTERACTIVE` - items can be clicked to select (buy via button) or dragged directly onto the buy overlay. Purchases trigger a **Financial Confirmation First** animation pipeline with VFX proxies.

## 5. Hero Starting Loadouts

- Dan and Shiken start with 30 Gold, three copies of their Tier 1 signature unit, two of each universal Tier 1 unit, and their Novice or Mercenary Crest. Dan gets two Study Pouches and Shiken gets two Claim Tickets.
- Base Set heroes start with 5 Gold and three of each universal Tier 1 unit. Han, Kon, Hiko, and Deko start with the Specialist, Tank, Fire, and Support Crest respectively.
- Each hero starts with two Candies, two Wakizashis, an Incubator, a Fortifying Tonic, an Impact Vial, and one Emblem matching their starting Crest.
- `RunState.initialize_run()` adds one seeded Tier 2 and one seeded Tier 3 unit or equipment item from the hero's own active set. The rolls exclude the fixed starter definitions and use `gacha_rng`. Base Set heroes draw both from Base. The consumables and equipment are described in [GameContentDocument.md](GameContentDocument.md#4-universal-neutral-items--equipment).
