# Flashcard Heroes - Code Guidelines & Constitution

> [!IMPORTANT]
> **Status:** MANDATORY
> This document defines the **Law of the Land**. Violating these rules causes desyncs, "ghost units", and impossible-to-debug states.

## 1. The Hybrid Architecture (The Foundation)

Flashcard Heroes uses a **Hybrid Architecture** that strictly separates "Truth" from "Indexing".

### 1.1 The Single Source of Truth & Component Composition
*   **The Instance (`GachaBallInstance`) is King.** It owns the data.
    *   **Live Combat Stats** (`current_hp`, `current_pwr`) are direct member variables, representing transient damage/healing.
    *   **Base Definitions & Modifiers** are dynamically composed using a stack of `GachaBallComponent` resources (e.g., `StatComponent`, `TagComponent`, `AbilityComponent`, `VisualComponent`).
    *   **Status Effects** (Burn, Spikes, Armor) are tracked in the `status_effects` dictionary and converted dynamically into status components.
*   **The Container (`Inventory`, `Lineup`) is just a List.** It only holds UUIDs. It *never* owns data.
*   **Effective Stat Calculation**: Never assume standard stats are static. Use `get_effective_starting_hp()` and `get_effective_starting_pwr()` to query the fully resolved stats from the aggregated component stack.
*   **No Caching:** Never cache properties like `current_hp` in localized variables for longer than a single function scope. Always query the instance.

### 1.2 The Atomic Transaction
Any operation that moves an instance (Equip, Move, Swap) **MUST** update both the Truth and the Index in a single, atomic transaction.
*   **Incorrect:** Removing from `Inventory A` then adding to `Inventory B` manually.
*   **Correct:** using `InventoryOperations.move_item(uuid, from_loc, to_loc)`.

### 1.3 The Unified Command Pipeline (Command Pattern)
No out-of-combat UI controller or event handler may directly mutate `RunState` or inventory contents.
*   **Command Factory:** UI components validate local drag/click state and create a validated `GameAction` subclass (e.g., `InventoryDragAction`, `ShopPurchaseAction`, `DismissTutorialAction`).
*   **Action Queue:** Commands are enqueued to `ActionQueue.enqueue()`. The queue executes `is_valid()` before invoking `execute()`, maintaining a FIFO execution loop and recording serialized action history (`to_dict()`) for replayability.
*   **Strict Deterministic Replays:** Replays are "dumb and blind". The playback engine ONLY injects recorded `GameAction`s. It never records or attempts to mimic UI states, mouse movements, or telemetries. During playback, all player input is strictly blocked (except spectator controls).
*   **No Core Game Loop:** Game state progresses strictly as a reaction to processed player input actions.

### 1.4 Isolated Seeded PRNG Streams
All game randomness must use `RNGManager` stream isolation.
*   **No System Random:** Direct calls to `randi()`, `randf()`, or unseeded `randi_range()` are banned in game logic.
*   **Stream Isolation:** Systems query dedicated streams (`map_rng`, `gacha_rng`, `shop_rng`, `combat_rng`, `reward_rng`) seeded from `RunState.run_seed`.

### 1.5 Global Engine Time Scaling
Playback speed changes (1x, 3x, etc.) are managed globally via `Engine.time_scale` (`AnimationConstants.speed_factor`).
*   **Universal Acceleration:** Setting `Engine.time_scale` automatically scales all tweens, timers, particle systems, and token animations uniformly across the engine.
*   **No Double-Scaling:** Individual animation scripts must NOT manually divide durations by `speed_factor` when `Engine.time_scale` is active. Use `AnimationConstants.scaled(duration)` which returns raw durations.

---

