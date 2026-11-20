# Enemy Trait Banners — Implementation Plan

Status: implemented on 2026-11-12. The blueprint below records the design rationale; current implementation details and measured minimum budgets are documented in `BannerDraftingSystem.md`.

## 1. Design objective

Create a regular enemy banner for each trait whose existing effects function for enemies. Each banner assembles a recognizable combat strategy from the existing unit, item, and trait mechanics, using curated positional pairs and triplets.

The Fire Banner establishes the design principle: Branblee needs healing to produce Armor and Spikes, so Ripplepup is a justified exception to the native Fire unit pool. Ripplepup receives a free Fire Emblem and contributes to the Fire trait while providing the missing healing trigger.

An off-trait unit must have a documented mechanical purpose in its selected package. Merely sharing a package with a native trait unit is insufficient. Approve particular package variants for particular banners and assign their emblems explicitly.

The proposed roster is **14 trait banners**: Fire, Earth, Water, Air, Tank, Fighter, Support, Plant, Food, Animal, Mecha, Toy, Appliance, and Costume.

## 2. Compatibility and existing constraints

| Trait or content | Treatment | Reason |
|---|---|---|
| Mercenary and Novice | Exclude as banner traits, crests, emblems, units, and secondary trinkets | Their mechanics depend on player systems. |
| Specialist | Exclude as a banner trait | Its current ladder depends on tokens, draws, Gold, and a shelf. The crest resource currently says `is_player_exclusive = false`, which conflicts with the content document and functional requirements. That flag alone does not make the ladder enemy compatible. |
| Enemy-valid Specialist units | Permit as curated partners | Puffcorn, Sojikun, and Mimicloak have usable combat abilities independently of the Specialist crest. |
| Furnair, Blendroid, Wind-up-kun, BubbleGunger | Keep excluded | These are already in `ENEMY_EXCLUDED_UNITS`. |
| Soliwhale | Keep primarily in the Lone Whale strategy | Filling the board undermines its empty-slot ability. Native trait membership alone should not admit it into saturated formations. |
| Mecha | Include, but give its merge tier no strategic credit | The current merge laser code is player-side. Enemy Mecha banners can use Spikes, Armor, attack/block Static, and death salvos. |
| Support and Costume | Include | `BattleManager.get_hero_on_team()` currently returns the frontmost living unit when there is no Hero. Their Hero-targeted effects therefore have an existing enemy recipient. |

All 14 banners receive their corresponding existing trait crest for free. Only approved off-trait package members receive the corresponding free emblem. Those emblems retain their existing stats and occupy the existing single item slot.

### Elemental thresholds

Elemental traits count individual souls; class and thematic traits count units. Evaluate the actual equipped formation, not a count of matching unit IDs.

The current eligible base definitions have at most two native souls of any one element per unit. With five units, and emblem exceptions granted only to units lacking that element, these proposed regular drafts can reach at most ten souls of one element. Unit level alone does not multiply the souls returned by `get_trait_soul_counts()`.

Therefore the initial elemental plans must function at **3 and 6 souls**. Do not promise 12/20/32-soul effects, grant extra souls, or change thresholds to make a banner work. Broader elemental progression would be a separate mechanics decision.

## 3. Blueprint for every compatible trait

Formation notation below runs from enemy front to back. An emblem is shown only on an approved unit that lacks the banner trait. These are alternative cores to select between, not a requirement to combine every listed package into one five-slot formation.

### Fire — sustained Burn pressure

- **Existing core:** Branblee → Ripplepup [Fire Emblem]. Ripplepup's healing directly activates Branblee's Armor/Spikes growth and keeps the frontline operating while Fire attacks apply Burn.
- **Additional core:** Pepspray → Ripplepup [Fire Emblem]. This requires a new curated pair. Ripplepup heals Pepspray specifically, activating its Burn fireballs. Alternatively, native Pepspray can hold Candy or Leech Gumi when another package supplies the frontline.
- **Expansion:** Retain the existing Fire triplet, with a real healing source for Pepspray, plus native Vulcannon/Pachinkannon artillery or Tsunamantle pressure. Preserve the distinct existing Burnie composition through a reserved boss slot.
- **Reinforcement priority:** Restore the healer behind a surviving Branblee/Pepspray, or the frontline ahead of a surviving healer, before adding another damage unit.

