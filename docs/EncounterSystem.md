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

## Encounter System (Schema Addendum)

This section documents the EncounterDefinition addition needed for enemy trinkets.

### EncounterDefinition (additions)

- `enemy_trinket_ids: Array[StringName] = []`
  - IDs must exist in `Database.trinkets` (loaded from `res://resources/trinkets/`).
  - Duplicates by definition should be avoided; the battle setup deduplicates by definition ID.
  - Player-exclusive trinkets (tags/flags like `is_player_exclusive` or legacy aliases) are ignored on load for enemies.

### Battle Setup Integration

- During battle setup, `BattleManager._setup_enemy_trinkets_from_encounter(enc)` reads `enc.enemy_trinket_ids` and builds the in-battle enemy trinket list.
- No generator-side auto-injection: enemy trinkets come strictly from the `EncounterDefinition` data.

### Testing Notes

- For deterministic tests, specify `enemy_trinket_ids` directly on the test `EncounterDefinition` resource to validate enemy trinket behaviors.

## Encounter Generation Algorithm (V9.2)

The `EncounterGenerator` uses a "Constrained Random Build" algorithm with a robust gap-filling step to generate dynamic enemy teams.

### Algorithm Phases

1.  **Setup & Pooling:**
    *   Loads all non-hero GachaBallDefinitions.
    *   Separates them into `available_units` and `available_items`, sorted by cost.

2.  **Mandatory Spend:**
    *   Ensures at least 50% of the budget is spent on units to prevent item-heavy, unit-light encounters.

3.  **Flexible Spending:**
    *   Iteratively buys random affordable units or items until the budget is nearly full.
    *   Respects unit caps (max 6) and item slot limits.

4.  **Gap Filling (Robustness):**
    *   If budget remains, explicitly searches for "filler" units or items that fit the remaining budget exactly or closely.
    *   Prioritizes expensive fillers first to maximize efficiency.

5.  **Fallback Mechanism:**
    *   If generation fails or produces an invalid encounter, a `_create_fallback_encounter` method is called.
    *   This method safely looks up a valid Tier 1 unit (e.g., via Database query) rather than relying on hardcoded IDs, ensuring playability even with data changes.