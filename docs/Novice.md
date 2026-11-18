# Hero Set: Novice (Hero: Dan)

**Status:** Canonical Design Specification  
**Scope:** Hero (Dan), Novice Trait, 11-Unit Lineage, Item Lineage, Novice Emblem, and Supporting Trinkets  
**Companion Master Reference:** [GameContentDocument.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/GameContentDocument.md)

---

## 1. Design Goal & Philosophy

The Novice Set is tailored for the starting Hero, **Dan**, designed specifically to welcome newcomers and support players tackling new, difficult, or unfamiliar flashcard decks.

Key pillars:
1. **Time-as-Power:** Extra study time is an economic multiplier. Seconds granted on correct answers or on unit death convert directly into answering more cards, earning more tokens, and strengthening the lineup.
2. **Organic Learning Incentives:** Combat power flows from good study habits: reviewing Mastery Level 1 (Very Hard / Red) cards, maintaining 3-streaks, and knowing when to Skip rather than guess blindly.
3. **Forgiving Safety Net:** The starter **Novice Crest** trinket guarantees a baseline of at least 3 Tokens from every study challenge, inside and outside battle.
4. **Token Tension at Tier 3:** High-tier Novice units gain scaling combat benefits from holding tokens into battle, creating tactical decisions during Management: spend tokens on gacha draws or hold them for battle boosts.

---

## 2. Hero Set Creation Rules & Composition Laws

Every Hero Content Pack adheres to the following structural and balance standards:
1. **Closed 11-Unit Lineage:** Exactly 1 Tier 1, 4 Tier 2 (crossbreeds with the 4 neutral base Tier 1 units), and 6 Tier 3 (the 6 pairings of Tier 2 units).
2. **Strict Single Class Trait Law:** Every unit in the lineage carries the Hero's Class Trait as its sole class trait (no two-class units).
3. **Thematic Counter-Balancing:** Distribute the 11 thematic slots across the lineage to counterbalance the 25 Universal Neutral Base Units, ensuring the combined 36-unit active pool maintains equal representation across all 7 thematic traits.
4. **Ranged Unit Requirement:** Every Hero Content Pack must include at least a few Ranged units (2 to 4 units).
5. **Basic Status Effect Coverage:** Every Hero Content Pack must include at least one unit that applies each of the four fundamental combat effects: **Armor**, **Spikes**, **Burn**, and **Static**.
6. **Universal Economic Valuation Law (1 / 2 / 4 Model):**
   * **Gacha Draw Cost (Tokens):** Tier 1 = 1 Token, Tier 2 = 2 Tokens, Tier 3 = 3 Tokens.
   * **Base Shop Gold Cost (`cost`):** Tier 1 = 1 Gold, Tier 2 = 2 Gold, Tier 3 = 4 Gold ($\text{Base Gold Cost} = 2^{\text{Tier} - 1}$).
   * **Level Valuation Multiplier:** Final Gold value doubles at each unit level ($\text{Valuation} = \text{Base Cost} \times 2^{\text{Level} - 1}$).

---

## 3. Hero: Dan (`hero_starter`)

| Field | Specification |
|---|---|
| **Name** | **Dan** |
| **Hero ID** | `hero_starter` |
| **Unlock** | Starting Hero, available from the very beginning. |
| **Base Stats** | 10 HP / 2 PWR |
| **Loadout** | Fixed **Novice** trait, plus 3 Elemental Souls of one randomly chosen element (all 3 of same element: Fire, Earth, Water, or Air: `?`), and one random Thematic trait. The dynamic element `?` is inherited by Dan's entire 11-unit lineage for that run. |
| **Innate Combat Passive** | **Soul Harvest:** When an allied unit is knocked out, Dan gains HP equal to that ally's PWR (`resources/abilities/HeroStarter_AllyDeathAbsorb.tres`). |
| **Starter Trinket** | **Novice Crest** (equipped at run start). |

---

## 4. Novice Trait Ladder

The Novice trait scales based on the number of Novice-tagged units in the active lineup. Dan provides +1 Novice counter permanently. Trait levels are cumulative.

| Level | Threshold | Effect |
|---|:---:|---|
| **Bronze** | 2 Novices | Add **+1.0 second** to the starting time of each battle challenge. |
| **Silver** | 3 Novices | In addition to Bronze, achieving a **3-correct-answer streak grants 1 bonus Gold** (once per challenge session, maximum 5 Gold per encounter). |
| **Gold** | 4 Novices | In addition to Silver, a correct answer to a card at **Mastery Level 1 (Very Hard)** grants **1 bonus Token**. |
| **Prismatic** | 5 Novices | In addition to all previous levels: Each incorrect submitted answer adds **+0.5s** to the remaining time (panic buffer; does not apply to Skips). Achieving a **3-correct-answer streak grants +1 bonus Token** (once per challenge session). |

