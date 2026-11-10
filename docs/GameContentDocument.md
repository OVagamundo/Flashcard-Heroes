# Game Content Document

*Comprehensive design specification and master reference for all Universal Base Content (Units, Items, Trinkets), Hero Sets (Shiken, Dan), Heroes, Enemies, Positive & Negative Effects, Battlefield Slots, and Trait Balancing Architecture.*

---

## Architecture: Closed Run Pool & Content Sets

*Flashcard Heroes* operates on a closed **36-unit active run pool** consisting of:
1. **The Universal Neutral Base Set (25 Units):** Permanently present in all runs regardless of hero choice (4 Tier 1 + 6 Tier 2 + 15 Tier 3).
2. **One Active Hero Content Pack (11 Units):** The chosen Hero injects their dedicated, closed lineage (1 Tier 1 + 4 Tier 2 + 6 Tier 3), alongside their set-specific items and trinkets.

> **Golden Law of Trait Balancing:** When authoring or balancing any Hero Content Pack, **only the Universal Neutral Base Set is accounted for**. Packs never balance against each other because only one Hero Content Pack is ever active in a run.

---

## 1. Universal Neutral Base Units (25 Units)

Every neutral base unit adheres to the strict architectural rule:
$$\text{\{Elemental Souls\}} + \text{\{Exactly 1 Class Trait\}} + \text{\{Exactly 1 Thematic Trait\}}$$

### 1.1 Tier 1 Base Units (Gacha: 1 Token | Base Shop: 1 Gold)

| ID | Name | Stats | Tags | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|:---:|---|:---:|---|
| `ETnkPla` | **Stumpling** | 2 HP / 1 PWR | EARTH, Tank, Plant | Melee | When hurt by an attack, heal this unit for 1 / 2 / 3 HP. |
| `FFigMec` | **Vulcannon** | 1 HP / 2 PWR | FIRE, Fighter, Mecha | Ranged | When hurt by an attack, executes a Reactive Attack shooting a projectile at the attacker dealing damage equal to PWR (triggers even if knocked out). Bounces to 0 / 1 / 2 extra targets for 50% damage per Bounce. |
| `WSupAni` | **Ripplepup** | 1 HP / 1 PWR | WATER, Support, Animal | Melee | When the ally directly in front takes damage, heal them for 1 / 2 / 3 HP. |
| `ASpeFod` | **Puffcorn** | 1 HP / 1 PWR | AIR, Specialist, Food | Ranged | When knocked out, grant current PWR to the ally behind (Level 2: also grant 50% to the second ally behind; Level 3: also grant 25% to the third ally behind). |

---

### 1.2 Tier 2 Base Units (Gacha: 2 Tokens | Base Shop: 2 Gold)

*The 6 pairings of the 4 Tier 1 Base Units.*

| ID | Name | Recipe | Stats | Tags | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|---|:---:|---|
| `EWFigCos` | **Bogmantle** | `ETnkPla` + `WSupAni` | 3 HP / 3 PWR | EARTH, WATER, Fighter, Costume | Melee | When an ally is knocked out, gain +1 / +2 / +2 HP and +1 / +1 / +2 PWR. |
| `FASpeApp` | **Furnair** | `FFigMec` + `ASpeFod` | 2 HP / 3 PWR | FIRE, AIR, Specialist, Appliance | Melee | Gains bonus PWR equal to 100% / 150% / 200% of current Tokens held, updating whenever current Tokens change. |
| `EASupToy` | **Matryodust** | `ETnkPla` + `ASpeFod` | 3 HP / 2 PWR | EARTH, AIR, Support, Toy | Melee | When knocked out, summon a random Tier 1 unit with level equal to this unit's level (Level 1 / 2 / 3). |
| `WATnkAni` | **Soliwhale** | `WSupAni` + `ASpeFod` | 2 HP / 2 PWR | WATER, AIR, Tank, Animal | Melee | Pre-Battle, gain +1 / +2 / +3 HP and +1 / +2 / +3 PWR for each empty slot on your team. |
| `EFTnkMec` | **Branblee** | `ETnkPla` + `FFigMec` | 3 HP / 2 PWR | EARTH, FIRE, Tank, Mecha | Melee | When healed, gain 1 / 2 / 3 Armor and 1 / 2 / 3 Spikes. |
| `FWFigFod` | **Pepspray** | `FFigMec` + `WSupAni` | 2 HP / 3 PWR | FIRE, WATER, Fighter, Food | Melee | When healed, shoots a Fireball at a random enemy that applies Burn stacks equal to the heal amount. Bounces to 0 / 1 / 2 extra targets, halving stacks per Bounce. |

---

### 1.3 Tier 3 Base Units (Gacha: 3 Tokens | Base Shop: 4 Gold)

*The 15 pairings of the 6 Tier 2 Base Units.*

