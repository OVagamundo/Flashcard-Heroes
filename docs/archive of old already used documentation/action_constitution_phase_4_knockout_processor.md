# Phase 4 Execution Plan: `KnockoutProcessor`, `PreKnockoutAttackCommand` & `CombatEvent` Alignment

**Master Roadmap:** [action_constitution_execution_roadmap.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/action_constitution_execution_roadmap.md)  
**Constitutional Spec:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) (Sections 3, 5.2, 6.2, and 9 — Phase 4)  
**Prerequisite:** Phase 3 `Complete`  
**Assigned Model:** `Gemini 3.8 Flash (High)`

## Phase Goal & Safety Guarantee

Eliminate legacy `set_meta` flags in the knockout pipeline, align `CombatEvent.Type` and `CausalReactionResolver.Phase` to Constitutional **Knockout** names, replace `KamikazeCommand` with `PreKnockoutAttackCommand`, and replace `DeathProcessor` with `KnockoutProcessor` (consolidating `BattleManager._process_registered_death` into `KnockoutProcessor`) — while preserving **100% identical `.mcr` replay state digest keys and animation timings**.

| Task | Assigned Model | Focus | Status |
| :--- | :--- | :--- | :---: |
| **4.1** | **Gemini 3.8 Flash (High)** | Move `set_meta` Deferred Knockout State onto Strongly Typed `BattleState` Fields | `Complete` |
| **4.2** | **Gemini 3.8 Flash (High)** | Rename `CombatEvent.Type` & `CausalReactionResolver.Phase` Knockout Enums | `Complete` |
| **4.3** | **Gemini 3.8 Flash (High)** | Replace `KamikazeCommand` & `KamikazeRequest` with `PreKnockoutAttackCommand` | `Complete` |
| **4.4** | **Gemini 3.8 Flash (High)** | Replace `DeathProcessor` with `KnockoutProcessor` & Consolidate `_process_registered_death` | `Complete` |

---

## Critical Replay Digest Lock (DO NOT VIOLATE!)

> [!CAUTION]
> **Preserve Exact Serialized Replay Snapshot Keys in [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L164-L180)**:
> `BattleManager.get_replay_state_snapshot()` feeds [ReplayStateDigest.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/engine/replay/ReplayStateDigest.gd) to compute deterministic SHA-256 hashes for `.mcr` replay files.
> - **DO NOT rename** the serialized dictionary string keys `"dead_this_turn"`, `"died_in_phase"`, `"def_id"`, `"team"`, `"first_killed_player_unit"`, `"first_killed_enemy_unit"`, `"aegis_prevented_PLAYER"`, or `"aegis_prevented_ENEMY"` inside `_turn_metadata` / `_dead_this_turn` / `get_replay_state_snapshot()`!
> - Renaming GDScript classes, methods, enums, and typed `BattleState` properties has **zero** impact on `.mcr` digests, whereas changing those serialized snapshot dictionary keys would invalidate existing `.mcr` recordings!

---

## Task 4.1 — Move `set_meta` Deferred Knockout State onto `BattleState`
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Eliminate all `set_meta` / `get_meta` / `has_meta` / `remove_meta` calls used for deferred knockouts and deferred enemy erasures in [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd) and [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd), replacing them with strongly typed fields on [BattleState.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/BattleState.gd) in strict compliance with [AGENTS.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/AGENTS.md) Law #1 & Law #2.

### Pre-Verified `meta` Call Sites to Eliminate
1. `DeathProcessor.gd` lines ~185, ~631: `deferred_ally_deaths_player` and `deferred_ally_deaths_enemy` on `bm`
2. `DeathProcessor.gd` lines ~220–298, ~562–566: `deferred_deaths` on `bm`
3. `BattleManager.gd` lines ~1839–1847, ~3113–3121: `_deferred_enemy_erasures` on `self`

