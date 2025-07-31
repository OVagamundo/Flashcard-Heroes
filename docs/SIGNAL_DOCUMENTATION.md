# Signal Documentation

## Overview

This document provides comprehensive documentation for all signals used in Flashcard Heroes. The SignalBus singleton serves as the central hub for all game communication, replacing the previous EventBus system with better organization and documentation.

## Signal Categories

### 1. Battle System Signals

#### `battle_start_requested(encounter_def: EncounterDefinition)`
- **Purpose**: Initiates a new battle with the specified encounter
- **Emitter**: GameManager, PathChoice
- **Listeners**: Main, BattleManager
- **Parameters**: 
  - `encounter_def`: The encounter definition containing enemy units and items

#### `battle_ended(results: Dictionary)`
- **Purpose**: Notifies that a battle has ended with results
- **Emitter**: BattleManager
- **Listeners**: GameManager, Main, EndBattlePopup
- **Parameters**:
  - `results`: Dictionary containing battle results (winner, rewards, etc.)

#### `unit_stats_changed(unit_uuid: String)`
- **Purpose**: Notifies that a unit's stats have changed
- **Emitter**: BattleManager, GachaBallInstance
- **Listeners**: UI components, BattleView
- **Parameters**:
  - `unit_uuid`: The UUID of the unit whose stats changed

#### `battle_inventory_changed`
- **Purpose**: Notifies that battle inventory has changed
- **Emitter**: BattleManager, InventoryManager
- **Listeners**: UI components, BattleView
- **Parameters**: None

#### `battle_log_event(message: String)`
- **Purpose**: Displays a message in the battle log
- **Emitter**: BattleManager, AbilityResolver
- **Listeners**: BattleLog
- **Parameters**:
  - `message`: The message to display

### 2. Inventory & Loadout Signals

#### `run_data_changed`
- **Purpose**: Notifies that run data has changed
- **Emitter**: GameManager, InventoryManager
- **Listeners**: UI components, Loadout
- **Parameters**: None

#### `gold_changed(new_amount: int)`
- **Purpose**: Notifies that gold amount has changed
- **Emitter**: GameManager
- **Listeners**: UI components, Shop
- **Parameters**:
  - `new_amount`: The new gold amount

#### `selection_changed(new_location: LocationIdentifier)`
- **Purpose**: Notifies that selection has changed
- **Emitter**: InteractionManager
- **Listeners**: UI components, Shop, Reward
- **Parameters**:
  - `new_location`: The newly selected location

#### `selection_clear_requested`
- **Purpose**: Requests that selection be cleared
- **Emitter**: UI components, GlobalInteractionRouter
- **Listeners**: InteractionManager
- **Parameters**: None

### 3. Shop System Signals

#### `shop_stock_refreshed(context: Dictionary)`
- **Purpose**: Refreshes shop stock display
- **Emitter**: GameManager
- **Listeners**: Shop
- **Parameters**:
  - `context`: Dictionary containing shop instances and reroll cost

#### `shop_purchase_requested(instance_uuid: String, cost: int)`
- **Purpose**: Requests a shop purchase
- **Emitter**: Shop
- **Listeners**: GameManager
- **Parameters**:
  - `instance_uuid`: The UUID of the item to purchase
  - `cost`: The cost of the item

#### `shop_reroll_requested`
- **Purpose**: Requests a shop reroll
- **Emitter**: Shop
- **Listeners**: GameManager
- **Parameters**: None

### 4. Reward System Signals

#### `reward_chosen(reward_data: Dictionary)`
- **Purpose**: Notifies that a reward has been chosen
- **Emitter**: Reward
- **Listeners**: GameManager
- **Parameters**:
  - `reward_data`: Dictionary containing reward type and data

### 5. Scene Management Signals

#### `path_choice_scene_requested`
- **Purpose**: Requests the path choice scene
- **Emitter**: Various UI components
- **Listeners**: Main
- **Parameters**: None

#### `shop_scene_requested(context: Dictionary)`
- **Purpose**: Requests the shop scene
- **Emitter**: GameManager
- **Listeners**: Main
- **Parameters**:
  - `context`: Shop context with instances and reroll cost

#### `battle_scene_requested(encounter_def: EncounterDefinition)`
- **Purpose**: Requests the battle scene
- **Emitter**: GameManager
- **Listeners**: Main
- **Parameters**:
  - `encounter_def`: The encounter to start

#### `rest_site_scene_requested`
- **Purpose**: Requests the rest site scene
- **Emitter**: GameManager
- **Listeners**: Main
- **Parameters**: None

