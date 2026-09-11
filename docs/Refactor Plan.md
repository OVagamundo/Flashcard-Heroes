# Architectural Mandate: Deterministic Game Engine & Command Pipeline

## 1. Prime Directive
Transform the game into a **fully deterministic, event-driven architecture** modeled after the core systems of *Slay the Spire 2*. 

The ultimate goal of this refactor is to establish a complete separation between **Player Agency / State Mutation** and **UI / Visual Presentation**. Every state modification across the entire game (run map, gacha pulls, inventory management, merges, and combat) must pass through a command pipeline driven by deterministic logic and seeded RNG.

**This refactor must unlock:**
1. **Run Replays:** The ability to serialize the player's stream of actions into a lightweight log and replay any run or combat turn at variable speeds.
2. **Headless Bot Testing:** The ability for an automated QA bot to feed commands directly into the queue at 100x speed to stress-test balance, find soft-locks, and gather telemetry without touching UI nodes.
3. **Zero-Desync Determinism:** Guaranteed identical run generation and combat outcomes across all platforms given the same seed.

---

## 2. The 4 Pillars of the Architecture

### Pillar 1: Unified Command & Input Pipeline (`GameAction` & `ActionQueue`)
Every decision a player can make—whether buying an item, drawing a gacha ball, merging units, equipping items, resting, or triggering combat—must be encapsulated into a command object (`GameAction`).

