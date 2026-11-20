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
The next Boss becomes the only Crossroads choice when enough cards in the selected run Deck are currently at Mastery Level 3 or higher. Cards that drop below Level 3 stop counting. Thresholds round up, with the final Boss at 80% of the selected pool.

| Deck mode | Mastery thresholds | Example |
| --- | --- | --- |
| Full Deck | 16%, 32%, 48%, 64%, 80% | 16, 32, 48, 64, 80 cards in a 100-card Deck |
| Half Deck | Three evenly spaced thresholds through 80% | 14, 27, 40 cards in a 50-card Deck |

`RunState` reveals the next Boss at the start of its leg. Later Boss previews unlock at fifths of the Full Deck or thirds of the Half Deck as cards are introduced. `EncounterGenerator.pick_boss_identity()` uses a seed derived from the run seed and milestone number with the weighted history below. `RunState` saves the revealed identity and the actual encounter uses it to resolve the Boss and its Banner.

### 3.2 Elite Battle Scheduling & Inventory-Bound Quota
Elite nodes are high-risk, high-reward optional encounters paced toward upcoming Bosses:
- Elite milestones at **20%, 40%, 60%, and 80%** use unlocked-card progress within the current boss tier. An eligible, unoffered milestone adds an Elite to the Crossroads choices unless the Boss is due.
- The run quota uses **12 Elite victories**. The player has **9 trinket slots**.
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

## 6. Player Shop and Reward Pools

[WeightedPoolDirector](../scripts/systems/director/WeightedPoolDirector.gd) applies stock and reward weights with the relevant seeded stream. Initial stock and rerolls use a fresh snapshot of the player's run inventory and equipped trinkets.

| Source | Eligible offerings | Roll |
| --- | --- | --- |
| Shop stock and rerolls | Universal and active Hero Set unit and item capsules | Three distinct offers using `shop_rng` |
| Regular reward machines | Universal and active Hero Set unit and item capsules of the selected tier | One capsule per paid draw using `reward_rng` |
| Elite and Boss reward stock and rerolls | Eligible unowned universal and active Hero Set trinkets | Up to three distinct offers using `reward_rng` |

The director starts with the definition's base weight and its existing dynamic rules. Offer affinity adds 15% per exact unit copy in the run’s tier machines and per match for the candidate's strongest matching trait or set. Each machine unit contributes once per matching trait. An owned Crest adds one match for its trait. A linked trinket uses its linked trait for affinity. Affinity uses active unit tags, including run-specific Hero Set tags.

### Crest offer weight

Each distinct Crest in the player's trinket slots counts toward the total, including the starting Crest. A Crest is the trinket ID registered for its linked trait in `Constants.TRAIT_DEFINITIONS`. Insignias, Emblems, other trinkets, and enemy Banners are outside that count. Already owned trinket IDs are excluded before the roll.

Apply the following factor to the affinity-adjusted weight of each new Crest. Each Crest owned from the second onward multiplies that weight by 0.35. This makes the third Crest less common and keeps later Crests eligible at progressively lower weights.

| Distinct Crests owned | New Crest weight multiplier |
| --- | ---: |
| 0–1 | 1.0 |
| 2 | 0.35 |
| 3 | 0.1225 |
| 4 | 0.042875 |
| 5+ | 0.35 raised to the number of Crests owned minus 1 |

These are relative weights in a roll. The probability of seeing a Crest depends on the other eligible offers in the pool. Other trinkets use their ordinary weights and affinity.
