# Phase 2: Game Content Reconciliation & Implementation Checklist

**Goal:** Reconcile the playable game with every entity, rule, name, stat, description, eligibility rule, slot effect, and trait in [`GameContentDocument.md`](GameContentDocument.md), while aligning implementation terminology with [`Game_Terminology_Glossary.md`](Game_Terminology_Glossary.md). This phase is complete only when each source entry has a verified resource/handler/localization mapping and its required behavior passes regression tests.

**Scope boundary:** Implement the values and mechanics specified by the content document. Do not make independent balance changes or alter visual aesthetics. Any proposed design change outside that document requires explicit approval. Keep simulation/data independent of presentation, route presentation from immutable simulation events, use strict types and explicit invariants, and do not add defensive duck-typing guards or symptom patches.

---

## 1. Source Authority and Resolved Terminology

1. `GameContentDocument.md` is the authority for entity roster, names, stats, effects, ability behavior, encounter eligibility, slots, and trait thresholds/distribution.
2. `Game_Terminology_Glossary.md` is the authority for engine and player-facing terms, trigger names, targeting, attack/damage categories, and description style, with the user-approved terms recorded below.
3. Use these approved terms consistently in resources, code, CSV, PO files, and tests.

### Approved terms and verified roster counts

- **Pre-Battle** is the canonical trigger phrase; the glossary and content document now use it.
- A standard attack is a **Melee Attack** or **Ranged Attack**. There is no “Basic Attack” or “regular attack” category. **Extra Attack** means one additional Melee Attack immediately after the main Melee Attack.
- **Mercenary is the fifth Class Trait.** The game has 16 traits total: 4 Elemental, 5 Class, and 7 Thematic. Novice and Fire Ritual remain Hero archetype/loadout labels; they do not add trait categories.
- The 36 §1 active-run roster rows contain 36 unique IDs (25 neutral base + 11 Bounty Hunter pack), and every ID has a matching resource in `resources/units/`. The other 18 unit resources are the six Heroes in §2 and twelve bosses/enemy/Dust entries in §3. The roster is not missing implemented unit IDs.
- The distribution matrices were checked against the 36 roster IDs and their tags. Class and Thematic counts match; the elemental matrix now labels its first row **Chosen Element**, because its counts include both fixed Souls and the Bounty Hunter lineage's inherited Random Souls (`?`), rather than counting only `?` markers.
- The remaining pool issue is eligibility, not roster coverage: §6 lists 32 player-only definitions—13 Units, 7 Items, and 12 Trinkets. All 11 Mercenary lineage Units are player-only, plus `EWAASpePlaApp` and `FWAASupToy`; only those last two currently set `is_player_exclusive = true`, so the Mercenary Units can leak into random enemy pools. `EncounterGenerator._create_resource_pools` filters Units and Trinkets by their flags, but does not apply the documented player-only exclusion list to Items. Four listed Trinkets lack the required true flag: `trinket_trait_mercenary`, `trinket_trait_specialist`, `trinket_trinity_charm`, and `trinket_twin_charm`.

---

## 2. Content Coverage Checklist by GameContentDocument Section

Every row in the referenced section is in scope, including entries whose mechanics did not change. A matching ID or display name alone is not proof of implementation: compare stats, tags, level variants, triggers, targets, conditions, effect amounts, decay, localization, and pool eligibility.

### 2.1 Units (§1)

Verify all 36 active-run roster entries and their level-specific abilities. The 25 neutral base units are the four T1 units, six T2 units, and fifteen T3 units. The 11-unit Bounty Hunter pack is `?MerSpe`; `?ASpeMerFodToy`, `E?TnkMerPlaToy`, `F?FigMerMecApp`, `W?SupMerAniCos`; and `E??ATnkSpeMerFodPlaToy`, `EF??TnkFigMerMecPlaToyApp`, `EW??TnkSupMerAniPlaToyCos`, `F??AFigSpeMerFodMecToyApp`, `FW??FigSupMerAniMecAppCos`, `W??ASupSpeMerFodAniToyCos`.

Use these IDs as the roster checklist:

