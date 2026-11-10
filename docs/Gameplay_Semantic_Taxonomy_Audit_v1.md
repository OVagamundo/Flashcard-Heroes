# Gameplay Semantic Taxonomy & Codebase Audit

**Status:** Canonical Audit & Specification (v2.0 — Aligned with Master Terminology)  
**Date:** 2026-11-02  
**Companion Specifications:**
- `res://docs/Game_Terminology_Glossary.md` *(Player-facing natural-language master vocabulary authority)*
- `res://docs/GameContentDocument.md` *(Master content & ability design authority — update terminology only after final glossary sign-off)*
- `res://docs/Aprendice.md` & `res://docs/Bounty Hunter.md` *(Active Hero Set design specifications)*
- `res://docs/Action_Constitution_v1_Flashcard_Heroes.md` & `res://docs/action_constitution_execution_roadmap.md` *(Phases 1–5 Complete)*

---

## 1. Purpose & Architectural Pillars

This document maps *Flashcard Heroes*' gameplay semantics across **design specifications** (`GameContentDocument.md`), **simulation code** (`BattleManager.gd`, `KnockoutProcessor.gd`, `CausalReactionResolver.gd`, `AbilityResolver.gd`, `GachaBallInstance.gd`, `MergeManager.gd`), **serialized `.tres` resources**, and **UI parsing** (`DescriptionParser.gd`, `localization/game.csv`).

> [!IMPORTANT]
> **Master Content Authority, Linguistic Standard & Description Rules:**
> - English is the official single source of truth for all game code, engine constants, design specifications, documentation, and data files. Translations exist only for localized player UI.
> - `docs/GameContentDocument.md` is the primary design authority for abilities, effects (such as the planned `Reinforce` effect), Sigils/Insignias, and trait ladders. It will be updated with canonical terminology once the final glossary is approved.
> - All previous uses of "combat" are standardized to **Battle** (*Battle Board*, *Battle Lineup*, *Battle Turn*, *Battle Pool*).
> - All card, item, and ability descriptions must prioritize **clarity and brevity**. Descriptions must use canonical terms with `#ffd166` bold inline styling for trigger phrases under the **Zero-Tooltip UI Standard**. **No flavor text is allowed in game descriptions.**

Five game-specific pillars govern all semantic definitions:

1. **Unbounded Small-Integer Stat Model (No `max_hp` Ceiling):**  
   Units start with compact stats (`1–6 HP`, `1–6 PWR`) and **have no upper HP cap in battle**. Both `ACTION_HEAL` and `ACTION_BUFF` increase `current_hp` unboundedly (`BattleManager.apply_stat_delta()`, L2380–2401). `Heal` vs. `Battle Buff` is a **synergy and trigger-channel distinction** (`TRIGGER_WHEN_HEALED` vs. `TRIGGER_ON_STAT_INCREASED`), not an RPG missing-HP cap.
2. **Run State vs. Battle-Clone Persistence Boundary:**  
   `RunState` owns persistent `GachaBallInstance` objects in your **Run Collection**. Entering battle creates ephemeral clones (`create_battle_copy()`, linked via `origin_uuid`) inside `BattleState`'s **Battle Pool**. Mutations stored in `battle_components` or effect stacks vanish when battle ends; only mutations written to `RunState` (Gold, persistent `components`, Permanent Buffs, out-of-battle merges/consumables) survive across encounters.
3. **Deterministic 3-Layer Causal Reaction Resolution (CRR) via Granular Semantic Sub-Phases:**  
   Battle reactions resolve synchronously through `CausalReactionResolver.gd` without arbitrary integer priorities, using:
   - **Layer 1: Granular Semantic Sub-Phases (`Constants.SubPhase`):** Sorted ascending (`a.sub_phase < b.sub_phase`), moving through defined phases (`PRE_TURN_TRANSFORM`, `PRE_DAMAGE_INTERCEPT`, `PREVENT_KNOCKOUT_CHECK`, `ON_ATTACK_BUFF`, `ON_DAMAGE_TAKEN`, `RETALIATION`, `PRE_DAMAGE_DEFENSE`, `KNOCKOUT_CASCADE`, `STANDARD`, `DOUBLE_STRIKE_FOLLOWUP`, `GRANT_EXTRA_ACTION`).
   - **Layer 2: Source Category Rank:** Breaks ties between identical SubPhases (`UNIT` $\to$ `ITEM` $\to$ `TRINKET`).
   - **Layer 3: Positional Board Order:** Pre-Combat resolves back-to-front; In-Battle Mirror Rule resolves left-to-right (Player `4 -> 0`, Enemy `0 -> 4`), followed by intra-unit item `sub_index` and lexical `ability_id`.
