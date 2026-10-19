# Flashcard Heroes - Technical Design Document (TDD V10.0)

## Part 1: Core Architecture & Principles

### 1.1 The Definitive Hybrid Architecture
The game follows a mandatory hybrid architecture that separates data truth from positional indexing. All systems must adhere to these four core rules:

1. **The Instance is the Source of Truth:** `GachaBallInstance` is a stateful composition container and the single source of truth for an individual gachaball's state (stats, components, location).
2. **Component-Based Composition:** All modifications to a gachaball (equipment, buffs, levels, rarity, permanent upgrades) are represented as source-aware components, allowing for deterministic resolution, inspection, and serialization.
3. **The Container is a Positional Index:** `DataContainer` (Lineups, Benches, Inventories) holds only UUIDs. It provides O(1) location-based lookups but does not "own" the instance data.
4. **The Golden Rule of State Synchronization:** Any operation moving an instance (move, swap, equip, discard) must update both the Index (`DataContainer`) and the Truth (`GachaBallInstance`) in a single atomic transaction.

### 1.2 The Command Pipeline (Slay the Spire 2 Architecture)
The game uses a strict Command Pattern to isolate user intent from state mutation:

- **Encapsulation**: Every state-altering player interaction (buying an item, dragging a card, choosing a path, or dismissing a tutorial) is encapsulated into an immutable object subclassed from `GameAction`. The UI is completely forbidden from directly mutating `RunState`.
- **Validation & Execution**:
  1. A UI script (e.g., `GlobalInteractionRouter` or a button click) instantiates a validated `GameAction` (e.g., `BuyShopAction(item_uuid)`).
  2. The action is passed to `ActionQueue.request()`. The queue checks `action.is_valid()`.
  3. If valid, the queue invokes `action.execute()`, delegating to backend logic (`InventoryOperations`, `CombatSimulator`).
- **Input Gating**: While an action is processing, `ActionQueue` blocks all global player input until the mutation and all resulting visual choreography have completed.
- **Serialization & Recording**: As the action completes, `SessionRecorder` serializes it as a JSON line to the active `.mcr` replay file alongside a `time_delta`.
- **Deterministic Replay Engine**: During playback, the replay engine is completely blind to UI state. It loads the initial RNG seed, blocks player input, deserializes the JSON lines back into `GameAction`s, and pushes them into `ActionQueue` at recorded intervals.

---

> [!IMPORTANT]
> **MANDATORY CODING STANDARDS:**
> Before writing any code, you **MUST** read [CODE_GUIDELINES.md](CODE_GUIDELINES.md).
> It defines the strict laws of the Hybrid Architecture, the VCR Pattern, and prohibited anti-patterns.

---

## Part 2: Data Domain

### 2.1 Core Resources & Data Models
- **`RunState.gd`**: Persistent state for the entire run (gold, day, unlocked recipes, global instance dictionary, deck progress, RNG states).
- **`GachaBallDefinition.gd`**: Immutable template for units and items. Contains base stats, abilities, token/gold costs, tags, and temporal prerequisites (`min_day`, `max_day`). Inherits from `WeightableEntity`.
  - **Unified Slot Constraint**: `item_slot_count` is strictly **1** for all units (`category == &"UNIT"`), enforcing that every unit holds at most one item, and 0 for non-units.
- **`TrinketDefinition.gd`**: Immutable template for trinkets, providing run-wide passive bonuses. Inherits from `WeightableEntity` for director-based generation.
- **`GachaBallInstance.gd`**: Stateful composition container representing an individual gachaball. Manages its own components, live combat stats (`current_hp`, `current_pwr`), and equipment references.
- **`GachaBallComponent.gd`**: Base class for all instance modifications (`StatComponent`, `TagComponent`, `AbilityComponent`, `VisualComponent`).
- **`VisualDataAdapter.gd`**: Logic-to-View bridge that converts instance component stacks into rendered visual layers.
- **`LocationIdentifier`**: Universal key `{container, index, unit_uuid}` used to bridge Managers and Views.

### 2.2 Location Registry
Logical locations are categorized by their lifecycle:
- **Run State**: `RunInventoryT1`, `RunInventoryT2`, `RunInventoryT3`, `PlayerLineup`, `PlayerBench`.
- **Battle State**: `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`, `EnemyLineup`, `EnemyBench`, `DiscardPile`, `EnemyTrinkets`.
- **Equipped**: `equipped_item` (conceptual slot attached directly to a unit).

