# Hero Set: Mercenary (Hero: Shiken)

**Status:** Canonical Design Specification  
**Scope:** Hero (Shiken), Mercenary Trait, 11-Unit Lineage, Item Lineage, Mercenary Emblem, and Supporting Trinkets  
**Companion Master Reference:** [GameContentDocument.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/GameContentDocument.md)

---

## 1. Design Goal & Philosophy

The Mercenary Set is tailored for the Hero **Shiken** (`hero_bounty_hunter`). It is designed around the core fantasy of gold accumulation, high-stakes bounties, and tactical gold spending.

Key pillars:
1. **Gold as Combat Engine:** Gold functions as both a recurring trigger and a spendable resource during battle.
2. **Uncapped Potential:** There is no hard Gold ceiling per turn or battle. Balance comes from discrete 1-Gold generation events and intentional spending costs.
3. **Bounty Hunting:** Marking enemies with Bounty stacks and executing them yields immediate Gold windfalls that trigger the entire Mercenary engine.
4. **Wallet-Scaled Decisions:** Players continually weigh hoarding Gold for passive stat scaling versus spending Gold for powerful combat bursts.

---

## 2. Hero Set Creation Rules & Composition Laws

Every Hero Content Pack adheres to the following structural and balance standards:
1. **Closed 11-Unit Lineage:** Exactly 1 Tier 1, 4 Tier 2 (crossbreeds with the 4 neutral base Tier 1 units), and 6 Tier 3 (the 6 pairings of Tier 2 units).
2. **Strict Single Class Trait Law:** Every unit in the lineage carries the Hero's Class Trait as its sole class trait (no two-class units).
3. **Thematic Counter-Balancing:** Distribute thematic slots across the lineage to counterbalance the 25 Universal Neutral Base Units, ensuring the combined 36-unit active pool maintains equal representation across all 7 thematic traits.
4. **Ranged Unit Requirement:** Every Hero Content Pack must include at least a few Ranged units (2 to 4 units).
5. **Basic Status Effect Coverage:** Every Hero Content Pack must include at least one unit that applies each of the four fundamental combat effects: **Armor**, **Spikes**, **Burn**, and **Static**.
6. **Universal Economic Valuation Law (1 / 2 / 4 Model):**
   * **Gacha Draw Cost (Tokens):** Tier 1 = 1 Token, Tier 2 = 2 Tokens, Tier 3 = 3 Tokens.
   * **Base Shop Gold Cost (`cost`):** Tier 1 = 1 Gold, Tier 2 = 2 Gold, Tier 3 = 4 Gold ($\text{Base Gold Cost} = 2^{\text{Tier} - 1}$).
   * **Level Valuation Multiplier:** Final Gold value doubles at each unit level ($\text{Valuation} = \text{Base Cost} \times 2^{\text{Level} - 1}$).

---

## 3. Hero: Shiken (`hero_bounty_hunter`)

| Field | Specification |
|---|---|
| **Name** | **Shiken** |
| **Hero ID** | `hero_bounty_hunter` |
| **Base Stats** | 10 HP / 2 PWR |
| **Loadout** | Fixed **Mercenary** trait, plus 3 Elemental Souls of one randomly chosen element (all 3 of same element: Fire, Earth, Water, or Air: `?`), and one random Thematic trait. The dynamic element `?` is inherited by Shiken's entire 11-unit lineage for that run. |
| **Innate Combat Passive** | **Bounty:** When this hero knocks out an enemy, earn 1 Gold. |
| **Starter Trinket** | **Mercenary Sigil** (equipped at run start). |

---

## 4. Mercenary Trait Ladder

The Mercenary trait scales based on the number of Mercenary-tagged units in the active lineup. Shiken provides +1 Mercenary counter permanently. Trait levels are cumulative.

| Level | Threshold | Effect |
|---|:---:|---|
| **Bronze** | 2 Mercenaries | Whenever Gold is earned, the allied unit with the lowest current HP gains +1 HP. |
| **Silver** | 3 Mercenaries | In addition to Bronze, whenever Gold is earned, the Hero gains +1 PWR. |
| **Gold** | 4 Mercenaries | In addition to Bronze and Silver, Pre-Battle each Mercenary unit gains 1 Armor for every full 10 Gold currently held. There is no cap. |
| **Prismatic** | 5 Mercenaries | In addition to all previous levels, earn 1 Gold Pre-Battle once per turn. This triggers all effects that respond to Gold earned. |