| ID | Name | Recipe | Stats | Tags | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|---|:---:|---|
| `EEFASpeCos` | **Mimicloak** | `EFTnkMec` + `EASupToy` | 6 HP / 4 PWR | 2x EARTH, FIRE, AIR, Specialist, Costume | Melee | At turn start, transforms into a Level 1 / 2 / 3 version of the enemy unit in the mirror slot and immediately takes its turn. If there is no unit in the mirror slot, performs a Melee Attack instead. |
| `EEFWSupPla` | **Oakbark** | `EWFigCos` + `EFTnkMec` | 6 HP / 5 PWR | 2x EARTH, FIRE, WATER, Support, Plant | Melee | When hurt by an attack, grant +1/+1 (Level 1), +2/+1 (Level 2), +2/+2 (Level 3) HP/PWR to adjacent allies. If there is no adjacent ally in front or behind, grant the buff to itself. |
| `EEWAFigAni` | **Griffoam** | `EWFigCos` + `EASupToy` | 6 HP / 5 PWR | 2x EARTH, WATER, AIR, Fighter, Animal | Melee | While in the active lineup, deals 1 / 2 / 3 damage as a ranged attack to any unit when they enter the lineup by any means (move from bench, summon, spawn after merge, or transform). |
| `EFAASupToy` | **Matryoshkan** | `EASupToy` + `FASpeApp` | 5 HP / 5 PWR | EARTH, FIRE, 2x AIR, Support, Toy | Melee | When knocked out, summon a Level 1 / 2 / 3 Tier 2 unit (`Matryodust`). |
| `EFFASupMec` | **Mechamom** | `EFTnkMec` + `FASpeApp` | 5 HP / 5 PWR | EARTH, 2x FIRE, AIR, Support, Mecha | Melee | Newly summoned allies gain +3 / +5 / +7 HP upon entering the board. |
| `EFFWSpeApp` | **Blendroid** | `EFTnkMec` + `FWFigFod` | 5 HP / 5 PWR | EARTH, 2x FIRE, WATER, Specialist, Appliance | Melee | Whenever a merge occurs on the battle board, gain +2 / +3 / +4 HP and PWR. |
| `EFWAFigMec` | **Pachinkannon** | `EASupToy` + `FWFigFod` | 5 HP / 5 PWR | EARTH, FIRE, WATER, AIR, Fighter, Mecha | Ranged | Ranged attacks Bounce 1 / 2 / 3 times to random enemies, halving damage per Bounce. |
| `EFWASpeFod` | **BubbleGunger** | `EFTnkMec` + `WATnkAni` | 5 HP / 4 PWR | EARTH, FIRE, WATER, AIR, Specialist, Food | Melee | Gains +3 / +4 / +5 PWR for each other BubbleGunger in battle. When knocked out, add 1 copy of this unit into the Gacha Machine. |
| `EFWATnkApp` | **Reizokun** | `EWFigCos` + `FASpeApp` | 5 HP / 6 PWR | EARTH, FIRE, WATER, AIR, Tank, Appliance | Melee | Before taking damage, gain +2 / +4 / +6 HP. |
| `EFWWFigCos` | **Tsunamantle** | `EWFigCos` + `FWFigFod` | 5 HP / 6 PWR | EARTH, FIRE, 2x WATER, Fighter, Costume | Melee | Instead of attacking, deals 100% / 150% / 200% PWR damage as a cascade attack to the frontmost enemy, spilling backward into enemies behind. |
| `EWAASpeApp` | **Sojikun** | `EASupToy` + `WATnkAni` | 5 HP / 4 PWR | EARTH, WATER, 2x AIR, Specialist, Appliance | Ranged | At turn start, cleanse 1 / 2 / 3 negative effect stacks from adjacent allies. When attacking, cleanse and remove all positive effect stacks (Armor, Spikes, Reinforce) from the target. |
| `EWWATnkToy` | **Komatop** | `EWFigCos` + `WATnkAni` | 5 HP / 5 PWR | EARTH, 2x WATER, AIR, Tank, Toy | Melee | Leaps to intercept lethal damage targeting allies, taking the blow instead. Gains 0 / 1 / 2 Armor when intercepting. |
| `FFWASupMec` | **Relaytron** | `FWFigFod` + `FASpeApp` | 5 HP / 5 PWR | 2x FIRE, WATER, AIR, Support, Mecha | Melee | When knocked out, Transfer equipped item to the ally directly behind (Level 2: also duplicate 1 copy to the next ally behind; Level 3: duplicate 2 copies to next allies behind). |
| `FWAASpeToy` | **Wind-up-kun** | `FASpeApp` + `WATnkAni` | 4 HP / 5 PWR | FIRE, WATER, 2x AIR, Specialist, Toy | Melee | At turn start, if placed on the bench, gain +3 / +5 / +7 HP and PWR. |
| `FWWATnkFod` | **Nuton** | `FWFigFod` + `WATnkAni` | 4 HP / 5 PWR | FIRE, 2x WATER, AIR, Tank, Food | Melee | Whenever an adjacent ally receives a stat buff, Copy Buff at 100% / 150% / 200% effectiveness. |

---

## 2. Hero Content Packs

### 2.0 Hero Set Creation Rules & Composition Laws
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

### 2.1 Hero Set: Mercenary (Hero: Shiken)
* **Associated Hero:** Shiken (`hero_bounty_hunter`)
* **Core Mechanic:** Gold Generation, Bounty Marking, and Scaled Gold-Spending.
* **Lineage Element:** The Hero inherits 3 souls of a random element (`?`); all 11 Mercenary lineage units dynamically inherit that element.
* **Design Pillars:**
  1. **Gold as Combat Engine:** Gold functions as both a recurring trigger and a spendable resource during battle.
  2. **Uncapped Potential:** There is no hard Gold ceiling per turn or battle. Balance comes from discrete 1-Gold generation events and intentional spending costs.
  3. **Bounty Hunting:** Marking enemies with Bounty stacks and executing them yields immediate Gold windfalls that trigger the entire Mercenary engine.
  4. **Wallet-Scaled Decisions:** Players continually weigh hoarding Gold for passive stat scaling versus spending Gold for powerful combat bursts.

#### Mercenary Trait Ladder

The Mercenary trait scales based on the number of Mercenary-tagged units in the active lineup. Shiken provides +1 Mercenary counter permanently. Trait levels are cumulative.

| Level | Threshold | Effect |
|---|:---:|---|
| **Bronze** | 2 Mercenaries | Whenever Gold is earned, the allied unit with the lowest current HP gains +1 HP. |
| **Silver** | 3 Mercenaries | In addition to Bronze, whenever Gold is earned, the Hero gains +1 PWR. |
| **Gold** | 4 Mercenaries | In addition to Bronze and Silver, Pre-Battle each Mercenary unit gains 1 Armor for every full 10 Gold currently held. There is no cap. |
| **Prismatic** | 5 Mercenaries | In addition to all previous levels, earn 1 Gold Pre-Battle once per turn. This triggers all effects that respond to Gold earned. |

#### Mercenary Units (11 Units)

