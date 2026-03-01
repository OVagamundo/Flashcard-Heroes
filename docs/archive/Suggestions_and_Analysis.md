# Suggestions & Analysis: Validated Systems & Content (V8)

**Status:** Code-Validated Proposal  
**Date:** 2026-02-01  

This document tracks content ideas and systemic additions that are validated against the current codebase architecture.

---

## 1. Advanced Mechanics

### 1.1 Enemy Archetype: "The Polluter"
*   **Goal:** Slow down the player's scaling by filling their shop with garbage.
*   **Mechanic:**
    *   **Ability:** "At start of turn, add 1 **Rock** (Tier 0, 1/1) to Player's Battle Inventory."
    *   **Result:** Player draws Rocks instead of Tier 3 units.
    *   **Counterplay:** Rush down these enemies first.

### 1.2 Boss Mechanic: "The Examiner"
*   **Goal:** Make the Mini-game matter for survival, not just tokens.
*   **Mechanic:**
    *   **Budget System:** Boss has a "Summon Points" budget.
    *   **Interaction:** Every **Correct Answer** reduces the Boss's Summon Points by 1.
    *   **Failure:** If Player gets < 50% accuracy, Boss casts "Detention" (Stun) on the Hero.

### 1.3 Trade-off Items (Glass Cannons)
*   **Goal:** High risk, high reward.
*   **Example:** "Cursed Blade" offers Tier 3 stats at Tier 1 cost, but applies "Vulnerable" to the holder permanently.

---

## 2. Validated Content Suggestions

### 2.1 Tier 1 Units (Foundations)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Gold-Eater Slime** | Beast | 1/2 | `on_turn_end_unspent`: Gain **+1 HP** per unspent Token. (Greed Tank). |
| **Spark Wisp** | Elemental | 3/1 | `on_attack`: Deal damage, then **Destroy Self**. (Early game nuke). |
| **Pebble Mite** | Construct | 1/1 | **Enemy Only**: `on_death`: Add 2 **Rocks** to Player's Battle Inventory. |
| **Apprentice Sprite** | Spirit | 1/3 | `on_turn_end_bench`: Restore **1 Durability** to a random ally's item. |

### 2.2 Tier 2 Units (Synergy)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Rust Moth** | Beast | 2/4 | **Enemy Only**: `on_attack`: Add 1 **Rust** (-1 PWR Item) to Player's Battle Inventory. |
| **Scrap Walker** | Construct | 2/5 | `on_durability_break`: When ANY item breaks, gain **+2/+2**. |
| **Scholar Owl** | Beast | 2/3 | `on_minigame_result`: Heal lowest HP ally for **(Correct Answers x 2)** HP. |
| **Steam Wisp** | Spirit | 1/3 | **Scald** (`on_healed`): Deal damage to the front enemy equal to **Heal Amount**. (Offensive Support). |

### 2.3 Tier 3 Units (Build Enablers)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Doppelganger** | Monster | 1/1 | `on_battle_start`: Permanently transforms into a copy of the **Strongest Enemy Unit** (Stats + Ability). |
| **Tempest** | Elemental | 4/4 | **Eye of the Storm** (`on_turn_start`): Steal **1 PWR** from **ALL** enemies. |
| **Phoenix** | Beast | 5/5 | **Rebirth** (`on_death`): Resurrects once per battle with **50% HP**. |
| **Avalanche** | Construct | 6/2 | **Permafrost** (`on_hurt`): When damaged, reduce attacker's PWR by **1** (Min 1). |

---

### 2.4 New Items & Consumables

| Name | Type | Effect |
|---|---|---|
| **Chaos Orb** | Consumable | Transform target unit into a random unit of the same Tier. (Reroll). |
| **Midas Touch** | Consumable | Destroy ally unit. Gain Gold equal to **Tier x 3**. |
| **Separation Potion** | Consumable | **Unmerge**: Splits a merged unit back into its component parts (if space allows). Retains learned traits. |

---

### 2.5 Trinkets
| Name | Effect |
|---|---|
| **Trophy Case** | `on_minigame_result`: If Accuracy is 100%, gain **1 Gold**. |
| **Stopwatch** | **Boss Only**: Reduces Player's Flashcard Timer by 50%. |
