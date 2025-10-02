Combat System
The combat loop is orchestrated by scripts/BattleManager.gd. It uses a priority-driven, "Simulate Full Turn, Then Present" model to ensure deterministic, visually coherent outcomes.
Phases & Flow
TURN START: At the very beginning of each team's turn, before any other actions, the manager emits the global on_turn_start trigger via AbilityResolver.process_trigger().
MANAGEMENT -> COMBAT: When the player ends the MANAGEMENT phase by pressing the "End Turn" button (_on_end_turn_requested), the system:
Switches to the COMBAT phase via _change_phase(Phases.COMBAT).
Makes a deferred call to _resolve_combat_phase(), which handles the entire turn's simulation and subsequent presentation.
END OF TURN: After all combat animations for the turn are finished, the _on_turn_animation_finished() callback triggers _trigger_turn_end_abilities() for all units and then transitions to the next turn's START_OF_TURN phase.
Priority-Driven Combat Resolution & Full-Turn Simulation
The _resolve_combat_phase function executes the core combat logic. It simulates the entire turn's actions and reactions first, then hands off a complete event log to the BattleAnimator for presentation.
Full Simulation:
Actor Queue: An _actor_queue is populated with all living units to determine the acting order for the turn.
HP Snapshot: Before simulation begins, a snapshot of every unit's current HP is saved. This is used later by the animator to create the illusion of incremental damage.
Actor Loop: The system iterates through the _actor_queue. For each actor, it enqueues their initial actions (e.g., a basic attack and any on_attack abilities) into a _pending_reactions queue.
Reaction Loop: A nested loop begins that continues as long as there are pending reactions. In every iteration, this queue is re-sorted by priority (highest first). The highest-priority EffectRequest is removed and simulated silently (updating data but not the UI).
Chaining: If the simulated effect triggers new reactive abilities (like an on_hurt effect), those new EffectRequests are added to the _pending_reactions queue. The loop continues, always re-sorting and executing the new highest-priority action until the queue is empty.
Event Collection: The outcome of every simulated effect (damage, healing, death, log messages) is recorded as a CombatEvent. These are collected into a single, comprehensive list for the entire turn.
Presentation Phase:
Handoff: After the simulation for all actors is complete, the single list of all CombatEvents is handed off to the BattleAnimator via _animator.play_turn().
UI Reset: The animator's first action is to use the hp_snapshot to silently reset the health of all units in the UI.
Sequential Replay: The animator then iterates through the CombatEvent list one by one. For each event, it triggers the appropriate visual effect (a bump, a flash, a death fade), applies the corresponding HP change, and waits for that animation to complete before proceeding to the next event in the list.
Lineups & Action Order
Containers: BATTLE_CONTAINER_TAGS.PLAYER_LINEUP and BATTLE_CONTAINER_TAGS.ENEMY_LINEUP.
Action Order Goal: Player units attack from left to right (index 0 -> 5). Enemy units attack from right to left (index 5 -> 0).
Implementation: _populate_actor_queue() first appends player units in order, then appends enemy units in reverse order. Since the combat loop processes this queue from the front (pop_front()), this FIFO (First-In, First-Out) processing achieves the desired visual sequence.
Enqueuing Attacks
Basic Attack: For each attacker, the system first triggers on_attack via the AbilityResolver. It then manually enqueues a default basic_attack with a neutral priority of 0.
Request Shape: EffectRequest.new(source_uuid, ability_id, effect_definition, [target_uuid], trigger_context, priority)
Ability Triggers: on_attack abilities may produce additional EffectRequests with varying priorities, which are added to the _pending_reactions queue to be sorted and simulated.
Target Selection
Helper: BattleManager._get_frontmost_target(attacker_is_player: bool).
It collects living targets in the opposing lineup, sorts them by slot index (ascending), then returns:
Player Attacker: The unit with the lowest index (visually the leftmost enemy).
Enemy Attacker: The unit with the highest index (visually the rightmost player unit).
Retargeting: During simulation, if an effect's primary target is already dead, the BasicAttackEffect will automatically retarget to the new frontmost enemy.
Counter-Attacks & Loop Prevention
Lethal Counters: on_hurt abilities (e.g., counter-attacks) can trigger even if the damaged unit is at or below 0 HP. Death processing for such units is deferred until after their counter-attack resolves, ensuring the visual order: incoming damage -> counter-attack -> defender death.
Per-Attacker Limit: To prevent infinite "ping-pong" counters, BattleManager enforces a per-attacker counter limit. A unit may counter-attack each distinct attacker at most once per turn. This is managed via:
has_counter_attacked(unit_uuid, attacker_uuid) -> bool
mark_counter_attack(unit_uuid, attacker_uuid)
The tracking dictionary is cleared at the START_OF_TURN.
Signals Used by the Animator
The BattleAnimator emits these signals, which are handled by the GachaBallViews to play animations. The animator waits for a corresponding completion signal before playing the next event.
SignalBus.unit_bump_attack(unit_uuid, dir: Vector2)
SignalBus.unit_flash_effect(unit_uuid, color: Color)
SignalBus.unit_death_fade(unit_uuid) -> followed by SignalBus.apply_deaths_requested([uuid])
SignalBus.battle_inventory_changed()