### Earth — an enduring Spikes frontline

- **Core:** Stumpling or Branblee → Ripplepup [Earth Emblem]. Sustain preserves the frontline that receives Earth's Armor/Spikes; Branblee adds its own healing-driven growth.
- **Advanced core:** Stumpling in Slot 0, then Oakbark → Bogmantle → Nuton [Earth Emblem] in Slots 1–3. Oakbark buffs adjacent Bogmantle; Nuton is adjacent to Bogmantle and copies that eligible HP/PWR buff. Author this exact new triplet instead of relying on the existing Oakbark/Nuton package's claimed multiplication.
- **Expansion:** Favor native Earth units with useful front or rear roles and enough souls to reach six. Use defensive equipment on native units with an available item slot.
- **Reinforcement priority:** Restore the frontline and its sustain or buff partner. Earth remains a defensive attrition strategy rather than relying on unreachable high elemental thresholds.

### Water — healing that activates allied abilities

- **Core:** Branblee [Water Emblem] → Ripplepup. Branblee converts healing into Armor/Spikes; Ripplepup supplies repeated healing and both units contribute Water souls.
- **Other cores:** Stumpling [Water Emblem] → Ripplepup for cheap sustain; Reizokun → Ripplepup for a larger frontline; Pepspray → Ripplepup for healing-driven Burn. The Pepspray pair needs a new package.
- **Expansion:** Native Komatop, Nuton, and Tsunamantle provide concentrated Water souls. Water's positional pre-combat healing and cleansing reinforce a formation intended to outlast debuffs.
- **Reinforcement priority:** Repair healing adjacency and protective coverage before purchasing another attacker.

### Air — build Static, then secure knockouts

- **Core:** Puffcorn → Vulcannon [Air Emblem]. Puffcorn passes PWR into the unit's ranged attacks and reactive damage; Air supplies Static through the attack paths that currently support it.
- **Advanced core:** Griffoam → Pachinkannon, both natively Air, for board-entry punishment and protected ranged pressure. Native Sojikun removes enemy positive effects, helping the team finish targets carrying Static.
- **Expansion:** Prefer native Air units that can attack safely or help finish marked targets. Preserve Puffcorn's death-pass direction and a recipient behind it.
- **Reinforcement priority:** Restore a PWR recipient or protective unit around the surviving attack core. Do not assume every projectile bounce or reaction automatically applies Air's on-attack effects.

### Tank — Armor passing and interception

- **Core:** Branblee → Ripplepup [Tank Emblem]. Healing grows Branblee's Armor/Spikes and enables repeated blocking; Tank's Armor passing helps the rear unit survive.
- **Other cores:** Stumpling → Ripplepup [Tank Emblem], Branblee → Komatop, Reizokun → Komatop. An advanced buff-copy formation uses a native Tank in Slot 0, followed by Oakbark [Tank Emblem] → Bogmantle [Tank Emblem] → Nuton in Slots 1–3. Nuton copies the buff given to adjacent Bogmantle.
- **Expansion:** Prioritize a functioning Armor chain, then four/five Tank thresholds where budget and formation support them. Support units are included for healing or buff triggers, with an explicit Tank Emblem.
- **Reinforcement priority:** Repair holes in the Armor/interception chain. Toughmon can later reuse the same profile with its existing boss reservation and budget policy.

### Fighter — PWR growth into attack pressure

- **Core:** Puffcorn [Fighter Emblem] → Vulcannon or Bogmantle. Puffcorn supplies PWR; Bogmantle also grows from the ally's death. This directly improves the damage that the Fighter ladder rewards.
- **Other core:** Matryodust [Fighter Emblem] → Bogmantle. Matryodust and its replacement provide successive allied deaths for Bogmantle's growth.
- **Expansion:** Native Pachinkannon, Griffoam, Pepspray, and Tsunamantle provide attacking roles. Prefer equipment that benefits the selected unit's actual attack implementation.
- **Reinforcement priority:** Rebuild the growth source in front of a surviving carry or restore pressure units after the core is functioning. Verify which attack routes receive Fighter cleave and extra-action effects.

