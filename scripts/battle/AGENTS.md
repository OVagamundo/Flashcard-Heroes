# Battle Simulation Domain Guidelines

## 1. Pure Simulation Zone
- Scripts in this directory are the authoritative simulation layer.
- Strictly forbidden in `scripts/battle/`:
  - `SceneTree` lookups (`get_tree()`, `find_child()`, `get_node()`)
  - Async delays (`await`, `get_tree().create_timer()`)
  - Audio playback (`Audio.*`)
  - UI managers (`WindowManager.*`, `BattleAnimator.*`)
  - Visual resource loading (`load("*.gdshader")`)

## 2. Isolated PRNG Streams
- Every gameplay random roll MUST route through `RNGManager` (`RNGManager.combat_rng`, `RNGManager.gacha_rng`, `RNGManager.loot_rng`).
- Global `randi()`, `randf()`, or `randomize()` are strictly banned.

## 3. Total Event Coverage (Zero Silent State Desyncs)
- Every single state mutation (HP changes, PWR deltas, status stack additions/removals, slot movements, summons, deaths, token/gold rewards) MUST emit a corresponding `CombatEvent` with a typed `CombatPayload`.
- The presentation layer (VCR puppet) updates exclusively from these events; un-emitted mutations cause silent visual desyncs.

## 4. Container Consistency Invariants
- All unit and item movements must execute through atomic transfer routines.
- Maintain bidirectional slot and instance location consistency, backed by `BattleState.assert_state_consistency()`.
