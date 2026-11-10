# Resources & Content Domain Guidelines

## 1. Schema Validation
- Always inspect the backing `.gd` script before creating or modifying `.tres` resources:
  - Units: `scripts/GachaBallDefinition.gd`
  - Abilities: `scripts/AbilityDefinition.gd`
  - Effects: `scripts/EffectDefinition.gd`
  - Recipes: `scripts/MergeRecipe.gd` (always use `MergeRecipe.gd`, never legacy `RecipeDefinition`).

## 2. Localization & Translation Synchronization
- Whenever `localization/game.csv` is modified, you MUST run:
  ```bash
  python3 scripts/utils/sync_translations.py
  ```
- This recompiles `localization/en.po` and `localization/pt_BR.po`. Never edit `.po` files manually.
- Content documentation (`docs/GameContentDocument.md`) is maintained manually by developers and MUST NEVER be programmatically overwritten.

## 3. Flyweight Immutability
- Resources loaded via `Database` are shared flyweight assets.
- NEVER mutate properties (such as `.tags`) on shared `.tres` definitions at runtime.
