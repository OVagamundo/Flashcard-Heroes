# Flashcard Heroes - Code Guidelines & Constitution

> [!IMPORTANT]
> **Status:** MANDATORY
> This document defines the **Law of the Land**. Violating these rules causes desyncs, "ghost units", and impossible-to-debug states.

## 1. The Hybrid Architecture (The Foundation)

Flashcard Heroes uses a **Hybrid Architecture** that strictly separates "Truth" from "Indexing".

### 1.1 The Single Source of Truth
*   **The Instance (`GachaBallInstance`) is King.** It owns the data (HP, PWR, Status).
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
2.  **Never Defensive Code:** Do not use `if is_instance_valid(x): return`. Use `assert(is_instance_valid(x))` and crash. We fail fast to find bugs, we don't hide them.
3.  **Never Modify Core for One Ability:** If you need to change `BattleManager.gd` for a specific trinket, your design is wrong. Use the existing Event/Trigger system.
4.  **Never Mix Logic and Visuals:** If your script imports `Control` or `Sprite2D`, it CANNOT contain combat logic. If your script imports `GachaBallInstance`, it CANNOT contain visual code.

---

## 6. Naming & Style

*   **Variables/Functions:** `snake_case` (e.g., `calculate_damage`)
*   **Classes:** `PascalCase` (e.g., `CombatSimulator`)
*   **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAX_INVENTORY_SLOTS`)
*   **Private Members:** Prefix with `_` (e.g., `_internal_cache`)
*   **Typing:** Static typing is **MANDATORY** for all new code.
    *   `var x: int = 5` (Good)
    *   `var x = 5` (Bad)
    *   `func foo() -> void:` (Good)
