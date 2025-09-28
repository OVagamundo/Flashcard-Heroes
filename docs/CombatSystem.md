## Combat System
3. Handling Asynchronous User Choices
When an action is ambiguous, the manager relies on signals to resume its operation after the player has made a choice.
Listens for Signal: merge_choice_made(chosen_action: String, source_uuid: String, target_uuid: String)
Action on Signal:
Receives the signal from the ChoiceWindow.
Based on the chosen_action ("merge" or "swap"), it proceeds to the specific validation and execution logic for that action, as detailed in Section 4.
4. Inventory Actions
These are the final execution steps, performed only after the player's intent is unambiguous.
4.1 Merge
Trigger: The merge_choice_made signal is received with chosen_action = "merge".
Validation: Confirms the merge is still valid.
Execution: Instructs the data owner to:
Destroy the two ingredient instances.
Create the new result instance.
Transfer all equipped items from the ingredients to the new unit.
Place the result instance in the target's original slot.
4.2 Equip
Trigger: An ITEM is dropped onto a UNIT (unambiguous REQUEST_ACTION).
Validation:
Confirms the target unit has an empty item slot.
Confirms the source item is in a valid inventory location.
Execution: Instructs the data owner to update the item's location properties, moving it to the unit's equipped_item_uuids array.
4.3 Swap
Trigger: A GachaBall is dropped on another where no merge is possible, OR the merge_choice_made signal is received with chosen_action = "swap".
Validation:
Confirms both entities can legally occupy the other's starting position.
Execution: Instructs the data owner to exchange the location properties of the two instances.
4.4 Move
Trigger: A GachaBall is dropped onto an EMPTY_SLOT (unambiguous REQUEST_ACTION).
Validation:
Confirms the GachaBall can legally occupy the target slot.
Execution: Instructs the data owner to update the GachaBall's location properties to the new slot.
5. Public Signals
instance_moved(instance_uuid: String, from_location: LocationIdentifier, to_location: LocationIdentifier)
Fired after a successful Move or Swap action. For a swap, this is fired for each instance.
instance_merged(ingredient_uuids: Array[String], result_instance: GachaBallInstance)
Fired after a successful Merge action.
inventory_action_invalid(source_uuid: String, target_uuid: String, reason_key: String)
Fired when a requested action fails validation.

The combat loop is orchestrated by `scripts/BattleManager.gd`. Below are the operational details not covered elsewhere.

### Phases & Flow
- __TURN START__: At the very beginning of each team's turn, before any queue population, the manager emits the trinket/ability trigger:
  - `AbilityResolver.process_trigger("on_turn_start", { "team": "PLAYER" | "ENEMY" })`
- __MANAGEMENT -> COMBAT__: When `BattleManager._on_end_turn_requested()` fires during the `MANAGEMENT` phase, it:
  - Calls `_populate_effect_queue()` to enqueue all attacks for the turn.
  - Switches to `COMBAT` via `_change_phase(Phases.COMBAT)`.
  - Processes the queue via `_process_effect_queue()`.
- __Turn end__: After the queue drains, `_change_phase(Phases.MANAGEMENT)` is called and `_trigger_turn_end_abilities()` fires for all units.

### Lineups & Indices
- Containers: `BATTLE_CONTAINER_TAGS.PLAYER_LINEUP` and `BATTLE_CONTAINER_TAGS.ENEMY_LINEUP`.
- Retrieval: `get_instances_in_container(tag)` returns units sorted by their slot `index` ascending.
- Convention: Lower `index` means further left within the lineup container.

- __Enemy__: Iterated in ascending index and enqueued in that order. Because effects are processed LIFO, execution occurs right-to-left.
- __Player__: Iterated in reverse (descending index) when enqueuing. With LIFO processing, execution occurs left-to-right.
- Rationale: `_process_effect_queue()` uses `pop_back()`; reversing only the player enqueue order yields the intended visual sequence.

### Target Selection
- Helper: `BattleManager._get_frontmost_target(attacker_is_player: bool)`.
- It collects living targets in the opposing lineup, sorts by slot `index` ascending, then returns:
  - Player attacker: `living_targets[0]` (frontmost/leftmost).
  - Enemy attacker: `living_targets[-1]` (frontmost/rightmost).

### Effect Queue
- Storage: `_effect_queue: Array[EffectRequest]`.
- Processing: `_process_effect_queue()` guards re-entrancy with `_is_processing_effect` and loops while the queue is non-empty using `pop_back()` (LIFO).
- Validation at execution time:
  - Skips a request if the `source` is invalid or dead.
  - Retargets if the current target is invalid or dead by calling `_get_frontmost_target()` based on the attacker's side. If no valid target exists, the request is skipped.