---

## Part 3: System Architecture & Responsibilities

### 3.1 Gameplay & Simulation
- **Battle System (`BattleManager.gd`)**: Orchestrates combat via a strict **"Simulate First, Present Later"** model. (See [CombatSystem.md](CombatSystem.md) for full phase and event logic).
  - Delegates to specialized helpers:
    - `CombatSimulator`: Combat loop, actor turn queue, reaction processing, and command pipeline execution.
    - `EffectHandlers`: Processing of raw stat/summon mutations into `CombatEvent` streams.
    - `BattleState`: Instance storage and container indexing during battle.
    - `InventoryOperations`: Exclusive handler for in-combat inventory mutations (draws, equips, merges, discards).
  - **Snapshotting**: Captures value-based snapshots of board states before turn execution to ensure views render consistent visual baselines.
- **Ability System (`AbilityResolver.gd`)**: A source-aware broadcast system that queries active ability entries from units, items, and traits in a unified priority pass (**Unit -> Item -> Trinket**).
- **Encounter System (`EncounterGenerator.gd`)**: Budget-based procedural enemy generator (`3 + (Day-1)`) utilizing a greedy fill algorithm to guarantee 100% budget spend. (See [EncounterSystem.md](EncounterSystem.md)).
- **Flashcard System (`FlashcardManager.gd`)**: Persistent autoload managing SRS minigame sessions, weighted distractor generation, and mid-minigame streak unlocks. (See [FlashcardSystem.md](FlashcardSystem.md)).
- **Inventory System (`InventoryManager.gd`)**: Stateless logic controller executing validated moves, equips, merges, and item replacements. (See [InventoryManager.md](InventoryManager.md)).

### 3.2 Interactions & UI Flow
- **Global Interaction Router (GIR)**: The central command factory that translates raw user input (`InteractionContext`) into validated `GameAction` commands. (See [UIInteraction.md](UIInteraction.md)).
- **Window Manager (`WindowManager.gd`)**: Manages the hierarchical lifecycle of modals and inspection peek windows using "Show-before-Measure" layout synchronization and a strict five-tier CanvasLayer system:
  - `BackgroundUILayer` (Layer 40): Inventory drawers and discard trays.
  - `HUDLayer` (Layer 60): Persistent HUD and Gacha Machines.
  - `EffectsLayer` (Layer 90): Standard visual effects.
  - `ModalLayer` (Layer 120): Modals, popups, and locked inspection windows.
  - `GlobalVFXLayer` (Layer 150): High-priority currency animations (Gold/Token Gain/Spend) and screen transitions.
  - `CursorLayer` (Layer 1024): 1000Hz raw software cursor overlay (`CursorManager.gd`).
- **Interactive Overlays**: Dedicated service zones (Shop, Black Market, Rewards) using `DropZone.gd` and visual proxies for stable drag-and-drop transactions.
- **Audio System (`AudioManager.gd` & `Audio.gd`)**: Global SFX pooling (16 pre-instantiated players), dynamic BGM pitch tweens, and semantic sound registry mapping. (See [AudioSystem.md](AudioSystem.md)).

---

## Part 4: System Interactions & Pipelines

### 4.1 Input-to-Action Pipeline
1. **View** emits `InteractionContext` to GIR upon player gesture (click, drag, drop).
2. **GIR** maps source and target locations to functional context groups and validates intent.
3. **GIR** instantiates a validated `GameAction` subclass and requests execution via `ActionQueue.request(action)`.
4. `ActionQueue` blocks player input, invokes `action.execute()`, and yields until state mutations and visual animations complete.
5. If ambiguous (e.g. valid merge recipe exists on drag-drop), `WindowManager.open_choice_window()` prompts the player, which dispatches a subsequent `ChoiceAction`.

### 4.2 Combat Broadcast & Execution Pipeline
1. `BattleManager` detects an execution trigger (e.g., `TRIGGER_ON_ATTACK`, `TRIGGER_ON_DEATH`).
2. `AbilityResolver` evaluates active instances in O(N) priority order: **Unit -> Item -> Trinket**.
3. `CombatSimulator` delegates effect calculations to `EffectHandlers`, generating an ordered queue of `CombatEvent`s (the `TurnLog`).
4. `BattleAnimator` consumes the `TurnLog` sequentially during the presentation phase to animate attacks, damage numbers, and death/summon transitions.