### 1.6 The "Why" of the Command Pipeline (Slay the Spire 2 Architecture)
The fundamental reason the entire game operates on this strict `GameAction` pipeline is exactly the same as the architecture for Slay the Spire 2:
1. **Deterministic Replays:** By turning every state mutation into a serialized command, any gameplay session can be perfectly recorded and reproduced without massive save states. The replay engine just needs the initial seed and the sequence of actions.
2. **Headless Bot Testing:** AI agents or automated QA bots can play the game at 100x speed by injecting `GameAction`s directly into the queue, entirely bypassing the UI layer, graphics rendering, and human reaction times.
3. **Desync Prevention:** It guarantees that the same input always results in the same outcome, completely eliminating "ghost units" or desyncs caused by UI glitches, animation race conditions, or frame drops.
4. **Decoupling Presentation from State:** It forces the UI to be a "dumb puppet," meaning visual polish, animation changes, and pacing adjustments can be made freely without ever breaking the underlying game logic.

---

## 2. The Simulation Layer (The Brain)

This layer includes `BattleManager`, `CombatSimulator`, and `EffectHandlers`. It represents the "Mind" of the game.

### 2.1 The "Blind God" Rule
The Simulation Layer is **BLIND**.
*   ❌ **NEVER** call `get_tree()`, `get_node()`, or access the SceneTree.
*   ❌ **NEVER** emit signals (except for debug/logging).
*   ❌ **NEVER** instantiate `.tscn` files or visual nodes.
*   ✅ **ALWAYS** return data (`CombatEvent`, `EffectResult`) for the UI to consume later.
*   ✅ **ALWAYS** use `is_simulation: true` when you need detailed events (even in Battle). Legacy `int` returns are banned.

### 2.2 Strict EffectResult Typing & The `is_simulation` Flag
Every ability/effect `execute()` function **MUST** strictly return an `EffectResult` object. Returning primitive types (like `int` or `bool`) is legacy behavior and will crash the Command Pipeline.
The `execute()` method receives an `is_simulation` flag in its context:
*   **If `true`:** You **MUST** return an `EffectResult` filled with DTOs (e.g. `DamageRequest`, `SummonRequest`) describing what *would* happen. You **CANNOT** change `current_hp` or any other state directly.
*   **If `false`:** You may mutate state directly (or use helper functions), and return a finalized `EffectResult` containing the visual `CombatEvent`s to be appended to the VCR TurnLog.

### 2.3 The Context Contract
Abilities are isolated functions. They know **only** what is passed in their `context` dictionary.
*   ❌ **NEVER** query `BattleManager` for global state (e.g., "get all enemies").
*   ✅ **ALWAYS** use `context` keys (`target_uuid`, `source_uuid`, `turn_number`).

---

## 3. The Presentation Layer (The Puppet)

This layer includes `BattleView`, `BattleAnimator`, and `GachaBallView`.

### 3.1 The VCR Pattern (Combat Phase)
Combat is a pre-recorded movie.
1.  **Simulation** runs instantly at Turn Start → generates `TurnLog`.
2.  **Presentation** plays the `TurnLog` sequentially like a VCR tape.
*   **Implication:** The UI is physically incapable of changing the game outcome. It is a dumb terminal.

### 3.2 The Async Pattern (Management Phase)
During the Management phase, actions like drawing units or merging do NOT use the sequential VCR.
*   **Simulation** runs the action instantly and returns a localized event chain.
*   **Presentation** plays this chain asynchronously (`animator.play_async_chain()`).
*   **Implication:** Multiple visual actions (like rapid-fire drawing) overlap and execute in parallel, completely decoupled from the strict sequential turn log.

### 3.3 The Snapshot Rule (Combat Phase)
During the `COMBAT` phase, the UI must **NEVER** query the live `GachaBallInstance`.
*   **Why?** The live instance is already at the "End of Turn" state (damaged/dead).
*   **How:** The UI uses a **Visual Snapshot** captured before the turn started.
*   ❌ **Banned in UI:** `BattleManager.get_instance(id)`
*   ✅ **Allowed:** `_visual_snapshot[id]`

### 3.4 The Puppet Mode (Orchestration)
During complex animation sequences (like a potion usage or combat event), the Data Model ("Truth") updates instantly, but visuals must animate.
*   **Silence the Index:** The Manager actively blocks global UI refreshes (`set_processing_effect(true)`) during the sequence.
*   **Guard the Puppet:** The View actively ignores "loud" signals (`unit_stat_changed`) if the Manager is in Puppet Mode.
*   **Tween, Don't Snap:** Visual updates must *always* tween from the current visual value, not snap to the new data value.
*   **Static vs. Dynamic:** `populate()` and `update_visuals()` are **STATIC** operations and must explicit disable animation (`animate=false`). Events are **DYNAMIC** and explicit enable animation.

