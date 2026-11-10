# Phase 1 Execution Plan: Terminology, Canonical `TRIGGER_*` Constants, `DescriptionParser` & Localization

**Master Roadmap:** [action_constitution_execution_roadmap.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/action_constitution_execution_roadmap.md)  
**Constitutional Spec:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) (Sections 2, 3, 7, 8, and 9 — Phase 1)  
**Assigned Model:** `Gemini 3.8 Flash (High)`

## Phase Goal & Safety Guarantee

Eliminate legacy `"death/dying/fainting/lethal/kill"` trigger/property/condition identifiers and raw `StringName` trigger literals across `scripts/`, `resources/`, and `localization/game.csv`, replacing them with the Action Constitution v1.0 **Knockout** vocabulary and `Constants.TRIGGER_*` constants — with **zero change to gameplay mechanics, trigger firing order, or sub-tooltip UI behavior**.

| Task | Assigned Model | Focus | Status |
| :--- | :--- | :--- | :---: |
| **1.1** | **Gemini 3.8 Flash (High)** | Canonical `Constants.gd` Triggers/Causes/Conditions + `execute_before_knockout` Rename | `Complete` |
| **1.2** | **Gemini 3.8 Flash (High)** | Lockstep Migration of All `.gd` & `.tres` Trigger, Cause, and Condition Identifiers | `Complete` |
| **1.3** | **Gemini 3.8 Flash (High)** | Zero-Tooltip Inline Trigger Phrase Highlighting in `DescriptionParser.gd` | `Complete` |
| **1.4** | **Gemini 3.8 Flash (High)** | EN + PT-BR Knockout Terminology Update in `localization/game.csv` & Docs Sync | `Complete` |

---

## Task 1.1 — Canonical `Constants.gd` Identifiers & `execute_before_knockout` Rename
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
1. Define the complete, canonical set of `TRIGGER_*`, `CAUSE_PRE_KNOCKOUT_ATTACK`, `COND_KNOCKED_OUT_UNIT_IS_DUST`, and `COND_DAMAGE_DID_NOT_KNOCK_OUT` constants in [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd) (keeping old `TRIGGER_*` / `CAUSE_*` / `COND_*` aliases temporarily until Task 1.2 finishes migrating callers).
2. Rename `execute_on_lethal: bool` to `execute_before_knockout: bool` in [AbilityDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityDefinition.gd), all `.gd` callers, and every `.tres` resource that sets `execute_on_lethal`.