4. **Strict Simulation $\leftrightarrow$ Presentation VCR Decoupling:**  
   Simulation mutates `BattleState` first and emits an immutable sequence of `CombatEvent` records carrying typed `CombatPayload` snapshots and `cause_event_id` lineage. `BattleAnimator` is a pure VCR playback consumer.
5. **The Zero-Tooltip UI Standard (`DescriptionParser.gd`):**  
   - **`KEYWORDS`** (`ARMOR`, `REINFORCE`, `SPIKES`, `BURN`, `STATIC`, `BOUNTY`) spawn colored `[url=effect_*]` sub-tooltips in `EffectInspectionWindow.gd`.
   - **`TRIGGER_PHRASES`** (`"When knocked out"`, `"When taking damage"`, `"When healed"`, etc.) render inline `#ffd166` bold highlights with **zero pop-up tooltips**.

---

## 2. Codebase Verification Audit (Code Reality vs. Design Specs)

### 2.1 Live Semantic Bugs & Pipeline Disconnects in Code

1. **`Purifying Pendant` (`EffectPurifyHeal.gd`) is Silently Dead:**
   - `resources/abilities/ability_trinket_purifying_pendant.tres` listens to `TRIGGER_WHEN_TAKING_DAMAGE` and `scripts/effects/EffectPurifyHeal.gd` (L8–15) requires `context.trigger_cause == C.CAUSE_STATUS_EFFECT` and `context.status_id != &""`.
   - However, `BattleManager._process_status_turn_effect()` (L3262–3294) never fires `trigger_on_hurt` on Burn ticks, and **`Constants.CAUSE_STATUS_EFFECT` is never assigned anywhere in `scripts/`**.
2. **Knockout Prevention (`EffectPreventLethal.gd`) Leaks Overkill-Scaled `Heal` Reactions & Merge Stats:**
   - `Aegis Charm` (`EffectPreventLethal.gd`, L63–81) rescues a unit at `<= 0 HP` by computing `heal_amount = 1 - victim_current_hp` and calling `battle_manager.apply_stat_delta(victim, "hp", heal_amount, _source_uuid, C.ACTION_HEAL, true)`.
   - Routing via `ACTION_HEAL`:
     - Fires `TRIGGER_WHEN_HEALED` (`BattleManager.gd`, L2409–2418), causing `EffectScald.gd` to shoot **Burn stacks equal to `1 - negative_hp`** (scaling with overkill depth) and proccing `Mud Coating` (`+Armor/+Spikes`).
     - Triggers **Plant L4** (`BattleManager.gd`, L2406: `+1 Spikes` on heal).
     - Appends `comp.id = &"battle_heal"` with `hp: 1 - negative_hp` to `battle_components` (`BattleManager.gd`, L2393–2398), which `MergeManager.gd` (L402) **inherits as bonus HP** if the saved unit is leveled up or merged on a later turn.
3. **Split Minimum-1 Floor (`_hp_debt`) vs. Unfloored Battle `ACTION_DEBUFF` on HP:**
   - `GachaBallInstance.apply_hp_delta()` / `apply_pwr_delta()` (L536–603) enforces a **Minimum-1 HP Floor + Stat Debt (`_hp_debt`, `_pwr_debt`)** for equipment unequip and conditional trinket revocation (`Rusty Ring`, expired `Insignia`).
   - Conversely, `BattleManager.apply_stat_delta()` (L2433–2454) bypasses `apply_hp_delta()` and computes `new_hp = instance.current_hp + delta` with **no floor**. Three live scripts call negative HP `ACTION_DEBUFF`:
     - `EffectTraitCostumePreCombat._steal_hp()` (L178–195): Can reduce a `1–2 HP` enemy to `<= 0 HP` during Pre-Combat AND computes `stolen = v_old_h - v_new_h`, stealing phantom HP when `new_hp` goes negative (`1 - (-2) = 3`).
     - `EffectGoldenSealScaling.execute()` (L43–46): Spending Gold mid-battle (`EffectSpendGold.gd`) applies negative `delta` via `ACTION_DEBUFF`, risking dropping a `1 HP` holder to `<= 0 HP`.
     - `EffectSetHPToGold.execute()` (L23–31): Legacy Merchant script (`0 Gold` $\to$ `0 HP`).
