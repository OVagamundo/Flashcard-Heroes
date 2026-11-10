# Flashcard Heroes — Canonical Game Terminology Glossary

**Status:** Master Terminology Authority (English Canonical Source)  
**Date:** 2026-11-02  
**Companion Documents:**
- `res://docs/GameContentDocument.md` *(Master content & ability design authority — update content with new terminology only after final glossary sign-off)*
- `res://docs/Gameplay_Semantic_Taxonomy_Audit_v1.md` *(Engine semantic taxonomy & audit)*

---

## 1. Architectural & Linguistic Standards

1. **English as Single Source of Truth:**  
   The English terminology defined in this document is the authoritative standard for all game code, engine constants, design specifications, documentation, and data files. Localized translations (e.g. Portuguese PT-BR) provide official player-facing UI text, but never alter or diverge from the underlying English architectural terms.
2. **"Battle" as Universal Domain:**  
   All previous uses of "combat" are replaced with **Battle** (e.g., *Battle Board*, *Battle Lineup*, *Battle Turn*, *Battle Phase*, *Battle Pool*) to maintain strict, unambiguous domain consistency.
3. **Card & Ability Description Standards:**  
   All card, item, and ability descriptions must prioritize **clarity and brevity**. Descriptions must use canonical terms with `#ffd166` bold inline styling for trigger phrases under the **Interactive Glossary Standard**. **No flavor text is allowed in game descriptions.**
4. **Current-Level-Only Law (The Merge Preview Paradigm):**  
   All active card, unit, item, and ability descriptions show **exclusively what the current level does**. Descriptions must **never** include raw bracketed multi-level progressions (`[ 1 / 2 / 3 ]`) or redundant level clauses (`at Levels 1 / 2 / 3`). Players evaluate next-level upgrade progressions directly within the **Merge Modal Preview** (`ChoiceWindow`) before confirming a merge.
5. **Interactive Glossary & Adaptive Tooltip Stacking Standard:**  
   Standardized glossary terms (e.g. `Melee Attack`, `Ranged Attack`, `Shockwave`, `Spikes`, `Burn`, `Armor`) appear with canonical color styling. Tooltip side cards are toggleable and lockable (`Tab` on PC, `[?] Glossary` pill button on mobile) and stack edge-to-edge in lightweight vertical columns (240px–260px width). If an opened glossary card contains terms in its text, those terms are **recursively opened** alongside it (cycle-safe via a visited set).
6. **No Decorative Ambiguity:**  
   Every term in an ability or card description must map to an exact, strongly typed simulation primitive (`Trigger`, `Target`, `Condition`, `Parameter`, `Damage Type`, or `Action Type`).

---

## 2. Entities, Gear & Progression

| Term | Natural-Language Meaning | Key Distinction from Similar Terms |
| :--- | :--- | :--- |
| **GachaBall** | Any capsule piece—**Unit**, **Item**, or **Consumable**—that can be stored in and drawn from Gacha Machines. | **Heroes** and **Trinkets** are never GachaBalls and never enter Gacha Machines. |
| **Hero** | Your team leader in the Lineup. If your Hero is **Knocked Out**, you immediately suffer **Defeat**. | Unlike **Units**, a Hero cannot be merged, sold, removed, transformed, or resurrected. |
| **Unit** | An active combatant placed on your **Lineup** or **Bench** that possesses **HP**, **PWR**, traits, and abilities. | Unlike a Hero, knocking out normal Units does not lose the battle while your Hero stands. |
| **Item** *(Equipment)* | Persistent gear equipped into a Unit's item slot, granting stats, tags, or abilities **While Equipped**. | Remains attached across turns until replaced or removed; a **Consumable** vanishes immediately on use. |
| **Consumable** | A single-use GachaBall (such as a potion) dragged onto a target for an immediate effect, then destroyed. | When used outside battle, its stat gains are a **Permanent Buff**; when used in battle, they last for that battle only. |
| **Trinket** | A relic on your Trinket bar that modifies rules for a team, for **both teams**, or **outside battles** (in minigames or shops). | Applies globally without consuming a Unit's **Item** slot. |
| **Sigil** | A Trait **Trinket** that unlocks the tiered ability thresholds for a specific Trait. | Activates Trait tier thresholds; an **Insignia** grants stats on entry, and an **Emblem** is equippable gear. |
| **Insignia** | A **Trinket** that grants `+1 HP` and `+1 PWR` to matching Units (by Tier, Level, or Trait) when they enter the board. | Awards entry stats; does **not** unlock Trait synergy thresholds (that requires a **Sigil**). |
| **Emblem** | An equippable **Item** that grants an **Elemental Soul** or **Class Trait** tag to its holder while equipped. | Occupies an **Item** slot; adds to Trait counts, but requires the Trait's **Sigil** to unlock synergy tiers. |
| **Tier (1 / 2 / 3)** | A GachaBall's power bracket and machine classification, influencing rarity and setting base **Draw Cost** (`1 / 2 / 3` Tokens). | Influences rarity without being a formal rarity rank. Changes only via **On Merge** (recipe merge). |
| **Level (1 / 2 / 3)** | A Unit's upgrade rank, granting `+1 HP` and `+1 PWR` per level above 1, improved ability values, and higher shop valuation. | Influences power and value without being a rarity rank. Raised via **On Level Up** without changing Tier or Draw Cost. |

