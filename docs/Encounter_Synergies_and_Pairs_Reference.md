# Encounter Synergies, Pairs & Equipment Reference

## Overview

This document is the authoritative master reference for all **Unit-by-Unit Positional Synergies**, **Front & Behind Pair Partners**, **Curated Atomic Synergy Packages**, **Item Compatibilities**, and **Secondary Trinket Affinities** across all 25 Universal Neutral Base Units.

In this architecture, synergy is evaluated **locally and directionally**:
* **Slot $N$:** The Subject Unit.
* **Front Partner (Slot $N-1$):** A unit placed *directly in front* of the Subject Unit that mechanically enables or protects it.
* **Behind Partner (Slot $N+1$):** A unit placed *directly behind* the Subject Unit that receives buffs, item passes, death-rattles, or backline protection from it.

When assembling or bridging teams, the generator connects units via **Atomic Synergy Packages** (Pairs and Triplets) and directional partner bridging:
$$\text{Slot } 0 \xleftrightarrow{\text{Front/Behind}} \text{Slot } 1 \xleftrightarrow{\text{Front/Behind}} \text{Slot } 2 \xleftrightarrow{\text{Front/Behind}} \text{Slot } 3 \xleftrightarrow{\text{Front/Behind}} \text{Slot } 4$$

> [!IMPORTANT]
> **Asymmetric Mechanics Exclusion (Player-Exclusive Units):**
> Four base units rely strictly on player-side meta-loop mechanics (shelf scaling, gacha machine injection, combat merges, and unspent player tokens) that do not exist or function for enemy teams. These units are **permanently excluded from enemy encounter generation and synergy package pools** (`EncounterSynergyRegistry.ENEMY_EXCLUDED_UNITS`):
> 1. `FWAASpeToy` (**Wind-up-kun**): Scales strictly on `PlayerShelf` (enemies have no shelf).
> 2. `EFFWSpeApp` (**Blendroid**): Scales `on_merge` on `merged_team` (enemies never merge in combat).
> 3. `FASpeApp` (**Furnair**): Scales with unspent gacha tokens (players spend all tokens before combat).
> 4. `EFWASpeFod` (**BubbleGunger**): Scales with duplicate team copies and shuffles copies into the gacha machine upon knockout (enemies have no gacha machine).

---

## 1. Tier 1 Base Units (Cost: 1 Gold)

---

### `ETnkPla` — Stumpling
* **Profile:** Tier 1 | Tank | Earth, Plant | 2 HP / 1 PWR | Melee
* **Ability:** *When hurt by an attack, heal this unit for 1 / 2 / 3 HP.*
* **Preferred Slots:** Slot 0 (Primary Tank) or Slot 1 (Secondary Tank).
* **Front Partners (Slot $N-1$):**
  * `ASpeFod` (**Puffcorn**): Puffcorn dies in front and passes its PWR to Stumpling, transforming Stumpling into a high-PWR, self-healing wall.
  * `EMPTY`: Excellent in Slot 0 taking the enemy's opening hits.
* **Behind Partners (Slot $N+1$):**
  * `WSupAni` (**Ripplepup**): *Top tier combo.* Stumpling heals 1 HP on hurt; Ripplepup heals it for 1 HP on hurt $\rightarrow$ net **+2 HP sustain per hit**.
  * `FWFigFod` (**Pepspray**): In the Food Banner, Stumpling with Food Emblem heals Pepspray behind it through Food's hurt trigger. Pepspray responds to its own healing; Stumpling's self-heal alone does not activate it.
  * `ASpeFod` (**Puffcorn**): Protects backline Puffcorn while it snipes with Ranged attacks.
  * `FFigMec` (**Vulcannon**): Absorbs melee hits while Vulcannon fires safe ranged artillery.
  * `EEFWSupPla` (**Oakbark**): Stumpling absorbs hits, shielding Oakbark while Oakbark buffs Stumpling.
  * `EWAASpeApp` (**Sojikun**): Midline cleansing cover.
* **Item Synergies:** `item_t1_a` Candy (recurring turn heal), `item_t2_c` Anvil (heals + gains PWR on hurt), `item_t3_a` Ramune (heals allies on hurt).
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_plant`, `trinket_trait_tank`, `trinket_spiked_armor` (if in Slot 0), `trinket_purifying_pendant`.

---

### `FFigMec` — Vulcannon
* **Profile:** Tier 1 | Fighter | Fire, Mecha | 1 HP / 2 PWR | Ranged
* **Ability:** *When hurt by an attack, fires a reactive bouncing projectile at the attacker dealing PWR damage (triggers even if knocked out).*
* **Preferred Slots:** Slot 0 (Reactive Counter-Bait) or Slot 3–4 (Safe Artillery).
* **Front Partners (Slot $N-1$):**
  * `ASpeFod` (**Puffcorn**): Puffcorn passes PWR on death; Vulcannon's counter-attack and ranged shots inherit that bonus PWR.
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Heavy tanks absorb hits while Vulcannon fires safe ranged shots from behind.
  * `FFWASupMec` (**Relaytron**): Relaytron dies and passes its equipped item to Vulcannon.
  * `FWFigFod` (**Pepspray**) / `WSupAni` (**Ripplepup**): Midline flame and heal catalyst engine.
  * `EMPTY`: Placed in Slot 0 as a sacrificial mine—when the enemy hits Vulcannon, it retaliates with heavy damage before dying.
* **Behind Partners (Slot $N+1$):**
  * `EWFigCos` (**Bogmantle**): If Vulcannon dies in Slot 0, Bogmantle immediately absorbs $+1/+1$.
* **Item Synergies:** `item_t1_b` Wakizashi (extra attack vs higher HP), `item_t2_b` Scythe (extra action on kill), `item_t3_b` HardCandy (Armor/Spikes on attack).
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_mecha`, `trinket_trait_fighter`, `trinket_vengeance` (low HP $\le 2$).

---