| Tier | ID | Name | Recipe | Stats | Tags | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|---|:---:|---|:---:|---|
| **T1** | `?MerSpe` | **Coinling** | Starter | 1 HP / 1 PWR | `?`, Mercenary, Specialist | Melee | Whenever 1 Gold is earned while this unit is in the active lineup, it gains +1 HP and +1 PWR. |
| **T2** | `?ASpeMerFodToy` | **Doughpuff** | `?MerSpe` + `ASpeFod` | 2 HP / 3 PWR | `?`, AIR, Specialist, Mercenary, Food, Toy | Melee | Pre-Battle, gain +1 / +2 / +3 HP for every full 10 Gold currently held. |
| **T2** | `E?TnkMerPlaToy` | **Vaultbark** | `?MerSpe` + `ETnkPla` | 3 HP / 1 PWR | EARTH, `?`, Tank, Mercenary, Plant, Toy | Melee | Whenever Gold is earned, gain 1 / 2 / 3 Armor and 1 / 2 / 3 Spikes. |
| **T2** | `F?FigMerMecApp` | **Cashcannon** | `?MerSpe` + `FFigMec` | 2 HP / 3 PWR | FIRE, `?`, Fighter, Mercenary, Mecha, Appliance | Ranged | When attacking, apply 1 stack of Bounty to the target (Level 1: target; Level 2: target and 1 adjacent enemy; Level 3: target and all adjacent enemies). When a marked unit is knocked out, earn 1 Gold per stack. |
| **T2** | `W?SupMerAniCos` | **Pennypaw** | `?MerSpe` + `WSupAni` | 3 HP / 2 PWR | WATER, `?`, Support, Mercenary, Animal, Costume | Melee | Whenever Gold is earned, heal the ally directly in front for 1 / 2 / 3 HP. |
| **T3** | `E??ATnkSpeMerFodPlaToy` | **Bullionbark** | `?ASpeMer...` + `E?TnkMer...` | 5 HP / 5 PWR | EARTH, 2x `?`, AIR, Tank, Specialist, Mercenary, Food, Plant, Toy | Melee | Pre-Battle, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to gain 1 / 2 / 3 Armor and Spikes for every full 10 Gold held before the spend. |
| **T3** | `FW??FigSupMerAniMecAppCos` | **Jackpotron** | `F?FigMer...` + `W?SupMer...` | 5 HP / 5 PWR | FIRE, WATER, 2x `?`, Fighter, Support, Mercenary, Animal, Mecha, Appliance, Costume | Ranged | When attacking, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to deal +1 / +2 / +3 Bonus Damage for every full 10 Gold held before the spend. |
| **T3** | `W??ASupSpeMerFodAniToyCos` | **Bountifur** | `?ASpeMer...` + `W?SupMer...` | 5 HP / 5 PWR | WATER, 2x `?`, AIR, Support, Specialist, Mercenary, Food, Animal, Toy, Costume | Melee | Whenever Gold is earned, heal a random allied unit (including the Hero) for 1 / 2 / 3 HP per 1 Gold earned. |
| **T3** | `F??AFigSpeMerFodMecToyApp` | **Coinroaster** | `?ASpeMer...` + `F?FigMer...` | 5 HP / 5 PWR | FIRE, 2x `?`, AIR, Fighter, Specialist, Mercenary, Food, Mecha, Toy, Appliance | Ranged | When attacking, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to apply 1 / 2 / 3 Burn to the target for every full 10 Gold held before the spend. |
| **T3** | `EF??TnkFigMerMecPlaToyApp` | **Furnasafe** | `E?TnkMer...` + `F?FigMer...` | 5 HP / 5 PWR | EARTH, FIRE, 2x `?`, Tank, Fighter, Mercenary, Mecha, Plant, Toy, Appliance | Melee | Before taking damage, if holding at least 10 Gold, spend 1 Gold to reduce incoming damage by 1 / 2 / 3 for every full 10 Gold held before the spend (minimum 0 damage). |
| **T3** | `EW??TnkSupMerAniPlaToyCos` | **Mosstycoon** | `E?TnkMer...` + `W?SupMer...` | 5 HP / 5 PWR | EARTH, WATER, 2x `?`, Tank, Support, Mercenary, Animal, Plant, Toy, Costume | Melee | At turn start, if holding at least 10 Gold, spend 1 / 2 / 3 Gold to gain +1 / +2 / +3 HP and +1 / +2 / +3 PWR for every full 10 Gold held before the spend. |

#### Mercenary Items & Trinkets

| Category | ID | Name | Tier & Recipe / Trigger | Effect Description |
|---|---|---|:---:|---|
| **Item** | `item_claim_ticket` | **Claim Ticket** | Unique Tier 1 | When holder is knocked out, earn 1 Gold. (+1 HP). |
| **Item** | `item_interest_ledger` | **Piggy Bank** | Tier 2: Claim Ticket + `item_t1_a` (Candy) | Whenever 1 Gold is earned, heal holder for 1 HP. (+2 HP). |
| **Item** | `item_loaded_contract` | **Loaded Contract** | Tier 2: Claim Ticket + `item_t1_b` (Wakizashi) | Whenever 1 Gold is earned, holder gains +1 PWR. (+2 PWR). |
| **Item** | `item_golden_seal` | **Golden Seal** | Tier 3: Piggy Bank + Loaded Contract | Dynamically grants +1 HP and +1 PWR for every full 10 Gold currently held. Recalculates immediately whenever Gold changes. (+2 HP / +2 PWR). |
| **Item** | `item_mercenary_emblem` | **Mercenary Emblem** | Tier 3 Standalone | Contributes +1 Mercenary trait counter. Whenever 1 Gold is earned while equipped, holder gains +1 HP and +1 PWR. Works from lineup or bench. |
| **Trinket** | `trinket_trait_mercenary` | **Mercenary Sigil** | Trait Thresholds | Enables and tracks the Mercenary Trait thresholds (2 / 3 / 4 / 5). |
| **Trinket** | `trinket_recruiting_charm` | **Recruiting Charm** | Turn Start | At turn start, if holding at least 1 Gold and a bench slot is open, spend 1 Gold to hire one Level 1 Coinling (`?MerSpe`) to the bench. |
| **Trinket** | `trinket_wanted_poster` | **Wanted Poster** | Turn Start | At turn start, apply 1 stack of Bounty to a random enemy unit. |
| **Trinket** | `trinket_mercenary_insignia` | **Mercenary Insignia** | Entry / Merge | When a Mercenary unit enters the board or merges, it gains +1 HP and +1 PWR. |

