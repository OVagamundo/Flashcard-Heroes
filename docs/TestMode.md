# Test Mode Implementation

Status: Canonical (Debug/Test Environment)

## Goal
Test mode must execute the same gameplay code paths as regular battle mode whenever possible.
The only intended differences are test utilities (spawn controls and flow shortcuts).

## Entry Points
1. `Loadout.gd`
   - `Test Mode` button sets `GameManager.is_test_mode = true`.
2. `GameManager.gd`
   - Creates a normal `RunState` via `start_run_requested`.
3. `RunState.gd`
   - Uses the same starter/loadout initialization pipeline as normal runs.
   - In test mode, calls `unlock_all_recipes_for_testing()` so spawned content can be merged.
4. `BattleManager.gd`
   - Reads `GameManager.is_test_mode` in `_ready()`.
   - Uses the same battle setup path (`_setup_battle`, `BattleSetup`, `BattleState`, `InventoryOperations`).
5. `TestEnvironmentManager.gd`
   - Exists in `Battle.tscn`, self-disables unless test mode + debug build.
   - Provides debug spawn UI.

## Parity Rules
Test mode must respect these rules:
1. No direct mutation of `_battle_instances` or container UUID arrays from test helpers.
2. Use battle atomic APIs:
   - `bm_add_instance`
   - `bm_remove_instance`
   - `bm_move_instance`
   - `bm_swap_instances`
   - `bm_equip_item`
3. Merge legality must use the same recipe gating logic as normal gameplay.
4. Interaction routing must use GIR + InventoryManager + InventoryOperations.

## Current Test Helper Flow
File: `scripts/battle/TestModeHelpers.gd`

1. `register_test_unit(...)`
   - Creates instance from definition.
   - Places via `bm_add_instance` into `PlayerLineup` or `EnemyLineup`.
2. `register_test_item(...)`
   - Spawns item via `bm_add_instance` into `PlayerBench` (same as draw destination).
   - If enemy target is selected, tries to equip to first enemy with free item slot via `bm_equip_item`.
3. `register_test_trinket(...)`
   - Places via `bm_add_instance` into trinket container.
   - Syncs `enemy_trinkets` cache for `BattleView`.
4. `clear_test_team(...)`
   - Collects UUIDs and removes with `bm_remove_instance` only.

## Interaction Behavior in Test Mode
1. `GlobalInteractionRouter`
   - In test mode, `EnemyLineup`/`EnemyBench` functional group is `BattleBoard`.
2. `SlotIndicatorController`
   - In test mode, unit drop targets include `EnemyLineup`.
3. `InventoryManager`
   - Equip/consumable target allow-list includes `EnemyLineup`.
   - Items/consumables cannot be placed directly into lineup containers.

## Intentional Differences vs Normal Battle
1. Debug panel for spawning units/items/trinkets.
2. Test mode can unlock all recipes in run state for unrestricted merge testing.
3. Test flow can remain in management/setup state for manual board construction before combat.

## Verification Checklist
1. Start run with `Test Mode`.
2. Spawn two units that have a valid recipe, merge them on board, confirm merge resolves.
3. Spawn item with player target, confirm it appears in `PlayerBench`.
4. Spawn item with enemy target, confirm equip attempt uses normal equip pipeline.
5. Spawn trinkets for both teams and confirm visuals + effects.
6. Confirm no direct-state helper code path bypasses `bm_*` atomic APIs.

