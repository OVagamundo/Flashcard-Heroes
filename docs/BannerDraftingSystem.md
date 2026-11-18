# Banner Drafting System & Strategy Drafter Architecture

## Overview

The **Banner Drafting System** is the execution engine responsible for micro budget drafting, formation assembly, synergistic item equipping, and mid-combat reinforcement waves for enemy encounters in *Flashcard Heroes*.

While the macro [`EncounterSystem.md`](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/EncounterSystem.md) determines **which** banner or boss is scheduled, balances environmental slot effects, and calculates the net effective budget, the **Banner Drafting System** determines **how** every Gold of that budget is spent on the battlefield.

Every battle is governed by an **encounter banner** using the **Strategy Pattern** via [`BannerDraftingRegistry`](../scripts/systems/encounter/BannerDraftingRegistry.gd). The banner occupies the dedicated one-entry `EnemyBanner` container, independently of the nine `EnemyTrinkets` slots. Existing `trinket_banner_*` resource IDs and their ability definitions remain stable.

All 21 banners use individual transparent PNGs in `assets/PixelArt/sprites/banners/`, each 56×120 pixels with a four-color opaque palette. `EnemyBannerView` displays the sprite at 112×240 pixels with its pole at the team boundary, cloth extending into the enemy area, and Z order above the battle background and below the platforms/units. Hover and long press use the shared inspection controller. VCR snapshots and activation events register the banner itself as the animation source. Legacy encounters with a banner in `enemy_trinket_ids` are normalized during battle setup. The commander retains its drafting affinities and is registered before enemy trinkets to preserve ability ordering.

---

## 1. Architectural Foundation & Strategy Pattern

```
                       ┌────────────────────────────┐
                       │     EncounterGenerator     │
                       │    (Macro Orchestration)   │
                       └──────────────┬─────────────┘
                                      │ delegates lineup & reinforcements
                                      ▼
                       ┌────────────────────────────┐
                       │   BannerDraftingRegistry   │
                       └──────────────┬─────────────┘
                                      │ routes to drafter
               ┌──────────────────────┴──────────────────────┐
               ▼                                             ▼
  ┌─────────────────────────┐                   ┌─────────────────────────┐
  │      BannerDrafter      │ (Base Contract)   │   SwarmBannerDrafter    │ (Modular Engine)
  └────────────┬────────────┘                   └────────────┬────────────┘
               │                                             │
      ┌────────┴────────┬───────────────┐           ┌────────┴────────┐
      ▼                 ▼               ▼           ▼                 ▼
LoneWhaleDrafter  FireDrafter    SlimeblobDrafter DustmonDrafter ToughmonDrafter
                        │                           │                 │
                        ▼                           └────────┬────────┘
                  BurnieDrafter                              ▼
                                                     DoppelkunDrafter
```

### 1.1 The Base Drafter Contract (`BannerDrafter`)
Located at [`scripts/systems/encounter/BannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/BannerDrafter.gd):
- `draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition`: Generates initial enemy placements, levels, items, secondary trinkets, and stat overflow.
- `draft_reinforcements(daily_budget: int, current_board: Dictionary, empty_slots: Array[int], active_trinkets: Array[StringName], rng: SeededRNG) -> Array[Dictionary]`: Generates mid-combat reinforcements when triggered by [`EffectBannerReinforce.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectBannerReinforce.gd).
- Shared utilities: `unit_has_trait()`, `get_trait_emblem()`, `get_trait_crest()`, `_get_item_cost()`, `_get_item_tier()`, and `_distribute_stat_overflow()`.

