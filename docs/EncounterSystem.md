# Encounter System & Generation

**Version:** 1.1
**Status:** Active

## Overview
The Encounter System is responsible for defining, generating, and instantiating enemy teams for battle. It includes the static `EncounterDefinition` resource and the dynamic `EncounterGenerator` service.

## Encounter System (Schema Addendum)

This section documents the EncounterDefinition addition needed for enemy trinkets.

### EncounterDefinition (additions)

- `enemy_trinket_ids: Array[StringName] = []`
  - IDs must exist in `Database.trinkets` (loaded from `res://resources/trinkets/`).
  - Duplicates by definition should be avoided; the battle setup deduplicates by definition ID.
  - Player-exclusive trinkets (tags/flags like `is_player_exclusive` or legacy aliases) are ignored on load for enemies.

### Battle Setup Integration

- During battle setup, `BattleManager._setup_enemy_trinkets_from_encounter(enc)` reads `enc.enemy_trinket_ids` and builds the in-battle enemy trinket list.
- No generator-side auto-injection: enemy trinkets come strictly from the `EncounterDefinition` data.

### Testing Notes

- For deterministic tests, specify `enemy_trinket_ids` directly on the test `EncounterDefinition` resource to validate enemy trinket behaviors.

## Encounter Generation Algorithm (V9.2)

The `EncounterGenerator` uses a "Constrained Random Build" algorithm with a robust gap-filling step to generate dynamic enemy teams.

### Algorithm Phases

1.  **Setup & Pooling:**
    *   Loads all non-hero GachaBallDefinitions.
    *   Separates them into `available_units` and `available_items`, sorted by cost.

2.  **Mandatory Spend:**
    *   Ensures at least 50% of the budget is spent on units to prevent item-heavy, unit-light encounters.

3.  **Flexible Spending:**
    *   Iteratively buys random affordable units or items until the budget is nearly full.
    *   Respects unit caps (max 5) and item slot limits.
    *   **Optimization:** The generator runs this process multiple times (up to 10 attempts) and selects the build that utilizes the most budget.

4.  **Gap Filling (Robustness):**
    *   If budget remains, explicitly searches for "filler" units or items that fit the remaining budget exactly or closely.
    *   Prioritizes expensive fillers first to maximize efficiency.

5.  **Fallback Mechanism:**
    *   If generation fails or produces an invalid encounter, a `_create_fallback_encounter` method is called.
    *   This method safely looks up a valid Tier 1 unit (e.g., via Database query) rather than relying on hardcoded IDs, ensuring playability even with data changes.