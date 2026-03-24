# System Refactoring Instructions: Priority & Step-by-Step Playback

## Goals

1. **[DONE] Priority Adjustability** — Single-value Inspector edit to reorder ability execution for balancing.
2. **[DONE] Step-by-Step Playback** — Player controls combat speed and can click through one event at a time to study the deterministic execution order.

---

## The Atomic Presentation Step (APS)

> The central design question: what is one "step" that the player sees?

### Answer: Each `CombatEvent` is already the correct granularity.

The existing `CombatEvent` types map 1:1 to player-visible information units:

| CombatEvent Type | What the player sees | Internal sub-animations (grouped) |
|---|---|---|
| `DAMAGE` | "Warrior hits Slime for 5" | Lunge → Impact flash → Recoil → HP label update → Spikes reflection |
| `HEAL` | "Potion heals Apprentice for 2" | Projectile → Hop → HP label update |
| `BUFF` | "Rally gives +2 PWR" | Projectile → Hop → PWR label update |
| `DEATH` | "Slime dies" | Float up → Fade out → Slot cleared |
| `SUMMON` | "Phoenix appears in Slot 2" | Drop from above → Fade in |
| `STATUS_EFFECT` | "Burn Vial applies 1 Burn" | Flash → Stack label update |
| `KAMIKAZE_ATTACK` | "Death's Bargain lunges and explodes" | Lunge → Impact → Fade at target |
| `GUARDIAN_INTERCEPT` | "Guardian leaps to protect Apprentice" | Leap → Land at ally position |
| `LETHAL_SAVE` | "Aegis saves Warrior at 1 HP" | Gold flash → Float → Land |
| `TRANSFORM` | "Mimic transforms into enemy" | Hop → Vanish → Reappear |
| `LOG_MESSAGE` | *(skip in step mode — no visual)* | None |

**Why this works**: Each `BattleAnimation.execute()` call already handles the full micro-sequence for one event. The `await` at the end of each event in `_animate_events()` already creates natural pause points. Step mode simply needs to **wait for user input between these existing pauses**.

**No new event type needed.** The events themselves are the steps. If the player wants to know "whose turn is it?", the `source_uuid` on each event already tells us.

### Actor Turn Headers

For the UI to show "Warrior's Turn" headers, use the existing `source_uuid` transitions. When the source changes between events (ignoring reactions), that's a new actor's turn. The `CombatSimulator` already processes actors sequentially, so this ordering is natural.

---

## Phase 1: SAP-Style Speed Control

Super Auto Pets uses a **global speed factor** that scales all animation durations. This is the simplest approach because:
- All animations already use `AnimationConstants` duration values
- All tween/timer calls go through predictable patterns (`create_timer(X).timeout`, `create_tween()` with `.set_duration(X)`)
- No need to touch `Engine.time_scale` (which would affect UI, music, etc.)

### Implementation

#### [MODIFY] `AnimationConstants.gd`

Add a static speed factor that all durations are divided by:

```gdscript
# --- PLAYBACK SPEED ---
# SAP-style speed factor. All animation durations are divided by this.
# 1.0 = normal, 2.0 = 2x speed, 4.0 = 4x speed
static var speed_factor: float = 1.0

## Get a duration scaled by the current speed factor.
## All animation code should call this instead of using raw constants.
static func scaled(duration: float) -> float:
    return duration / speed_factor
```

#### [MODIFY] All animation classes (17 files)

Replace all raw duration references with `AnimationConstants.scaled(DURATION)`:

```gdscript
# BEFORE:
await animator.get_tree().create_timer(0.5).timeout

# AFTER:
await animator.get_tree().create_timer(AnimationConstants.scaled(0.5)).timeout
```

```gdscript
# BEFORE:
var tween = create_tween()
tween.tween_property(node, "position", target, AnimationConstants.MELEE_LUNGE_DURATION)

# AFTER:
var tween = create_tween()
tween.tween_property(node, "position", target, AnimationConstants.scaled(AnimationConstants.MELEE_LUNGE_DURATION))
```

This is a mechanical find-and-replace across the 17 animation files. Each `create_timer()`, `tween_property()`, and `.set_duration()` call that uses a time value gets wrapped.

#### [MODIFY] `BattleAnimator.gd`

Add speed control API:

```gdscript
## Set combat playback speed (1.0 = normal, 2.0 = 2x, etc.)
func set_combat_speed(factor: float) -> void:
    AnimationConstants.speed_factor = clampf(factor, 1.0, 4.0)
```