---

## 4. Ability & Trinket Standards

### 4.1 Component-Composed Ability Broadcast
Active abilities are no longer statically bound to a unit. They are dynamically resolved via the source-aware broadcast system:
*   **Abilities Query**: The `AbilityResolver` maps active abilities by querying `instance.get_active_ability_entries()`.
*   **Component Modifiers**: Ability components (`AbilityComponent`) can dynamically inject abilities (e.g., from equipped items or persistent buffs), or they can set modes to `DISABLE` or `REPLACE` base unit abilities.
*   **Decoupled Triggers**: Abilities must *always* execute through the event-driven system (triggers like `on_attack`, `on_hurt`, etc.), sorted deterministically by priority.

### 4.2 Priority Is Law
Every reaction has a strict numeric priority defined in `Constants.gd`.
*   `PRIORITY_TRINKET_SUMMON` (210) > `PRIORITY_ITEM_SUMMON` (200).
*   **Rule:** Always explicitly define priority in `.tres` files if the ability reacts to an event.

### 4.2 Ownerless Trinkets
Trinkets are not "held" by units in the simulation sense (even if the UI shows them there).
*   **Context:** `source_uuid` is always `""` (empty string).
*   **Team Check:** You **MUST** use `context.team` (or `fainting_ally_team`) to determine which side owns the trinket.

---

## 5. The "Never" List (Critical Anti-Patterns)

1.  **Never `await` in Simulation:** The simulation must be synchronous and instant. `await` breaks the VCR generation.
2.  **Never Return Primitives from Effects:** Effects must return `EffectResult` objects. Returning raw `int` or `bool` causes crashes in the animation loop.
3.  **Never Defensive Code:** Do not use `if is_instance_valid(x): return`. Use `assert(is_instance_valid(x))` and crash. We fail fast to find bugs, we don't hide them.
2.  **Never Defensive Code:** Do not use `if is_instance_valid(x): return`. Use `assert(is_instance_valid(x))` and crash. We fail fast to find bugs, we don't hide them.
3.  **Never Modify Core for One Ability:** If you need to change `BattleManager.gd` for a specific trinket, your design is wrong. Use the existing Event/Trigger system.
4.  **Never Mix Logic and Visuals:** If your script imports `Control` or `Sprite2D`, it CANNOT contain combat logic. If your script imports `GachaBallInstance`, it CANNOT contain visual code.
5.  **Never Leak Engine Resources:** When destroying nodes (`queue_free`), ALWAYS ensure that any active `Tween` or `SceneTreeTimer` is explicitly killed or properly bound (`tween.bind_node(self)`). Orphaned tweens holding references to freed nodes will cause severe memory leaks and desyncs.

6.  **Never Assume Existence:** Do not call a function (e.g. `enqueue_reaction`) unless you have verified it exists in the definition file.
7.  **Never Leave Zombies:** When removing a unit, ALWAYS use `bm_remove_instance`. Never use `container.set_uuid(i, "")` directly.

---

## 6. Naming & Style

