# Flashcard Heroes - Technical Design Document

**Status:** Active

## Part 1: Core Architecture & Principles

### 1.1 The Definitive Hybrid Architecture
The game follows a mandatory hybrid architecture that separates data truth from positional indexing. All systems must adhere to these three rules:

1.  **The Instance is the Source of Truth:** `GachaBallInstance` is the single source of truth for all mutable data (stats, status, location properties). Caching or duplicating this data elsewhere is prohibited.
2.  **The Container is a Positional Index:** `DataContainer` (Lineups, Benches, Inventories) holds only UUIDs. It provides O(1) location-based lookups but does not "own" the instance data.
3.  **The Golden Rule of State Synchronization:** Any operation moving an instance (move, swap, equip) must update both the Index (`DataContainer`) and the Truth (`GachaBallInstance`) in a single atomic transaction.

---

> [!IMPORTANT]
> **MANDATORY CODING STANDARDS:**
> Before writing any code, you **MUST** read [CODE_GUIDELINES.md](CODE_GUIDELINES.md).
> It defines the strict laws of the Hybrid Architecture, the VCR Pattern, and the prohibited anti-patterns.

---

## Part 2: Data Domain

### 2.1 Core Resources
-   **`RunState.gd`**: Persistent state for the entire run (gold, day, unlocked recipes, global instance dictionary).
-   **`GachaBallDefinition.gd`**: Immutable template for units/items. Contains stats, abilities, cost, and temporal prerequisites (`min_day`, `max_day`). Inherits from `WeightableEntity`.
-   **`TrinketDefinition.gd`**: Immutable template for trinkets. Now inherits from `WeightableEntity` to support Director-based reward generation.
-   **`GachaBallInstance.gd`**: Mutable state of a specific gachaball.
-   **`FlashcardDefinition.gd` & `FlashcardProgress.gd`**: loaded JSON data and run-specific mastery tracking.
-   **`LocationIdentifier`**: Universal key `{container, index, unit_uuid}` used to bridge Managers and Views.

### 2.2 Location Registry
Logical locations are categorized by their lifecycle:
-   **Run State:** `RunInventoryT*`, `PlayerLineup`, `PlayerBench`.
-   **Battle State:** `BattleInventoryT*`, `EnemyLineup`, `DiscardPile`, `EnemyTrinkets`.
-   **Equipped:** `equipped_item` (conceptual slot on a unit).

---

## Part 3: System Architecture & Responsibilities

### 3.1 Gameplay & Simulation
Core logic is partitioned to ensure Single Responsibility:

-   **Battle System:** Orchestrates combat via a **"Simulate First, Present Later"** model.
    -   (See `docs/CombatSystem.md` for phase logic)
    -   **SRP Delegation:** `BattleManager` delegates to specialized helpers:
        - `CombatSimulator`: Logic loop and reaction processing.
        - `EffectHandlers`: Conversion of simulation results into `CombatEvent` payloads.
        - `BattleState`: Atomic mutations and container persistence.
    -   **Snapshotting:** Before playback, a value-based snapshot is captured. Views query this snapshot to ensure visual consistency regardless of underlying state mutations.
-   **Ability System:** A broadcast-based system where `AbilityResolver` converts triggers into effects using an O(N) single-pass bucketing algorithm for efficiency.
    -   (See `docs/AbilityExecutionPipeline.md`)
-   **Encounter System:** A budget-based generator (`3 + (Day-1)`) that guarantees 100% budget spend using a greedy fill algorithm.
    -   (See `docs/EncounterSystem.md`)

### 3.2 Interactions & UI Flow
Centralized interpretation of user intent to decouple Views from Logic:

-   **Global Interaction Router (GIR):** The entry point for all UI input. It translates raw `InteractionContext` into a `CommandQueue`.
    -   (See `docs/UIInteraction.md` for selection/interaction rules)
    -   **O(1) Domain Mapping:** Maps containers to functional groups (`BattleBoard`, `InventoryGrid`, etc.) to determine valid interactions.
-   **Window Manager:** Manages the hierarchical lifecycle of modals and inspection windows. Implements **"Show-before-Measure"** layout synchronization to ensure windows shrink to content before positioning.
-   **Inventory Manager:** Stateless executor of `REQUEST_ACTION` commands. It bridges the GIR and the data owners (RunState/BattleManager).
-   **Audio System:** Decoupled SFX/BGM management via semantic IDs (`unit_hop`, `ui_click`).
    -   (See `docs/AudioSystem.md`)

---

## Part 4: System Inter-Actions (Flows)

### 4.1 Input-to-Action Pipeline
1.  **View** emits `InteractionContext` to GIR.
2.  **GIR** maps source/target to functional groups and validates the transition.
3.  **GIR** generates a `REQUEST_ACTION` command.
4.  **InventoryManager** receives the command and requests a `MergeRecipe` from `MergeManager`.
5.  **MergeManager** calculates the result (Sum of parents - equipped bonuses).
6.  **InventoryManager** executes the atomic mutation on the `DataOwner` (RunState or BattleManager).

### 4.2 Combat Broadcast Pattern
1.  `BattleManager` detects a trigger event (e.g., `TRIGGER_ON_ATTACK`).
2.  `AbilityResolver` buckets all active instances (Units, Items, Trinkets) in O(N).
3.  Abilities are resolved in priority order: **Unit -> Item -> Trinket**.
4.  `CombatSimulator` executes the resulting effects and generates the `TurnLog`.