---

### 2.2 Hero Set: Novice (Hero: Dan)
* **Associated Hero:** Dan (`hero_starter`)
* **Core Mechanic:** Flashcard Mastery Scaling, Study Time Banking, and 3-Token Baseline Safety Net.
* **Lineage Element:** Dan inherits 3 souls of a random element (`?`); all 11 Novice lineage units dynamically inherit that element.
* **Trait Rule:** All 11 Novice units carry **Novice** as their sole class trait.

#### Novice Trait Ladder

The Novice trait scales based on the number of Novice-tagged units in the active lineup. Dan provides +1 Novice counter permanently. Trait levels are cumulative.

| Level | Threshold | Effect |
|---|:---:|---|
| **Bronze** | 2 Novices | Add **+1.0 second** to the starting time of each battle minigame. |
| **Silver** | 3 Novices | In addition to Bronze, achieving a **3-correct-answer streak grants 1 bonus Gold** (once per minigame session, maximum 5 Gold per encounter). |
| **Gold** | 4 Novices | In addition to Silver, a correct answer to a card at **Mastery Level 1 (Very Hard)** grants **1 bonus Token**. |
| **Prismatic** | 5 Novices | In addition to all previous levels: Each incorrect submitted answer adds **+0.5s** to the remaining time (panic buffer; does not apply to Skips). Achieving a **3-correct-answer streak grants +1 bonus Token** (once per minigame session). |

#### Novice Units (11 Units)

| Tier | ID | Recipe | Stats | Tags | Attack | Ability (Levels 1 / 2 / 3) |
|---|---|---|:---:|---|:---:|---|
| **T1** | `?NovPla` | Starter | 1 HP / 1 PWR | `?`, Novice, Plant | Ranged | When knocked out, add 1 / 2 / 3 seconds to the starting time of the next battle minigame. This effect stacks. |
| **T2** | `?ANovFod` | `?NovPla` + `ASpeFod` | 2 HP / 3 PWR | `?`, AIR, Novice, Food | Ranged | Pre-Battle, Charge an Empowered Attack that inflicts 1 / 2 / 3 Static on the target for every 2 Current Tokens held. |
| **T2** | `E?NovPla` | `?NovPla` + `ETnkPla` | 3 HP / 2 PWR | EARTH, `?`, Novice, Plant | Melee | Pre-Battle, gain 1 / 2 / 3 Armor for every 2 Current Tokens held. |
| **T2** | `F?NovApp` | `?NovPla` + `FFigMec` | 2 HP / 3 PWR | FIRE, `?`, Novice, Appliance | Melee | Pre-Battle, Charge an Empowered Attack that applies 1 / 2 / 3 Burn to the target for every 2 Current Tokens held. |
| **T2** | `W?NovCos` | `?NovPla` + `WSupAni` | 2 HP / 3 PWR | WATER, `?`, Novice, Costume | Melee | When hurt by an attack, heal self for 1 / 2 / 3 HP for every 2 Current Tokens held. |
| **T3** | `E??ANovPla` | `?ANovFod` + `E?NovPla` | 5 HP / 5 PWR | EARTH, 2x `?`, AIR, Novice, Plant | Melee | Pre-Battle, spend 1 Token to gain 1 / 2 / 3 Armor for each Current Token held and 1 / 2 / 3 Spikes for every 2 Current Tokens held before the spend. |
| **T3** | `F??ANovFod` | `?ANovFod` + `F?NovApp` | 5 HP / 5 PWR | FIRE, 2x `?`, AIR, Novice, Food | Melee | When attacking, spend 1 Token to inflict 1 / 2 / 3 Static on the target per Current Token held before the spend. |
| **T3** | `W??ANovCos` | `?ANovFod` + `W?NovCos` | 5 HP / 5 PWR | WATER, 2x `?`, AIR, Novice, Costume | Melee | When hurt by an attack, spend 1 Token to heal self for 1 / 2 / 3 HP for each Current Token held before the spend. (Can activate multiple times if tokens available). |
| **T3** | `EF??NovApp` | `E?NovPla` + `F?NovApp` | 5 HP / 5 PWR | EARTH, FIRE, 2x `?`, Novice, Appliance | Ranged | When attacking, spend 1 Token to Charge an Empowered Attack that applies 1 / 2 / 3 Burn to the target per Current Token held before the spend. |
| **T3** | `EW??NovPla` | `E?NovPla` + `W?NovCos` | 5 HP / 5 PWR | EARTH, WATER, 2x `?`, Novice, Plant | Ranged | When attacking, spend 1 Token to deal 1 / 2 / 3 Bonus Damage per Current Token held before the spend. |
| **T3** | `FW??NovAni` | `F?NovApp` + `W?NovCos` | 5 HP / 5 PWR | FIRE, WATER, 2x `?`, Novice, Animal | Ranged | When knocked out, add 1 / 2 / 3 seconds to the starting time of the next battle minigame and gain Tokens equal to this unit's level (1 / 2 / 3 Tokens). |

#### Novice Items & Trinkets

| Category | ID | Name | Tier / Trigger | Effect Description |
|---|---|---|:---:|---|
| **Item** | `item_study_pouch` | **Token** | Tier 1 | When holder is knocked out, gain Tokens equal to holder's Tier (1 / 2 / 3 Tokens). (+1 HP). |
| **Item** | `item_review_ledger` | **Nail** | Tier 2 | Pre-Battle, while equipped in the active lineup, holder gains 1 / 2 / 3 Spikes for each Current Token held. (+2 HP). |
| **Item** | `item_answer_key` | **Burnout** | Tier 2 | When attacking, while equipped in the active lineup, apply 1 / 2 / 3 Burn to the target for each Current Token held. (+2 PWR). |
| **Item** | `item_novice_archive` | **Novice's Archive** | Tier 3 | When attacking, spend 1 Token to deal 1 / 2 / 3 Bonus Damage for each Current Token held before the spend. (+2 HP / +2 PWR). |
| **Item** | `item_novice_emblem` | **Novice Emblem** | Tier 3 Standalone | Contributes +1 Novice trait counter while in active lineup. For each enemy unit knocked out by holder in battle, add 1 second to the starting time of the next battle minigame. |
| **Trinket** | `trinket_trait_novice` | **Novice Sigil** | Trait Thresholds | Enables and tracks the Novice Trait thresholds (2 / 3 / 4 / 5). Guarantees at least 3 Tokens from every token-awarding minigame session (inside and outside battle). |
| **Trinket** | `trinket_beginners_charm` | **Beginner's Charm** | Minigame | Gain 1 extra Token if the answered flashcard is Mastery Level 1 (Very Hard). Synergizes directly with Gold Novice. |
| **Trinket** | `trinket_study_hall_bell` | **Study Hall Bell** | Turn Start | At turn start, if available, spend 1 Token to summon a Level 1 `?NovPla` into the first open lineup slot (or bench if full). Battle-only summon. |