---

## 5. Unique Unit Lineage (11 Units)

Following the single-class architectural law:
* Every unit in the Mercenary lineage carries **Mercenary** as its sole class trait.
* All units dynamically inherit the Hero's assigned run element (`?`).

### 5.1 Tier 1 Starter Unit (Gacha: 1 Token | Base Shop: 1 Gold)

| ID / Name | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|:---:|:---:|---|
| `?MerSpe` | `?`, Mercenary, Specialist | 1 HP / 1 PWR | Melee | Whenever 1 Gold is earned while this unit is in the active lineup, it gains +1 HP and +1 PWR. |

*Note: Like all units, merging duplicates increases level and adds +1 HP and +1 PWR per level (Level 1: 1 HP / 1 PWR, Level 2: 2 HP / 2 PWR, Level 3: 3 HP / 3 PWR).*

---

### 5.2 Tier 2 Crossbreeds (Gacha: 2 Tokens | Base Shop: 2 Gold)

*The 4 pairings of `?MerSpe` with the 4 Neutral Tier 1 Base Units (`ASpeFod`, `ETnkPla`, `FFigMec`, `WSupAni`).*

| ID / Name | Recipe | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|:---:|---|
| `?ASpeMerFodToy` | `?MerSpe` + `ASpeFod` | `?`, AIR, Specialist, Mercenary, Food, Toy | 2 HP / 3 PWR | Melee | Pre-Battle, gain +1 / +2 / +3 HP for every full 10 Gold currently held. |
| `E?TnkMerPlaToy` | `?MerSpe` + `ETnkPla` | EARTH, `?`, Tank, Mercenary, Plant, Toy | 3 HP / 1 PWR | Melee | Whenever Gold is earned, gain 1 / 2 / 3 Armor and 1 / 2 / 3 Spikes. |
| `F?FigMerMecApp` | `?MerSpe` + `FFigMec` | FIRE, `?`, Fighter, Mercenary, Mecha, Appliance | 2 HP / 3 PWR | Ranged | When attacking, apply 1 stack of Bounty to the target (Level 1: target; Level 2: target and 1 adjacent enemy; Level 3: target and all adjacent enemies). When a marked unit is knocked out, earn 1 Gold per stack. |
| `W?SupMerAniCos` | `?MerSpe` + `WSupAni` | WATER, `?`, Support, Mercenary, Animal, Costume | 3 HP / 2 PWR | Melee | Whenever Gold is earned, heal the ally directly in front for 1 / 2 / 3 HP. |

---

### 5.3 Tier 3 Crossbreeds (Gacha: 3 Tokens | Base Shop: 4 Gold)

*All 6 pairings of the 4 Tier 2 Mercenary Units.*

| ID / Name | Recipe | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|:---:|---|
| `E??ATnkSpeMerFodPlaToy` | `?ASpeMer...` + `E?TnkMer...` | EARTH, 2x `?`, AIR, Tank, Specialist, Mercenary, Food, Plant, Toy | 5 HP / 5 PWR | Melee | Pre-Battle, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to gain 1 / 2 / 3 Armor and Spikes for every full 10 Gold held before the spend. |
| `FW??FigSupMerAniMecAppCos` | `F?FigMer...` + `W?SupMer...` | FIRE, WATER, 2x `?`, Fighter, Support, Mercenary, Animal, Mecha, Appliance, Costume | 5 HP / 5 PWR | Ranged | When attacking, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to deal +1 / +2 / +3 Bonus Damage for every full 10 Gold held before the spend. |
| `W??ASupSpeMerFodAniToyCos` | `?ASpeMer...` + `W?SupMer...` | WATER, 2x `?`, AIR, Support, Specialist, Mercenary, Food, Animal, Toy, Costume | 5 HP / 5 PWR | Melee | Whenever Gold is earned, heal a random allied unit (including the Hero) for 1 / 2 / 3 HP per 1 Gold earned. |
| `F??AFigSpeMerFodMecToyApp` | `?ASpeMer...` + `F?FigMer...` | FIRE, 2x `?`, AIR, Fighter, Specialist, Mercenary, Food, Mecha, Toy, Appliance | 5 HP / 5 PWR | Ranged | When attacking, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to apply 1 / 2 / 3 Burn to the target for every full 10 Gold held before the spend. |
| `EF??TnkFigMerMecPlaToyApp` | `E?TnkMer...` + `F?FigMer...` | EARTH, FIRE, 2x `?`, Tank, Fighter, Mercenary, Mecha, Plant, Toy, Appliance | 5 HP / 5 PWR | Melee | Before taking damage, if holding at least 10 Gold, spend 1 Gold to reduce incoming damage by 1 / 2 / 3 for every full 10 Gold held before the spend (minimum 0 damage). |
| `EW??TnkSupMerAniPlaToyCos` | `E?TnkMer...` + `W?SupMer...` | EARTH, WATER, 2x `?`, Tank, Support, Mercenary, Animal, Plant, Toy, Costume | 5 HP / 5 PWR | Melee | At turn start, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to gain +1 / +2 / +3 HP and +1 / +2 / +3 PWR for every full 10 Gold held before the spend. |