4. **`On Merge Action` vs. `Mirror Transform` Inheritance Asymmetry:**
   - `MergeManager.gd` (L402) inherits both `BATTLE_BUFF` and `battle_heal` components into the merged unit.
   - `EffectHandlers.gd` (L1048–1051, `Mirror Transform`) preserves equipped items and `BATTLE_BUFF` / `CONSUMABLE` components, **excluding `battle_heal`** (while `EffectMirrorTransform.gd` L6 has a stale comment saying `"Discards all equipped items"`).

### 2.2 Conditional Stat Storage Fragmentation (4 Incompatible Patterns)

Dynamic/conditional stat bonuses currently use four separate storage mechanisms:
1. **Persistent `StatComponent` + `dynamic_tags`:** `Rusty Ring` and `Insignias` (`source_type = &"CONDITIONAL_TRINKET"`).
2. **Ephemeral `battle_components`:** `Templar` token-to-PWR scaling (`source_type = &"CONDITIONAL_ABILITY"`).
3. **Hidden Pseudo-Statuses inside `unit.status_effects`:**
   - `twin_charm_scaling_PLAYER` / `twin_charm_scaling_ENEMY` (`BattleManager.gd`, L673–691),
   - `doppleganger_scaling` (`EffectDopplegangerScaling.gd`, L32–44),
   - `echoing_orb_scaling_<uuid>` (`EffectEchoingOrbScaling.gd`, L27–56).
4. **Object Metadata (`set_meta`):** `item.set_meta("golden_seal_bonus", target_bonus)` (`EffectGoldenSealScaling.gd`, L33–39).

### 2.3 Confirmed Design Rulings vs. Stale Text & Dead Code

- **Static vs. Armor Ruling:** **Static damage is mitigated by Armor point-for-point** (matches `BattleManager.apply_damage()` L2227 and `KnockoutProcessor.gd`). Lines 251 & 261 in `GameContentDocument.md` stating Armor is *"Bypassed by Burn and Static"* are stale and will be corrected to reflect that only Burn (and Instant Knockouts) bypass Armor.
- **Spikes Formula & Decay Ruling:** **Spikes deals damage equal to its active stacks and loses 1 stack per activation** (matches `BattleManager.gd` L2269–2285 and `docs/status_effects.csv` L5). Lines 252 & 262 in `GameContentDocument.md` stating Spikes deals *"PWR damage... does not decay"* will be aligned to the implemented stack-damage and decay rule.
- **Bounty Clearing Ruling:** **Bounty clears to 0 at the start of the next turn** (`START_OF_TURN` `CLEAR`, matching `bounty.tres` and `GameContentDocument.md` L264). `STATUS_BOUNTY_DESC` in `localization/game.csv` (L286) and `docs/status_effects.csv` (L3) have stale text (*"Stays until this unit dies..."*) that will be updated during the terminology pass.
- **Discard Pile Gacha Machine Architecture:** The Discard Pile operates as a 4th Gacha Machine (`scripts/GachaMachineDiscard.gd` and `scripts/battle/InventoryOperations.gd` L121–160). Players draw from it using Tokens, which transfers a random GachaBall from the Discard Pile to its matching Tier Machine (`BattleInventoryT{tier}`) so it can be drawn into play.
- **Removal of "Sacrifice" Myth:** There is no "Sacrifice" mechanic or player ability in the game. The term appeared in earlier AI documentation derived from external card game research (`Monster_Train_2_Effect_Building_Blocks_Reference.md`). The only unit file with the word (`UnitTier3B_GuardianSacrifice.tres`) is actually **Intercept** (`EWWATnkMecApp` leaps to take lethal damage targeting an ally). All references to "Sacrifice" are eliminated.
- **Dead / Unlisted Code Artifacts:**
  - `scripts/effects/EffectStaticDischarge.gd`: Unreferenced by all `.tres` files; assigns nonexistent `battle_manager._is_applying_static_damage = true` (crash on run).
  - `Constants.CAUSE_COST` (`Constants.gd`, L154): Zero references.
  - `&"CAUSE_ABILITY_RETRIGGER"` (`EffectRetriggerTurnAttack.gd`, L64): Live StringName missing from `Constants.gd`.
  - `CombatEvent.Type.DAMAGE_BURN` (L13) & `CombatEvent.Type.APPLY_BURN` (L17): Unused legacy enums.
  - Stale docstrings in `EffectItemSteal.gd` (L9: says Discard Pile, actually moves to `BattleInventoryT{tier}`) and `EffectTransferItemBehind.gd` (L6: says transfers item, actually spawns `1..pass_count` copies).