* **Validation First:** A command must validate itself against the current `RunState` / `BattleState` before execution (`is_valid() -> bool`). If invalid (e.g., trying to equip an item that no longer exists), it gracefully aborts.
* **Execution & Mutation:** The command mutates state strictly through pure backend systems (`InventoryOperations.gd`, `MergeManager.gd`, `CombatSimulator.gd`).
* **UI Decoupling:** UI controls (drag-and-drop routers, shop buttons, gacha levers) are strictly **Command Generators**. They never mutate game state directly; they instantiate a `GameAction` and push it to the `ActionQueue`.
* **Strict Input Blocking:** When a `GameAction` is enqueued, the `ActionQueue` MUST physically block all other global player input (e.g. via a transparent full-screen `ColorRect` overlay intercepting mouse events) until the action and ALL of its resulting visual animations are 100% finished. Players cannot spam inputs or execute new actions while one is resolving.
* **UI Telemetry & Execution Bypass:** The recorder MUST capture data on how the player interacts with the UI (e.g., when they change combat speed, pause the game via ESC, or open a unit's inspection window) so developers have statistical data on player behavior and animation pacing. However, these pure UI interactions MUST NEVER be implemented as `GameAction`s. They are pushed to the recorder as `TelemetryEvent`s, which bypass the `ActionQueue` completely and take effect instantly on the client side. During replay playback, the engine reads these events for statistical logging but **does not execute them**, ensuring that a recorded speed change never overrides the spectator's replay UI controls.
* **Blocker Layering:** To allow players to click on-screen presentation buttons (like changing speed or opening the settings menu) while the `ActionQueue` is blocking input, those specific UI elements must reside on a CanvasLayer with a higher index than the global input blocker.

### Pillar 2: Simulation Event Stream & Reactive Presentation ("VCR System")
The visual layer (animations, floating numbers, unit jumps, audio) must never dictate game logic.

* **Simulation Generates Events:** When commands or combat turns resolve, the underlying engine generates a queue of immutable `CombatEvent` / `GameEvent` logs carrying snapshot payloads (`CombatPayload`).
* **UI as a Reactive View:** Nodes like `BattleAnimator.gd`, `GachaBallView.gd`, and `SlotView.gd` are purely visual puppets. They consume the event stream and play animations sequentially.
* **Global Engine Speed Scaling:** Playback speed (1x, 3x, etc.) is controlled globally via `Engine.time_scale` (`AnimationConstants.speed_factor`), uniformly accelerating all tweens, timers, particle systems, and token animations without double-scaling. Headless QA bots operate at 0x animation wait time for instant turn processing.
* **Perfect Pacing Preservation:** The event stream must record the exact physical time delta between user actions. Replays must NOT skip or fast-forward human idle time—they must capture and recreate the exact physical time the player waited between clicks to guarantee a perfectly organic VCR playback.
* **Empty Animation Resolution:** If a `GameAction` (like swapping inventory slots) does not trigger any visual animations, the `AnimationCompletionTracker` must instantly resolve without yielding, allowing the `ActionQueue` to proceed immediately without hanging in a soft-lock.
* **Combat Resolution Locking:** For complex state transitions like `BattleStartAction`, the action's `execute()` method must yield until the `CombatSimulator` explicitly broadcasts a `combat_resolved` signal. This guarantees the `ActionQueue` remains locked for the entire multi-minute duration of the battle, preventing players from injecting map or inventory actions while units are fighting.

### Pillar 3: Card / Unit Instance & 3-Tier Stat Lifecycle
Units, items, and flashcard resources must maintain clean state tracking as they are acquired, modified, upgraded, and removed over the course of a run.

* **Flyweight Base + Cloned Instances:** Use master definitions (`GachaBallDefinition`) for static data, and cloned instances (`GachaBallInstance`) for run/battle state.
* **3-Tier Stat System:** Stats (HP, PWR, etc.) must clearly differentiate between:
  1. **Base Value:** Unmodified definition default.
  2. **Enchanted / Permanent Value:** Modifications accrued across the run (merges, training, permanent items).
  3. **Active / Display Value:** Temporary combat-only modifications (buffs, debuffs, burn, armor).
* **Reset Lifecycle:** At the end of combat, active stats discard temporary modifiers and fall back to their run-permanent values.

### Pillar 4: Isolated, Seeded PRNG Streams (COMPLETED)
Randomness no longer relies on platform-dependent system random functions (`randi()`, `randf_range()`). This pillar has been fully implemented.

* **Seeded PRNG (`SeededRNG.gd`):** A wrapper around Godot's `RandomNumberGenerator` that provides deterministic API replacements and serialization support.
* **Stream Isolation (`RNGManager.gd`):** The game now utilizes 6 completely isolated, independent streams derived from a master seed:
  - `map_rng`: Node selection, encounter generation, deck shuffling, flashcards.
  - `combat_rng`: Target resolution, abilities, bounce mechanics, summons.
  - `shop_rng`: Shop generation and `WeightedPoolDirector` rolls.
  - `reward_rng`: Post-combat drops, rest sites, training outcomes.
  - `gacha_rng`: In-combat inventory pulls, UUID generation, run-level overflow.
  - `cosmetic_rng`: Screen shake, coin scatter, physics spread, and audio pitch variance.

---

## 3. Codebase Integration Map & Hotspots

As you implement this refactor, pay close attention to how existing scripts fit into this pipeline:

* **`CombatSimulator.gd` & `CombatCommand.gd`:** You already have a strong command/reaction pattern working inside combat! **Keep this engine intact.** Extend its pattern upward so that out-of-combat operations (`InventoryOperations.gd`, `MergeManager.gd`) follow the same queue-and-event structures.
* **`GlobalInteractionRouter.gd`:** Refactor this from a synchronous logic executor into a **Command Factory**. On drop/click, validate basic UI state, construct the appropriate `GameAction` (e.g., `EquipItemAction`, `SwapInstancesAction`), and pass it to the queue.
* **`SignalBus.gd` & Reactive UI:** When `GameActionQueue` processes an action, it must emit through `SignalBus`. Visual nodes (`SlotView.gd`, `BattleInventoryWindow.gd`) update their presentation solely by reacting to these signals.
* **`AnimationCompletionTracker.gd`:** Use this to allow the `ActionQueue` to `await` active visual feedback before processing the next queued action (during normal player sessions), while bypassing it during headless bot simulations.

---

## 4. Developer Autonomy & Refactoring Freedom

As the lead developer executing this refactor:
* **Freedom of Implementation:** You have full authority to introduce new base classes, helper singletons, or event types as you explore the codebase.
* **Iterative Migration:** You do not need to rewrite the entire engine in a single pass. You can introduce the `GameActionQueue` and migrate input handling subsystem by subsystem (e.g., Inventory drag-drop -> Gacha pulls -> Merge encounters -> Shop choices).
* **Preserve Core Rules:** The balance, math, unit abilities, and visual feel of the game must remain identical. The player should experience no change in gameplay—only a vastly more stable, deterministic, and replay-capable architecture under the hood.

---

## 5. Definition of Done
1. **100% Command Ingestion:** All player interactions across the run map, management screens, gacha, and combat are routed through validated `GameAction` objects.
2. **Replayability:** A list of serialized `GameAction` objects combined with a Run Seed can reproduce an entire game session identically from start to finish.
3. **Bot Compatibility:** An automated script can feed valid `GameAction` commands into the queue without UI interaction and successfully play through runs headless.