*   **Variables/Functions:** `snake_case` (e.g., `calculate_damage`)
*   **Classes:** `PascalCase` (e.g., `CombatSimulator`)
*   **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAX_INVENTORY_SLOTS`)
*   **Private Members:** Prefix with `_` (e.g., `_internal_cache`)
*   **Typing:** Static typing is **MANDATORY** for all new code.
    *   `var x: int = 5` (Good)
    *   `var x = 5` (Bad)

---

## 7. Verification & Audit (The Process)

Errors often arise from assuming APIs or schemas instead of verifying them. To prevent "death by a thousand cuts":

### 7.1 Verify BEFORE You Write
*   **Check File Paths**: Do not guess where scripts live. Use `ls` or `find`. (e.g., `Scripts/` vs `Scripts/Resources/`).
*   **Check Property Names**: Do not assume variable names in Resources. Open the script (`.gd`) defining the Resource and check the `@export` variables. (e.g., `icon` vs `icon_path`, `display_name_key` vs `display_name`).
*   **Check API Signatures**: Open the file defining the class functions you are calling. Do not guess parameters or return types. (e.g., `bm_add_instance` vs `run_instances`).

### 7.2 Result Object Integrity
*   **Respect Return Types**: If a function returns a Helper Class (e.g., `SummonResult`), **OPEN THAT CLASS** to see what fields it actually has. Do not invent fields like `target_container_tag` if they don't exist.
*   **No Magic Fields**: If you need data passed back, check if the existing structure supports it. If not, modify the structure definitions *first*, then the logic.

### 7.3 Encapsulation Check
*   **Respect Private Members**: If a variable starts with `_` (e.g., `_battle_instances`), do not access it from outside. Look for a public API (e.g., `bm_add_instance`, `get_instance`).
*   **Atomic Operations**: Prefer atomic APIs (`add`, `remove`, `move`) over manual dictionary manipulation.

---

## 8. Agent Verification Protocol (MANDATORY FOR AI)

As an autonomous agent, you are prone to hallucinations regarding file paths and class structures. You MUST strictly adhere to this protocol to prevent errors.

### 8.1 The "Verify Before Creation" Rule
Before creating ANY new resource (`.tres`) or script (`.gd`):
1.  **Check the Reference**: Find an *existing* file of the same type and read it.
    *   *Example*: Before creating `Recipe_Tier2_G.tres`, read `Recipe_Tier1_A.tres`.
    *   *Goal*: Copy the `script_class` and property names exactly.
2.  **Verify Dependencies**: If your new file references a script (e.g., `res://scripts/MergeRecipe.gd`), you **MUST** run `find_by_name` or `ls` to confirm that script exists at that exact path.
3.  **No Assumptions**: Never assume a class name matches a filename. Read the file to see `class_name`.

### 8.2 The "Copy First" Workflow
When implementing content (Units, Items, Recipes, Abilities):
1.  **USE THE WORKFLOW**: Check `.agent/workflows/implement_new_content.md` for the mandatory checklist.
2.  **Search**: Find a similar existing item.
3.  **Read**: `view_file` the existing item.
4.  **Replicate**: Create your new item using the *exact same structure* as the existing one, changing only the values.

> [!CRITICAL]
> **Violation of this protocol allows you to be fired (or reset).**
> If you use property names that don't match the script's `@export` variables, you have failed.

---

## 9. Localization and UI Text Rules

Translations and descriptions in Flashcard Heroes use Godot's `Translation` system (`game.csv`), but the UI scripts apply strict contextual rules on how keys are interpreted and displayed. **Do not assume all translation keys in a Resource must be mapped to `game.csv`.**

### 9.1 The "Hidden Ability" Trick (Trinkets)
When an ability is attached to a Trinket (e.g., `Beginner's Charm`), the Trinket's base description already explains what the ability does mechanically. 
*   To prevent the UI from displaying redundant or duplicate text, the `AbilityDefinition` `.tres` file should intentionally leave its `name_key` and `description_key` empty (`""`).
*   **Agent Rule:** If a script audits for "missing keys" and finds an ability `.tres` with unmapped keys, **check if it is attached to a Trinket**. Do not hastily inject generic descriptions into `game.csv`, as this will cause the UI to display duplicate/incorrect ability blocks.

### 9.2 The Trait Synergy Override (`SOUL_` tags)
Items that grant trait synergies (e.g., `Fire Emblem`) apply the trait to the equipped unit using tags (e.g., `SOUL_FIRE`). 
*   **The Display Override:** If the `ItemInspectionWindow` detects a `SOUL_` tag on an item, it is hardcoded to erase the item's base description and replace it with the **full Trinket Trait description** instead. 
*   **Agent Rule:** If an item description in `game.csv` is not displaying in-game, always check `ItemInspectionWindow.gd` or `UnitInspectionWindow.gd` to verify if a UI override is hijacking the text based on its tags or traits.