### 2.4 Intentional Action Constitution Parity Locks (Do Not Regress)

Per `docs/action_constitution_execution_roadmap.md` (L26–30):
1. **Aegis Charm Placement:** Remains on `TRIGGER_WHEN_TAKING_DAMAGE` at `SubPhase.PREVENT_KNOCKOUT_CHECK = 15`.
2. **Inert Dust Elite `&"turn_start"` Resources:** `ability_dust_elite_spawn_turn.tres`, `ability_dust_elite1_spawn_turn.tres`, and `ability_dust_elite2_spawn_turn.tres` intentionally retain `&"turn_start"` for 100% baseline replay parity.

### 2.5 Zero-Tooltip (`DescriptionParser.gd`) & `localization/game.csv` Desyncs

- **Missing Effect Keywords:** `BOUNTY` and planned `REINFORCE` are absent from `DescriptionParser.KEYWORDS` (L4–9).
- **Broken PT-BR `BURN` Keyword on `Scald`:** `ability.scald_l1..l3.desc` (`game.csv`, L430–432) uses `"Queimadura"`, failing to match `KEYWORDS["BURN"]` (`["BURN", "CHAMAS", "CHAMA"]`).
- **Unhighlighted Trigger Phrases in `game.csv`:** `"When an ally is defeated"` (`L49–52, 81, 89, 625`), `"When hurt BY AN ATTACK"` (`L18–20, 29, 47, 106–107, 617`), `"On attack"` (`L112–113`), `"When this unit is healed"` (`L430–432, 635`), and PT-BR `"Quando curado"` (`L427–429`).

---

## 3. Whole-Game Engine Semantic Taxonomy

### 3.1 Domain A — Damage, Mitigation, Survivability, & Mortality