#### UI: Speed Buttons

A small panel in `BattleView` with speed buttons (1x / 2x / 4x) that call `BattleAnimator.set_combat_speed()`.

---

## Phase 2: Step-by-Step Mode

### Behavior
- Player clicks **"Next Step"** button during combat → combat pauses at the **current event**
- Each subsequent click advances exactly **one `CombatEvent`**
- The current event's description is shown in a UI overlay
- Player can click **"Play"** to resume continuous playback at the selected speed
- If player changes speed during playback, it takes effect immediately

### Implementation

#### [MODIFY] `BattleAnimator.gd`

Add step mode state:

```gdscript
var _step_mode_active: bool = false
var _step_advance_signal: bool = false

signal combat_step_reached(step_info: Dictionary)  # For UI to display step description

## Called by UI when "Next Step" is clicked
func request_step_advance() -> void:
    if not _step_mode_active:
        # First click: activate step mode and pause
        _step_mode_active = true
        # Current event will complete, then we pause before the next one
    _step_advance_signal = true

## Called by UI when "Play" is clicked to resume
func resume_playback() -> void:
    _step_mode_active = false
    _step_advance_signal = true  # Unblock if waiting
```

Modify `_animate_events()` to check step mode between events:

```gdscript
func _animate_events(events: Array[CombatEvent]) -> void:
    for event in events:
        SignalBus.log_animation_event.emit(event)
        
        # Skip non-visual events
        if event.type == CombatEvent.Type.LOG_MESSAGE:
            continue
        
        # STEP MODE: Pause before each visual event and wait for user click
        if _step_mode_active:
            # Build step description from event data
            var step_info = _build_step_info(event)
            emit_signal("combat_step_reached", step_info)
            
            # Wait for user to click "Next Step"
            _step_advance_signal = false
            while not _step_advance_signal:
                await get_tree().process_frame
            _step_advance_signal = false
        
        # Execute the animation (unchanged)
        match event.type:
            CombatEvent.Type.DAMAGE:
                # ... existing code ...
```

#### Step Description Builder

New helper in `BattleAnimator` to create human-readable descriptions from event data:

```gdscript
func _build_step_info(event: CombatEvent) -> Dictionary:
    var info: Dictionary = {
        "event_type": event.get_type_name(),
        "source_uuid": event.source_uuid,
        "target_uuids": event.target_uuids,
        "ability_id": event.ability_id,
        "trigger_type": event.trigger_type
    }
    
    match event.type:
        CombatEvent.Type.DAMAGE:
            var amount = abs(int(event.visual_payload.get("amount", 0)))
            info["description"] = "Deals %d damage" % amount
        CombatEvent.Type.HEAL:
            var amount = int(event.visual_payload.get("amount", 0))
            info["description"] = "Heals for %d" % amount
        CombatEvent.Type.BUFF:
            var stat = String(event.visual_payload.get("stat", ""))
            var amount = int(event.visual_payload.get("amount", 0))
            info["description"] = "+%d %s" % [amount, stat.to_upper()]
        CombatEvent.Type.DEATH:
            info["description"] = "Dies"
        CombatEvent.Type.SUMMON:
            info["description"] = "Summoned"
        CombatEvent.Type.KAMIKAZE_ATTACK:
            var amount = abs(int(event.visual_payload.get("amount", 0)))
            info["description"] = "Kamikaze for %d damage" % amount
        _:
            info["description"] = event.get_type_name()
    
    return info
```

> [!NOTE]
> The step info uses only event payload data (no instance queries). Unit display names can be resolved by the UI layer using the `source_uuid`/`target_uuids` from the start-of-turn snapshot that `BattleAnimator` already holds.

#### UI: Step Mode Panel

A panel that appears during combat with:
- **⏩ Speed buttons** (1x / 2x / 4x)
- **⏭ Next Step button** — click to pause and advance one event at a time
- **▶ Play button** — resume continuous playback (replaces Next Step while in step mode)
- **Current step display** — shows the description from `combat_step_reached` signal

---

## Phase 3: Priority Inspector Enhancement

#### [MODIFY] `AbilityDefinition.gd`

Add `_get_property_list()` to show a labeled dropdown in the Inspector:

```gdscript
# Remove the @export from priority since _get_property_list overrides it
var priority: int = 0

func _get_property_list() -> Array[Dictionary]:
    return [{
        "name": "priority",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Standard:0,Defensive Stance:10,Counter Attack:50,Aura/Heal:100,Summon Blessing:110,Item Summon:200,Unit Summon:205,Trinket Summon:210,Death Damage:215,Guardian Intercept:300,Boss Summon:-50,Extra Action:-100"
    }]
```

