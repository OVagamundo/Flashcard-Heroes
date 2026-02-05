# Suggestions & Analysis: Validated Systems & Content (V8)

**Status:** Code-Validated Proposal  
**Date:** 2026-02-01  
**Constraint Validation:**
*   **Pollution Direction:** Strictly **Enemy -> Player** (Enemies have no "Deck" to pollute).
*   **Durability:** Implemented as a **new field** (`durability`) on Items, distinct from Stats, to allow "High Power / Low Use" designs.
*   **Mini-game Integration:** Triggered at **Turn Start/End** to modify Boss "Action Budget" (avoids mid-combat flow interruption).
*   **Lore:** All units are Gachamon (Elementals, Spirits, Constructs or warrior creatures) or anthropomorphic Animal Heroes. No Humans.

---

## 1. New System Primitives (Codebase Ready)

### 1.1 Trigger: `on_minigame_result`
*   **Hook:** `FlashcardManager.minigame_finished` signal.
*   **Context:** `{"correct_count", "total_questions", "accuracy_percent", "time_taken"}`.
*   **Use Case:** Bosses reading this context to adjust their logic (e.g., "If accuracy < 100%, Boss gains Enrage").

### 1.2 Property: `durability` (Item Use Limit)
*   **Implementation:** Add `max_durability` (Definition) and `current_durability` (Instance).
*   **Logic:**
    *   On `on_attack` / `on_use`, decrement `current_durability`.
    *   If `current_durability <= 0`: Trigger `on_item_destroy` and remove item.
*   **UI:** Show a small counter on the Item Icon.

### 1.3 Effect: `add_junk_to_player_pool`
*   **Target:** `BattleManager.bm_add_instance(junk_uuid, "BattleInventoryTn")`.
*   **Logic:** Inserts "Junk" units directly into the Player's drawable Gacha Pool.
*   **Strategic Impact:** Dilutes player's draws, forcing them to waste tokens rerolling or drawing trash.

### 1.4 Condition: `trait_count_exact`
*   **Logic:** Checks if active trait count `==` specific value (e.g., "Active only at exactly 2 units").
*   **Context:** Allows for small, specific synergies (Duo-Types) vs wide vertical scaling.

---

## 2. Advanced Mechanics

### 2.1 Enemy Archetype: "The Polluter"
*   **Goal:** Slow down the player's scaling by filling their shop with garbage.
*   **Mechanic:**
    *   **Ability:** "At start of turn, add 1 **Rock** (Tier 0, 1/1) to Player's Battle Inventory."
    *   **Result:** Player draws Rocks instead of Tier 3 units.
    *   **Counterplay:** Rush down these enemies first.

### 2.2 Boss Mechanic: "The Examiner"
*   **Goal:** Make the Mini-game matter for survival, not just tokens.
*   **Mechanic:**
    *   **Budget System:** Boss has a "Summon Points" budget.
    *   **Interaction:** Every **Correct Answer** reduces the Boss's Summon Points by 1.
    *   **Failure:** If Player gets < 50% accuracy, Boss casts "Detention" (Stun) on the Hero.

### 2.3 Trade-off Items (Glass Cannons)
*   **Goal:** High risk, high reward.
*   **Example:** "Cursed Blade" offers Tier 3 stats at Tier 1 cost, but applies "Vulnerable" to the holder permanently.

---

## 3. Validated Content Suggestions

### 3.1 Tier 1 Units (Foundations)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Gold-Eater Slime** | Beast | 1/2 | `on_turn_end_unspent`: Gain **+1 HP** per unspent Token. (Greed Tank). |
| **Spark Wisp** | Elemental | 3/1 | `on_attack`: Deal damage, then **Destroy Self**. (Early game nuke). |
| **Pebble Mite** | Construct | 1/1 | **Enemy Only**: `on_death`: Add 2 **Rocks** to Player's Battle Inventory. |
| **Apprentice Sprite** | Spirit | 1/3 | `on_turn_end_bench`: Restore **1 Durability** to a random ally's item. |

