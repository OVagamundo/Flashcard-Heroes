# Ability Implementation Guide

## Purpose
This document serves as the definitive guide for implementing new abilities, items, and trinkets in Flashcard Heroes. It enforces the strict architectural separation between **Simulation** (Game Logic) and **Presentation** (UI/Animation) and ensures deterministic, cause-and-effect based gameplay.

> [!WARNING]
> Failure to follow these rules will result in desynchronized state, visual glitches (animations playing on dead units), or logic crashes (missing context keys).

---

## 0. Golden Rules

> [!CAUTION]
> **RULE #1: DON'T BREAK WHAT WORKS**
> - Never modify `BattleManager.gd` or `AbilityResolver.gd` when adding new abilities
> - Never add new context flags (`_skip_trinkets`, `_trinkets_only`, etc.) to core systems
> - If you think you need to modify core systems, you are solving the wrong problem
> - Test ALL existing abilities after ANY change

> [!CAUTION]
> **RULE #2: REUSE BEFORE CREATE**
> - Check if an existing effect script handles your need (see Section 8)
> - Most abilities use `EffectModifyStat.gd` - do NOT create a new script for HP/PWR changes
> - If you create a new effect script, justify why existing ones don't work

> [!CAUTION]
> **RULE #3: COPY WORKING PATTERNS**
> - Find a similar existing ability and copy its `.tres` structure exactly
> - Copy from the same category (unit ability → copy unit ability, trinket → copy trinket)
> - Only modify the parts that need to differ (trigger, target, parameters)

---

## 1. The Priority System

The `BattleManager` processes reactions using a priority queue.
**Higher Priority = Executed First.**

> [!IMPORTANT]
> **Single Source of Truth:** All priority constants are defined in [`scripts/AbilityPriorities.gd`](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/AbilityPriorities.gd).
> Use these constants in code. For `.tres` files, use the numeric value with a comment referencing the constant name.

| Priority | Constant | Description | Examples |
|----------|----------|-------------|----------|
| 300 | `GUARDIAN_INTERCEPT` | Damage interception | Guardian Sentinel |
| 210 | `TRINKET_SUMMON` | Resurrection from trinkets | Soul Echo |
| 205 | `UNIT_SUMMON` | Unit on-death summon | Sakura Spirit |
| 200 | `ITEM_SUMMON` | Item on-death summon | Last Wish |
| 100 | `RESILIENT_AURA` | On-hurt buffs/heals | Resilient Aura, Heart Stone |
| 50 | `COUNTER_ATTACK` | Retaliation damage | Retaliate, Counter on Hurt |
| 10 | `DEFENSIVE_STANCE` | Attack modifiers | Shockwave, Mirror Strike |
| 0 | `STANDARD` | Default abilities | Most abilities |
| -50 | `BOSS_SUMMON` | End-of-turn spawns | Boss reinforcements |
| -100 | `EXTRA_ACTION` | Grant extra turns | Bloodlust Edge |

### Usage in `.tres` Files
```tres
priority = 50  # AbilityPriorities.COUNTER_ATTACK
```

### Importance
If multiple valid triggers occur (e.g., Unit A dies, triggering both `Soul Echo` and `Vengeance Buff`), the order matters.
- If `Soul Echo` (Priority 210) resurrects the unit, the slot becomes occupied.
- If a summon item (Priority 200) tries to summon into that slot afterwards, it gracefully finds an alternative slot.

**Rule:** Always define `priority` in your `AbilityDefinition` (`.tres`) if order creates dependencies.


---

## 2. The Context Contract (What Data is Available?)

Abilities receive a `context` dictionary. **This is your ONLY link to the world state regarding the event.**

> [!IMPORTANT]
> **ZERO-INSTANCE-QUERY RULE**
> Effects must NEVER call `get_instance()`, `get_location_for_uuid()`, or query BattleManager.
> All needed data must come from `context` or `parameters`.

### Trigger Context Keys

