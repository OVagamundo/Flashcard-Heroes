# Flashcard Heroes: Systems Architecture and Content Creation Guide

> [!IMPORTANT]
> This document is the **Single Source of Truth** for the entire Flashcard Heroes codebase.
> It consolidates and replaces:
> *   `AbilityImplementationGuide.md`
> *   `AbilityExecutionPipeline.md`
> *   `AnimationImplementationGuide.md`
>
> **Philosophy:** Strict Separation of Simulation vs. Presentation.

---

## Table of Contents

### Part I: Systems Architecture
1.  [Core Philosophy: The Hybrid Architecture](#1-core-philosophy-the-hybrid-architecture)
2.  [The Golden Rules of State](#2-the-golden-rules-of-state)
3.  [System Responsibilities](#3-system-responsibilities)

### Part II: Ability Implementation (Simulation)
4.  [The Priority System](#4-the-priority-system)
5.  [The Context Contract & Triggers](#5-the-context-contract--triggers)
    *   [Full Trigger Table](#51-full-trigger-table)
    *   [Attack Type Triggers](#52-attack-type-triggers)
    *   [Context Safety (Causes)](#53-context-safety--causes)
6.  [Event Causality & Order](#6-event-causality--order)
7.  [Trinket Specifics](#7-trinket-specifics)
8.  [Effect Scripts & Templates](#8-effect-scripts--templates)
    *   [EffectResult Pattern](#81-effectresult-pattern)
    *   [Stats vs Status Effects](#82-technical-distinction-stats-vs-status-effects)

### Part III: Animation Implementation (Presentation)
9.  [The Visual Contract](#9-the-visual-contract)
    *   [Standard Visual Events](#91-standard-visual-events)
10. [Composable Animation Channels](#10-composable-animation-channels)
11. [Gacha Draw & Physics](#11-gacha-draw--physics)
12. [Interaction Animations (Drag/Drop/Select)](#12-interaction-animations)

### Part IV: Technical Deep Dives
13. [The Ability Execution Pipeline (17 Steps)](#13-the-ability-execution-pipeline)
    *   [Critical Blocking Points (Debugging)](#131-critical-blocking-points)
14. [Complex Interaction Pitfalls](#14-complex-interaction-pitfalls)
    *   [Death Tracking](#141-death-tracking-architecture)
    *   [Board Space Priority](#142-board-space-and-summon-slot-priority)

---

## Part I: Systems Architecture

### 1. Core Philosophy: The Hybrid Architecture

The game follows a mandatory **Hybrid Architecture** that separates **Data Truth** from **Positional Indexing**. All systems must adhere to these rules:

| Concept | Class | Responsibility |
|---------|-------|----------------|
| **The Truth** | `GachaBallInstance` | A stateful composition container and the single source of truth for all mutable data (stats, components, location). **Never duplicate this data.** |
| **The Component** | `GachaBallComponent` | Source-aware modifications (Stat, Ability, Tag, Visual) that explain *why* an instance has its current properties. |
| **The Index** | `DataContainer` | A positional index (Array of UUIDs) that allows O(1) lookups. It does NOT own the data, only the *location* of the data. |
| **The Bridge** | `LocationIdentifier` | A universal key `{container, index, unit_uuid}` used to bridge Managers and Views. |

### 2. Tier-Based Strategic Roles
Content design should move away from generic "Weak vs. Strong" tiers toward functional board roles:

- **Tier 1 & 2 (The Engines)**: Designed for high **Interaction Surplus**. These units have low baked-in stats but complex scaling abilities. They are cheap to realize (T1L1 = 1 Gold) and serve as the fuel for the team engine.
- **Tier 3 (The Anchors)**: Designed for high **Stat Density**. They provide massive baked-in packages and serve as the ultimate multiplicative chassis for high-tier equipment to create "Board Stability." They have the highest "Gold-per-Token" realization rate (T3L1 = 4 Gold).
- **The Carry (Tier-Agnostic)**: A "Carry" is any unit where the Interaction Surplus (from Traits, Trinkets, and Items) makes them the primary value-driver. Even a Tier 1 unit can be a Carry if its scaling synergy is properly fueled. Leveling up further increases their Carry potential (+1 stat per level gained).

### 3. The Golden Rules of State

1.  **The Instance is King**: If `GachaBallInstance` says HP is 50, and the UI says 40, the Instance is right.
2.  **Atomic Transactions**: Any operation moving an instance (move, swap, equip) must update both the **Index** (`DataContainer`) and the **Truth** (`GachaBallInstance` location property) in a single underlying transaction.
3.  **Simulation First, Presentation Second**:
    *   **Simulation** (`BattleManager`) calculates the *entire* result of an interaction instantly.
    *   **Presentation** (`BattleAnimator`) replays that result over time.
    *   **NEVER** let an animation change the state of the simulation.

### 3. System Responsibilities

| System | Role | Key Components |
|--------|------|----------------|
| **Data Domain** | The raw state of the game. | `RunState`, `GachaBallDefinition`, `GachaBallInstance`, `GachaBallComponent` |
| **Battle System** | Simulation and Orchestration. | `BattleManager`, `CombatSimulator`, `EffectHandlers` |
| **Ability System** | Unified trigger processing and Effect execution. | `AbilityResolver` (Unified Query), `EffectDefinition` |
| **Presentation** | Visual feedback and User Interface. | `BattleAnimator`, `GachaBallView`, `BattleView`, `VisualDataAdapter` |

---

## Part II: Ability Implementation (Simulation)

### 4. The Priority System

The `BattleManager` processes reactions using a priority queue. **Higher Priority = Executed First.**
All constants are in `scripts/Constants.gd`.

| Priority | Constant | Usage | Examples |
|----------|----------|-------|----------|
| 300 | `PRIORITY_GUARDIAN_INTERCEPT` | Damage interception | Guardian Sentinel |
| 210 | `PRIORITY_SOUL_ECHO` | High-priority Resurrection | Soul Echo |
| 205 | `PRIORITY_UNIT_SUMMON` | Unit on-death summon | Sakura Spirit |
| 200 | `PRIORITY_ITEM_SUMMON` | Item on-death summon | Last Wish |
| 100 | `PRIORITY_BUFF_HEAL` | Standard Buffs/Heals | Resilient Aura |
| 50 | `PRIORITY_COUNTER_ATTACK` | Retaliation damage | Retaliate |
| 10 | `PRIORITY_MODIFY_ATTACK` | Attack modifiers | Shockwave |
| 0 | `PRIORITY_STANDARD` | Default abilities | Most abilities |
| -50 | `PRIORITY_BOSS_REINFORCEMENT`| End-of-turn spawns | Boss waves |
| -100 | `PRIORITY_EXTRA_ACTION` | Grant extra turns | Bloodlust Edge |

> [!TIP]
> **Instructor Dropdown**: You don't need to remember these integers. The `AbilityDefinition.tres` Inspector now provides a labeled dropdown for selecting these priority tiers directly.

> [!TIP]
> **Summon Logic:** High priority summons (Trinkets) claim slots first. If `Soul Echo` resurrects a unit into its own slot, `Last Wish` (lower priority) will look for a *different* open slot.

#### 4.1 Summon Restrictions

To maintain balance and logical consistency in encounters and summons, the following strict rules apply:
- **Dust Units and Elites Restriction**: Dust units and Dust elites CANNOT be summoned randomly by any standard units or items.
- **Soul Echo Exception**: The ONLY exception is the `Soul Echo` trinket, which CAN resurrect a Dust unit or Dust elite if it is the very first unit to die that turn and the team holds this trinket.
- **Boss Summoning**: Bosses cannot summon any Dust units or Dust elites through their generic reinforcement calls.
- **Dust Elite Summoning**: Dust elites themselves can ONLY summon standard Dust units; they can NEVER summon other Dust elites.

### 5. The Context Contract & Triggers

Abilities receive a `context` dictionary. **This is your ONLY link to the world state regarding the event.**

> [!IMPORTANT]
> **ZERO-INSTANCE-QUERY RULE**
> Effects must NEVER call `get_instance()` or query BattleManager state directly. All needed data must come from `context` or `parameters`.

#### 5.1 Full Trigger Table

| Trigger | Available Context Keys |
| :--- | :--- |
| `on_attack` | `attacker_uuid`, `target_uuid`, `target_initial_hp`, `is_simulation` |
| `on_before_damage` | `source_uuid`, `defender_uuid`, `attacker_uuid`, `target_initial_hp`, `is_simulation` |
| `on_hurt` | `victim_uuid`, `attacker_uuid`, `damage_taken`, `victim_team`, `victim_current_hp`, `is_simulation` |
| `on_healed` | `healed_uuid`, `heal_amount`, `healer_uuid`, `is_simulation` |
| `on_kill` | `attacker_uuid`, `killed_uuid`, `is_simulation` |
| `on_death` | `dying_uuid`, `dying_team`, `dying_location`, `equipped_items` |
| `on_ally_death` | `fainting_ally_uuid`, `fainting_ally_location`, `fainting_ally_team` (Trinket Critical!) |
| `on_before_turn_action` | `actor_uuid` |
| `on_turn_start/end` | `turn_number` |
| `on_draw` | `drawn_uuid`, `dest_container`, `dest_slot`, `tier`, `tokens_spent` |
| `on_token_spent` | `drawn_uuid`, `dest_container`, `dest_slot`, `tier`, `tokens_spent` |
| `on_merge` | `merged_uuid`, `merged_team`, `merge_container`, `merge_category` |

#### 5.2 Attack Type Triggers

**Which attacks trigger `on_before_damage` (Defensive)?**
| Attack Type | Triggers? | Implementation |
|-------------|-----------|----------------|
| Basic/Retaliation | ✅ Yes | `BasicAttackEffect.gd` |
| Shockwave | ✅ Yes | `EffectCascadeAOE.gd` (per target) |
| Bloodlust Extra | ✅ Yes | Goes through standard queue |

**Which attacks trigger `on_attack` (Offensive)?**
| Attack Type | Triggers? | Implementation |
|-------------|-----------|----------------|
| Basic/Retaliation | ✅ Yes | `BasicAttackEffect.gd` |
| Shockwave | ❌ No | It's an AOE, not a single targeted attack |
| Double Strike | ✅ Yes | Triggers via ability chain |

#### 5.3 Context Safety & Causes

To prevent infinite recursion, the system uses a **Cause Propagation** model (`trigger_cause`).

**Trigger Causes:**
*   `CAUSE_TURN`: Natural turn start.
*   `CAUSE_ABILITY`: Triggered by another ability/item.
*   `CAUSE_ATTACK`: Triggered by damage.
*   `CAUSE_STATUS`: Triggered by Burn/Poison.

**Safety Check Pattern:**
Use `ContextCauseCondition` to ensure your "Extra Attack" ability doesn't trigger itself.
```gdscript
# Prevent Infinite Loops:
# Only trigger Extra Attack if the cause was the TURN (natural attack), not another ability.
ContextCauseCondition(allowed_causes=[CAUSE_TURN])
```

### 6. Event Causality & Order

Events fire in a strict sequence per interaction.

**The Damage Sequence:**
1.  **`on_attack`**: Pre-attack buffs (e.g., Power Amulet).
2.  **`on_before_damage`**: Defensive triggers (e.g., Defensive Stance).
3.  **`DAMAGE` Applied**: State changes mechanically.
4.  **`on_damage_dealt`**: **Lifesteal** happens here (before hurt reactions).
5.  **`on_hurt`**: Counter-attacks, Retaliation.
6.  **`on_kill`**: If target HP <= 0.
7.  **`on_death`**: Self-death processing (Item Summons).
8.  **`on_ally_death`**: Ally reactions (Vengeance buffs).

> [!NOTE]
> **Shockwave (Cascade AOE)** uses a two-phase pattern:
> 1. Apply ALL damage to all targets (Wave effect).
> 2. Process ALL reactions (hurt/death) for each target.

### 7. Trinket Specifics

Trinkets are "Global Abilities" that sit on the sideline.
*   **Source UUID is EMPTY (`""`)**: The system does not treat the trinket as a unit on the board.
*   **Team Filtering**: `AbilityResolver` automatically filters trunkets so Player Trinkets only see Player events.
*   **Implementation**:
    *   Use `EffectModifyStat` for buffs.
    *   Set `target_type` to `RANDOM_ALLY`, `ALL_ALLIES`, etc.
    *   **NEVER** try to verify `source_uuid` inside a trinket effect.

### 8. Effect Scripts & Templates

#### Common Effect Scripts
| Script | Purpose |
|--------|---------|
| `EffectModifyStat.gd` | **90% of use cases.** Heals, Buffs, Damage (via negative HP). |
| `BasicAttackEffect.gd` | Standard attacks, counter-attacks, retaliation. |
| `EffectApplyStatus.gd` | Apply Burn, Armor, Spikes stacks. |
| `EffectLifesteal.gd` | Heal attacker based on damage dealt. |
| `EffectSummonOnDeath.gd` | Spawn units. |
| `EffectPreventLethal.gd` | Aegis Charm logic. |

#### 8.1 EffectResult Pattern
Effect scripts must return an `EffectResult` object in simulation mode, NOT a raw value or direct mutation.

```gdscript
var result := EffectResult.new()
# Add events directly
result.add_event(CombatEvent.new(CombatEvent.Type.HEAL, {...}))
# Or request damage processing
result.damage_request = {"stat": "hp", "amount": -10, "targets": targets}
return result
```

#### 8.2 Technical Distinction: Stats vs. Status Effects
To prevent "silent failures," understand the architectural difference.

*   **Stats (HP/PWR):** Use `EffectModifyStat.gd`. Stored in member variables.
*   **Status Effects (Burn/Armor/Spikes):** Use `EffectApplyStatus.gd`. Stored in `status_effects` dictionary.
*   **Common Bug:** Using `EffectModifyStat` to try to add "spikes_stacks". It will fail silently because "spikes_stacks" is not a stat.

---

## Part III: Animation Implementation (Presentation)

### 9. The Visual Contract
The `BattleAnimator` is a dumb puppet. It reads `CombatEvent.visual_payload`.

#### 9.1 Standard Visual Events

| Event Type | Visual Behavior | Payload Requirements |
|------------|-----------------|----------------------|
| `DAMAGE` | Shake, flash white, float number | `amount`, `stat="hp"`, `targets_old_hp`, `targets_new_hp` |
| `HEAL` | Green flash, float number | `amount`, `stat="hp"`, `targets_old_hp`, `targets_new_hp` |
| `BUFF` | Icon popup, stat change text | `stat`, `amount`, `targets_old_pwr`, `targets_new_pwr` |
| `DEATH` | Fade out, remove from scene | `target_uuids` |
| `DAMAGE_BURN` | Fire flash, float number | `amount`, `targets` |
| `SUMMON` | Fade in new unit | `new_unit_uuid`, `snapshot` |
| `LETHAL_SAVE` | Turn gold, float up | `saved_uuid` |
| `GUARDIAN_INTERCEPT` | Leap in front of ally | `guardian_uuid`, `protected_uuid` |

> [!IMPORTANT]
> If you don't provide `targets_old_hp` and `targets_new_hp`, the health bar will desync from the floating numbers.

### 10. Composable Animation Channels
The animation system allows 3 simultaneous effects on a unit. You can mix and match them using `SignalBus`.

1.  **Color Flash** (`unit_color_flash`): Shader tint.
2.  **Deformation** (`unit_deform`): Squash and stretch.
3.  **Movement** (`unit_move`): Position offset.

**Examples:**
*   **Hit Impact**: `HIT_IMPACT` (deform) + `RECOIL` (move) + `WHITE` (flash).
*   **Heal**: `HOP_DEFORM` (deform) + `HOP` (move) + `GREEN` (flash).

### 11. Gacha Draw & Physics

During battle, the gacha pools (and the shared Discard Pile) are represented as **Physics-Based Drawers**. These are read-only visualizations that represent the exact contents of the underlying `DataContainers`.

#### Drawer Visualization
-   **Persistent Simulation**: The physics continues simulated while closed/hidden.
-   **Inescapable Boundaries**: Walls are ~2000px thick to prevent balls escaping during high-velocity drawer animations.
-   **Sequential Spawning**: Balls spawn one-by-one with random stagger to prevent physics explosions.

#### Arc Trajectory
The draw animation follows a strict **Bezier Curve**.
*   **End**: Center of destination slot (+96px Y for visual centering).
*   **Control Point**: Horizontally centered, 400px above min(start.y, end.y).
*   **Easing**: `pow(t, 0.55)` for fast launch, snappy landing.

#### Signal Flow
```mermaid
BM->>SignalBus: emit("gacha_draw_animated", draw_result)
SignalBus->>BattleView: _on_gacha_draw_animated()
BattleView->>BattleView: Suppress redraw, play animation
BattleView->>BattleView: _force_refresh_after_anim()
```

### 12. Interaction Animations

#### Drag & Drop
*   **Pick up**: Scale up, follow mouse.
*   **Drag**: Rubber-band deformation based on velocity.
*   **Drop Success**: `LANDING_BOUNCE` (Squash -> Stretch -> Settle).
*   **Drop Fail**: Spring back to original slot.

#### Selection Feedback
*   When clicking a unit to inspect:
    *   **Visual**: `HOP` move + `HOP_DEFORM` + White Outline.
    *   **Logic**: Handled via `UnitAnimationController.play_selection_bounce()`.

---

## Part IV: Technical Deep Dives

### 13. The Ability Execution Pipeline

1.  **Trigger Emission**: `BattleManager` emits `on_X`.
2.  **Discovery**: `AbilityResolver` finds all units/items/trinkets.
3.  **Filtering**: Check `_should_unit_respond()` (Team check, Dead check).
4.  **Matching**: Find matching abilities in definition.
5.  **Lethal Check**: If source is dead, block unless `execute_on_lethal` is true.
6.  **Condition Check**: Run `check_condition()`.
7.  **Target Resolution**: Find targets (`resolved_targets`).
8.  **Queue**: Create `EffectRequest` and push to `_pending_reactions`.
9.  **Drain**: `CombatSimulator` sorts by priority and executes.
10. **Re-Validation**: Ensure targets are still alive/valid.
11. **Execution**: Call `effect.execute()`.
12. **Event Creation**: Generate `CombatEvent`s for the Animator.

#### 13.1 Critical Blocking Points

When an ability fails to fire, check these specific code blocks:

1.  **Optimization Filter (Step 4)**: `AbilityResolver.gd:38`. Does `unit_uuid` match the context (e.g. `dying_uuid`)?
2.  **Death Block (Step 6)**: `AbilityResolver.gd:266`. Is `source.current_hp <= 0` and `execute_on_lethal` false?
3.  **Dead Source Check (Step 12)**: `BattleManager._resolve_single_effect_request`. Did the unit die while the effect was in the queue?
4.  **Target Validation (Step 13)**: Did the targets die while the effect was in the queue?

### 14. Complex Interaction Pitfalls

#### 14.1 Death Tracking Architecture
The system uses a **turn-scoped death registry** (`_dead_this_turn`).
*   **Rule**: Never check `current_hp <= 0` without also checking `is_dead_this_turn()`.
*   **Reason**: Units can be mechanically dead (0 HP) but still processing reactions (e.g. Counter-Attack).

#### 14.2 Board Space and Summon Slot Priority
When multiple summons occur simultaneously (e.g. Soul Echo + Last Wish):

| Priority | Source | Claims Slot |
|----------|--------|-------------|
| 210 | Trinket (Soul Echo) | 1st (Gets dying unit's slot) |
| 205 | Unit Ability | 2nd |
| 200 | Item (Last Wish) | 3rd (Must find new slot) |

**Slot Search Order**:
1.  Original Slot.
2.  Alternative Slots (Back-to-Front).
3.  Discard Pile (Player only).

---

## ✅ Verification Checklists

Use these checklists **BEFORE** marking any implementation as complete.

### 1. New Unit Checklist
- [ ] **Stats Validated**: Ensure the unit's Tier and Level are correctly set in the `.tres` file.
- [ ] **Evolution Chain**: 
    - Is this a unique level definition (Lv 1 -> Lv 2 -> Lv 3)?
    - Does it have a self-merge recipe defined for the previous level?
- [ ] **Scaling vs. Package Density**: 
    - Is this an **Engine** (High Interaction Surplus) or an **Anchor** (High Stat Density)?
- [ ] **Tier & Cost Integrity**: 
    - `tier` matches filename and intended container.
    - `cost` follows the formula: `BaseTierCost * 2^(Level-1)` (e.g., T1L1=1, T1L2=2, T1L3=4; T3L1=4, T3L2=8, T3L3=16).
- [ ] **Category**: Set to `&"UNIT"`.
- [ ] **Soul Tags**: 
    - MUST include elemental souls corresponding to ingredients.
    - **Rule**: Use `SOUL_` prefix (e.g., `&"SOUL_FIRE"`, `&"SOUL_EARTH"`).
    - *Common Mistake*: Using just `&"FIRE"` is invalid and will break Trait calculations.
- [ ] **Exclusivity**:
    - Set `is_player_exclusive` to `true` if this content should NOT appear in enemy encounters.
- [ ] **Resources Created**:
    - Unit Resource (`.tres`)
    - Ability Resource (`.tres`)
    - Effect Script (`.gd`) - if custom logic needed.
- [ ] **Documentation**:
    - Added to `GameContentDocument.md` (Table).
- [ ] **RunState**:
    - Added to `RunState.gd` (Timekeeper Starters) for testing?

### 2. New Item Checklist
- [ ] **Category**: Set to `&"ITEM"`.
- [ ] **Tier & Cost**: Matches filename.
- [ ] **Exclusivity**: Set `is_player_exclusive` to `true` if player-only.
- [ ] **Ability**:
    - `trigger_type` appropriate? (Items usually `on_hurt`, `on_attack`, `on_damage_dealt`).
    - **Targeting**: Items usually target `HOLDER` or `ATTACK_TARGET`.
- [ ] **Documentation**:
    - Added to `GameContentDocument.md`.

### 3. New Trinket Checklist
- [ ] **Source UUID**: Must be `""` (Global/Passive).
- [ ] **Exclusivity**: Set `is_player_exclusive` to `true` if player-only.
- [ ] **Trigger**: usually `on_battle_start` or specific events (`on_ally_death`).
- [ ] **Targeting**: usually `RANDOM_ALLY` or `ALL_ALLIES`.
- [ ] **Team Context**: Ensure effects use `team` from context if needed.

### 4. New Consumable Checklist
- [ ] **Category**: Set to `&"CONSUMABLE"`. (Wait, consumables use `&"ITEM"` category but have specific tags? No, `C.CATEGORY_CONSUMABLE` exists?).
- [ ] **Verification**: Check `InventoryManager.gd` `_use_consumable` logic support.
- [ ] **Effect**: Must return `EffectResult`.

---