### Support — positional buffs and copied growth

- **Cheap core:** Stumpling [Support Emblem] → Ripplepup. A durable frontline enables Ripplepup's healing; Support's positional HP buff reinforces that frontline.
- **Advanced core:** Matryodust in Slot 0, then Oakbark → Bogmantle [Support Emblem] → Nuton [Support Emblem] in Slots 1–3. Oakbark buffs Bogmantle and adjacent Nuton copies that increase. Support's positional and turn-start stat buffs reinforce that strategy.
- **Other core:** Matryodust/Matryoshkan → Mechamom. All are naturally Support; the summoner activates Mechamom's entry buff.
- **Reinforcement priority:** Preserve the buff sources, targets, and adjacency. Do not describe HP stat buffs as heals or expect them to trigger Branblee/Pepspray.

### Plant — healing converted into a Spikes wall

- **Core:** Stumpling → Ripplepup [Plant Emblem]. Repeated healing keeps the native Plant frontline alive and gains additional relevance at Plant's healing-to-Spikes tier.
- **Additional core:** Branblee [Plant Emblem] → Ripplepup [Plant Emblem], approved only as an extension of a formation with a native Plant anchor. Branblee converts the healing into Armor/Spikes; the Plant ladder can add further Spikes. This is not a standalone all-converted core.
- **Advanced core:** Stumpling in Slot 0, then Oakbark → Bogmantle [Plant Emblem] → Nuton [Plant Emblem] in Slots 1–3. Oakbark is the native high-tier Plant anchor, Bogmantle receives its adjacent buff, and Nuton copies the buff received by neighboring Bogmantle.
- **Reinforcement priority:** Restore healing or the buff-copy chain. Distinguish this banner from Earth through recurring Plant healing and healing-driven Spikes rather than Earth's opening soul-based defense.

### Food — feed the unit directly behind

- **Core:** Stumpling [Food Emblem] → Pepspray. Stumpling is a durable hurt trigger; Food heals the unit behind it, so Pepspray receives the heal and fires Burn projectiles. Add this as an explicit new package.
- **Advanced core:** Stumpling [Food Emblem] → Pepspray → Nuton. At the relevant Food threshold, Food's PWR buff to Pepspray also gives adjacent Nuton an eligible buff to copy.
- **Other core:** Puffcorn → Bogmantle [Food Emblem] → Nuton, using the existing death-growth triplet. Puffcorn passes PWR, Bogmantle grows on deaths, and Nuton copies adjacent stat growth.
- **Reinforcement priority:** Replace the unit in front of the heal beneficiary or repair the death-pass recipient. The direction of Food's heal is the opposite of Ripplepup's.

### Animal — attack healing activates Armor or Burn

- **Core:** Branblee [Animal Emblem] → Ripplepup. Animal's healing on Branblee's qualifying attacks activates its Armor/Spikes ability; Ripplepup adds another healing source when it is hurt.
- **Other cores:** Pepspray [Animal Emblem] → Ripplepup, so Animal attack healing activates Pepspray's Burn; Stumpling [Animal Emblem] → Ripplepup for a cheap sustain core.
- **Expansion:** Native Griffoam supports later anti-entry pressure. Use the actual Animal heal-on-attack behavior; extra healing does not follow automatically from every special damage event.
- **Reinforcement priority:** Restore converted heal beneficiaries and their native Animal support. Soliwhale remains primarily in its separate empty-slot strategy.

### Mecha — Armor, Static, and attrition salvos

- **Core:** Branblee → Ripplepup [Mecha Emblem]. The healer grows Branblee's Armor, enabling more Armor-absorption Static triggers at the appropriate Mecha threshold.
- **Other core:** Matryodust [Mecha Emblem] → Mechamom. Matryodust supplies a summon for Mechamom's HP buff and an allied Mecha death for the five-unit trait effect when active.
- **Expansion:** Native Vulcannon/Pachinkannon artillery. A new native Relaytron → Vulcannon item-transfer package can preserve a required Scythe without needing an emblem on either endpoint.
- **Reinforcement priority:** Sustain the armored core or replenish the sacrifice/summon role. Give no budget or package-score credit for an enemy merge action that does not occur.