### Mechanics & Event Resolution Rules
* **Correct-Answer vs. Generic Tokens:** Buffs requiring correct answers trigger strictly on answer submission events. Token guarantees, death refunds, or trinket payouts do not trigger answer-based buffs.
* **Pre-Answer Mastery Check:** Low-mastery triggers evaluate the card's mastery level *before* recording the correct answer.
* **Skip vs. Incorrect Outcomes:** An incorrect answer resets the streak. A Skip preserves the streak. Gold's Mastery 1 token bonus applies only to correct answers. Prismatic's +0.5s panic buffer applies only to incorrect submissions, whereas Silver's +1.0s applies strictly to Skips.

---

## 5. Unique Unit Lineage (11 Units)

Following the single-class architectural law:
* Every unit in the Novice lineage carries **Novice** as its sole class trait.
* Every unit carries exactly **1 Thematic Trait** chosen to balance the 25 base units.
* All units dynamically inherit the Hero's assigned run element (`?`).

### 5.1 Tier 1 Starter Unit (Gacha: 1 Token | Base Shop: 1 Gold)

| ID / Name | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|:---:|:---:|---|
| `?NovPla` | `?`, Novice, Plant | 1 HP / 1 PWR | Ranged | When knocked out, add 1 / 2 / 3 seconds to the starting time of the next battle challenge. This effect stacks. |

*Note: Like all units, merging duplicates increases level and adds +1 HP and +1 PWR per level (Level 1: 1 HP / 1 PWR, Level 2: 2 HP / 2 PWR, Level 3: 3 HP / 3 PWR).*

---

### 5.2 Tier 2 Crossbreeds (Gacha: 2 Tokens | Base Shop: 2 Gold)

*The 4 pairings of `?NovPla` with the 4 Neutral Tier 1 Base Units (`ASpeFod`, `ETnkPla`, `FFigMec`, `WSupAni`).*

| ID / Name | Recipe | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|:---:|---|
| `?ANovFod` | `?NovPla` + `ASpeFod` | `?`, AIR, Novice, Food | 2 HP / 3 PWR | Ranged | Pre-Battle, Charge an Empowered Attack that inflicts 1 / 2 / 3 Static on the target for every 2 Current Tokens held. |
| `E?NovPla` | `?NovPla` + `ETnkPla` | EARTH, `?`, Novice, Plant | 3 HP / 2 PWR | Melee | Pre-Battle, gain 1 / 2 / 3 Armor for every 2 Current Tokens held. |
| `F?NovApp` | `?NovPla` + `FFigMec` | FIRE, `?`, Novice, Appliance | 2 HP / 3 PWR | Melee | Pre-Battle, Charge an Empowered Attack that applies 1 / 2 / 3 Burn to the target for every 2 Current Tokens held. |
| `W?NovCos` | `?NovPla` + `WSupAni` | WATER, `?`, Novice, Costume | 2 HP / 3 PWR | Melee | When hurt by an attack, heal self for 1 / 2 / 3 HP for every 2 Current Tokens held. |

---

### 5.3 Tier 3 Crossbreeds (Gacha: 3 Tokens | Base Shop: 4 Gold)

*All 6 pairings of the 4 Tier 2 Novice Units.*