### Pre-Verified Safety Facts (Do Not Re-Guess)
- Only **5** `.gd` files reference `execute_on_lethal`:
  1. [AbilityDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityDefinition.gd#L62)
  2. [AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd#L446-L447)
  3. [CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd#L233-L250) (method `extract_lethal_reactions` — rename to `extract_before_knockout_reactions`)
  4. [CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L408-L415) (plus `drain_lethal_reactions_crr` / `drain_lethal_reactions_only` comments & call to `extract_before_knockout_reactions`)
  5. [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd#L100) (plus comment in [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L1853))
- Updating `AbilityDefinition.gd` and `.tres` files in the **same** Task Card prevents Godot from silently dropping serialized `execute_on_lethal = true` flags on resources like `trinket_aegis.tres`!

### Exact Steps

1. **Add Canonical Constants in [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd#L85-L152)**:
   Add the complete canonical block below (keep the old `TRIGGER_ON_*`, `CAUSE_KAMIKAZE`, `COND_DYING_UNIT_IS_DUST`, and `COND_DAMAGE_WAS_NON_LETHAL` lines right underneath marked `# REMOVED IN TASK 1.2` so Task 1.1 compiles cleanly before Task 1.2 switches callers):
   ```gdscript
   # --- Canonical Constitutional Triggers (Action Constitution v1.0) ---
   const TRIGGER_WHEN_KNOCKED_OUT: StringName = &"when_knocked_out"
   const TRIGGER_WHEN_ALLY_KNOCKED_OUT: StringName = &"when_ally_knocked_out"
   const TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT: StringName = &"when_any_unit_knocked_out"
   const TRIGGER_BEFORE_BEING_KNOCKED_OUT: StringName = &"before_being_knocked_out"
   const TRIGGER_PREVENT_KNOCKOUT: StringName = &"prevent_knockout"
   const TRIGGER_ON_KNOCKOUT_BLOW: StringName = &"on_knockout_blow"

   const TRIGGER_WHEN_ATTACKING: StringName = &"when_attacking"
   const TRIGGER_BEFORE_TAKING_DAMAGE: StringName = &"before_taking_damage"
   const TRIGGER_WHEN_TAKING_DAMAGE: StringName = &"when_taking_damage"
   const TRIGGER_ON_DAMAGE_DEALT: StringName = &"on_damage_dealt"
   const TRIGGER_WHEN_ALLY_TAKES_DAMAGE: StringName = &"when_ally_takes_damage"
   const TRIGGER_INTERCEPT_ATTACK: StringName = &"intercept_attack"
   const TRIGGER_BEFORE_TURN_ACTION: StringName = &"before_turn_action"

   const TRIGGER_AT_BATTLE_START: StringName = &"at_battle_start"
   const TRIGGER_PRE_COMBAT: StringName = &"pre_combat"
   const TRIGGER_AT_TURN_START: StringName = &"at_turn_start"
   const TRIGGER_AT_TURN_END: StringName = &"at_turn_end"

   const TRIGGER_WHEN_ALLY_SUMMONED: StringName = &"when_ally_summoned"
   const TRIGGER_WHEN_ENEMY_SUMMONED: StringName = &"when_enemy_summoned"
   const TRIGGER_ON_ENTER_BOARD: StringName = &"on_enter_board"
   const TRIGGER_ON_BOARD_STATE_CHANGED: StringName = &"on_board_state_changed"

   const TRIGGER_ON_GACHA_DRAW: StringName = &"on_gacha_draw"
   const TRIGGER_ON_MERGE: StringName = &"on_merge"
   const TRIGGER_ON_TOKEN_SPENT: StringName = &"on_token_spent"
   const TRIGGER_ON_GACHA_TOKENS_CHANGED: StringName = &"on_gacha_tokens_changed"
   const TRIGGER_ON_GOLD_EARNED: StringName = &"on_gold_earned"
   const TRIGGER_ON_BOUNTY_CLAIMED: StringName = &"on_bounty_claimed"

   const TRIGGER_WHEN_HEALED: StringName = &"when_healed"
   const TRIGGER_ON_STAT_INCREASED: StringName = &"on_stat_increased"
   const TRIGGER_ON_STAT_DECREASED: StringName = &"on_stat_decreased"

   # --- Canonical Causes & Conditions ---
   const CAUSE_PRE_KNOCKOUT_ATTACK: StringName = &"CAUSE_PRE_KNOCKOUT_ATTACK"
   const COND_KNOCKED_OUT_UNIT_IS_DUST: StringName = &"KNOCKED_OUT_UNIT_IS_DUST"
   const COND_DAMAGE_DID_NOT_KNOCK_OUT: StringName = &"DAMAGE_DID_NOT_KNOCK_OUT"
   ```

2. **Rename `execute_on_lethal` -> `execute_before_knockout` in GDScript**:
   - [AbilityDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityDefinition.gd#L62): `@export var execute_before_knockout: bool = false`
   - [AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd#L446-L447): `if not ability.execute_before_knockout:`
   - [CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd#L233-L250): Rename `extract_lethal_reactions` -> `extract_before_knockout_reactions` and check `ability_def.execute_before_knockout`.
   - [CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L408-L660): Update `ability_def.execute_on_lethal` -> `ability_def.execute_before_knockout` and `_crr.extract_lethal_reactions()` -> `_crr.extract_before_knockout_reactions()`. (Keep `drain_lethal_reactions_crr` / `drain_lethal_reactions_only` method names until Phase 4 or rename simultaneously with [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L1854-L1856) and [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd#L421) — if renaming now, update all 3 files together: `drain_before_knockout_reactions_crr` / `drain_before_knockout_reactions_only`).
   - [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd#L100): Update `ability.execute_on_lethal` -> `ability.execute_before_knockout`.

3. **Rename `execute_on_lethal =` -> `execute_before_knockout =` in all `.tres` files**:
   Write a temporary Python script `scratch/rename_exec_before_ko.py`, run it, and immediately delete it:
   ```python
   import pathlib
   count = 0
   for p in sorted(pathlib.Path("resources").rglob("*.tres")):
       txt = p.read_text(encoding="utf-8")
       if "execute_on_lethal" in txt:
           p.write_text(txt.replace("execute_on_lethal", "execute_before_knockout"), encoding="utf-8")
           count += 1
   print(f"Updated {count} .tres files")
   ```
   Then run `rm scratch/rename_exec_before_ko.py`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "execute_on_lethal" scripts/ resources/ tests/ && echo "PASS: Task 1.1 verified"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 1.1** from `docs/action_constitution_phase_1_terminology.md` step-by-step. Follow `AGENTS.md` (zero defensive code, delete temporary scripts in `scratch/` before finishing), run the Mandatory Verification Command, and mark Task 1.1 `Complete` in `docs/action_constitution_phase_1_terminology.md`.

---

## Task 1.2 — Lockstep Migration of All `.gd` & `.tres` Trigger, Cause & Condition IDs
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Atomically migrate every trigger string literal, legacy `TRIGGER_ON_*` constant, `CAUSE_KAMIKAZE`, `DYING_UNIT_IS_DUST`, and `DAMAGE_WAS_NON_LETHAL` across **all `.gd` files and `.tres` resources** in a single lockstep turn, and delete the temporary legacy aliases from [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd). Note: Content documentation (`docs/GameContentDocument.md`) is maintained manually and is never auto-generated.

### Complete Bijective Trigger Mapping Table

| Old StringName / Constant | New `Constants.gd` Symbol | New StringName Value |
| :--- | :--- | :--- |
| `&"on_death"` / `TRIGGER_ON_DEATH` | `C.TRIGGER_WHEN_KNOCKED_OUT` | `&"when_knocked_out"` |
| `&"on_ally_death"` / `TRIGGER_ON_ALLY_DEATH` | `C.TRIGGER_WHEN_ALLY_KNOCKED_OUT` | `&"when_ally_knocked_out"` |
| `&"on_unit_death"` | `C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT` | `&"when_any_unit_knocked_out"` |
| *(new fatal-only trigger)* | `C.TRIGGER_BEFORE_BEING_KNOCKED_OUT` | `&"before_being_knocked_out"` |
| *(new knockout-save trigger)* | `C.TRIGGER_PREVENT_KNOCKOUT` | `&"prevent_knockout"` |
| `&"on_kill"` / `TRIGGER_ON_KILL` | `C.TRIGGER_ON_KNOCKOUT_BLOW` | `&"on_knockout_blow"` |
| `&"on_attack"` / `TRIGGER_ON_ATTACK` | `C.TRIGGER_WHEN_ATTACKING` | `&"when_attacking"` |
| `&"on_before_damage"` | `C.TRIGGER_BEFORE_TAKING_DAMAGE` | `&"before_taking_damage"` |
| `&"on_hurt"` / `TRIGGER_ON_HURT` | `C.TRIGGER_WHEN_TAKING_DAMAGE` | `&"when_taking_damage"` |
| `&"on_damage_dealt"` / `TRIGGER_ON_DAMAGE_DEALT` | `C.TRIGGER_ON_DAMAGE_DEALT` | `&"on_damage_dealt"` |
| `&"on_ally_hurt"` / `TRIGGER_ON_ALLY_HURT` | `C.TRIGGER_WHEN_ALLY_TAKES_DAMAGE` | `&"when_ally_takes_damage"` |
| `&"passive_intercept"` | `C.TRIGGER_INTERCEPT_ATTACK` | `&"intercept_attack"` |
| `&"on_before_turn_action"` | `C.TRIGGER_BEFORE_TURN_ACTION` | `&"before_turn_action"` |
| `&"on_battle_start"` / `TRIGGER_ON_BATTLE_START` | `C.TRIGGER_AT_BATTLE_START` | `&"at_battle_start"` |
| `&"on_pre_combat"` / `TRIGGER_ON_PRE_COMBAT` | `C.TRIGGER_PRE_COMBAT` | `&"pre_combat"` |
| `&"on_turn_start"` / `TRIGGER_ON_TURN_START` | `C.TRIGGER_AT_TURN_START` | `&"at_turn_start"` |
| `&"on_turn_end"` / `TRIGGER_ON_TURN_END` | `C.TRIGGER_AT_TURN_END` | `&"at_turn_end"` |
| `&"on_ally_summon"` / `TRIGGER_ON_ALLY_SUMMON` | `C.TRIGGER_WHEN_ALLY_SUMMONED` | `&"when_ally_summoned"` |
| `&"on_enemy_summon"` / `TRIGGER_ON_ENEMY_SUMMON` | `C.TRIGGER_WHEN_ENEMY_SUMMONED` | `&"when_enemy_summoned"` |
| `&"on_board_enter"` | `C.TRIGGER_ON_ENTER_BOARD` | `&"on_enter_board"` |
| `&"on_board_changed"` | `C.TRIGGER_ON_BOARD_STATE_CHANGED` | `&"on_board_state_changed"` |
| `&"on_draw"` / `TRIGGER_ON_DRAW` | `C.TRIGGER_ON_GACHA_DRAW` | `&"on_gacha_draw"` |
| `&"on_merge"` / `TRIGGER_ON_MERGE` | `C.TRIGGER_ON_MERGE` | `&"on_merge"` |
| `&"on_token_spent"` | `C.TRIGGER_ON_TOKEN_SPENT` | `&"on_token_spent"` |
| `&"on_gacha_tokens_changed"` | `C.TRIGGER_ON_GACHA_TOKENS_CHANGED` | `&"on_gacha_tokens_changed"` |
| `&"on_gold_earned"` / `TRIGGER_ON_GOLD_EARNED` | `C.TRIGGER_ON_GOLD_EARNED` | `&"on_gold_earned"` |
| `&"on_bounty_rewarded"` / `TRIGGER_ON_BOUNTY_REWARDED` | `C.TRIGGER_ON_BOUNTY_CLAIMED` | `&"on_bounty_claimed"` |
| `&"on_healed"` / `TRIGGER_ON_HEALED` | `C.TRIGGER_WHEN_HEALED` | `&"when_healed"` |
| `&"on_stat_increased"` / `TRIGGER_ON_STAT_INCREASED` | `C.TRIGGER_ON_STAT_INCREASED` | `&"on_stat_increased"` |
| `&"on_stat_decreased"` / `TRIGGER_ON_STAT_DECREASED` | `C.TRIGGER_ON_STAT_DECREASED` | `&"on_stat_decreased"` |
| `&"CAUSE_KAMIKAZE"` / `CAUSE_KAMIKAZE` | `C.CAUSE_PRE_KNOCKOUT_ATTACK` | `&"CAUSE_PRE_KNOCKOUT_ATTACK"` |
| `&"DYING_UNIT_IS_DUST"` / `COND_DYING_UNIT_IS_DUST` | `C.COND_KNOCKED_OUT_UNIT_IS_DUST` | `&"KNOCKED_OUT_UNIT_IS_DUST"` |
| `&"DAMAGE_WAS_NON_LETHAL"` / `COND_DAMAGE_WAS_NON_LETHAL` | `C.COND_DAMAGE_DID_NOT_KNOCK_OUT` | `&"DAMAGE_DID_NOT_KNOCK_OUT"` |

> [!CAUTION]
> **Three Critical Traps to Avoid**:
> 1. **Do NOT touch `trigger = &"turn_start"`** (without `on_`) in `ability_dust_elite1_spawn_turn.tres`, `ability_dust_elite2_spawn_turn.tres`, or `ability_dust_elite_spawn_turn.tres`. Those 3 files are currently inert; changing them to `&"at_turn_start"` would change live encounter gameplay!
> 2. **Do NOT leave hardcoded trigger literals inside `Effect*.gd` files**:
>    - [EffectTrinityCharm.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTrinityCharm.gd#L16-L56) checks `trigger_type == &"on_draw"` and `trigger_type in [&"on_turn_end", &"on_battle_start"]` -> replace with `C.TRIGGER_ON_GACHA_DRAW` and `[C.TRIGGER_AT_TURN_END, C.TRIGGER_AT_BATTLE_START]`.
>    - [EffectRepeatAdjacentBuff.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectRepeatAdjacentBuff.gd#L98-L108), [EffectTraitPowerBuff.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTraitPowerBuff.gd#L82), [EffectBuffAllyBehindPWR.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectBuffAllyBehindPWR.gd#L45), [EffectGainDeadAllyPwrAsHP.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectGainDeadAllyPwrAsHP.gd#L51) pass default trigger fallback strings -> replace with `C.TRIGGER_*`.
> 3. **Wire `C.TRIGGER_BEFORE_BEING_KNOCKED_OUT` and `C.TRIGGER_PREVENT_KNOCKOUT` in [AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd)**:
>    - In `_should_unit_respond`: route `C.TRIGGER_BEFORE_BEING_KNOCKED_OUT` and `C.TRIGGER_PREVENT_KNOCKOUT` identically to self-scoped `source_uuid` / `damaged_uuid` checks (allowing `current_hp <= 0` for both, just like `C.TRIGGER_WHEN_KNOCKED_OUT`).
>    - In `_should_trinket_respond`: allow team-matched trinkets to respond to `C.TRIGGER_PREVENT_KNOCKOUT` (matching `damaged_team` / `victim_team`).
>    - In [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd) (lines ~255 and ~508, right before firing `C.TRIGGER_WHEN_KNOCKED_OUT`): also fire `AbilityResolver.process_trigger(C.TRIGGER_BEFORE_BEING_KNOCKED_OUT, death_ctx)` and drain inline if non-empty. (Zero existing `.tres` files use `before_being_knocked_out`, so existing combat behavior is 100% unchanged while the constitutional trigger is live and ready.)

### Complete `.gd` & `.py` File Checklist for Task 1.2
1. [Constants.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/Constants.gd): Remove the legacy `TRIGGER_ON_*`, `CAUSE_KAMIKAZE`, `COND_DYING_UNIT_IS_DUST`, and `COND_DAMAGE_WAS_NON_LETHAL` aliases once callers below are updated.
2. [AbilityDefinition.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityDefinition.gd#L16): Change default `@export var trigger: StringName = &"at_battle_start"` (using `Constants.TRIGGER_AT_BATTLE_START`).
3. [AbilityResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityResolver.gd): Replace all trigger literals in `_should_unit_respond`, `_should_item_respond`, `_should_trinket_respond`, line ~389 (`C.TRIGGER_ON_GACHA_TOKENS_CHANGED`), and line ~517 (`trigger == C.TRIGGER_WHEN_ATTACKING` for `replaces_basic_attack`).
4. [CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd#L153-L156): Update `_is_enemy_summon_trigger` to check `tt == C.TRIGGER_WHEN_ENEMY_SUMMONED or tt == C.TRIGGER_PRE_COMBAT`.
5. [TargetResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TargetResolver.gd): Replace `C.COND_DYING_UNIT_IS_DUST` -> `C.COND_KNOCKED_OUT_UNIT_IS_DUST` and `C.COND_DAMAGE_WAS_NON_LETHAL` -> `C.COND_DAMAGE_DID_NOT_KNOCK_OUT` (plus any raw condition string checks).
6. [CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L277-L700): Replace `&"on_before_turn_action"` -> `C.TRIGGER_BEFORE_TURN_ACTION` and `&"on_board_changed"` -> `C.TRIGGER_ON_BOARD_STATE_CHANGED`.
7. [TurnAbilities.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/TurnAbilities.gd): Replace all 9 raw `&"on_*"` literals with `C.TRIGGER_*`.
8. [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd): Replace `&"on_hurt"`, `&"on_death"`, `&"on_ally_death"`, `&"on_unit_death"`, `&"on_board_changed"`, and `C.TRIGGER_ON_BOUNTY_REWARDED` with `C.TRIGGER_*`.
9. [BattleHelpers.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/BattleHelpers.gd#L263): Replace `&"passive_intercept"` -> `C.TRIGGER_INTERCEPT_ATTACK`.
10. [DamageCommand.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/commands/DamageCommand.gd#L52) and [KamikazeCommand.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/commands/KamikazeCommand.gd#L65): Replace `&"on_before_damage"` -> `C.TRIGGER_BEFORE_TAKING_DAMAGE` and `C.CAUSE_KAMIKAZE` -> `C.CAUSE_PRE_KNOCKOUT_ATTACK`.
11. [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd): Replace all trigger literals and legacy `C.TRIGGER_ON_*` references (`L296–449`, `L832`, `L1043–1045`, `L1293`, `L1389–1392`, `L1594`, `L1624`, `L1667`, `L1747`, `L1850`, `L1981`, `L2389–2563`, `L2822–2856`, `L3176–3188`, `L3225`, `L3605–3607`, `L3664–3666`, `L3722`).
12. Effect scripts with trigger literals: [BasicAttackEffect.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BasicAttackEffect.gd), [EffectRetriggerTurnAttack.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectRetriggerTurnAttack.gd), [EffectCascadeAOE.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectCascadeAOE.gd), [EffectTrinityCharm.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTrinityCharm.gd), [EffectRepeatAdjacentBuff.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectRepeatAdjacentBuff.gd), [EffectTraitPowerBuff.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTraitPowerBuff.gd), [EffectBuffAllyBehindPWR.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectBuffAllyBehindPWR.gd), [EffectGainDeadAllyPwrAsHP.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectGainDeadAllyPwrAsHP.gd).
13. [sync_translations.py](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/utils/sync_translations.py): Ensure translation catalogs compile cleanly.
14. **Bulk `.tres` Resource Update (`scratch/migrate_phase1_tres.py`)**:
    Run this exact Python script in `scratch/` (and delete it right after) to update `trigger = &"..."`, `condition_type = &"..."`, and `allowed_causes` across all `resources/**/*.tres` while explicitly leaving `trigger = &"turn_start"` untouched:
    ```python
    import pathlib, re

    TRIGGER_MAP = {
        "on_death": "when_knocked_out",
        "on_ally_death": "when_ally_knocked_out",
        "on_unit_death": "when_any_unit_knocked_out",
        "on_kill": "on_knockout_blow",
        "on_attack": "when_attacking",
        "on_before_damage": "before_taking_damage",
        "on_hurt": "when_taking_damage",
        "on_damage_dealt": "on_damage_dealt",
        "on_ally_hurt": "when_ally_takes_damage",
        "passive_intercept": "intercept_attack",
        "on_before_turn_action": "before_turn_action",
        "on_battle_start": "at_battle_start",
        "on_pre_combat": "pre_combat",
        "on_turn_start": "at_turn_start",
        "on_turn_end": "at_turn_end",
        "on_ally_summon": "when_ally_summoned",
        "on_enemy_summon": "when_enemy_summoned",
        "on_board_enter": "on_enter_board",
        "on_board_changed": "on_board_state_changed",
        "on_draw": "on_gacha_draw",
        "on_merge": "on_merge",
        "on_token_spent": "on_token_spent",
        "on_gacha_tokens_changed": "on_gacha_tokens_changed",
        "on_gold_earned": "on_gold_earned",
        "on_bounty_rewarded": "on_bounty_claimed",
        "on_healed": "when_healed",
        "on_stat_increased": "on_stat_increased",
        "on_stat_decreased": "on_stat_decreased",
    }

    updated = 0
    for path in sorted(pathlib.Path("resources").rglob("*.tres")):
        orig = path.read_text(encoding="utf-8")
        txt = orig
        for old_t, new_t in TRIGGER_MAP.items():
            txt = re.sub(rf'(trigger\s*=\s*&?"){re.escape(old_t)}"', rf'\1{new_t}"', txt)
        txt = txt.replace('&"DYING_UNIT_IS_DUST"', '&"KNOCKED_OUT_UNIT_IS_DUST"')
        txt = txt.replace('"DYING_UNIT_IS_DUST"', '"KNOCKED_OUT_UNIT_IS_DUST"')
        txt = txt.replace('&"DAMAGE_WAS_NON_LETHAL"', '&"DAMAGE_DID_NOT_KNOCK_OUT"')
        txt = txt.replace('"DAMAGE_WAS_NON_LETHAL"', '"DAMAGE_DID_NOT_KNOCK_OUT"')
        txt = txt.replace('&"CAUSE_KAMIKAZE"', '&"CAUSE_PRE_KNOCKOUT_ATTACK"')
        txt = txt.replace('"CAUSE_KAMIKAZE"', '"CAUSE_PRE_KNOCKOUT_ATTACK"')
        if txt != orig:
            path.write_text(txt, encoding="utf-8")
            updated += 1
    print(f"Migrated {updated} .tres files")
    ```
    Delete `scratch/migrate_phase1_tres.py` immediately after running it!

### Mandatory Verification Command
```zsh
python3 scripts/utils/sync_translations.py && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn '&"on_death"\|&"on_ally_death"\|&"on_unit_death"\|&"on_kill"\|&"on_hurt"\|&"on_before_damage"\|&"passive_intercept"\|&"on_battle_start"\|&"on_pre_combat"\|&"on_turn_start"\|&"on_turn_end"\|&"on_ally_summon"\|&"on_enemy_summon"\|&"on_board_enter"\|&"on_board_changed"\|&"on_draw"\|&"on_bounty_rewarded"\|&"on_healed"\|CAUSE_KAMIKAZE\|DYING_UNIT_IS_DUST\|DAMAGE_WAS_NON_LETHAL' scripts/ resources/ tests/ && \
echo "PASS: Task 1.2 verified"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 1.2** from `docs/action_constitution_phase_1_terminology.md` step-by-step. Update all listed `.gd` files and `.tres` files in lockstep, delete `scratch/migrate_phase1_tres.py` before finishing, run the Mandatory Verification Command, and mark Task 1.2 `Complete` in `docs/action_constitution_phase_1_terminology.md`.

---

## Task 1.3 — Zero-Tooltip Inline Trigger Phrase Highlighting in `DescriptionParser.gd`
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Extend [DescriptionParser.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/utils/DescriptionParser.gd) so natural-prose Constitutional trigger phrases in **English and Portuguese (PT-BR)** receive clean inline BBCode highlight styling inside `DescriptionParser.parse(...)` **without** spawning `EffectInspection` sub-tooltip cards.

### Pre-Verified Safety Facts (Do Not Re-Guess)
- [UnitInspectionWindow.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/UnitInspectionWindow.gd#L387-L422), [ItemInspectionWindow.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/ItemInspectionWindow.gd#L520), and [TraitInspectionWindow.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/TraitInspectionWindow.gd#L98) call `DescriptionParser.find_keywords(raw_text)` and iterate `DescriptionParser.KEYWORDS` to instantiate `EffectInspection` sub-tooltip scenes (`STATUS_<KEY>`).
- **Therefore, `KEYWORDS` and `find_keywords()` MUST NOT be modified to include trigger phrases.**
- Instead, add a separate `const TRIGGER_PHRASES: Array[String]` (sorted longest-phrase-first so `"Before being knocked out"` matches before `"knocked out"`) and apply BBCode `[color=#ffd166][b]...[/b][/color]` (preserving original capitalization via regex capture group) inside `DescriptionParser.parse()` **only**.

### Exact Steps
1. Read [DescriptionParser.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/utils/DescriptionParser.gd) in full.
2. Add `const TRIGGER_HIGHLIGHT_HEX: String = "#ffd166"` and `const TRIGGER_PHRASES: Array[String]` containing longest-first EN + PT-BR trigger clauses:
   - EN: `"Before being knocked out"`, `"When an ally is knocked out"`, `"When any unit is knocked out"`, `"When this unit is knocked out"`, `"When holder is knocked out"`, `"When knocked out"`, `"Prevent knockout"`, `"Prevents knockout"`, `"On knockout blow"`, `"Before taking damage"`, `"When taking damage"`, `"When an ally takes damage"`, `"When attacking"`, `"At battle start"`, `"Pre-combat"`, `"At turn start"`, `"At the start of turn"`, `"At turn end"`, `"At the end of turn"`, `"When an ally is summoned"`, `"When an enemy is summoned"`, `"When healed"`
   - PT-BR: `"Antes de ser nocauteado"`, `"Antes de ser nocauteada"`, `"Quando um aliado é nocauteado"`, `"Quando qualquer unidade é nocauteada"`, `"Quando esta unidade é nocauteada"`, `"Quando o portador é nocauteado"`, `"Quando nocauteado"`, `"Quando nocauteada"`, `"Ao ser nocauteado"`, `"Ao ser nocauteada"`, `"Impede o nocaute"`, `"Prevenir nocaute"`, `"Ao nocautear"`, `"Antes de sofrer dano"`, `"Ao sofrer dano"`, `"Quando um aliado sofre dano"`, `"Ao atacar"`, `"No início da batalha"`, `"Pré-combate"`, `"No início do turno"`, `"No fim do turno"`, `"No final do turno"`, `"Quando um aliado é invocado"`, `"Quando um inimigo é invocado"`, `"Ao ser curado"`, `"Ao ser curada"`
3. Inside `DescriptionParser.parse(raw_text: String) -> String` (after variable interpolation and before or after status keyword formatting, avoiding double-wrapping existing `[color=...]` tags), apply case-insensitive whole-phrase regex replacement wrapping matched trigger phrases in `[color=%s][b]$1[/b][/color]`.
4. Leave `KEYWORDS` and `find_keywords()` completely untouched so zero new sub-tooltips are spawned.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 1.3** from `docs/action_constitution_phase_1_terminology.md`. Keep `DescriptionParser.KEYWORDS` and `find_keywords()` untouched so zero sub-tooltips are created, add `TRIGGER_PHRASES` inline BBCode highlighting inside `DescriptionParser.parse()`, run the Mandatory Verification Command, and mark Task 1.3 `Complete`.

---

## Task 1.4 — EN + PT-BR Knockout Prose in `localization/game.csv` & Translation Sync
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Update player-facing ability, item, trinket, trait, and inspection descriptions in [game.csv](file:///Users/danhh/Desktop/Flashcard%20Heroes/localization/game.csv) so all legacy `"dies"`, `"dead"`, `"faints"`, `"lethal damage"`, and `"kills an enemy"` wording uses natural **Knockout** prose in both English (`en`) and Brazilian Portuguese (`pt_BR`), then re-sync `.po` / `.translation` binaries and generated content docs.

### Pre-Verified Safety Facts (Do Not Re-Guess)
- **Never change localization keys** (column 0 of `game.csv`, e.g., `ABILITY_EMPATHIC_LINK_DESC`, `ITEM_DEATHS_BARGAIN_NAME`, etc.) — `.tres` resources reference those exact keys!
- **Preserve item/unit proper names** (such as `"Death's Bargain"` / `"Barganha da Morte"` or lore flavor names if any), updating **mechanical description text** (`*_DESC` rows and UI combat log strings if present) to use constitutional Knockout terminology:
  - EN: `"dies"` / `"faints"` -> `"is knocked out"`; `"On death:"` / `"When this unit dies"` -> `"When knocked out,"` / `"When this unit is knocked out,"`; `"dead ally"` -> `"knocked-out ally"`; `"lethal damage"` -> `"knockout damage"` (or `"prevents knockout and restores to 1 HP"` for Aegis Charm); `"kills"` / `"On kill"` -> `"knocks out"` / `"On knockout blow"`; `"non-lethal damage"` -> `"damage that does not knock it out"`.
  - PT-BR: `"morre"` / `"desmaia"` -> `"é nocauteado"` (or `"é nocauteada"` when agreeing with `"esta unidade"`); `"Ao morrer"` -> `"Quando nocauteado"` / `"Ao ser nocauteado"`; `"aliado morto"` -> `"aliado nocauteado"`; `"dano letal"` -> `"dano de nocaute"` / `"impede o nocaute"`; `"mata"` / `"abate"` -> `"nocauteia"` / `"Ao nocautear"`.
- Always parse and write [game.csv](file:///Users/danhh/Desktop/Flashcard%20Heroes/localization/game.csv) with Python's `csv` module (`lineterminator="\n"`) so commas and quotes inside CSV cells are never corrupted!

### Exact Steps
1. Inspect all rows in [game.csv](file:///Users/danhh/Desktop/Flashcard%20Heroes/localization/game.csv) whose `_DESC` or combat UI text contains `die`, `dies`, `dead`, `death`, `faint`, `lethal`, `kill`, `morr`, `mort`, `desmai`, `letal`, `matar`, `mata`, `abat`.
2. Update those mechanical description cells in `en` and `pt_BR` using natural Knockout prose (preserving `{0}`, `{pwr}`, BBCode tags, and CSV quoting).
3. Run `python3 scripts/utils/sync_translations.py` to regenerate `localization/en.po`, `localization/pt_BR.po`, and `localization/game.pot`.
4. Run headless Godot `--import --quit` so `localization/game.en.translation` and `localization/game.pt_BR.translation` binaries are re-imported cleanly, then run `run_fast_suite.tscn`.

### Mandatory Verification Command
```zsh
python3 scripts/utils/sync_translations.py && \
.agents/skills/verify-headless/scripts/run_headless.sh --import --quit && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 1.4** from `docs/action_constitution_phase_1_terminology.md`. Update mechanical descriptions in `localization/game.csv` (EN + PT-BR) to natural Knockout prose without changing any CSV keys or breaking CSV quoting, run `sync_translations.py`, re-import translations headlessly, run `run_fast_suite.tscn`, and mark Phase 1 `Complete` in both `docs/action_constitution_phase_1_terminology.md` and `docs/action_constitution_execution_roadmap.md`.

