# Hero Set Proposal: Bounty Hunter

**Status:** Design proposal

**Scope:** Bounty Hunter, Mercenary trait, unit and item lineages, Mercenary Emblem, and supporting trinkets

**Design goal:** Make Gold valuable in battle as both a trigger and a spendable resource, while letting unusually strong builds emerge without a hard generation ceiling.

This proposal follows the GDD's deterministic merge rules and closed Hero-pack approach. It uses the four neutral Tier 1 units and two neutral Tier 1 items as recipe parents. The unit lineage contains one unique Tier 1 unit, four Tier 2 crossbreeds, and all six Tier 3 pairings of those four Tier 2 units.

## 1. Unit placeholder naming convention

The game-content refactor documentation defines unit placeholder names as a compact record of their elemental souls and traits. Use that convention for every unit in this set instead of inventing fantasy names.

**Formula:** elemental soul letters first, then class-trait abbreviations, then visual-trait abbreviations.

| Code group | Codes |
|---|---|
| Elemental souls | `E` = Earth, `F` = Fire, `W` = Water, `A` = Air. Repeat a letter for multiple souls. Standard units carry 1 soul at Tier 1, 2 at Tier 2, and 4 at Tier 3. |
| Class-position codes | `Tnk` = Tank, `Fig` = Fighter, `Sup` = Support, `Spe` = Specialist. Add `Mer` = Mercenary after the existing class codes. |
| Visual traits | `Fod` = Food, `Mec` = Mecha, `Ani` = Animal, `Pla` = Plant, `Toy` = Toy, `App` = Appliance, `Cos` = Costume. |

For this lineage, the Tier 1 Mercenary unit is assigned one fixed Earth soul as a design assumption. This keeps the normal 1 / 2 / 4 elemental-soul progression through its Tier 2 and Tier 3 recipes. It does not affect the Hero's separately randomized elemental trait. The placeholder code is used as the unit ID and display-name placeholder; it is not a separate character name.

## 2. Hero

| Field | Proposal |
|---|---|
| Name | Bounty Hunter |
| Base stats | 10 HP / 2 PWR (keep current values) |
| Fixed trait | Mercenary |
| Run-specific traits | One randomly assigned Elemental trait and one randomly assigned Class or Visual trait. Roll once when the Hero is selected and keep the result for the run. |
| Ability | **Bounty:** When the Hero defeats an enemy, earn 1 Gold. |
| Removed ability | Remove “When an ally is defeated, gain +1 HP and +1 PWR.” |

The Hero's random Elemental tag contributes its normal soul count; the random Class or Visual tag contributes one unit toward that trait. The Hero always contributes one Mercenary counter.

## 3. Gold and trigger rules

- **There is no fixed Gold cap per turn or battle.** Balance comes from earning Gold in discrete, conditional events, usually 1 Gold at a time, and from abilities that spend Gold to buy an effect. Rare builds may generate or spend far more than the usual amount.
- Unless an ability explicitly says otherwise, a Gold-generation effect earns **1 Gold per trigger**. This keeps room for multiple abilities to generate separate Gold and lets each gain trigger the rest of the set. Avoid routine effects that grant 2 or more Gold in one trigger.
- Each 1 Gold added is a separate “Gold earned” trigger. An effect that adds more than 1 Gold, if introduced later, triggers other effects once per Gold added.
- “Gold held” means the current run-wallet balance at the time of the check. Effects that spend Gold calculate their power from the wallet **before** paying the Gold cost.
- Spending Gold is not earning Gold and does not trigger Gold-earned abilities. A spent Gold can still lower later current-Gold scaling.
- `EMer` responds to Gold earned from any source while it is in the active lineup, including Gold earned outside battle. It does not trigger while benched. The Mercenary Emblem responds to each Gold earned while equipped, whether its holder is on the lineup or bench.
- Unless an ability says its gains persist for the run or update dynamically with the wallet, stat and status effects from battle abilities follow the game's normal encounter-duration rules.

This supports the intended economy: the Hero, bounty marks, an item death trigger, and Prismatic Mercenary can each generate a separate 1-Gold event. Their triggers can feed `EMer`, the Emblem, the trait, and the items. Costs and setup make large totals difficult, but there is no ceiling that blocks a rare chain.

