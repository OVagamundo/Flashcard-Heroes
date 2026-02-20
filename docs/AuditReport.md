# Flashcard Heroes Documentation Audit Report

## Scope and Method

- Scope: Documentation accuracy audit only (`/docs`), compared against current runtime scripts/scenes/resources.
- Goal: Ensure docs represent implemented behavior and are useful for future feature work and bug fixes.
- Status: Consolidated and corrected from prior report versions.

## Severity Scale

- Critical: Core system behavior is materially misrepresented; likely to cause wrong implementation decisions.
- High: Significant drift/contradiction; likely to cause recurring confusion or incorrect design assumptions.
- Medium: Important stale/inaccurate references; lower immediate gameplay risk but high maintenance cost.
- Low: Quality/portability issues that reduce usability but do not directly change behavior.

## Findings

### F01 - Critical - Economy model conflict across docs and code paths [RESOLVED]
**Resolution:** Code updated to strictly enforce 1/2/4 gold tier costs across the Shop, Encounter Budget, and Reward systems.

- Docs conflict on tier cost model (`1/2/4` vs `1/2/3`) and imply a single rule.
- Runtime uses mixed logic: shop purchase price is derived from `tier` in UI flow, while encounter generation uses each definition's `cost`.
- Impact: Economy balancing and future feature work can be implemented against the wrong model.
- Evidence:
`docs/GameplayDocument.md:100`
`docs/EncounterSystem.md:24`
`scripts/Shop.gd:95`
`scripts/GameManager.gd:417`
`scripts/EncounterGenerator.gd:446`

### F02 - Critical - Merge behavior documented as additive inheritance does not match implementation [RESOLVED]
**Resolution:** Code updated to calculate merges as the sum of parents' current stats. Base stats are properly persisted across battles using new `base_hp_modifier` properties.

- Docs describe additive stat/status/ability inheritance from both parents.
- Merge code initializes a new instance from result definition, subtracts parent item bonuses before re-equip, and does not merge parent status dictionaries.
- Impact: Merge design documentation is not reliable for implementing or balancing merge-related systems.
- Evidence:
`docs/GameplayDocument.md:311`
`docs/GameplayDocument.md:319`
`docs/GameContentDocument.md:13`
`scripts/MergeManager.gd:19`
`scripts/MergeManager.gd:33`
`scripts/GachaBallInstance.gd:29`

### F03 - Critical - Encounter docs claim guaranteed full budget spend, but generator allows overflow [RESOLVED]
**Resolution:** Code updated with a deterministic greedy knapsack algorithm that mathematically guarantees 100% budget spend.

- Docs state guaranteed 100% budget spend.
- Generator explicitly tracks unspent overflow and can leave budget unused.
- Impact: Encounter difficulty assumptions in docs are overstated.
- Evidence:
`docs/EncounterSystem.md:8`
`docs/EncounterSystem.md:43`
`scripts/EncounterGenerator.gd:247`
`scripts/EncounterGenerator.gd:249`

### F04 - High - Hero HP persistence is internally contradictory in GDD and diverges from battle-copy behavior [RESOLVED]
**Resolution:** Code behavior is confirmed as correct. Hero works like other units in battle (starts fresh from base, changes discarded), but out-of-battle stat changes permanently affect base stats.

- Same document says run HP persists between encounters and also says hero starts battles fresh.
- Runtime uses fresh battle copies and discards battle HP changes at battle end.
- Impact: Core run-survival rules are unclear in canonical design docs.
- Evidence:
`docs/Flashcard Heroes GDD.md:19`
`docs/Flashcard Heroes GDD.md:146`
`scripts/BattleManager.gd:149`
`scripts/BattleManager.gd:875`

### F05 - High - Rest-site stat rewards documented as linear, implemented as generic gacha [RESOLVED]
**Resolution**: RESOLVED. `FlashcardSystem.md` updated to reflect the runtime behavior where tokens are earned and used to spin stat machines at the Rest Site.
- Docs state: "Every 2 correct answers = +1 chosen stat".
- Runtime implements a token-gain system driving stat-gacha machines with costs.
- Impact: Reward expectations in design do not match economy implemented.
- Evidence:
`docs/FlashcardSystem.md:115`
`scripts/RestSite.gd:162`

### F06 - High - Deck expansion rule is stricter than documented [RESOLVED]
**Resolution**: RESOLVED. `RunState.gd` and `FlashcardSystem.md` updated to enforce and document that deck expansion is gated by all active cards reaching at least Mastery Level 3.
- Docs imply one new card per minigame trigger/session.
- Runtime gates expansion on intro progression and review state checks.
- Impact: Flashcard progression planning/testing against docs will fail.
- Evidence:
`docs/FlashcardSystem.md:55`
`docs/Flashcard Heroes GDD.md:29`
`scripts/FlashcardManager.gd:133`
`scripts/RunState.gd:795`
`scripts/RunState.gd:813`

