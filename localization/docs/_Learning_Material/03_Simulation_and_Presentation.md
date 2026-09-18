# Module 3: The Simulation vs. Presentation Pipeline (The VCR Pattern)

## The VCR Pattern
In a highly reactive game, computing damage and playing animations simultaneously causes chaos. If Unit A attacks Unit B, and Unit B has a "Thorns" effect that kills Unit A, and Unit A has a "Explode on Death" effect... attempting to wait for animations between all these steps results in race conditions and bugs.

Instead, we use **The VCR Pattern**:
1. **The Recording (Simulation):** `CombatSimulator.gd` does all the math instantly in a `while` loop. It records everything that happens into a "tape" (an Array of `CombatEvent`s).
2. **The Playback (Presentation):** `BattleAnimator.gd` takes that "tape" and plays it back visually on the screen, one event at a time, using `await`.

```mermaid
flowchart TD
    %% Define the Layers
    subgraph Simulation_Phase [Silent Simulation Phase (Math)]
        direction TB
        CS[CombatSimulator.gd]
        BAE[BasicAttackEffect.gd]
        CS -- "1. Loops through Actor Queue\nand resolves effects" --> BAE
        BAE -- "2. Returns damage\n(No visual changes)" --> CS
        CS -- "3. Appends results to turn_log" --> CS
    end

    subgraph Playback_Phase [Loud Playback Phase (Visuals)]
        direction TB
        BAnim[BattleAnimator.gd]
        AReg[AnimationRegistry]
        CS -- "4. Returns Array[CombatEvent]" --> BAnim
        BAnim -- "5. Loops through events\nawait anim.execute()" --> AReg
    end
```

## The Precedence Engine: Ability Priority Tiers

When multiple abilities trigger simultaneously, we need a deterministic order of execution. If a unit takes fatal damage, does a "Guardian Intercept" save them before the "On Death" triggers fire? We solve this using a priority tier system embedded in every ability definition.

### 1. `AbilityDefinition.gd` Priority Tiers
*File: `scripts/AbilityDefinition.gd`*

Notice how the `priority` property defines the mechanical precedence of different ability types, ensuring defensive interceptors always fire before counter-attacks or bonus actions.

```gdscript
## Execution priority. Higher numbers resolve first. Default 0 for all existing abilities.
## See scripts/Constants.gd for named constants (PRIORITY_*) and full reference.
## Default is 0 (PRIORITY_STANDARD).
## Quick Reference (from Constants.gd):
##  300: GUARDIAN_INTERCEPT (Damage interception)
##  210: TRINKET_SUMMON (Soul Echo resurrection)
##  100: RESILIENT_AURA (On-hurt buffs/heals)
##   50: COUNTER_ATTACK (Retaliation)
##   10: MODIFIERS (Defensive Stance, Shockwave)
##    0: STANDARD (Default for new abilities)
##  -50: BOSS_SUMMON (End-of-turn spawns)
## -100: EXTRA_ACTION (Grant extra turn)
var priority: int = 0
```

### 2. Priority Execution in `CombatSimulator.gd`
*File: `scripts/battle/CombatSimulator.gd`*

The simulator enforces this hierarchy in `process_reaction_queue()`.

```gdscript
func process_reaction_queue(battle_manager, death_tracking: Dictionary) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	
	while not _pending_reactions.is_empty():
		# Always re-sort as new reactions might have been added (e.g. on_death triggers)
		_pending_reactions.sort_custom(func(a, b): return a.priority > b.priority)
		var current_reaction = _pending_reactions.pop_front()
```
**Syntax Breakdown:**
- `sort_custom()`: A built-in array method that sorts elements based on a custom comparison function.
- `func(a, b): return a.priority > b.priority`: An anonymous inline lambda function. By returning `true` when `a > b`, we sort the array in **descending** order (highest priority executes first).
- **Dynamic Recalculation:** Because triggers can spawn *more* triggers mid-loop (e.g., an on_death trigger killing someone else), we re-sort the queue on every single iteration to ensure the highest priority is always executed next.

---

## Line-by-Line Mastery: The Silent Simulation

Let's look at how the math is calculated instantly.

### 3. `CombatSimulator.execute_combat_turn()`
*File: `scripts/battle/CombatSimulator.gd`*

This function processes every unit's action instantly without waiting for any animations to finish. 

```gdscript
func execute_combat_turn(battle_manager, death_tracking: Dictionary) -> Array[CombatEvent]:
	var turn_log: Array[CombatEvent] = []
	
	while not _actor_queue.is_empty():
		var current_actor: GachaBallInstance = _actor_queue.pop_front()
		_current_acting_unit = current_actor
		
		if not is_instance_valid(current_actor):
			continue
		
		if current_actor.current_hp <= 0:
			continue
		
		# Robust Turn Tracking: Snapshot slot/team BEFORE execution (in case unit dies/moves)
		_current_turn_slot_index = current_actor.location_slot_index
		_current_turn_is_player = battle_manager._is_player_unit(current_actor)
		
		# Enqueue attack for this actor
		battle_manager._enqueue_attack_for(current_actor)
		
		# Process all reactions (including on_kill triggers from the attack)
		turn_log.append_array(process_reaction_queue(battle_manager, death_tracking))
		
		# Check battle-over AFTER all reactions for this actor
		if battle_manager._is_battle_over():
			battle_manager._battle_over_deferred = true
			_actor_queue.clear()
			break
	
	# Final reaction drain - process remaining reactions after all actors
	turn_log.append_array(process_reaction_queue(battle_manager, death_tracking))
	
	# FINAL DEATH CHECK + FLUSH: Ensure any skipped deaths (e.g. from inline Thorns on last action)
	# are caught and released immediately.
	battle_manager._check_for_deaths_with_counter_delay(true, turn_log, death_tracking)
	battle_manager._process_completed_counter_deaths(turn_log, death_tracking)
	
	return turn_log
```