- **T1:** `?MerSpe`, `ASpeFodToy`, `ETnkPlaToy`, `FFigMecApp`, `WSupAniCos`.
- **T2:** `?ASpeMerFodToy`, `E?TnkMerPlaToy`, `EASpeFodToy`, `EFTnkAniCos`, `EWFigCosToy`, `F?FigMerMecApp`, `FASpeMecApp`, `FWSpeAppFod`, `W?SupMerAniCos`, `WATnkPlaAni`.
- **T3:** `E??ATnkSpeMerFodPlaToy`, `EEFASpeFodCos`, `EEFWFigTnkPlaToy`, `EEWAFigFodAniCos`, `EF??TnkFigMerMecPlaToyApp`, `EFAASupToy`, `EFFASupPlaToy`, `EFFWSupMecApp`, `EFWAFigSpeAniMec`, `EFWASupFodToy`, `EFWATnkCosMec`, `EFWWFigSpeAniFodMecCos`, `EW??TnkSupMerAniPlaToyCos`, `EWAASpePlaApp`, `EWWATnkMecApp`, `F??AFigSpeMerFodMecToyApp`, `FFWASpeSupMecAniApp`, `FW??FigSupMerAniMecAppCos`, `FWAASupToy`, `FWWASupAniToy`, `W??ASupSpeMerFodAniToyCos`.

Implement or verify these updated unit requirements specifically:

- `ASpeFodToy`: knockout grants current PWR behind; at Levels 2 and 3 also grants 50% to the second ally and 25% to the third ally, respectively.
- `?ASpeMerFodToy`: when Bounty is rewarded, apply its level-scaled Static to every living enemy with Bounty.
- `EASpeFodToy`: on knockout, summon a random T1 unit at the holder's level. Remove the old Gold-scaled PWR behavior.
- `F?FigMerMecApp`: apply Bounty stacks on attack; Level 2 marks the target and one adjacent enemy; Level 3 marks the target and all adjacent enemies. Repeated applications stack.
- `W?SupMerAniCos`: Gold earned heals the allied unit directly in front, not a random ally.
- `EEFASpeFodCos`: mirror transformation uses an exact Level 1/2/3 copy at the corresponding level, with the specified no-mirror fallback.
- `EEWAFigFodAniCos`: while in the active lineup, deal level-scaled ranged damage when any unit enters that lineup by movement, summon, merge spawn, or transformation—not only when an enemy is summoned.
- `EFAASupToy`: summon the specified `EASpeFodToy` unit at the holder's level, not a random T2 unit.
- `EFWASupFodToy`: use the player-facing name **Bubblegum Slime** and scale PWR from other Bubblegum Slimes; preserve its knockout Gacha-machine copy behavior.
- `EWWATnkMecApp`: intercept lethal damage to allies and gain 0/1/2 Armor by level.
- For every other unit, verify the exact GCD trigger, target, damage type, level scaling, position, and amount, including Random Soul (`?`) inheritance for the Bounty Hunter lineage.

**Observed gaps:** Current `?ASpeMerFodToy` resources still use a Pre-Battle Gold/PWR effect; `EASpeFodToy` still has Gold-to-PWR and random T2 summon abilities; `W?SupMerAniCos` targets `RANDOM_ALLY`; `EFAASupToy` uses a random T2 summon; and `EEWAFigFodAniCos` is wired to an enemy-summoned trigger with Melee Attack delivery. Verify/fix the source ability resources and event routing, not just descriptions.

### 2.2 Heroes (§2)

Implement all six complete Hero records, including names, base stats, soul loadout, archetype, bonus traits, starter Sigil, minigame behavior, and battle abilities:

