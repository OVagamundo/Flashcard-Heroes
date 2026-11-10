# Phase 3 Execution Plan: Granular Semantic `SubPhase` Enum Migration

**Master Roadmap:** [action_constitution_execution_roadmap.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/action_constitution_execution_roadmap.md)  
**Constitutional Spec:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) (Sections 5, 6, and 9 — Phase 3)  
**Prerequisite:** Phase 2 `Complete`  
**Assigned Model:** `Gemini 3.8 Flash (High)`

## Phase Goal & Safety Guarantee

Eliminate arbitrary integer `priority` sorting from `AbilityDefinition`, `EffectRequest`, `CausalReactionResolver`, `CombatSimulator`, and all **289 `.tres` resources** that define `priority = ...`, replacing them with a strictly monotonic `Constants.SubPhase` enum sorted **ascending** (`a.sub_phase < b.sub_phase`) — while preserving **100% identical execution order and RNG call sequences across every existing ability interaction in the game**.

| Task | Assigned Model | Focus | Status |
| :--- | :--- | :--- | :---: |
| **3.1** | **Gemini 3.8 Flash (High)** | Define Bijective `Constants.SubPhase` Enum in `Constants.gd` | `Complete` |
| **3.2** | **Gemini 3.8 Flash (High)** | Lockstep Migration of `AbilityDefinition`, `EffectRequest`, `CausalReactionResolver`, Callers & All 289 `.tres` Files | `Complete` |
| **3.3** | **Gemini 3.8 Flash (High)** | Re-Sync Content Docs & Run Static `SubPhase` Cleanliness Audit | `Complete` |

---

## Critical Guardrail: Do NOT Touch `GachaBallComponent.priority`!