### 1.2 Trait & Emblem Invariant Map
Every trait maps deterministically to its corresponding Trait Crest (trinket) and Trait Emblem (item):
- **Tank:** `trinket_trait_tank` / `item_emblem_tank`
- **Fighter:** `trinket_trait_fighter` / `item_emblem_fighter`
- **Support:** `trinket_trait_support` / `item_emblem_support`
- **Specialist:** `trinket_trait_specialist` / `item_emblem_specialist`
- **Earth / Fire / Water / Air:** `trinket_trait_<elem>` / `item_emblem_<elem>`
- **Plant / Animal / Toy / Costume / Food / Appliance / Mecha:** `trinket_trait_<origin>` / `item_emblem_<origin>`

Equipping an emblem item directly injects the corresponding trait tag into the unit during combat via `GachaBallInstance._build_equipment_components()`, enabling cross-trait synergies.

---

## 2. The Atomic Synergy Package Drafting Engine

Encounter drafting avoids independent greedy slot rolling by assembling units into **Atomic Synergy Packages** (Curated Pairs and Triplets) and chaining them across contiguous open slots.

### 2.1 Problem Solved
1. **Synergy Dilution:** Independent slot rolls evaluated base scores alongside a multitude of units, causing intended 2-unit synergies (e.g. Branblee + Ripplepup) to be broken up by unrelated units.
2. **Budget Starvation:** In saturation-focused banners, greedy constraints like `max_cost = remaining - slots_after` forced the generator to pick cheap 1G units on early days, strictly barring Tier 2/Tier 3 units and items.
3. **Directional Dependency Failures:** Abilities like Ripplepup's heal (*heals the ally directly in front*) or Puffcorn's deathrattle (*grants PWR to the ally behind*) depend entirely on the partner's exact relative position. Drafting units independently risked placing healers with nothing in front or deathrattle vanguards with nothing behind.

### 2.2 Execution Pipeline
1. **Contiguous Open Spans:** The drafter scans the board for unbroken spans of empty slots (e.g. Slots 0–2 is a span of 3, Slot 4 is a span of 1).
2. **Package Selection:** For spans of length $\ge 2$, `EncounterSynergyRegistry.get_eligible_packages(remaining, start_slot, span_len)` queries all packages fitting the budget, start slot, and span.
3. **Dynamic Package Scoring:** Packages are weighted by `score_package(...)`:
   $$\text{Score} = \text{base\_weight} \times \left(1.0 + \frac{\text{base\_cost}}{\text{remaining}}\right) \times \prod_{\text{tags}} (1.5 \text{ if matching active secondary trinket})$$
   * Plus adjacency bonuses (+25) if the package front or rear matches surviving board neighbors.
4. **Single-Slot Bridging Fallback:** If only a single slot remains (or remaining budget cannot afford any package), the system selects a single bridge unit using `score_unit_in_slot(...)`, checking `front_partners` of Slot $N+1$ and `behind_partners` of Slot $N-1$.
5. **Master Reference:** Curated Packages, Unit Profiles, and Partner Matrices are documented in [`docs/Encounter_Synergies_and_Pairs_Reference.md`](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Encounter_Synergies_and_Pairs_Reference.md).

---

## 3. Regular Banners

### 3.1 The Lone Whale Banner (`trinket_banner_lone_whale`)
Implemented in [`LoneWhaleBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/LoneWhaleBannerDrafter.gd).

* **Core Unit:** Exactly 1 `WATnkAni` (**Soliwhale**) placed in **Slot 0**.
* **Identity:** Maximizes Soliwhale's passive (*Pre-Battle, gain +1 / +2 / +3 HP and PWR for each empty slot*). Solitary raid boss that attacks first.
* **Budget Hierarchy (100% of Daily Budget):**
  $$\text{Level Up Soliwhale (L2 at } B \ge 4\text{, L3 at } B \ge 8\text{)} \longrightarrow \text{Equip Synergistic Item (T1/T2/T3)} \longrightarrow \text{Secondary Trinket (5G)} \longrightarrow \text{Stat Overflow}$$
* **Stat Overflow:** Leftover budget converts into raw stats at **+2 HP and +1 PWR per 1 Gold**.
* **Reinforcement Rules:** **Zero reinforcements.** Summoning units mid-combat would undermine empty slot scaling.

---

### 3.2 The Swarm Banner (`trinket_banner_swarm`)
Implemented in [`SwarmBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/SwarmBannerDrafter.gd).