#### `flashcard_minigame_requested(run_state: RunState, active_deck: Array[String])`
- **Purpose**: Requests the flashcard minigame scene
- **Emitter**: GameManager
- **Listeners**: Main
- **Parameters**:
  - `run_state`: The current run state
  - `active_deck`: The active deck IDs

### 6. Interaction System Signals

#### `interaction_context_received(context: InteractionContext)`
- **Purpose**: Receives an interaction context from UI components
- **Emitter**: UI components, GachaBallView, SlotView
- **Listeners**: GlobalInteractionRouter
- **Parameters**:
  - `context`: The interaction context

### 7. Window Management Signals

#### `inspection_windows_close_requested`
- **Purpose**: Requests that inspection windows be closed
- **Emitter**: GlobalInteractionRouter
- **Listeners**: WindowManager
- **Parameters**: None

#### `all_inspection_windows_close_requested`
- **Purpose**: Requests that all inspection windows be closed
- **Emitter**: GlobalInteractionRouter
- **Listeners**: WindowManager
- **Parameters**: None

### 8. Flashcard System Signals

#### `flashcard_minigame_ended(results: Dictionary)`
- **Purpose**: Notifies that flashcard minigame has ended
- **Emitter**: FlashcardMinigame
- **Listeners**: GameManager, FlashcardManager
- **Parameters**:
  - `results`: Dictionary containing minigame results

#### `flashcard_progress_updated(card_id: String, new_progress: FlashcardProgress)`
- **Purpose**: Notifies that flashcard progress has been updated
- **Emitter**: FlashcardManager
- **Listeners**: UI components, Database
- **Parameters**:
  - `card_id`: The card ID that was updated
  - `new_progress`: The updated progress

### 9. Debug & Development Signals

#### `debug_log(message: String, level: String)`
- **Purpose**: Logs debug messages
- **Emitter**: Various components
- **Listeners**: Debug system
- **Parameters**:
  - `message`: The debug message
  - `level`: The debug level (INFO, WARNING, ERROR)

#### `game_save_requested`
- **Purpose**: Requests game state save
- **Emitter**: UI components
- **Listeners**: Save system
- **Parameters**: None

#### `game_load_requested`
- **Purpose**: Requests game state load
- **Emitter**: UI components
- **Listeners**: Load system
- **Parameters**: None

## Signal Emission Patterns

### 1. Immediate Emission
Signals that should be emitted immediately when an event occurs:
- `unit_stats_changed`
- `battle_log_event`
- `selection_changed`
- `interaction_context_received`

### 2. Deferred Emission
Signals that should be emitted after processing is complete:
- `battle_ended`
- `run_data_changed`
- `shop_stock_refreshed`

### 3. Request-Based Emission
Signals that represent requests for actions:
- `battle_start_requested`
- `shop_purchase_requested`
- `selection_clear_requested`

## Best Practices

### 1. Signal Naming
- Use descriptive names that clearly indicate the event
- Use past tense for completed events
- Use present tense for requests

### 2. Parameter Documentation
- Always document parameter types and purposes
- Use consistent parameter naming across related signals
- Provide default values where appropriate

### 3. Emission Timing
- Emit signals at the appropriate time in the execution flow
- Avoid emitting signals during initialization unless necessary
- Ensure signals are emitted after all relevant state changes

### 4. Error Handling
- Use debug signals for error logging
- Ensure signals don't cause cascading failures
- Provide fallback behavior for missing listeners

## Migration from EventBus

The SignalBus replaces the previous EventBus system with the following improvements:

1. **Better Organization**: Signals are categorized by system
2. **Comprehensive Documentation**: All signals have detailed documentation
3. **Type Safety**: Parameter types are clearly defined
4. **Emission Patterns**: Clear guidelines for when and how to emit signals
5. **Error Handling**: Better error handling and debugging support

## Usage Examples

### Connecting to Signals
```gdscript
# Connect to a signal
SignalBus.battle_ended.connect(_on_battle_ended)

# Disconnect from a signal
SignalBus.battle_ended.disconnect(_on_battle_ended)
```

### Emitting Signals
```gdscript
# Emit a signal with parameters
SignalBus.unit_stats_changed.emit(unit_uuid)

# Emit a signal without parameters
SignalBus.run_data_changed.emit()
```

### Signal Handler
```gdscript
func _on_battle_ended(results: Dictionary):
    print("Battle ended with results: ", results)
    # Handle battle end logic
``` 