## 4. Mercenary trait

Mercenary is tracked by the **Mercenary Sigil**. It counts Mercenary-tagged units in the active lineup; the Hero counts as one. A Mercenary Emblem equipped on a unit in the active lineup adds one more Mercenary counter. Trait levels are cumulative.

| Level | Threshold | Effect |
|---|---:|---|
| **Bronze** | 2 Mercenaries | Whenever Gold is earned, the allied unit with the lowest current HP gains +1 HP. |
| **Silver** | 3 Mercenaries | In addition to Bronze, whenever Gold is earned, the Hero gains +1 PWR. |
| **Gold** | 4 Mercenaries | In addition to Bronze and Silver, at pre-combat each Mercenary unit gains +1 Armor for every full 10 Gold currently held. There is no cap. |
| **Prismatic** | 5 Mercenaries | In addition to all previous levels, earn 1 Gold at pre-combat once per turn. This is one 1-Gold event and triggers all effects that respond to Gold earned. |

For deterministic resolution, Prismatic earns its Gold first during pre-combat. That gain triggers Bronze and Silver and any on-Gold effects. Gold then checks the current wallet and applies its Armor per 10-Gold threshold. For example, a 9-Gold wallet becomes 10 Gold before the Gold-level Armor is calculated.

## 5. Unique unit lineage

The four base Tier 1 recipe parents are `ASpeFodToy`, `ETnkPlaToy`, `FFigMecApp`, and `WSupAniCos`. All Mercenary units carry the Mercenary tag. The placeholder names below encode the union of their elemental souls and traits according to the naming convention above.

### Tier 1 starter

| Placeholder ID / name | Tags | Level 1 stats | Level 2 stats | Level 3 stats | Ability |
|---|---|---:|---:|---:|---|
| `EMerSpe` | Earth, Mercenary, Specialist | 1 HP / 1 PWR | 2 HP / 2 PWR | 3 HP / 3 PWR | Whenever 1 Gold is earned while this unit is in the active lineup, it gains +1 HP and +1 PWR. The effect works for any Gold source and does not trigger from the bench. There is no effect-specific ceiling. |

### Tier 2 crossbreeds

Each Tier 2 unit is formed by merging `EMer` with exactly one neutral Tier 1 unit. “On board entry” effects trigger when that unit enters the active lineup and do not repeat at turn start. The level columns show ability scaling at Levels 1 / 2 / 3.

| Placeholder ID / name | Recipe | Proposed base stats | Tags | Ability at Levels 1 / 2 / 3 |
|---|---|---:|---|---|
| `EASpeMerFodToy` | `EMer` + `ASpeFodToy` | 2 HP / 3 PWR | Earth, Air, Specialist, Mercenary, Food, Toy | On board entry, gain +1 / +2 / +3 PWR for every full 10 Gold held. This is uncapped and resolves once for that board entry. |
| `EETnkMerPlaToy` | `EMer` + `ETnkPlaToy` | 3 HP / 1 PWR | 2 Earth, Tank, Mercenary, Plant, Toy | Whenever 1 Gold is earned, gain +1 / +2 / +3 Armor and +1 / +2 / +3 Spikes. Each 1 Gold earned triggers the ability. |
| `EFFigMerMecApp` | `EMer` + `FFigMecApp` | 2 HP / 3 PWR | Earth, Fire, Fighter, Mercenary, Mecha, ApplianceWhen this ranged unit attacks, mark its target with Bounty if that target is not already marked. At Level 1, it marks only its target; at Level 2, it marks its target and one random unmarked unit; at Level 3, it marks its target and adjacent units. If a marked unit dies by any means, earn 1 Gold. A mark stays until that unit dies or the battle ends. |
| `EWSupMerAniCos` | `EMer` + `WSupAniCos` | 3 HP / 2 PWR | Earth, Water, Support, Mercenary, Animal, Costume | Whenever 1 Gold is earned, heal a random allied unit for 1 / 2 / 3 HP. Each 1 Gold earned triggers the ability. |

### Tier 3 crossbreeds

