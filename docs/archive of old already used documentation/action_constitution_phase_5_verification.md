# Phase 5 Execution Plan: Determinism, Knockout Invariant Tests & Constitutional Cleanliness Audit

**Master Roadmap:** [action_constitution_execution_roadmap.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/action_constitution_execution_roadmap.md)  
**Constitutional Spec:** [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) (Sections 5, 6, and 9 — Phase 5)  
**Prerequisite:** Phase 4 `Complete`  
**Assigned Model:** `Gemini 3.8 Flash (High)`

## Phase Goal & Safety Guarantee

Prove mathematically and headlessly that every law of the Action Constitution v1.0 holds under automated regression testing in [run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd), multi-seed `ReplayStateDigest` parity checks, `.mcr` replay verification, and repository-wide static `grep` cleanliness audits.

| Task | Assigned Model | Focus | Status |
| :--- | :--- | :--- | :---: |
| **5.1** | **Gemini 3.8 Flash (High)** | Add Constitutional SubPhase & Knockout Cascade Invariant Tests to `run_fast_suite.gd` | `Complete` |
| **5.2** | **Gemini 3.8 Flash (High)** | Add Multi-Seed Combat `ReplayStateDigest` Determinism & `.mcr` Replay Verification | `Complete` |
| **5.3** | **Gemini 3.8 Flash (High)** | Run Final Constitutional Cleanliness Audit & Documentation Sync | `Complete` |

---

## Task 5.1 — Add Constitutional SubPhase & Knockout Cascade Invariant Tests
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Extend [run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd) (keeping total runtime `< 5.0s` so `stop_verify_gate.py` remains fast!) with deterministic, self-contained headless tests proving all core ordering and knockout invariants from Sections 5 and 6 of [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md).

### Pre-Verified Test Cases to Add in `tests/run_fast_suite.gd`

1. **`_test_subphase_three_layer_sorting()`**:
   - Instantiate a `CausalReactionResolver`, push a scope, and enqueue synthetic `EffectRequest` instances in intentionally scrambled order testing:
     - **Layer 1 (`SubPhase` ascending)**: `PRE_DAMAGE_INTERCEPT (10)` < `KNOCKOUT_STAT_PASS (12)` < `PREVENT_KNOCKOUT_CHECK (15)` < `ITEM_TRANSFER (20)` < `PRE_KNOCKOUT (25)` < `KNOCKOUT_SUMMON_TRINKET (30)` < `KNOCKOUT_SUMMON_UNIT (35)` < `KNOCKOUT_SUMMON_ITEM (40)` < `STANDARD (200)` < `GRANT_EXTRA_ACTION (300)`.
     - **Layer 2 (Active Team -> Passive Team)** when `sub_phase` is equal.
     - **Layer 3 (Front-to-Back Slot `0 -> 4`, then Equipment Slot `sub_index 0 -> 1`)** when `sub_phase` and `team` are equal.
   - Assert exact popped order matches Constitutional Section 6.1.

2. **`_test_prevent_knockout_blocks_knockout_chain()`**:
   - Set up a headless `BattleManager` board where a Player unit takes fatal damage while `trinket_aegis` (`SubPhase.PREVENT_KNOCKOUT_CHECK`) is active on the Player team and the unit also holds an item/ability with `TRIGGER_WHEN_KNOCKED_OUT`.
   - Resolve the attack and assert:
     - Unit survives with `current_hp == 1` and remains in `PlayerLineup`.
     - `CombatEvent.Type.PREVENT_KNOCKOUT` was emitted.
     - `CombatEvent.Type.KNOCKOUT` was **not** emitted for that unit.
     - Neither `TRIGGER_WHEN_KNOCKED_OUT` nor `TRIGGER_ON_KNOCKOUT_BLOW` fired!

