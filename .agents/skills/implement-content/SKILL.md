---
name: implement-content
description: Implements new Units, Items, Trinkets, Merge Recipes, and Abilities using atomic resource decomposition, localization compilation, and headless verification.
---

# Workflow: Implement New Content (Atomic Decomposition)

This skill enforces strict atomic decomposition for adding game content (Units, Items, Trinkets, Recipes, and Abilities) while preventing missing steps, broken contracts, or desynced localizations.

## Step 1: Research & Schema Inspection (Never Skip)
1. **Inspect Backing Scripts**: Always view the resource definitions before writing `.tres` files:
   - Units: `scripts/GachaBallDefinition.gd`
   - Abilities: `scripts/AbilityDefinition.gd`
   - Effects: `scripts/EffectDefinition.gd` and specific effects in `scripts/effects/`
   - Recipes: `scripts/MergeRecipe.gd` (NEVER use legacy `RecipeDefinition.gd`)
   - Architecture & Pipeline: `docs/CombatSystem.md`
2. **Find Reference Assets**: Locate an existing similar item to model after:
   - Units: `resources/units/`
   - Items: `resources/items/`
   - Trinkets: `resources/trinkets/`
   - Abilities: `resources/abilities/`
   - Recipes: `resources/recipes/`

## Step 2: Atomic Implementation Checklist
Track progress across each distinct stage:

1. **Core Logic (Scripts)**:
   - If a new effect behavior is needed, create or extend an `EffectDefinition` script in `scripts/effects/`.
   - Ensure the effect returns an `EffectResult` or appropriate event commands.
   - Do NOT modify `BattleManager.gd` or `BattleState.gd` to hardcode content.

2. **Resources (Data `.tres`)**:
   - Create `AbilityDefinition` resources (`resources/abilities/`).
   - Create Unit/Item/Trinket resources (`resources/units/`, `resources/items/`, `resources/trinkets/`).
   - Create `MergeRecipe` resources (`resources/recipes/`) if the item/unit is craftable.
   - Ensure all `@export` properties match the backing script types exactly.

3. **Localization**:
   - Add name keys (`*_NAME`) and description keys (`*_DESC`) to `localization/game.csv`.
   - **MANDATORY**: Run the sync tool to update `.po` translation catalogs:
     ```bash
     python3 scripts/utils/sync_translations.py
     ```
   - Never edit `localization/en.po` or `localization/pt_BR.po` directly.

4. **Headless Verification**:
   - Execute the headless runner to confirm syntax and load integrity:
     ```bash
     .agents/skills/verify-headless/scripts/run_headless.sh
     ```

## Step 3: Critical Safety Audits (Must Pass Before Completion)
1. **Infinite Recursion Check**:
   - If an ability triggers on a reaction (e.g. `on_stat_increased`, `on_damage_taken`), does it filter out its own effect source to prevent recursive loops?
2. **Atomic Container Operations**:
   - If an ability removes, spawns, or transfers units, does it use atomic methods (`execute_transfer` / `bm_remove_instance`) and emit corresponding `CombatEvent`s?
3. **Seeded PRNG**:
   - Are all rolls routed through `RNGManager` (`combat_rng`, `loot_rng`, `gacha_rng`)? Never call `randi()` or `randf()`.
4. **Asset & Sound Path Validity**:
   - Do all referenced texture icons and audio paths exist on disk? Sound keys must exist in `SoundRegistry.gd`.
