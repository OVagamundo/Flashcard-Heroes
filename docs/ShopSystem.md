# Shop System

**Version:** 1.0  
**Status:** Active

## 1. Purpose & Responsibility

The Shop System provides the primary economic hub for a run, allowing the player to spend Gold to purchase new GachaBall instances for their permanent Run Inventory. The system is responsible for:
- Generating a random, temporary stock of GachaBalls for purchase.
- Handling the player's purchase and reroll actions.
- Managing the state of the shop during a single Shop Node visit.
- Ensuring all purchased items are correctly added to the RunState.

## 2. System Architecture & Data Flow

The shop's logic is distributed between the persistent GameManager and the scene-specific Shop.tscn UI. This follows the principle of a "dumb" view, where the UI is only responsible for rendering state and emitting user intents.

### GameManager's Role (State Authority)

The GameManager serves as the authoritative controller for the shop's state during a node visit. It does not use a separate ShopManager.

**Temporary State Variables:**
- `_temporary_shop_master_dict: Dictionary`: Holds the actual GachaBallInstance objects available for purchase.
- `_temporary_shop_container: DataContainer`: A FixedArrayContainer of size 3 that holds the UUIDs of the items in the shop slots, acting as a performant index.
- `_reroll_cost: int`: Tracks the current cost to reroll, which increases with each use within the same shop visit.

### Shop.tscn's Role (View)

The Shop.tscn scene and its script ([Shop.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Shop.gd)) are responsible for the presentation layer.

- **Renders State:** It populates its SlotView children based on the data provided by the GameManager.
- **Emits Intents:** It does not perform any game logic. Instead, it emits signals like `shop_purchase_requested` or `shop_reroll_requested` when the player clicks buttons.
- **Handles Interaction:** Player interactions (clicks, double-clicks) with the GachaBalls are routed through the Global Interaction Router (GIR). The shop context is configured with an `interaction_mode` of `SELECTION_ONLY`, meaning items can be selected for purchase but not moved or dragged.

## 3. Key Logic Flows

### A. Entering a Shop

1. **Node Selection:** The player selects a SHOP node from the Path Choice screen.
2. **State Initialization:** The GameManager's `_enter_shop()` method is called.
   - It resets the `_reroll_cost` to its base value (1 Gold).
   - It calls `_generate_shop_stock()` to create 3 new, random GachaBallInstance objects and populates its temporary state variables.
3. **Scene Display:** The GameManager requests the SceneManager to display the Shop.tscn. It passes the generated stock and reroll cost to the scene for initial rendering.

### B. Purchasing an Item

1. **Player Action:** The player selects an item and clicks the "Buy" button.
2. **Gold Coin Animation:** `_animate_gold_spend()` animates gold coins flying from the gold counter to the Buy button.
3. **Intent Emitted:** The Shop.gd script emits the `shop_purchase_requested(instance_uuid, cost)` signal.
4. **Validation:** The GameManager receives the signal. It validates that:
   - The player has enough Gold.
   - The `instance_uuid` exists in its `_temporary_shop_master_dict`.
5. **State Change (The Golden Rule):** If valid, the GameManager performs the state change:
   - It deducts the cost from the `RunState.gold`.
   - It moves the GachaBallInstance from its `_temporary_shop_master_dict` to the permanent `RunState.run_instances` dictionary.
   - It updates the instance's location properties to place it in the correct `RunInventoryT<n>` container.
   - It removes the UUID from the `_temporary_shop_container`, leaving the shop slot empty.
6. **GachaBall Animation:** `_animate_gachaball_to_machine()` animates the purchased gachaball from its shop slot to the corresponding tier's gacha machine with a Bezier arc (same animation as battle draw, but reversed direction).
7. **Machine Bounce:** When the ball lands, `Main.trigger_machine_bounce(tier)` is called to bounce the target machine.
8. **UI Refresh:** The GameManager emits a `shop_stock_refreshed` signal, causing the Shop.tscn to update its view, showing the empty slot.

### C. Rerolling Stock

1. **Player Action:** The player clicks the "Reroll" button.
2. **Gold Coin Animation:** `_animate_gold_spend()` animates gold coins flying from the gold counter to the Reroll button.
3. **Intent Emitted:** The Shop.gd script emits the `shop_reroll_requested` signal.
4. **Validation:** The GameManager receives the signal and validates that the player has enough Gold to pay the current `_reroll_cost`.
5. **State Change:** If valid, the GameManager:
   - Deducts the `_reroll_cost` from `RunState.gold`.
   - Increments the `_reroll_cost` by 1 for the next reroll.
   - Clears its temporary shop dictionaries and calls `_generate_shop_stock()` to create a new set of 3 items.
6. **UI Refresh:** The GameManager emits `shop_stock_refreshed` with the new stock, causing the Shop.tscn to display the new items and the updated reroll cost.

### D. Inspection

Although the `interaction_mode` is `SELECTION_ONLY`, players can still inspect items. A double-click on a GachaBall in the shop will be interpreted by the GIR as a valid inspection request, which will generate an `OPEN_INSPECTION_WINDOW` command for the WindowManager to execute. This allows players to view item details before purchasing.

## 4. Animation Implementation

See [AnimationImplementationGuide.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/AnimationImplementationGuide.md) Section 8.5-8.6 for details on:
- Gold coin tossing animation (`_animate_gold_spend()`)
- GachaBall return animation (`_animate_gachaball_to_machine()`)
- Machine bounce effect (`trigger_machine_bounce()`)