---

## 3. Heroes

All Heroes adhere to the standard selection constitution:
* **3 Elemental Souls of the Same Element:** Immediately activates that element's 3-Soul synergy threshold. Lineage Heroes pass this dynamic element to their 11 lineage units.
* **Fixed Archetype / Class Trait:** Defines the Hero's mechanical identity.
* **Bonus Random Trait:** 1 Random Class or Thematic trait to maintain starting trait parity.
* **Starter Sigil:** Starts with the dedicated trait Sigil trinket in inventory.

| ID | Name | Stats | Starting Trait & Soul Loadout | Starter Sigil | Abilities |
|---|---|:---:|---|---|---|
| `hero_starter` | **Dan** | 10 HP / 2 PWR | • 3x Random Element (`?`, inherited by Novice lineage)<br>• **Fixed Trait:** Novice<br>• **Bonus Trait:** 1 Random Thematic Trait | Novice Sigil | When an allied unit is knocked out, gain HP equal to that ally's PWR. |
| `hero_bounty_hunter` | **Shiken** | 10 HP / 2 PWR | • 3x Random Element (`?`, inherited by Mercenary lineage)<br>• **Fixed Trait:** Mercenary<br>• **Bonus Trait:** 1 Random Thematic Trait | Mercenary Sigil | When this hero knocks out an enemy, earn 1 Gold. |
| `hero_avenger` | **Han** | 6 HP / 2 PWR | • 3x Random Element<br>• **Fixed Trait:** Fighter<br>• **Bonus Trait:** 1 Random Thematic Trait | Ninja Sigil | When an allied unit is knocked out, immediately execute a Reactive Attack on the frontmost enemy. |
| `hero_bastion` | **Kon** | 12 HP / 1 PWR | • 3x Random Element<br>• **Fixed Trait:** Tank<br>• **Bonus Trait:** 1 Random Thematic Trait | Bastion Sigil | Pre-Battle, gain 1 stack of Reinforce.<br><br>When this hero knocks out a unit, gain 1 Armor and 1 Spikes. |
| `hero_pyro` | **Hiko** | 8 HP / 2 PWR | • 3x Fire (Assigned)<br>• **Fixed Trait:** Fire Ritual<br>• **Bonus Traits:** 1 Random Class + 1 Random Thematic Trait | Fire Sigil | Instead of attacking, shoots a Fireball at the mirror slot enemy that applies Burn stacks equal to PWR. |
| `hero_timekeeper` | **Deko** | 10 HP / 1 PWR | • 3x Random Element<br>• **Fixed Trait:** Support (Monk Trait in development)<br>• **Bonus Trait:** 1 Random Thematic Trait | Monk Sigil | At turn start, grant +1 HP to the unit directly in front and +1 PWR to the unit directly behind. |

---

## 4. Universal Neutral Items & Equipment

These items are permanently available across all runs and gacha pools.

| ID | Name | Stats | Tier / Tags | Ability Description |
|---|---|:---:|---|---|
| `consumable_potion_plunder` | **Plunder** | - | Consumable | Steals a random item from target and places it into matching tier Gacha Machine. |
| `item_emblem_air` | **Air Emblem** | +2 HP / +1 PWR | AIR | Grants the **Air** soul, enabling Air trait threshold scaling. |
| `item_emblem_earth` | **Earth Emblem** | +4 HP | EARTH | Grants the **Earth** soul, enabling Earth trait threshold scaling. |
| `item_emblem_fire` | **Fire Emblem** | +2 PWR | FIRE | Grants the **Fire** soul, enabling Fire trait threshold scaling. |
| `item_emblem_water` | **Water Emblem** | +2 HP / +1 PWR | WATER | Grants the **Water** soul, enabling Water trait threshold scaling. |
| `item_potion_heroism` | **Battery** | - | Tier 2, Potion | Applies 4 Armor stacks immediately upon use. |
| `item_potion_spikes` | **Cactus Juice** | - | Tier 2, Potion | Grants 4 Spikes stacks immediately upon use. |
| `item_potion_t1` | **Apple** | - | Tier 1, Potion | Restores 4 HP immediately upon use. |
| `item_t1_a` | **Candy** | +1 HP | Tier 1 | At turn start, heal holder for 2 HP. |
| `item_t1_b` | **Wakizashi** | +1 PWR | Tier 1 | When attacking, if target has more HP than holder, perform an immediate Extra Attack. |
| `item_t2_a` | **Summoning Scroll** | +2 HP | Tier 2 | When holder is knocked out, summon a random Tier 1 unit. |
| `item_t2_b` | **Scythe** | +2 PWR | Tier 2 | When holder knocks out an enemy, gain an Extra Action immediately (once per turn). |
| `item_t2_c` | **Anvil** | +1 HP / +1 PWR | Tier 2 | When hurt by an attack, heal holder for 1 HP and gain +1 PWR. |
| `item_t2_d` | **Slime Cell** | - | Tier 2 | Grants holder +1 PWR for each Slime Cell in battle. When holder is knocked out, spawn a Slime Cell into the Tier 2 Gacha Machine. |
| `item_t3_a` | **Ramune** | +4 HP | Tier 3 | When holder is hurt by an attack, heal two random allies for 2 HP each. |
| `item_t3_b` | **HardCandy** | +4 PWR | Tier 3 | When holder attacks, grant 50% of damage dealt as Armor and Spikes stacks to holder. |
| `item_t3_c` | **Leech Gumi** | +2 HP / +2 PWR | Tier 3 | When attacking, heal holder for 20% of damage dealt (minimum 1 HP). |
| `item_t3_d` | **Rubber Ball** | +2 HP / +2 PWR | Tier 3 | When hurt by an attack, deal that damage as a ranged attack to a random enemy. |
| `item_t3_e` | **Sour Candy** | +3 HP / +1 PWR | Tier 3 | When holder is knocked out, deal damage equal to 50% of the highest HP enemy's current HP to that enemy. |
| `item_t3_f` | **popcorn** | +1 HP / +3 PWR | Tier 3 | After dealing attack damage, steal half of target's PWR (minimum 1). |
| `item_t3_g` | **Slingshot** | +1 PWR | Tier 3 | Melee attacks convert to ranged attacks targeting the mirror slot enemy. |