| Trigger | Available Context Keys |
| :--- | :--- |
| `on_attack` | `attacker_uuid`, `target_uuid`, `target_initial_hp`, `is_simulation` |
| `on_before_attack` | `source_uuid`, `defender_uuid`, `attacker_uuid`, `target_initial_hp`, `is_simulation` |
| `on_hurt` | `victim_uuid`, `attacker_uuid`, `damage_taken`, `victim_team`, `victim_current_hp`, `is_simulation` |
| `on_kill` | `attacker_uuid`, `killed_uuid`, `is_simulation` |
| `on_death` | `dying_uuid`, `dying_team`, `dying_location`, `equipped_items` |
| `on_ally_death` | `fainting_ally_uuid`, `fainting_ally_location`, `fainting_ally_team` |
| `on_turn_start/end` | `turn_number` |

### Attack Types and Defensive Triggers

**All attack types trigger `on_before_attack`:**

| Attack Type | Triggers `on_before_attack`? | Implementation |
|-------------|------------------------------|----------------|
| Basic Attack | ✅ Yes | `BasicAttackEffect.gd` line 57 |
| Retaliation | ✅ Yes | Uses `BasicAttackEffect` |
| Counter Attack | ✅ Yes | Uses `BasicAttackEffect` |
| Shockwave (Cascade) | ✅ Yes | `EffectCascadeAOE.gd` for each target |
| Bloodlust Extra | ✅ Yes | Goes through `_enqueue_attack_for` → `BasicAttackEffect` |

> [!IMPORTANT]
> **Defensive abilities like Defensive Stance** (which heal on `on_before_attack`) will activate against ANY attack type, including shockwave cascade damage.

### Attack Types and Offensive Triggers

**All attack types trigger `on_attack`:**

| Attack Type | Triggers `on_attack`? | Implementation |
|-------------|----------------------|----------------|
| Basic Attack | ✅ Yes | `_enqueue_attack_for` then `BasicAttackEffect.gd` (skips duplicate) |
| Retaliation | ✅ Yes | `BasicAttackEffect.gd` line 38-46 |
| Counter Attack | ✅ Yes | `BasicAttackEffect.gd` line 38-46 |
| Shockwave (Cascade) | ❌ No | Uses `EffectCascadeAOE.gd` (AOE, not single attack) |
| Bloodlust Extra | ✅ Yes | Goes through `_enqueue_attack_for` |
| Double Strike | ✅ Yes | Triggers via `on_attack` ability chain |

### Attack Types and Offensive Triggers

**All attack types trigger `on_attack`:**

| Attack Type | Triggers `on_attack`? | Implementation |
|-------------|----------------------|----------------|
| Basic Attack | ✅ Yes | `_enqueue_attack_for` then `BasicAttackEffect.gd` (skips duplicate) |
| Retaliation | ✅ Yes | `BasicAttackEffect.gd` line 38-46 |
| Counter Attack | ✅ Yes | `BasicAttackEffect.gd` line 38-46 |
| Shockwave (Cascade) | ❌ No | Uses `EffectCascadeAOE.gd` (AOE, not single attack) |
## The Trigger Context Standard (Universal Safety)