| ID / Name | Recipe | Tags | Stats | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|:---:|---|
| `E??ANovPla` | `?ANovFod` + `E?NovPla` | EARTH, 2x `?`, AIR, Novice, Plant | 5 HP / 5 PWR | Melee | Pre-Battle, spend 1 Token to gain 1 / 2 / 3 Armor for each Current Token held and 1 / 2 / 3 Spikes for every 2 Current Tokens held before the spend. |
| `F??ANovFod` | `?ANovFod` + `F?NovApp` | FIRE, 2x `?`, AIR, Novice, Food | 5 HP / 5 PWR | Melee | When attacking, spend 1 Token to inflict 1 / 2 / 3 Static on the target per Current Token held before the spend. |
| `W??ANovCos` | `?ANovFod` + `W?NovCos` | WATER, 2x `?`, AIR, Novice, Costume | 5 HP / 5 PWR | Melee | When hurt by an attack, spend 1 Token to heal self for 1 / 2 / 3 HP for each Current Token held before the spend. (Can activate multiple times if tokens available). |
| `EF??NovApp` | `E?NovPla` + `F?NovApp` | EARTH, FIRE, 2x `?`, Novice, Appliance | 5 HP / 5 PWR | Ranged | When attacking, spend 1 Token to Charge an Empowered Attack that applies 1 / 2 / 3 Burn to the target per Current Token held before the spend. |
| `EW??NovPla` | `E?NovPla` + `W?NovCos` | EARTH, WATER, 2x `?`, Novice, Plant | 5 HP / 5 PWR | Ranged | When attacking, spend 1 Token to deal 1 / 2 / 3 Bonus Damage per Current Token held before the spend. |
| `FW??NovAni` | `F?NovApp` + `W?NovCos` | FIRE, WATER, 2x `?`, Novice, Animal | 5 HP / 5 PWR | Ranged | When knocked out, add 1 / 2 / 3 seconds to the starting time of the next battle challenge and gain Tokens equal to this unit's level (1 / 2 / 3 Tokens). |

---

## 6. Unique Item Lineage

The item lineage merges the unique Tier 1 item with the neutral Tier 1 base items (`item_t1_a` Candy and `item_t1_b` Wakizashi).

| ID | Item | Tier & Recipe | Stats | Ability Description |
|---|---|---|:---:|---|
| `item_study_pouch` | **Token** | Unique Tier 1 | +1 HP | When holder is knocked out, gain Tokens equal to holder's Tier (1 / 2 / 3 Tokens). |
| `item_review_ledger` | **Nail** | Tier 2: Token + `item_t1_a` (Candy) | +2 HP | Pre-Battle, while equipped in the active lineup, holder gains 1 / 2 / 3 Spikes for each Current Token held. |
| `item_answer_key` | **Burnout** | Tier 2: Token + `item_t1_b` (Wakizashi) | +2 PWR | When attacking, while equipped in the active lineup, apply 1 / 2 / 3 Burn to the target for each Current Token held. |
| `item_novice_archive` | **Novice's Archive** | Tier 3: Nail + Burnout | +2 HP / +2 PWR | When attacking, spend 1 Token to deal 1 / 2 / 3 Bonus Damage for each Current Token held before the spend. |
| `item_novice_emblem` | **Novice Emblem** | Tier 3 Standalone | - | Contributes +1 Novice trait counter while in active lineup. For each enemy unit knocked out by holder in battle, add 1 second to the starting time of the next battle challenge. |

---

## 7. Supporting Trinkets

| ID | Trinket | Trigger | Effect Description |
|---|---|:---:|---|
| `trinket_trait_novice` | **Novice Crest** | Trait Thresholds | Enables and tracks the Novice Trait thresholds (2 / 3 / 4 / 5). Guarantees at least 3 Tokens from every token-awarding challenge session (inside and outside battle). |
| `trinket_study_hall_bell` | **Study Hall Bell** | Turn Start | At turn start, if available, spend 1 Token to summon a Level 1 `?NovPla` into the first open lineup slot (or shelf if full). Battle-only summon. |
| `trinket_beginners_charm` | **Beginner's Charm** | Challenge | Gain 1 extra Token if the answered flashcard is Mastery Level 1 (Very Hard). Synergizes directly with Gold Novice. |

---

## 8. Trait Balancing & Active Run Pool Parity

When Dan is selected, the active run pool consists of the **25 Universal Base Units** plus the **11 Novice Units** (36 units total):

| Thematic Trait | Universal Base Units | Novice Pack Units | Combined Active Pool (36 Units) |
|---|:---:|:---:|:---:|
| **Plant** | 2 | **+3** (`?NovPla`, `E?NovPla`, `E??ANovPla`, `EW??NovPla`) | **5** |
| **Food** | 4 | **+2** (`?ANovFod`, `F??ANovFod`) | **6** |
| **Animal** | 3 | **+1** (`FW??NovAni`) | **4** |
| **Costume** | 3 | **+2** (`W?NovCos`, `W??ANovCos`) | **5** |
| **Appliance** | 4 | **+2** (`F?NovApp`, `EF??NovApp`) | **6** |
| **Toy** | 4 | **+0** | **4** |
| **Mecha** | 5 | **+0** | **5** |
| **Total Thematics** | **25** | **11** | **36** |

* Every single unit in the 36-unit pool carries **exactly 1 class trait and 1 thematic trait**.
* Every thematic trait in the active run pool sits comfortably between **4 and 6 units**, maintaining near-perfect distribution across all 7 archetypes.