* **Strategy:** High board saturation. Overwhelms player lanes and creates an escalating attrition battle.
* **Initial Board Budget:** Uses 100% of Daily Budget ($B$).
* **Drafting Pipeline:**
  1. **Phase 1: Synergy Packages & Bridging:** Fills open contiguous spans with 2-unit pairs and 3-unit triplets.
  2. **Phase 2: Secondary Trinket Pre-allocation & Voting:** If $B \ge 8$, pre-allocates 5G to ensure high-budget encounters secure strategic trait support via bidirectional voting.
  3. **Phase 3: Synergistic Items & Level Ups:** Rolls weighted choices (Item weight 30, Level weight 25) to equip synergistic items or level up units.
  4. **Phase 4: Stat Overflow Fallback:** Leftover budget evenly distributed at **+2 HP / +1 PWR per 1 Gold**.
* **Reinforcement Rules:**
  * **Cadence:** Every Other Turn (Turns 1, 3, 5).
  * **Wave Budget:** Spends **33% of Daily Budget** ($B \times 0.33$).
  * **Summon Behavior:** Fills empty slots using modular package drafting into contiguous pairs, bridging single slots, and applying stat overflow.

---

### 3.3 Trait Banners (14 strategies)

Regular trait banners use `TraitBannerDrafter` and `EnemyTraitBannerProfile`. Fire retains its existing banner ID and icon through the `FireBannerDrafter` adapter. The other thirteen banners have dedicated transparent 64×64 icons and enemy-exclusive trinket resources.

Every profile owns an explicit list of approved pair/triplet IDs. Only off-trait members of those approved packages receive the matching free emblem; the primary crest is also free. Independent fillers are native trait units. Compatible package extensions and missing-partner repairs can introduce the defined enablers, preserving unit order and one equipment slot.

| Trait | Minimum initial budget | Main interaction |
|---|---:|---|
| Fire | 3G | Branblee/Pepspray healing, Burn pressure |
| Earth | 3G | Sustained Armor/Spikes frontline |
| Water | 4G | Positional healing, cleansing, healing-trigger abilities |
| Air | 3G | PWR inheritance, ranged pressure, Static |
| Tank | 2G | Armor passing and interception |
| Fighter | 2G | Sacrificial PWR transfers and death growth |
| Support | 2G | Positional buffs, summon support, adjacent buff copying |
| Plant | 2G | Repeated healing and Spikes |
| Food | 3G | Heal the ally behind; trigger Pepspray and feed Nuton |
| Animal | 2G | Attack healing activates Branblee/Pepspray |
| Mecha | 3G | Armor, Static, summons and death salvos; no enemy merge dependency |
| Toy | 4G | Replacement bodies, summon buffs and melee Static retaliation |
| Appliance | 5G | Durable anchors, healing, status immunity/reflection |
| Costume | 3G | Opening theft followed by inherited PWR and death growth |

The generator evaluates feasibility after battlefield slot effects establish the effective budget. Each initial formation contains an approved core, a native anchor, and enough equipped trait contributions to activate its first threshold. Elemental profiles currently target 3/6 souls; they do not fabricate access to 12/20/32.

The drafter first finds a valid core, chains affordable packages/fillers into compatible slots, then buys secondary trinkets, equipment and levels. Required healing equipment is included in the cost before selection. Remaining Gold uses the existing evenly distributed +2 HP/+1 PWR overflow policy. Trait voting counts equipped emblems and excludes player-only resources.

**Fire examples:** Branblee → Ripplepup with Fire Emblem; Pepspray → Ripplepup with Fire Emblem; the Fire triplet includes Candy on Pepspray so its own healing ability actually activates. The free emblem does not cost Gold. The triplet costs 6G: 5G of units plus 1G Candy.