### Toy — punish melee contact and use replacement bodies

- **Core:** Matryodust → Bogmantle [Toy Emblem]. Matryodust supplies allied death events and another body; Bogmantle is the specific growth beneficiary.
- **Other core:** Matryodust/Matryoshkan → Mechamom [Toy Emblem]. Summons activate Mechamom's HP buffs, extending the attrition strategy.
- **Advanced core:** Komatop → Pachinkannon [Toy Emblem]. Komatop protects the damage unit and can take melee contact that activates Toy's Static retaliation.
- **Reinforcement priority:** Replace the missing summoner, growth recipient, or guardian partner. At five Toys, use the existing death detonation. Summoned children do not inherit the parent's Toy Emblem unless existing mechanics explicitly transfer it.

### Appliance — counter hostile statuses while maintaining a damage engine

- **Core:** Reizokun → Ripplepup [Appliance Emblem]. Ripplepup sustains the native tank, while Appliance immunity/reflection protects the formation from Burn and Static strategies.
- **Other core:** Reizokun → Komatop [Appliance Emblem]. Komatop provides lethal protection for the tank.
- **Expansion:** Native Sojikun supplies enemy positive-effect removal. An explicitly approved Sojikun/Pachinkannon [Appliance Emblem] package can pair that removal with ranged finishing pressure if its timing and slots work in the simulator.
- **Reinforcement priority:** Restore the healing/guardian partner or the native Appliance anchor. The usable native anchors are Tier 3, so this banner needs a higher minimum budget; Furnair and Blendroid are not cheap substitutes.

### Costume — opening theft followed by inherited PWR

- **Core:** Puffcorn [Costume Emblem] → Bogmantle. Opening theft improves the initial exchange; Puffcorn then passes its current PWR to Bogmantle, which also grows from the death.
- **Other core:** Matryodust [Costume Emblem] → Bogmantle, combining theft with replacement-body death growth.
- **Expansion:** Native Tsunamantle converts accumulated offensive advantages into cascade pressure. Mimicloak is optional only after confirming its transformation preserves the profile's equipment and trait expectations.
- **Reinforcement priority:** Restore the sacrificial partner or carry. Reinforcements receive only the pre-combat, entry, and turn effects that the existing phase rules actually trigger; summoning does not grant an extra theft execution.

## 4. Shared implementation

### A. Data describes the strategy

Introduce a typed `EnemyTraitBannerProfile` resource and one `TraitBannerDrafter`. Reuse the current package definitions and drafting utilities; do not create fourteen copied drafting scripts.

Each profile describes:

- Banner ID, primary trait, existing crest, and emblem.
- Native unit pool, eligible package variants, and relative package preferences.
- Exact off-trait members allowed in each package, their emblem assignments, and the mechanical reason for including them.
- Required equipment, positional dependencies, upgrade priorities, reinforcement policy, and minimum feasible budget.
- Mutually exclusive cores where two attractive packages cannot share the same slots.

Shared packages retain their actual unit order and mechanical requirements. Banner-specific variants provide the emblem overlay. For example, the generic Branblee/Ripplepup pair needs a healer; a Fire variant equips Fire Emblem on Ripplepup, while a Water variant equips Water Emblem on Branblee.

Review package claims against the executable targeting rules before reusing them. In the documented Stumpling → Oakbark → Nuton triplet, Oakbark buffs Stumpling and Nuton. Nuton cannot copy the buff given to Stumpling because they are two slots apart, and receiving its own buff is not a second copied buff. The proposed Oakbark → Bogmantle → Nuton triplet starts at Slot 1 so Oakbark retains a legal position, Bogmantle is the shared recipient, and Nuton is adjacent to that recipient. It requires a suitable frontline in Slot 0.