---

## 3. Core Stats, Stat Changes & Buff Types

### Buff Taxonomy & Subgroups (`Constants.BUFF_SUBGROUP_*`)
All stat alterations in *Flashcard Heroes* are strictly categorized into three canonical architectural subgroups:
1. **Discrete Buff (`BUFF_SUBGROUP_DISCRETE`):** Trigger-driven, stackable in-combat stat modifications applied via battle actions or reactive triggers (e.g. Dan hero ally-death soul harvest, in-combat kill/death stat bonuses). Stackable (`is_stackable = true`). **Strictly eligible for Buff Echo**.
2. **Conditional Buff (`BUFF_SUBGROUP_CONDITIONAL`):** Continuous, state-bound stat alterations active strictly while a specific condition or predicate is satisfied (e.g. item equipment stats *"While Equipped"*, *"While unequipped"* [*Rusty Ring*], *"Per 10 Gold held"* [*Golden Seal*], Level-gated Insignias [*Apprentice/Veteran Insignia*]). Non-stackable (`is_stackable = false`); dynamically applied or revoked upon inventory/state transitions; **strictly excluded from Buff Echo**.
3. **Permanent Buff (`BUFF_SUBGROUP_PERMANENT`):** Base stat modifications permanently written into the unit's core definition for the entire run (e.g. Dojo training, Shrines, Study sessions). Non-stackable (`is_stackable = false`); persists across all battles; **strictly excluded from Buff Echo**.

| Term | Natural-Language Meaning | Key Distinction from Similar Terms |
| :--- | :--- | :--- |
| **HP** *(Health)* | The life pool of a Unit. Reduced by **Damage** and **Debuffs**; when it hits `0`, the Unit is **Knocked Out**. Has **no upper cap** in battle. | Units can gain or heal HP infinitely beyond their starting base HP. |
| **PWR** *(Power)* | The offensive strength of a Unit, determining the baseline damage dealt by its **Melee Attack** (minimum `0 PWR`). | Scales Melee Attacks and abilities that explicitly reference the Unit's **PWR**. |
| **Heal** *("Heal X HP")* | Restores/increases a Unit's current **HP** and routes to **When Healed** abilities (*Scald*, *Mud Coating*, *Plant*). | Unlike an **HP Buff**, **Heal** triggers *When Healed* and is **never** echoed by *Buff Echo*. |
| **Lifesteal** | **Heals** the attacker after an attack for a percentage of actual HP damage dealt to the target. | Operates as a standard **Heal** scaled by unmitigated damage dealt. |
| **Battle Buff** *("Grant +X HP / PWR")* | A flat numeric stat increase applied during battle. Belongs to the Unit for that entire battle and is inherited on **Level Up** or **Merge**. Belongs to **`BUFF_SUBGROUP_DISCRETE`**. | A fixed addition lasting the battle, unlike a **Conditional Buff** which recalculates live. Never triggers *When Healed*. Eligible for **Buff Echo**. |
| **Conditional Buff** | A dynamic numeric stat modifier active only *while* a condition is met (*"While unequipped"*, *"Per 5 Tokens held"*, *"Per 2 copies"*). Belongs to **`BUFF_SUBGROUP_CONDITIONAL`**. | Continuously recalculates; **never** inherited permanently on merge because it depends on the condition remaining true. **Excluded from Buff Echo**. |
| **Permanent Buff** *("Permanently gain")* | A permanent stat increase added to the Unit's core definition for the **entire run** (from Training Grounds, Shrines, or Studies). Belongs to **`BUFF_SUBGROUP_PERMANENT`**. | Persists across all battles, unlike in-battle **Battle Buffs** and **Conditional Buffs**. Replaces "Permanent Upgrade". **Excluded from Buff Echo**. |
| **Debuff** *("-X HP" / "-X PWR")* | Directly lowers a Unit's numeric **HP** (down to a minimum floor of `1 HP`) or **PWR** (minimum `0 PWR`). | Ignores `Armor` and **cannot Knock Out** a Unit (stops at `1 HP`). Refers strictly to stats, never to **Negative Effects**. |
| **Steal** *(Stat / Effect)* | Reduces a target's stat or effect stacks and grants the **exact amount actually lost** to the stealing Unit. | Clamped by what the target actually lost (cannot steal below `1 HP`, `0 PWR`, or `0` stacks). |
| **Transfer** *(Item / Effect)* | Moves an equipped **Item** or Effect from one Unit directly to another Unit. | If the target's item slot is occupied, passes to the next eligible ally behind; if no slots are open, drops to Bench or Gacha Discard. |
| **Copy Buff** *(Buff Echo)* | Replicates an adjacent ally's stat buff onto this Unit at a specified percentage effectiveness. Strictly clones **`BUFF_SUBGROUP_DISCRETE`** (`is_stackable = true`). | Copied buffs flag `is_echo = true` and never trigger further copies, preventing infinite loops. Strictly ignores conditional buffs (equipment, trinkets) and permanent upgrades. |
| **While Equipped** | Modifiers granted by an **Item** that remain active strictly while that Item is equipped on the Unit (**`BUFF_SUBGROUP_CONDITIONAL`**). | Unequipping removes the modifier immediately (clamped to the `1 HP` floor). Excluded from **Buff Echo**. |