- **Han / `hero_avenger`:** 6 HP / 2 PWR; 3 same-element random Souls; Fighter; one random thematic trait; Ninja Sigil; ally-knockout leap strike.
- **Kon / `hero_bastion`:** 12 HP / 1 PWR; 3 same-element random Souls; Tank; one random thematic trait; Bastion Sigil; Pre-Battle Reinforce; when this Hero knocks out a unit, gain 1 Armor and 1 Spikes.
- **Shiken / `hero_bounty_hunter`:** 10 HP / 2 PWR; 3 same-element random Souls inherited by the Mercenary lineage; Mercenary; one random Class or Thematic trait; Mercenary Sigil; gain 1 Gold on this Hero's knockout blow.
- **Hiko / `hero_pyro`:** 8 HP / 2 PWR; 3 Fire Souls; Fire Ritual; one random Class and one random Thematic trait; Fire Sigil; replace the Melee Attack with a Ranged Attack that applies Burn equal to PWR.
- **Dan / `hero_starter`:** 10 HP / 2 PWR; 3 same-element random Souls inherited by the Novice lineage; Novice; one random Class or Thematic trait; Novice Sigil; minimum 3 Tokens per minigame and gain HP equal to an ally's PWR on ally knockout.
- **Deko / `hero_timekeeper`:** 10 HP / 1 PWR; 3 same-element random Souls; Support; one random Thematic trait; Monk Sigil; +1.0s on correct and -0.5s on wrong minigame answer; at turn start grant +1 HP directly in front and +1 PWR directly behind.

Run initialization must give each Hero the three matching elemental Souls, required fixed and bonus traits, the correct starter Sigil, and the appropriate lineage inheritance. Do not implement this only for Shiken. Confirm random assignments use the seeded RNG.

**Observed gaps:** `HeroBastion.tres` remains 10/2 and its current ability triggers on ally knockout; `HeroTimekeeper.tres` remains 50/2 and its turn aura grants +2 instead of +1. RunState currently initializes the special trait loadout only for the Bounty Hunter and starts only that Hero with a Sigil. Hiko's resource marks its status effect as an attack override but does not encode/verify the documented Ranged Attack delivery. Audit `hero_starter` and `hero_timekeeper` minigame behavior against their complete rows as well.

### 2.3 Enemies & Bosses (§3)

Verify all eleven entries and their names, stats, tags, triggers, targets, and summon behavior: `boss_1`–`boss_5`, `enemy_hero`, `unit_dust_elite_t1`–`unit_dust_elite_t3`, and `unit_dust_t1`–`unit_dust_t3`. Cover boss draw/token/ally-growth passives, end-of-turn team filling, Dust tier-scaled growth and spawning, and whether each Dust summon goes to a lineup or player inventory exactly as specified.

### 2.4 Items & Equipment (§4)

Verify every item and consumable in the master table, including stat bonuses, tier, tags, category, names, ability text, effect conditions, damage class, and consumption/equip rules. Required ID inventory: `consumable_potion_plunder`; `item_claim_ticket`; the four `item_emblem_*` entries; `item_golden_seal`, `item_interest_ledger`, `item_loaded_contract`, `item_mercenary_emblem`; `item_potion_heroism`, `item_potion_spikes`, `item_potion_t1`; `item_t1_a`, `item_t1_b`; `item_t2_a`–`item_t2_d`; and `item_t3_a`–`item_t3_g`.

Use the updated player names from §4, including **Plunder**, **Gold Coin**, **Battery**, **Cactus Juice**, **Apple**, **Candy**, **Wakizashi**, **Scythe**, **Anvil**, **Slime Cell**, **Ramune**, **HardCandy**, **Leech Gumi**, **Rubber Ball**, **Sour Candy**, **popcorn**, and **Slingshot**. Do not leave old display names in descriptions, localization, or docs.

Check these mechanics against the current item resources in particular:

- `item_t1_b` / Wakizashi: **Extra Attack** when the target has more HP; preserve the documented turn-action restriction.
- `item_t2_b` / Scythe: grant an **Extra Action** on knockout blow, once per turn.
- `item_t2_c` / Anvil: when hurt by an attack, heal 1 HP and gain 1 PWR.
- `item_t2_d` / Slime Cell: conditional +1 PWR per Slime Cell in battle and spawn a Slime Cell on knockout. Current resource still references Echoing Orb scaling/death abilities.
- `item_t3_b` / HardCandy: on attack, grant the holder Armor and Spikes equal to half the damage. Current resource still has +4 PWR and a two-random-ally PWR buff.
- `item_t3_d` / Rubber Ball: when hurt by an attack, deal the received damage as a Ranged Attack to a random enemy. Current resource still retaliates for half holder PWR.
- `item_t3_g` / Slingshot: convert Melee Attacks to Ranged Attacks aimed at the Mirror Slot. Verify behavior uses the approved name and attack taxonomy.
- Verify every remaining item against its exact GCD row, including the four Elemental Emblems, Gold scaling, Gold-triggered effects, potions, knockout summons, lifesteal, highest-HP targeting, and PWR stealing.