### `WSupAni` — Ripplepup
* **Profile:** Tier 1 | Support | Water, Animal | 1 HP / 1 PWR | Melee
* **Ability:** *When the ally directly in front takes damage, heal them for 1 / 2 / 3 HP.*
* **Preferred Slots:** Slot 1, 2, or 3 (**Never place in Slot 0**—has no ally in front to heal).
* **Directional Healing Rule:** Ripplepup strictly heals the ally **directly in front (Slot $N-1$)**. It does *not* heal allies behind (Slot $N+1$).
* **Front Partners (Slot $N-1$):** *(MANDATORY: Must have an ally in front).*
  * `EFTnkMec` (**Branblee**): *God-tier synergy.* Healing Branblee triggers Branblee's passive to generate **+Armor and +Spikes** on every hit taken. In the Fire Banner, equipping Ripplepup with `item_emblem_fire` adds +2 PWR and grants Fire Soul so it counts toward Fire traits.
  * `ETnkPla` (**Stumpling**): Stacks with Stumpling's self-heal for +2 HP recovery per hit.
  * `EFWATnkApp` (**Reizokun**): Massive HP tank in front; heals ensure Reizokun never falls below threshold.
  * `EWFigCos` (**Bogmantle**): Keeps Bogmantle alive as it grows from knockout triggers.
* **Behind Partners (Slot $N+1$):**
  * `FWFigFod` (**Pepspray**): Sits behind Ripplepup. When Pepspray has self-healing items (Candy/Leech Gumi) or receives heals, it launches bouncing Burn fireballs.
  * `ASpeFod` (**Puffcorn**) / `FFigMec` (**Vulcannon**): Backline ranged DPS protected by the front tank + Ripplepup engine.
* **Item Synergies:** `item_emblem_fire` (Fire Soul + 2 PWR; mandatory in Fire setups), `item_t1_a` Candy (self-sustain), `item_t2_a` Summoning Scroll (spawns replacement frontline if knocked out), `item_t3_a` Ramune.
* **Trinket Votes (5G):** `trinket_trait_water`, `trinket_trait_animal`, `trinket_trait_support`, `trinket_vengeance` (low HP $\le 2$).

---

### `ASpeFod` — Puffcorn
* **Profile:** Tier 1 | Specialist | Air, Food | 1 HP / 1 PWR | Ranged
* **Ability:** *When knocked out, grant current PWR to the ally behind (L2: +50% to 2nd ally behind; L3: +25% to 3rd ally behind).*
* **Preferred Slots:** Slot 0 (Sacrifice Vanguard) or Slot 3–4 (Safe Ranged Sniper).
* **Front Partners (Slot $N-1$):**
  * `EMPTY`: Ideal in Slot 0 to take the first blow, immediately passing its PWR backward.
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Sits in back, using Ranged attacks to bypass enemy Spikes.
  * `ASpeFod` (**Puffcorn**): Compounded death-rattle chain.
  * `FWFigFod` (**Pepspray**) / `WSupAni` (**Ripplepup**): Midline screen.
* **Behind Partners (Slot $N+1$):** *(MANDATORY when in Slot 0).*
  * `FFigMec` (**Vulcannon**): Passes PWR to Vulcannon; Vulcannon's counter-attack and basic shots inherit this damage.
  * `EWFigCos` (**Bogmantle**): Bogmantle gains $+1/+1$ from its own knockout passive PLUS inherits Puffcorn's PWR!
  * `EFTnkMec` (**Branblee**) / `ETnkPla` (**Stumpling**): Empowers tanks with bonus PWR.
  * `EASupToy` (**Matryodust**): Empowers Matryodust before it dies and summons a T1 unit.
  * `ASpeFod` (**Puffcorn**): Chained Puffcorns pass compounded PWR down the formation.
* **Item Synergies:** `item_t1_b` Wakizashi (+1 PWR, double attack), `item_t3_e` Sour Candy (nukes highest HP enemy on death).
* **Trinket Votes (5G):** `trinket_trait_air`, `trinket_trait_food`, `trinket_trait_specialist`, `trinket_vengeance` (prime knockout trigger).

---

## 2. Tier 2 Base Units (Cost: 2 Gold)

---

### `EWFigCos` — Bogmantle
* **Profile:** Tier 2 | Fighter | Earth, Water, Costume | 3 HP / 3 PWR | Melee
* **Ability:** *When an ally is knocked out, gain +1 / +2 / +2 HP and +1 / +1 / +2 PWR.*
* **Preferred Slots:** Slot 1, 2, or 3 (Behind sacrificial units).
* **Front Partners (Slot $N-1$):**
  * `ASpeFod` (**Puffcorn**): Puffcorn dies $\rightarrow$ Bogmantle gets $+1/+1$ from its ability and inherits Puffcorn's PWR.
  * `EASupToy` (**Matryodust**) / `EFAASupToy` (**Matryoshkan**): Multi-stage death trigger engines.
  * `FFigMec` (**Vulcannon**): Vulcannon trades in Slot 0; Bogmantle steps up with boosted stats.
  * `EEFWSupPla` (**Oakbark**): Receives continuous buffs while waiting to strike.
  * `FFWASupMec` (**Relaytron**): Relaytron dies and passes high-tier items to Bogmantle.
* **Behind Partners (Slot $N+1$):**
  * `FWWATnkFod` (**Nuton**): When Bogmantle gains stat buffs from allied deaths, Nuton copies those buffs.
  * `WSupAni` (**Ripplepup**): Heals Bogmantle as it grows larger, making its accumulated HP permanent.
* **Item Synergies:** `item_t2_b` Scythe (gains extra action on kill as its PWR scales), `item_t3_c` Leech Gumi, `item_t1_b` Wakizashi.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_water`, `trinket_trait_fighter`, `trinket_trait_costume`, `trinket_vengeance`, `trinket_soul_echo`.

---

### `FASpeApp` — Furnair [PLAYER-EXCLUSIVE — EXCLUDED FROM ENEMY DRAFTS]
* **Profile:** Tier 2 | Specialist | Fire, Air, Appliance | 2 HP / 3 PWR | Melee
* **Ability:** *Gains bonus PWR equal to 100% / 150% / 200% of current Tokens held, updating dynamically.*
* **Status:** **Excluded from enemy drafting pools.** Retained for player team reference.
* **Preferred Slots:** Slot 2 or 3 (Midline damage dealer).
* **Front Partners (Slot $N-1$):**
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Heavy tank shields Furnair so it delivers high-PWR strikes.
  * `ASpeFod` (**Puffcorn**): Passes additional PWR to Furnair on death.
* **Behind Partners (Slot $N+1$):**
  * `WSupAni` (**Ripplepup**): Sustains Furnair's modest 2 HP pool.
  * `EFWAFigMec` (**Pachinkannon**): Backline ranged follow-up.
* **Item Synergies:** `item_t1_b` Wakizashi, `item_t2_b` Scythe, `item_t3_b` HardCandy (converts high PWR into Armor/Spikes).
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_air`, `trinket_trait_specialist`, `trinket_trait_appliance`.