---

## 4. Attacks, Delivery & Granular Damage Types

### Damage Taxonomy & Subgroups
All damage in *Flashcard Heroes* is categorized into three major groups:
1. **Attack Damage (Group):** Damage delivered by unit attacks. Subdivided into **Melee Attack Damage** (triggers Spikes reflection) and **Ranged Attack Damage** (bypasses Spikes reflection). Both are mitigated by Armor.
2. **Effect Damage (Group):** Damage delivered by positive or negative effects. Subdivided into **Spikes Damage** (mitigated by Armor), **Static Damage** (mitigated by Armor), and **Burn Damage** (**bypasses Armor completely**).
3. **Ability Damage:** Non-attack damage dealt directly by abilities, Trinkets, or board events. Mitigated by Armor; bypasses Spikes.

> [!IMPORTANT]
> **Centralized Armor Mitigation Law:** Armor absorbs **all** damage point-for-point across every damage type, and is bypassed **only** by Burn damage (`damage_type != DamageType.BURN`).

| Term | Natural-Language Meaning | Key Distinction from Similar Terms |
| :--- | :--- | :--- |
| **Attack Damage** *(Group)* | Damage originating from a Unit's attack strike. Covers both **Melee Attack Damage** and **Ranged Attack Damage**. | Mitigated by Armor; triggers *When Taking Attack Damage* reactions. |
| **Effect Damage** *(Group)* | Damage dealt by positive or negative effects. Covers **Spikes Damage**, **Static Damage**, and **Burn Damage**. | Fires *When Taking Effect Damage* reactions; does not count as an attack. |
| **Melee Attack** | A Unit's standard offensive action, targeting the **Frontmost Enemy** and making physical contact. | Mitigated by Armor; **triggers defender Spikes**. *(Does NOT trigger Static natively; Toy trait is a specific reactive ability).* Replaces all uses of "Basic Attack". |
| **Ranged Attack** | A distant offensive strike targeting the **Mirror Slot** (`Lineup Size - 1 - Source Index`). If the mirror slot is empty or its occupant is knocked out, **falls back to the backmost living enemy**. | Mitigated by Armor; **bypasses defender Spikes**. |
| **Attack Override** *("Instead of attacking...")* | Replaces a Unit's standard attack with a custom action (e.g. applying Burn, executing a Shockwave). | Still fires **When Attacking** triggers, but skips the standard basic attack hit. Explicitly states attack delivery type (Melee or Ranged). |
| **Melee Attack Damage** | Damage dealt by a **Melee Attack**. | **Mitigated by Armor**; triggers defender **Spikes**; fires **When Taking Melee Attack Damage**. |
| **Ranged Attack Damage** | Damage dealt by a **Ranged Attack**. | **Mitigated by Armor**; **bypasses Spikes**; fires **When Taking Ranged Attack Damage**. |
| **Ability Damage** | Damage dealt by an ability, Trinket, or merge laser (*"Deal X damage"*). | **Mitigated by Armor**; does **not** count as an attack hit and never triggers Spikes. |
| **Spikes Damage** | Retaliatory damage dealt by **Spikes** to a melee attacker equal to the defender's Spikes stacks. | **Mitigated by Armor**; bypasses Intercept; does not trigger hurt/retaliation chains. |
| **Static Damage** | Collateral damage dealt by **Static** stacks on Knockout to living adjacent allies, or by Toy L4 detonation. | **Mitigated by Armor**; bypasses Intercept; fires **When Taking Effect Damage**. |
| **Burn Damage** | End-of-turn damage dealt to a burning Unit equal to its active Burn stacks. | **Ignores Armor completely**; bypasses Intercept; fires **When Taking Effect Damage**. |
| **Bonus Damage** | Additional damage added directly onto an attack's base PWR before Armor mitigation, inheriting the attack's damage type (**Melee Attack** or **Ranged Attack**). | Combines into a single unified damage instance, meaning **Armor** mitigates the total sum only once (unlike a secondary strike or separate **Ability Damage**). |
| **Shockwave** *(Cleave)* | Damage that strikes a primary target (frontmost enemy) and spills backward into up to **2 consecutive slots behind** (Depth = 2) with **50% damage falloff per slot behind** (100% $\to$ 50% $\to$ 25%). | Propagates in slot order behind the primary target with 50% falloff per slot (empty or dead slots still consume falloff, checking the next slot). Defaults to Melee damage unless declared otherwise. Replaces all uses of "Cascade" and "Cleave". |
| **Bounce** | A projectile mechanic where a strike or projectile hits its primary target and then jumps to $N$ additional random living enemy targets (typically halving damage or effect stacks per bounce). | Bounces randomly across valid targets, unlike linear **Shockwave** which spills directly into consecutive slots behind. |
| **Fireball** | A flaming projectile attack that delivers **Burn** stacks equal to its power to the target at range, capable of **Bounce** mechanics. | A named projectile archetype used in attack overrides and reactive triggers (Hero Pyro, Pepspray). |
| **Intercept** | An allied Unit leaps in front of a single-target Melee, Ranged, or Ability strike to absorb the blow in the target's place. | Redirects the hit *before* damage calculation; cannot intercept Burn, Static, or Spikes. *(Replaces legacy "Guardian Sacrifice").* |
| **Retaliate** *(Counter)* | A reactive strike fired back at an attacker **When Taking Attack Damage**. | Triggered defensively upon getting hit; an **Extra Attack** chains off your own offensive attack. |
| **Reactive Attack** | An attack executed out of regular turn-queue order in immediate response to a board event (such as an ally being knocked out, or taking damage). | Resolves with full Melee or Ranged attack rules without consuming the unit's normal turn action. Replaces "Out-of-Turn Attack" and generalizes retaliation. |
| **Extra Attack** | An additional attack executed immediately during this turn action (max once per turn). | **Not restricted to Melee.** Inherits the unit's attack type or declares a specific attack type (Melee, Ranged, or Special). Distinct from an **Extra Action** which grants an entirely new turn. Replaces "Follow-Up Attack". |
| **Extra Action** | Inserts the Unit back into the turn queue for an entire additional turn action (max once per turn). | Re-runs full turn action logic (including Attack Overrides), stronger than an **Extra Attack**. Replaces "Act Again". |
| **Empowered Attack** | An enhanced attack action that expends upon execution to deal **Bonus Damage** or apply **Effects** (**Burn**, **Static**) to the target. | Expended immediately upon executing the attack; distinct from persistent stat buffs. Replaces deprecated standalone "Charge" concept. Matches verbatim for keyword linking. |

