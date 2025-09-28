Inventory Manager
Version: 1.1
Status: Active
1. Purpose & Responsibility
The Inventory Manager is a stateless logic controller that executes all GachaBall manipulation actions. It acts as the "verb" system for the player's inventory and battle board. Its core responsibilities are:
Executing REQUEST_ACTION commands issued by the Global Interaction Router (GIR).
Determining the player's intent (Move, Swap, Equip, or Merge) based on the context of the action.
Handling ambiguity by requesting a ChoiceWindow when an action could be either a Merge or a Swap.
Performing all gameplay validation for the requested action.
Instructing the appropriate data owner (RunState or BattleManager) to perform the state change if the action is valid.
The Inventory Manager does not own any data. It queries the data owners for the current state, performs its logic, and commands the owners to mutate their state.
2. Commands Handled
The Inventory Manager listens for a single, powerful command routed from the GIR.
Command ID	Payload Structure	Internal Validation & Actions	Events Raised
REQUEST_ACTION	{ "source_uuid": String, "target_uuid": String }	1. Fetch Context: Retrieves instances for the source and target from the appropriate data owner. <br> 2. Determine Intent: Determines the potential action based on the priority: Merge > Equip > Swap/Move. <br> 3. Handle Ambiguity: If the action is determined to be a GachaBall on another GachaBall, it checks if a valid MergeRecipe exists. <br>      a. If YES: The action is ambiguous. The manager calls WindowManager.open_modal_window("ChoiceWindow", ...) and halts further processing. It will wait for a merge_choice_made signal. <br>      b. If NO: The action is unambiguously a Swap, Move, or Equip. It proceeds directly to validation. <br> 4. Validate & Execute: For unambiguous actions, it performs validation and instructs the data owner to update state.	inventory_action_invalid, instance_moved, instance_merged
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
6. Invariants
Stateless Operation: The manager must never store its own state between actions.
The Golden Rule: All state change instructions sent to data owners must be designed to be atomic, ensuring that both the DataContainer (index) and the GachaBallInstance (truth) are updated together.

## Reactive UI & Combat Signals (2025-09-27)

Overview
- Combat presentation is event-driven and paced by `scripts/BattleAnimator.gd`.
- Effects simulate first (no UI), then the animator emits UI signals per event and waits only for the animation duration of that event. There is no fixed global delay between events.

Signals Emitted by Animator
- `SignalBus.battle_log_event(text: String)`
  - Append `text` to the battle log view immediately on receipt.
- Combat animation signals used by views:
  - `SignalBus.unit_bump_attack(unit_uuid: String, direction: Vector2)`
  - `SignalBus.unit_flash_effect(unit_uuid: String, flash_color: Color)`
  - `SignalBus.unit_death_fade(unit_uuid: String)`
  - After death fades, animator emits `SignalBus.apply_deaths_requested([unit_uuid])` to request data removal.
- Inventory/UI synchronization:
  - `SignalBus.battle_inventory_changed()` updates lineup/bench grids and reflows as needed.

- Stacked effects note: For stacked resolutions (e.g., multiple heals from unit and items on a single `on_hurt`), multiple events will be replayed sequentially. Expect multiple back-to-back emissions. Do not aggregate; render each distinctly so players can count stacks.

Simulation Suppression
- During combat simulation, effects must not emit UI signals. They use silent setters (e.g., `set_current_hp_silent`) to avoid triggering UI indirectly.
- All reactive UI changes tied to combat are driven by the animator’s signals above.

View Guidance
- Subscribe to the animation signals at initialization time; unsubscribe on `_exit_tree()`.
  - On `unit_bump_attack`: play a short forward-and-back tween (~0.16s total). When finished, emit `SignalBus.unit_bump_finished(unit_uuid)`.
  - On `unit_flash_effect`: tween the view’s modulate to the flash color and back (~0.30s). When finished, emit `SignalBus.unit_flash_finished(unit_uuid)`.
  - On `unit_death_fade`: tween alpha to 0 (~0.28s). When finished, emit `SignalBus.unit_death_fade_finished(unit_uuid)`; removal is requested via `apply_deaths_requested`.
- On `battle_inventory_changed()`: rebuild only the affected container(s).
- Do not block the main thread inside signal handlers; the animator yields a frame after each emission to allow UI to render.
- Stacked effects: Render updates in arrival order (Unit → Items by slot → Trinkets). Animate each small HP change individually (brief pulse/flash); do not skip intermediate values even when updates arrive in quick succession.

Diagnostics
- Prefer visual indicators and lightweight counters over `print()` logging (global prints were removed). Consider optional, scoped debug labels within UI that can be toggled.

### Completion Signals (fully signal-based)
- Views should emit the following when their tweens complete:
  - `SignalBus.unit_bump_finished(unit_uuid: String)`
  - `SignalBus.unit_flash_finished(unit_uuid: String)`
  - `SignalBus.unit_death_fade_finished(unit_uuid: String)`
- **All events** await completion signals with timeout fallbacks for robustness.
- **Key insight**: Death animations work perfectly with signals because the unit emits the completion signal **before** being removed from UI via `apply_deaths_requested`.
- **Proper death tracking**: BattleManager ensures each unit gets exactly one DEATH event per battle using death event deduplication.

### Animation Durations Reference
This table defines the canonical animation timings used throughout the combat system. Update both the view implementations and the animator timeout fallbacks when changing these values.

| Animation Type | Duration (seconds) | Description | Implementation Location |
|---|---|---|---|
| **Bump Attack** | 0.16 | Forward-and-back position tween (0.08s out + 0.08s back) | `GachaBallView._on_unit_bump_attack()` |
| **Flash Effect** | 0.30 | Color modulation tween for damage/heal feedback | `GachaBallView._flash_unit_color()` |
| **Death Fade** | 0.28 | Alpha fade to 0 before unit removal | `GachaBallView._on_unit_death_fade()` |

- Ability and description text is stored in `localization/game.csv`.
- Use `(PWR)` as a placeholder where the UI should insert the current PWR value. The unit inspection replaces `(PWR)` with the unit’s live PWR and appends ` (PWR)` to make scaling explicit.
- Example keys used:
  - `ability.basic_attack.desc`
  - `ability.unit_tier1b_counter_on_hurt.desc`
  - `ability.unit_tier1a_passive_heal.desc`
  - `ability.item_tier2c_passive_heal.desc`
- Item stat lines use:
  - `item.effect.both`, `item.effect.hp`, `item.effect.pwr`

### Behavior Summary

- Units: Base description + Basic Attack (numeric + PWR hint) + all abilities (excluding Basic Attack) with dynamic `(PWR)` replacement and counter-attack numeric hint.
- Items: No flavor description; show only stat bonuses and abilities; abilities listed for both item and trinket definitions.