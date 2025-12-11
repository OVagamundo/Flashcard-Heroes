# Ability Implementation Guide

## Purpose
This document serves as the definitive guide for implementing new abilities, items, and trinkets in Flashcard Heroes. It enforces the strict architectural separation between **Simulation** (Game Logic) and **Presentation** (UI/Animation) and ensures deterministic, cause-and-effect based gameplay.

> [!WARNING]
> Failure to follow these rules will result in desynchronized state, visual glitches (animations playing on dead units), or logic crashes (missing context keys).

## 1. The Priority System

The `BattleManager` processes reactions using a priority queue.
**Higher Priority = Executed First.**

- **Default:** `0`
- **High:** `10-100` (Interrupts, Blocks, Fast Counters)
- **Low:** `-10 to -100` (Cleanups, Slow Reactions)

### Importance
If multiple valid triggers occur (e.g., Unit A dies, triggering both `Soul Echo` and `Vengeance Buff`), the order matters.
- If `Soul Echo` (Priority 10) resurrects the unit, the slot becomes occupied.
- If `Vengeance Buff` (Priority 0) tries to summon a helper into that slot afterwards, it will fail because the slot is taken.

**Rule:** Always define `priority` in your `AbilityDefinition` (`.tres`) if order creates dependencies.

## 2. The Context Contract (What Data is Available?)

Abilities receive a `context` dictionary. **This is your ONLY link to the world state regarding the event.**
Accessing keys that don't exist for a specific trigger will cause runtime errors.

| Trigger | Available Context Keys |
| :--- | :--- |
| `on_attack` | `attacker_uuid`, `target_uuid`, `target_initial_hp` |
| `on_hurt` | `victim_uuid`, `attacker_uuid`, `damage_taken` |
| `on_kill` | `attacker_uuid`, `killed_uuid` |
| `on_death` | `dying_uuid`, `dying_team`, `dying_location`, `equipped_items` |
| `on_ally_death` | `fainting_ally_uuid`, `fainting_ally_location`, `fainting_ally_team` |
| `on_before_attack` | `defender_uuid`, `attacker_uuid` |
| `on_turn_start/end` | `turn_number` |

> [!NOTE]
> **Unified Broadcast Pattern:**
> BattleManager broadcasts `on_ally_death` **once** per death. AbilityResolver uses `_should_unit_respond()` and `_should_trinket_respond()` to filter which instances react (same team, alive, not the fainting unit).
>
> **CRITICAL:** When `source_uuid` is empty, the `team` key **MUST** be present in the context for `RANDOM_ALLY`, `RANDOM_ENEMY`, and other team-based target types to resolve correctly. Without it, `resolve_target()` returns an empty array.

> [!IMPORTANT]
> **Trinket Team Filtering:**
> Trinkets ONLY trigger for deaths on their own team. `AbilityResolver` compares the trinket's container (`PLAYER_TRINKETS` vs `ENEMY_TRINKETS`) against `fainting_ally_team` in the context. If a player ally dies, only player trinkets trigger. If an enemy ally dies, only enemy trinkets trigger. This prevents cross-team effects.

> [!WARNING]
> **Trigger Separation Architecture (`on_ally_death`):**
> 
> **Problem:** Unit abilities (e.g., "When ally dies, I gain +1 HP") need to be fired once per surviving ally observer. Trinkets are GLOBAL and must fire exactly **ONCE** per death event.
> 
> **Solution:** `BattleManager` makes TWO separate calls per death:
> 1. **Unit call** (in ally loop): Context includes `_skip_trinkets: true` → `AbilityResolver` skips Phase 3 (trinkets)
> 2. **Trinket call** (once per death): Context includes `_trinkets_only: true` → `AbilityResolver` skips Phase 1 (units) and Phase 2 (items)
> 
> **Implementation Requirement:** When adding new death-triggered effects, you MUST use this pattern. Never fire a single `on_ally_death` call that processes both units AND trinkets, or trinkets will fire N times (once per survivor).
> 
> **Context Flags:**
> - `_skip_trinkets: true` - Process unit and item abilities ONLY
> - `_trinkets_only: true` - Process trinket abilities ONLY