---

## 5. Positioning, Targeting & Target Types

### Positioning Terms
- **Lineup Slot (0 to 4):** The 5 combat positions. For the Player, Slot 4 is **Frontmost** (closest to clash) and Slot 0 is **Backmost**. For the Enemy, Slot 0 is **Frontmost** and Slot 4 is **Backmost**.
- **Frontmost / Backmost:** The living Unit closest to (`Frontmost`) or farthest from (`Backmost`) the center clash line, skipping empty slots.
- **In Front / Behind:** Relative direction on a Lineup toward the clash line (**In Front**) or away from it (**Behind**).
- **Directly In Front / Directly Behind:** Exactly the neighboring slot ahead (`index + 1` for player) or behind (`index - 1` for player) without skipping.
- **Adjacent:** The living Units in the immediately neighboring slots directly in front and directly behind on the same team.
- **Mirror Slot:** The enemy slot at the exact matching spatial position across the clash line (Player Back Slot 0 targets Enemy Back Slot 4).

### Target Types Catalog (`TargetResolver.gd`)
| Target Type Key | Resolution Rule |
| :--- | :--- |
| **`SELF`** | The unit or item instance activating the ability. |
| **`HOLDER`** | The unit equipped with the activating item (or self if activated by a unit). |
| **`ATTACK_TARGET`** | The specific unit currently targeted by an incoming attack. |
| **`ATTACKER`** | The unit that initiated the current attack. |
| **`DEFENDER`** | The unit on the receiving end of the current attack. |
| **`TRIGGERING_ENTITY`** | The unit or item whose action/event fired the current trigger context. |
| **`FRONTMOST_ENEMY`** | The first living enemy unit closest to the clash line. |
| **`FRONTMOST_ALLY`** | The first living allied unit closest to the clash line. |
| **`RANDOM_ENEMY`** | A randomly selected living enemy unit. |
| **`RANDOM_UNMARKED_ENEMY`**| A randomly selected living enemy unit that has `0` Bounty stacks. |
| **`HIGHEST_HP_ENEMY`** | The living enemy unit with the highest current HP. |
| **`LOWEST_HP_ALLY`** | The living allied unit with the lowest current HP. |
| **`HERO_ALLY`** | The friendly Hero unit on your team. |
| **`ALLY_BEHIND`** | The living ally in the slot directly behind this unit. |
| **`ALLY_SLOT_AHEAD`** | The living ally in the slot directly in front of this unit. |
| **`ADJACENT_ALLIES`** | All living allies in the slots immediately in front of and behind this unit. |
| **`ALLIES_IN_FRONT`** | All living allies in slots closer to the clash line than this unit. |
| **`ALLIES_BEHIND`** | All living allies in slots farther from the clash line than this unit. |
| **`ALL_ALLIES`** | All living units on the activating unit's team. |
| **`MIRROR_SLOT_ENEMY`** | The enemy in the spatially mirrored slot (falls back to the backmost enemy if empty). |
| **`MANUAL`** | The specific unit selected by the player dragging a consumable onto it. |

---

## 6. Conditions & Condition Types (`ConditionDefinition.gd`)