**Syntax Breakdown:**
- `Array[CombatEvent]`: Godot 4 strongly typed arrays. This ensures the array can only ever contain `CombatEvent` objects.
- `pop_front()`: Removes and returns the first element of the array. This is how we move down the queue.
- `append_array()`: Adds all elements from one array to the end of another. We use this to stitch the individual attack events into the master `turn_log`.

### 4. `BasicAttackEffect.execute()`
*File: `scripts/BasicAttackEffect.gd`*

When `_enqueue_attack_for` triggers an attack, the effect resolves mathematically. Notice how we explicitly avoid touching the UI if we are in simulation mode.

```gdscript
	# CRITICAL: During simulation, DO NOT modify state here.
	# BattleManager handles the application via apply_stat_delta().
	# Modifying it here would cause double damage (once here, once in BattleManager).
	if not is_simulation:
		battle_manager.apply_stat_delta(target_instance, "hp", -damage)

	# NOTE: on_hurt is triggered by BattleManager AFTER apply_stat_delta, not here.
	# This ensures condition checks like DAMAGE_WAS_NON_LETHAL see post-damage HP.
	
	# NOTE: on_kill is NOT triggered here - BattleManager handles kill tracking
	# at the per-actor level after all reactions complete. This ensures kills from
	# all sources (shockwave, counter, double strike, etc.) are properly attributed.

	# Inform UI and log systems (suppressed when simulating)
	if not is_simulation:
		SignalBus.battle_inventory_changed.emit()
		# NOTE: apply_stat_delta() already handles silent/loud logic per context

	return damage
```

---

## Line-by-Line Mastery: The Loud Playback & Sequential Overlaps

Once `execute_combat_turn()` returns the `turn_log`, the `BattleAnimator` takes over to play the visual tape. 

### 5. `BattleAnimator.play_turn()`
*File: `scripts/BattleAnimator.gd`*

```gdscript
func play_turn(events: Array[CombatEvent]) -> void:
	if events.is_empty():
		emit_signal("turn_animation_finished")
		return
	
	_dead_units.clear()
	
	# DECOUPLED: No instance rewinding needed
	# Views are initialized from snapshot in play_turn_sequence()
	# Events contain absolute values (old_hp,  new_hp) so views animate correctly
	# This is true presentation-only mode - no simulation mutation
	
	await _animate_events(events)
```

> ### Godot 4 Refactoring Guide: Signal Emission
> Notice the line `emit_signal("turn_animation_finished")` in the code above. This is the legacy string-based emission from Godot 3. In Godot 4, we define signals as actual objects, which prevents typos and improves code completion.
> 
> **Refactored Code:**
> ```gdscript
> 	if events.is_empty():
> 		turn_animation_finished.emit() # Modern direct-call syntax
> 		return
> ```

### 6. `BattleAnimator._animate_events()`
*File: `scripts/BattleAnimator.gd`*

This is where the magic happens. The animator loops through every event in the log, matches its type, and waits for the specific animation to complete before moving to the next frame of the "VCR". 

**Complex Sequencing:** Look specifically at the `CombatEvent.Type.DAMAGE` block. If a Guardian Intercept ability triggered earlier in the simulation, the damage happens, but the animation pauses and waits for the Guardian to leap back to its original position using `_pending_guardian_return` before proceeding to the next event in the log!

```gdscript
func _animate_events(events: Array[CombatEvent]) -> void:
	for event in events:
		SignalBus.log_animation_event.emit(event)
		
		# ... (Trinket and Pause logic abbreviated for clarity)
		
		match event.type:
			CombatEvent.Type.LOG_MESSAGE:
				pass

			CombatEvent.Type.DAMAGE:
				var anim = AnimationRegistry.get_animation("damage")
				if anim:
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Damage animation not found in registry!")
				
				if not _pending_guardian_return.is_empty():
					var guardian_view = _visual_registry.get(_pending_guardian_return)
					if is_instance_valid(guardian_view) and guardian_view.has_method("animate_leap_return"):
						await guardian_view.animate_leap_return()
					_pending_guardian_return = ""

			CombatEvent.Type.HEAL:
				var anim = AnimationRegistry.get_animation("heal")
				if anim:
					Audio.play_sfx("combat_heal")
					await anim.execute(self, event.target_uuids, event.visual_payload)
				else:
					push_error("[BattleAnimator] Heal animation not found in registry!")

		# ... (Other event types handled similarly)
		
		await get_tree().process_frame
	
	_is_paused = false
	_step_advance_requested = false
	
	emit_signal("turn_animation_finished")
```

**Syntax Breakdown:**
- `match`: Godot's version of a `switch` statement, but more powerful. It matches the `event.type` enum against the possible `CombatEvent.Type` values.
- `await`: Yields execution of this function until the awaited signal (in this case, `anim.execute()`) finishes. This is what creates the "sequential" playback.
- `await get_tree().process_frame`: Ensures we wait exactly one engine frame between processing events, preventing visual stuttering and allowing the Godot engine to catch up and redraw the screen.
