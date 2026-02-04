---
description: Workflow for implementing new Units, Items, or Trinkets with strict verification.
---

# Workflow: Implement New Content (Atomic Decomposition)

This workflow enforces the "Atomic Task Decomposition" strategy to prevent missing steps (Localization, Registry, Recipes).

## Step 1: Research & Protocol (Do not skip)
1.  **Identify Reference**: Find a similar existing item to copy.
    *   Command: `find_by_name(Pattern="*SimilarItem*.tres", SearchDirectory="resources/")`
    *   Command: `view_file(AbsolutePath=".../SimilarItem.tres")`
2.  **Verify Architecture**: Check `AbilityImplementationGuide.md` for current patterns.
    *   Command: `view_file(AbsolutePath=".../docs/AbilityImplementationGuide.md")`

## Step 2: Atomic Plan Creation
Create or update `task.md` with the following **MANDATORY** sections. Do not group them; keep them separate to track progress.

```markdown
- [ ] **Core Logic (Scripts)**
    - [ ] Create/Update Effect Script (e.g. `scripts/effects/...`).
    - [ ] Verify Script Dependencies (ls/find).
- [ ] **Resources (Data)**
    - [ ] Create Ability Resource (`resources/abilities/...`).
    - [ ] Create Item/Unit Resource (`resources/units/...` or `resources/items/...`).
    - [ ] **VERIFY**: Check keys match script exports.
- [ ] **Registration (The "Missing Link")**
    - [ ] **Inventory**: Add to `RunState.gd` (`_get_starters_...`) if starter/test.
    - [ ] **Loot Pools**: Verify definition has correct `tier` and definitions are valid.
    - [ ] **Recipes**: Create `resources/recipes/...` (Use `MergeRecipe.gd`).
- [ ] **Localization**
    - [ ] Add Name Key to `localization/game.csv`.
    - [ ] Add Description Key to `localization/game.csv`.
- [ ] **Documentation**
    - [ ] Update `docs/GameContentDocument.md`.
    - [ ] Update `walkthrough.md` with verification steps.
```

## Step 3: Execution (Verify-Before-Write)
*   **Rule**: Never create a resource without reading the script it uses first.
*   **Rule**: Never use `RecipeDefinition.gd`. Always use `MergeRecipe.gd`.
*   **Rule**: If modifying `BattleManager.gd`, **STOP**. Read `CODE_GUIDELINES.md` Rule #1.

## Step 4: Verification
1.  **Run Tests**: Execute the walkthrough steps.
2.  **Check Logs**: Look for "Stack Overflow" or "Recursion" errors.
3.  **Check UI**: Verify Name/Description appear correctly (Localization check).