---

## 5. Universal Neutral Trinkets

### 5.1 Insignias (Enter Board Stat Trinkets)
An **Insignia** grants +1 HP and +1 PWR to a matching unit when it enters the board.

| Insignia Group | Items | Effect |
|---|---|---|
| **Level Insignias** | Apprentice Insignia (Level 1), Veteran Insignia (Level 2), Master Insignia (Level 3) | Grant +1 HP and +1 PWR to units of matching level. |
| **Tier Insignias** | Cheap Insignia (Tier 1), Fair Insignia (Tier 2), Premium Insignia (Tier 3) | Grant +1 HP and +1 PWR to units of matching tier. |
| **Trait Insignias** | One for each Elemental, Class, and Thematic trait | Grant +1 HP and +1 PWR to units with matching trait. |

---

### 5.2 Base Sigils & Charms Master Table

| ID | Name | Trigger / Type | Effect Description |
|---|---|:---:|---|
| `trinket_aegis` | **Aegis Charm** | Once per turn | When an ally would be knocked out, they survive with 1 HP instead. |
| `trinket_armor_aura` | **Armor Aura** | Turn Start | At turn start, all allies gain 3 Armor. |
| `trinket_awe_inspiring_totem` | **Awe Inspiring Totem** | Turn Start | At turn start, if there is a Tier 3 or Level 3 unit in lineup, grants +1 HP and +1 PWR to all lower tier/level units. |
| `trinket_bargain_charm` | **Bargain Charm** | Passive (Player) | Gacha draws cost 1 token less (minimum 1) once per machine, per turn. |
| `trinket_burn_vial` | **Burn Vial** | When Attacking | Attacks apply 1 Burn stack. |
| `trinket_hero_catalyst` | **Hero's Catalyst** | On Merge | Grants Hero +1 HP and +1 PWR on any merge performed on the battle board. |
| `trinket_merge_damage_charm` | **Fusion Spark** | On Merge | Whenever a merge is performed on battle board, deal 3 damage to a random enemy. |
| `trinket_polished_plate` | **Polished Plate** | Pre-Battle | Pre-Battle, grants 1 stack of Reinforce to all allies. |
| `trinket_purifying_pendant` | **Purifying Pendant** | Reactive | When an ally takes damage from a negative effect, cleanse and remove all remaining stacks of that effect. |
| `trinket_rusty_ring` | **Rusty Ring** | Passive | Grants +1 HP and +1 PWR to all units with no equipment. |
| `trinket_soul_echo` | **Soul Echo** | Ally Knockout | When an ally is knocked out, resurrect the first non-hero unit that died this turn. |
| `trinket_spiked_armor` | **Spiked Armor** | Turn Start | At turn start, frontmost unit gains 2 Armor and 2 Spikes. |
| `trinket_time_sprint_charm` | **Sprint Charm** | Minigame | Minigame time gets a flat 2-second increase in battle. |
| `trinket_token_return_charm` | **Token Return Charm** | First Knockout / Round | When first unit is knocked out each round, return Tokens equal to its Tier. |
| `trinket_trinity_charm` | **Trinity Charm** | Turn / Encounter | If you draw at least once from each tier machine (1, 2, and 3) in a turn or encounter, gain 1 Token. |
| `trinket_twin_charm` | **Twin Charm** | Passive | Your units gain +1 PWR for every 2 copies of that same unit in your battle pool. |
| `trinket_underdog_emblem` | **Underdog Emblem** | Pre-Battle | If team fields fewer units than enemy, all allies gain 2 Armor per unit difference. |
| `trinket_vengeance` | **Vengeance Charm** | Ally Knockout | When an ally is knocked out, grant +1 HP and +1 PWR to a random living ally. |
| `trinket_trait_air` | **Air Sigil** | Trait Thresholds | Air trait effects activate at 3, 6, 12, 20, and 32 units. |
| `trinket_trait_earth` | **Earth Sigil** | Trait Thresholds | Earth trait effects activate at 3, 6, 12, 20, and 32 units. |
| `trinket_trait_fire` | **Fire Sigil** | Trait Thresholds | Fire trait effects activate at 3, 6, 12, 20, and 32 units. |
| `trinket_trait_water` | **Water Sigil** | Trait Thresholds | Water trait effects activate at 3, 6, 12, 20, and 32 units. |
| `trinket_trait_fighter` | **Fighter Sigil** | Trait Thresholds | Fighter trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_tank` | **Tank Sigil** | Trait Thresholds | Tank trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_support` | **Support Sigil** | Trait Thresholds | Support trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_specialist` | **Specialist Sigil** | Trait Thresholds | Specialist trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_animal` | **Animal Sigil** | Trait Thresholds | Animal trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_appliance` | **Appliance Sigil** | Trait Thresholds | Appliance trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_costume` | **Costume Sigil** | Trait Thresholds | Costume trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_food` | **Food Sigil** | Trait Thresholds | Food trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_mecha` | **Mecha Sigil** | Trait Thresholds | Mecha trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_plant` | **Plant Sigil** | Trait Thresholds | Plant trait effects activate at 2, 3, 4, and 5 units. |
| `trinket_trait_toy` | **Toy Sigil** | Trait Thresholds | Toy trait effects activate at 2, 3, 4, and 5 units. |

---

## 6. Enemies & Bosses

| ID | Name | Stats | Tags | Abilities |
|---|---|:---:|---|---|
| `boss_1` | **The Awakened Guardian** | 6 HP / 6 PWR | Boss | At turn end, summons minions to fill all empty team slots. Whenever a GachaBall is drawn, gains +1 HP. |
| `boss_2` | **The Shadow Warden** | 8 HP / 8 PWR | Boss | At turn end, summons minions to fill all empty team slots. Whenever a Token is spent, gains +1 HP. |
| `boss_3` | **The Storm Herald** | 10 HP / 10 PWR | Boss | At turn end, summons minions to fill all empty team slots. When an allied unit is knocked out, gains +1 HP and +1 PWR. |
| `boss_4` | **The Ancient Titan** | 12 HP / 12 PWR | Boss | At turn end, summons minions to fill all empty team slots. |
| `boss_5` | **The Final Arbiter** | 15 HP / 15 PWR | Boss | At turn end, summons minions to fill all empty team slots. |
| `enemy_hero` | **Enemy Hero** | 10 HP / 2 PWR | Rival | Melee Attack: Deal (PWR) damage to frontmost enemy. |
| `unit_dust_elite_t1` | **Dust Guard (T1)** | 3 HP / 3 PWR | Elite | At turn end, summons minions to fill all empty team slots. When an allied unit is knocked out, spawns a T1 Dust minion. Gains HP and PWR based on tier of knocked-out Dust unit (+1/+1 for T1, +2/+2 for T2). |
| `unit_dust_elite_t2` | **Dust Sentinel (T2)** | 4 HP / 4 PWR | Elite | At turn end, summons minions to fill all empty team slots. When an allied unit is knocked out, spawns random T1 or T2 Dust minion. Gains HP and PWR based on tier of knocked-out Dust unit (+1/+1 for T1, +2/+2 for T2). |
| `unit_dust_elite_t3` | **Dust Overlord (T3)** | 5 HP / 5 PWR | Elite | At turn end, summons minions to fill all empty team slots. When an allied unit is knocked out, spawns random Dust minion. Gains HP and PWR based on tier of knocked-out Dust unit (+1/+1 for T1, +2/+2 for T2, +3/+3 for T3). |
| `unit_dust_t1` | **Dust Minion (T1)** | 1 HP / 1 PWR | Minion | Melee Attack: Deal (PWR) damage to frontmost enemy. |
| `unit_dust_t2` | **Dust Minion (T2)** | 2 HP / 2 PWR | Minion | Melee Attack: Deal (PWR) damage to frontmost enemy. |
| `unit_dust_t3` | **Dust Minion (T3)** | 3 HP / 3 PWR | Minion | Melee Attack: Deal (PWR) damage to frontmost enemy. |

---

## 7. Enemy Encounter Eligibility (Player-Only List)

The following resources depend on player-only economies (Tokens, Flashcard Minigames, Gacha draws, Gold, Discard Pile) and are excluded from random enemy encounter pools:

* **Hero Set Units:** All 11 Mercenary Units and all 11 Novice Units.
* **Hero Set Items:** `item_claim_ticket`, `item_interest_ledger`, `item_loaded_contract`, `item_golden_seal`, `item_mercenary_emblem`, `item_study_pouch`, `item_review_ledger`, `item_answer_key`, `item_novice_archive`, `item_novice_emblem`, `consumable_potion_plunder`, `item_t2_d`.
* **Player-Exclusive Trinkets:** `trinket_bargain_charm`, `trinket_beginners_charm`, `trinket_hero_catalyst`, `trinket_merge_damage_charm`, `trinket_mercenary_insignia`, `trinket_novice_insignia`, `trinket_recruiting_charm`, `trinket_study_hall_bell`, `trinket_trait_specialist`, `trinket_time_sprint_charm`, `trinket_token_return_charm`, `trinket_trait_mercenary`, `trinket_trait_novice`, `trinket_trinity_charm`, `trinket_twin_charm`, `trinket_wanted_poster`.

---

## 8. Core Stats, Attributes & Status Effects

| Stat / Status | Category | Mechanics | Decay Mode |
|---|:---:|---|---|
| **HP (Health)** | Core Stat | Life pool of unit. Reaching 0 knocks out unit. | Permanent |
| **PWR (Power)** | Core Stat | Base damage output for attacks and Spikes scaling. | Permanent |
| **Armor** | Battle Shield | Absorbs all damage point-for-point. Bypassed only by Burn. | Decays to 0 at turn start (unless preserved by Reinforce). |
| **Spikes** | Counter | Reflects active Spikes stacks damage when hit by Melee Attack. | Loses 1 stack per melee activation. Bypassed by Ranged Attacks. |
| **Burn** | Negative Status | Deals damage equal to stacks at end of turn. Bypasses Armor. | Reduced by 50% (rounded down) at end of turn. Stacks in Burn Slot do not decay. |
| **Reinforce** | Positive Status | Prevents Armor decay at turn start. Stackable. | Decays by 1 stack at turn start. |
| **Static** | Negative Status | When knocked out, deals damage equal to stacks to adjacent allies. Mitigated by Armor. | Cleared on explosion; decays by 1 stack at turn end if living. |
| **Bounty** | Special Status | When marked unit is knocked out, awards 1 Gold per stack. | Decays by 1 stack at turn start. |

---

## 9. Battlefield Slot Effects

| ID | Slot Name | Trigger | Effect | Cost (Gold) |
|---|---|:---:|---|:---:|
| `burn` | **Burn Slot** | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 Gold |
| `lightning` | **Lightning Slot** | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 Gold |
| `death` | **Death Slot** | `on_turn_end` (Turn 10+) | Systemic sudden-death slot advancing forward from Turn 10+. Immediately reduces unit HP to 0. | Automatic |

---

## 10. Trait Synergies & Thresholds

| Trait Category | Trait | Thresholds | Archetype Mechanic |
|---|---|:---:|---|
| **Elemental** | **Fire** | 3 / 6 / 12 / 20 / 32 Souls | Applies Burn on attack, spreads Burn on tick, deals bonus damage vs burning targets. |
| | **Earth** | 3 / 6 / 12 / 20 / 32 Souls | Grants Armor and Spikes across frontline at Pre-Battle; attacks deal bonus damage equal to Spikes. |
| | **Water** | 3 / 6 / 12 / 20 / 32 Souls | Pre-Battle healing and cleansing; lowest-HP healing; consumes debuffs to heal. |
| | **Air** | 3 / 6 / 12 / 20 / 32 Souls | Inflicts Static on attack, splashes Static to adjacent enemies, team Pre-Battle Static. |
| **Class** | **Tank** | 2 / 3 / 4 / 5 Units | Frontline Armor, backward Armor passing, attack interception, Armor-to-Spikes. |
| | **Fighter** | 2 / 3 / 4 / 5 Units | Bonus damage vs higher HP, ranged counter-attack, cleave splash, extra action on kill. |
| | **Support** | 2 / 3 / 4 / 5 Units | Positional +HP (front) / +PWR (behind), turn-start lowest-stat buffs, Hero empowerment. |
| | **Specialist** | 2 / 3 / 4 / 5 Units | Opening tokens, Gacha discount, gold on kill, bench battle clone, +PWR per 5 Gold. |
| | **Mercenary** | 2 / 3 / 4 / 5 Units | Gold-focused scaling, Bounty triggering, wallet-based defense and attacks. |
| | **Novice** | 2 / 3 / 4 / 5 Units | Extra starting study time, streak-preserving Skips, bonus tokens on Level 1 cards, panic buffer on wrong answers. |
| **Thematic** | **Plant** | 2 / 3 / 4 / 5 Units | Frontline Spikes, turn-start healing, team Spikes & HP, converts heals to Spikes. |
| | **Food** | 2 / 3 / 4 / 5 Units | Feeds ally behind when hurt (+HP/+PWR), passes all PWR when knocked out. |
| | **Animal** | 2 / 3 / 4 / 5 Units | Random alpha +PWR, healing per attack (scaling with PWR). |
| | **Mecha** | 2 / 3 / 4 / 5 Units | Spikes & Armor, Static on attack & hit, merge laser strikes, knockout revenge salvos. |
| | **Appliance** | 2 / 3 / 4 / 5 Units | Static immunity, Pre-Battle Static/Burn, status reflection, converts debuffs to PWR/HP. |
| | **Costume** | 2 / 3 / 4 / 5 Units | Pre-Battle effect and stat theft from mirror enemies and highest-status targets. |
| | **Toy** | 2 / 3 / 4 / 5 Units | Melee Static reflection, knockout explosion detonating highest Static enemy. |

---

## 11. Universal Neutral Base Trait Distribution Matrix

*Master architectural baseline for balancing all future content packs. Only these 25 units are factored into new set calculations.*

### 11.1 Elemental Souls in Base (Tier 1 / Tier 2 / Tier 3 / Total)
*Each Tier 1 has 1 soul, Tier 2 has 2 souls, Tier 3 has 4 souls.*

| Element | Tier 1 (4 Units) | Tier 2 (6 Units) | Tier 3 (15 Units) | Base Total Souls |
|---|:---:|:---:|:---:|:---:|
| **Earth** | 1 | 3 | 15 | **19** |
| **Fire** | 1 | 3 | 15 | **19** |
| **Water** | 1 | 3 | 15 | **19** |
| **Air** | 1 | 3 | 15 | **19** |
| **Total** | **4** | **12** | **60** | **76** |

---

### 11.2 Class Traits in Base (Tier 1 / Tier 2 / Tier 3 / Total)
*Every base unit carries exactly 1 Class Trait.*

| Class Trait | Tier 1 (4 Units) | Tier 2 (6 Units) | Tier 3 (15 Units) | Base Total Units | Units Represented |
|---|:---:|:---:|:---:|:---:|---|
| **Tank** | 1 | 2 | 3 | **6** | Stumpling, Soliwhale, Branblee, Reizokun, Komatop, Nuton |
| **Fighter** | 1 | 2 | 3 | **6** | Vulcannon, Bogmantle, Pepspray, Griffoam, Pachinkannon, Tsunamantle |
| **Support** | 1 | 1 | 4 | **6** | Ripplepup, Matryodust, Oakbark, Matryoshkan, Mechamom, Relaytron |
| **Specialist** | 1 | 1 | 5 | **7** | Puffcorn, Furnair, Mimicloak, Blendroid, BubbleGunger, Sojikun, Wind-up-kun |
| **Total** | **4** | **6** | **15** | **25** | *Every class is between 6 and 7 units.* |

---

### 11.3 Thematic Traits in Base (Tier 1 / Tier 2 / Tier 3 / Total)
*Every base unit carries exactly 1 Thematic Trait.*

| Thematic Trait | Tier 1 (4 Units) | Tier 2 (6 Units) | Tier 3 (15 Units) | Base Total Units | Units Represented |
|---|:---:|:---:|:---:|:---:|---|
| **Plant** | 1 | 0 | 1 | **2** | Stumpling, Oakbark |
| **Animal** | 1 | 1 | 1 | **3** | Ripplepup, Soliwhale, Griffoam |
| **Costume** | 0 | 1 | 2 | **3** | Bogmantle, Mimicloak, Tsunamantle |
| **Food** | 1 | 1 | 2 | **4** | Puffcorn, Pepspray, BubbleGunger, Nuton |
| **Appliance** | 0 | 1 | 3 | **4** | Furnair, Blendroid, Reizokun, Sojikun |
| **Toy** | 0 | 1 | 3 | **4** | Matryodust, Matryoshkan, Komatop, Wind-up-kun |
| **Mecha** | 1 | 1 | 3 | **5** | Vulcannon, Branblee, Mechamom, Pachinkannon, Relaytron |
| **Total** | **4** | **6** | **15** | **25** | *All thematic traits are clustered between 2 and 5.* |
