# Implementation: Encounter Generator Budgeting

## 1. Budget Calculation & Valuation
Encounter difficulty is driven by a deterministic budget spent on unit costs and upgrades.

### 1.1 Daily Budget Formula
- **Standard Daily Budget:** `3 + (RunState.day - 1) * 1`.
- **Difficulty Multipliers:**
  - **Standard Encounter:** `DailyBudget * 1.0`
  - **Elite Encounter:** `DailyBudget * 1.5`
  - **Boss Encounter:** `DailyBudget * 2.5` (excluding the Boss unit itself).

### 1.2 Unit Valuation ($Tier \times Level$)
| Tier | Lv 1 (1x) | Lv 2 (2x) | Lv 2.5 (3x) | Lv 3 (4x) |
| :--- | :--- | :--- | :--- | :--- |
| **T1** | 1 | 2 | 3 | 4 |
| **T2** | 2 | 4 | 6 | 8 |
| **T3** | 4 | 8 | 12 | 16 |

## 2. Spend Algorithm (The Two-Pass Priority)
Refactor `_single_build_attempt` in `EncounterGenerator.gd` to replace the knapsack loop with a deterministic priority pass.

### 2.1 Pass 1: Quantity (The "Greedy Fill")
- **Constraint:** Attempt to fill all 5 lineup slots.
- **Logic:** Iterate through the `WeightedPoolDirector`. Draw only **Level 1** units of the current day's appropriate tier.
- **Stop Condition:** 5 slots occupied OR budget is < current minimum unit cost.

### 2.2 Pass 2: Quality & Leveling
- **Constraint:** Spend the remaining budget on existing units.
- **Logic:** 
  1. Iterate through the units created in Pass 1.
  2. For each unit, check if a higher-level definition exists (`_lv2`, `_lv2_5`, or `_lv3`) using `Database.has_definition(id)`.
  3. Spend the budget to "Swap" to the highest affordable definition.
  4. If budget remains after all units are Lv 3, spend on **Items**.

## 3. Stat Persistence Logic
Implement in `GachaBallInstance.gd` to allow non-resetting level-ups mid-battle or mid-generation.

```gdscript
func apply_new_definition_preserving_delta(new_def: GachaBallDefinition) -> void:
    var old_def = get_definition()
    # Calculate current deltas (Damage/Buffs)
    var delta_hp = self.current_hp - old_def.base_hp
    var delta_pwr = self.current_pwr - old_def.base_pwr
    
    # Update Definition
    self.definition_id = new_def.id
    self.abilities = new_def.ability_definitions.duplicate(true)
    
    # Apply new stats while preserving delta
    self.current_hp = clampi(new_def.base_hp + delta_hp, 1, 99)
    self.current_pwr = clampi(new_def.base_pwr + delta_pwr, 0, 99)
    
    # Resize items slots if level-up increases capacity
    if new_def.item_slot_count > self.equipped_item_uuids.size():
        self.equipped_item_uuids.resize(new_def.item_slot_count)
        # Note: We do not fill empty strings as resize(N) on String arrays handles it.
```

## 4. AI Adaptive Scaling
- **Rule:** If an AI ability triggers a "Spawn" effect (e.g., `EffectSummon`) but the lineup is already at 5 units, the budget must be redirected.
- **Logic:** Use the spawn's assigned budget to trigger `apply_new_definition_preserving_delta` on a random existing AI unit, targeting its next available level.