### 4.3 Progression & Unlocks
-   **Recipe Unlocks:** Merge recipes stay locked in `RunState` until the result is first acquired. `MergeManager` checks `RunState.is_recipe_unlocked()` before allowing a merge.
-   **Stat Scaling:** `GachaBallInstance.recalculate_stats` is designed to be cumulative. It preserves current health/power deltas during merges and tier-ups, allowing for infinite growth without clamping to base values.

---

## Part 5: Infrastructure

-   **Database:** Singleton that loads all `.tres` and `.json` resources on startup, providing a central registry for definitions.
-   **Localization:** Key-based translation via Godot `Translation` resources. Exported/mobile builds must load `.translation` assets instead of relying on raw CSV reads at runtime.
-   **Exported Resource Loading:** Runtime directory scans must support exported `.remap` files (`.tres.remap`, `.res.remap`) because Android/exported builds do not expose loose desktop resources the same way.
-   **Inventory Visualization**: Count labels on gacha machines/discard pile are driven by signals from `DataContainers`, ensuring real-time UI magnitude feedback.
-   **Android/Mobile Reference:** See [AndroidPorting.md](AndroidPorting.md) for export setup, touch model, discard-pile mobile notes, and the current unresolved Android-only run-inventory glow issue.
## Part 6: Run Lifecycle & Persistence

### 6.1 Save & Checkpoints
- **Checkpointing**: The run state is automatically serialized and saved to disk at the start of each "Day" (Path Selection scene).
- **Session Management**: Players can resume from the title screen. The save file is **permanently deleted** upon reaching a terminal state (Victory or Defeat) to enforce roguelike stakes.

### 6.2 Scene & State Transitions
- **Persistence**: Core resources (Hero HP, Gold, Run Inventory, Trinkets, Mastery) are persisted in `RunState` and carried across all scenes.
- **Temporary State**: Battle-specific data (Gacha Tokens, Battle Inventory, Discard Pile, Board State) is initialized upon entering a battle node and discarded upon exit.
- **Transition Safety**: Managers must ensure atomic state transfers during transitions to prevent data loss or duplication between the persistent `RunState` and transient battle managers.

---

## Part 8: Physics-Based Gacha Visuals

The battle inventory system uses a pure Godot 2D Physics simulation for the gachaball containers. To ensure stability and visual fidelity during high-speed movement, the following architectural choices are enforced:

### 8.1 Stability & Resting State
-   **Restitution (Bounce)**: Set to `0.08` for all gachaball physics materials. This trace amount of bounce is required to prevent "grid-locking," allowing balls to naturally jostle and settle into hexagonal packing patterns.
-   **Damping**: `linear_damp` and `angular_damp` are set to `0.5` on the gachaballs. This lower value prevents the "syrup-like" stacking seen in previous iterations and ensures gravity remains the dominant force.
-   **Friction**: Set to `0.3` to provide enough surface grip for stable stacking.
-   **Sleep Mode**: `can_sleep` is disabled on gachaballs to prevent them from freezing in "floating" positions before they have fully settled into the pile.

### 8.4 Soft Spawning (Collision Scaling)
-   **Initial State**: To prevent the "Popcorn Effect" (violent upward shooting) caused by simultaneous overlaps during high-volume spawning, gachaballs are initialized with a collision scale of `0.1`.
-   **Growth Transition**: A `Tween` is used to grow the collision shape to `1.0` scale over **0.5 seconds**. This translates potentially explosive restorative impulses into gentle "nudges," allowing the physics solver to resolve overlaps gracefully as the balls fall.
-   **Spawn Interval**: The `DropTimer` is set to **0.18s** to provide enough temporal breathing room for the physics engine between spawns.

### 8.6 Dodecagon Shape Approximation
-   **Stable Facets**: Direct `CircleShape2D` contact is avoid due to numerical instability (single-point contact). Instead, gachaballs use a **12nd-sided CollisionPolygon2D (Dodecagon)**.
-   **Resting Stability**: The flat facets of the dodecagon allow balls to "lock" together in a stable pile, creating "stable bridges" that Godot's physics solver can resolve to a zero-velocity state much faster.
-   **Visual Fidelity**: 12 sides provide a visual approximation that is indistinguishable from a circle at 48px radius while providing the necessary structural stability.

### 8.2 Tunneling Prevention (Fast Movement)
-   **Massive Boundary Buffering**: Container boundaries (walls, floor, and hard lid) utilize a thickness of **5000.0 pixels**. This ensures that even during extreme single-frame positional deltas (rapid elevator slams), the physics solver's corrective vectors always push the balls inward.
-   **Discrete Layering**: Containers use mutually exclusive physics layers (e.g., Tier 1 on Layers 10/11, Tier 2 on 12/13). This isolation allows the massive bounds of one container to safely overlap others without causing unintended collisions.

### 8.3 Rendering Fidelity
-   **Physics Interpolation**: The system utilizes Godot 4's native `Node.PHYSICS_INTERPOLATION_MODE_ON` to decouple visual rendering from the fixed physics tick rate (currently 120 Hz).
-   **Spawn Sequence**: To prevent a 1-frame "flash" at the scene origin `(0,0)`, gachaballs have their local position calculated and assigned *before* calling `add_child()`.
-   **Interpolation Reset**: Immediately after being added to the tree, `reset_physics_interpolation()` is called to prevent the interpolation engine from "sliding" the ball from the origin to its spawn point in a single frame.