---

### `EASupToy` — Matryodust
* **Profile:** Tier 2 | Support | Earth, Air, Toy | 3 HP / 2 PWR | Melee
* **Ability:** *When knocked out, summon a random Tier 1 unit with level equal to this unit's level.*
* **Preferred Slots:** Slot 0 (Re-spawning Vanguard) or Slot 1 (Midline Buffer).
* **Front Partners (Slot $N-1$):**
  * `EMPTY`: Sits in Slot 0. Enemy must chew through 3 HP, and upon kill, a fresh T1 spawns into Slot 0 to take the next hit.
  * `ASpeFod` (**Puffcorn**): Puffcorn passes PWR to Matryodust before Matryodust dies.
* **Behind Partners (Slot $N+1$):**
  * `EWFigCos` (**Bogmantle**): Double death-trigger engine (+2/+2 total).
  * `EFFASupMec` (**Mechamom**): When Matryodust summons a T1 unit, Mechamom immediately grants that new unit **+3 / +5 / +7 HP**!
* **Item Synergies:** `item_t2_a` Summoning Scroll (spawns 2 units on death!), `item_t3_e` Sour Candy, `item_t1_a` Candy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_air`, `trinket_trait_support`, `trinket_trait_toy`, `trinket_vengeance`.

---

### `WATnkAni` — Soliwhale
* **Profile:** Tier 2 | Tank | Water, Air, Animal | 2 HP / 2 PWR | Melee
* **Ability:** *Pre-Battle, gain +1 / +2 / +3 HP and PWR for each empty slot on your team.*
* **Preferred Slots:** **Slot 0 exclusively** (Raid Boss initiative).
* **Front Partners (Slot $N-1$):**
  * `EMPTY` (Strictly empty).
* **Behind Partners (Slot $N+1$):**
  * `EMPTY` (Strictly empty). Soliwhale pairs with **empty space**, not units!
* **Item Synergies:** `item_t2_c` Anvil, `item_t3_b` HardCandy, `item_t3_c` Leech Gumi, `item_t3_d` Rubber Ball, `item_t1_a` Candy.
* **Trinket Votes (5G):** `trinket_underdog_emblem`, `trinket_spiked_armor`, `trinket_polished_plate`, `trinket_aegis`, `trinket_rusty_ring`.

---

### `EFTnkMec` — Branblee
* **Profile:** Tier 2 | Tank | Earth, Fire, Mecha | 3 HP / 2 PWR | Melee
* **Ability:** *When healed, gain 1 / 2 / 3 Armor and 1 / 2 / 3 Spikes.*
* **Preferred Slots:** Slot 0 (Primary Thorn Wall) or Slot 1 (Protected Spikes Ramp).
* **Front Partners (Slot $N-1$):**
  * `ASpeFod` (**Puffcorn**): Dies, giving Branblee high PWR so its basic attacks hit hard alongside its Spikes.
  * `EMPTY`: Sits in Slot 0 to immediately receive melee hits and reflect Spikes.
* **Behind Partners (Slot $N+1$):**
  * `WSupAni` (**Ripplepup**): *The engine partner.* Every time Branblee is hit, Ripplepup heals it $\rightarrow$ Branblee gains +Armor and +Spikes!
  * `FWFigFod` (**Pepspray**): Sits behind Ripplepup in pyre setups; triggers fireballs when healed via equipment.
  * `FFigMec` (**Vulcannon**) / `ASpeFod` (**Puffcorn**): Ranged artillery firing safely from behind Branblee's Spikes.
  * `EEFASpeCos` (**Mimicloak**) / `EEFWSupPla` (**Oakbark**): Protected midline utility and adjacent buff engine.
  * `EEWAFigAni` (**Griffoam**) / `EFWWFigCos` (**Tsunamantle**) / `EWWATnkToy` (**Komatop**): Mid-to-rear damage scaling and intercept defense.
  * `EWAASpeApp` (**Sojikun**): Midline cleansing cover.
* **Item Synergies:** `item_t1_a` Candy (turn-start heal triggers Armor/Spikes passively), `item_t2_c` Anvil, `item_t3_b` HardCandy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_tank`, `trinket_trait_mecha`, `trinket_spiked_armor`, `trinket_polished_plate`.

---

### `FWFigFod` — Pepspray
* **Profile:** Tier 2 | Fighter | Fire, Water, Food | 2 HP / 3 PWR | Melee
* **Ability:** *When healed, shoots a bouncing Fireball at a random enemy applying Burn equal to the heal amount.*
* **Preferred Slots:** Slot 2 or 3 (Midline pyre engine).
* **Heal Activation Rules:**
  * Pepspray triggers only when **Pepspray itself receives a heal**. Ripplepup heals forward to Slot $N-1$, so Ripplepup in Slot 1 does not trigger Pepspray in Slot 2 directly.
  * In standard formations (Branblee Slot 0, Ripplepup Slot 1, Pepspray Slot 2), Pepspray activates its Fireball barrage via **self-healing equipment** (`item_t1_a` Candy for turn-start heals; `item_t3_c` Leech Gumi for attack heals) or team heals (`item_t3_a` Ramune).
* **Front Partners (Slot $N-1$):**
  * `WSupAni` (**Ripplepup**): Shields Pepspray with midline healing support for the front tank.
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Heavy frontline walls absorbing opening burst.
* **Behind Partners (Slot $N+1$):**
  * `ASpeFod` (**Puffcorn**) / `FFigMec` (**Vulcannon**): Backline ranged fire synergy.
  * `EFWAFigMec` (**Pachinkannon**): Artillery backline support.