3. **`_test_knockout_subphase_cascade_order()`**:
   - Set up a unit with `Empathic Link` (`KNOCKOUT_STAT_PASS = 12`) + an ally behind it, or equip `Death's Bargain` (`PRE_KNOCKOUT = 25`) / `item_t2_c_summon` (`KNOCKOUT_SUMMON_ITEM = 40`), deal fatal damage, run `KnockoutProcessor.check_for_knockouts_with_counter_delay` + `process_completed_counter_knockouts`, and assert:
     - `Empathic Link` passes item-inclusive PWR before item unequip/transfer.
     - `PreKnockoutAttackCommand` emits `CombatEvent.Type.PRE_KNOCKOUT_ATTACK` (and suppresses duplicate `CombatEvent.Type.KNOCKOUT` visual fade when lunging).
     - `BattleState.validate_state_consistency()` returns `true` after cleanup.

4. **`_test_registered_knockout_consolidation()`**:
   - Place a 1-HP unit with a `when_knocked_out` effect on a burn/death slot at end of turn (routing through `KnockoutProcessor.process_registered_knockout`), and assert:
     - `KnockoutProcessor.is_knocked_out_this_turn(bm._state, unit.ball_uuid)` is `true`.
     - `WHEN_KNOCKED_OUT` reaction executed with valid `source_pwr` and `knocked_out_tier`.
     - `BattleState.validate_state_consistency()` returns `true`.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 5.1** from `docs/action_constitution_phase_5_verification.md`. Add the 4 constitutional invariant test methods to `tests/run_fast_suite.gd` and wire them into `_run()`, keeping total execution time under 5 seconds. Run the Mandatory Verification Command and mark Task 5.1 `Complete`.

---

## Task 5.2 — Multi-Seed Combat `ReplayStateDigest` Determinism & `.mcr` Verification
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Expand determinism coverage in [run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd) to run multi-seed combat simulations (`5` diverse seeds covering summons, counter-attacks, items, and knockouts) asserting **byte-identical `ReplayStateDigest.compute(bm)` SHA-256 hashes** across paired runs, and verify any `.mcr` replay files if present in the workspace.

