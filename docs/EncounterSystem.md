# Encounter System & Generation

**Version:** 2.0  
**Status:** Active

## Overview

The Encounter System is responsible for defining, generating, and instantiating enemy teams for battle. It uses a budget-based algorithm that **guarantees 100% budget spending**.

## Budget Formula

| 1 | 5 | Base |
| 2 | 8 | 5 + 3 |
| 3 | 11 | 5 + 6 |
| 5 | 17 | 5 + 12 |
| 10 | 32 | 5 + 27 |

**Formula:** `5 + 3 * (day - 1)`

## Gachaball Costs

Tiered units and items have the following budget costs:

| Tier | Cost | Notes |
|------|------|-------|
| 1 | 1 | Base tier |
| 2 | 2 | |
| 3 | 4 | Merge of 4x Tier 1 |

Bosses don't have a cost, they are free.

### Battle Type Modifiers

| Type | Budget | Notes |
|------|--------|-------|
| Regular | Daily budget | Full budget for units/items/trinkets |
| Elite | Daily budget × 1.3 | Elite unit is FREE | Full budget for units/items/trinkets |
| Boss | Daily budget | Boss unit is FREE | Full budget for units/items/trinkets |
| Boss Summons | Daily budget ÷ 2 | No trinkets |

## Encounter Generation Algorithm

The `EncounterGenerator` uses a **"Greedy Fill + Knapsack Top-up"** algorithm that guarantees 100% budget spending.

### Algorithm Phases

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
- Uses **half the daily budget**
- Generates units with equipped items
- **No trinkets** for summoned units
- Returns Array of `{unit_id: StringName, items: Array[StringName]}`

## Fallback Mechanism

If generation fails or produces invalid encounter:
- `_create_fallback_encounter()` creates minimal valid encounter
- Looks up Tier 1 unit via Database query (not hardcoded ID)