| Canonical Concept | Engine Primitive | Code Semantics & Approved Ruling |
| :--- | :--- | :--- |
| **Melee Attack Damage** | `apply_damage(..., DamageType.MELEE)` | Direct combat hit (`BasicAttackEffect.gd`, L159). Interceptable by Guardian; **mitigated by Armor**; triggers defender **Spikes** & Toy **Static** reflection; fires **When Taking Melee Attack Damage** & `TRIGGER_ON_DAMAGE_DEALT`. |
| **Ranged Attack Damage** | `apply_damage(..., DamageType.RANGED)` | Distant combat hit (Mirror Slot / Sniper Aim). Interceptable by Guardian; **mitigated by Armor**; **bypasses Spikes** and Static reflection; fires **When Taking Ranged Attack Damage** & `TRIGGER_ON_DAMAGE_DEALT`. |
| **Ability Damage** | `apply_damage(..., DamageType.ABILITY)` | Direct non-attack ability hit (e.g., Fusion Spark, Death's Bargain, Mecha lasers, Ambush Predator). **Mitigated by Armor**; single-target commands interceptable by Guardian; does **not** trigger melee Spikes. |
| **Spikes Damage** | `apply_damage(..., DamageType.SPIKES)` | Retaliatory melee damage equal to defender's active Spikes stacks (`BattleManager.gd`, L2269–2285). **Mitigated by Armor**; bypasses Guardian; loses `1` stack per activation; credits defender on KO. |
| **Static Damage** | `apply_damage(..., DamageType.STATIC)` | Collateral discharge on Knockout to living adjacent allies (`KnockoutProcessor.gd`, L704–758) or Toy L4 enemy detonation (L790–845). **Mitigated by Armor**; bypasses Guardian; fires **When Taking Status Damage**. |
| **Burn Damage** | `apply_damage(..., DamageType.BURN)` | End-of-turn damage equal to `burn` stacks (`BattleManager.gd`, L3271). **Bypasses Armor completely**; bypasses Guardian; fires **When Taking Status Damage**. |
| **Heal** | `apply_stat_delta("hp", +X, ACTION_HEAL)` | Unbounded positive HP gain routing to **When Healed** (`Scald`, `Mud Coating`, `Plant L4`). Never echoed by `Buff Echo`. |
| **Lifesteal** | `TRIGGER_ON_DAMAGE_DEALT` $\to$ `ACTION_HEAL` | Post-hit `Heal` scaled off unmitigated damage dealt (`Lifesteal Ring`). |
| **Prevent Knockout** | `EffectPreventLethal` (`PREVENT_KNOCKOUT`) | **Approved Ruling:** Pure state-floor rescue (`current_hp = 1`) once per turn per team. Must **not** use `ACTION_HEAL`, create `battle_heal` merge components, or fire `TRIGGER_WHEN_HEALED` / `Plant L4`. |
| **Knockout (KO)** | `KnockoutProcessor.process_knockouts()` | Authoritative removal of a lineup unit at `current_hp <= 0` (`CombatEvent.Type.KNOCKED_OUT`). Fires `on_knockout_blow` $\to$ `when_knocked_out` $\to$ `when_ally_knocked_out`. |
| **Instant Knockout** | `_process_death_slots_end_of_turn()` | Direct state elimination (`unit.current_hp = 0`, `BattleManager.gd` L3471) on Turn 10+ **Death Slots**. Bypasses Damage, Armor, and Prevent Knockout. |

---

### 3.2 Domain B — Numeric Stat Mutation & Persistence Layers

**Approved 2-Channel Mortality Law:** Only **Damage** and **Instant Knockout** (`Death Slot`) can reduce a unit to `<= 0 HP`. All battle `ACTION_DEBUFF` HP losses (`Costume` steal, `Golden Seal` spend adjustment) must clamp at **`1 HP`** (`PWR` at **`0 PWR`**), and stat steals only grant the clamped delta actually lost.

| Layer / Concept | Engine Representation | Survives Battle End? | Inherited on Level Up / Merge? | Inherited on Transform? |
| :--- | :--- | :---: | :---: | :---: |
| **Base Definition Stats** | `UnitDefinition.base_hp / base_pwr` | Yes | Target base stats | Target def base |
| **Level Scaling** | `StatComponent` (`LEVEL_BONUS`) | Yes | Recomputed from new level | Recomputed from target level |
| **Permanent Buff** | `StatComponent` (`PERMANENT_UPGRADE` in `components`) | **Yes** | **Yes** | **Yes** |
| **Out-of-Battle Consumable** | `StatComponent` (`CONSUMABLE` in `components`) | **Yes** | **Yes** | **Yes** |
| **In-Battle Consumable** | `StatComponent` (`CONSUMABLE` in `battle_components`) | No | Yes | Yes |
| **Battle Buff / Echo** | `ACTION_BUFF` $\to$ `BATTLE_BUFF` in `battle_components` | No | Yes | Yes |
| **Battle Heal Gain** | `ACTION_HEAL` $\to$ `battle_heal` in `battle_components` | No | Yes | Align to **Yes** (`§2.1 #4`) |
| **Battle Debuff / Steal** | `ACTION_DEBUFF` (clamped: `HP >= 1`, `PWR >= 0`) | No | Positive net only | Positive net only |
| **While Equipped** | Virtual `EQUIPMENT` component (`equipped_item_uuids`) | Yes (while equipped) | Recomputed from kept items | Preserved |
| **Conditional Buff** | `CONDITIONAL_TRINKET` / `CONDITIONAL_ABILITY` | Re-evaluated dynamically | **Excluded** (re-evaluated) | **Excluded** (re-evaluated) |
| **Stat Debt (`_hp_debt`, `_pwr_debt`)** | `GachaBallInstance._hp_debt / _pwr_debt` | Cleared on reset | Not inherited | Not inherited |

---

### 3.3 Domain C — Positive & Negative Effects

| Effect ID | Polarity | Turn Timing & Decay Rule | Reactive & Special Rules |
| :--- | :---: | :--- | :--- |
| **`armor`** | Positive | Clears to `0` at **Turn End** | Absorbs Melee, Ranged, Ability, Spikes, and Static hits `1:1`. Preserved by **Reinforce**. **Tank L4:** Gaining Armor grants equal Spikes. |
| **`reinforce`** *(Planned)* | Positive | Decrements by `1` stack at **Turn End** | While active, prevents the unit's **Armor** from clearing at Turn End (`GameContentDocument.md`, L71). |
| **`spikes`** | Positive | **No turn-end decay.** Loses `1` stack per activation. | Deals damage equal to active stacks back to **Melee** attackers. Bypassed by **Ranged Attacks**. **Earth L3+:** Adds Spikes stacks to outgoing Melee Attacks and loses `1` stack. |
| **`burn`** | Negative | Deals damage equal to stacks at **Turn End**, then **halves** ($\lfloor n/2 \rfloor$) | **Ignores Armor completely.** Stacks on a **Burn Slot** do not halve at Turn End. **Fire:** Spreads on tick, boosts attacks vs burning targets, redistributes stacks on KO. |
| **`static`** | Negative | Decrements by `1` stack at **Turn End** | **When Knocked Out**, deals damage equal to stacks to living adjacent Lineup allies (**mitigated by Armor**), then clears. **Toy:** Reflects Static on melee contact and detonates highest-Static enemy on Toy KO. |
| **`bounty`** | Negative | **Clears to `0` at the start of the next turn.** | When the marked unit is knocked out by any means, awards `1 Gold` and fires *On Bounty Claimed*. |

**Trait Effect Conversions:** **Appliance** (Static immunity, effect reflection, `Burn -> +HP` / `Static -> +PWR`); **Water** (pre-combat cleanse, turn-start consume negative effects to `Heal`); **Templar** (`CONVERT_PWR_TO_HP` buff conversion).

---

### 3.4 Domain D — Attack Pipeline, Redirection, & Action Economy

1. **Standard Turn Attack (`CAUSE_TURN`):** Scheduled Actor Queue attack; fires `TRIGGER_WHEN_ATTACKING` $\to$ `BasicAttackEffect` (Melee Attack default).
2. **Attack Override (`replaces_basic_attack = true`):** Replaces Melee Attack (`Hero Pyromancer` Burn attack, `Cascade AOE`).
3. **Delivery & Targeting Override:** `melee` (`FRONTMOST_ENEMY`) vs. `ranged` (`MIRROR_SLOT_ENEMY`, including `Sniper Aim` override; bypasses Spikes and Toy Static reflection).
4. **Transform:**
   - **In-Battle Transform (`EffectMirrorTransform.gd`):** Swaps unit in-slot with a copy of the mirror enemy before acting, preserving equipped items and battle buffs.
   - **Shrine Transform (`TransformShrineAction.gd`):** Permanently changes a GachaBall in your Run Collection into another random GachaBall.
5. **Guardian Interception (`GUARDIAN_INTERCEPT`):** Redirects single-target Melee, Ranged, or Ability hits to an allied interceptor (`EWWATnkMecApp` on lethal hit, or **Tank L3**).
6. **Cleave & Cascade (`CascadeCommand` / Fighter L3):** Propagates secondary splash damage behind the primary target.
7. **Extra Attack (`EffectRetriggerTurnAttack.gd` — `Tiger's Spirit`):** Immediate extra attack at `SubPhase.DOUBLE_STRIKE_FOLLOWUP = 245` (`CAUSE_ABILITY_RETRIGGER`, non-stacking).
8. **Extra Action (`grant_extra_action` — `Bloodlust Edge` / Fighter L4):** Re-queues the unit in the Actor Queue to take an entire extra turn action (max 1/turn).
9. **Retaliation & Pre-Knockout Attacks:** `EffectCounterAttack.gd` / `Vengeful Thorn` / Fighter L2 (`execute_before_knockout = true` runs in `Phase.LETHAL_COUNTER` before casualty removal); `Hero Avenger` ally-KO leap; `Death's Bargain` on-KO strike.

---

### 3.5 Domain E — Battlefield Slots & Terrain Progression

- **`slot_burn` (`Burn Slot`, `3 Gold`):** Applies `1 Burn` at turn start; occupant's Burn stacks do not decay at Turn End.
- **`slot_lightning` (`Lightning Slot`, `2 Gold`):** Applies `1 Static` at turn start.
- **`death` (`Death Slot`, Turn `>= 10` Sudden Death):** Advances inward at turn end, executing an **Instant Knockout** (`0 HP`) on any occupant.

---

### 3.6 Domain F — Containers, Entity Lifecycle, Traits, & Dual Economy

- **Containers:** Run-scope (`PlayerLineup`, `PlayerBench`, `RunInventoryT1..T3`, `PlayerTrinkets`) vs. Battle-scope clones (`BattleInventoryT1..T3`, `DiscardPile`, `EnemyLineup`, `EnemyTrinkets`, `EnemyGraveyard`).
- **Gacha & Discard Operations:** `DrawGachaAction` (`1/2/3` Tokens, discounted by `Bargain Charm` / Specialist L2), `DrawDiscardAction` (draws from Discard Pile Gacha Machine into matching `BattleInventoryT{tier}`), `MoveInventoryAction` / `ConfirmSwapAction`, `ConfirmMergeAction` / `MergeEncounterAction` (**On Level Up** vs. **On Merge** under **On Merge Action**), `Summon`, `Resurrect` (`Soul Echo` fresh Level 1 base copy), `Duplicate to Gacha` (`Doppleganger`, `Echoing Orb`), `Replace Item` (sends previous item to Discard Pile), `Plunder Item` (`Potion of Plunder` $\to$ `BattleInventoryT{tier}`).
- **Traits & Souls:** Requires matching **Sigil** (`trinket_trait_*`, except Hero-innate traits like `Aprendice` `Scholars`).
  - **Elemental Traits (`Fire`, `Earth`, `Water`, `Air`):** Scale on total **Elemental Souls** on active Lineup (`3 / 6 / 12 / 20 / 32` Souls), including **Random Souls (`?`)**.
  - **Class Traits (`Tank`, `Fighter`, `Support`, `Specialist`, `Mercenary`, `Scholars`):** Scale on count of **living Lineup Units** (`2 / 3 / 4 / 5` Units).
  - **Thematic Traits (`Food`, `Mecha`, `Animal`, `Plant`, `Toy`, `Appliance`, `Costume`):** Scale on count of **living Lineup Units** (`2 / 3 / 4 / 5` Units).
  - Snapshot-locked at combat start (`_lock_traits()`).
- **Dual Economy & Minigame:** Persistent **Gold** (`earn_gold` / `spend_gold`) vs. Encounter **Tokens** (**Current Tokens**, **Session Tokens**, **Guaranteed Tokens**, **Saved Tokens**), driven by Flashcard SRS sessions (**Mastery Level 1–5**, **Correct Answer**, **Incorrect Answer**, **Skip**, **Streak**, **Starting Time**, **Remaining Time**, and non-battle **"Get Tokens" Events**).

---

## 4. Trigger & Event Reference Summary

### 4.1 Dispatched Battle & Management Triggers (`Constants.gd`)

- **Phase / Turn Framing:** `TRIGGER_PRE_COMBAT` (`&"pre_combat"`), `TRIGGER_AT_BATTLE_START` (`&"at_battle_start"`), `TRIGGER_AT_TURN_START` (`&"at_turn_start"`, SubPhase `100`), `TRIGGER_AT_TURN_END` (`&"at_turn_end"`, SubPhase `300`). *(Planned Minigame hooks: `before_minigame`, `on_correct_answer`, `at_minigame_end`).*
- **Attack & Damage:**
  - `TRIGGER_WHEN_ATTACKING` (SubPhase `60` / `95`)
  - `TRIGGER_INTERCEPT_ATTACK` (SubPhase `10`)
  - `TRIGGER_BEFORE_TAKING_DAMAGE` (SubPhase `90`)
  - **When Taking Damage (Group):** `TRIGGER_WHEN_TAKING_DAMAGE` (SubPhase `15` Aegis / `61` standard), with granular triggers **When Taking Melee Attack Damage** and **When Taking Ranged Attack Damage**.
  - `TRIGGER_WHEN_ALLY_TAKES_DAMAGE` (SubPhase `61`)
  - `TRIGGER_ON_DAMAGE_DEALT` (SubPhase `61`)
  - `TRIGGER_WHEN_TAKING_STATUS_DAMAGE` (approved for *Purifying Pendant*)
- **Mortality:** `TRIGGER_BEFORE_BEING_KNOCKED_OUT` (SubPhase `25`), `TRIGGER_ON_KNOCKOUT_BLOW` (SubPhase `150`), `TRIGGER_WHEN_KNOCKED_OUT` (SubPhase `12` / `25` / `40`), `TRIGGER_WHEN_ALLY_KNOCKED_OUT` (SubPhase `30` / `170`), `TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT`.
- **Stats, Board, & Merging:**
  - `TRIGGER_WHEN_HEALED` (SubPhase `61`)
  - `TRIGGER_ON_STAT_INCREASED` (SubPhase `190`)
  - `TRIGGER_ON_STAT_DECREASED` (SubPhase `190`)
  - `TRIGGER_WHEN_ALLY_SUMMONED` (SubPhase `50`), `TRIGGER_WHEN_ENEMY_SUMMONED` (SubPhase `62`)
  - `TRIGGER_ON_ENTER_BOARD` (SubPhase `64`), `TRIGGER_ON_BOARD_STATE_CHANGED` (SubPhase `64`)
  - **On Merge Action (Group):** `On Level Up` (identical units) and `On Merge` (recipe evolution, SubPhase `70`).
  - `TRIGGER_ON_GACHA_DRAW`, `TRIGGER_ON_GACHA_TOKENS_CHANGED`, `TRIGGER_ON_GOLD_EARNED`, `TRIGGER_ON_BOUNTY_CLAIMED`.
- **Non-Resolver Metadata Labels:** `&"manual_activation"` (Consumables), `&"gacha_draw_cost"` (`Bargain Charm`), `&"minigame_start"` (`Beginner's Charm`, `Sprint Charm`), `&"passive"` / `&"on_passive"` (`Timekeeper`, `Burn Vial`).

### 4.2 Presentation Events (`CombatEvent.Type`)

Active VCR event types: `ATTACK`, `DAMAGE`, `HEAL`, `BUFF`, `DEBUFF`, `STATUS_EFFECT`, `PREVENT_KNOCKOUT`, `KNOCKED_OUT`, `SUMMON`, `TRANSFORM`, `GUARDIAN_INTERCEPT`, `ITEM_EQUIP`, `ITEM_DISCARD`, `ITEM_TRANSFER`, `GOLD_CHANGE`, `TOKEN_GAIN`, `SLOT_EFFECT_CHANGE`, `TURN_START`, `TURN_END`, `VICTORY`, `DEFEAT`, `LOG_MESSAGE`.  
*(Legacy dead enums to prune: `DAMAGE_BURN`, `APPLY_BURN`).*

---

## 5. Approved Implementation Roadmap (Hold Until Glossary Sign-Off)

1. **Terminology Sign-Off First:** Review and approve `docs/Game_Terminology_Glossary.md`.
2. **Master Content & Localization Sync:** Apply the approved vocabulary across `docs/GameContentDocument.md`, `docs/*.csv`, `DescriptionParser.gd` (`BOUNTY`, `REINFORCE`, PT-BR `"Chamas"`, trigger phrases), and `localization/game.csv` (`STATUS_BOUNTY_DESC` turn-start decay, constitutional trigger phrases with brevity and zero flavor text).
3. **Simulation Bug & Architecture Fixes:**
   - Decouple `EffectPreventLethal.gd` from `ACTION_HEAL` (`current_hp = 1` pure state floor).
   - Enforce `1 HP` / `0 PWR` floor on `BattleManager.apply_stat_delta(..., ACTION_DEBUFF)` and clamp `EffectTraitCostumePreCombat._steal_hp()`.
   - Add `TRIGGER_WHEN_TAKING_STATUS_DAMAGE` and wire `Purifying Pendant` (`EffectPurifyHeal.gd`).
   - Align `Mirror Transform` (`EffectHandlers.gd`) `battle_heal` inheritance with `MergeManager.gd`.
   - Migrate hidden `status_effects` / `set_meta` scalers (`Twin Charm`, `Doppleganger`, `Echoing Orb`, `Golden Seal`) into `CONDITIONAL_ABILITY` `battle_components`.
   - Delete dead `scripts/effects/EffectStaticDischarge.gd`, register `CAUSE_ABILITY_RETRIGGER` in `Constants.gd`, and remove unused `CAUSE_COST`, `DAMAGE_BURN`, and `APPLY_BURN`.
