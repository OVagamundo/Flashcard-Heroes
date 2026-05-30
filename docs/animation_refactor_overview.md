# Animation Refactor & Bug Fix Plan (Godot/GDScript)

## 1. Problem Analysis

The user reported two main issues:
1. **Trinket cross-talk (spurious animations)**: E.g., Veteran Insignia activating causes Royal Insignia to animate. Fusion Spark hops extra times.
2. **Incorrect sequential pacing**: Trinket animations play one after another and delay the actual combat events, rather than playing concurrently.

### Root Causes Discovered in the Codebase

**1. Data Contamination in `CombatSimulator._tag_trinket_events`:**
- Currently, `CombatSimulator` loops through generated `CombatEvent`s and injects trinket data into the `visual_payload` dictionary. 
- However, if a reaction triggers *inline events* (e.g. Fusion Spark deals damage -> triggers an enemy's Phoenix Feather heal), those inline heal events are appended to the same array and get tagged by Fusion Spark too!
- Furthermore, Godot passes dictionaries by reference. If events share payloads, or if `_tag_trinket_events` blindly overrides the singleton keys (`trinket_visual_uuid`), the previous trinket tags get permanently overwritten. When `BattleAnimator` fails to find the exact `visual_uuid`, it falls back to `trinket_definition_id`, which can erroneously grab the first matching trinket on the board (e.g. Royal Insignia).

**2. Forced Sequential `await` in `BattleAnimator.gd`:**
- In `_animate_events(events)`, the code explicitly does `await _play_trinket_activations_for_event(event)` BEFORE advancing to the event's actual visual playback (`match event.type`).
- Inside `_play_trinket_activations_for_event`, it loops through activations and forces an `await get_tree().create_timer(0.25).timeout` for every single trinket. This forces all trinkets to hop sequentially and blocks the main combat animation.

---

## 2. Proposed Implementation Plan

We do NOT need to rewrite the entire VCR pattern into a generic event bus (which would be defensive coding). The current `CombatEvent` queue and VCR replay system works perfectly for decoupling simulation from presentation. We just need to fix the data structure and playback timing.

### Step 1: Strongly Type Trinket Activations on `CombatEvent`
Instead of loosely stuffing data into the `visual_payload` dictionary (which is vulnerable to reference-sharing and key-overwriting), we will add a dedicated array to the `CombatEvent` class.

**`scripts/CombatEvent.gd`:**
```gdscript
# Add new property
var trinket_activations: Array[Dictionary] = []
```

### Step 2: Fix Tagging Scope in `CombatSimulator.gd`
We will modify `_tag_trinket_events` to:
1. Use the new `event.trinket_activations.append()` method.
2. **Crucially:** Only tag events that *actually belong* to the triggering trinket by validating `event.ability_holder_uuid == request.source_uuid`. This prevents Fusion Spark from tagging the target's reactive heal events.

**`scripts/battle/CombatSimulator.gd` (`_tag_trinket_events`):**
```gdscript
func _tag_trinket_events(events: Array[CombatEvent], request: EffectRequest, bm, start_index: int = 0) -> void:
    # ... setup logic ...
    for i in range(start_index, events.size()):
        var event := events[i]
        
        # FIX: Only tag events that actually originated from this trinket!
        if event.ability_holder_uuid != request.source_uuid:
            continue
            
        event.trinket_activations.append({
            "visual_uuid": visual_uuid,
            "definition_id": source.definition_id,
            "is_enemy": is_enemy_trinket
        })
```
*(We will also remove the legacy `visual_payload` overwriting logic from this function).*

### Step 3: Enable Concurrent Playback in `BattleAnimator.gd`
We will modify the animator to play the trinket bounces *concurrently* with each other and concurrently with the main event, precisely as requested.

**`scripts/BattleAnimator.gd`:**
1. In `_play_trinket_activations_for_event`, read directly from `event.trinket_activations` (with fallback to legacy visual payload keys if any remain, for backward compatibility).
2. **Remove** the `await get_tree().create_timer(0.25).timeout`.
3. In `_animate_events`, **remove** the `await` before `_play_trinket_activations_for_event(event)` so it fires asynchronously at the exact moment the combat event begins.

```gdscript
# In _animate_events:
# Fire concurrent trinket activations without blocking
_play_trinket_activations_for_event(event)

# In _play_trinket_activations_for_event:
for activation in event.trinket_activations:
    play_trinket_activation(
        String(activation.get("visual_uuid", "")),
        StringName(activation.get("definition_id", &"")),
        bool(activation.get("is_enemy", false))
    )
# (Remove the 0.25s await timer)
```

---

## 3. Verification Plan

1. **Bug Resolution**:
   - Merging units while Fusion Spark and Veteran Insignia are equipped.
   - **Expected Behavior**: Fusion Spark hops exactly **once** (simultaneously with its damage particle). Veteran Insignia hops exactly **twice** (simultaneously with its HP and PWR buffs). Royal Insignia does not hop at all.
2. **Visual Pacing**: The combat flow should feel significantly faster and more dynamic, as trinket bounces now weave seamlessly into the action rather than halting the game.

## 4. User Review Required
Does this specific GDScript plan align with your vision? By fixing the explicit data ownership (`event.trinket_activations`) and removing the forced sequential `await`s, we completely solve the bugs while avoiding unnecessary defensive abstraction layers.