**Reinforcements:** odd turn ends. Fire spends 50% of daily budget; the other trait banners spend 33%. A typed survivor snapshot preserves actual equipment, effective trait membership, repeated elemental souls and HP. Missing approved partners take priority, followed by whole pairs/triplets and useful native fillers. Surviving units are never moved or equipped by the drafter.

**Composition constraints:** A required item and emblem cannot share a slot. Relaytron transfer packages require an unoccupied recipient item slot. Branblee and Pepspray need an actual healing source; HP buffs do not count as healing. Nuton copies discrete HP/PWR buffs on adjacent recipients, not heals or buffs two slots away.

Mercenary, Novice, and Specialist crests are excluded from enemy strategies. Enemy-valid Specialist units remain usable package partners. Dustmon's seeded trait roll uses the same fourteen compatible traits. Soliwhale retains its separate empty-slot strategy.

See `Enemy_Trait_Banners_Implementation_Plan.md` for the per-trait package reasoning and `tests/trait_banner_suite.tscn` for generation, casualty-pattern, and combat-trigger regression checks.

---

## 4. Elite Banners

### 4.1 The Slimeblob Banner (`trinket_banner_slimeblob`)
Implemented in [`SlimeblobBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/SlimeblobBannerDrafter.gd).

* **Placement:**
  * **Slot 0:** `unit_spikeslime` (1G Level 1 Spikeslime).
  * **Slot 1:** `unit_spikeslime` (1G Level 1 Spikeslime, if budget permits).
  * **Slot 2:** `elite_slimeblob` (Elite boss, Cost = 0, dynamic scaling: $\text{HP} = 6 + \lfloor B \times 0.5 \rfloor$, $\text{PWR} = 2 + \lfloor B \times 0.15 \rfloor$).
  * **Slots 3 & 4:** Left empty intentionally for Reactive Mitosis and evolution spawns.
* **Equipment & Trinkets:** Purchases up to 2 defensive secondary trinkets (`trinket_spiked_armor`, `trinket_polished_plate`, `trinket_trait_tank`, `trinket_armor_aura`), defensive item (`item_t3_b`, `item_t2_c`, `item_t1_a`), and overflow directly onto Slimeblob.
* **Reinforcement Rules:** **Zero horn reinforcements.** Mitosis (`[When Taking Damage]`) and Evolution Clock (`[At Start of Turn]`) handle all spawning in-combat.

---

### 4.2 The Burnie Banner (`trinket_banner_burnie`)
Implemented in [`BurnieBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/BurnieBannerDrafter.gd).

* **Placement:**
  * **Slot 2:** `elite_burnie` (Elite boss, Cost = 0, dynamic scaling: $\text{HP} = 4 + \lfloor B \times 0.4 \rfloor$, $\text{PWR} = 3 + \lfloor B \times 0.2 \rfloor$, 4x Fire Souls).
  * **Slots 0, 1, 3, 4:** Drafted by `FireBannerDrafter` with support budget (85% of Daily Budget).
* **Trinkets:** Automatically receives `trinket_banner_burnie` and free `trinket_trait_fire` (0G).
* **Reinforcement Rules:** Inherits Fire Banner reinforcement engine (50% daily budget, fire units + Ripplepup w/ Fire Emblem).

---

## 5. Milestone Boss Banners

> [!IMPORTANT]
> **No Predefined Boss Order:** Bosses in *Flashcard Heroes* have **no static sequencing** (e.g. "Boss 1", "Boss 2", "Boss 3"). Milestone bosses are selected dynamically from the boss pool via weighted history decay at Flashcard Deck Mastery Milestones (20%, 40%, 60%, 80%, 100%).

