# Code Improvement Opportunities

This document outlines areas for code improvement, focusing on clean code, maintainability, expandability, and the removal of legacy/obsolete patterns.

## 1. Code Cleanup & Hygiene

### 1.1 Remove Debug Print Statements
The codebase contains numerous `print()` statements used for debugging. These clutter the output and should be removed or replaced with proper logging/error handling if strictly necessary.

**Affected Files:**
- `scripts/BattleManager.gd`: Lines 1071, 1680-1692, 1701, 1775, 2531, 2686.
- `scripts/BattleAnimator.gd`: Lines 37, 69, 71, 73, 75, 77, 192, 196, 203, 205, 207, 255, 260, 262, 264, 271, 275, 279, 283, 300, 305, 308, 310, 390.
- `scripts/BattleView.gd`: Lines 75, 86.
- `scripts/GachaBallView.gd`: Lines 213, 216, 245, 248, 256.
- `scripts/WindowManager.gd`: Lines 52-59, 541-559.
- `scripts/TestEnvironmentManager.gd`: Lines 227-266.
- `scripts/FlashcardMinigame.gd`: Lines 219-229.
- `scripts/AbilityResolver.gd`: Remove commented-out debug prints.

### 1.2 Remove Unused Variables
- **`scripts/BattleAnimator.gd`**: In the `SUMMON` event handler (Line 222), `var bm = _get_battle_manager()` is assigned but never used (only checked for validity). This dependency should be removed to enforce decoupling.

## 2. Architectural Compliance ("No Defensive Code")

The project adheres to a strict "No Defensive Code" policy. "Impossible" states should trigger `assert()` failures rather than silent returns.

### 2.1 Replace Silent Failures with Assertions
Many files use `if not is_instance_valid(x): return` patterns for core dependencies that *must* exist. These should be converted to `assert(is_instance_valid(x), "Error message")`.

**Examples to Refactor:**
- **`AbilityResolver.gd`**: Checks for `battle_manager` validity.
- **`BattleView.gd`**: Checks for `battle_manager` validity.
- **`WindowManager.gd`**: Numerous checks for window/view validity that might mask lifecycle bugs.
- **`GachaBallView.gd`**: Checks for `_location` validity.
- **`BattleManager.gd`**: `bm_add_instance`, `bm_remove_instance`, etc., return `false` on invalid input. If these are internal system calls, they should `assert`.

## 3. Architectural Compliance (Simulate-Present Decoupling)

### 3.1 Strict Separation
- **`BattleAnimator.gd`**: Generally follows the pattern well. The `_visual_registry` is correctly used.
- **`BattleManager.gd`**: Ensure no UI nodes are accessed. (Preliminary scan looks good).

## 4. Maintainability & Expandability

### 4.1 Type Safety
Ensure all variables and function returns have explicit type hints to leverage Godot's static typing features.
- **`BattleManager.gd`**: `_battle_instances` is `Dictionary`, could be `Dictionary[String, GachaBallInstance]` (if Godot 4.x supports typed dictionaries, otherwise keep as is but document).

### 4.2 Magic Numbers
Replace hardcoded values with named constants.
- **`BattleAnimator.gd`**: Animation durations (1.1s, 0.5s) are hardcoded in `_wait_for_animation_completion` and `_animate_events`. These should be constants (e.g., `ANIM_DURATION_BUMP`, `ANIM_TIMEOUT_BUFFER`).

## 5. Completed Refactorings (2025-12-18)

### 5.1 SRP Helper Extraction
- **Status: COMPLETED**
- `BattleManager` (formerly 4068 lines) has been refactored to ~2200 lines by extracting logic into 9 specialized helper files.
- All board setup logic (lineup, trinkets, items) moved to `BattleSetup.gd`.
- All mutation/data management moved to `BattleState.gd`.
- All effect execution logic moved to `EffectHandlers.gd`.
- Combat loop and reaction processing moved to `CombatSimulator.gd`.

### 5.2 Legacy Signal Removal
- **Status: COMPLETED**
- `BattleLog` and related signals successfully removed.
