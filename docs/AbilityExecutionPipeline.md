# Ability Execution Pipeline: Definitive Technical Reference

This document provides a complete technical trace of how abilities flow from definition to presentation. Use this to debug any ability issue without guesswork.

---

## 1. Data Schema (Resource Definitions)

### AbilityDefinition.gd
The "glue" resource that links a Trigger to Effects via an optional Condition.

| Property | Type | Purpose |
|----------|------|---------|
| `id` | StringName | Unique ID (e.g., `&"unit_tier3c_soul_summon"`) |
| `trigger` | StringName | Event that activates this ability (see [Trigger Vocabulary](#3-trigger-vocabulary)) |
| `condition` | ConditionDefinition | Optional check before firing |
| `effects` | Array[EffectDefinition] | Actions to execute when triggered |
| `priority` | int | Execution order (higher = first, default 0) |
| `execute_on_lethal` | bool | If true, can fire even when source has HP ≤ 0 |

### EffectDefinition.gd
Base class for effect scripts. Concrete implementations (e.g., `EffectModifyStat`, `EffectSummonT2OnDeath`) inherit from this.

| Property | Type | Purpose |
|----------|------|---------|
| `parameters` | Dictionary | Effect-specific config (damage amount, stat name, etc.) |
| `target_type` | StringName | How to resolve targets (`SELF`, `ATTACK_TARGET`, `ALL_ENEMIES`, etc.) |

**Key Method:**
```gdscript
func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant
```
- Returns `Dictionary` with effect outcome data (`summon_unit_id`, `stat`, `amount`, etc.)
- Returns `int` (legacy) for simple damage values
- Returns `null` or `{}` for no action

### EffectRequest.gd
A queued request to execute an effect. Created by `AbilityResolver._process_ability()`.

| Property | Type | Purpose |
|----------|------|---------|
| `source_uuid` | String | UUID of the instance whose ability is being processed |
| `ability_id` | StringName | ID of the AbilityDefinition |
| `effect_definition` | EffectDefinition | The effect script to execute |
| `resolved_targets` | Array[String] | Pre-resolved target UUIDs |
| `trigger_context` | Dictionary | Original context (contains `dying_uuid`, `attacker_uuid`, etc.) |
| `priority` | int | Copied from AbilityDefinition.priority |

### CombatEvent.gd
The simulation→presentation bridge. Created by BattleManager after effect execution.

| Type | Purpose | Key Payload Fields |
|------|---------|-------------------|
| `DAMAGE` | HP reduction | `amount`, `new_hp`, `is_crit` |
| `HEAL` | HP restoration | `amount`, `new_hp` |
| `DEATH` | Unit died | `target_uuids` |
| `SUMMON` | Unit spawned | `snapshot`, `old_unit_location` |
| `BUFF` | Stat change | `stat`, `amount`, `new_val` |

---

## 2. Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ABILITY EXECUTION PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐                                                       │
│  │ 1. GAME EVENT    │  A unit takes damage, attacks, dies, etc.             │
│  └────────┬─────────┘                                                       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 2. TRIGGER EMISSION (BattleManager)                              │       │
│  │    AbilityResolver.process_trigger(&"on_X", context)             │       │
│  │    context = { dying_uuid, attacker_uuid, victim_uuid, etc. }    │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 3. INSTANCE DISCOVERY (AbilityResolver.process_trigger)         │       │
│  │    Queries battle_manager.get_all_instances()                    │       │
│  │    Categorizes into: unit_instances, equipped_item_instances,    │       │
│  │                      trinket_instances                           │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 4. FILTER (AbilityResolver._should_*_respond)                   │       │
│  │    Checks: Is this instance relevant to this trigger?           │       │
│  │    Example: on_self_death only allows unit_uuid == dying_uuid   │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 5. ABILITY MATCH (AbilityResolver.process_trigger loop)         │       │
│  │    For each ability in definition.ability_definitions:          │       │
│  │      if ability.trigger == trigger: _process_ability(...)       │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 6. DEATH/LETHAL CHECK (AbilityResolver._process_ability)        │       │
│  │    IF source is UNIT with HP ≤ 0:                               │       │
│  │      Block execution UNLESS ability.execute_on_lethal == true   │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 7. CONDITION CHECK (AbilityResolver._process_ability)          │       │
│  │    IF ability.condition exists:                                  │       │
│  │      battle_manager.check_condition(condition, source, context) │       │
│  │      Block if returns false                                      │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 8. TARGET RESOLUTION (AbilityResolver._process_ability)         │       │
│  │    resolved_targets = battle_manager.resolve_target(            │       │
│  │        source_uuid, effect.target_type, context)                │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 9. EFFECT REQUEST CREATION (AbilityResolver._process_ability)   │       │
│  │    EffectRequest.new(source_uuid, ability.id, effect,           │       │
│  │                      resolved_targets, context, ability.priority)│       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 10. ENQUEUEING (BattleManager.enqueue_effect_request)           │       │
│  │     _pending_reactions.push_back(request)                       │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 11. QUEUE DRAIN (CombatSimulator.execute_combat_turn)            │       │
│  │     _pending_reactions.sort_custom(by priority, descending)     │       │
│  │     For each request: battle_manager._resolve_single_effect_request()│  │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 12. DEAD SOURCE CHECK (BattleManager._resolve_single_effect_request)│   │
│  │     IF source is UNIT with HP ≤ 0:                              │       │
│  │       ALLOW if dying_uuid == source_uuid (own death trigger)    │       │
│  │       ALLOW if ability_id contains "counter" or "retaliate"     │       │
│  │       OTHERWISE: return (block execution)                        │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 13. TARGET VALIDATION (BattleManager._resolve_single_effect_request)│   │
│  │     Filter out dead targets (HP ≤ 0) and targets not in battle  │       │
│  │     If expected targets but all invalid → return                │       │
│  │     EXCEPTION: Targetless effects (summons) proceed with []     │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 14. EFFECT EXECUTION (BattleManager._resolve_single_effect_request)│    │
│  │     res = request.effect_definition.execute(source_uuid,        │       │
│  │           exec_targets, battle_manager, sim_ctx)                │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 15. RESULT PROCESSING (BattleManager._resolve_single_effect_request)│   │
│  │     Normalize: int → {"stat": "hp", "amount": -damage}          │       │
│  │     Route by effect_data keys:                                   │       │
│  │       "summon_unit_id" → Create unit, emit SUMMON event         │       │
│  │       "stat" + "amount" → Apply delta, emit DAMAGE/HEAL/BUFF    │       │
│  │       "cascade_damage" → Process AOE chain                       │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 16. EVENT CREATION (BattleManager._resolve_single_effect_request)│      │
│  │     out_events.append(CombatEvent.new(Type.X, {...}))           │       │
│  └────────┬─────────────────────────────────────────────────────────┘       │
│           ▼                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐       │
│  │ 17. PRESENTATION (BattleAnimator.play_turn_sequence)            │       │
│  │     Receives Array[CombatEvent] from simulation                  │       │
│  │     Plays each event in sequence with animations                │       │
│  └──────────────────────────────────────────────────────────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Trigger Vocabulary

### Trigger Execution Order (Per Damage Event)

```
on_attack → on_before_damage → DAMAGE applied → on_damage_dealt → on_hurt → on_kill → on_death → on_ally_death
```

> [!IMPORTANT]
> **Lifesteal Timing**: `on_damage_dealt` fires BEFORE `on_hurt`. Lifesteal heals appear immediately after damage, before counter-attack chains.

### Trigger Reference

| Trigger | When Fired | Context Keys |
|---------|-----------|--------------|
| `on_battle_start` | Once at combat start | `{}` |
| `on_turn_start` | Each turn before first action | `turn_number` |
| `on_attack` | **ALL attacks** - emitted before damage. Use conditions (e.g., `CAUSE_TURN`) to filter. | `attacker_uuid`, `target_uuid`, `trigger_cause` |
| `on_before_damage` | Before damage is dealt to defender | `attacker_uuid`, `defender_uuid` |
| `on_damage_dealt` | After attacker deals damage (fires before `on_hurt`) | `attacker_uuid`, `victim_uuid`, `damage_dealt` |
| `on_hurt` | After unit receives attack damage (fires after `on_damage_dealt`) | `victim_uuid`, `attacker_uuid`, `damage_taken` |
| `on_kill` | When damage causes target HP ≤ 0 | `attacker_uuid`, `killed_uuid` |
| `on_death` | When unit's HP drops to ≤ 0 | `dying_uuid`, `dying_location`, `dying_team`, `equipped_items` |
| `on_ally_death` | For allies when any ally dies (includes bench units) | `fainting_ally_uuid`, `fainting_ally_location`, `fainting_ally_team` |
| `on_turn_end` | After all units have acted | `turn_number` |


---

## 4. Filter Logic Reference

### _should_unit_respond (AbilityResolver.gd:38-69)

| Trigger | Filter Logic |
|---------|--------------|
| `on_death` | `unit_uuid == context.dying_uuid` |
| `on_ally_death` | Same team, alive, not the dying unit |
| `on_hurt` | `unit_uuid == context.victim_uuid` |
| `on_attack`, `on_kill`, `on_damage_dealt` | `unit_uuid == context.attacker_uuid` |
| `on_before_damage` | `unit_uuid == context.defender_uuid` |
| `on_turn_start`, `on_turn_end`, `on_battle_start` | `unit.current_hp > 0` |


### _should_item_respond (AbilityResolver.gd:76-105)
Uses `item.equipped_on_uuid` (holder) instead of item's own UUID.

### _should_trinket_respond (AbilityResolver.gd:114-128)
Filters by team matching (player trinket for player unit events, etc.)

---

## 5. Critical Blocking Points

When an ability doesn't fire, check these locations in order:

### Step 4 - Filter
**File:** `AbilityResolver.gd:38-69`
**Symptom:** Ability not found for trigger
**Debug:** Check if `unit_uuid` matches required context key (e.g., `dying_uuid`)

### Step 6 - Death Check in AbilityResolver
**File:** `AbilityResolver.gd:266-276`
**Symptom:** Dead unit abilities blocked
**Debug:** Check `ability.execute_on_lethal` flag
```gdscript
if source.current_hp <= 0:
    if not ability.execute_on_lethal:
        return  # BLOCKED
```

### Step 12 - Dead Source Check in BattleManager
**File:** `BattleManager.gd` in `_resolve_single_effect_request()`
**Symptom:** EffectRequest silently dropped
**Debug:** Verify `trigger_context.dying_uuid == request.source_uuid`
```gdscript
if src_def.category == &"UNIT" and source.current_hp <= 0:
    var dying_uuid: String = request.trigger_context.get("dying_uuid", "")
    var is_own_death_trigger: bool = (dying_uuid == request.source_uuid)
    if not is_own_death_trigger and not is_reactive_ability:
        return  # BLOCKED
```

### Step 13 - Target Validation
**File:** `BattleManager.gd` in `_resolve_single_effect_request()`
**Symptom:** Effect has targets but all are dead
**Debug:** Check `resolved_targets` vs current HP of targets
```gdscript
if valid_targets.is_empty() and not exec_targets.is_empty():
    return  # BLOCKED - expected targets but all invalid
```

### Step 14 - Invalid Effect Definition
**File:** `BattleManager.gd` in `_resolve_single_effect_request()`
**Symptom:** execute() never called
**Debug:** Check `is_instance_valid(request.effect_definition)`

---

## 6. Effect Return Value Format

Effects must return structured data for BattleManager to create events:

### Damage/Heal/Buff
```gdscript
return {
    "stat": "hp",        # or "pwr", "burn_stacks", etc.
    "amount": -5,        # negative = damage, positive = heal/buff
    "targets": [uuid1, uuid2]
}
```

### Summon
```gdscript
return {
    "summon_unit_id": "unit_t2_a",
    "holder_uuid": dying_uuid,
    "holder_location": LocationIdentifier
}
```

### Multi-Target Buff/Heal
```gdscript
return {
    "multi_buff": true,
    "buffs": [{"uuid": uuid1, "amount": 2}, {...}],
    "stat": "pwr"
}
```

---

## 7. Queue Drain Points

The `_pending_reactions` queue is drained at these locations:

| Location | When | Notes |
|----------|------|-------|
| `CombatSimulator.execute_combat_turn()` | Main combat loop | Actor/reaction processing |
| `BattleManager._check_for_deaths_with_counter_delay` | Death processing | Death-triggered effects |
| `BattleManager.drain_pending_reactions_inline` | Inline during effect | For on_hurt chains |
| `BattleManager._trigger_turn_end_abilities` | End-of-turn | Burn damage deaths |

---

## 8. Debugging Checklist

When an ability doesn't work:

1. **Check Resource Definition**
   - Does `.tres` have correct `trigger` StringName?
   - Is `effects` array populated with valid EffectDefinition?
   - For death triggers on units: is `execute_on_lethal` needed?

2. **Check Filter Logic**
   - Add trace in `_should_unit_respond` for the trigger
   - Verify context has expected keys

3. **Check Condition**
   - If ability has condition, verify it passes

4. **Check Effect Execution**
   - Add trace at start of effect's `execute()` method
   - Verify return value matches expected format

5. **Check Event Creation**
   - Verify effect return value routes to correct handler in `_resolve_single_effect_request`
   - Check `out_events` array after execution

6. **Check for Side-Channel Leaks**: Ensure no code (including `BattleManager` callbacks) emits global redraw signals like `battle_inventory_changed` during combat. Redrawing mid-animation forces the UI to the "future" model state, causing desyncs.
