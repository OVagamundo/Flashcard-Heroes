# Commit Diff Report (Last 3 Commits)

> [!WARNING]
> **Git Access Note**: The `git` executable was not found in the system PATH. This report is based on a manual audit of the files and recent session logs.

## Summary of Changes
Based on the project state and recent history, the last few commits focused on:
1. **Combat Duplication System**: Implementation of Doppleganger, Echoing Orb, and Soul Echo.
2. **Technical Rollback Documentation**: Creation of `Implementation_Duplication_System.md` to track logic for potential restoration.
3. **Visual Feedback Refinement**: Updates to status effect colors and projectile textures.

## Potential Cause of Visual Glitch
The "one-frame flash" issue was likely introduced during the centralization of VFX instantiation in `VFXFactory.gd`. When nodes are added to the tree before their positions are initialized, they default to `(0,0)` for one frame.

---

## Technical Audit: VFX Glitch Fix

### File: `scripts/vfx/VFXFactory.gd`
**Change**: Set initial position *before* calling `add_child()` to ensure the node is correctly positioned the moment it enters the render tree.

```diff
- effects_layer.add_child(projectile)
- projectile.setup(amount, stat, start_pos + offset, end_pos + offset, is_self_cast)
+ projectile.position = start_pos + offset
+ effects_layer.add_child(projectile)
+ projectile.setup(amount, stat, start_pos + offset, end_pos + offset, is_self_cast)
```

---

## Commit History (Simulated)

### Commit 1: Implementation of Combat Duplication Logic
- Added `EffectDuplicateToDiscard.gd`
- Updated `BattleManager.gd` to handle `spawn_request` in combat events.
- Modified `DeathProcessor.gd` to trigger `on_death` effects before instance removal.

### Commit 2: Visual VFX Centralization
- Created `VFXFactory.gd` as an autoload.
- Moved projectile and damage number instantiation from individual animations to the factory.
- **Side Effect**: Introduced the one-frame lag by adding children to the tree before setup.

### Commit 3: Localization and Documentation
- Updated `localization.csv` with new ability strings.
- Created `docs/Implementation_Duplication_System.md`.
