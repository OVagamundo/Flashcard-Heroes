# Encounter System & Macro Generator Architecture

## Overview

The **Encounter System** defines, generates, and instantiates enemy encounters for battle in *Flashcard Heroes*. It operates on a deterministic economic budget model driven by run progression and flashcard deck mastery milestones.

The architecture is strictly divided into two decoupled domains:
1. **The Macro Encounter Generator ([`EncounterGenerator.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EncounterGenerator.gd)):** Responsible for run scheduling, deck mastery milestone triggers, environmental slot generation, weighted decay banner/boss selection, and budget balance equilibrium.
2. **The Micro Banner Drafting System ([`BannerDraftingSystem.md`](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/BannerDraftingSystem.md)):** Responsible for how the Daily Budget is spent for each specific banner using the Strategy Pattern via [`BannerDraftingRegistry`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/BannerDraftingRegistry.gd), executing contiguous package drafting, equipment allocation, stat overflow, and reinforcement wave summons.

---

## 1. Economic Engine & Valuation Metrics

*(These foundational economic and cost mechanics remain permanently anchored across all encounters).*

### 1.1 The Daily Budget Formula
Encounter difficulty scales linearly with each calendar day of the run:

$$\text{Daily Budget } (B) = 3 + (\text{day} - 1)$$

| Day | Daily Budget ($B$) | Baseline Encounter Scope |
| :---: | :---: | :--- |
| **1** | 3 | 3x Tier 1 Level 1 Units |
| **2** | 4 | First Tier 2 Units or Tier 1 with Equipment |
| **3** | 5 | Tier 2 + Tier 1 Synergistic Pairings |
| **5** | 7 | First Tier 3 Units or Fully Equipped Tier 2 Lineups |
| **10** | 12 | Fully Formed 4–5 Unit Synergistic Formations |
| **20** | 22 | High-Tier Formations with Multiple Equipped Items & Secondary Trinkets |

### 1.2 The Standard Valuation Metric (The Gold Standard)
The system uses a unified "Gold Standard" to convert character stats into economic value:
- **1 Gold (or 1 Token)** buys approximately **3 HP** (Durability focus) or **2 PWR** (Offensive/Scaling focus) at T1L1.
- **Leveling** adds exactly **+1 HP and +1 PWR** per level.
- **Stat Hierarchy:** PWR is valued significantly higher than HP because PWR drives scaling multipliers (AoE, Lifesteal, Spikes scaling, Cascade). 1 point of PWR generates more interaction surplus than 1 point of HP.

### 1.3 Entity Cost Tables
Tiered units and items have standardized economic values:

| Tier | Value (Gold) | Cost (Tokens) | Level Multiplier |
| :---: | :---: | :---: | :---: |
| **Tier 1** | 1 Gold | 1 Token | $1 \times 2^{(\text{Level}-1)}$ |
| **Tier 2** | 2 Gold | 2 Tokens | $2 \times 2^{(\text{Level}-1)}$ |
| **Tier 3** | 4 Gold | 3 Tokens | $4 \times 2^{(\text{Level}-1)}$ |

- **Items:** Value equals their Tier base cost ($1$ Gold for T1, $2$ Gold for T2, $4$ Gold for T3). Units are strictly limited to **1 item per unit** (max 5 items per team). Emblems equipped for trait synergy have **Cost = 0 (Free)**.
- **Secondary Trinkets:** All secondary enemy trinkets cost **5 Gold** each in encounter generation.
- **Banner Trinkets:** Always have **Cost = 0 (Free)**.
- **Elites & Bosses:** Unit costs are **Cost = 0 (Free)**, with support units budgeted via their dedicated Banner Drafter.

### 1.4 Exclusivity & Pool Invariants
- **Player Exclusivity Rule:** Any unit, item, or trinket tagged with `is_player_exclusive = true` (including Hero Sets like Mercenary and Novice, player economies like Tokens/Gold/Discard, and the Bounty status effect) is strictly excluded from enemy encounter generation.
- **Asymmetric Mechanics Exclusion Rule:** Units whose abilities rely strictly on player-side out-of-lineup mechanics are excluded from enemy drafting pools (`EncounterSynergyRegistry.ENEMY_EXCLUDED_UNITS`):
  - `FWAASpeToy` (**Wind-up-kun**): Scales strictly on `PlayerShelf` (enemies have no shelf).
  - `EFFWSpeApp` (**Blendroid**): Scales `on_merge` on `merged_team` (enemies never merge in combat).
  - `FASpeApp` (**Furnair**): Scales with unspent gacha tokens (players spend all tokens before combat).
  - `EFWASpeFod` (**BubbleGunger**): Scales with duplicate team copies and shuffles copies into the gacha machine upon knockout (enemies have no gacha machine).
- **Set Exclusion Rule:** Enemy teams are assembled exclusively from the Universal Neutral Base Set.
- **Tag Exclusion Rule:** Units tagged with `HIDDEN`, `BOSS`, or `TOKEN` are excluded from standard pools and reserved for specific Banner Trinkets or Boss definitions.

---

## 2. Battlefield Slot Generation & Budget Balancing

Starting at Day 1, special battlefield slots can generate on player and enemy lineups, replacing standard slots:
* **Slot Types & Budget Costs:**
  * **Burn Slot:** Costs **3 Gold** of the encounter budget. Applies 1 Burn at Turn Start; stacks on units in this slot do not decay.
  * **Lightning Slot:** Costs **2 Gold** of the encounter budget. Applies 1 Static at Turn Start.
* **Generation Probability by Day:**
  * **Day 1–10:** 10% spawn chance.
  * **Day 11–20:** 40% spawn chance.
  * **Day 21–40:** 75% spawn chance.
  * **Day 41+:** 100% spawn chance.
* **Slot Limits:** Maximum **3 Burn slots** and **3 Lightning slots** per team lineup.
* **Budget Balancing:**
  * Player slot effects deduct directly from the player's generation budget (ensuring at least 1 Gold remains for units).
  * Enemy slot effects increase the enemy encounter's generation budget.
  * The net change ($\text{enemy\_bonus} - \text{player\_cost}$) is applied to the final enemy lineup budget to maintain equilibrium:
    $$\text{effective\_budget} = \max(1, \text{daily\_budget} + (\text{enemy\_bonus} - \text{player\_cost}))$$

---

## 3. Encounter Scheduling & Map RNG

### 3.1 Milestone Boss Battle Scheduling (Mastery-Driven)
Boss battles are triggered strictly by **Flashcard Deck Mastery Progression**, not fixed calendar days:
- **Full Deck (Standard):** Occurs at **20%, 40%, 60%, 80%, and 100%** of the selected deck unlocked. Maximum 5 Bosses per run.
- **Half Deck (Quick Run):** Occurs at **33.3%, 66.6%, and 100%** of the deck unlocked. Maximum 3 Bosses per run.
- **Dynamic Selection (No Predefined Order):** There is **no static boss sequencing** (e.g. no fixed "Boss 1", "Boss 2", "Boss 3"). Bosses (`boss_dustmon`, `boss_toughmon`, `boss_doppelkun`) are selected dynamically from the milestone pool using the Unified Weighted Decay algorithm.

### 3.2 Elite Battle Scheduling & Inventory-Bound Quota
Elite nodes are high-risk, high-reward optional encounters paced toward upcoming Bosses:
- **Progress-Paced Milestones:** Crossing **20%, 40%, 60%, and 80%** of the cards required for the next boss level guarantees that an Elite battle node is included as one of the 3 path choices.
- **Inventory-Bound Lifetime Quota (12 Trinkets):** Players have a maximum capacity of **12 trinkets per run**. Consequently, a player can fight a baseline maximum of **12 Elite battles per run**.
  * **Trinket Liquidation Rule:** If the player sells a trinket in the Shop, an additional Elite encounter is restored to their available run pool ($+1$ Elite encounter per trinket sold), allowing strategic players to hunt additional elites if they curate their trinket inventory.
- **Per-Tier Quota Limit:** Players can fight at most **4 Elite battles per mini-boss tier** (quota resets to 0 upon defeating each mini-boss).
- **Elite Pool:** Selected dynamically between `elite_slimeblob` and `elite_burnie` using Weighted Decay.

### 3.3 Map Generation RNG (Seeded PRNG)
Map path generation is deterministically driven by `RNGManager.map_rng` derived from `RunState.run_seed`:
- **Regular Battles (Priority 1):** Dominant base weight of **1500** (~96%–98% appearance rate across 3-path options).
- **Elite Battles (Priority 2):** Base weight of **350** when eligible and under quota.
- **Non-Battle Encounters (Equal Priority):** Base weight of **100** each:
  - Shop (`SHOP`)
  - Merge Encounter (`MERGE`)
  - Shrine (`SHRINE`)
  - Surprise Event (`SURPRISE`)
  - Unit Training Ground / Dojo (`DOJO`)
- **Pity System:** For every day an encounter type is *not* offered, it gains **+10** to its weight until offered, which resets the pity bonus.
- **Study Sessions:** Non-combat encounters can activate a Study Session (Flashcard challenge) for **5 Gold** once per visit to earn tokens.

---

## 4. Unified Weighted Decay Selection Algorithm

When selecting regular banners, elites, or milestone bosses, the generator applies exponential history decay with an immediate repeat penalty:

$$\text{Weight}(B) = \frac{100}{1 + (\text{Encounter Count} \times 2)} \times (0.20 \text{ if } B == \text{Last Encounter})$$

This prevents monotonous repeat battles while allowing seeded diversity throughout a run.

### 4.1 Regular Banners Pool
- `trinket_banner_lone_whale` (The Lone Whale Banner)
- `trinket_banner_swarm` (The Swarm Banner)
- `trinket_banner_fire_phalanx` (The Fire Banner)
- `trinket_banner_<trait>` for Earth, Water, Air, Tank, Fighter, Support, Plant, Food, Animal, Mecha, Toy, Appliance, and Costume.

Trait banners enter this pool only when the effective budget (after slot effects) can afford a functioning core and its first trait threshold. All trait banners include their matching free crest and approved emblem-bearing partners. Mercenary, Novice and Specialist are excluded. See `BannerDraftingSystem.md` for measured minimum budgets and wave policies.

### 4.2 Elite Banners Pool
- `elite_slimeblob` $\longrightarrow$ `trinket_banner_slimeblob`
- `elite_burnie` $\longrightarrow$ `trinket_banner_burnie`

### 4.3 Milestone Bosses Pool
- `boss_dustmon` $\longrightarrow$ `trinket_banner_dustmon`
- `boss_toughmon` $\longrightarrow$ `trinket_banner_toughmon`
- `boss_doppelkun` $\longrightarrow$ `trinket_banner_doppelkun`

---

## 5. Delegation to the Banner Drafting System

Once the banner or boss is selected, `EncounterGenerator.gd` delegates lineup assembly and reinforcement drafting directly to [`BannerDraftingRegistry`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/systems/encounter/BannerDraftingRegistry.gd):

```gdscript
# Regular Encounter
var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(chosen_banner)
var encounter: EncounterDefinition = drafter.draft_lineup(effective_budget)

# Elite & Boss Encounters
var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter_for_entity(chosen_entity)
var encounter: EncounterDefinition = drafter.draft_lineup(support_budget, {"daily_budget": daily_budget})

# Mid-Combat Reinforcements
var drafter: BannerDrafter = BannerDraftingRegistry.get_drafter(banner_id)
return EncounterGenerator.generate_banner_reinforcements(
    banner_id, daily_budget, current_board, empty_slots,
    active_secondary_trinkets, rng, board_snapshot
)
```

For complete specifications on banner drafting mechanics, package contiguous chaining, Dustmon trait/emblem injection, Toughmon tank emblem injection, Doppelkun mimic rules, and reinforcement wave cadences:

$$\longrightarrow \text{See } \textbf{docs/BannerDraftingSystem.md}$$
$$\longrightarrow \text{See } \textbf{docs/Encounter\_Synergies\_and\_Pairs\_Reference.md}$$