### F07 - High - Inspection interaction model changed, docs still reference double-click [RESOLVED]
**Resolution**: RESOLVED. `Flashcard Heroes GDD.md` updated to correctly document the "Hover-to-Inspect" and "Single-Click Lock" model.
- Runtime inspection model is hover-to-inspect + single-click lock.
- GDD still documents double-click in interactive contexts.
- Impact: UX specs and QA test cases are stale.
- Evidence:
`docs/Flashcard Heroes GDD.md:207`
`scripts/GachaBallView.gd:1041`
`scripts/GlobalInteractionRouter.gd:110`
`scripts/GlobalInteractionRouter.gd:568`

### F08 - High - Event node documented but not present in active path generation/handling [RESOLVED]
**Resolution**: RESOLVED. `Flashcard Heroes GDD.md` updated to remove Event Nodes from the active path generation list, accurately reflecting the current Battle/Elite/Shop/Rest options.
- GDD includes Event nodes as active run flow elements.
- Runtime path options are Battle/Elite/Shop/Rest only.
- Impact: Progression flow docs misrepresent available node types.
- Evidence:
`docs/Flashcard Heroes GDD.md:145`
`scripts/PathChoice.gd:61`
`scripts/GameManager.gd:348`

### F09 - High - Shop services in GDD exceed implemented shop behavior [RESOLVED]
**Resolution**: RESOLVED. The documentation describes planned features (removing and transforming services) that will be implemented soon. The documentation is considered correct and will remain as-is.
- GDD describes remove/transform services in shop.
- Runtime shop currently supports buy/reroll/leave only.
- Impact: Feature assumptions from docs are ahead of implementation.
- Evidence:
`docs/Flashcard Heroes GDD.md:144`
`scripts/Shop.gd:23`
`scripts/Shop.gd:208`

### F10 - High - Meta-progression documented as active but not present in runtime UI/systems [RESOLVED]
**Resolution**: RESOLVED. Similar to F09, the documentation describes planned features (Achievements/Codex) that will be implemented soon. The documentation is considered correct and will remain as-is.
- Docs describe Achievements/Codex screens and title access.
- Title scene/script expose Start/Continue/Options/tutorial toggle; no Achievements/Codex flow found in active UI.
- Impact: Documentation overstates shipped systems.
- Evidence:
`docs/ProgressionSystems.md:44`
`docs/Flashcard Heroes GDD.md:220`
`scripts/Title.gd:4`
`scenes/Title.tscn:42`

### F11 - High - Reward reroll documentation excludes trinket reward screens, code rerolls them [RESOLVED]
**Resolution**: RESOLVED. `ProgressionSystems.md` was updated to note that reward rerolls are a future Trinket feature, but are currently enabled by default for testing purposes.
- Progression docs say reroll excludes trinket reward screen.
- Runtime reroll path regenerates special trinket reward pools.
- Impact: Reward economy design docs are inaccurate.
- Evidence:
`docs/ProgressionSystems.md:39`
`scripts/GameManager.gd:477`
`scripts/Reward.gd:77`

### F12 - High - Status effect state is stale in docs (Poison vs current Burn/Armor/Spikes set) [RESOLVED]
**Resolution**: RESOLVED. `Flashcard Heroes GDD.md` was updated to remove Poison as an implemented effect and accurately list Burn, Armor, and Spikes.
- GDD and parts of combat docs still reference Poison as implemented.
- Current status resources and active runtime systems are Burn/Armor/Spikes.
- Impact: Content and balance documentation is out of date.
- Evidence:
`docs/Flashcard Heroes GDD.md:170`
`docs/CombatSystem.md:205`
`resources/status_effects/burn.tres:8`
`resources/status_effects/armor.tres:8`
`resources/status_effects/spikes.tres:8`

### F13 - High - "Synced with Codebase" content doc has verified stale entries [RESOLVED]
**Resolution**: RESOLVED. Consumables costs are now assigned strictly according to their Tier in the `.tres` files, and `GameContentDocument.md` was updated to reflect this rule and the current item list.

- `consumable_potion_healing_minor` is documented but not present.
- Consumables section implies low-cost pattern; active consumables include cost-5 entries.
- Impact: Content reference doc is not trustworthy as canonical source.
- Evidence:
`docs/GameContentDocument.md:2`
`docs/GameContentDocument.md:103`
`resources/items/consumables/item_potion_spikes.tres:23`
`resources/items/consumables/item_potion_heroism.tres:23`