* **Item Synergies:** `item_t1_a` Candy (self-heal triggers fireball), `item_t3_c` Leech Gumi (attack heals trigger fireballs!).
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_fighter`, `trinket_trait_food`.

---

## 3. Tier 3 Base Units (Cost: 4 Gold)

---

### `EEFASpeCos` — Mimicloak
* **Profile:** Tier 3 | Specialist | 2x Earth, Fire, Air, Costume | 6 HP / 4 PWR | Melee
* **Ability:** *At turn start, transforms into a mirror copy of the enemy unit opposite to it and takes its turn.*
* **Preferred Slots:** Slot 0, 1, or 2 (Placed opposite key player carries).
* **Front Partners (Slot $N-1$):**
  * `EFTnkMec` (**Branblee**) / `EWWATnkToy` (**Komatop**): Protects Mimicloak if placed in mid-slots.
  * `EMPTY`: In Slot 0 to mirror the player's front tank immediately.
* **Behind Partners (Slot $N+1$):**
  * `EWAASpeApp` (**Sojikun**): Cleanses negative effects from Mimicloak before it transforms.
* **Item Synergies:** `item_t2_b` Scythe, `item_t1_b` Wakizashi, `item_t3_b` HardCandy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_air`, `trinket_trait_specialist`, `trinket_trait_costume`.

---

### `EEFWSupPla` — Oakbark
* **Profile:** Tier 3 | Support | 2x Earth, Fire, Water, Plant | 6 HP / 5 PWR | Melee
* **Ability:** *When hurt by an attack, grants +1/+1 (L1), +2/+1 (L2), +2/+2 (L3) to adjacent allies.*
* **Preferred Slots:** **Slot 1 or 2 exclusively** (Must have adjacent allies on both sides to maximize value).
* **Front Partners (Slot $N-1$):**
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Heavy tank in front takes damage; Oakbark buffs it whenever Oakbark takes AoE or overflow hits.
* **Behind Partners (Slot $N+1$):**
  * `FWWATnkFod` (**Nuton**): *The supreme synergy.* Oakbark buffs both Slot $N-1$ and Nuton (Slot $N+1$); Nuton copies the buff given to Slot $N-1$ as well!
  * `EWFigCos` (**Bogmantle**): Receives continuous buffs while waiting to strike.
* **Item Synergies:** `item_t1_a` Candy, `item_t2_c` Anvil, `item_t3_a` Ramune (spreads heals while Oakbark spreads stats).
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_support`, `trinket_trait_plant`, `trinket_armor_aura`.

---

### `EEWAFigAni` — Griffoam
* **Profile:** Tier 3 | Fighter | 2x Earth, Water, Air, Animal | 6 HP / 5 PWR | Melee
* **Ability:** *Deals 1 / 2 / 3 ranged damage to any unit that enters the active lineup by any means (shelf, summon, merge, transform).*
* **Preferred Slots:** Slot 2, 3, or 4 (Keep safe in backline to punish player spawns).
* **Front Partners (Slot $N-1$):**
  * `EFTnkMec` (**Branblee**) / `EFWATnkApp` (**Reizokun**): Heavy tanks keep Griffoam alive to maintain its spawn-sniping aura all combat.
  * `EWWATnkToy` (**Komatop**): Intercepts lethal damage aimed at Griffoam.
* **Behind Partners (Slot $N+1$):**
  * `EFWAFigMec` (**Pachinkannon**): Dual backline artillery barrage.
* **Item Synergies:** `item_t1_b` Wakizashi, `item_t2_b` Scythe, `item_t3_f` Popcorn.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_fighter`, `trinket_trait_animal`.

---

### `EFAASupToy` — Matryoshkan
* **Profile:** Tier 3 | Support | Earth, Fire, 2x Air, Toy | 5 HP / 5 PWR | Melee
* **Ability:** *When knocked out, summon a Level 1 / 2 / 3 Tier 2 Matryodust.*
* **Preferred Slots:** Slot 0 or 1 (3-stage Russian doll vanguard).
* **Front Partners (Slot $N-1$):**
  * `EMPTY`: Sits in Slot 0. Dies $\rightarrow$ summons Matryodust $\rightarrow$ Matryodust dies $\rightarrow$ summons T1 unit. 3 lives in a single slot!
* **Behind Partners (Slot $N+1$):**
  * `EWFigCos` (**Bogmantle**): Gains $+1/+1$ three separate times from this single slot dying!
  * `EFFASupMec` (**Mechamom**): Grants bonus HP to both Matryodust and the subsequent T1 unit when they spawn.
* **Item Synergies:** `item_t2_a` Summoning Scroll, `item_t3_e` Sour Candy, `item_t2_c` Anvil.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_air`, `trinket_trait_support`, `trinket_trait_toy`, `trinket_vengeance`.

---

### `EFFASupMec` — Mechamom
* **Profile:** Tier 3 | Support | Earth, 2x Fire, Air, Mecha | 5 HP / 5 PWR | Melee
* **Ability:** *Newly summoned allies gain +3 / +5 / +7 HP upon entering the board.*
* **Preferred Slots:** Slot 3 or 4 (Protected rear engine).
* **Front Partners (Slot $N-1$):**
  * `EASupToy` (**Matryodust**) / `EFAASupToy` (**Matryoshkan**): Both units spawn replacements in front of Mechamom; Mechamom instantly gives them +HP.
* **Behind Partners (Slot $N+1$):**
  * `EFWAFigMec` (**Pachinkannon**): Artillery cover.
* **Item Synergies:** `item_t1_a` Candy, `item_t2_a` Summoning Scroll (spawns an extra buffed unit on death).
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_air`, `trinket_trait_support`, `trinket_trait_mecha`.

---