---

## Part 5: Infrastructure & Platform Architecture

### 5.1 Database Registry
- Central autoload (`Database.gd`) that loads all `.tres` definitions and `.json` tables at boot, exposing cached registries for units, items, trinkets, flashcards, and merge recipes.

### 5.2 Localization & Exported Resource Loading
- Key-based translation via Godot `Translation` resources. Exported/mobile builds load compiled `.translation` binaries rather than reading loose CSV files at runtime.
- Runtime directory scans support `.remap` file references (`.tres.remap`, `.res.remap`) to ensure compatibility with packed PCK archives on mobile and console exports.

### 5.3 Mobile & Android Platform Architecture
To guarantee visual stability, input parity, and power efficiency on mobile devices:
- **SubViewport UI Rendering Isolation**:
  To resolve mobile rendering glitches (dithered lines, non-square pixels, and shader scaling artifacts across non-standard mobile aspect ratios), the main game hierarchy is isolated within a `SubViewportContainer`:
  ```
  Main.tscn
  └── ContentArea (SubViewportContainer)
      └── SubViewport (Fixed 1920x1080 canvas)
          ├── SceneBackground (FullScreen)
          └── VBoxContainer (Centering Layout)
  ```
  This ensures opaque backgrounds span screen notches without grey bars, keeps custom shaders at native aspect ratio, and maps touch coordinates directly without manual offsets.
- **Platform Detection (`OS.has_feature("mobile")`)**:
  - **Cursor Management**: Software cursors are disabled on mobile by default (`CursorManager.gd`), restoring the native OS touch indicator.
  - **Touch-to-Hover**: Hover peeks are adapted to mobile touch using long-press detection (`0.5s` hold) via `InputUtils.gd`. Touch drag greater than 24 pixels cleanly cancels inspection.
- **Mobile Performance & Power Optimization**:
  - The deterministic Command Pipeline and discrete turn architecture completely eliminate per-frame state polling in `_process()`, significantly reducing mobile battery drain and thermal throttling.
  - Global playback acceleration (`Engine.time_scale`) smoothly accelerates tweens and particle timers across mobile threads without extra script iterations.

---

## Part 6: Run Lifecycle, Persistence & Serialization

### 6.1 Checkpoint Architecture
The run state is serialized and saved to disk automatically **immediately upon entering the Path Choice scene** (at the start of each Day, after the day counter advances). This creates a safe, deterministic checkpoint at the start of every day.

### 6.2 Save File Schema & SaveManager
The `SaveManager` autoload singleton (`res://scripts/SaveManager.gd`) manages file I/O:
- **Storage Location**: `user://run_save.dat`.
- **Format**: Native Godot variant dictionary serialization via `FileAccess.store_var()` and `get_var()`.
- **Serialized Dictionary Schema (`RunState.to_save_dict()`)**:
  - **Run Seed & Seeded PRNG**: Master seed `run_seed` (32-bit uint) and stream states (`rng_state` for `map_rng`, `gacha_rng`, `shop_rng`, `combat_rng`, `reward_rng`), ensuring 100% deterministic run resumption.
  - **Run Progress**: `day`, `gold`, `tokens`, `bosses_defeated`, `current_boss_level`.
  - **Run Statistics**: `total_enemies_defeated`, `total_gold_earned`.
  - **Deck State**: `deck_def_id`, `active_deck_ids`, `cards_presented_count`.
  - **Flashcard Progress**: Full mastery history per card (`mastery_level`, `times_reviewed`, `last_review_day`).
  - **Instance Registry**: All `GachaBallInstance` dictionaries (`ball_uuid`, `definition_id`, `origin_uuid`, stats, components, equipment UUIDs, tags, status effects).
  - **Containers**: UUID layouts across all inventory containers (`PlayerLineup`, `PlayerBench`, `RunInventoryT1/T2/T3`).
  - **Action Queue History**: Processed `GameAction` history for session audit and VCR playback.