## 3. The Visual Contract (Simulation -> Presentation)

The `BattleAnimator` is dumb. It only knows what you tell it in `CombatEvent.visual_payload`.
If you implement a new ability "Meteor Strike", you must ensure the Presentation layer knows how to draw it.

### Required Payload Keys
When creating `BattleAnimator` compliant events, you must provide specific keys in `visual_payload`:

**For `DAMAGE` events:**
- `amount`: (int) The number to display.
- `is_crit`: (bool) Changes text color/shake.
- `element`: (String) "physical", "fire", "poison", etc. (Used by `DamageAnimation` to pick color).
- `has_projectile`: (bool) If true, triggers `ProjectileAnimation`.
- `projectile_texture`: (String) Path to texture (Required if `has_projectile` is true).
- `start_pos`: (Vector2) Origin of attack (Required if `has_projectile` is true).

> [!FAILURE MODE]
> If you omit `start_pos` but set `has_projectile: true`, the projectile will spawn at (0,0) or crash the tween.

## 4. Complex Interaction Pitfalls

### A. Death Tracking Architecture

The system uses a **turn-scoped death registry** (`_dead_this_turn`) to ensure each unit dies exactly once per turn:

1. `_register_death(unit, phase)` → Call before creating DEATH events
2. `is_dead_this_turn(uuid)` → Check if unit already died this turn
3. Registry persists across COMBAT → END_OF_TURN → START_OF_TURN
4. Cleared only at the start of each new combat turn

> [!CAUTION]
> **Never check `current_hp <= 0` without also checking `is_dead_this_turn()`!**
> Multiple code paths detect deaths; without the registry check, you'll create duplicate DEATH events.

### B. Deferred Death & Counter-Attacks
When a unit takes lethal damage but has a pending Counter-Attack:
1.  **Lethal Damage Detected.**
2.  `_register_death()` marks unit as dead in the turn registry.
3.  `on_death` triggers **IMMEDIATELY** (e.g., Summon Item).
4.  The unit is **marked for death** but **remains in the container** (Status: Fighting Ghost).
5.  Counter-Attack executes.
6.  Unit is finally removed by `_finalize_deaths()`.

**Consequence:** If your `on_death` ability tries to Summon a unit into the dying unit's slot, it will likely **FAIL** (Slot Occupied) unless your Summon logic explicitly accounts for overwriting the `source_uuid`.
*Correction:* `EffectSummonOnDeath` handles this by checking if the occupier is the dying unit. Custom effects might not.

### C. Board Space
Summon abilities generally fail silently if the board (or specific row) is full.
**Rule:** Always check `container.find_first_empty_slot()` before assuming a summon succeeded.

### D. Infinite Loops
The `AbilityResolver` limits trigger depth to prevent chain reactions (Unit A counters Unit B -> Unit B counters Unit A...).
**Limit:** Reaction depth is hardcoded (usually 3-5 layers).
**Consequence:** Deeply nested chains (Death -> Explosion -> Death -> Explosion...) may abruptly stop if the depth limit is reached.

## 5. Architectural Checklist for New Units

When adding `Unit_New`:
1.  **Define Abilities:** Create `.tres` files.
2.  **Verify Triggers:** Check `AbilitySystem.md` regarding trigger context.
3.  **Visuals:**
    - Does `BattleAnimator` have a case for this?
    - If strictly new visual (e.g., "Portal Open"):
        - Add new `CombatEvent.Type.PORTAL`.
        - Add handler in `BattleAnimator._animate_events`.
        - Add `PortalAnimation` class.
4.  **Determinism Check:**
    - **Randomness:** The system currently uses global `randi()`. Because the Simulation Phase is atomic (synchronous), this is safe from frame-by-frame UI interference *during* calculation. However, avoid using `await` or any async logic in the Simulation, as that would allow UI randomness to pollute the combat seed.
    - Does it query `get_tree()`? **STOP.** State must be derived from `BattleManager` internal state only.

## 6. Decoupling Verification

Before committing, ask:
* "If I delete the entire HUD and run the battle in a invisible console, would this ability still work?"
    * **Yes:** Good.
    * **No:** You are relying on UI state. Refactor.