### 3.2 Tier 2 Units (Synergy)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Rust Moth** | Beast | 2/4 | **Enemy Only**: `on_attack`: Add 1 **Rust** (-1 PWR Item) to Player's Battle Inventory. |
| **Mirror Golem** | Construct | 2/2 | `on_hurt`: Transform into a base copy of the attacker. |
| **Scrap Walker** | Construct | 2/5 | `on_durability_break`: When ANY item breaks, gain **+2/+2**. |
| **Scholar Owl** | Beast | 2/3 | `on_minigame_result`: Heal lowest HP ally for **(Correct Answers x 2)** HP. |
| **Mud Wretch** | Elemental | 2/2 | `on_healed`: When healed, gain **+2 Armor**. |


### 3.4 Tier 3 Units (Build Enablers)
| Unit Name | Tags | Stats | Ability |
|---|---|---|---|
| **Doppelganger** | Monster | 1/1 | `on_battle_start`: Become a copy of the **Strongest Enemy**. |
| **Void Cat** | Spirit | 3/3 | **Trait**: Active only at **Exact 1 Void Cat**. Effect: "Dodge the first attack." |
| **Forge Spirit** | Elemental | 4/5 | `on_turn_start`: Grant **Infinite Durability** to adjacent allies' items this turn. |
| **Meditating Monk** | Human/Spirit | 2/2 | `on_turn_start_bench`: Gain **+3/+3**. (Bench Scaler). |


---

### 3.4 New Items (Durability & Pollution)

| Name | Type | Stats | Durability | Effect |
|---|---|---|---|---|
| **Glass Dagger** | Weapon | +15 PWR | **1** | Huge burst, breaks immediately. |
| **Whetstone** | Weapon | +6 PWR | **3** | Loses 1 Durability on attack. |
| **Ablative Plate** | Armor | +20 Armor | **5** | Loses 1 Durability when hit. Breaks -> 0 Armor. |
| **Rust** | Junk | -2 PWR | - | **Pollution Item**. Clogs inventory/slots. |
| **Cursed Idol** | Relic | +10 HP | - | `on_turn_start`: Add 1 **Rock** to your own Battle Inventory. (Stats vs Draw). |

---

### 3.5 Consumables
| Name | Effect |
|---|---|
| **Chaos Orb** | Transform target unit into a random unit of the same Tier. (Reroll). |
| **Repair Kit** | Fully restore the **Durability** of target item. |
| **Purify Scroll** | Remove all **Junk** (Rocks/Rust) from your Battle Inventory. |
| **Midas Touch** | Destroy ally unit. Gain Gold equal to **Tier x 3**. |

---

### 3.6 Trinkets
| Name | Effect |
|---|---|
| **Trophy Case** | `on_minigame_result`: If Accuracy is 100%, gain **1 Gold**. |
| **Recycling Bin** | `on_durability_break`: When an item breaks, gain **1 Token**. |
| **Stopwatch** | **Boss Only**: Reduces Player's Flashcard Timer by 50%. |

---

### 3.7 Proposed Recipe Expansions (Brainstorming)
*Filling the elemental gaps and creating High-Tier synergies.*

#### Missing Tier 2 Combinations
| Unit Name | Tags | Recipe | Stats | Ability |
|---|---|---|---|---|
| **Steam Wisp** | Spirit | **Squire (Fire) + Protector (Water)** | 1 HP / 3 PWR | **Scald** (`on_healed`): Deal damage to the front enemy equal to **Heal Amount**. (Offensive Support). |

#### Tier 3 Evolutions
| Unit Name | Tags | Recipe | Stats | Ability |
|---|---|---|---|---|
| **Doppelganger** | Monster | **Mimic + Mimic** | 1 HP / 1 PWR | **Perfect Copy** (`on_battle_start`): Permanently transforms into a copy of the **Strongest Enemy Unit** (Stats + Ability). |
| **Tempest** | Elemental | **Shadow Cloner + Shadow Cloner** | 4 HP / 4 PWR | **Eye of the Storm** (`on_turn_start`): Steal **1 PWR** from **ALL** enemies. |
| **Phoenix** | Beast | **Berserker + Shadow Cloner** | 5 HP / 5 PWR | **Rebirth** (`on_death`): Resurrects once per battle with **50% HP**. |
| **Avalanche** | Construct | **Paladin + Mud Wretch** | 6 HP / 2 PWR | **Permafrost** (`on_hurt`): When damaged, reduce attacker's PWR by **1** (Min 1). |
