# Flashcard Heroes — Novel Trigger & Mechanic Ideas Catalog

**Status:** Design Ideas & Future Mechanical Expansions Catalog  
**Companion Document:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md)  
**Purpose:** This document records proposed, prospective, and experimental triggers, status mechanics, and building blocks that are **not currently implemented** in the active codebase. Keeping them separated here preserves the architectural truth of the core Action Constitution while giving designers a rich pool of ideas for future content.

---

## 1. Board & Summoning Expansions

While the active game currently implements `[When Ally Summoned]` (`on_ally_summon`) and `[When Enemy Summoned]` (`on_enemy_summon`), several board observer triggers are natural design evolutions:

| Proposed Tag | Proposed Engine Identifier | Intended Mechanic & Design Use Case |
| :--- | :--- | :--- |
| **`[When Any Unit Summoned]`** | `TRIGGER_WHEN_ANY_UNIT_SUMMONED` | Board-wide observer firing whenever *any* token or unit is spawned on either side. Useful for chaotic neutral trinkets or board-scaling passives. |
| **`[When Summoning Fails]`** | `TRIGGER_WHEN_SUMMON_BLOCKED` | Fires when a summon ability attempts to create a minion/token, but all lineup slots are full. Could convert the blocked unit into Armor, Gold, or buffs. |
| **`[When Lineup Shifts]`** | `TRIGGER_WHEN_LINEUP_SHIFTS` | Fires when a unit is forced forward due to a frontally knocked-out ally. Ideal for "Vanguard" rush abilities or push mechanics. |

---

## 2. Granular Status Effect Triggers (Buffs & Debuffs)

Currently, status effects (Armor, Spikes, Burn, Static, Bounty) apply and tick passively. In future expansions, units could directly react to gaining, losing, or suffering from specific Buffs and Debuffs:

### 2.1 Category Triggers
| Proposed Tag | Proposed Engine Identifier | Intended Mechanic & Design Use Case |
| :--- | :--- | :--- |
| **`[When Gaining a Buff]`** | `TRIGGER_ON_BUFF_APPLIED` | Fires whenever any positive status effect (Armor, Spikes, Aegis) is applied to the unit. Does *not* trigger from raw numeric HP heals or equipped item stats. |
| **`[When Inflicted with a Debuff]`** | `TRIGGER_ON_DEBUFF_APPLIED` | Fires whenever an enemy inflicts a negative status effect (Burn, Static, Bounty) on this unit. Could trigger cleansing passives, retaliation, or self-shields. |

### 2.2 Granular Status Life-Cycle Triggers
| Proposed Tag | Proposed Engine Identifier | Intended Mechanic & Design Use Case |
| :--- | :--- | :--- |
| **`[When Armor Breaks]`** | `TRIGGER_WHEN_ARMOR_BREAKS` | Fires at the exact moment a unit's Armor stacks are reduced from $>0$ to $0$ by incoming damage. Ideal for brittle shields, shatter explosions, or desperation attacks. |
| **`[When Burned]`** | `TRIGGER_WHEN_BURNED` | Fires when Burn stacks are applied. Could accelerate burn damage or transfer stacks to adjacent units. |
| **`[When Inflicted with Static]`** | `TRIGGER_WHEN_STATIC_APPLIED` | Fires when Static stacks are applied. Could immediately trigger a mini electrical discharge. |
| **`[When Marked with Bounty]`** | `TRIGGER_WHEN_MARKED_WITH_BOUNTY` | Fires when a unit receives a Bounty mark. Could grant the marked unit temporary panic PWR or damage resistance. |

---

## 3. Flashcard Educational Combat Triggers

Flashcard mini-games are currently evaluated in dedicated mini-game loops (`minigame_start`). If educational answers are tied directly into in-combat abilities, the following triggers would enable direct card-gameplay synergies:

| Proposed Tag | Proposed Engine Identifier | Intended Mechanic & Design Use Case |
| :--- | :--- | :--- |
| **`[On Correct Answer]`** | `TRIGGER_ON_CORRECT_ANSWER` | Fires when the player correctly solves a flashcard prompt. Could empower the hero's next attack with +50% PWR or grant team Armor. |
| **`[On Missed Answer]`** | `TRIGGER_ON_MISSED_ANSWER` | Fires when the player answers incorrectly. Could activate defensive fallback shields or trigger a "learning study guide" bonus. |
| **`[On Answer Streak]`** | `TRIGGER_ON_ANSWER_STREAK` | Fires when the player achieves 3 or 5 consecutive correct answers without mistakes, unlocking a team ultimate attack. |

---

## 4. Resource Threshold & State-Based Triggers

Currently, abilities like Merchant check Gold dynamically via conditions. Future abilities could trigger specifically upon crossing resource boundaries:

| Proposed Tag | Proposed Engine Identifier | Intended Mechanic & Design Use Case |
| :--- | :--- | :--- |
| **`[When Spending Gold]`** | `TRIGGER_WHEN_SPENDING_GOLD` | Fires when Gold is spent in shop re-rolls or upgrades. Rewards aggressive economic velocity. |
| **`[When Bankrupt]`** | `TRIGGER_WHEN_BANKRUPT` | Fires when Gold reaches $0$, granting massive temporary combat PWR to "desperation" units. |
| **`[When Gacha Misses]`** | `TRIGGER_WHEN_GACHA_MISSES` | Fires when a gacha draw produces a Tier 1 common unit, boosting luck tokens for subsequent draws. |

---

## 5. Monster Train 2 Advanced Mechanics Considered for Future Porting

1. **Rally / Synergy Wave:** Triggering when an ally of a specific Trait (e.g. *Toy*, *Element*, *Mercenary*) acts or is summoned.
2. **Siphon / Drain:** Stealing enemy Buff stacks (e.g. absorbing enemy Armor upon hit).
3. **Ascension / Reposition:** Swapping active slot positions mid-combat as an active tactical action.