### `EFFWSpeApp` — Blendroid [PLAYER-EXCLUSIVE — EXCLUDED FROM ENEMY DRAFTS]
* **Profile:** Tier 3 | Specialist | Earth, 2x Fire, Water, Appliance | 5 HP / 5 PWR | Melee
* **Ability:** *Whenever a merge occurs on the battle board, gain +2 / +3 / +4 HP and PWR.*
* **Status:** **Excluded from enemy drafting pools.** Retained for player team reference.
* **Preferred Slots:** Slot 1 or 2 (Midline scaling fighter).
* **Front Partners (Slot $N-1$):**
  * `ETnkPla` (**Stumpling**) / `EFTnkMec` (**Branblee**): Standard defensive cover.
* **Behind Partners (Slot $N+1$):**
  * `FWWATnkFod` (**Nuton**): Copies Blendroid's merge stat boosts.
* **Item Synergies:** `item_t2_b` Scythe, `item_t3_b` HardCandy, `item_t3_c` Leech Gumi.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_specialist`, `trinket_trait_appliance`.

---

### `EFWAFigMec` — Pachinkannon
* **Profile:** Tier 3 | Fighter | Earth, Fire, Water, Air, Mecha | 5 HP / 5 PWR | Ranged
* **Ability:** *Ranged attacks bounce 1 / 2 / 3 times to random enemies, halving damage per bounce.*
* **Preferred Slots:** **Slot 3 or 4 exclusively** (Backline Ranged Artillery).
* **Front Partners (Slot $N-1$):**
  * `EWWATnkToy` (**Komatop**): Intercepts lethal damage aimed at Pachinkannon so it fires safely.
  * `EFWATnkApp` (**Reizokun**): Heavy front wall preventing melee penetration.
  * `EEWAFigAni` (**Griffoam**) / `EFFASupMec` (**Mechamom**): Midline support buffers.
* **Behind Partners (Slot $N+1$):**
  * `EMPTY`: Sits at the back of the line.
* **Item Synergies:** `item_t3_f` Popcorn (steals PWR across all bounce targets!), `item_t2_b` Scythe, `item_t1_b` Wakizashi.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_fighter`, `trinket_trait_mecha`.

---

### `EFWASpeFod` — BubbleGunger [PLAYER-EXCLUSIVE — EXCLUDED FROM ENEMY DRAFTS]
* **Profile:** Tier 3 | Specialist | Earth, Fire, Water, Air, Food | 5 HP / 4 PWR | Melee
* **Ability:** *Gains +3 / +4 / +5 PWR for each other BubbleGunger in battle. When knocked out, adds 1 copy into the Gacha Machine.*
* **Status:** **Excluded from enemy drafting pools.** Retained for player team reference.
* **Preferred Slots:** Slot 1, 2, or 3 (Clustered with duplicate copies).
* **Front Partners (Slot $N-1$):**
  * `EFWASpeFod` (**BubbleGunger**) or `EFTnkMec` (**Branblee**).
* **Behind Partners (Slot $N+1$):**
  * `EFWASpeFod` (**BubbleGunger**).
* **Item Synergies:** `item_t1_b` Wakizashi, `item_t2_b` Scythe, `item_t3_b` HardCandy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_specialist`, `trinket_trait_food`, `trinket_twin_charm`.

---

### `EFWATnkApp` — Reizokun
* **Profile:** Tier 3 | Tank | Earth, Fire, Water, Air, Appliance | 5 HP / 6 PWR | Melee
* **Ability:** *Before taking damage, gain +2 / +4 / +6 HP.*
* **Preferred Slots:** **Slot 0** (Primary Behemoth Wall).
* **Front Partners (Slot $N-1$):**
  * `EMPTY`: Unstoppable opening sponge in Slot 0.
* **Behind Partners (Slot $N+1$):**
  * `WSupAni` (**Ripplepup**): Heals Reizokun to ensure its HP pool never depletes.
  * `EWWATnkToy` (**Komatop**): Backs up Reizokun if extreme burst breaks through.
  * `EFWWFigCos` (**Tsunamantle**): Reizokun buys time for Tsunamantle's Cascade attacks.
  * `EEWAFigAni` (**Griffoam**) / `EFWAFigMec` (**Pachinkannon**): Safe midline and backline pressure.
  * `EWAASpeApp` (**Sojikun**): Midline cleansing cover.
* **Item Synergies:** `item_t2_c` Anvil, `item_t3_b` HardCandy, `item_t1_a` Candy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_tank`, `trinket_spiked_armor`, `trinket_polished_plate`.

---

### `EFWWFigCos` — Tsunamantle
* **Profile:** Tier 3 | Fighter | Earth, Fire, 2x Water, Costume | 5 HP / 6 PWR | Melee
* **Ability:** *Instead of attacking, deals 100% / 150% / 200% PWR damage as a Cascade attack to the frontmost enemy, spilling backward into enemies behind.*
* **Preferred Slots:** Slot 1 or 2 (Directly behind a sacrifice unit or tank).
* **Front Partners (Slot $N-1$):**
  * `FFWASupMec` (**Relaytron**): Relaytron dies and passes its offensive item to Tsunamantle.
  * `EFWATnkApp` (**Reizokun**) / `EFTnkMec` (**Branblee**) / `EWWATnkToy` (**Komatop**): Shields Tsunamantle while its Cascade clears the opposing lineup.
* **Behind Partners (Slot $N+1$):**
  * `FWWATnkFod` (**Nuton**): Copies stat buffs applied to Tsunamantle.
* **Item Synergies:** `item_t2_b` Scythe (cascade kills trigger extra actions!), `item_t3_b` HardCandy, `item_t1_b` Wakizashi.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_fighter`, `trinket_trait_costume`.

---

### `EWAASpeApp` — Sojikun
* **Profile:** Tier 3 | Specialist | Earth, Water, 2x Air, Appliance | 5 HP / 4 PWR | Ranged
* **Ability:** *At turn start, cleanses negative status from adjacent allies. When attacking, cleanses all positive status (Armor, Spikes, Reinforce) from the target.*
* **Preferred Slots:** Slot 2 or 3 (Midline Utility).
* **Front Partners (Slot $N-1$):**
  * `EEFASpeCos` (**Mimicloak**): Cleanses negative effects from Mimicloak before it transforms.
  * Any frontline Tank (`ETnkPla`, `EFTnkMec`, `EFWATnkApp`, `EWWATnkToy`) suffering from Burn or Static.
* **Behind Partners (Slot $N+1$):**
  * `EMPTY`: Sits in midline utility position.
* **Item Synergies:** `item_t1_b` Wakizashi, `item_t3_c` Leech Gumi, `item_t3_f` Popcorn.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_specialist`, `trinket_trait_appliance`.