* "If I record this turn and replay it with different unit skins, does the logic change?"
    * **No:** Good.
    * **Yes:** You are coupling logic to visuals.

---

## 7. Trinket Implementation Checklist

> [!CAUTION]
> **DO NOT modify core trigger systems (BattleManager.gd, AbilityResolver.gd) when adding new trinkets!**
> Trinkets should be implemented using ONLY:
> - New `.tres` definition files
> - New effect scripts (if needed)
> - Existing trigger/context infrastructure

### 7.1 Pre-Implementation Verification

Before writing ANY code for a new trinket:

1. **Verify existing trinkets work** - Run the game and confirm all existing trinkets trigger correctly
2. **Find a similar existing trinket** - Copy its structure exactly
3. **Check if existing effects can be reused** - Many trinkets use `EffectModifyStat` or similar generic effects
4. **Never modify `BattleManager.gd` or `AbilityResolver.gd`** unless you are fixing a bug in the trigger system itself

### 7.2 Required Files for New Trinket

| File | Purpose | Copy From |
|------|---------|-----------|
| `resources/trinkets/trinket_[name].tres` | Trinket definition | Existing trinket |
| `resources/abilities/ability_trinket_[name].tres` | Ability definition | Existing ability |
| `resources/effects/effect_[name].tres` | Effect definition (if new effect needed) | Existing effect |
| `scripts/effects/Effect[Name].gd` | Effect script (only if new behavior) | Existing effect script |

### 7.3 Trinket Source UUID Rules

> [!IMPORTANT]
> **For trinket effects, `source_uuid` in the context is empty (`""`).**
> - `AbilityResolver` uses the **trinket instance itself** as the source
> - For buff visuals, the buff appears as a **self-buff** on the target, not a projectile from a unit
> - **NEVER** change `source_uuid` to hero_uuid or any unit - this breaks visual presentation

### 7.4 Team Filtering

Trinkets are filtered by team in `AbilityResolver`:
- Player trinkets (in `PLAYER_TRINKETS` container) only trigger for player ally deaths
- Enemy trinkets (in `ENEMY_TRINKETS` container) only trigger for enemy ally deaths
- This is handled automatically - **do not duplicate this logic**

### 7.5 Common Mistakes (Lessons Learned)

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Modifying `BattleManager._check_for_deaths` | Breaks all death triggers | Never modify core death handling |
| Changing `source_uuid` in trinket context | Wrong visual source, log shows "Unknown grants" | Leave source_uuid empty |
| Adding new context flags (`_skip_trinkets`, `_trinkets_only`) | All existing abilities may break | Use existing infrastructure |
| Not testing existing trinkets after changes | Silent regressions | Always verify ALL trinkets work |
| Duplicating code across death paths | Inconsistent behavior | Refactor to single function first (separate PR) |
| Using same icon as another trinket | Visual confusion | Verify icon is unique |

### 7.6 Post-Implementation Verification

After implementing a new trinket:

1. **Run game and trigger the new trinket** - Verify it works
2. **Verify ALL existing trinkets still work** - Check Soul Echo, Burn Vial, Healing Amulet, etc.
3. **Check log for "Unknown grants"** - This indicates wrong source_uuid
4. **Check log for multiple triggers** - Each trinket should fire exactly ONCE per death
5. **Verify both teams** - If trinket should work for enemies, test enemy deaths too
6. **Check visual presentation** - Buffs should appear on target, not fly from hero

### 7.7 Quick Reference: Adding a Buff Trinket

For a trinket like "When ally dies, grant +1 PWR to random ally":

1. **Copy existing trinket definition:**
   ```
   resources/trinkets/trinket_vengeance.tres → copy from trinket_burn_vial.tres
   ```

2. **Create ability definition:**
   ```tres
   trigger = &"on_ally_death"
   effects = [effect_modify_stat.tres with stat="pwr", amount=1]
   target_type = &"RANDOM_ALLY"
   ```

3. **Use existing `EffectModifyStat`** - No new effect script needed

4. **Add unique icon** - Create new sprite in `assets/sprites/trinkets/`

5. **Register in Database** - Add to `scripts/Database.gd` trinket list

6. **Test ALL trinkets** - Not just the new one