Use explicit profile data and stable IDs. Do not infer strategies from localized descriptions, search trinket names for trait substrings, or add ad hoc metadata flags.

### B. Eligibility distinguishes three questions

1. Is every unit/item/crest compatible with enemy play?
2. Is this complete package explicitly approved for this banner, with its required triggers and equipment intact?
3. Does this placement fit the current slots and budget?

Native trait membership is the normal rule for independent fillers. An off-trait singleton is permitted only when it repairs a known approved package around a surviving dependency, and receives its defined emblem.

The current `get_eligible_packages()` applies the caller's unit filter to every package member. Separate universal enemy eligibility from the banner's package-level approval so that a native-only filler filter does not reject the authorized healer or other enabler.

### C. Plan a valid formation before spending on upgrades

For the five-slot board, compare feasible approved core placements and compatible completions before selecting one with seeded RNG. Preserve contiguous package order and required front/behind relationships. Treat incompatible positions and missing required triggers as invalid, rather than just giving them a small score penalty.

Prefer a working core and an activated primary trait over unrelated coverage. Then consider compatible additional packages, single-slot bridging, reachable trait thresholds, and the profile's equipment/level priorities. Use existing stat overflow only after the composition's dependencies are satisfied.

Allow deliberate empty slots when the available budget cannot buy a useful completion. Avoid the current first-open-slot dead end preventing a valid later-slot package or filler from being considered.

### D. Equipment and accounting are resolved before package selection

- Each unit still has one item slot. A package's required Scythe and an emblem cannot occupy the same slot.
- Keep an otherwise conflicting package out of that profile, or author a genuinely different valid variant. Do not discard its required item or silently leave an approved partner without the promised emblem.
- Item-transfer packages also need a compatible receiver: transferring Scythe onto an emblemed partner can replace its emblem and remove the banner trait. Prefer native recipients when preserving the emblem would otherwise be impossible.
- Compute cost from units at their selected levels plus required ordinary items; authorized banner emblems and the primary crest cost zero.
- Fire accounting is centralized: Ripplepup costs 1G in both initial drafts and waves; the Fire triplet costs 6G because it now includes required Candy on Pepspray (5G of units + 1G Candy, with a free emblem).
- Evaluate trait counts and secondary trinket utility from the fully equipped placements. Current board-by-ID voting misses traits added by emblems.

### E. Initial drafting and reinforcements use the same rules

Use a typed board snapshot containing positions, unit IDs, levels, equipment, and effective traits. Reinforcement drafting must understand the actual survivors and their emblem-derived traits.

At the existing reinforcement opportunity:

1. Repair a surviving approved core when a needed partner is missing.
2. Place an affordable approved pair/triplet into a contiguous empty span.
3. Use a native filler only if its slot and role are useful.
4. Spend remaining wave budget according to the existing overflow policy.

Do not move surviving enemy units. Expand the modular reinforcement path beyond its current two-slot package limit so triplets can be used when three contiguous slots are available. Respect current phase and trait snapshot timing.

For a first implementation, use the existing Swarm cadence and 33% wave-budget policy for new regular profiles; retain Fire's existing 50% policy and specialized boss policies. These are proposed reuse choices, not new per-trait balance numbers.

### F. Register resources and gate encounter selection by feasibility

Create one enemy-exclusive banner trinket per new trait profile, using the existing trait icon initially. Register profiles with `BannerDraftingRegistry`, add their localization, and include them in the existing weighted-decay selection pool.

Filter the selection pool using the effective encounter budget after slot effects are known. A banner becomes available when it can afford a valid core that activates its first trait threshold. Do not select an unaffordable banner and replace its identity with unrelated units.

Create cheaper package variants only where existing units genuinely provide the needed interaction. Appliance's expensive native anchors justify later availability. The original Lone Whale and unrestricted Swarm remain separate strategies.

## 5. Implementation sequence and acceptance criteria