| Condition Type Key | Validation Rule |
| :--- | :--- |
| **`TEAM_SIZE_LESS_THAN_ENEMY`** | Friendly lineup has fewer living units than the enemy lineup. |
| **`SLOT_AHEAD_IS_EMPTY`** | The lineup slot directly in front of this unit is currently unoccupied. |
| **`TARGET_HP_GREATER_THAN_SELF_HP`** | The target's current HP is strictly greater than this unit's (or holder's) current HP. |
| **`DAMAGE_DID_NOT_KNOCK_OUT`** | The damage received was non-lethal (the unit survived with `HP > 0`). |
| **`DAMAGE_WAS_RECEIVED`** | The incoming hit successfully reduced HP by `1` or more (not 100% blocked by Armor). |
| **`IS_TURN_INITIATED_ATTACK`** | The attack was declared as a scheduled turn action (not a counter, retaliation, or bonus strike). |
| **`TRIGGER_CAUSE_MATCH`** | The event's trigger cause matches a declared list of allowed causes. |
| **`KNOCKED_OUT_UNIT_IS_DUST`** | The knocked-out unit's definition ID contains `"dust"`. |
| **`MIN_TRAIT_COUNT`** | The team fields at least the specified count of units/souls for a designated trait. |
| **`MIN_GOLD`** | The player currently holds at least the specified amount of Gold (e.g. 10 Gold). |
| **`COMPOSITE`** | Combines multiple child conditions (all must evaluate to true). |
| **`invert_result`** | Inverts the condition's outcome (logical NOT). |

---

## 7. Triggers & Turn Timing Phrases

All trigger phrases must use constitutional `#ffd166` bold inline styling under the **Zero-Tooltip UI Standard**. Game text descriptions must use these exact phrases with clarity, brevity, and zero flavor text.

### 7.1 Battle Flow & Turn Framing
- **At Battle Start:** Triggers once at the very start of Round 1 of an encounter.
- **Before Minigame:** Triggers each battle round before the Flashcard Minigame begins.
- **At Minigame End:** Triggers immediately after a Flashcard Minigame finishes, evaluating answers and streaks.
- **Pre-Battle:** Triggers each round when the player presses "Battle!", locking preparation and resolving setup abilities.
- **At Turn Start:** Triggers at the start of a combat turn before units begin taking actions.
- **At Turn End:** Triggers after all units have acted, resolving effect ticks, decay, and sudden death.

### 7.2 Attacks, Hits & Damage Reactions
- **When Attacking:** Triggers upon attack declaration, before the hit lands (even if blocked by Armor).
- **Before Taking Damage:** Triggers when targeted by an attack, before Armor absorption and HP reduction.
- **When Taking Damage (Group):** Triggers whenever a direct hit reduces this unit's HP by `1` or more.
  - **When Taking Melee Attack Damage:** Specifically triggers when HP is lost to a **Melee Attack**.
  - **When Taking Ranged Attack Damage:** Specifically triggers when HP is lost to a **Ranged Attack**.
- **When Taking Effect Damage:** Triggers when HP is reduced by a **Negative Effect** (`Burn` tick or `Static` blast). *(Replaces legacy "When Taking Status Damage").*
- **When an Ally Takes Damage:** Triggers when *another* allied unit loses HP to a direct hit.
- **After Dealing Damage:** Triggers on the attacker after successfully dealing `1+` HP damage to the target.
- **When Healed:** Triggers whenever this unit receives a **Heal** (`1+` HP gained via Heal channel).

### 7.3 Mortality & Casualty Chains
- **Before Being Knocked Out:** Triggers when a unit reaches `0 HP`, allowing final counter-strikes before removal.
- **On Knockout Blow:** Triggers on the **attacker** when its direct hit knocks out an enemy.
- **When Knocked Out:** Triggers on the **victim** *(or **"When Holder Is Knocked Out"** on items)* upon reaching `0 HP`.
- **When an Ally Is Knocked Out:** Triggers on surviving teammates when an allied unit is knocked out.
- **When Any Unit Is Knocked Out:** Triggers whenever either a friendly or enemy unit is knocked out.

### 7.4 Board Management & Merging
- **On Merge Action (Group):** Triggers whenever two GachaBalls are combined during Management.
  - **On Level Up:** Specifically triggers when combining two identical units of the same Level (`Lv. 1 + Lv. 1` $\to$ `Lv. 2`).
  - **On Merge:** Specifically triggers when combining two recipe-paired units to create a higher-Tier unit.
- **On Enter Board:** Triggers whenever a unit enters the active Lineup by any means (drawn, deployed, summoned, leveled, merged, or transformed).
- **When an Ally / Enemy Is Summoned:** Triggers when a new unit is spawned directly onto the board.
- **On Board State Changed:** Internal hook that recalculates dynamic aura bonuses when lineup composition changes.

### 7.5 Economy & Minigame Triggers
- **On Gacha Draw:** Triggers whenever a GachaBall is drawn from any Gacha Machine.
- **On Token Spent:** Triggers whenever a Gacha Token is expended.
- **On Gacha Tokens Changed:** Triggers whenever the current Token balance increases or decreases.
- **On Gold Earned:** Triggers whenever persistent Gold is added to your wallet.
- **On Bounty Claimed:** Triggers whenever Gold is awarded from knocking out a unit marked with Bounty.

---

## 8. Execution Architecture: Granular Semantic Sub-Phases & Rules

| Architecture Element | Meaning & Mechanics |
| :--- | :--- |
| **Granular Semantic Sub-Phases** | The strict, monotonic reaction order in `CausalReactionResolver.gd` (`Constants.SubPhase`, e.g. `PRE_TURN_TRANSFORM`, `PRE_DAMAGE_INTERCEPT`, `PREVENT_KNOCKOUT_CHECK`, `KNOCKOUT_CASCADE`, `STANDARD`). Determines resolution order across simultaneous reactions without arbitrary integer priority numbers. |
| **3-Layer Deterministic Comparator** | When simultaneous reactions occur, CRR resolves them deterministically using: **Layer 1:** SubPhase execution order; **Layer 2:** Category Rank (`UNIT` $\to$ `ITEM` $\to$ `TRINKET`); **Layer 3:** Spatial Mirror Direction (Player `4 -> 0`, Enemy `0 -> 4`), sub-index, and lexical ID. |
| **Replaces Melee Attack** | Ability flag (`Attack Override`). The unit performs this ability instead of its standard Melee Attack. |
| **Execute Before Knockout** | Ability flag (`Last Gasp`). Allows a unit reduced to `0 HP` to execute retaliation or counters in `Phase.LETHAL_COUNTER` before being removed. |
| **Once Per Turn** | Enforces that an item or ability effect can activate at most once within a single combat turn. |
| **Non-Stacking** | Prevents multiple equipped items of the same type from duplicating their effect on the same trigger. |
| **Buff Echo (`is_echo`)** | A secondary buff replicated onto an adjacent ally. An echo **never echoes another echo**, preventing infinite recursion. |

---

## 9. Survivability, Knockouts, Transforms & Unit Creation

| Term | Natural-Language Meaning | Key Distinction from Similar Terms |
| :--- | :--- | :--- |
| **Knocked Out** | When a Unit reaches `0 HP`, removing it from the Lineup into the **Discard Pile**. | Units are **Knocked Out**; **Defeat** is reserved exclusively for losing the entire battle/run. |
| **Prevent Knockout** *("Survive with 1 HP")* | A team-wide rescue (once per turn) that stops a lethal blow and sets the unit to `1 HP`. | A pure state floor: does **not** count as a **Heal**, creates no merge buff, and triggers no heal reactions. |
| **Instant Knockout** *(Sudden Death)* | Directly reduces a Unit's HP to `0` on Turn 10+ **Death Slots**. | Bypasses Armor, damage reduction, and Prevent Knockout. |
| **Summon** | Creates a new Unit directly into an open Lineup or Bench slot for the active battle only. | Ephemeral to this battle; **Duplicate** puts a copy into a Gacha Machine instead of the board. |
| **Resurrect** | **Summons** a fresh `Level 1` base copy of the first non-Hero unit knocked out earlier this turn. | Restores only the baseline `Level 1` definition—previous buffs, levels, and items are not restored. |
| **Duplicate** | Creates a fresh copy of a Unit or Item into its matching-tier **Gacha Machine** during battle. | Adds to the Gacha Machine to be drawn later; does not place directly onto the board. |
| **Transform** | Replaces a Unit in-place with a different Unit. In battle, keeps equipped **Items** and **Battle Buffs**; at a **Shrine**, permanently replaces the ball in your **Run Collection**. | Swaps the entity identity without triggering **When Knocked Out**. |

---

## 10. Positive & Negative Effects

Stack-based combat modifiers are termed **Positive Effects** and **Negative Effects** (never "status effects", and never "buffs" or "debuffs", which refer strictly to numeric stats). In engine code, these are modeled as `CombatEffectDefinition` resources loaded via `CombatEffectRegistry`.

| Effect | Polarity | Turn Timing & Decay Rule | Special & Reactive Rules |
| :--- | :---: | :--- | :--- |
| **Armor** | Positive | Clears to `0` at **Turn Start** unless preserved by **Reinforce**. | Absorbs all damage point-for-point. Bypassed only by **Burn** and Instant Knockouts. |
| **Reinforce** | Positive | Loses `1` stack at **Turn Start**. Stackable. | While a unit holds Reinforce, its **Armor** is immune to turn-start clearing. Does not absorb damage itself. |
| **Spikes** | Positive | **No turn-end decay.** Loses `1` stack per activation. | Deals damage equal to active stacks back to **Melee** attackers when struck. Bypassed by **Ranged Attacks**. |
| **Burn** | Negative | Deals damage equal to stacks at **Turn End**, then **halves** (rounded down). | **Ignores Armor completely.** Stacks on a **Burn Slot** do not decay at turn end. |
| **Static** | Negative | Decrements by `1` stack at **Turn End**. | **When Knocked Out**, deals damage equal to stacks to living adjacent Lineup allies (**mitigated by Armor**), then clears. *(Note: The Toy trait reflects Static to melee attackers via a trait-specific reactive ability, not as an innate effect property).* |
| **Bounty** | Negative | Decays by `1` stack at **Turn Start**. Stackable. | When the marked unit is knocked out by any means, awards `1 Gold` per stack and fires *On Bounty Claimed*. |
| **Cleanse** | Neutral Action | Instantaneous stack removal. | Removes active stack(s) of a Positive or Negative Effect from a target immediately, bypassing normal turn-end decay or knockout expiration. |

---

## 11. Battlefield Slots & Sudden Death

- **Burn Slot (`3 Gold`):** Applies `1 Burn` to its occupant at turn start; occupant's Burn stacks do not halve at turn end.
- **Lightning Slot (`2 Gold`):** Applies `1 Static` to its occupant at turn start.
- **Death Slot (Turn 10+ Sudden Death):** Advances inward from outer slots starting Turn 10, executing an **Instant Knockout** (`0 HP`) on any occupant at turn end.

---

## 12. Containers, Gacha Machines & Discard Draw Lifecycle

- **Run Collection:** Your permanent inventory of Units, Items, Hero, Trinkets, and Gold saved across the entire run.
- **Battle Pool:** The temporary clone of your Units and Items inside the current battle (Lineup + Bench + Machines + Discard Pile). All in-battle summons, duplicates, and merges revert when the battle ends.
- **Battle Lineup (5 slots):** Active combat formation acting **Frontmost** to **Backmost**. Only units here fight and contribute to active Traits.
- **Battle Bench (8 slots):** Safe reserve slots during battle Management where units wait out of combat.
- **Tier 1 / 2 / 3 Gacha Machines:** The three tiered machines holding your undrawn Units and Items. Drawing costs `1 / 2 / 3` Tokens.
- **Discard Pile Gacha Machine:** A 4th gacha machine positioned alongside the tier machines. Players spend Tokens to draw from it, transferring a random knocked-out/discarded ball from the **Discard Pile** into its matching **Tier Gacha Machine** (`BattleInventoryT{tier}`) so it can be drawn back into play.
- **Discard Pile:** Storage container holding Units knocked out and Items replaced or discarded during the current battle.
- **On Level Up:** Combining two identical units of the same Level to elevate rank (`Lv. 1 + Lv. 1` $\to$ `Lv. 2`), keeping base stats and inheriting accumulated buffs.
- **On Merge:** Combining two recipe-paired units to evolve into a higher-Tier `Level 1` unit, inheriting surplus stats from both constituents.
- **Replace Item:** Equipping an Item onto a Unit with a full equipment slot, sending the previous Item to the Discard Pile.
- **Plunder Item:** Stealing an equipped Item from an enemy and sending it into your matching-tier Gacha Machine.
- **Remove:** Permanently purging a GachaBall from your **Run Collection** at a **Shrine** to thin your deck.

---

## 13. Traits, Souls & Synergies

- **Trait:** A team-wide synergy category unlocked by holding that Trait's **Sigil** and fielding required thresholds, snapshot-locked at combat start.
- **Elemental Traits (`Fire`, `Earth`, `Water`, `Air`):** Scale on total **Elemental Souls** on the active Lineup (`3 / 6 / 12 / 20 / 32` Souls). Units carry `1` (T1), `2` (T2), or `4` (T3) Souls.
- **Random Soul (`?`):** A dynamic Elemental Soul rolled randomly once at run start for your Hero's lineage and inherited by all `?` units in that run.
- **Class Traits (`Tank`, `Fighter`, `Support`, `Specialist`, `Mercenary`):** Scale on the count of **living Lineup Units** (`2 / 3 / 4 / 5` Units).
- **Thematic Traits (`Food`, `Mecha`, `Animal`, `Plant`, `Toy`, `Appliance`, `Costume`):** Archetype traits scaling on the count of **living Lineup Units** (`2 / 3 / 4 / 5` Units).

---

## 14. Dual Economy, Flashcard Minigame & Encounters

- **Gold:** Persistent run currency carried across days, spent in **Shops**, for **"Get Tokens" Events**, and for Gold-spending combat abilities.
- **Tokens:** Tactical encounter currency earned in Flashcard Minigames to draw from Gacha Machines or fuel Token abilities.
- **Current Tokens:** Your live, unspent Token balance currently held in your wallet.
- **Session Tokens:** The Tokens earned strictly within the most recent Flashcard Minigame.
- **Guaranteed Tokens:** The minimum session floor (e.g. guarantees at least `3 Tokens` from a minigame, topping up only if fewer were earned).
- **Saved Tokens:** Unspent Tokens carried over from the end of the previous turn into the new turn.
- **Mastery Level (1–5):** A flashcard's SRS learning rank from `Level 1` (*Very Hard / New*) to `Level 5` (*Mastered*). Checked *before* an answer updates it.
- **Starting Time vs. Remaining Time:** **Starting Time** is the opening minigame clock; **Remaining Time** is the live time ticking during play.
- **Correct Answer:** Submitting the right answer: awards `1 Token`, raises card Mastery, extends Remaining Time, and adds `+1` to **Streak**.
- **Incorrect Answer:** Submitting a wrong answer: awards `0 Tokens`, lowers card Mastery, resets **Streak** to `0`, and applies wrong-answer time penalties.
- **Skip:** Passing on a flashcard: awards `0 Tokens`, lowers Mastery, but **preserves Streak** and adds a small time extension.
- **Streak:** Consecutive Correct Answers within a minigame session (`3` consecutive correct answers unlocks a new card mid-session and triggers 3-streak bonuses).
- **"Get Tokens" Event:** Spending `5 Gold` once at a non-battle encounter to play an extra Flashcard Minigame for bonus Tokens.
- **Common / Elite / Boss Battle:** Combat encounters paced by deck Mastery progression. Elites and Bosses award Trinkets and higher Gold.
- **Non-Battle Encounters:** **Shop** (buy/reroll with Gold), **Rest Site** (+HP), **Training Grounds** (permanent stat training), **Gambling Den** (Gold wagering), **Merge Encounter** (out-of-battle permanent merges), and **Shrine** (permanent Remove or Transform).

---

## 15. Quick Style Guide — Retired Synonyms $\to$ Canonical Terms

| Do **NOT** Write | **Write Instead** | Reason |
| :--- | :--- | :--- |
| *"Basic Attack"* | **`Melee Attack`** | Standard close-range attack is Melee Attack (triggers Spikes). |
| *"Cascade"* / *"Cleave"* | **`Shockwave`** | Canonical name for linear spillover damage (depth 2, 50% falloff per slot). |
| *"Status Effect"* | **`Positive Effect`** / **`Negative Effect`** | Canonical name for stack-based modifiers (Armor, Spikes, Burn, Static, etc.). |
| *"Combat"* | **`Battle`** | Standardized domain term (*Battle Board*, *Battle Lineup*, *Battle Turn*). |
| *"Dies"*, *"Killed"*, *"Faints"*, *"Defeated"* (unit) | **`Knocked Out`** | Constitutional mortality term. *"Defeat"* is strictly losing the battle/run. |
| *"Kills"*, *"Slays"* | **`Knocks Out`** / **`On Knockout Blow`** | Matches trigger parser and UI standard. |
| *"Restores X HP"* | **`Heal X HP`** / **`Heals X HP`** | Unifies potions with abilities so players recognize *When Healed* reactions. |
| *"Buff"* / *"Debuff"* (for Armor, Spikes, Burn, Static, Bounty) | **`Positive Effect`** / **`Negative Effect`** | Prevents confusion with `+HP/+PWR` **Buffs** (*Buff Echo*) and `-HP/-PWR` **Debuffs**. |
| *"Conditional Bonus"* | **`Conditional Buff`** | Standardizes dynamic, condition-dependent stat modifiers. |
| *"Battle Bonus"* | **`Battle Buff`** | Standardizes fixed, in-battle stat increases lasting for the battle. |
| *"Permanent Upgrade"* | **`Permanent Buff`** | Standardizes run-persistent stat increases (*"Permanently gain +X"*). |
| *"Follow-Up Attack"* | **`Extra Attack`** | Canonical immediate additional attack (max once per turn). |
| *"Act Again"* | **`Extra Action`** | Canonical entire additional turn action (*Bloodlust Edge*). |
| *"Sacrifice"* | *(Removed — use `Knocked Out` / `Damage`)* | Removed; no player sacrifice mechanic exists. Guardian is **Intercept**. |
| *"When Taking Attack Damage"* (vague) | **`When Taking Melee Attack Damage`** / **`When Taking Ranged Attack Damage`** | Distinguishes hits that trigger Spikes from hits that bypass Spikes. |
| *"When Taking Status Damage"* | **`When Taking Effect Damage`** | Canonical trigger phrase for damage from Burn ticks or Static detonations. |
| *"On Merge"* (vague) | **`On Level Up`** (identical units) / **`On Merge`** (recipe pairs) | Distinguishes leveling from recipe evolution under the **On Merge Action** group. |
| *"Level Merge"* / *"Recipe Merge"* | **`On Level Up`** / **`On Merge`** | Canonical action and trigger phrasing. |
| *"Rolled Soul"* | **`Random Soul`** (`?`) | Clear player-facing and architectural terminology. |
| *"Visual Traits"* | **`Thematic Traits`** | Accurate categorization alongside Elemental and Class traits. |
| *"Held Tokens"* | **`Current Tokens`** | Unambiguous live token wallet balance. |
| *"Token Floor"* | **`Guaranteed Tokens`** | Clear natural-language reward guarantee. |
| *"Starting / Remaining Timer"* | **`Starting Time`** / **`Remaining Time`** | Natural-language clock description. |
| *"Study Session"* | **`"Get Tokens" Event`** | Accurately describes the non-battle encounter flashcard minigame. |
| *"Prismatic"* | *(Removed)* | Deprecated rarity concept removed from active vocabulary. |
| *"Charge"* | **`Empowered Attack`** | Eliminates redundant priming jargon; an ability directly grants or prepares an Empowered Attack. |
| *"Next Attack"* | **`Empowered Attack`** | Standardizes attack enhancement storage and keyword linking. |
| *"Out-of-Turn Attack"* | **`Reactive Attack`** | Canonical term for triggered or counter strikes outside normal turn order. |
| *"Empower this attack"* | **`Empowered Attack`** / **`Bonus Damage`** | Retains exact glossary keywords for tooltip highlighting. |