To prevent infinite recursion (Ability A triggers Ability B triggers Ability A) and ensure logical causality (e.g., Poison shouldn't trigger Retaliation), the system uses a **Cause Propagation** model.

### 1. The `trigger_cause` Context
Every event context contains a `trigger_cause` identifying the *Source* of the event:
*   `CAUSE_TURN`: Initiated by the game system (e.g., specific unit's turn start).
*   `CAUSE_ABILITY`: Initiated by an Item, Ability, or Trinket (e.g., Double Strike).
*   `CAUSE_ATTACK`: Initiated by damage from an attack.
*   `CAUSE_STATUS`: Initiated by a status effect (Poison, Burn).
*   `CAUSE_COST`: Initiated by a self-imposed cost (Sacrifice).

### 2. Using Conditions to Filter Causes
When creating abilities that react to triggers, you **MUST** consider the cause.

#### Example: "Extra Attack" (Recursion Prevention)
**Goal**: Triggers when the unit attacks normally, but NOT when it attacks via this ability itself.
**Pattern**:
1.  Trigger: `on_attack`
2.  Condition: **ContextCauseCondition**
    *   `allowed_causes`: `[CAUSE_TURN]`

#### Example: "Retaliation" (Logic Safety)
**Goal**: Triggers when damaged by an enemy attack, but NOT when damaged by Poison or Burn.
**Pattern**:
1.  Trigger: `on_hurt`
2.  Condition: **ContextCauseCondition**
    *   `allowed_causes`: `[CAUSE_ATTACK]`

#### Example: "Power Amulet" (Universal Buff)
**Goal**: Buff allies on ANY attack (Normal, Retaliation, or Extra).
**Pattern**:
1.  Trigger: `on_attack`
2.  Condition: None (or just standard conditions).
    *   *Result*: Triggers for `CAUSE_TURN` and `CAUSE_ABILITY`.

### Best Practices
*   **Default to Specificity**: If an ability creates a new event of the same type (Attack -> Attack), you MUST restrict the input cause to prevent loops.
*   **Use Composite Conditions**: Combine `ContextCauseCondition` with game logic (HP checks, RNG) using `CompositeCondition`. |
| Bloodlust Extra | ✅ Yes | Goes through `_enqueue_attack_for` |
| Double Strike | ✅ Yes | Triggers via `on_attack` ability chain |

> [!IMPORTANT]
>
> **Composite Conditions** are available to combine existing checks with this safety guard.


### Critical Context Keys

| Key | Type | When Required |
|-----|------|---------------|
| `is_simulation` | bool | Always present. `true` = return data, don't mutate. `false` = mutate state. |
| `team` | String | Required when `source_uuid` is empty (trinkets). Values: `"PLAYER"` or `"ENEMY"`. |
| `trigger_type` | StringName | Added by `AbilityResolver`. Tells you which trigger this is. |

> [!WARNING]
> **TEAM KEY IS CRITICAL FOR TRINKETS**
> When `source_uuid` is empty (which is ALWAYS for trinkets), the `team` key **MUST** be present in context for `RANDOM_ALLY`, `RANDOM_ENEMY`, and other team-based target types to resolve correctly. Without it, `resolve_target()` returns an empty array and your ability silently fails.

### Unified Broadcast Pattern
BattleManager broadcasts `on_ally_death` **once** per death. AbilityResolver uses `_should_unit_respond()` and `_should_trinket_respond()` to filter which instances react.

### Trinket Team Filtering
Trinkets ONLY trigger for deaths on their own team:
- Player trinkets → trigger only on player ally deaths
- Enemy trinkets → trigger only on enemy ally deaths

This is handled automatically in `AbilityResolver` - **do not duplicate this logic**.

---

## 3. The Effect Execution Contract

Effects implement the `execute()` method with two modes:

### Simulation Mode (`is_simulation = true`)
- **MUST NOT** mutate game state (no `inst.current_hp = X`)
- **MUST** return a Dictionary with structured data for `CombatEvent` creation
- BattleManager will apply the changes based on your returned data

```gdscript
# ✅ CORRECT: Return data for BattleManager to apply
func execute(...) -> Dictionary:
    if is_simulation:
        return {
            "stat": "pwr",
            "amount": 1,
            "targets": resolved_targets
        }
```

### Execution Mode (`is_simulation = false`)
- Mutate state directly (legacy compatibility)
- Return the numeric amount applied

### Critical Rules

| ❌ NEVER DO | ✅ INSTEAD |
|-------------|-----------|
| Call `BattleManager.apply_stat_delta()` from effect | Return data, let BattleManager apply |
| Call `trigger_on_hurt()` or `trigger_on_kill()` | BattleManager owns trigger flow |
| Query `get_instance()` for live data | Use context keys or parameters |
| Emit signals during simulation | Only emit in non-simulation mode |

---

## 4. Event Causality & Ordering

Events must be ordered by cause and effect. A cause must *always* precede its effect in the TurnLog.

### Correct Event Order
```
ATTACK_START → DAMAGE → on_hurt reactions → DEATH → on_death reactions → SUMMON → BUFF
```

### Key Ordering Rules

1. **on_hurt before on_death**: All pending `on_hurt` reactions (counter-attacks, buffs) are drained BEFORE `on_death` triggers fire
2. **DEATH event before on_death effects**: The DEATH event is created BEFORE on_death ability effects execute (for correct visual ordering)
3. **on_death before on_ally_death**: Items trigger before allies react
4. **on_before_attack collected immediately**: Events from `on_before_attack` (like Defensive Stance heal) are collected and added BEFORE damage events

> [!IMPORTANT]
> **Why This Matters**
> If `on_death` SUMMON events appear before `on_hurt` BUFF events in the TurnLog, animations will play out of order - the summoned unit appears before the buff animation on allies completes.

### Shockwave (Cascade AOE) Processing Rules

**Processing Order:**
- Shockwave processes targets **front-to-back** (from attacker's perspective)
- Player shockwave: lowest slot index (0) → highest slot index
- Enemy shockwave: highest slot index → lowest slot index (0)

**Event Sequence per Target:**
1. `on_before_attack` triggered (defensive abilities like Defensive Stance)
2. DAMAGE event created
3. `on_hurt` triggered (Aegis Charm, counter-attacks)
4. If HP <= 0 after Aegis processing: `on_kill` triggered
5. Continue to next cascade target (shockwave never stops early)

> [!NOTE]
> **Aegis Charm Interaction:** If Aegis saves a unit from shockwave, the LETHAL_SAVE event is emitted and the unit survives with 1 HP. The shockwave continues to deal damage to remaining targets normally.

### LETHAL_SAVE Event (Aegis Charm)

The `LETHAL_SAVE` event is a special CombatEvent for the Aegis Charm trinket:

**Flow:**
```
Effect returns {prevented_lethal: true} → BattleManager creates LETHAL_SAVE event → BattleAnimator emits unit_lethal_save → GachaBallView animates
```

**Visual Payload:**
| Key | Type | Purpose |
|-----|------|---------|
| `saved_uuid` | String | UUID of saved unit |
| `heal_amount` | int | Amount healed (to reach 1 HP) |

**Animation:** Unit floats up while turning golden, holds briefly, then lands back while returning to normal color. HP label updates to 1 after animation.

---

## 5. The Visual Contract (Simulation -> Presentation)

The `BattleAnimator` is dumb. It only knows what you tell it in `CombatEvent.visual_payload`.

### Required Payload Keys

**For `DAMAGE` events:**
| Key | Type | Purpose |
|-----|------|---------|
| `amount` | int | The number to display |
| `stat` | String | "hp" |
| `targets_old_hp` | Array[int] | HP before damage |
| `targets_new_hp` | Array[int] | HP after damage |
| `targets_max_hp` | Array[int] | Max HP for bar calculation |
| `skip_bump` | bool | If true, no recoil animation |
| `bump_direction` | Vector2 | Direction of knockback |

**For `BUFF` events:**
| Key | Type | Purpose |
|-----|------|---------|
| `amount` | int | The stat change |
| `stat` | String | "hp", "pwr", "burn_stacks" |
| `targets_old_val` | Array[int] | Value before |
| `targets_new_val` | Array[int] | Value after |

**For `SUMMON` events:**
| Key | Type | Purpose |
|-----|------|---------|
| `new_unit_uuid` | String | UUID of spawned unit |
| `old_unit_location` | LocationIdentifier | Where to spawn |
| `new_unit_snapshot` | Dictionary | hp, pwr, icon, tier, def_id, etc. |

---

## 6. Complex Interaction Pitfalls

### A. Death Tracking Architecture

The system uses a **turn-scoped death registry** (`_dead_this_turn`):

1. `_register_death(unit, phase)` → Call before creating DEATH events
2. `is_dead_this_turn(uuid)` → Check if unit already died this turn
3. Registry persists across COMBAT → END_OF_TURN → START_OF_TURN
4. Cleared only at the start of each new combat turn

> [!CAUTION]
> **Never check `current_hp <= 0` without also checking `is_dead_this_turn()`!**
> Multiple code paths detect deaths; without the registry check, you'll create duplicate DEATH events.

### B. Deferred Death & Counter-Attacks
When a unit takes lethal damage but has an ability with `execute_on_lethal = true`:
1. **Lethal Damage Detected.**
2. `_register_death()` marks unit as dead in the turn registry.
3. `on_hurt` abilities with `execute_on_lethal = true` execute (e.g., Counter-Attack, Retaliation).
4. `on_death` triggers fire (e.g., Summon Item).
5. The DEATH event is generated.
6. Unit is removed by `_finalize_deaths()`.

> [!IMPORTANT]
> Abilities with `execute_on_lethal = false` (default) are **discarded** if the source is dead.

### C. Board Space
Summon abilities gracefully handle full boards:
- Try original slot first
- If occupied by resurrection, find empty slot
- If no slots, send to discard pile
- If discard full, cancel summon

**Rule:** Effects that return summon data don't need to handle this - `BattleManager` does.

### D. Infinite Loops
The `AbilityResolver` limits trigger depth to prevent chain reactions.
**Limit:** Reaction depth is hardcoded (3-5 layers).

---

## 7. Trinket Implementation Checklist

> [!CAUTION]
> **DO NOT modify `BattleManager.gd` or `AbilityResolver.gd` when adding new trinkets!**
> Trinkets should be implemented using ONLY:
> - New `.tres` definition files
> - New effect scripts (only if existing ones don't work)
> - Existing trigger/context infrastructure

### 7.1 Pre-Implementation Verification

Before writing ANY code for a new trinket:

1. [ ] **Run game and verify ALL existing trinkets work**
2. [ ] **Find a similar existing trinket** and copy its structure exactly
3. [ ] **Check if `EffectModifyStat` can be reused** - it handles most buff/debuff cases
4. [ ] **Verify the trigger provides the context keys you need** (check Section 2)

### 7.2 Required Files

| File | Purpose | Copy From |
|------|---------|-----------|
| `resources/trinkets/trinket_[name].tres` | Trinket definition | `trinket_soul_echo.tres` |
| `resources/abilities/ability_trinket_[name].tres` | Ability definition | Similar ability |
| `resources/effects/effect_[name].tres` | Effect (only if new behavior) | Existing effect |
| `scripts/effects/Effect[Name].gd` | Effect script (only if needed) | `EffectModifyStat.gd` |

### 7.3 Trinket Source UUID Rules

> [!IMPORTANT]
> **For trinket effects, `source_uuid` in the context is EMPTY (`""`).**
> - `AbilityResolver` uses the **trinket instance itself** as the source
> - For buff visuals, the buff appears as a **self-buff** on the target
> - **NEVER** change `source_uuid` to hero_uuid - this breaks visual presentation

### 7.4 Team Determination for Trinkets

Because `source_uuid` is empty, you MUST have `team` in the context:

```gdscript
# ✅ CORRECT: Use fainting_ally_team from context
var is_player_team = (context.get("fainting_ally_team", "") == "PLAYER")

# ❌ WRONG: Try to get team from source instance
var source = battle_manager.get_instance(source_uuid)  # source_uuid is empty!
```

### 7.5 Common Trinket Mistakes

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Modifying `BattleManager._check_for_deaths` | Breaks all death triggers | Never modify core death handling |
| Changing `source_uuid` in trinket context | Wrong visual source, "Unknown grants" in log | Leave source_uuid empty |
| Missing `team` key in context | Silent targeting failure | Verify context keys at trigger source |
| Not testing existing trinkets after changes | Silent regressions | Always verify ALL trinkets work |
| Creating new effect script for simple buff | Code duplication | Use `EffectModifyStat.gd` |

### 7.6 Post-Implementation Verification

1. [ ] **Run game and trigger the new trinket** - Verify it works
2. [ ] **Verify ALL existing trinkets still work** - Check Soul Echo, Burn Vial, Healing Amulet
3. [ ] **Check log for "Unknown grants"** - This indicates wrong source_uuid
4. [ ] **Check log for multiple triggers** - Each trinket should fire exactly ONCE per death
5. [ ] **Verify both teams** - If trinket should work for enemies, test enemy deaths
6. [ ] **Check visual presentation** - Buffs should appear on target, not fly from hero

---

## 8. Reusable Effect Scripts

Before creating a new effect script, check if these existing ones handle your case:

| Effect Script | Use Case | Key Parameters |
|---------------|----------|----------------|
| `EffectModifyStat.gd` | HP/PWR/Status changes | `stat`, `base_value` |

| `BasicAttackEffect.gd` | Damage with targeting | `damage`, `target_type` |
| `EffectSummonOnDeath.gd` | Spawn random T1 unit when holder dies | (none) |
| `EffectResurrectFirstKilledUnit.gd` | Soul Echo resurrection | (none) |
| `EffectBossSummon.gd` | Boss wave reinforcements | `summon_list` |

**Example: Adding a "Grant +2 HP on ally death" trinket**
```tres
# DON'T create a new effect script!
# USE EffectModifyStat.gd with parameters:
[resource]
script = preload("res://scripts/EffectModifyStat.gd")
parameters = {
    "stat": "hp",
    "base_value": 2  # CRITICAL: Must use 'base_value', NOT 'amount'
}
target_type = &"RANDOM_ALLY"
```

---

## 9. Common Mistakes From Previous Sessions

### A. Multiple Trigger Fires
**Symptom:** Ability triggers 2+ times per event
**Cause:** Not using unified death registry, or duplicate broadcast calls
**Fix:** Use `_register_death()` before creating DEATH events; never duplicate trigger calls

### B. Wrong Event Order
**Symptom:** Resurrection happens before buff animation completes
**Cause:** `on_death` firing before `on_hurt` reactions drain
**Fix:** BattleManager drains pending reactions BEFORE calling `_check_for_deaths`. Don't bypass this.

### C. Ghost Attacks (Attacking Dead Units)
**Symptom:** Damage applied to units with 0 HP
**Cause:** Not checking `is_dead_this_turn()` or targeting after cleanup
**Fix:** `apply_stat_delta()` already rejects damage to dead units. Don't bypass it.

### D. Missing Animations
**Symptom:** Stat changes happen but no visual feedback
**Cause:** Missing required `visual_payload` keys
**Fix:** Include all required keys (see Section 5)

### E. Broken Targeting (Empty Target Arrays)
**Symptom:** `resolve_target()` returns `[]` for team-based targets
**Cause:** Empty `source_uuid` and missing `team` key in context
**Fix:** Ensure context includes `team` when source is empty (always for trinkets)

### F. Silent Effect Failure (Vengeance Trinket Bug)
**Symptom:** Trinket trigger fires (visible in logs) but no stat change occurs
**Root Cause:** Using wrong parameter name in `EffectModifyStat.gd` parameters
**What Happened:** Used `"amount": 1` instead of `"base_value": 1`. The script specifically reads `base_value`, and if it's 0 (the default), the effect silently returns `null`.

**Prevention Checklist:**
1. [ ] **ALWAYS view the effect script first** - Read `EffectModifyStat.gd` to see expected parameter names
2. [ ] **Check the exact variable names** - `parameters.get("base_value", 0)` means you MUST use `base_value`
3. [ ] **Copy working examples verbatim** - Don't guess parameter names
4. [ ] **Add debug logging if effect doesn't work** - Check if effect returns `null`

**The Silent Failure Pattern:**
```gdscript
# In EffectModifyStat.gd:
var base_value: int = int(parameters.get("base_value", 0))
if base_value == 0:
    return null  # SILENT FAILURE - no error, just no effect!
```

> [!CAUTION]
> `EffectModifyStat.gd` uses `base_value`, NOT `amount`. This caused multiple debugging sessions. Always verify parameter names by reading the effect script.

---

## 10. Copy-Paste Templates

### Template A: Buff on Ally Death (Trinket)

**Step 1: Create trinket definition** (`resources/trinkets/trinket_example.tres`)
```tres
[resource]
script = preload("res://scripts/TrinketDefinition.gd")
id = &"trinket_example"
display_name_key = "trinket.example.name"
description_key = "trinket.example.desc"
category = &"TRINKET"
ability_definitions = [preload("res://resources/abilities/ability_trinket_example.tres")]
icon = preload("res://assets/sprites/trinkets/example.png")
```

**Step 2: Create ability definition** (`resources/abilities/ability_trinket_example.tres`)
```tres
[resource]
script = preload("res://scripts/AbilityDefinition.gd")
id = &"trinket_example_effect"
trigger = &"on_ally_death"
effects = [preload("res://resources/effects/effect_example_buff.tres")]
priority = 0
```

**Step 3: Create effect definition** (`resources/effects/effect_example_buff.tres`)
```tres
[resource]
script = preload("res://scripts/EffectModifyStat.gd")
target_type = &"RANDOM_ALLY"
parameters = {
    "stat": "pwr",
    "base_value": 1  # CRITICAL: Must be 'base_value', NOT 'amount'!
}
```

**Step 4: Register in Database.gd**
```gdscript
trinkets[&"trinket_example"] = preload("res://resources/trinkets/trinket_example.tres")
```

### Template B: Damage on Attack (Unit Ability)

**Ability definition:**
```tres
[resource]
script = preload("res://scripts/AbilityDefinition.gd")
id = &"unit_cascade_strike"
trigger = &"on_attack"
effects = [preload("res://resources/effects/effect_cascade_damage.tres")]
priority = 10  # After normal attack
```

**Effect definition (using BasicAttackEffect):**
```tres
[resource]
script = preload("res://scripts/BasicAttackEffect.gd")
target_type = &"ADJACENT_ENEMIES"
parameters = {
    "damage_ratio": 0.5  # Half damage to adjacent
}
```

---

## 11. Decoupling Verification

Before committing, ask:
* "If I delete the entire HUD and run the battle in an invisible console, would this ability still work?"
    * **Yes:** Good.
    * **No:** You are relying on UI state. Refactor.
* "If I record this turn and replay it with different unit skins, does the logic change?"
    * **No:** Good.
    * **Yes:** You are coupling logic to visuals.

---

## 12. Architectural Checklist for New Units

When adding `Unit_New`:
1. [ ] **Define Abilities:** Create `.tres` files
2. [ ] **Verify Triggers:** Check Section 2 for available context keys
3. [ ] **Check Existing Effects:** Can you reuse `EffectModifyStat` or `BasicAttackEffect`?
4. [ ] **Visuals:**
    - Does `BattleAnimator` have a case for this event type?
    - If new visual needed (e.g., "Portal Open"): Add `CombatEvent.Type.PORTAL`, handler in `BattleAnimator`, and `PortalAnimation` class
5. [ ] **Determinism Check:**
    - Does it query `get_tree()`? **STOP.** State must be derived from context only.
6. [ ] **Test:**
    - New ability works as expected
    - ALL existing abilities still work

---

## 13. The `execute_on_lethal` Flag

### Purpose
Controls whether an ability can execute after the source unit has taken lethal damage.

### Usage
```gdscript
@export var execute_on_lethal: bool = false  # Default: ability discarded if source HP <= 0
```

| Value | Behavior |
|-------|----------|
| `false` (default) | Ability is discarded if source HP ≤ 0 |
| `true` | Ability executes even if source HP ≤ 0 |

### When to Use
| Ability Type | Setting | Reason |
|--------------|---------|--------|
| Counter-Attacks | `true` | Unit retaliates before dying |
| Resilient Aura | `true` | Buff allies even when taking fatal damage |
| Regular Buffs | `false` | No reason to buff if dying |
| Self-Heals | `false` | Can't heal yourself out of death |

### Example in `.tres` File
```tres
[resource]
script = preload("res://scripts/AbilityDefinition.gd")
id = &"item_t3d_retaliate_random"
trigger = &"on_hurt"
priority = 50
effects = Array[Resource]([SubResource("BasicAttackEffect_Retaliate_1")])
execute_on_lethal = true  # ← Allows execution after lethal damage
```