#### [MODIFY] `Constants.gd`

Add tier band documentation above the priority constants:

```gdscript
# --- Ability Priority System ---
# HIGHER value = executes FIRST. 
# To change execution order: change the priority value here AND update the
# corresponding AbilityDefinition._get_property_list() dropdown hint_string.
#
# BAND 300+  : Interceptors (Guardian - must pre-empt damage)
# BAND 200-299: Death reactions (Summons, Resurrections - slot conflict ordering)
# BAND 100-199: Combat responses (Buffs, Heals, Auras)
# BAND 1-99  : Modifiers (Counter-attacks, Defensive abilities)
# BAND 0     : Standard (Default for ALL new abilities)
# BAND < 0   : Delayed (Boss summons, Extra actions - fire last)
```

---

## Golden Test Scenario: Maximum Cascade Chain

The most complex chain possible with current content for testing step-by-step and priority correctness.

### Setup: The Death Cascade

**Player lineup** (left to right, slot 4 → 0):
- **Slot 4 (front)**: Necromancer (T3) — "Soul Summon" (`on_death`, priority 205): summons T2 unit
  - Equipped: **Deathbomb** (T3 item) — "Explode" (`on_death`, priority 200): damage to highest HP enemy
  - Equipped: **Summon Scroll** (T2 item) — "Summon" (`on_death`, priority 200): summons T1 unit
- **Slot 3**: Warden (T3) — "Resilient Aura" (`on_hurt`, priority 100): +1 HP/+1 PWR to adjacent allies
  - Equipped: **Bloodlust Blade** (T2 item) — "Bloodlust" (`on_kill`): extra action
- **Slot 2**: Assassin (T3) — "Ambush Predator" (`on_enemy_summon`): damage to summoned enemies
- **Slot 1**: Knight (T2) — "Morale Boost" (`on_ally_death`): +1 HP / +1 PWR
- **Slot 0 (back)**: Squire (T1) — "Retaliation" (`on_hurt`, priority 50): counter-attack

**Player trinkets**: **Soul Echo** (`on_ally_death`, priority 210): resurrect first killed ally

**Enemy lineup**: Strong enough to kill the Necromancer in one hit.

### Expected Chain

1. **Enemy attacks Necromancer** → DAMAGE event
2. **Warden's Resilient Aura fires** → BUFF event (adjacent ally buff, priority 100)
3. **Necromancer reaches 0 HP** → death processing begins
4. **Soul Echo fires** (priority 210) → SUMMON: resurrects Necromancer
5. **Necromancer's Soul Summon fires** (priority 205) → SUMMON: T2 unit appears
   - Assassin's Ambush Predator fires on this summon
6. **Deathbomb fires** (priority 200) → DAMAGE to highest HP enemy
   - If enemy dies → on_kill triggers
7. **Summon Scroll fires** (priority 200) → SUMMON: T1 unit appears
   - Assassin fires again
8. **Knight's Morale Boost fires** (`on_ally_death`) → BUFF
9. **DEATH event** for any killed enemies → more cascades possible
10. **Warden with Bloodlust gets extra action** if it killed something

This chain tests: priority ordering, multiple death triggers, summon reactions, counter-attacks, and cascading kills.

### How to Verify

Run this scenario in test mode, enable step-by-step mode, and click through each step confirming:
- [ ] Events appear in correct causal order (cause before effect)
- [ ] Priority ordering is respected (210 before 205 before 200)
- [ ] No duplicate death events or triggers
- [ ] Step descriptions accurately reflect what's happening
- [ ] Speed control (2x/4x) doesn't skip or reorder events

---

## Files Changed Summary

| File | Phase | Change |
|---|---|---|
| `AnimationConstants.gd` | 1 | Add `speed_factor` static var + `scaled()` helper |
| 17 animation files | 1 | Wrap all durations with `AnimationConstants.scaled()` |
| `BattleAnimator.gd` | 1+2 | Add speed API + step mode logic |
| `BattleView` (UI) | 1+2 | Add speed buttons + step mode buttons |
| `AbilityDefinition.gd` | 3 | Add `_get_property_list()` for Inspector dropdown |
| `Constants.gd` | 3 | Add tier band documentation comments |

### Bug Fix (any phase)
| File | Change |
|---|---|
| `CombatSimulator.gd:676-678` | Remove duplicate `on_kill` trigger loop |