> [!CAUTION]
> **Two Completely Separate Systems Used the Word `priority`**:
> 1. **Reaction Queue Sorting (`AbilityDefinition.priority` & `EffectRequest.priority`)** — **MIGRATE THIS** to `sub_phase: Constants.SubPhase`.
> 2. **ECS Component Layering (`GachaBallComponent.priority` in [GachaBallComponent.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/resources/GachaBallComponent.gd) and [GachaBallInstance.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallInstance.gd#L360-L956))** — **DO NOT TOUCH THIS!** Component `priority` (`-1000`, `-900`, `-50`, `slot_index`) controls deterministic stat/tag/equipment component composition order on `GachaBallInstance`, NOT combat reaction timing.
>    - **The ONLY line in `GachaBallInstance.gd` to update is [line 713](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallInstance.gd#L713)**:
>      Replace `"priority": priority_value if priority_value != 0 else ability.priority,`
>      With: `"component_priority": priority_value, "sub_phase": ability.sub_phase,`

---

## Task 3.1 — Define Bijective `Constants.SubPhase` Enum in `Constants.gd` [Complete]
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Add `enum SubPhase` to [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd) with monotonically increasing enum values (`lower value = resolves FIRST`) that preserve **100% bijective order parity** across all **18 distinct `priority` integers** present in live `.tres` files (`500, 300, 250, 220, 215, 210, 205, 200, 120, 110, 100, 60, 50, 10, 0, -10, -50, -100`) plus `EffectRetriggerTurnAttack`'s `-50` follow-up attack.

### Pre-Verified Bijective Mapping Table (Old Descending `priority` -> New Ascending `SubPhase`)

| Old `priority` | Context / Live `.tres` Resources | New `Constants.SubPhase` Member | Int Value |
| :---: | :--- | :--- | :---: |
| `500` | `UnitTier2E_Mimic*.tres` (`before_turn_action`) | `PRE_TURN_TRANSFORM` | `5` |
| `300` | `UnitTier3B_GuardianSacrifice*.tres` (`intercept_attack`) | `PRE_DAMAGE_INTERCEPT` | `10` |
| `300` | `UnitTier1D_EmpathicLink*.tres` (`when_knocked_out`) | `KNOCKOUT_STAT_PASS` | `12` |
| `250` | `trinket_aegis.tres` (`when_taking_damage` + `execute_before_knockout`) | `PREVENT_KNOCKOUT_CHECK` | `15` |
| `220` | `UnitTier3J_Ability.tres`, `ability_trinket_token_return_charm.tres` | `ITEM_TRANSFER` | `20` |
| `215` | `ItemTier3E_DeathDamage.tres` (Death's Bargain), `ability_trinket_doppleganger_death.tres` | `PRE_KNOCKOUT` | `25` |
| `210` | `ability_trinket_soul_echo.tres`, `ability_trinket_vengeance.tres` | `KNOCKOUT_SUMMON_TRINKET` | `30` |
| `205` | `UnitTier3C_SoulSummon*.tres` | `KNOCKOUT_SUMMON_UNIT` | `35` |
| `200` | `item_t2_c_summon.tres`, `ability_trinket_echoing_orb_death.tres` | `KNOCKOUT_SUMMON_ITEM` | `40` |
| `120` | `ability_trinket_*_insignia_summon.tres` | `ON_SUMMON_INSIGNIA` | `50` |
| `110` | `UnitTier3F_SummonBlessing*.tres` | `ON_SUMMON_BLESSING` | `55` |
| `100` | `when_attacking` buffs (`PowerAmulet`, `AttackGrowth`, `trait_fire_burn`) | `ON_ATTACK_BUFF` | `60` |
| `100` | `when_taking_damage` / `when_ally_takes_damage` (`PassiveHeal`, `ResilientAura`, `Purify`, `Scald`) | `ON_DAMAGE_TAKEN` | `61` |
| `100` | `when_enemy_summoned` (`AmbushPredator`) | `ON_SUMMON_AMBUSH` | `62` |
| `100` | `on_board_state_changed`, `on_enter_board`, `on_gacha_tokens_changed` *(must share `64`!)* | `BOARD_STATE_SYNC` | `64` |
| `60` | `ability_trinket_royal_insignia_merge.tres` | `ON_MERGE_PRIMARY` | `70` |
| `50` | `ItemTier3D_RetaliateRandom.tres` (`when_taking_damage`) | `RETALIATION` | `75` |
| `50` | Trinket phase/draw/merge/summon modifiers (`Insignias`, `Trinity`, `Totem`, `SpikedArmor`, etc.) | `TRINKET_MODIFIER` | `80` |
| `10` | `before_taking_damage` (`DefensiveStance`, `ability_efaa_*`) | `PRE_DAMAGE_DEFENSE` | `90` |
| `10` | `when_attacking` modifiers (`Shockwave`, `BerserkerShockwave`, `MirrorStrike`) | `ON_ATTACK_MODIFIER` | `95` |
| `10` | `pre_combat` (`ability_trait_mercenary_pre_combat.tres`) | `PRE_COMBAT_PRIORITY` | `98` |
| `0` *(default)* | All standard unit/item/trinket abilities (including `UnitTier1B_CounterOnHurt`, `Lifesteal`, `AllyDeathBuff`, slot effects, manual consumables, basic attacks) | `STANDARD` | `200` |
| `-10` | `ability_trait_*` pre-combat & turn-start effects | `TRAIT_PHASE_EFFECT` | `220` |
| `-50` | `EffectRetriggerTurnAttack.gd` queued follow-up attack (`double_strike_attack`) | `DOUBLE_STRIKE_FOLLOWUP` | `245` |
| `-50` | `ability_boss_*_summon.tres` (`at_turn_end`) | `END_OF_TURN_SUMMON` | `250` |
| `-100` | `ItemTier1B_ExtraAttack.tres` | `GRANT_EXTRA_ACTION` | `300` |

> [!NOTE]
> **Why `GuardianSacrifice` (`10`) and `EmpathicLink` (`12`) Are Split**: Both previously used `priority = 300`, and [CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd#L228) extracted interceptions via `req.priority >= C.PRIORITY_GUARDIAN_INTERCEPT`. Giving `PRE_DAMAGE_INTERCEPT = 10` and `KNOCKOUT_STAT_PASS = 12` guarantees `req.sub_phase <= C.SubPhase.PRE_DAMAGE_INTERCEPT` matches **only** true attack interceptions while `KNOCKOUT_STAT_PASS` (`12`) still executes before `ITEM_TRANSFER` (`20`)!
>
> **Why `BOARD_STATE_SYNC = 64` Is Shared Across `on_board_state_changed`, `on_enter_board`, and `on_gacha_tokens_changed`**: During `bm_draw_gacha_instance` and `bm_merge_instances`, those triggers enqueue into the same scope and previously shared `priority = 100`, relying on Layer 2/3 tie-breaking. Sharing `64` preserves that exact tie-breaking order!

### Exact Steps
1. Add `enum SubPhase { ... }` with all 26 entries above to [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd) (keep old `PRIORITY_*` constants in place until Task 3.2 removes them).
2. Run headless verification to confirm clean compilation.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 3.1** from `docs/action_constitution_phase_3_subphases.md`. Add `enum SubPhase` with the exact 26 members and integer values to `scripts/Constants.gd` (leaving existing `PRIORITY_*` constants until Task 3.2). Run the Mandatory Verification Command and mark Task 3.1 `Complete`.

---

## Task 3.2 — Lockstep Migration of Code & All 289 `.tres` Resources to `SubPhase` [Complete]
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Atomically replace `priority: int` with `sub_phase: Constants.SubPhase` across `AbilityDefinition`, `EffectRequest`, `CausalReactionResolver`, `CombatSimulator`, all `EffectRequest.new(...)` callers, and all **289 `.tres` files** that specify `priority = ...`, then delete all legacy `PRIORITY_*` constants from `Constants.gd`.

### Complete `.gd` Edit Checklist (11 Files)
1. **[AbilityDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityDefinition.gd#L28-L35)**:
   - Replace `@export var priority: int = 0` with:
     ```gdscript
     const C = preload("res://scripts/Constants.gd")
     @export var sub_phase: C.SubPhase = C.SubPhase.STANDARD
     ```
     *(If `C` is already preloaded in `AbilityDefinition.gd`, reuse it.)*
2. **[EffectRequest.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRequest.gd)**:
   - Replace `var priority: int = 0` with `var sub_phase: C.SubPhase = C.SubPhase.STANDARD` (preloading `const C = preload("res://scripts/Constants.gd")`).
   - Update `_init(..., p_sub_phase: C.SubPhase = C.SubPhase.STANDARD, ...)`.
3. **[GachaBallInstance.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallInstance.gd#L713)** (**LINE 713 ONLY — DO NOT TOUCH OTHER `.priority` LINES!**):
   - Replace `"priority": priority_value if priority_value != 0 else ability.priority,` with:
     ```gdscript
     "component_priority": priority_value,
     "sub_phase": ability.sub_phase,
     ```
4. **[AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd#L499-L510)**:
   - Pass `ability.sub_phase` instead of `ability.priority` into `EffectRequest.new(...)`.
5. **[CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd)**:
   - Line ~145 (`_compare_requests`): Flip sort from descending `priority` to **ascending `sub_phase`**:
     ```gdscript
     if a.sub_phase != b.sub_phase:
         return a.sub_phase < b.sub_phase
     ```
     *(Keep Layer 2 team order, Layer 3 front-to-back `slot_index` order, Layer 4 `sub_index` order, and Layer 5 `enqueue_seq` FIFO fallback 100% untouched!)*
   - Line ~228 (`extract_interceptions`):
     ```gdscript
     return req.sub_phase <= C.SubPhase.PRE_DAMAGE_INTERCEPT
     ```
6. **[CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L207)**:
   - Rename `sort_reactions_by_priority()` -> `sort_reactions_by_sub_phase()` (or keep body calling `_crr` sort cleanly) and update its 2 callers in `BattleManager.gd` (`L2896`, `L3196`).
7. **[BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd)**:
   - Line ~1678 (`basic_attack_request`): Pass `C.SubPhase.STANDARD` instead of `0`.
   - Line ~2930 (`_create_slot_effect_request`): Pass `C.SubPhase.STANDARD` instead of `C.PRIORITY_STANDARD`.
   - Lines ~2896 & ~3196: Call `_combat.sort_reactions_by_sub_phase()`.
8. **[InventoryManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/InventoryManager.gd#L246)**:
   - Pass `C.SubPhase.STANDARD` instead of `0` to `EffectRequest.new(...)`.
9. **[EffectRetriggerTurnAttack.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRetriggerTurnAttack.gd#L81-L84)**:
   - Pass `C.SubPhase.DOUBLE_STRIKE_FOLLOWUP` instead of `-50` to `EffectRequest.new(...)`.
10. **[Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd#L155-L210)**:
    - Delete all `const PRIORITY_*` integer constants (`L155–157` and `L189–210`).
11. **[run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd#L282-L325)**:
    - Update lines `282` and `325` from `0` to `C.SubPhase.STANDARD` in `EffectRequest.new(...)`.

### Exact Bulk `.tres` Migration Script (`scratch/migrate_subphases_tres.py`)

> [!WARNING]
> Only replace `priority = <N>` inside **`AbilityDefinition`** resources / sub-resources! **Never** replace `priority = <N>` inside `TagComponent`, `StatComponent`, `AbilityComponent`, or `VisualComponent` sub-resources if any `.tres` contains them! Check the section's script/type before replacing!

Write `scratch/migrate_subphases_tres.py` using section-by-section `.tres` parsing so **only** `AbilityDefinition` blocks (`script = ExtResource(...)` pointing to `AbilityDefinition.gd`) have `priority = <old>` converted to `sub_phase = <new_int>`:
- `500` -> `5`
- `300`: if `trigger == "intercept_attack"` -> `10`; else (`when_knocked_out` / Empathic Link) -> `12`
- `250` -> `15`
- `220` -> `20`
- `215` -> `25`
- `210` -> `30`
- `205` -> `35`
- `200` -> `40`
- `120` -> `50`
- `110` -> `55`
- `100`:
  - if `trigger == "when_attacking"` -> `60`
  - elif `trigger in ("when_taking_damage", "when_ally_takes_damage")` -> `61`
  - elif `trigger == "when_enemy_summoned"` -> `62`
  - else (`on_board_state_changed`, `on_enter_board`, `on_gacha_tokens_changed`) -> `64`
- `60` -> `70`
- `50`: if `trigger == "when_taking_damage"` (`ItemTier3D_RetaliateRandom`) -> `75`; else -> `80`
- `10`:
  - if `trigger == "before_taking_damage"` -> `90`
  - elif `trigger == "when_attacking"` -> `95`
  - else (`pre_combat`) -> `98`
- `0` -> `200` (or remove redundant line since default is `200`, or write `sub_phase = 200` explicitly)
- `-10` -> `220`
- `-50` -> `250`
- `-100` -> `300`

Fail fast (`raise ValueError(...)`) if any `AbilityDefinition` section has an unmapped `priority` integer! Run the script, verify count (`289` `.tres` files), and immediately run `rm scratch/migrate_subphases_tres.py`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 3.2** from `docs/action_constitution_phase_3_subphases.md`. Update all 11 `.gd` / test files and migrate `AbilityDefinition` `priority` -> `sub_phase` across `.tres` resources in lockstep (never touching `GachaBallComponent.priority`!). Delete `scratch/migrate_subphases_tres.py` before finishing, run the Mandatory Verification Command, and mark Task 3.2 `Complete`.

---

## Task 3.3 — Static `SubPhase` Cleanliness Audit [Complete]
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Verify that `sync_translations.py` runs cleanly and that zero stale `PRIORITY_*` or `ability.priority` / `req.priority` references remain anywhere in the codebase while `GachaBallComponent.priority` stays intact. Note: Content documentation (`docs/GameContentDocument.md`) is maintained manually by developers and is never auto-generated.

### Exact Steps
1. Run `python3 scripts/utils/sync_translations.py` to ensure translations compile.
2. Run the verification gate below.

### Mandatory Verification Command
```zsh
python3 scripts/utils/sync_translations.py && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "PRIORITY_\|ability\.priority\|ability_def\.priority\|req\.priority\|request\.priority" scripts/ tests/ && \
echo "PASS: Phase 3 SubPhase migration 100% verified"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 3.3** from `docs/action_constitution_phase_3_subphases.md`. Run `python3 scripts/utils/sync_translations.py`, run the Mandatory Verification Command, and mark Phase 3 `Complete` in both `docs/action_constitution_phase_3_subphases.md` and `docs/action_constitution_execution_roadmap.md`.