### 6.3 Loading & Scene Transitions
- The Title Screen detects `user://run_save.dat` on startup and displays the "Continue" button.
- Clicking "Continue" loads `RunState` into `GameManager.run_state` and transitions directly to the Path Choice scene.
- **Double Increment Prevention**: `GameManager.loading_from_save` is flagged during load. `PathChoice.gd` checks this flag to suppress daily day increment logic, preserving exact checkpoint day numbers.
- **Roguelike Save Clearing**: To enforce permadeath stakes, `SaveManager.delete_save()` deletes the save file immediately upon reaching a terminal state (Victory or Defeat).

---

## Part 7: Deterministic PRNG Stream Isolation

To guarantee that gameplay decisions, combat outcomes, and replays remain 100% deterministic and immune to desynchronization:
- **Stream Isolation (`RNGManager.gd`)**: Game systems are strictly prohibited from calling global unseeded random methods (`randi()`, `randf()`). All randomness routes through dedicated `SeededRNG` streams derived from `RunState.run_seed`:
  - `map_rng`: Node generation and path randomization.
  - `gacha_rng`: In-combat gacha machine draw order and distractor picks.
  - `shop_rng`: Shop inventory generation and Black Market transformations.
  - `combat_rng`: Combat targeting choices (`TARGET_RANDOM_ENEMY`, `TARGET_RANDOM_ALLY`) and effect rolls.
  - `reward_rng`: Post-battle reward capsules and trinket offerings.
- **State Capture**: When saving a checkpoint, the internal state of each RNG stream is serialized into `rng_state`, guaranteeing identical outcome sequences upon run continuation.

---

## Part 8: Physics-Based Gacha Visuals

The battle inventory system uses a pure Godot 2D Physics simulation for the gachaball containers. The following architectural parameters are enforced for high-speed stability and visual fidelity:

### 8.1 Stability & Resting State
- **Restitution (Base Bounce)**: Set to **0.15** to ensure stability while maintaining tactile 'life'.
- **Gravity Scale**: Fixed at **4.0** (RigidBody2D property) for crisp, heavy impacts and rapid settling.
- **Damping**: `linear_damp = 0.05` and `angular_damp = 0.5` on gachaballs to allow fluid movement while preventing eternal rolling.
- **Friction**: Set to **0.05** (`GachaBallMaterial.tres`) for slippery, high-density packing.
- **Sleep Mode**: A global 6.0s countdown force-sleeps the entire drawer pile after container motion stops.
- **Continuous Collision Detection (CCD)**: Enabled on all balls to prevent floor-tunneling during high-velocity drawer animations.

### 8.2 Boundary Buffering & Fast Movement
- **Massive Boundary Buffering**: Container boundaries (walls, floor, and hard lid) use a thickness of **5000.0 pixels**, preventing physics escape during extreme single-frame positional deltas.
- **Discrete Layering**: Containers use mutually exclusive physics layers (e.g., Tier 1 on Layers 10/11, Tier 2 on Layers 12/13), allowing bounds of one container to overlap another without unintended collisions.
- **Overflow Detection**: A 30px sensor at the top of the drawer detects overflow. Contact for 5 continuous seconds triggers discard penalty routing to the Battle Discard Pile.

### 8.3 Rendering Fidelity & Interpolation
- **Physics Interpolation**: Uses Godot 4 native `Node.PHYSICS_INTERPOLATION_MODE_ON` to decouple visual rendering from the fixed physics tick rate (120 Hz).
- **Spawn Origin Handling**: To prevent a 1-frame visual flash at `(0,0)`, local positions are calculated and assigned before `add_child()`, followed immediately by `reset_physics_interpolation()`.

### 8.4 Soft Spawning (Collision Scaling)
- **Overlap Prevention**: Gachaballs spawn with an initial collision scale of `0.1`.
- **Gentle Impulse Expansion**: A `Tween` scales the collision shape to `1.0` over **0.5 seconds**, translating explosive overlap impulses into gentle nudges.
- **Spawn Stagger**: Drops are spaced by a `0.15s` interval (`DropTimer`) to give the physics solver temporal breathing room.

### 8.5 Dodecagon Shape Approximation
- **Stable Facets**: Rather than direct `CircleShape2D` contact (which produces single-point instability), gachaballs use a **12-sided CollisionPolygon2D (Dodecagon)**.
- **Bridge Stability**: The flat facets allow balls to lock together into stable bridges, resolving to zero velocity significantly faster while remaining visually indistinguishable from a circle at 48px radius.