### F14 - Medium - Encounter fallback mechanism documentation is inaccurate [RESOLVED]
**Resolution**: RESOLVED. Replaced the defensive fallback mechanism in `EncounterGenerator.gd` with hard assertions to strictly enforce exact budget matching rules. Removed outdated documentation in `EncounterSystem.md`.

- Docs state fallback uses DB query (not hardcoded ID).
- Generator fallback first attempts a hardcoded ID before generic fallback.
- Impact: Maintenance expectations around resilience behavior are inaccurate.
- Evidence:
`docs/EncounterSystem.md:99`
`scripts/EncounterGenerator.gd:500`

### F15 - Medium - UI architecture document no longer matches active scene structure/details [RESOLVED]
**Resolution**: RESOLVED. Updated `UIArchitecture.md` to accurately reflect the VBoxContainer and area breakdown in `Main.tscn` as well as correcting the trinket slots metrics to 128x128px.

- Doc hierarchy and component naming are outdated relative to current `Main.tscn`/WindowManager setup.
- Some layout details (example trinket slot sizing narrative) are inconsistent with scene definitions.
- Impact: UI/scene onboarding and change planning are harder than necessary.
- Evidence:
`docs/UIArchitecture.md:12`
`docs/UIArchitecture.md:28`
`scenes/Main.tscn:139`
`scenes/Main.tscn:249`
`scripts/WindowManager.gd:65`

### F16 - Medium - TDD/UIInteraction contain stale container names and missing cross-doc references [RESOLVED]
**Resolution**: RESOLVED. Erased mentions of the extinct `ItemInventory` from interaction lists and rectified the link for `docs/AbilitySystem.md` to map to `docs/AbilityExecutionPipeline.md`.

- `ItemInventory` is still referenced as active container in docs.
- TDD references `docs/AbilitySystem.md`, which is not present in `/docs`.
- Impact: New contributors can follow obsolete pathways.
- Evidence:
`docs/UIInteraction.md:60`
`docs/Flashcard Heroes TDD (Technichal Design Document) V9.0.md:34`
`docs/Flashcard Heroes TDD (Technichal Design Document) V9.0.md:53`
`scripts/GlobalInteractionRouter.gd:887`

### F17 - Medium - Temporary/planning artifacts are mixed with canonical docs [RESOLVED]
**Resolution**: RESOLVED. Merged `AbilityImplementationGuide.md` directly into `AbilityExecutionPipeline.md`. Migrated the outdated `ImplementationBrief` and `Suggestions_and_Analysis` files into a new `docs/archive` subfolder.

- Implementation brief and proposal files are useful history, but currently co-located as peer docs without clear status partition.
- Impact: Harder to identify canonical truth quickly.
- Evidence:
`docs/ImplementationBrief_HoverInspectSelectLock.md:2`
`docs/Suggestions_and_Analysis.md:1`

### F18 - Low - Non-portable absolute `file:///Users/...` links in docs [RESOLVED]
**Resolution**: RESOLVED. Scanned and replaced the machine-local `file:///Users/...` absolute file paths in documentation with working relative links `../`.

- Several guides use machine-local absolute links.
- Impact: Broken navigation for other collaborators/environments.
- Evidence:
`docs/AbilityImplementationGuide.md:40`
`docs/AnimationImplementationGuide.md:218`

### F19 - Low (Inferred) - Rest-site base-stat updates mutate shared definitions in-memory [RESOLVED]
**Resolution:** Code updated to avoid mutating shared `Resource`. Progression stats are now tracked individually per-instance via modifier properties.

- Rest-site applies permanent base-stat changes by mutating the unit definition resource.
- This may leak across runs in the same app session if definitions are reused, depending on lifecycle assumptions.
- Impact: If unintended, docs claiming run-local permanence become ambiguous.
- Evidence:
`scripts/RunState.gd:285`
`scripts/RunState.gd:669`
`scripts/RestSite.gd:530`

## Consolidation Recommendations

- Define a canonical docs index with explicit status tags: `Canonical`, `Reference`, `Archive/Implementation Notes`.
- Unify economy rules into one authoritative source, then reference it from GDD/Gameplay/Encounter docs.
- Reconcile flashcard/rest-site progression docs with current token-machine implementation.
- Update UI interaction docs to reflect hover-inspect/single-click-lock and current GIR group mapping.
- Remove or migrate stale cross-doc references (`AbilitySystem.md`, obsolete container names).

## Out-of-Scope Appendix (Carried from Prior Audit Version)

- Prior report included code-level effect implementation issues not part of this docs-only scope:
`scripts/EffectGrantStatsPerEmptySlot.gd`
`scripts/EffectBuffAllyBehindPWR.gd`
- They may still be valid engineering findings, but they are not documentation drift findings and should be tracked separately in a code-quality audit.