### Exact Steps
1. **Add Typed Fields & Clear Helper to [BattleState.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/BattleState.gd#L32-L40)**:
   ```gdscript
   ## Units whose knockout completion is deferred until pending counter-attacks resolve
   var deferred_knockouts: Array[String] = []

   ## Deferred WHEN_ALLY_KNOCKED_OUT contexts waiting for counter-attacking units
   var deferred_ally_knockouts_player: Array[TriggerContext] = []
   var deferred_ally_knockouts_enemy: Array[TriggerContext] = []

   ## Enemy instance UUIDs deferred from final erasure until combat event playback finishes
   var deferred_enemy_erasures: Array[String] = []
   ```
   Also ensure wherever `BattleState` resets turn/encounter state (e.g. `clear_turn_tracking()` / `reset()`), `deferred_knockouts.clear()`, `deferred_ally_knockouts_player.clear()`, `deferred_ally_knockouts_enemy.clear()`, and `deferred_enemy_erasures.clear()` are called.
2. **Update [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd)**:
   - Replace `bm.has_meta("deferred_deaths")` / `bm.get_meta("deferred_deaths")` / `bm.set_meta(...)` / `bm.remove_meta(...)` with `bm._state.deferred_knockouts`.
   - Replace `deferred_ally_deaths_player` / `deferred_ally_deaths_enemy` meta access with `bm._state.deferred_ally_knockouts_player` / `bm._state.deferred_ally_knockouts_enemy`.
3. **Update [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L1837-L1850) & [L3113–3122](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L3113-L3122)**:
   - Pass `_state.deferred_enemy_erasures` directly to `perform_unit_death_cleanup(_state, unit, _state.deferred_enemy_erasures)`.
   - In `_flush_deferred_enemy_erasures()`, iterate `_state.deferred_enemy_erasures` and call `_state.deferred_enemy_erasures.clear()` instead of `get_meta` / `remove_meta`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "deferred_deaths\|deferred_ally_deaths\|_deferred_enemy_erasures" scripts/ && \
echo "PASS: Task 4.1 set_meta knockout state eliminated"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 4.1** from `docs/action_constitution_phase_4_knockout_processor.md`. Replace `deferred_deaths`, `deferred_ally_deaths_*`, and `_deferred_enemy_erasures` `set_meta`/`get_meta` calls with typed arrays on `BattleState.gd`. Do not change any serialized keys in `get_replay_state_snapshot()`. Run the Mandatory Verification Command and mark Task 4.1 `Complete`.

---

## Task 4.2 — Rename `CombatEvent.Type` & `CausalReactionResolver.Phase` Knockout Enums
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Align combat event and causal reaction phase enums with Constitutional Knockout vocabulary across Simulation and Presentation.

### Complete Pre-Verified Enum Rename Matrix (Zero Missing Call Sites!)

1. **`CombatEvent.Type.DEATH` -> `CombatEvent.Type.KNOCKOUT`**:
   - [CombatEvent.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/CombatEvent.gd)
   - [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd) (`L132`, `L324`, `L362`, `L601`)
   - [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L1870)
   - [BattleAnimator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleAnimator.gd#L363)
   - [BattleLogger.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleLogger.gd#L174)
2. **`CombatEvent.Type.LETHAL_SAVE` -> `CombatEvent.Type.PREVENT_KNOCKOUT`** (and `AnimationCompletionTracker.AnimationType.LETHAL_SAVE` -> `PREVENT_KNOCKOUT`):
   - [CombatEvent.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/CombatEvent.gd#L20)
   - [EffectPreventLethal.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectPreventLethal.gd#L91) *(Note: keep the file path `scripts/EffectPreventLethal.gd` intact because `.tres` resources reference its `ExtResource` path/UID!)*
   - [BattleAnimator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleAnimator.gd#L559) & [L918](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleAnimator.gd#L918)
   - [AnimationCompletionTracker.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/animations/AnimationCompletionTracker.gd#L18-L119) (`L18`, `L31`, `L119`)
3. **`CombatEvent.Type.KAMIKAZE_ATTACK` -> `CombatEvent.Type.PRE_KNOCKOUT_ATTACK`**:
   - [CombatEvent.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/CombatEvent.gd#L22)
   - [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd#L593)
   - [KamikazeCommand.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/commands/KamikazeCommand.gd#L57)
   - [BattleAnimator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleAnimator.gd#L573)
4. **`CausalReactionResolver.Phase.MORTALITY` -> `CausalReactionResolver.Phase.KNOCKOUT`**:
   - [CausalReactionResolver.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CausalReactionResolver.gd#L27) (check `grep -rn "Phase\.MORTALITY\|MORTALITY" scripts/` for any callers in `CombatSimulator.gd` or `DeathProcessor.gd` and update them simultaneously).

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "CombatEvent\.Type\.DEATH\|LETHAL_SAVE\b\|KAMIKAZE_ATTACK\|Phase\.MORTALITY" scripts/ tests/ && \
echo "PASS: Task 4.2 CombatEvent & Phase enums aligned"
```
*(Note: `LETHAL_SAVE_LEVITATE_HEIGHT` / `RISE_DURATION` visual tween constants in `AnimationConstants.gd` and `UnitAnimationController.gd` are pure presentation constants locked under `AGENTS.md` Law #4; leave them untouched or only rename if zero visual timings change.)*

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 4.2** from `docs/action_constitution_phase_4_knockout_processor.md`. Rename `CombatEvent.Type.DEATH` -> `KNOCKOUT`, `LETHAL_SAVE` -> `PREVENT_KNOCKOUT`, `KAMIKAZE_ATTACK` -> `PRE_KNOCKOUT_ATTACK`, and `CausalReactionResolver.Phase.MORTALITY` -> `KNOCKOUT` across all listed files (do not rename `scripts/EffectPreventLethal.gd` file path). Run the Mandatory Verification Command and mark Task 4.2 `Complete`.

---

## Task 4.3 — Replace `KamikazeCommand` & `KamikazeRequest` with `PreKnockoutAttackCommand`
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Replace [KamikazeCommand.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/commands/KamikazeCommand.gd) with `scripts/battle/commands/PreKnockoutAttackCommand.gd` (`class_name PreKnockoutAttackCommand`) and rename `EffectResult.KamikazeRequest` / `kamikaze_request` to `EffectResult.PreKnockoutAttackRequest` / `pre_knockout_attack_request`.

### Pre-Verified Complete Call-Site List (Only 4 Files!)
1. **[EffectResult.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/EffectResult.gd#L65-L112)**:
   - Rename inner class `KamikazeRequest` -> `PreKnockoutAttackRequest` (and `dying_max_hp` -> `knocked_out_max_hp`).
   - Rename field `var kamikaze_request: KamikazeRequest = null` -> `var pre_knockout_attack_request: PreKnockoutAttackRequest = null`.
2. **[EffectDeathDamageHighestEnemy.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/EffectDeathDamageHighestEnemy.gd#L48)**:
   - Assign `result.pre_knockout_attack_request = EffectResult.PreKnockoutAttackRequest.new(...)`.
3. **Create `scripts/battle/commands/PreKnockoutAttackCommand.gd`** (migrating logic cleanly from `KamikazeCommand.gd` with `class_name PreKnockoutAttackCommand extends CombatCommand`, `var pre_knockout_attack_request: EffectResult.PreKnockoutAttackRequest`, and `C.CAUSE_PRE_KNOCKOUT_ATTACK`) and **delete** `scripts/battle/commands/KamikazeCommand.gd` AND `scripts/battle/commands/KamikazeCommand.gd.uid`.
4. **[CombatSimulator.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/CombatSimulator.gd#L364-L365)**:
   - Replace `if effect_result.kamikaze_request != null: commands.append(KamikazeCommand.new(...))` with `if effect_result.pre_knockout_attack_request != null: commands.append(PreKnockoutAttackCommand.new(request, combat_sim, bm, effect_result.pre_knockout_attack_request))`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh --import --quit && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "KamikazeCommand\|KamikazeRequest\|kamikaze_request" scripts/ tests/ && \
find scripts -name "*.uid" | while read u; do base="${u%.uid}"; [ ! -e "$base" ] && echo "ORPHAN_UID: $u"; done
```
- **Pass Criteria**: `run_fast_suite.tscn` passes, zero `Kamikaze*` references remain, and zero `ORPHAN_UID` lines print.

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 4.3** from `docs/action_constitution_phase_4_knockout_processor.md`. Replace `KamikazeCommand.gd` (+ `.uid`) with `PreKnockoutAttackCommand.gd`, update `EffectResult.gd`, `EffectDeathDamageHighestEnemy.gd`, and `CombatSimulator.gd`, run `--import --quit` + the Mandatory Verification Command, and mark Task 4.3 `Complete`.

---

## Task 4.4 — Replace `DeathProcessor` with `KnockoutProcessor` & Consolidate `_process_registered_death`
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Replace [DeathProcessor.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/battle/DeathProcessor.gd) with `scripts/battle/KnockoutProcessor.gd` (`class_name KnockoutProcessor`), consolidate `BattleManager._process_registered_death` ([BattleManager.gd:3168–3201](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd#L3168-L3201)) into `KnockoutProcessor.process_registered_knockout(...)`, and update all callers across `BattleManager.gd`, `EffectTraitToy.gd`, and `tests/run_fast_suite.gd`.

### Pre-Verified Complete Call-Site List (Only 4 Files Touch `DeathProcessor`!)
1. **Create `scripts/battle/KnockoutProcessor.gd`** from `DeathProcessor.gd` (`class_name KnockoutProcessor extends RefCounted`) and **delete** `scripts/battle/DeathProcessor.gd` + `scripts/battle/DeathProcessor.gd.uid`:
   - Rename public static methods to Constitutional Knockout names:
     - `check_for_deaths` -> `check_for_knockouts`
     - `check_for_deaths_with_counter_delay` -> `check_for_knockouts_with_counter_delay`
     - `process_completed_counter_deaths` -> `process_completed_counter_knockouts`
     - `process_deferred_ally_death` -> `process_deferred_ally_knockout`
     - `has_lethal_counter_abilities` -> `has_before_knockout_counter_abilities`
     - `register_death` -> `register_knockout` *(keep `_state` dictionary key `"died_in_phase"` untouched per Replay Digest Lock!)*
     - `is_dead_this_turn` -> `is_knocked_out_this_turn`
     - `get_death_info` -> `get_knockout_info`
     - `perform_unit_death_cleanup` -> `perform_unit_knockout_cleanup`
     - `track_first_killed` -> `track_first_knocked_out` *(keep `_turn_metadata` keys `"first_killed_player_unit"` / `"first_killed_enemy_unit"` untouched per Replay Digest Lock!)*
     - `finalize_deaths` -> `finalize_knockouts`
     - `snapshot_equipped_items` -> `snapshot_equipped_items`
   - **Add `static func process_registered_knockout(unit: GachaBallInstance, phase: StringName, knockout_team: String, all_events: Array[CombatEvent], knockout_tracking: Dictionary, bm: Node) -> void`**:
     Consolidates `BattleManager._process_registered_death` (`L3168–3201`, used by End-of-Turn Death Slots & Burn KOs):
     1. Calls `if not register_knockout(bm._state, unit, phase): return`
     2. Emits `CombatEvent.Type.KNOCKOUT` once via `bm._create_death_event_if_needed` (renamed `_create_knockout_event_if_needed`)
     3. Calls `track_first_knocked_out(bm, unit, knockout_team)`
     4. Builds typed `TriggerContext` (including `knocked_out_uuid`, `knocked_out_team`, `knocked_out_location`, `knocked_out_tier`, `knocked_out_definition_id`, `equipped_items = snapshot_equipped_items(unit, bm._battle_instances)`, `source_pwr = unit.current_pwr`, `ally_knocked_out_uuid`, `ally_knocked_out_location`, `ally_knocked_out_team`, `ally_knocked_out_pwr = unit.current_pwr`) — fixing the historical bug where `_process_registered_death` forgot to populate `source_pwr`, `knocked_out_tier`, and `knocked_out_definition_id`!
     5. Fires `C.TRIGGER_BEFORE_BEING_KNOCKED_OUT`, `C.TRIGGER_WHEN_KNOCKED_OUT`, `C.TRIGGER_WHEN_ALLY_KNOCKED_OUT`, and `C.TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT`, then drains pending reactions cleanly via `bm._combat.sort_reactions_by_sub_phase()` and `bm._resolve_single_effect_request(...)`.
2. **Update [BattleManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/BattleManager.gd)**:
   - Update all 11 `DeathProcessor.*` delegations (`L59`, `L1806`, `L1814`, `L1829`, `L1832`, `L1835`, `L1844`, `L1855`, `L1861`, `L1878`, `L1883`, `L3204`, `L3800`) to `KnockoutProcessor.*`.
   - Replace `_process_registered_death` body (`L3168–3201`) with a 1-line delegation to `KnockoutProcessor.process_registered_knockout(unit, phase, death_team, all_events, death_tracking, self)`.
3. **Update [EffectTraitToy.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/effects/EffectTraitToy.gd#L9)**:
   - Update doc comment `DeathProcessor` -> `KnockoutProcessor`.
4. **Update [run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd#L285-L330)**:
   - Update lines `285–286` and `328–329` from `DeathProcessor.check_for_deaths_with_counter_delay` / `process_completed_counter_deaths` to `KnockoutProcessor.check_for_knockouts_with_counter_delay` / `process_completed_counter_knockouts`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh --import --quit && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \
! grep -rn "DeathProcessor" scripts/ tests/ && \
find scripts -name "*.uid" | while read u; do base="${u%.uid}"; [ ! -e "$base" ] && echo "ORPHAN_UID: $u"; done
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 4.4** from `docs/action_constitution_phase_4_knockout_processor.md`. Replace `DeathProcessor.gd` (+ `.uid`) with `KnockoutProcessor.gd`, consolidate `BattleManager._process_registered_death` into `KnockoutProcessor.process_registered_knockout`, update `BattleManager.gd`, `EffectTraitToy.gd`, and `tests/run_fast_suite.gd`, preserve all serialized keys in `get_replay_state_snapshot()`, run `--import --quit` + the Mandatory Verification Command, and mark Phase 4 `Complete` in both `docs/action_constitution_phase_4_knockout_processor.md` and `docs/action_constitution_execution_roadmap.md`.

