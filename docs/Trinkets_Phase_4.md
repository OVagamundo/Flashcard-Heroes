
# Trinkets — Phase 4: Final Smoke/Regression (No New Features)

**Scope**  
This phase adds **no features and no new behavior**. It only verifies that Phases 1–3 are wired exactly as specified and that each trinket behaves as described. If something below fails, fix the referenced step from earlier phases rather than inventing new code.

---

## 0) Pre‑flight checklist (must already be true)

- `TrinketDefinition.gd`, `TrinketAbilityDefinition.gd` exist and load.
- Database loads `res://resources/trinkets/` and returns definitions via `Database.get_trinket_definition(...)`.
- RunState exposes a 5‑slot `RUN_CONTAINER_TAGS.PLAYER_TRINKETS` container and the helpers:
  - `add_trinket_definition(def)`, `remove_trinket_at(i)`, `get_trinket_definitions()`
- `Main.tscn` has **PlayerTrinketGrid** before `DaysLabel`; `Main.gd` rebuilds that grid on `run_data_changed`.
- `Battle.tscn` has **EnemyTrinketGrid** under Enemy area; `BattleView.gd` populates it from `BattleManager.get_enemy_trinkets()`.
- `TrinketInspectionWindow` is registered in `WindowManager` and opens on single‑click of a `TrinketView` via `WindowManager.open_window(&"TrinketInspection", {"trinket_id": <id>})`.
- `BattleManager.apply_direct_damage(...)` exists and is the **only** place that emits `on_hurt` and `on_kill`.
- `AbilityResolver.process_trigger(...)` runs **player trinkets** then **enemy trinkets**, then your instance/item pipeline.
- `AbilityResolver.process_trigger_immediate(...)` exists (for minigame open).
- `resolve_target(...)` supports `FRONTMOST_ALLY` and `RANDOM_ENEMY` (living‑only).
- `on_ally_death` context includes `dead_ally_container` and `dead_ally_slot_index`.
- Start‑of‑turn dispatch calls `process_trigger(TRIGGER_ON_TURN_START, ...)` and resets once‑per‑turn flags.
- Effect scripts exist for: `EffectHealFlat`, `EffectDirectDamage`, `EffectSummonRandomTier1`, `EffectAddMinigameTime`.
- The five `.tres` trinkets exist and reference the effects exactly as specified in Phase 3.

If any of the above is missing, return to the corresponding phase and complete it. Do not add new behavior.

---

## 1) Smoke/regression checklist

- E2E battle demo: one encounter showcasing all five trinkets (player + enemy) executes without errors.
- Routing audit: confirm all damage (including Lightning Rod) flows through `BattleManager.apply_direct_damage(...)`.
- Start-of-turn & gating: triggers fire exactly once; trinket once-per-turn flags reset at the beginning of each team turn.
- Minigame session time: `session_seconds` arrives via `FlashcardManager` and is used by `FlashcardMinigame`.
- No accidental regressions: running Phase‑2 and Phase‑3 checklists still passes.

---

## 2) Done criteria

Phase is complete when the smoke checklist passes and Phases 2–3 verification still pass. If something fails, fix the earlier phase; do not add new behavior here.