### 5.1 The Dustmon Banner (`trinket_banner_dustmon`)
Implemented in [`DustmonBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/DustmonBannerDrafter.gd).

* **Concept:** Meta-deck pollution and attrition. Injects ticking hazard "Dust units" into player gacha machines on ally death.
* **Boss Placement (Slot 4):** Free unit (Cost = 0). Scales dynamically:
  $$\text{HP} = 4 + \lfloor B \times 0.4 \rfloor \quad | \quad \text{PWR} = 3 + \lfloor B \times 0.2 \rfloor$$
* **Random Trait & Free Crest Roll:**
  * At encounter generation, Dustmon rolls **1 or 2 random traits** from `TRAIT_MAP`.
  * The corresponding Trait Crests (`trinket_trait_<trait>`) are added to `enemy_trinket_ids` for **FREE (0G)**.
* **Lower-Tier Swarm Drafting Engine:**
  * Drafts support units in Slots 0..3 using the Swarm package engine with 85% of Daily Budget.
  * **Lower-Tier Bias:** Heavily prioritizes Tier 1 and Tier 2 packages ($2\times$ weight for cost $\le 3$, $1.3\times$ for cost $\le 6$, $0.4\times$ for expensive Tier 3 packages). Deprioritizes high level-ups to favor a wider fodder swarm.
  * **Trait Single-Unit Filter:** Single bridge units must natively match one of the rolled traits.
  * **Free Trait Emblem Injection:** When drafting a synergy package that contains a rolled-trait unit alongside a partner that lacks the trait, the non-matching partner is automatically equipped with `item_emblem_<trait>` for **FREE (0G)**! This enables cohesive package synergies without trait dilution.
* **Reinforcement Rules:**
  * **Cadence:** Every Other Turn (Turns 1, 3, 5) with **33% Daily Budget**.
  * **Targeting:** Prioritizes low-cost fodder (Cost $\le 2$) matching active rolled traits, equipping free emblems on non-matching package units.

---

### 5.2 The Toughmon Banner (`trinket_banner_toughmon`)
Implemented in [`ToughmonBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/ToughmonBannerDrafter.gd).

* **Concept:** Unbreakable armored vanguard commander. Shells behind heavy tanks, refreshing armor and spikes.
* **Boss Placement (Slot 4):** Free unit (Cost = 0). Scales dynamically:
  $$\text{HP} = 4 + \lfloor B \times 0.3 \rfloor \quad | \quad \text{PWR} = 1 + \lfloor B \times 0.1 \rfloor$$
* **Innate Secondary Trinket:** Always holds **`trinket_trait_tank` (Tank Crest)** for **FREE (0G)**.
* **Package Drafting & Free Tank Emblem Injection:**
  * Drafts support units in Slots 0..3 using 85% of Daily Budget.
  * Single-unit fallback filters strictly for native Tank units (`ETnkPla`, `EFTnkMec`, `WATnkAni`, `EFWATnkApp`, `EWWATnkToy`, `FWWATnkFod`).
  * **Free Tank Emblem Injection:** When synergy packages with non-tank partners are selected (such as `pair_branblee_ripplepup` where Ripplepup is Support/Water), the non-tank partner is automatically equipped with **`item_emblem_tank`** for **FREE (0G)**! This ensures full Tank trait activation across the entire vanguard.
* **Reinforcement Rules:**
  * **Cadence:** Every Other Turn (Turns 1, 3, 5) with **33% Daily Budget**.
  * **Targeting:** Drafts Tank units and synergy packages, equipping `item_emblem_tank` for free on any summoned non-tank partners.

---