---

## 6. Unique Item Lineage

The item lineage merges the unique Tier 1 item with the neutral Tier 1 base items (`item_t1_a` Candy and `item_t1_b` Wakizashi).

| ID | Item | Tier & Recipe | Stats | Ability Description |
|---|---|---|:---:|---|
| `item_claim_ticket` | **Gold Coin** *(Claim Ticket)* | Unique Tier 1 | +1 HP | When holder is knocked out, earn 1 Gold. |
| `item_interest_ledger` | **Piggy Bank** *(Interest Ledger)* | Tier 2: Gold Coin + `item_t1_a` (Candy) | +2 HP | Whenever 1 Gold is earned, heal holder for 1 HP. |
| `item_loaded_contract` | **Coin Laundry** *(Loaded Contract)* | Tier 2: Gold Coin + `item_t1_b` (Wakizashi) | +2 PWR | Whenever 1 Gold is earned, holder gains +1 PWR. |
| `item_golden_seal` | **Golden Seal** | Tier 3: Piggy Bank + Coin Laundry | +2 HP / +2 PWR | Dynamically grants +1 HP and +1 PWR for every full 10 Gold currently held. Recalculates immediately whenever Gold changes. |
| `item_mercenary_emblem` | **Mercenary Emblem** | Tier 3 Standalone | - | Contributes +1 Mercenary trait counter. Whenever 1 Gold is earned while equipped, holder gains +1 HP and +1 PWR. Works from lineup or shelf. |

---

## 7. Supporting Trinkets

| ID | Trinket | Trigger | Effect Description |
|---|---|:---:|---|
| `trinket_trait_mercenary` | **Mercenary Sigil** | Trait Thresholds | Enables and tracks the Mercenary Trait thresholds (2 / 3 / 4 / 5). |
| `trinket_recruiting_charm` | **Recruiting Charm** | Turn Start | At turn start, if holding at least 1 Gold and a shelf slot is open, spend 1 Gold to summon one Level 1 `?MerSpe` to the shelf. |
| `trinket_wanted_poster` | **Wanted Poster** | Turn Start | At turn start, apply 1 stack of Bounty to a random enemy unit. |

---

## 8. Trait Balancing & Active Run Pool Parity

When Shiken is selected, the active run pool consists of the **25 Universal Base Units** plus the **11 Mercenary Units** (36 units total).

### 8.1 The Multi-Class Architectural Comparison
Under Rule 2 ("Strict Single Class Trait Law"), hero content packs ideally carry only the hero's class trait (`Mercenary`). However, the existing Mercenary lineage carries secondary class tags (`Specialist`, `Tank`, `Fighter`, `Support`) inherited from early design iterations:

* **Model A (Preserving Secondary Classes):**
  * Mercenary units retain their secondary class hooks (`?MerSpe` carries Specialist; crossbreeds carry Tank, Fighter, Support).
  * Active Pool Class Totals (36 Units): **Tank = 10, Fighter = 10, Support = 10, Specialist = 12, Mercenary = 11**.
  * Gives players extensive flexibility to trigger base class synergies alongside Mercenary scaling.
* **Model B (Strict Single-Class Law Alignment):**
  * Mercenary units are cleansed to carry solely `Mercenary` (mirroring Dan's `Novice` lineage).
  * Active Pool Class Totals (36 Units): **Tank = 6, Fighter = 6, Support = 6, Specialist = 7, Mercenary = 11**.
  * Preserves strict single-class architecture where base classes remain scarce and specialized.
