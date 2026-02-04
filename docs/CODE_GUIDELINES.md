# Flashcard Heroes - Code Guidelines & Constitution

> [!IMPORTANT]
> **Status:** MANDATORY
> This document defines the **Law of the Land**. Violating these rules causes desyncs, "ghost units", and impossible-to-debug states.

## 1. The Hybrid Architecture (The Foundation)

Flashcard Heroes uses a **Hybrid Architecture** that strictly separates "Truth" from "Indexing".

### 1.1 The Single Source of Truth
*   **The Instance (`GachaBallInstance`) is King.** It owns the data.
    *   **Stats** (HP, PWR) are direct member variables.
    *   **Status Effects** (Burn, Spikes, Armor) are stored in the `status_effects` dictionary.
*   **The Container (`Inventory`, `Lineup`) is just a List.** It only holds UUIDs. It *never* owns data.
*   **No Caching:** Never cache properties like `current_hp` in localized variables for longer than a single function scope. Always query the instance.

### 1.2 The Atomic Transaction
Any operation that moves an instance (Equip, Move, Swap) **MUST** update both the Truth and the Index in a single, atomic transaction.
*   **Incorrect:** Removing from `Inventory A` then adding to `Inventory B` manually.
*   **Correct:** using `InventoryOperations.move_item(uuid, from_loc, to_loc)`.

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

### 2.2 The Zero-Mutation Rule (`is_simulation`)
Every ability/effect receives an `is_simulation` flag.
*   **If `true`:** You **MUST** return an `EffectResult` describing what *would* happen. You **CANNOT** change `current_hp` or any other state.
*   **If `false`:** You may mutate state directly.

### 2.3 The Context Contract
Abilities are isolated functions. They know **only** what is passed in their `context` dictionary.
*   ❌ **NEVER** query `BattleManager` for global state (e.g., "get all enemies").
*   ✅ **ALWAYS** use `context` keys (`target_uuid`, `source_uuid`, `turn_number`).

---

## 3. The Presentation Layer (The Puppet)

This layer includes `BattleView`, `BattleAnimator`, and `GachaBallView`.

### 3.1 The VCR Pattern
Combat is a pre-recorded movie.
1.  **Simulation** runs instantly at Turn Start → generates `TurnLog`.
2.  **Presentation** plays the `TurnLog` like a VCR tape.
*   **Implication:** The UI is physically incapable of changing the game outcome. It is a dumb terminal.

### 3.2 The Snapshot Rule
During the `COMBAT` phase, the UI must **NEVER** query the live `GachaBallInstance`.
*   **Why?** The live instance is already at the "End of Turn" state (damaged/dead).
*   **How:** The UI uses a **Visual Snapshot** captured before the turn started.
*   ❌ **Banned in UI:** `BattleManager.get_instance(id)`
*   ✅ **Allowed:** `_visual_snapshot[id]`

### 3.3 The Puppet Mode (Orchestration)
During complex animation sequences (like a potion usage with multiple effects), the Data Model ("Truth") updates instantly, but visuals must play sequentially.
*   **Silence the Index:** The Manager actively blocks global UI refreshes (`set_processing_effect(true)`) during the sequence.
*   **Guard the Puppet:** The View actively ignores "loud" signals (`unit_stat_changed`) if the Manager is in Puppet Mode.
*   **Tween, Don't Snap:** Visual updates must *always* tween from the current visual value, not snap to the new data value.
*   **Static vs. Dynamic:** `populate()` and `update_visuals()` are **STATIC** operations and must explicit disable animation (`animate=false`). Events are **DYNAMIC** and explicit enable animation.

---

## 4. Ability & Trinket Standards

### 4.1 Priority Is Law
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
> If you create a resource pointing to a non-existent script, you have failed.
> If you use property names that don't match the script's `@export` variables, you have failed.
