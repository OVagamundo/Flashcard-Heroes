# Encounter System & Generation

**Version:** 2.0  
**Status:** Active

## Overview

The Encounter System is responsible for defining, generating, and instantiating enemy teams for battle. It uses a budget-based algorithm that **guarantees 100% budget spending**.

## Budget Formula

| Day | Budget | Calculation |
|-----|--------|-------------|
| 1   | 3      | Base        |
| 2   | 4      | 3 + 1       |
| 3   | 5      | 3 + 2       |
| 5   | 7      | 3 + 4       |
| 10  | 12     | 3 + 9       |

**Formula:** `3 + (day - 1)`

## Gachaball Costs

Tiered units and items have the following budget costs:

| Tier | Cost | Notes |
|------|------|-------|
| 1 | 1 | Base tier |
| 2 | 2 | |
| 3 | 4 | High tier |

Bosses don't have a cost, they are free.

### Battle Type Modifiers

| Type | Budget | Notes |
|------|--------|-------|
| Regular | Daily budget | Full budget for units/items/trinkets |
| Elite | Daily budget × 0.85 | Elite unit is FREE | Full budget for supports |
| Boss | Daily budget × 0.85 | Boss unit is FREE | Full budget for supports |
| Summons | Daily budget × 0.33 | Cap for Boss/Elite reinforcements per turn |

## Encounter Generation Algorithm

The `EncounterGenerator` uses a **"Greedy Fill + Knapsack Top-up"** algorithm that guarantees 100% budget spending.

### Algorithm Phases

1. **Gap Filtering & Prerequisites**
   - The generator pools all available Units, Items, and Trinkets.
   - **Exclusivity Rule**: Content with `is_player_exclusive = true` is filtered out.
   - **Tag-Based Exclusion Rule**: Units tagged with `HIDDEN`, `BOSS`, or `TOKEN` are excluded from standard budget-based pools. This ensures special-purpose units (like Dust units) are reserved for Elite battles or specific summons.
   - **Temporal Rule**: Content must satisfy `min_day` and `max_day` constraints relative to the current run day (e.g., Hermit locked until Day 10).
   
1. **Greedy Weighted Selection**
   - Priority weights: Units (3) > Items (2) > Trinkets (1)
   - Respects slot limits: Max 5 units, max 5 trinkets
   - Items limited by unit item slots

2. **Gap-Fill Phase**
   - Searches for exact-cost items/units to fill remaining budget
   - Tries single items, then combinations

3. **Swap Optimization**
   - If gap remains, tries swapping owned items for different costs
   - Example: Swap cost-3 item for cost-4 to gain 1 gold

4. **Overflow Tracking** *(Future Feature)*
   - If all slots full and budget remains, track as "overflow"
   - Future: Convert to stat bonuses (HP/PWR boosts)

### Slot Limits

- **Units:** 5 max
- **Items:** Based on unit item slot counts
- **Trinkets:** 5 max per encounter

## EncounterDefinition Schema

```gdscript
var id: String
var enemy_placements: Array[Dictionary]  # {id, position, items}
var enemy_trinket_ids: Array[StringName]
```

### Battle Setup Integration

- `BattleSetup.setup_enemy_lineup(state, encounter_def)` - Creates units with equipment
- `BattleSetup.setup_enemy_trinkets(state, encounter_def)` - Activates enemy trinkets
- For boss encounters, `encounter_def.get_meta("current_day")` provides day for boss summon budget

## Boss Summons

Boss units call `EncounterGenerator.generate_boss_summons(day, max_units)` which:
- Uses **one-third (33%)** of the daily budget
- Generates units with equipped items
- **No trinkets** for summoned units
- Returns Array of `{unit_id: StringName, items: Array[StringName]}`

## Elite Encounter Pity System

To ensure variety, the `EncounterGenerator` tracks the history of encountered elite variants.

### Weighted Selection Formula
When generating an elite encounter, the system accepts an `elite_encounter_history` dictionary and adjusts the weights of available bosses:
- **Base Weight**: 100
- **Formula**: `Weight = 100 / (1 + Count * 2)`
  - *0 Encounters*: 100 Weight
  - *1 Encounter*: 33 Weight
  - *2 Encounters*: 20 Weight
- **Impact**: This significantly reduces the probability of seeing the same elite back-to-back, ensuring a balanced frequency between Tier 2 and Tier 3 Dust Elites.