### 2.5 Trinkets, Sigils & Insignias (§5)

Compare every row in the Sigil/Insignia description and Trinkets Master Table to its resource, ability, trigger, stat/effect, team scope, once-per-turn limit, and localization. This includes all level/tier/trait Insignias; all 16 Sigils as currently represented by the GCD rows; and every named general Trinket in the table. The audit must explicitly cover the following updated behaviors:

Use this complete GCD ID inventory to ensure no Trinket row is skipped: `trinket_aegis`, `trinket_air_insignia`, `trinket_animal_insignia`, `trinket_appliance_insignia`, `trinket_armor_aura`, `trinket_awe_inspiring_totem`, `trinket_bargain_charm`, `trinket_beginners_charm`, `trinket_burn_vial`, `trinket_costume_insignia`, `trinket_earth_insignia`, `trinket_fighter_insignia`, `trinket_fire_insignia`, `trinket_food_insignia`, `trinket_hero_catalyst`, `trinket_level3_insignia`, `trinket_mecha_insignia`, `trinket_merge_damage_charm`, `trinket_plant_insignia`, `trinket_polished_plate`, `trinket_purifying_pendant`, `trinket_recruiting_charm`, `trinket_royal_insignia`, `trinket_rusty_ring`, `trinket_soul_echo`, `trinket_specialist_insignia`, `trinket_spiked_armor`, `trinket_support_insignia`, `trinket_tank_insignia`, `trinket_tier1_insignia`, `trinket_tier2_insignia`, `trinket_tier3_insignia`, `trinket_time_sprint_charm`, `trinket_token_return_charm`, `trinket_toy_insignia`, `trinket_trait_air`, `trinket_trait_animal`, `trinket_trait_appliance`, `trinket_trait_costume`, `trinket_trait_earth`, `trinket_trait_fighter`, `trinket_trait_fire`, `trinket_trait_food`, `trinket_trait_mecha`, `trinket_trait_mercenary`, `trinket_trait_plant`, `trinket_trait_specialist`, `trinket_trait_support`, `trinket_trait_tank`, `trinket_trait_toy`, `trinket_trait_water`, `trinket_trinity_charm`, `trinket_twin_charm`, `trinket_underdog_emblem`, `trinket_vengeance`, `trinket_veteran_insignia`, `trinket_wanted_poster`, and `trinket_water_insignia`.

- **Polished Plate:** Pre-Battle, grant one Reinforce stack to all allies. Current `PolishedPlate.tres` has no abilities, while Armor decay is special-cased in BattleManager.
- **Rusty Ring:** conditional +1 HP/+1 PWR while unequipped, removed when an Item is equipped.
- **Aegis Charm:** once-per-turn lethal save at 1 HP; verify team scope and the limit.
- **Purifying Pendant:** remove all remaining stacks of a Negative Effect when its damage harms an ally.
- **Recruiting Charm:** spend 1 Gold at turn start to hire a Level 1 `?MerSpe` only when a bench slot is open.
- **Trait Sigils:** verify the threshold set and the effect text for every level; distinguish Sigils (threshold unlocks) from entry-stat Insignias and equippable Emblems.
- **Player-only systems:** mark every definition that depends on the player Gold/Token economies, Flashcard Minigames, Gacha Machines, recruitment, player merges, player discard-pile operations, or the player's Battle Pool as excluded from enemy selection. This includes all Mercenary Units and the Mercenary Sigil, the Specialist Sigil, Trinity Charm, Twin Charm, Plunder, and Slime Cell; do not infer eligibility from names alone.

### 2.6 Enemy Encounter Eligibility (§6)