### 5.3 The Doppelkun Banner (`trinket_banner_doppelkun`)
Implemented in [`DoppelkunBannerDrafter.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/drafters/DoppelkunBannerDrafter.gd).

* **Concept:** Symmetric hero mirror and mimic army. Heroic Mirror copies the player Hero's exact base HP and PWR at battle start.
* **Boss Placement (Slot 0):** Free unit (Cost = 0), placed in Slot 0 for frontline duel initiative.
* **Mimicloak Army Drafting Rules:**
  * **Exclusive Support Unit:** Drafts **strictly `EEFASpeCos` (Mimicloak)** with all available support budget (Cost = 4G each).
  * **Preferred Front Positions:** Deploys Mimicloaks into front slots (Slots 1, 2, 3, 4) in ascending positional order.
  * **Minimum Initial Lineup Rule:** Because only the boss is on the board initially, Doppelkun **guarantees a minimum of 2 Mimicloaks** (Slots 1 and 2), even if support budget is low ($B < 8$).
  * **Budget Scaling:** If remaining budget allows:
    1. Upgrades Mimicloaks to **Level 2** (4G each).
    2. Equips offensive items (`item_t3_b` 4G, `item_t2_b` 2G, `item_t1_b` 1G).
    3. Distributes leftover budget to stat overflow evenly across the Mimicloaks (+2 HP / +1 PWR per 1G).
* **Reinforcement Rules:**
  * **Cadence:** Every Other Turn (Turns 1, 3, 5) with **33% Daily Budget**.
  * **Summon Minimums:**
    * If non-boss allies exist: Guarantees a **minimum of 1 Mimicloak**.
    * If only Doppelkun is alive: Guarantees a **minimum of 2 Mimicloaks** (if at least 2 empty slots exist).
  * **Positioning:** Prefers frontmost empty slots. Spends remaining wave budget on Level 2, offensive items, and stat overflow on the summoned Mimicloaks.

---

## 6. Summary Comparison Matrix

| Banner ID | Drafter Class | Reinforcement Cadence | Wave Budget | Free Trait Crest (0G) | Free Trait Emblem (0G) | Special Drafting Logic |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| `trinket_banner_lone_whale` | `LoneWhaleBannerDrafter` | **None (0%)** | 0G | None | None | 100% budget on Slot 0 Soliwhale; empty slot scaling |
| `trinket_banner_swarm` | `SwarmBannerDrafter` | Turns 1, 3, 5 | 33% | None | None | Contiguous package drafting; pre-reserved 5G secondary trinket ($B \ge 8$) |
| `trinket_banner_fire_phalanx` | `FireBannerDrafter` / `TraitBannerDrafter` | Turns 1, 3, 5 | 50% | Fire Crest (0G) | Free emblem on approved enablers | Curated packages, effective trait counts, dependency repair |
| `trinket_banner_<trait>` (13 other profiles) | `TraitBannerDrafter` | Turns 1, 3, 5 | 33% | Matching crest (0G) | Free emblem on approved enablers | Budget-gated cores, package chaining and dependency repair |
| `trinket_banner_burnie` | `BurnieBannerDrafter` | Turns 1, 3, 5 | 50% | `trinket_trait_fire` (Free 0G) | None | Preplaced Elite Burnie Slot 2; Fire Banner support engine |
| `trinket_banner_slimeblob` | `SlimeblobBannerDrafter` | **None (0%)** | 0G | None | None | Preplaced Spikeslimes (0, 1) & Slimeblob (2); Reactive Mitosis & Evolution |
| `trinket_banner_dustmon` | `DustmonBannerDrafter` | Turns 1, 3, 5 | 33% | 1–2 Random Crests (Free 0G) | Free Emblem of rolled trait(s) | Preplaced Boss Dustmon Slot 4; favors low-tier packages; free emblems for non-matching units |
| `trinket_banner_toughmon` | `ToughmonBannerDrafter` | Turns 1, 3, 5 | 33% | `trinket_trait_tank` (Free 0G) | Free `item_emblem_tank` | Preplaced Boss Toughmon Slot 4; Tank packages; free tank emblems for non-tank partners |
| `trinket_banner_doppelkun` | `DoppelkunBannerDrafter` | Turns 1, 3, 5 | 33% | None | None | Preplaced Boss Doppelkun Slot 0; only Mimicloaks; min 2 initial; min 1 wave (2 if boss alone) |