All six pairs of the four Tier 2 Mercenary units create a distinct Tier 3 unit. Gold thresholds use the current wallet at resolution and are uncapped. For spend abilities, calculate the bonus from Gold held before paying the cost. The stat changes follow normal encounter-duration rules unless described as a dynamic wallet-based effect.

| Placeholder ID / name | Recipe | Proposed base stats | Ability at Levels 1 / 2 / 3 |
|---|---|---:|---|
| `EEEATnkSpeMerFodPlaToy` | `EASpeMerFodToy` + `EETnkMerPlaToy` | 5 HP / 5 PWR | **Pre-combat:** Spend 1 Gold to gain +1 / +2 / +3 Armor and +1 / +2 / +3 Spikes for every full 10 Gold held before the spend. If fewer than 10 Gold is held, do not spend Gold. |
| `EEFWFigSupMerAniMecAppCos` | `EFFigMerMecApp` + `EWSupMerAniCos` | 5 HP / 5 PWR | ****On attack:** Spend 1 Gold to deal +1 / +2 / +3 bonus damage for every full 10 Gold held before the spend. If fewer than 10 Gold is held, do not spend Gold and make a normal ranged attack. |
| `EEWASupSpeMerFodAniToyCos` | `EASpeMerFodToy` + `EWSupMerAniCos` | 5 HP / 5 PWR | Whenever Gold is earned, heal a random allied unit, including the Hero, for 1 / 2 / 3 HP per 1 Gold earned. |
| `EEFAFigSpeMerFodMecToyApp` | `EASpeMerFodToy` + `EFFigMerMecApp` | 5 HP / 5 PWR | **On attack:** If at least 10 Gold is held, spend 1 Gold and apply 1 / 2 / 3 Burn for every full 10 Gold held before the spend. If fewer than 10 Gold is held, do not spend Gold and make a normal attack. |
| `EEEFTnkFigMerMecPlaToyApp` | `EETnkMerPlaToy` + `EFFigMerMecApp` | 5 HP / 5 PWR | **When hurt, before damage is applied:** If at least 10 Gold is held, spend 1 Gold and reduce the incoming damage by 1 / 2 / 3 for every full 10 Gold held before the spend, to a minimum of 0 damage. If fewer than 10 Gold is held, do not spend Gold. |
| `EEEWTnkSupMerAniPlaToyCos` | `EETnkMerPlaToy` + `EWSupMerAniCos` | 5 HP / 5 PWR | **Turn start:** If at least 10 Gold is held, spend 1 Gold and gain +1 / +2 / +3 HP and +1 / +2 / +3 PWR for every full 10 Gold held before the spend. If fewer than 10 Gold is held, do not spend Gold. |

All six pairs are listed explicitly so that the recipe graph stays closed and deterministic. The three Gold-spending capstones make holding Gold powerful but costly over multiple turns; the other three preserve wallet value and scale without a ceiling.

### Bounty mark

**Bounty** is a new battle mark/status effect. It decays at the start of turn. When a marked unit is defeated by any means. Bounty marks can be applied by `EFFigMerMecApp` and Wanted Poster. A Bounty death counts as a normal Gold-earned event for all other abilities.

## 6. Unique item lineage

The item lineage uses the two neutral Tier 1 items, `item_t1_a` (Koi's Blessing) and `item_t1_b` (Tiger's Spirit). These are separate from the standalone Mercenary Emblem.

| Item | Tier and recipe | Stats | Ability |
|---|---|---:|---|
| **Claim Ticket** | Tier 1 unique | +1 HP | When the holder dies, earn 1 Gold. |
| **Interest Ledger** | Tier 2: Claim Ticket + `item_t1_a` | +2 HP | Whenever 1 Gold is earned, heal the holder for 1 HP. |
| **Loaded Contract** | Tier 2: Claim Ticket + `item_t1_b` | +2 PWR | Whenever 1 Gold is earned, the holder gains +1 PWR. |
| **Golden Seal** | Tier 3: Interest Ledger + Loaded Contract | +2 HP / +2 PWR | Dynamically grants +1 HP and +1 PWR for every full 10 Gold currently held. Apply the buff when equipped and recalculate it whenever the Gold wallet changes. The bonus has no cap and can increase or decrease as Gold is earned or spent. |