1. Add typed profiles, package variants, centralized cost resolution, effective trait counting, and enemy eligibility rules.
2. Build the shared formation planner and core-repair reinforcement path. Use Fire as the first integration case while preserving Burnie's reserved slot and existing policies.
3. Add Water, Earth, Plant, Animal, and Food to establish distinct healing, buffing, and directional trigger behavior.
4. Add Tank, Fighter, Support, Mecha, and Toy; verify equipment transfers, summons, and actual attack-path trait interactions.
5. Add Air, Costume, and Appliance; verify soul feasibility, theft timing, status interactions, and availability gates.
6. Register the complete regular pool and update `BannerDraftingSystem.md`, the package reference, and `EncounterSystem.md`. Maintain `GameContentDocument.md` manually and run the required translation sync when localization changes.

Validate during implementation:

- All 14 profiles can produce a valid first-threshold formation at their minimum feasible budget and scale across representative later budgets.
- No Mercenary/Novice content, Specialist crests, or excluded units enter drafts or secondary trinket selection.
- Each off-trait member has an approved dependency and the correct emblem; no item-slot conflicts occur initially or through required item transfers.
- Simulated event chains demonstrate the intended interaction: Ripplepup heals the dependent in front; Food heals the beneficiary behind; Branblee/Pepspray respond to their own healing; Nuton copies discrete HP/PWR buffs rather than heals or Armor.
- Reinforcements repair isolated missing partners, fill pairs/triplets where legal, and respect the wave budget without rearranging survivors.
- Emblem-derived tags/souls affect the initial trait count, future live counts, trinket voting, and reinforcement decisions correctly.
- Seeded generation is repeatable; resource definitions remain immutable; the drafter has no UI or presentation dependencies.
- Current Fire/Burnie, Lone Whale, Swarm, and existing boss arrangements retain their intended contracts.

Implementation validation is maintained in `tests/trait_banner_suite.tscn` and the existing fast suite. The dedicated suite checks all fourteen banners, exact budget accounting, seeded parity, all casualty patterns, live combat triggers, boss integration, and equipped soul snapshots.

## 6. Source files reviewed

- `docs/BannerDraftingSystem.md`
- `docs/Encounter_Synergies_and_Pairs_Reference.md`
- `docs/EncounterSystem.md`
- `docs/GameContentDocument.md`
- `scripts/systems/EncounterSynergyRegistry.gd`
- `scripts/systems/encounter/BannerDrafter.gd`
- `scripts/systems/encounter/BannerDraftingRegistry.gd`
- `scripts/systems/encounter/drafters/FireBannerDrafter.gd`
- `scripts/systems/encounter/drafters/SwarmBannerDrafter.gd`
- `scripts/systems/encounter/drafters/DustmonBannerDrafter.gd`
- `scripts/systems/encounter/drafters/ToughmonBannerDrafter.gd`
- `scripts/EncounterGenerator.gd`
- `scripts/GachaBallInstance.gd`
- `scripts/BattleManager.gd`
- `scripts/AbilityResolver.gd`
- `scripts/BasicAttackEffect.gd`
- `scripts/EffectTransferItemBehind.gd`
- `scripts/effects/EffectRepeatAdjacentBuff.gd`
- Trait effect scripts and the referenced unit, item, ability, and trinket resources.


## 7. Implementation verification (2026-11-12)

- Fourteen compatible strategies are registered; thirteen new enemy-exclusive trinket resources and thirteen transparent 64×64 PNG icons accompany the existing Fire resource/icon.
- Dedicated Godot regression suite: 434 generated drafts, 432 casualty patterns, exact budget/overflow accounting, deterministic generation, all five-unit class/thematic formations, Fire/Burnie integration, twenty Dustmon trait rolls, repeated dependency-repair checks, live soul snapshots, and actual summon-command equipment/events.
- Live combat checks cover Ripplepup → Branblee, Food → Pepspray → Nuton, Animal attack healing → Pepspray Burn, and Oakbark → Bogmantle → Nuton.
- Both the dedicated suite and the existing eight-part fast suite pass. New icons have been visually inspected and their transparency, dimensions, references and Godot imports checked.
- Free emblems occupy the single item slot. Required healing equipment and item transfers are resolved before a package is approved. Repair priority first restores missing ability triggers, then other partial packages, then new packages and native fillers.