Implement and test the full GCD exclusion list for Items, Trinkets, and Units. Verify both the metadata flags and the actual encounter-pool builder. Current `EncounterGenerator._create_resource_pools` filters Units and Trinkets by their player-exclusive flags, but appends all non-consumable Items without applying the documented Item exclusion list. Only the two non-Mercenary player-only Units currently set `is_player_exclusive = true`; all 11 Mercenary Units are unset. Four listed Trinkets are not marked player-exclusive: `trinket_trait_mercenary`, `trinket_trait_specialist`, `trinket_trinity_charm`, and `trinket_twin_charm`. The §6 player-only Items also include Plunder (consumable, already omitted by the pool) and Slime Cell (non-consumable, currently eligible for enemy selection). Add a regression assertion that no listed excluded definition can appear in an enemy encounter pool.

### 2.7 Core Stats & Battle Attributes (§7)

Enforce the GCD rules: HP reaches knockout at zero; PWR drives attacks and Spikes base reflection; Armor mitigates all damage point-for-point except Burn and decays at turn start unless protected by Reinforce; Spikes reflect Melee Attack damage equal to active stacks, lose one stack per activation, and are bypassed by Ranged Attacks. Use the approved terminology for defeat/knockout consistently.

### 2.8 Positive & Negative Effects (§8)

Verify all six statuses and their full lifecycle, classification, stackability, damage behavior, and decay:

| Effect | Required lifecycle |
|---|---|
| Burn | End-of-turn damage equal to stacks; ignores Armor; halve stacks at turn end, rounded down; no decay while on a Burn Slot. |
| Reinforce | Positive, stackable; prevents Armor decay at turn start; lose one stack at turn start. |
| Armor | Absorbs all damage except Burn; clear at turn start unless Reinforce preserves it. |
| Spikes | On Melee Attack contact, reflect damage equal to current stacks; consume one stack; no turn-end decay; Ranged Attacks bypass it. |
| Static | On knockout, damage living adjacent lineup allies for current stacks; Armor mitigates; clear on explosion; lose one stack at turn end. |
| Bounty | Negative, stackable; award 1 Gold per stack on knockout by any means; lose one stack at turn start. |

**Observed gaps:** `resources/status_effects/reinforce.tres` does not exist. `armor.tres` is configured for `END_OF_TURN`; BattleManager preserves Armor through Polished Plate/Bastion special cases rather than Reinforce. `bounty.tres` uses `CLEAR`; `KnockoutProcessor._process_bounty_death` awards a fixed 1 Gold and clears all stacks. Correct the lifecycle at the status/data and simulation source, then test it through normal event processing.

### 2.9 Battlefield Slot Effects (§9)

Verify Burn Slot (3 Gold; applies Burn at turn start and prevents Burn decay), Lightning Slot (2 Gold; applies Static at turn start), and the automatic Death Slot. Test slot generation costs and effects, occupancy, both teams, Burn decay immunity, and advancing Death Slots from Turn 10 onward with immediate knockout at turn end. Current generation and execution exist in `EncounterGenerator.gd` and `BattleManager.gd`; assert their mechanics against the GCD rather than treating their presence as proof of parity.

### 2.10 Traits, Thresholds & Distribution (§10)

Verify all 16 traits across the documented run pool: 4 Elemental, 5 Class (Tank, Fighter, Support, Specialist, Mercenary), and 7 Thematic. Check their descriptions, levels, threshold counts, ability effects, Sigil resources, and trait-tag counts. Cover the four elemental thresholds (3/6/12/20/32 Souls), the Class and Thematic thresholds (2/3/4/5 Units), every effect in each trait overview, and the full distribution matrices for the neutral and Bounty Hunter rosters. Treat Novice and Fire Ritual as Hero archetype/loadout labels, not additional trait categories. Validate Random Soul assignment and lineage inheritance with seeded tests.

---

## 3. Descriptions, Localization & Tutorial Text

1. Audit every player-facing name and description referenced by the GCD across `localization/game.csv`, English and PT-BR translations, relevant `.tres` resources, and any generated translation artifacts.
2. Descriptions must state the approved trigger, exact target, action, amount/scaling, duration/decay, and exception needed to understand the mechanic. Use approved glossary phrases and `#ffd166` bold styling for triggers. Keep flavor text out of mechanical descriptions.
3. Ensure text distinguishes **Melee Attack**, **Ranged Attack**, **Extra Attack**, **Extra Action**, **Battle Buff**, **Permanent Buff**, **Debuff**, **Negative Effect**, **Knockout**, **Heal**, and **Armor** where applicable.
4. Update names to the current GCD names, including renamed Heroes/Items/Trinkets and Bubblegum Slime; search every locale for stale names.
5. Sync translations with `scripts/utils/sync_translations.py`, then verify English and PT-BR lookups for every entity and ability description. Keep any additional translation exports in sync with the source PO/CSV files.