- Execution: For each request, the effect is executed in simulation: `request.effect_definition.execute(source_uuid, exec_targets, self, sim_ctx)` where `sim_ctx.is_simulation = true`. This updates data silently and returns any result payload (e.g., damage) used to build `CombatEvent`s.
- Pacing: `scripts/BattleAnimator.gd` replays the collected `CombatEvent`s for the request using animation-driven timing. There is no global fixed delay between events. Each event's animation duration determines pacing:
  - DAMAGE: attacker bump (~0.16s) then target flash (~0.30s)
  - HEAL: target flash (~0.30s)
  - DEATH: death fade (~0.28s) followed by `apply_deaths_requested`
  - INVENTORY_SYNC/LOG_MESSAGE: instant (frame-yield only)
  If the animator is missing, the manager falls back to timers that match the same per-event durations.

### Animator & Event Replay (2025-09-27)
- Simulation vs. Presentation: `BattleManager` simulates one request at a time, building an `Array[CombatEvent]` for just that action. It then calls and awaits `BattleAnimator.play_turn(events)` before moving to the next request.
  - `LOG_MESSAGE` `{ text: String }` → emits `SignalBus.battle_log_event(text)`
  - `DAMAGE` `{ target_uuids: Array[String], amount: int, source_uuid: String }` → emits `unit_flash_effect` and updates HP
  - `INVENTORY_SYNC` `{}` → emits `SignalBus.battle_inventory_changed()` (e.g., unit removal after death)
  - `DEATH` `{ target_uuids: Array[String] }` → emits `unit_death_fade` then `apply_deaths_requested`
- Animator Behavior (in `scripts/BattleAnimator.gd`):
  - For each event: emit the mapped UI signal(s), then await only that event's animation duration (see Pacing table above). Note: The animator awaits completion signals (`unit_flash_finished`, `unit_bump_finished`, `unit_death_fade_finished`) emitted by views when their tweens complete. Timeout fallbacks matching the animation durations provide robustness. Death animations work perfectly with signals because units emit completion signals before being removed via `apply_deaths_requested`.
- Deaths & Selective Deferral:
  - During simulation, `BattleManager` checks for lethal units after each effect resolution.
  - Units without lethal counter-attack capability immediately enqueue a `DEATH` event.
  - Units with lethal counter-attack capability have their `DEATH` deferred until after their counter-attack finishes. The manager tracks these UUIDs and emits their `DEATH` as soon as their counter actions complete, ensuring visual order: damage → counter → death.
- Phase Safety: `BattleManager._on_turn_animation_finished()` ignores intermediate animator signals while `_is_processing_effect` is true; phase advancement happens only after the effect queue fully drains.
### Enqueuing Attacks
- Basic Attack: `_populate_effect_queue()` resolves the `basic_attack` effect from `Database`. If missing, it falls back to `res://scripts/BasicAttackEffect.gd`.
- Request shape: `EffectRequest.new(source_uuid, ability_key, effect_definition, [target_uuid], trigger_context)`.
- Ability Triggers: For each attacker, the manager emits the `on_attack` trigger through `AbilityResolver.process_trigger("on_attack", context)`. Abilities may produce additional `EffectRequest`s via `BattleManager.enqueue_effect_request()`.

### Counter-Attacks & Loop Prevention
- Lethal Counters: `on_hurt` abilities (e.g., counter-attacks) can trigger even if the damaged unit is at or below 0 HP; death processing is deferred for such units until their counter resolves.
- Per-Attacker Limit: `BattleManager` enforces a per-attacker counter limit using `has_counter_attacked(source_uuid, attacker_uuid)` and `mark_counter_attack(...)`. A unit may counter each distinct attacker once per turn. The tracking dictionary is cleared at `START_OF_TURN`.

### Signals used by the Animator
- `SignalBus.unit_bump_attack(unit_uuid, dir: Vector2)`
- `SignalBus.unit_flash_effect(unit_uuid, color: Color)`
- `SignalBus.unit_death_fade(unit_uuid)` → followed by `SignalBus.apply_deaths_requested([uuid])`
- `SignalBus.battle_inventory_changed()`

6. Invariants
Stateless Operation: The manager must never store its own state between actions.
The Golden Rule: All state change instructions sent to data owners must be designed to be atomic, ensuring that both the DataContainer (index) and the GachaBallInstance (truth) are updated together.