---

### `EWWATnkToy` — Komatop
* **Profile:** Tier 3 | Tank | Earth, 2x Water, Air, Toy | 5 HP / 5 PWR | Melee
* **Ability:** *Leaps to intercept lethal damage targeting allies, taking the blow instead. Gains 0 / 1 / 2 Armor when intercepting.*
* **Preferred Slots:** Slot 1 or 2 (Positioned to guard fragile carries).
* **Front Partners (Slot $N-1$):**
  * `EFWATnkApp` (**Reizokun**) / `EFTnkMec` (**Branblee**): Komatop guards the front tank against lethal overkill.
* **Behind Partners (Slot $N+1$):**
  * `EFWAFigMec` (**Pachinkannon**) / `EFWWFigCos` (**Tsunamantle**): Komatop intercepts lethal ranged shots or snipes aimed at backline carries.
  * `EEFASpeCos` (**Mimicloak**) / `EEWAFigAni` (**Griffoam**): Intercepts lethal damage aimed at midline carries.
  * `EWAASpeApp` (**Sojikun**): Midline cleansing cover.
* **Item Synergies:** `item_t2_c` Anvil, `item_t3_b` HardCandy, `item_t1_a` Candy.
* **Trinket Votes (5G):** `trinket_trait_earth`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_tank`, `trinket_trait_toy`, `trinket_aegis`, `trinket_polished_plate`.

---

### `FFWASupMec` — Relaytron
* **Profile:** Tier 3 | Support | 2x Fire, Water, Air, Mecha | 5 HP / 5 PWR | Melee
* **Ability:** *When knocked out, transfers equipped item to the ally directly behind (L2: duplicates 1 copy; L3: duplicates 2 copies).*
* **Preferred Slots:** **Slot 0 or 1** (Must die before the unit behind it).
* **Front Partners (Slot $N-1$):**
  * `EMPTY`: Sits in Slot 0 carrying a top-tier item (Scythe or HardCandy) to pass it backward upon death.
* **Behind Partners (Slot $N+1$):** *(MANDATORY).*
  * `EFWWFigCos` (**Tsunamantle**): Receives Scythe to turn its Cascade into extra-action sweeps.
  * `EWFigCos` (**Bogmantle**): Receives Scythe/HardCandy alongside $+1/+1$ from Relaytron's death.
  * `FFigMec` (**Vulcannon**): Inherits items to amplify counter-attacks.
* **Item Synergies:** `item_t2_b` Scythe, `item_t3_b` HardCandy, `item_t3_c` Leech Gumi.
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_support`, `trinket_trait_mecha`, `trinket_vengeance`.

---

### `FWAASpeToy` — Wind-up-kun [PLAYER-EXCLUSIVE — EXCLUDED FROM ENEMY DRAFTS]
* **Profile:** Tier 3 | Specialist | Fire, Water, 2x Air, Toy | 4 HP / 5 PWR | Melee
* **Ability:** *At turn start, if placed on the shelf, gains +3 / +5 / +7 HP and PWR.*
* **Status:** **Excluded from enemy drafting pools.** Retained for player team reference.
* **Preferred Slots:** Player Shelf (scales during battle).
* **Front Partners (Slot $N-1$):**
  * Any frontline Tank (`EFTnkMec`, `EFWATnkApp`).
* **Behind Partners (Slot $N+1$):**
  * `FWWATnkFod` (**Nuton**): Copies stat buffs when Wind-up-kun enters the field.