---

## 4. Simulation Routing, Reuse & Terminology Refactor

1. Route Melee and Ranged attacks through explicit delivery and damage-type handling. Melee contact can trigger Spikes/Toy reflection; Ranged delivery bypasses those reflections. Both use the centralized Armor mitigation rule; Burn alone bypasses Armor.
2. Route all effects through simulation results/events. Presentation consumes immutable event sequences; no simulation or data resource may depend on UI, animation, shaders, or audio.
3. Consolidate truly shared stat, status, heal, damage, summon, and targeting behavior into configurable handlers where contracts match. Keep unique mechanics explicit where merging them would obscure or distort their semantics.
4. Audit all target types and trigger contexts against the glossary and `TargetResolver.gd`; add no localized-text comparisons or timer-based ordering patches.
5. Migrate legacy engine terms to the approved terminology. Audit `TRIGGER_PRE_COMBAT`, `pre_combat` resource triggers, `PRE_COMBAT` phase labels, `_trigger_pre_combat_abilities`/`on_pre_combat` methods, `*PreCombat` effect names, `Pre-Combat` description-parser aliases, and localized trigger strings for migration to **Pre-Battle**. Audit `basic_attack` ability IDs/resource paths and the `replaces_basic_attack` property for migration to **Melee Attack** terminology; audit `act_again` and `follow_up_attack` aliases/usages for migration to **Extra Action** and **Extra Attack**; and audit `Combat`/`combat` domain names against the glossary's universal **Battle** terminology. Preserve serialized save compatibility through an explicit, tested migration if identifiers change.
6. Audit trigger constants, enums, methods, variables, logs, test names, translation keys, resource IDs, and docs together. A string rename alone does not satisfy semantic alignment.

---

## 5. Implementation Traceability & Acceptance

Maintain a checklist/table for every row in `GameContentDocument.md` with: source section and ID; current resource/handler/localization; required GCD behavior; status (verified, mismatch, missing); implementation owner/path; and regression test. No section is complete while any row is unreviewed, and a resource-presence check alone does not count as behavior verification.

### Required regression coverage

- All six statuses: application, stacking, turn timing, decay, mitigation, knockout interactions, and emitted events.
- Reinforce preserving Armor and decrementing one stack at turn start; Armor clears at turn start without Reinforce.
- Bounty decrements one stack at turn start and awards Gold equal to all remaining stacks on knockout by attack, status, slot, and summon/effect paths as applicable.
- Melee Attack triggers Spikes; Ranged Attack bypasses Spikes; Spikes damage uses Armor and loses one stack per activation.
- Each changed unit behavior listed in §2.1, including each level variant and target/position rule.
- Hero soul/archetype/bonus-trait/Sigil constitution, seeded Random Soul lineage inheritance, updated stats, and all six Hero ability/minigame rows.
- Each changed item behavior and name listed in §2.4; all remaining item and Trinket table rows receive data/localization crosswalk assertions.
- Enemy encounter exclusions for every §6 ID; no excluded definition appears in generated enemy pools.
- Burn/Lightning slot triggers and costs; Death Slot advancement and knockout timing.
- Every trait threshold, effect overview, and roster distribution count after taxonomy reconciliation.
- Canonical trigger/target/action terminology in code, resources, English/PT-BR descriptions, and compatibility migrations.

### Run and report

1. Run the project startup/compilation check and `.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn` after implementation.
2. The fast suite must exit `0`, report all five suites passing, and contain no project-script errors. Record unrelated platform startup/teardown warnings separately; do not count them as proof that content tests passed.
3. Add the regression assertions above to `tests/run_fast_suite.gd` or dedicated headless tests invoked by the suite. Report the traceability checklist, any unresolved source conflicts, and any remaining mismatches; do not mark Phase 2 complete while any required row is unresolved.
