@ -0,0 +1,147 @@
# Flashcard Heroes - Technical Design Document (V9.2)

**Version:** 9.2
**Status:** Active
**Architectural Update (V9.2):** This version introduces further optimizations and robustness improvements:
1.  **Optimized Ability Resolution:** `AbilityResolver` now uses a single-pass O(N) bucketing algorithm instead of multiple O(N) passes, improving performance for complex board states.
2.  **Robust Encounter Generation:** `EncounterGenerator` now uses a "gap-filling" algorithm to maximize budget usage and includes a safe fallback mechanism for generation failures.
3.  **Explicit Dependency Injection:** `GameManager` and `Main` now use an explicit registration pattern (`register_main_node`) to prevent fragile scene tree lookups.

**Architectural Update (V9.1):**
1.  **Polymorphic Inventory API:** `InventoryManager` now interacts with `RunState` and `BattleManager` via a unified interface.
2.  **Centralized Window Positioning:** `WindowManager` uses shared logic for viewport clamping.
3.  **Optimized View Lookup:** `GlobalInteractionRouter` uses O(1) lookups.

<!-- TOC -->
- [Part 1: Core Architecture & Principles](#part-1-core-architecture--principles)
- [Part 2: Data Schemas & Structures](#part-2-data-schemas--structures)
- [Part 3: System Architecture & Managers](#part-3-system-architecture--managers)
- [Part 4: Input Handling](#part-4-input-handling)
- [Part 5: Game Flows](#part-5-game-flows)
- [Part 6: Localization](#part-6-localization)
<!-- /TOC -->

## Part 1: Core Architecture & Principles

### 1.1 The Definitive Hybrid Architecture

The game's logic is built upon a mandatory hybrid architecture to guarantee data integrity while maintaining performance. This pattern is required for all game state management.

1.  **The Instance is the Source of Truth:** The `GachaBallInstance` resource is the single, undeniable source of truth for all of its own data, including its stats, status, and location (`location_container_tag`, `location_slot_index`, `equipped_on_uuid`). Caching this data in managers is strictly forbidden.

2.  **The Container is a Performant Index:** `DataContainer` objects hold only UUIDs and act as a disposable index into the master instance dictionary. They provide fast, location-based lookups but are not a source of truth for any data besides the ordering of UUIDs in a location.

3.  **Managers are Authoritative Operators:** Managers contain the stateless logic (the "verbs") that operates on the data. They are responsible for correctly executing the **Golden Rule of State Synchronization**: any operation that moves an instance *must* update both the `DataContainer` (the index) and the `GachaBallInstance`'s properties (the truth) in a single, atomic operation.

## Part 2: Data Schemas & Structures

### 2.1 Core Data Resources

-   **`RunState.gd`**: (Resource) The persistent state for an entire run, including `gold`, `day`, the master `run_instances` dictionary, and flashcard progress.
-   **`GachaBallDefinition.gd`**: (Resource) The immutable template for a GachaBall, defining its base stats, abilities, tags, tier, and `@export var cost: int`.
-   **`GachaBallInstance.gd`**: (Resource) A unique, mutable instance of a GachaBall. This is the single source of truth for an instance's current HP/PWR, status effects, and location properties.
-   **`MergeRecipe.gd`**: (Resource) Defines a valid merge combination of two ingredient IDs and the resulting ID.
-   **`FlashcardDefinition.gd`**: (Resource) An in-memory representation of a flashcard, loaded from JSON.
-   **`FlashcardProgress.gd`**: (Resource) Tracks run-specific progress (`mastery_level`, `last_review_time`) for a single flashcard.
-   **`AbilityDefinition.gd`**: (Resource) Defines an ability by linking a `trigger`, `condition`, and `effects`.
-   **`EffectRequest.gd`**: (Resource) A request to execute an ability, placed on the effect queue.
-   **`InteractionContext`**: (Immutable Packet) A standardized data packet sent from a UI view to the Global Interaction Router with every gesture. Its structure is defined in `docs/InputHandling(GIR).md`.
-   **`LocationIdentifier`**: (Object) A lightweight object containing a `container` (StringName), `index` (int), and `unit_uuid` (String). Used as the universal key for locating instances in the Hybrid Architecture.

### 2.2 Location Container Tags

These `StringName` values define all possible logical locations for a `GachaBallInstance` and are used in its `location_container_tag` property.

-   **Run State Locations:** `RunInventoryT1`, `RunInventoryT2`, `RunInventoryT3`, `PlayerLineup`, `PlayerBench`, `ItemInventory`.
-   **Battle State Locations:** `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`, `EnemyLineup`, `DiscardPile`.
-   **Special Location:** `equipped_item` (conceptual, used by `LocationIdentifier`).

### 2.3 Data Containers

A layer of `DataContainer` objects provides a fast, location-based index for O(1) lookups.

-   **`DataContainer.gd`**: Abstract base class defining the common interface.
-   **`FixedArrayContainer.gd`**: Implements a fixed-size array for lineups and benches.
-   **`GrowableGridContainer.gd`**: Implements an expandable container for inventories and discard piles.

## Part 3: System Architecture & Managers

The game logic is modularized into distinct systems and managers, each with a clear responsibility.

### 3.1 Core Systems

-   **GachaBall System:** Manages the definitions and instances of all collectible units and items.
    -   (See `docs/GachaBallSystem.md`)
-   **Combat System:** Orchestrates the turn-based, auto-battler combat phases and logic.
    -   (See `docs/CombatSystem.md`)
    -   **Architecture:** Uses a **Strict State-Event Decoupling** model ("Simulate First, Present Later").
    -   **Snapshot Architecture:** Before simulation, captures a value-based snapshot (no object references) of the entire board state.
        - Views populate from snapshot values, never query live instances during COMBAT
        - Prevents presentation from seeing "future" state after simulation mutates data
    -   **Phase-Based UI Blocking:** During animation phases (COMBAT, START_OF_TURN, END_OF_TURN), UI updates are blocked to prevent destroying the Animator's visual registry.
-   **Event Causality:** Events must appear in causal order (DAMAGE → DEATH → SUMMON).
    -   **Death Event Ordering:** DEATH events generate BEFORE on_ally_death triggers, ensuring correct TurnLog order. Game state cleanup is deferred internally for reaction mechanics.
    -   **Effect Decoupling:** Effects receive ALL data via `context` parameter. Effects NEVER call `get_instance()` or query containers. This is the most critical architectural rule.
    -   **Unified Stat Modification:** All stat changes (HP, PWR, Status) use `apply_stat_delta()` for consistency and correct snapshotting.
    -   **Visual Registry:** The Animator scans the scene tree at the start of a turn to map UUIDs to `GachaBallView` nodes, storing them in a `_visual_registry`.
    -   **Puppet Views:** During playback, Views operate in "Puppet Mode," strictly decoupled from live data. They are populated via `VisualDataAdapter` and updated strictly via `CombatEvent` payloads.

-   **Ability System:** A data-driven system for executing all special abilities in response to game events.
    -   (See `docs/AbilitySystem.md`)
-   **Flashcard System:** Manages the high-speed learning mini-game and its associated rewards.
    -   (See `docs/FlashcardSystem.md`)
    -   **New Decks Added:** `portuguese_100.json` (100 everyday Portuguese sentences) and `german_100.json` (100 everyday German sentences) with three‑word sentences.
-   **Dynamic Encounter Generation System:** Programmatically generates enemy teams for non-boss battles based on a budget.
    -   (See `docs/EncounterGenerationSystem.md`)
-   **Status Effects System:** Manages temporary buffs/debuffs on units.
    -   **Storage:** `GachaBallInstance.status_effects` dictionary (EffectID -> Stacks).
    -   **Application:** `apply_stat_delta()` handles stacking, removal, and snapshotting.
    -   **Processing:** `BattleManager` processes effects (damage, decay) at specific phases (e.g., End of Turn).
    -   **Extensibility:** Designed to support arbitrary effects via data-driven IDs.

### 3.2 Interaction & UI Managers

These managers are responsible for interpreting player input and managing the UI state. They execute commands issued by the GIR.

-   **Global Interaction Router (GIR):** The central clearing-house for all raw user input. It translates gestures into a command queue for other managers to execute.
    -   (See `docs/InputHandling(GIR).md`)
-   **Selection Manager:** Maintains the state of the single currently selected GachaBall or UI element. Replaces the legacy `InteractionManager`.
    -   (See `docs/SelectionManager.md`)
-   **Window Manager:** The sole authority for the lifecycle of all modal and inspection windows.
    -   (See `docs/WindowManager.md`)

### 3.3 Gameplay Logic Managers

These managers contain the core "verb" logic of the game.

-   **Game Manager:** Orchestrates the meta-game loop, run state, and transitions between scenes.
-   **Battle Manager:** Manages the state and flow of a single battle encounter. Its lifecycle is tied to the battle scene.
-   **Inventory Manager:** A stateless logic controller for all inventory actions (move, swap, merge, equip). It executes `REQUEST_ACTION` commands from the GIR.
    -   (See `docs/InventoryManager.md`)
-   **Database:** Loads and provides query access to all game data resources (`.tres`, `.json`) on startup.

## Part 4: Input Handling

All user gestures and inputs are processed through a unified, decoupled system.

**All user gestures/inputs route through the Global Interaction Router – Refer to `docs/InputHandling(GIR).md`.**

## Part 5: Game Flows

### 5.1 Battle Setup Flow

1.  `BattleManager` receives an `EncounterDefinition`.
2.  It creates `battle_copy()` instances from `run_state.run_instances` for all player GachaBalls. The Hero instance is used directly.
3.  It creates new instances for all enemies and their items as defined in the encounter.
4.  It places all instances into the correct `DataContainer` indices.

### 5.2 Gacha Draw Flow (In-Battle)

1.  A draw is requested for a specific tier.
2.  A random GachaBall is drawn from the corresponding `BattleInventoryT<n>` pool.
3.  If a pool becomes empty, it is immediately reshuffled with all matching GachaBalls from the `DiscardPile`. Reshuffled instances have their HP/PWR reset to base values.
4.  The drawn instance's location is updated to the player's bench or item inventory.

### 5.3 Merge Flow

1.  The Global Interaction Router (GIR) processes a user gesture and places a `REQUEST_ACTION` command (with `source_uuid` and `target_uuid`) onto the command queue, intended for the `InventoryManager`.
2.  The `InventoryManager` queries the `MergeManager` to determine if a valid recipe exists. If it does, the manager calls `MergeManager.calculate_merge_result`, which:
    a. Calculates the merged unit's stats as the sum of both parents' current HP and PWR, minus any equipped item bonuses to prevent "double dipping".
    b. Initializes the new unit instance with its definition (setting base stats).
    c. Applies the calculated combined stats to the new unit.
    d. Returns the merged unit instance and a list of items that should be equipped (without linking them).
3.  The `InventoryManager` receives the result and:
    a. Places the merged unit in the correct destination slot.
    b. Equips the returned items using the data owner's atomic equip API (which adds bonuses back).
    c. Updates all data containers and instance location properties.
    d. Destroys the ingredient instances.
4.  When items are equipped via `BattleManager.bm_equip_item` or `RunState.equip_item`, the unit's `current_hp` and `current_pwr` are modified by calling `equip_item_bonus`, which adds the item's bonuses to the current stats.
5.  The `unit_inventory_changed` signal triggers `GachaBallInstance.recalculate_stats`, which preserves the unit's current stats without clamping PWR to base values, allowing merged units to scale indefinitely.

### 5.4 Post-Battle Reward Flow

1.  After victory is acknowledged, `GameManager` generates temporary `GachaBallInstance` rewards.
2.  The `Reward.tscn` scene is displayed. Its views are configured with an `interaction_mode` of `SELECTION_ONLY`.
3.  The player's clicks are routed through the GIR, which issues `SELECT` and `DESELECT` commands to the `SelectionManager`.
4.  Upon confirmation, `GameManager` performs the state change, moving the chosen instance to the `RunState` and destroying the others.
5.  The player manually transitions back to the path choice screen.

## Part 6: Localization

-   **System:** A key-based system is used for all user-facing text.
-   **Source:** A central `localization.csv` file stores all key-value pairs.
-   **Implementation:** Text is set in UI scripts using Godot's `tr()` function.