Claim Ticket is a one-Gold death trigger. Its Tier 2 recipes turn each later Gold event into sustain or attack power. Golden Seal rewards a large wallet while still letting the player spend Gold and accept a lower bonus afterward.

### Mercenary Emblem

| Item | Tier and recipe | Traits/effect |
|---|---|---|
| **Mercenary Emblem** | Tier 3 standalone item; no merge recipe | While equipped, contributes +1 Mercenary counter to its holder for trait counting. Whenever 1 Gold is earned while equipped, the holder gains +1 HP and +1 PWR. This works while the holder is on the lineup or bench and has no cap. |

The Emblem opens a Mercenary trait slot on a non-Mercenary unit and acts as a second Gold-to-stat engine. Its trait counter counts toward the active lineup only when its holder is on the lineup.

## 7. Supporting trinkets

| Trinket | Proposed effect |
|---|---|
| **Mercenary Sigil** | Enables and tracks the cumulative Mercenary trait levels at 2 / 3 / 4 / 5 counters. |
| **Recruiting Charm** | At turn start, if the player has at least 1 Gold and a bench slot is open, spend 1 Gold to hire one Level 1 Tier 1 Mercenary unit: `EMer`Spe. Place it on the bench (summon). If either condition is not met, do nothing and spend nothing. Spending does not trigger Gold-earned effects. |
| **Wanted Poster** | At turn start, mark a random enemy unit that is not already marked with Bounty.  |

Recruiting Charm converts saved Gold into a future merge or lineup option. Wanted Poster creates one additional Gold trigger opportunity each turn without directly awarding Gold when the mark is applied.

## 8. Recipe and balance notes

- The unique Tier 1 unit merges only with the four neutral Tier 1 units listed above. The four resulting Tier 2 units merge only with one another, producing exactly six Tier 3 definitions.
- Tier 2 Mercenary units do not merge with neutral Tier 2 units. Tier 3 units do not merge into further Hero-set recipes.
- The item lineage is Claim Ticket + each neutral Tier 1 item, yielding two Tier 2 items that merge with each other into Golden Seal. Mercenary Emblem is a separate Tier 3 standalone item.
- No ability in this proposal imposes a Gold-per-turn or Gold-per-battle ceiling. The usual event is 1 Gold; spending costs, attack/death conditions, turn frequency, target availability, and saved-wallet requirements keep high Gold totals uncommon. Rare builds may break past normal expectations by chaining multiple sources.
- The `1 Gold` generated by a Bounty mark, Claim Ticket, Hero kill, or Prismatic trait can trigger `EMer`, the Mercenary trait, the Emblem, Interest Ledger, Loaded Contract, `EWSupMerAniCos`, and `EEWASupSpeMerFodAniToyCos`. This overlap is intentional.
- Gold spending is a meaningful cost: attack, defense, and turn-start capstones consume 1 Gold per successful trigger, Recruiting Charm consumes 1 Gold each turn it hires, and spending lowers Golden Seal and wallet-scaled abilities. A player can choose deck investments, saved-Gold scaling, or paid combat bursts.
- Existing Specialist content already includes Gold interactions. Keep Mercenary distinct by leaning on bounty marks, recurring Gold-earned triggers, wallet thresholds, and explicit Gold spending rather than duplicating Specialist discounts.

## 9. Source alignment and assumptions

The proposal follows the current GDD's deterministic merge model, five-slot lineup, tier-level progression, stat inheritance, and run-versus-battle economy. It uses the neutral Tier 1 unit IDs and item IDs in `docs/GameContentDocument.md`. The current Bounty Hunter stays at 10 HP / 2 PWR and keeps the Hero-kill Gold ability; the ally-death HP/PWR ability is removed.

The source naming formula is described in the archived game-content refactor notes, but is not explained in the current Game Content Document. This document repeats the formula and adds `Mer` for the new trait. The fixed Earth soul on `EMer` is a proposal to preserve the standard 1 / 2 / 4 soul counts in Tier 1 / 2 / 3 recipes; if Mercenary units should not have an elemental soul, the recipe names and soul progression need a separate rule.