* **Item Synergies:** `item_t2_b` Scythe, `item_t3_c` Leech Gumi, `item_t1_b` Wakizashi.
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_specialist`, `trinket_trait_toy`.

---

### `FWWATnkFod` — Nuton
* **Profile:** Tier 3 | Tank | Fire, 2x Water, Air, Food | 4 HP / 5 PWR | Melee
* **Ability:** *Whenever an adjacent ally receives a stat buff, copy buff at 100% / 150% / 200% effectiveness.*
* **Preferred Slots:** **Slot 2** (Center of formation, flanked by buffing allies on both sides).
* **Front Partners (Slot $N-1$):**
  * `EEFWSupPla` (**Oakbark**): *The golden synergy.* When Oakbark buffs its neighbors, Nuton receives its own buff AND copies the buff Oakbark gave to Slot 0!
  * `EWFigCos` (**Bogmantle**): When Bogmantle buffs itself on allied deaths, Nuton copies the buff!
  * `EFWWFigCos` (**Tsunamantle**): Copies stat buffs applied to allies.
* **Behind Partners (Slot $N+1$):**
  * `EMPTY`: Positioned at the center/flank of formation.
* **Item Synergies:** `item_t1_a` Candy, `item_t2_c` Anvil, `item_t3_b` HardCandy.
* **Trinket Votes (5G):** `trinket_trait_fire`, `trinket_trait_water`, `trinket_trait_air`, `trinket_trait_tank`, `trinket_trait_food`, `trinket_armor_aura`.

---

## 4. Curated Atomic Synergy Packages (Pairs & Triplets)

Rather than assembling teams through uncoordinated single-slot rolling, the encounter generation engine drafts cohesive multi-unit packages defined in `EncounterSynergyRegistry.SYNERGY_PACKAGES`.

Packages enforce exact positional ordering, required combos, pre-equipped items, and budget feasibility.

### 4.1 Tier 1 Pairs (Base Cost: 2 Gold)

| Package ID | Units (Slot $N$, $N+1$) | Valid Slots | Cost | Tags | Synergy & Tactical Strategy |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `pair_stumpling_ripplepup` | `ETnkPla` (Stumpling) + `WSupAni` (Ripplepup) | 0, 1 | 2G | Tank, Support, Earth, Water | **Infinite Sustain Wall:** Stumpling heals on hit; Ripplepup in Slot $N+1$ heals front ally on hit. Combines into +2 HP recovery per blow taken. |
| `pair_puffcorn_vulcannon` | `ASpeFod` (Puffcorn) + `FFigMec` (Vulcannon) | 0 | 2G | Specialist, Fighter, Air, Fire | **Sacrificial Mine:** Puffcorn in Slot 0 takes opening hits and dies, passing its PWR backward to Vulcannon. Vulcannon unleashes boosted reactive counter-attacks and ranged shots. |
| `pair_stumpling_vulcannon` | `ETnkPla` (Stumpling) + `FFigMec` (Vulcannon) | 0, 1, 2 | 2G | Tank, Fighter, Earth, Fire | **Shield & Gun:** Heavy self-healing tank shields backline Vulcannon while it snipes with safe ranged fire. |

---

### 4.2 Tier 2 & Cross-Tier Pairs (Base Cost: 3G – 6G)

| Package ID | Units (Slot $N$, $N+1$) | Valid Slots | Cost | Tags | Synergy & Tactical Strategy |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `pair_branblee_ripplepup` | `EFTnkMec` (Branblee) + `WSupAni` (Ripplepup) | 0, 1 | 3G | Tank, Support, Fire, Earth, Water | **Thorn Reactor:** Ripplepup heals Branblee every time Branblee is hurt $\rightarrow$ Branblee generates +Armor and +Spikes on every blow. |
| `pair_puffcorn_bogmantle` | `ASpeFod` (Puffcorn) + `EWFigCos` (Bogmantle) | 0, 1 | 3G | Specialist, Fighter, Air, Earth | **Deathrattle Ascension:** Puffcorn dies in front $\rightarrow$ Bogmantle gains $+1/+1$ from its own knockout passive PLUS inherits Puffcorn's PWR! |
| `pair_branblee_vulcannon` | `EFTnkMec` (Branblee) + `FFigMec` (Vulcannon) | 0, 1, 2 | 3G | Tank, Fighter, Fire, Earth | **Spikes & Artillery:** Branblee punishes melee attackers while Vulcannon safely bombards opposing ranks. |
| `pair_stumpling_branblee` | `ETnkPla` (Stumpling) + `EFTnkMec` (Branblee) | 0 | 3G | Tank, Earth, Fire | **Double Vanguard:** Tier 1 self-healing wall backed by a Tier 2 Spikes wall, absorbing heavy melee aggression. |
| `pair_matryodust_bogmantle` | `EASupToy` (Matryodust) + `EWFigCos` (Bogmantle) | 0, 1 | 4G | Support, Fighter, Earth, Toy | **Double Death Trigger:** Matryodust dies, granting $+1/+1$ to Bogmantle and summoning a T1 unit that also feeds Bogmantle upon death. |
| `pair_reizokun_ripplepup` | `EFWATnkApp` (Reizokun) + `WSupAni` (Ripplepup) | 0 | 5G | Tank, Support, Water, Appliance | **Unstoppable Glacial Engine:** Pre-damage HP buffering combined with reactive healing ensures Reizokun remains impenetrable. |
| `pair_matryodust_mechamom` | `EASupToy` (Matryodust) + `EFFASupMec` (Mechamom) | 0, 1, 2 | 6G | Support, Toy, Mecha | **Doll Nursery:** When Matryodust is knocked out and summons a T1 unit, Mechamom immediately grants that new spawn +3 HP! |
| `pair_bogmantle_nuton` | `EWFigCos` (Bogmantle) + `FWWATnkFod` (Nuton) | 1 | 6G | Fighter, Tank, Food | **Buff Mirroring:** Whenever an ally dies and Bogmantle gains $+1/+1$, Nuton copies those exact stat buffs! |
| `pair_branblee_komatop` | `EFTnkMec` (Branblee) + `EWWATnkToy` (Komatop) | 0, 1 | 6G | Tank, Toy, Mecha | **Aegis Wall:** Branblee ramps Spikes while Komatop leaps to intercept lethal damage, gaining Armor on intercept. |

---

### 4.3 Tier 3 Pairs (Base Cost: 8G – 10G)

| Package ID | Units (Slot $N$, $N+1$) | Valid Slots | Cost | Tags | Synergy & Tactical Strategy |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `pair_matryoshkan_mechamom` | `EFAASupToy` (Matryoshkan) + `EFFASupMec` (Mechamom) | 0, 1, 2 | 8G | Support, Toy, Mecha | **Multi-Stage Nursery:** Matryoshkan dies and summons Matryodust, which dies and summons a T1 unit. Mechamom buffs every spawn with +3 HP! |
| `pair_oakbark_nuton` | `EEFWSupPla` (Oakbark) + `FWWATnkFod` (Nuton) | 1 | 8G | Support, Tank, Plant, Food | **Direct Buff Recipient:** Oakbark buffs adjacent Nuton directly. Nuton cannot additionally copy the buff given to Slot $N-1$, which is two slots away from Nuton. Use the new Oakbark/Bogmantle/Nuton triplet for a true copied-buff chain. |
| `pair_komatop_pachinkannon` | `EWWATnkToy` (Komatop) + `EFWAFigMec` (Pachinkannon) | 1, 2 | 8G | Tank, Fighter, Toy, Mecha | **Guardian Sniper:** Komatop intercepts lethal burst aimed at Pachinkannon while Pachinkannon fires bouncing ranged shots. |
| `pair_griffoam_pachinkannon` | `EEWAFigAni` (Griffoam) + `EFWAFigMec` (Pachinkannon) | 2, 3 | 8G | Fighter, Animal, Mecha | **Artillery Crossfire:** Dual backline pressure. Griffoam punishes enemy summons/merges while Pachinkannon bounces through backlines. |
| `pair_reizokun_komatop` | `EFWATnkApp` (Reizokun) + `EWWATnkToy` (Komatop) | 0 | 8G | Tank, Toy, Appliance | **Iron Bastion:** High-HP pre-damage shield backed by lethal intercept protection. |
| `pair_relaytron_bogmantle` | `FFWASupMec` (Relaytron [w/ Scythe]) + `EWFigCos` (Bogmantle) | 0, 1 | 8G | Support, Fighter, Mecha | **Relay Execution:** Relaytron holds Scythe (2G). Upon death, transfers Scythe to Bogmantle, granting Bogmantle extra actions on kill plus deathrattle stat buffs. |
| `pair_relaytron_tsunamantle` | `FFWASupMec` (Relaytron [w/ Scythe]) + `EFWWFigCos` (Tsunamantle) | 0, 1 | 10G | Support, Fighter, Mecha, Costume | **Relay Cascade:** Relaytron holds Scythe (2G). Upon death, passes Scythe to Tsunamantle, enabling its Cascade attacks to trigger extra actions on knockout. |

---

### 4.4 Curated Triplets (Base Cost: 6G – 9G)

| Triplet ID | Units (Slots $N, N+1, N+2$) | Valid Slots | Cost | Tags | Synergy & Tactical Strategy |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `triplet_fire_branblee_ripplepup_pepspray` | `EFTnkMec` (Branblee) + `WSupAni` (Ripplepup [w/ Fire Emblem]) + `FWFigFod` (Pepspray) | 0 | 6G | Tank, Support, Fighter, Fire, SOUL_FIRE | **The Core Fire Engine:** Branblee tanks in Slot 0; Ripplepup in Slot 1 heals Branblee (triggering +Armor/+Spikes) and holds Fire Emblem (+2 PWR, Fire Soul). Pepspray in Slot 2 holds required Candy (1G), which heals it to activate its Burn fireballs; the Fire Emblem is free. |
| `triplet_puffcorn_bogmantle_nuton` | `ASpeFod` (Puffcorn) + `EWFigCos` (Bogmantle) + `FWWATnkFod` (Nuton) | 0 | 7G | Specialist, Fighter, Tank, Food | **Compounded Death Growth:** Puffcorn in Slot 0 dies $\rightarrow$ Bogmantle in Slot 1 gains $+1/+1$ and inherits Puffcorn's PWR $\rightarrow$ Nuton in Slot 2 copies Bogmantle's massive stat gains! |
| `triplet_branblee_ripplepup_pachinkannon` | `EFTnkMec` (Branblee) + `WSupAni` (Ripplepup) + `EFWAFigMec` (Pachinkannon) | 0, 1 | 7G | Tank, Support, Fighter, Mecha | **Iron & Artillery:** Thorn wall frontline sustained by Ripplepup with backline bouncing sniper pressure. |
| `triplet_matryodust_bogmantle_mechamom` | `EASupToy` (Matryodust) + `EWFigCos` (Bogmantle) + `EFFASupMec` (Mechamom) | 0, 1 | 8G | Support, Fighter, Toy, Mecha | **Attrition Nursery:** Matryodust dies $\rightarrow$ feeds Bogmantle $+1/+1$ and summons a T1 unit $\rightarrow$ Mechamom immediately gives the spawned unit +3 HP. |
| `triplet_stumpling_oakbark_nuton` | `ETnkPla` (Stumpling) + `EEFWSupPla` (Oakbark) + `FWWATnkFod` (Nuton) | 0 | 9G | Tank, Support, Plant, Food | **Frontline and Direct Buffs:** Oakbark buffs Stumpling and Nuton directly. Nuton cannot copy Stumpling's buff across two slots. This legacy package is not used as a multiplying core in the trait profiles. |

---

## 5. Universal Secondary Trinket Voting Rules

When an encounter drafts a 5-Gold Secondary Trinket:
1. Every living unit in the lineup tallies **1 Vote** for each matching Trait Crest.
2. Units also vote for Universal Mechanical Trinkets if their mechanical triggers match (e.g. `trinket_vengeance` receives votes from all units with $\le 2$ HP; `trinket_spiked_armor` receives a vote from any Tank in Slot 0).
3. The trinket with the **highest vote count** is selected.

---

## 6. Bidirectional Reinforcement Weighting

When mid-combat reinforcements are generated:
* If a Secondary Trinket is active (e.g., `trinket_trait_earth`), all units carrying the `EARTH` tag receive a **$3\times$ RNG Weight Multiplier** during reinforcement selection.
* This ensures that reinforcements seamlessly match the Front/Behind pair criteria of surviving units on the board.

## 7. Trait Banner Package Extensions

`EnemyTraitBannerProfiles` explicitly approves packages for each of the fourteen compatible banner traits. Off-trait members receive that profile's free emblem only when the package is approved; this is independent of the legacy Swarm native-unit filter. `TraitBannerDrafter` computes actual costs from equipped units rather than trusting a package's display/base cost.

| Package | Ordered members | Start slots | Base cost | Interaction |
|---|---|---|---:|---|
| `pair_pepspray_ripplepup` | Pepspray → Ripplepup | 0, 1, 2 | 3G | Heal the unit that launches Burn |
| `pair_stumpling_pepspray` | Stumpling → Pepspray | 0, 1 | 3G | Food-only: front hurt trigger heals rear beneficiary |
| `triplet_stumpling_pepspray_nuton` | Stumpling → Pepspray → Nuton | 0 | 7G | Food-only: healing triggers Burn; Food PWR buffs reach a recipient adjacent to Nuton |
| `triplet_oakbark_bogmantle_nuton` | Oakbark → Bogmantle → Nuton | 1 | 10G | Frontline required at 0; Oakbark buffs Bogmantle and Nuton copies that adjacent recipient's buff |
| `pair_nuton_ripplepup` | Nuton → Ripplepup | 2, 3 | 5G | Sustain the stat-copy beneficiary |
| `pair_relaytron_vulcannon` | Relaytron with Scythe → Vulcannon | 0, 1 | 7G | Transfer Scythe into an empty native Mecha item slot |
| `pair_stumpling_sojikun` | Stumpling → Sojikun | 0, 1 | 5G | Durable protection for the Appliance purifier |
| `pair_sojikun_pachinkannon` | Sojikun → Pachinkannon | 1, 2, 3 | 8G | Remove enemy positive effects and apply ranged finishing pressure |

The Food-only extensions require the corresponding active crest/emblems and are never offered to unrestricted Swarm drafting. Mandatory healing equipment can increase the actual cost of other profile variants. The Fire triplet now includes Candy on Pepspray, so its 6G cost is 5G of units plus 1G equipment, with a free Fire Emblem.