### Pre-Verified Determinism Trap to Fix in `tests/run_fast_suite.gd`
- In [GameManager.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GameManager.gd#L300-L306), `start_run_with_seed(...)` calls `UUIDUtils.clear_run_scope()` before `run_state.initialize_run(...)` and calls `UUIDUtils.begin_run_scope(run_state.run_id)` right after. Consequently, starter units created inside `initialize_run` embed `int(Time.get_unix_time_from_system())` in their UUIDs (which real `.mcr` replays preserve verbatim in the initial `RunState` snapshot).
- If a test calls `start_run_with_seed(...)` twice across a wall-clock second boundary (e.g. `.99s` -> `.01s`), the starter UUIDs in Run A vs Run B will differ by `1` second even when RNG is 100% deterministic!
- **Canonical Fix in `run_fast_suite.gd` (`_run_suite_3_seed_determinism`)**: Mirror how `ReplayController` works! After `start_run_with_seed(...)` initializes Run A, capture `var initial_run_snapshot: Dictionary = GameManager.run_state.serialize()` and `var initial_uuid_state: Dictionary = UUIDUtils.serialize_state()`. For Run B, re-seed `RNGManager.initialize(seed)`, restore `GameManager.run_state = RunState.deserialize(initial_run_snapshot)` and `UUIDUtils.restore_state(initial_uuid_state, TEST_RUN_ID)`, and then generate the encounter and run all combat turns! That tests 100% pure RNG + combat determinism with **zero** wall-clock timestamp flake.

### Exact Steps
1. Read the existing paired combat determinism test in [run_fast_suite.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/tests/run_fast_suite.gd#L248-L365).
2. Update `_run_suite_3_seed_determinism` to restore Run B's initial `RunState` + `UUIDUtils` state from Run A's pre-encounter snapshot (eliminating wall-clock second-boundary UUID drift), and loop across a fixed seed array `[101, 2026, 7777, 42424, 99991]` asserting for **every** seed:
   - Identical `CombatEvent` count and `CombatEvent.Type` sequence (`events_a[i].type == events_b[i].type`).
   - Identical `ReplayStateDigest` hash (`ReplayStateDigest.digest(snap_a) == ReplayStateDigest.digest(snap_b)`).
   - `bm_a._state.validate_state_consistency()` and `bm_b._state.validate_state_consistency()` both pass.
3. Check `find . -name "*.mcr"`; if any `.mcr` replay recordings exist in the project, execute headless replay verification via `ReplayController` to confirm zero digest mismatch.

### Mandatory Verification Command
```zsh
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 5.2** from `docs/action_constitution_phase_5_verification.md`. Add multi-seed paired `ReplayStateDigest` combat verification in `tests/run_fast_suite.gd` (and run `.mcr` replay verification if any `.mcr` files exist). Run the Mandatory Verification Command and mark Task 5.2 `Complete`.

---

## Task 5.3 — Final Constitutional Cleanliness Audit & Documentation Sync
**Assigned Model:** `Gemini 3.8 Flash (High)`

### Objective
Run the comprehensive static audit across `scripts/`, `resources/`, `localization/`, `tests/`, and `docs/` to verify 100% conformance with [Action_Constitution_v1_Flashcard_Heroes.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Action_Constitution_v1_Flashcard_Heroes.md) and [AGENTS.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/AGENTS.md), regenerate content documentation, and confirm zero orphan `.uid` or `scratch/` leftovers remain.

### Exact Verification & Cleanliness Gate

Run every check below in a single command; if any check reports a leftover violation, fix it cleanly at the root before marking Phase 5 complete:

```zsh
# 1. Sync PO translations, re-import Godot assets, and run headless test suite
python3 scripts/utils/sync_translations.py && \
.agents/skills/verify-headless/scripts/run_headless.sh --import --quit && \
.agents/skills/verify-headless/scripts/run_headless.sh res://tests/run_fast_suite.tscn && \

# 2. Zero legacy trigger literals in scripts/ or resources/
! grep -rn '&"on_death"\|&"on_ally_death"\|&"on_unit_death"\|&"on_kill"\|&"on_hurt"\|&"on_before_damage"\|&"passive_intercept"\|&"on_battle_start"\|&"on_pre_combat"\|&"on_turn_start"\|&"on_turn_end"\|&"on_ally_summon"\|&"on_enemy_summon"\|&"on_board_enter"\|&"on_board_changed"\|&"on_draw"\|&"on_bounty_rewarded"\|&"on_healed"' scripts/ resources/ tests/ && \

# 3. Zero untyped Dictionary contexts in EffectDefinition / resolvers
! grep -rn "context: Dictionary\|_context: Dictionary" scripts/Effect*.gd scripts/BasicAttackEffect.gd scripts/abilities/ scripts/effects/ scripts/AbilityResolver.gd scripts/battle/TargetResolver.gd && \

# 4. Zero legacy ability priority / DeathProcessor / KamikazeCommand / execute_on_lethal
! grep -rn "PRIORITY_\|ability\.priority\|req\.priority\|DeathProcessor\|KamikazeCommand\|execute_on_lethal\|CAUSE_KAMIKAZE\|DYING_UNIT_IS_DUST\|DAMAGE_WAS_NON_LETHAL" scripts/ resources/ tests/ && \

# 5. Zero deferred knockout set_meta patches
! grep -rn "deferred_deaths\|deferred_ally_deaths\|_deferred_enemy_erasures" scripts/ && \

# 6. Zero orphan .uid files & clean scratch/ directory
test -z "$(find scripts -name '*.uid' | while read u; do base="${u%.uid}"; [ ! -e "$base" ] && echo "$u"; done)" && \
test -z "$(find scratch -maxdepth 1 -type f 2>/dev/null)" && \
echo "ALL ACTION CONSTITUTION v1.0 GATES PASSED"
```

### Ready-to-Run Prompt (`Gemini 3.8 Flash (High)`)
> Execute **Task 5.3** from `docs/action_constitution_phase_5_verification.md`. Run the complete Constitutional Cleanliness Gate, resolve any remaining static check failures cleanly without defensive code, and mark Phase 5 and all phases `Complete` in `docs/action_constitution_phase_5_verification.md` and `docs/action_constitution_execution_roadmap.md`.
