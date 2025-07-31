Flashcard Heroes - Technical Design Document (V7.0 - Global Interaction Router update)

<!-- TOC -->
- [Part 1: Core Architecture & Principles](#part-1-core-architecture--principles)
- [Part 2: Data Schemas & Structures](#part-2-data-schemas--structures)
- [Part 3: Manager & System Responsibilities](#part-3-manager--system-responsibilities)
- [Part 4: Presentation Layer - Global Interaction Router](#part-4-presentation-layer--ui---the-global-interaction-router-architecture-rewritten)
- [Part 5: Game Flows](#part-5-game-flows)
- [Part 6: Localization & Sequence Diagrams](#part-6-localization--sequence-diagrams)
- [Part 7: Event-Driven Ability System Architecture](#part-7-event-driven-ability-system-architecture)
- [Part 8: Dynamic Encounter Generation System](#part-8-dynamic-encounter-generation-system)
- [Part 9: Flashcard System & Resource Generation](#part-9-flashcard-system--resource-generation)
- [Part 10: Pre-Run Setup & Data Pipeline](#part-10-pre-run-setup--data-pipeline)
<!-- /TOC -->
Part 1: Core Architecture & Principles
### 1.1 Architectural Principles
The game's logic is built upon a definitive **Hybrid Architecture** to guarantee data integrity while maintaining performance. This architecture is not optional; it is the required implementation pattern for all game state management. It consists of three pillars:

1.  **The Instance is the Source of Truth:** The `GachaBallInstance` resource is the single, undeniable source of truth for all of its own data, including its stats, status, and location (`location_container_tag`, `location_slot_index`, `equipped_on_uuid`). There are no other sources of truth. Caching this data in managers is strictly forbidden.

2.  **The Container is a Performant Index:** `DataContainer` objects (e.g., `FixedArrayContainer`) are used by managers (`RunState`, `BattleManager`) to provide fast, location-based lookups. These containers hold only UUIDs and act as a disposable index into the master instance dictionary. They are not a source of truth for any data besides the ordering of UUIDs in a location. If a container's index were to become corrupted, it could be rebuilt from the instance data, ensuring the game's state is never permanently lost.

3.  **Managers are Authoritative Operators:** Managers like `InventoryManager` contain the stateless logic (the "verbs") that operates on the data. They are responsible for correctly executing the **Golden Rule of State Synchronization**: any operation that moves an instance *must* update both the `DataContainer` (the index) and the `GachaBallInstance`'s properties (the truth) in a single, atomic operation.

4.  **Inversion of Control for Transient Dependencies:** To prevent circular preload dependencies, transient objects (like `BattleManager`) must register themselves with persistent objects (like `GameManager`) rather than persistent objects searching for transient objects. This follows the principle that persistent Autoload singletons should not query the scene tree during preload validation, as this can create unresolvable dependency loops.

### 1.2 Directory Structure
res://
├── assets/
├── resources/
│   ├── units/, items/, abilities/, recipes/
├── scenes/
└── scripts/
├── localization.csv
Use code with caution.
## Part 2: Data Schemas & Structures
### 2.1 Core Data Resources
**RunState.gd**: Resource, class_name RunState. The persistent state for an entire run.
*   **Properties:**
    *   `gold: int` - The player's current gold count.
    *   `day: int` - The current day of the run.
    *   `run_instances: Dictionary[String, GachaBallInstance]` - The master dictionary of all permanent instances for the run.
    *   `flashcard_progress: Dictionary[StringName, FlashcardProgress]` - Master dictionary of progress for every card in the loaded deck.
    *   `active_deck_ids: Array[StringName]` - The list of card IDs currently available in the mini-game.

**GachaBallDefinition.gd**: Resource, class_name GachaBallDefinition. The immutable template for a GachaBall.
*   **Properties:**
    *   `@export var id: StringName` - Unique identifier.
    *   `@export var display_name_key: String` - Localization key.
    *   `@export var description_key: String` - Localization key.
    *   `@export var icon: Texture2D` - Display icon.
    *   `@export var tags: Array[StringName]` - Tags like "hero", "unit".
    *   `@export var tier: int` - Power level (0-3).
    *   `@export var cost: int` - Gold cost for shops and encounter generation.
    *   `@export var category: StringName` - Must be "UNIT" or "ITEM".
    *   `@export var item_slot_count: int` - For "UNIT" category.
    *   `@export var base_hp: int` - For "UNIT" category.
    *   `@export var base_pwr: int` - For "UNIT" category.
    *   `@export var bonus_hp: int` - For "ITEM" category.
    *   `@export var bonus_pwr: int` - For "ITEM" category.
    *   `@export var ability_definitions: Array[AbilityDefinition]`

**GachaBallInstance.gd**: Resource, class_name GachaBallInstance. A unique, mutable instance of a GachaBall. This resource is the single source of truth for all of its own data.
*   **Core Properties:** 
    - `definition_id: StringName` - Reference to the definition this instance is based on
    - `ball_uuid: String` - Unique identifier for this instance
    - `origin_uuid: String` - UUID of the instance this was copied from (if applicable)
    - `current_hp: int` - Current health points
    - `current_pwr: int` - Current power value

*   **Location Properties (The Single Source of Truth):** 
    - `location_container_tag: StringName` - The container tag when not equipped
    - `location_slot_index: int` - The slot index when not equipped
    - `equipped_on_uuid: String` - UUID of the unit this item is equipped on (empty if not equipped)
    - `equipped_slot_index: int` - The slot index on the unit where this item is equipped (-1 if not equipped)
    - `equipped_item_uuids: Array[String]` - For units: array of UUIDs of equipped items (empty strings for empty slots)

*   **Status Effect Properties:**
    - `status_effects: Dictionary[StringName, int]` - Stores active status effects and their stacks (e.g., {"poison": 5, "strength": 2}).
    - `temporary_multipliers: Dictionary[StringName, float]` - Stores temporary multiplicative modifiers from abilities (e.g., {"rage_ability": 1.5}). This dictionary is cleared at the end of each turn.

*   **Methods:** 
    - `initialize(def: GachaBallInstance)` - Initialize a new instance based on a definition
    - `add_tag(tag: StringName)`, `remove_tag(tag: StringName)`, `has_tag(tag: StringName) -> bool` - Tag management
    - `create_battle_copy() -> GachaBallInstance` - Create a battle-specific copy of this instance
    - `get_location() -> LocationIdentifier` - Returns a LocationIdentifier representing the instance's current location
    - `get_current_pwr() -> int` - Calculates and returns the final, effective Power
    - `get_current_hp() -> int` - Calculates and returns the final, effective Health

**MergeRecipe.gd**: Resource, class_name MergeRecipe.
*   **Properties:**
    - `@export var id: StringName` - Unique recipe identifier
    - `@export var ingredient_a_id: StringName` - First ingredient definition ID
    - `@export var ingredient_b_id: StringName` - Second ingredient definition ID
    - `@export var result_id: StringName` - Resulting definition ID

**FlashcardDefinition.gd**: Resource, class_name `FlashcardDefinition`. An in-memory resource created from a JSON deck file.
*   **Properties:** 
    - `id: StringName` - Unique identifier
    - `question: String` - The flashcard question text
    - `answer: String` - The flashcard answer text
    - `explanation: String` - Detailed explanation (optional)

**FlashcardProgress.gd**: Resource, class_name `FlashcardProgress`. Tracks run-specific progress for a single flashcard.
*   **Properties:**
    - `definition_id: StringName` - Reference to the FlashcardDefinition
    - `mastery_level: int` - Current mastery level (0-5)
    - `last_review_time: int` - Last time this card was reviewed

**EffectRequest.gd**: Resource, class_name EffectRequest. A request to execute an ability, placed on the effect queue.
*   **Properties:**
    - `source_uuid: String` - UUID of the source instance
    - `ability_id: StringName` - ID of the ability being executed
    - `trigger_context: Dictionary` - Additional context about what triggered this effect

**AbilityDefinition.gd & EffectDefinition.gd**: Define abilities and their executable effects.

### 2.2 Location Container Tags (location_container_tag)

These StringName values define all possible logical locations for a GachaBallInstance. They are used in the `location_container_tag` property of `GachaBallInstance` and in the `container` field of `LocationIdentifier`.

#### Run State Locations
*   `RunInventoryT1`, `RunInventoryT2`, `RunInventoryT3`: Tiered inventory containers for units and items during the run
*   `PlayerLineup`: Active units in the player's battle formation
*   `PlayerBench`: Reserve units not currently in the lineup
*   `ItemInventory`: General storage for items not currently equipped

#### Battle State Locations
*   `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`: Battle-specific tiered inventory
*   `EnemyLineup`: Enemy units in the current battle
*   `DiscardPile`: Contains units and items that have been used or defeated in battle

#### Special Location
*   `equipped_item` - A conceptual location indicating an item is equipped on a unit. This is used in the `LocationIdentifier` but is never stored directly in `location_container_tag`.

#### Location Resolution Rules
1.  **Equipped Items**: If `equipped_on_uuid` is set, the item is considered to be in the special "equipped_item" container on the parent unit.
    - `LocationIdentifier` will have:
      - `container = "equipped_item"`
      - `unit_uuid` = the UUID of the parent unit
      - `index` = the equipped slot index on the unit

2.  **Unequipped Items**: If `equipped_on_uuid` is empty, the item is in the container specified by `location_container_tag` at `location_slot_index`.
    - `LocationIdentifier` will have:
      - `container` = the value of `location_container_tag`
      - `unit_uuid` = empty string
      - `index` = the value of `location_slot_index`

**Important**: Always use `GachaBallInstance.get_location()` to get the current location of an instance. This method encapsulates the logic above and ensures consistent behavior throughout the codebase.

### 2.3 Data Containers
To solve the performance and complexity issues of querying scattered instance data, the architecture uses a layer of `DataContainer` objects to act as a fast, location-based index. These containers provide O(1) lookup time for instances by their location, while maintaining the single source of truth in the `GachaBallInstance` objects themselves.

#### Core Container Classes

**`DataContainer.gd`** (Abstract Base Class)
*   **Purpose**: Defines the common interface for all container implementations
*   **Key Methods**:
    - `get_uuid(index: int) -> String` - Returns the UUID at the specified index
    - `set_uuid(index: int, uuid: String) -> void` - Sets the UUID at the specified index
    - `find_first_empty_slot() -> int` - Returns the first available slot index, or -1 if full
    - `is_valid_index(index: int) -> bool` - Checks if an index is within bounds
    - `get_size() -> int` - Returns the current capacity of the container
    - `is_empty() -> bool` - Returns true if the container has no items

**`FixedArrayContainer.gd`**
*   **Purpose**: Implements a fixed-size array container
*   **Use Cases**: Player/enemy lineups, benches, and other collections with a fixed number of slots
*   **Implementation**:
    - Backed by a fixed-size array
    - Throws an error if attempting to exceed capacity
    - Optimized for fast random access

**`GrowableGridContainer.gd`**
*   **Purpose**: Implements a container that can expand when full
*   **Use Cases**: Tiered inventories, discard piles, and other collections that need to grow
*   **Implementation**:
    - Starts with an initial capacity (see Initial Size Rule)
    - Automatically expands by a configured amount when full
    - Maintains a free list for efficient slot reuse

#### Initial Size Rule
To ensure a consistent player experience and optimal performance, all tiered inventory containers (RunInventoryT* and BattleInventoryT*) must be instantiated with an initial size of 16. This provides a good balance between memory usage and performance for the expected number of items.

#### Container Management
Both `RunState` and `BattleManager` maintain an internal dictionary of these containers, keyed by container tag. This allows for efficient lookup of containers by their logical names (e.g., "PlayerLineup", "BattleInventoryT1").

**Example Usage**:
```gdscript
# Getting a container from RunState
var container = run_state.get_container("PlayerLineup")

# Checking if a slot is occupied
if container.is_valid_index(slot_index) and container.get_uuid(slot_index) != "":
    var instance = run_state.run_instances[container.get_uuid(slot_index)]
    # Do something with the instance
```

**Important**: While containers provide fast lookups, they should never be used to store or modify instance data directly. All modifications to instance state must go through the appropriate manager methods to maintain data consistency.

### 2.4 Game Loop Data Structures
To manage the meta-game loop and battle progression, the following data-driven resources are used:

**PathNodeDefinition.gd**: Resource, class_name PathNodeDefinition. Defines a single selectable node from a set of choices in the run's path.
*   **Properties:**
    - `node_type: StringName` - The primary type of the node. Must be one of:
      - `"BATTLE"`: Combat encounter with enemies
      - `"SHOP"`: Shop to purchase items/units
      - `"EVENT"`: Special game event or story moment
      - `"REST"`: Rest area to heal and upgrade
    - `subtype: StringName` - A variant of the node type:
      - For `BATTLE`: `"COMMON"`, `"ELITE"`, `"MINIBOSS"`, `"BOSS"`
      - For `SHOP`: `"REGULAR"`, `"SPECIAL"`
      - For `EVENT`: Event-specific identifier
      - For `REST`: `"CAMPFIRE"`, `"TOWN"`
    - `display_name_key: String` - Localization key for the node's display name
    - `description_key: String` - Localization key for the node's description
    - `icon: Texture2D` - Visual representation of the node on the path
    - `encounter_id: StringName` - For "BATTLE" nodes, references an EncounterDefinition
    - `rewards: Array[RewardDefinition]` - Potential rewards for completing this node
    - `difficulty: int` - Relative difficulty level (1-5)

**EncounterDefinition.gd**: Resource, class_name EncounterDefinition. Defines the composition and behavior of enemy teams.
*   **Properties:**
    - `id: StringName` - Unique identifier for this encounter
    - `display_name_key: String` - Localization key for the encounter's name
    - `enemy_placements: Array[Dictionary]` - Array of enemy unit placements with format:
      ```gdscript
      {
          "id": StringName,      # Enemy unit definition ID
          "position": int,       # Battlefield position (0-based)
          "level": int,          # Unit level
          "equipment": Array[    # Optional equipment for this unit
              {
                  "id": StringName,  # Item definition ID
                  "level": int       # Item level
              }
          ]
      }
      ```
    - `ai_behavior: StringName` - Default AI behavior for enemies
    - `environment: StringName` - Battlefield environment/theme
    - `background: Texture2D` - Background image for the battle
    - `music_track: StringName` - Music track to play during battle
    - `is_boss: bool` - Whether this is a boss encounter
    - `victory_rewards: Array[RewardDefinition]` - Guaranteed rewards for victory
    - `possible_rewards: Array[RewardDefinition]` - Possible additional rewards

**RewardDefinition.gd**: Resource, class_name RewardDefinition. Defines rewards that can be granted to the player.
*   **Properties:**
    - `type: StringName` - Type of reward ("GOLD", "ITEM", "UNIT", "CARD", "UPGRADE")
    - `amount: int` - Quantity or value of the reward
    - `item_id: StringName` - For ITEM/UNIT rewards, the definition ID
    - `rarity_weights: Dictionary` - For random rewards, the weights for each rarity
    - `min_tier: int` - Minimum tier for random rewards
    - `max_tier: int` - Maximum tier for random rewards

**BattleResult.gd**: Resource, class_name BattleResult. Contains the outcome of a battle.
*   **Properties:**
    - `victory: bool` - Whether the player won
    - `rounds: int` - Number of rounds taken
    - `player_units_lost: int` - Number of player units defeated
    - `enemy_units_defeated: int` - Number of enemy units defeated
    - `gold_earned: int` - Gold earned from the battle
    - `experience_gained: int` - Experience points gained
    - `drops: Array[StringName]` - Item/unit drops from the battle
    - `achievements: Array[StringName]` - Any achievements unlocked

## Part 3: Logic Layer & Managers
### 3.1 Shop Node Implementation
The Shop system allows players to purchase items and units using gold. The shop's inventory is generated based on the current run state and available resources.

**ShopManager.gd**: Singleton that manages all shop-related functionality.
*   **Properties:**
    - `current_shop_inventory: Array[ShopItem]` - Items/units currently available for purchase
    - `current_reroll_cost: int` - Cost to reroll the shop inventory
    - `purchase_modifier: float` - Multiplier for all shop prices (for difficulty modifiers)

*   **Key Methods:**
    - `initialize_shop(run_state: RunState) -> void` - Sets up the shop for the first time
    - `reroll_shop(run_state: RunState) -> bool` - Rerolls the shop inventory, returns success
    - `purchase_item(item_id: StringName, buyer: Node) -> bool` - Attempts to purchase an item
    - `get_affordable_items(gold: int) -> Array[ShopItem]` - Returns items the player can afford

**ShopItem.gd**: Resource representing an item/unit in the shop.
*   **Properties:**
    - `id: StringName` - Unique identifier
    - `item_type: StringName` - "UNIT" or "ITEM"
    - `definition_id: StringName` - References GachaBallDefinition
    - `price: int` - Cost in gold
    - `stock: int` - How many are available (0 for unlimited)
    - `is_on_sale: bool` - Whether this item is discounted

### 3.2 Signal Bus
The Signal Bus is a global event system that allows decoupled communication between game systems. While the `GlobalInteractionRouter` handles UI interactions, the Signal Bus is used for game-wide event notifications.

**SignalBus.gd**: Autoload singleton that defines and emits all game signals.

**Core Signals:**
- `game_state_changed(old_state: StringName, new_state: StringName)` - When game state changes
- `battle_started(encounter_id: StringName)` - When a battle begins
- `battle_ended(victory: bool, result: BattleResult)` - When a battle concludes
- `inventory_updated(container_tag: StringName)` - When items/units are moved/changed
- `gold_changed(old_amount: int, new_amount: int)` - When player's gold changes
- `day_advanced(new_day: int)` - When progressing to a new day
- `achievement_unlocked(achievement_id: StringName)` - When player earns an achievement

**Usage Example:**
```gdscript
# Connect to a signal
SignalBus.battle_started.connect(_on_battle_started)

# Emit a signal
SignalBus.gold_changed.emit(old_gold, new_gold)
```

**Important Note**: While the Signal Bus is powerful, prefer direct method calls within the same system and only use signals for cross-system communication to maintain code clarity and code reuse.

- **State Authority**: GameManager serves as the authority for the Shop's state during a node visit.
- **Data Flow**: 
  - On purchase: GameManager moves the selected GachaBallInstance from temporary storage to RunState.run_instances
  - Follows the Golden Rule of State Synchronization for all state changes
- **UI Responsibility**: Shop.tscn acts as a "dumb" view, only rendering state and emitting user intents

#### 2. Data Structures & State Management

**GameManager.gd - New Member Variables**:
```gdscript
# Temporary shop state
var _temporary_shop_master_dict: Dictionary  # Holds GachaBallInstances for current shop stock
var _temporary_shop_container: DataContainer  # FixedArrayContainer of size 3 for slot UUIDs
var _reroll_cost: int = 1  # Current cost to reroll, resets on new shop visit
```

#### 3. New Scenes & UI Components

**Shop.tscn (New Scene)**:
- **Structure**:
  - %ShopSlotsContainer (HBoxContainer): Contains three SlotView.tscn instances
  - Buy, Reroll, and Leave buttons as direct children of the VBoxContainer
  - Price labels container (HBoxContainer): Displays cost labels below each GachaBall

**Shop.gd**:
- **Responsibilities**:
  - Renders UI based on GameManager state
  - Connects to EventBus.selection_changed
  - Emits user intent signals (shop_purchase_requested, shop_reroll_requested)
  - Listens for shop_stock_refreshed to update view
  - Manages price label display and positioning
  - Handles global input for closing inspection windows on background clicks

#### 4. Signal & API Modifications

**New Signals in EventBus.gd**:
```gdscript
# Shop Flow
signal shop_scene_requested(context: Dictionary)  # Context: {instances: Array[GachaBallInstance], reroll_cost: int}
signal shop_purchase_requested(instance_uuid: String, cost: int)
signal shop_reroll_requested()
signal shop_stock_refreshed(context: Dictionary)  # Context: {instances: Array[GachaBallInstance], reroll_cost: int}
```

#### 5. Manager & System Responsibilities

**GameManager.gd**:
- **New Functions**:
  - `_enter_shop()`: Initializes shop state
  - `_generate_shop_stock()`: Creates 3 random GachaBallInstances
  - Signal handlers for shop-related events
- **Enhanced Functions**:
  - `get_instance_from_location()`: Extended to support `&"Shop"` container for inspection windows

**Main.gd/SceneManager.gd**:
- Loads and displays Shop.tscn on shop_scene_requested

**InteractionManager.gd**:
- Handles selection state within shop UI (reuses existing functionality)

#### 6. Key Logic Flows

**A. Entering a Shop**:
1. Player clicks "SHOP" node in PathChoice.tscn
2. GameManager initializes shop state and generates stock
3. UI is populated with available items and reroll cost
4. Price labels are displayed below each GachaBall

**B. Purchasing an Item**:
1. Player selects item and confirms purchase
2. GameManager validates and processes transaction
3. UI updates to reflect new inventory and empty slot
4. Price label is removed for the purchased item

**C. Rerolling Stock**:
1. Player pays to refresh shop stock
2. GameManager generates new items and updates reroll cost
3. UI refreshes to show new items with updated price labels

**D. Inspection and Background Interaction**:
1. Double-click on GachaBalls opens inspection windows (enabled by `&"Shop"` container support)
2. Clicking on background closes inspection windows
3. Price labels are positioned to not interfere with GachaBall interactions

#### 7. UI Enhancement Features

**Price Label System**:
- Dynamic price labels displayed below each GachaBall
- Labels show cost based on item tier
- Positioned in separate container to avoid interference with clickable areas
- Automatically updated when shop stock refreshes

**Global Input Handling**:
- Background clicks close inspection windows
- Maintains consistent UX with other game scenes
- Prevents ghost selection states

**Shop Container Support**:
- `&"Shop"` container recognized by location system
- Enables double-click inspection functionality
- Integrates with existing WindowManager and InteractionManager systems

### 3.2 Signal Bus (Updated)
All global signals are defined in `SignalBus.gd` to decouple systems. Key signals include:
- `inspection_requested(target_uuid: String, context_uuid: String = "")` - Emitted when a GachaBallInstance should be inspected.
  - `target_uuid`: The UUID of the instance being inspected.
  - `context_uuid`: An optional UUID of the instance providing the stats for calculation.
- `inspection_closed(uuid: String)` - Emitted when an inspection is closed.
- `instance_moved(instance_uuid: String, from_location: LocationIdentifier, to_location: LocationIdentifier)` - Emitted when an instance changes location.
- `instance_merged(ingredient_uuids: Array[String], result_instance: GachaBallInstance)` - Emitted when instances are merged.
- `draw_gacha_requested(tier_tag: StringName)` - Emitted when a gacha draw is requested.
- `inventory_action_requested(source_uuid: String, target_uuid: String, explicit_action: String = "")` - Emitted when an inventory action is requested.
- `display_discard_pile_requested` - Emitted when the discard pile should be displayed.
- `instance_data_changed(uuid: String)` - Emitted when an instance's data changes.
- `instance_location_changed(uuid: String)` - Emitted when an instance's location changes.
- `instance_created(uuid: String)` - Emitted when an instance is created.
- `instance_destroyed(uuid: String)` - Emitted when an instance is destroyed.
- `battle_state_changed(is_in_battle: bool)` - Emitted when the battle state changes.
- `gacha_tokens_changed(new_amount: int)` - Emitted when the gacha tokens change.
- `battle_victory_acknowledged` - Emitted by EndBattlePopup when the player clicks "Continue" after a victory.
- `reward_scene_requested(context: Dictionary)` - Emitted by GameManager to request the display of the reward screen. The context contains the generated reward choices.
- `node_selected(node_def: PathNodeDefinition)` - Emitted by the UI when the player chooses a path.
- `reward_chosen(reward_data: Dictionary)` - Emitted by the reward UI. The reward_data contains the chosen reward. The payload will be {"type": "gachaball", "instance_uuid": "..."} or {"type": "gold", "amount": ...}.
- `selection_changed(new_location: LocationIdentifier) - Emitted by InteractionManager when the selected view changes. UI scenes like Reward.tscn will listen to this to manage the state of their controls (e.g., enabling a confirm button).
- `results_acknowledged` - Emitted by ResultsPopup when the player clicks its confirm button.
### 3.2 Manager Roles

#### Core Game Managers
- `GameManager.gd`: Holds the master run_state. Orchestrates the meta-game loop, including run initialization from the Loadout scene, managing temporary reward/shop instances, and processing post-battle rewards. Maintains a direct reference to the active BattleManager to avoid circular preload dependencies.
- `Database.gd`: Loads all .tres resources and .json deck files on startup. Provides public methods to query all game data.
- `SceneManager.gd`: Handles scene transitions.

#### Gameplay Logic & State
- `BattleManager.gd`: This manager is implemented as a node within Battle.tscn and added to the battle_manager group. Its lifecycle is tied to the battle scene, ensuring all its state is automatically created and destroyed. This prevents state-leakage bugs. **It registers itself with GameManager when entering the scene tree and unregisters when exiting, allowing GameManager to maintain a direct reference to the active BattleManager. This eliminates the need for scene tree queries that can cause circular preload dependencies.**
- `FlashcardManager.gd`: Manages the flashcard mini-game UI, SRS logic, and reports results via signals.
- `InventoryManager.gd`: Stateless logic controller for all inventory actions.
- `MergeManager.gd`: Stateless helper for merge calculations.
- `AbilityResolver.gd`: Takes an EffectRequest and calls the appropriate EffectDefinition.execute() method.

#### UI & Presentation
- `WindowManager.gd`: The sole authority for the lifecycle of all modal and inspection windows. **Uses `load()` instead of `preload()` for scene resources to prevent circular preload dependencies.**
- `InteractionManager.gd`: UI state machine holding the source_uuid of the selected instance. It is the single authority for processing all gameplay-related clicks on views and slots. It contains the master logic for determining whether a click results in a selection, an action, or a deselection, based on the current state and context. View scripts (GachaBallView, SlotView) must not contain their own complex interaction logic; they must simply report clicks to this manager.
- `StatTooltipGenerator.gd`: A stateless utility service for creating formatted tooltip strings that break down a unit's stat calculations.

#### Utilities
- `UUIDUtils.gd`: Provides a `generate_uuid()` utility function.
- `AudioManager.gd`: Central controller for all sound effects and music.
- `SaveManager.gd`: Handles saving and loading game state.
3.3 The Definitive Hybrid Architecture: The "Why"
This architecture was chosen to solve the problems of data duplication and complex state management found in traditional container-based models. The original "pure" data-centric model, where all queries directly accessed the master instance dictionaries, was inefficient for common access patterns like finding empty slots or iterating through specific locations.

The true hybrid model combines three essential pillars:
1. The "single source of truth" on the instance data
2. The "performant index" in the DataContainers
3. The "contextual understanding" in the managers' relational queries

This gives us the debuggability of the former (data is never duplicated) while providing the necessary speed for a responsive UI through the DataContainer index layer. The DataContainers act as disposable, fast-access indices that can be rebuilt from the instance data when needed, but provide O(1) access to slots and locations.

This architecture prevents data duplication while providing the necessary speed for a responsive UI, ensuring that the game remains performant while maintaining data integrity and ease of debugging.

### 3.4 Circular Preload Dependency Prevention

**Critical Architectural Rule:** To prevent game crashes caused by circular preload dependencies, the following pattern must be strictly followed:

#### The Problem
When Autoload singletons (like `GameManager`) use `get_tree().get_first_node_in_group()` or similar scene tree queries during preload validation, they can create circular dependencies. For example:
1. `WindowManager` (Autoload) preloads scenes that depend on `GameManager`
2. `GameManager` (Autoload) queries the scene tree for `BattleManager`
3. This creates a dependency loop that fails during preload, causing crashes

#### The Solution: Inversion of Control
Instead of persistent objects searching for transient objects, transient objects must register themselves with persistent objects:

**Implementation Pattern:**
```gdscript
# In GameManager.gd (persistent Autoload)
var _active_battle_manager: BattleManager = null

func register_battle_manager(bm: BattleManager):
    _active_battle_manager = bm

func unregister_battle_manager():
    _active_battle_manager = null

# In BattleManager.gd (transient scene node)
func _ready():
    add_to_group("battle_manager")
    GameManager.register_battle_manager(self)

func _exit_tree():
    GameManager.unregister_battle_manager()
```

**Benefits:**
- Eliminates circular preload dependencies
- Improves performance by avoiding repeated scene tree searches
- Provides better architectural separation
- Maintains the same functionality as scene tree queries

**Rule:** All persistent Autoload singletons must use direct references rather than scene tree queries for accessing transient objects.

#### WindowManager Scene Loading Pattern
**Additional Rule:** When Autoload singletons need to preload scene resources, use `load()` instead of `preload()` to break circular dependencies:

```gdscript
# CORRECT: Use load() to prevent circular dependencies
var _window_scenes: Dictionary = {
    &"Inventory": load("res://scenes/InventoryWindow.tscn"),
    &"DiscardPile": load("res://scenes/DiscardPileWindow.tscn"),
    # ... other scenes
}

# INCORRECT: preload() can cause circular dependencies
var _window_scenes: Dictionary = {
    &"Inventory": preload("res://scenes/InventoryWindow.tscn"),
    &"DiscardPile": preload("res://scenes/DiscardPileWindow.tscn"),
    # ... other scenes
}
```

**Why:** `preload()` resolves dependencies during script parsing, which can create circular dependency loops. `load()` defers resolution until first access, breaking the dependency cycle.

### 3.5 The Golden Rule of State Synchronization
This rule is the fundamental contract of the hybrid architecture and must be adhered to by all game logic that modifies an instance's location.

**The Rule:** To move an instance, a two-step process is mandatory:
1.  **Update the Index:** The instance's UUID must be removed from the source `DataContainer` and added to the destination `DataContainer`.
2.  **Update the Truth:** The instance's own `location_container_tag` and `location_slot_index` properties must be updated to reflect its new location.

Failing to perform both steps will de-synchronize the game state (specifically, the performant index will not match the data truth) and is considered a critical bug. Caching location data in managers is strictly forbidden as it violates the principle of having a single source of truth.
### 3.6 Positional & Targeting Logic
This logic is implemented within BattleManager's relational query functions.

**Player Team (Left Side):** "Frontmost" corresponds to the unit with the highest location_slot_index (e.g., 5). "Backmost" is the lowest index (e.g., 0).

**Enemy Team (Right Side):** "Frontmost" corresponds to the unit with the lowest location_slot_index (e.g., 0). "Backmost" is the highest index (e.g., 5).

**Action Order:** The standard combat action order for both teams is back-to-front (index 5 down to 0).

### 3.7 The Effect Resolution Queue
This system, managed by BattleManager, governs the flow of combat. It uses a LIFO (Last-In, First-Out) stack to ensure that interruptions and reactions (like a "retaliate on hit" ability) are processed immediately after the event that caused them, creating an intuitive and predictable chain of events.
Population: When the COMBAT phase begins, BattleManager creates an EffectRequest for each unit's action and pushes it onto the _effect_queue stack.
Processing Loop: The BattleManager's _process function contains a loop that pops one request from the stack, awaits its resolution via the AbilityResolver, and then repeats until the queue is empty.
    *   The system must re-validate that the source unit is still alive (HP > 0) at the moment its action is popped from the queue. If the source is no longer alive, its action is skipped.
Chain Reactions: Any ability that triggers another effect creates a new EffectRequest and pushes it to the top of the stack, ensuring it is resolved next.

Part 4: Presentation Layer (UI) - The Global Interaction Router Architecture
The game's UI is built upon a definitive Intent-Based Interaction Architecture. This system is designed to be robust, scalable, and completely decoupled from the specifics of Godot's scene tree structure and input propagation quirks. It ensures that all user interactions are handled consistently and predictably.
4.1 Architectural Pillars
Views are Dumb Sensors: UI elements that can be clicked (GachaBallView, SlotView, RichTextLabel links, window backgrounds) have one primary responsibility: to sense a raw input event (like a click or double-click), package it with context, and report it. They contain no complex interaction logic themselves and are configured to stop event propagation once handled.
Context is Explicit Data: When a view reports an input, it packages a standardized data resource, the InteractionContext, which describes everything about the click: what was clicked, where it is, and the rules governing its area. This makes context explicit and removes any reliance on get_parent() or scene tree assumptions.
The Router is the Central Brain: A new singleton, GlobalInteractionRouter, is the single source of truth for interpreting user intent. It receives the InteractionContext from the clicked view, compares it to the current UI state (e.g., what is already selected, which windows are open), and determines the user's goal.
Execution is a Command Queue: The router's output is a "Command Queue"—an array of simple, atomic command objects (e.g., DESELECT, OPEN_WINDOW, REQUEST_ACTION). This chain of commands represents the complete, multi-step result of a single user click. Managers like WindowManager and InventoryManager become simple executors that process these commands.
4.2 Core Data Schema: InteractionContext.gd
This Resource is the lifeblood of the system. It is the standardized data packet sent with every interaction.
InteractionContext.gd: Resource, class_name InteractionContext.
source_view_instance_id: int: The instance ID of the Control node that was clicked, obtained via source_view.get_instance_id(). This allows any system to retrieve the node reference later using instance_from_id().
event_type: StringName: The type of input (&"SINGLE_CLICK", &"DOUBLE_CLICK").
location: LocationIdentifier: The game-logic location of the entity.
entity_uuid: String: The UUID of the GachaBallInstance represented, if any.
entity_type: StringName: The kind of thing clicked (e.g., &"UNIT", &"ITEM", &"EMPTY_SLOT", &"WINDOW_BACKGROUND", &"UI_LINK", &"GLOBAL_BACKGROUND").
interaction_mode: StringName: The TDD-defined interaction rules for this context (e.g., &"FULLY_INTERACTIVE", &"SELECTION_ONLY", &"INSPECTION_ONLY").
window_group_id: int: A unique ID for the chain of inspection windows this element belongs to (0 if on the main board).
4.3 Definitive Mouse Filter Strategy
To ensure unambiguous and reliable input handling, particularly within layered inspection windows, the following mouse_filter strategy is mandatory. This "Layered Catcher" pattern is designed to work seamlessly with the Global Interaction Router.
The Problem: A single click can be interpreted in multiple ways if input events are allowed to propagate through multiple UI layers. A click on an inspection window's background might incorrectly also register as a click on the battle scene behind it.
The Solution: The Layered Catcher Pattern
Every complex UI view (like an inspection window) is composed of three conceptual input layers:
The Container Layer (e.g., the root PanelContainer): Its role is to hold other elements and provide styling. It must be completely transparent to mouse input.
The Catcher Layer (e.g., an InternalBackground ColorRect): A single, large node that sits at the bottom of the visual hierarchy. Its role is to catch any input that is not caught by the Content Layer and stop it from propagating further.
The Content Layer (e.g., GachaBallView, Button, RichTextLabel): These are the interactive elements the user is meant to click on. They are responsible for handling their own input and stopping it.
Mandatory mouse_filter Settings:
Node Type	Role	mouse_filter Setting	Rationale
Root PanelContainer (of an inspection window)	Container	MOUSE_FILTER_IGNORE (2)	Must not interfere with input intended for its children or background.
InternalBackground ColorRect	Catcher	MOUSE_FILTER_STOP (1)	Catches all "missed" clicks within the window's bounds and prevents them from passing through to the scene behind it. Its _gui_input creates the WINDOW_BACKGROUND InteractionContext.
GachaBallView, SlotView, Button	Content	MOUSE_FILTER_STOP (1)	These are the primary interactive elements. They must handle their own input and stop the event from propagating to the Catcher Layer behind them.
4.4 The Definitive Guide to Player Interactions
This section is the single source of truth for the rules that the GlobalInteractionRouter must implement.
4.4.1 Core Terminology & Interaction Modes (interaction_mode)
&"FULLY_INTERACTIVE": Contexts where GachaBalls can be selected, moved, swapped, merged, and equipped. Double-clicking is required for inspection.
&"SELECTION_ONLY": Contexts where the only valid interaction is to change the current selection. All other actions are invalid. Double-clicking is required for inspection.
&"INSPECTION_ONLY": Contexts where GachaBalls cannot be moved or selected. A single-click is used for inspection.
4.4.2 Global Router Rules (Master Checklist)
[GR-1] Open on Request: The router must generate an OPEN_INSPECTION_WINDOW command when a valid inspection event occurs (determined by combining event_type and interaction_mode).
[GR-2] Clear Selection on Open: The command queue for opening any inspection window must begin with a DESELECT command.
[GR-3] Position Correctly: The OPEN_INSPECTION_WINDOW command must contain the anchor view's instance ID for the WindowManager to use.
[GR-4] Close on "True" Background Click: If the router receives a context with entity_type: &"GLOBAL_BACKGROUND", it must generate a CLOSE_ALL_INSPECTION_WINDOWS command.
[GR-5] Close on Invalid Action Click: If a selection is active and the router receives a click context that results in an invalid action, it must generate the command queue: [ {cmd: "CLOSE_ALL_INSPECTION_WINDOWS"}, {cmd: "DESELECT"} ].
[GR-6] Child Window Closure: If the router receives a click with entity_type: &"WINDOW_BACKGROUND", it must generate a CLOSE_CHILD_WINDOWS command for that window's group.
[GR-7] Same Item Deselection: If the router receives a click on the currently selected item (same source_view_instance_id), it must generate a DESELECT command.
[GR-8] Drag and Drop State Management: 
- Drag operations must clear any existing selection state when started
- After any drag operation (successful or failed), selection state must be cleared
- Drag operations bypass the GlobalInteractionRouter and go directly to InventoryManager
- After successful inventory actions (move, swap, equip, merge), selection state must be cleared

[GR-9] Robust State Management (Critical):
- Selection and drag states are mutually exclusive - both cannot be active simultaneously
- State transitions are atomic and protected by a transition lock to prevent race conditions
- Redundant clear_selection() calls are ignored to prevent signal emission conflicts
- Periodic state validation runs every frame to detect and correct inconsistencies
- GlobalInteractionRouter validates state before processing any interaction
- State validation failures trigger automatic cleanup and recovery
- **CRITICAL**: Both InteractionManager and GlobalInteractionRouter maintain selection state and must be synchronized
- All selection state changes must update both systems simultaneously
- State validation includes cross-system consistency checks
4.4.3 Interaction Rules by Context
1. The Battle Board (PlayerLineup, PlayerBench, ItemInventory):
interaction_mode: &"FULLY_INTERACTIVE".
A click on a GachaBallView while another is selected generates a REQUEST_ACTION command.
2. The UnitInspectionWindow Equipped Item Grid:
Player Unit: interaction_mode: &"FULLY_INTERACTIVE".
Enemy Unit: interaction_mode: &"INSPECTION_ONLY".
3. The Inventory Window ((Run/Battle)InventoryT<n>):
interaction_mode: &"FULLY_INTERACTIVE".
Router Rule: If the active selection's context and the new click's context both have an InventoryT container but the containers are not identical, the generated command queue is [ {cmd: "DESELECT"}, {cmd: "SELECT", ...} ].
4. Shop & Reward Scenes:
interaction_mode: &"SELECTION_ONLY".
Router Rule: If a selection is active and a new click is received in this mode, the command queue is [ {cmd: "DESELECT"}, {cmd: "SELECT", ...} ].
5. EnemyLineup Container:
interaction_mode: &"INSPECTION_ONLY".
4.4.4 Invalid Action Resolution Flow
If an inventory_action_requested signal is sent for an action that is not valid, InventoryManager will emit inventory_action_invalid. InteractionManager listens for this and resolves the invalid UI state by closing all inspection windows and clearing the selection, as per Rule [GR-5].
4.5 Advanced Window Group Navigation
The Global Interaction Router must handle complex navigation within an active inspection window group. The following rules govern interactions with parent windows when child windows are open, using the interaction_mode from the InteractionContext to determine the precise user intent.
The Principle: Clicks on elements within a parent window serve as commands to change the focus of the inspection, effectively re-directing or pruning the inspection "branch" from that parent.
Rule [GR-10] Re-Inspection from Parent (Context-Aware):
Scenario: A child window is open. The user clicks on an interactive element (e.g., another item) within the parent window.
User Intent: To switch inspection focus or select an item.
Router Logic:
The router first identifies the parent window of the clicked element.
It then checks the interaction_mode of the received InteractionContext.
If interaction_mode is &"INSPECTION_ONLY": The single-click is an inspection request.
Generated Command Queue:
CLOSE_CHILD_WINDOWS (for the identified parent window).
OPEN_INSPECTION_WINDOW (for the newly clicked element).
If interaction_mode is &"FULLY_INTERACTIVE": A single-click is a selection request, not an inspection request.
Generated Command Queue:
CLOSE_CHILD_WINDOWS (for the identified parent window).
SELECT (for the newly clicked element).
Outcome: The UI correctly distinguishes between a request to inspect and a request to select, based on the rules of the area that was clicked. The old child window is always closed, as the user's focus has definitively shifted.
Rule [GR-11] Navigational Clicks on Parent:
Scenario: A child window is open. The user clicks on a non-actionable element within the parent window, such as an EMPTY_SLOT or the window's background.
User Intent: To close the child and return focus to the parent.
Router Logic: The router identifies the parent window of the clicked element. A click on an EMPTY_SLOT in this context is treated identically to a click on a WINDOW_BACKGROUND.
Generated Command Queue:
CLOSE_CHILD_WINDOWS (for the identified parent window).
Outcome: The child window is closed, pruning the inspection branch back to the parent that was clicked.
4.6 UI Population Pattern: Persistent Slots
To ensure a stable, performant, and bug-free UI, views that display collections of items in a grid (such as InventoryWindow or DiscardPileWindow) must adhere to the "Persistent Slots" pattern.
The Problem to Avoid:
Constantly destroying (queue_free()) and recreating UI nodes for every data change is inefficient and leads to visual bugs, loss of state, and desynchronization between the view and the data model.
The Correct Pattern:
One-Time Initialization: When the window is first created, it should programmatically instantiate and add the required number of "slot" nodes (e.g., SlotView.tscn) to its GridContainer. These slot nodes are now persistent for the lifetime of the window.
Content Update on Refresh: When a UI refresh is required, the window must not destroy the persistent slot nodes. Instead, it should iterate through its existing slot nodes, clear any old content (e.g., a GachaBallView child), look up the corresponding data, and instantiate a new content view if necessary.
Context Configuration: During population, each view (SlotView, GachaBallView, etc.) must be initialized with the correct InteractionContext data (interaction_mode, entity_type, etc.) so it can report its context accurately to the GlobalInteractionRouter.

Part 5: Game Flows
### 5.1 In-Battle Instance Lifecycle
To ensure data integrity and prevent unnecessary object creation, the following rules govern how GachaBall instances are handled during a battle after the initial setup:

**No New Copies:** After the initial `battle_copy()` creation at the start of a battle, no further copies or clones of `GachaBall` instances are made. All subsequent operations manipulate the existing battle instances.

**Movement is a State Change:** "Moving" an instance (e.g., from bench to lineup, or inventory to discard) is achieved by changing the `location_container_tag` and `location_slot_index` properties on the instance itself, and updating the relevant `DataContainer` objects. The instance's `ball_uuid` remains the same for the duration of the battle.

**Item Salvage and Inheritance:** When a unit is defeated or used as a merge ingredient, its equipped items are not copied. The exact same item instances are transferred. Their `equipped_on_uuid` and `location` properties are updated to reflect their new state (either moved to the discard pile or re-equipped on a newly merged unit).

### 5.2 Battle Setup Flow
1.  `BattleManager` receives a generated `EncounterDefinition`.
2.  It creates `battle_copy()` instances from `run_state.run_instances` for all player units and items. It stores a map of permanent-to-battle UUIDs.
3.  It iterates through the new battle copies and remaps their `equipped_item_uuids` to the new battle-specific UUIDs.
4.  The Hero is a special case; the persistent `GachaBallInstance` from `RunState` is used directly in battle without being copied.
5.  It creates new instances for all enemies and their items as defined in the `EncounterDefinition`.
6.  It places all instances into the correct `DataContainer` indices according to their original locations or the encounter definition.

### 5.3 Gacha Draw Flow
BattleManager receives draw_gacha_requested(tier_tag).
It queries _battle_instances for instances with location_container_tag == "BATTLE_DRAW_POOL_[tier_tag]".
If a draw or merge action causes a tiered battle inventory pool to become empty, it is automatically and immediately replenished with all corresponding GachaBalls from the BATTLE_DISCARD_PILE. When a reshuffle occurs, any GachaBall instance being moved from the BATTLE_DISCARD_PILE to a BATTLE_DRAW_POOL must have its current_hp and current_pwr stats reset to the base_hp and base_pwr values from its GachaBallDefinition. This ensures a player never attempts to draw from a visibly empty pool if matching items exist in the discard pile.
It picks a random instance and changes its location properties to an available slot in BATTLE_PLAYER_BENCH or BATTLE_ITEM_INVENTORY.
It emits instance_location_changed(drawn_uuid).
### 5.4 Merge Flow
1.  `InventoryManager` receives `inventory_action_requested` for a merge.
2.  It instructs the appropriate data owner (`RunState` or `BattleManager`) to perform the following atomic operation:
    a. Create a new `result_instance` from the merge recipe.
    b. Update the `result_instance`'s location properties to place it in the correct destination container and slot. **Rule: If the merge occurs on the battle board (`PlayerLineup`, `PlayerBench`, `ItemInventory`) or in an equipped item slot, the result is placed in the target ingredient's original slot. The tier-up-to-new-inventory-pool logic only applies when merging within the `(Run/Battle)InventoryT<n>` containers.**
    c. Add the new instance's UUID to the master instance dictionary and the destination `DataContainer` (the index).
    d. For each ingredient, remove its UUID from its `DataContainer` and the master instance dictionary.
    e. For all inherited items, update their `equipped_on_uuid` property to point to the new `result_instance`.
3.  The data owner emits the necessary state change signals (`battle_inventory_changed` or `run_data_changed`).

### 5.6 Post-Battle Reward Flow

#### Design Rationale: Instance-Based Rewards
To ensure architectural consistency and maximum feature reuse, the reward system uses real GachaBallInstance objects instead of temporary representations. This approach treats the reward choice screen as a temporary inventory, allowing all existing systems (inspection, selection, tooltips) to function without special-case logic. When a choice is made, the selected instance is simply moved to the permanent RunState, while the unchosen instances are discarded. This maintains the "single source of truth" principle and creates a more robust and extensible system.

#### Authoritative Flow
1. **Victory & Acknowledgement**: The flow begins after the player acknowledges a battle victory, which emits `battle_victory_acknowledged`.

2. **Reward Instance Generation**: 
   - `GameManager` receives the signal, generates the temporary reward instances, and stores them in its `_temporary_reward_master_dict`.
   - The reward instances are created with proper location information in a temporary container.

3. **Display**: 
   - `GameManager` emits `reward_scene_requested`. 
   - The `Reward.tscn` scene is displayed. Its `GachaBallViews` and `SlotViews` are configured for a selection-only context (`is_interactive: false`). 
   - Double-click to inspect remains functional.

4. **Player Interaction**: 
   - The player interacts with the rewards. 
   - The UI follows the **Definitive Click Interaction Cycle** (Sec 4.3.3), allowing for seamless one-click selection changes.
   - The player can inspect rewards by double-clicking.

5. **Final Choice & State Change**: 
   - The player clicks either the `%ConfirmSelectionButton` or `%TakeGoldButton`.
   - The `Reward.gd` script emits the `reward_chosen` signal with the appropriate payload.
   - The script then changes the UI state: it hides the `Confirm` and `Gold` buttons and makes a new `%BackToPathButton` visible. 
   - The reward scene itself does not close yet.

6. **State Update & Cleanup**: 
   - `GameManager` receives `reward_chosen` and performs the final state modification:
     - It immediately calls `InteractionManager.clear_selection()` to prevent a stale state.
     - It adds the chosen GachaBall or gold to the `RunState`, correctly setting all location properties according to the **Golden Rule of State Synchronization**.
     - It emits `run_data_changed`.
     - It clears its internal temporary reward data (`_temporary_reward_master_dict`).

7. **Manual Scene Transition**: 
   - The player is now on the reward screen with their new item added to their inventory (visible if they open the inventory window). 
   - The screen shows the "Back to the Path" button.
   - When the player clicks `%BackToPathButton`, the `Reward.gd` script emits `path_choice_scene_requested`.
   - Immediately after emitting the signal, the `Reward.gd` script must call `queue_free()` on itself to ensure it is properly destroyed and removed from the scene tree.

8. **Loop Continuation**: 
   - `SceneManager` receives `path_choice_scene_requested` and displays the path choice content, completing the loop.

#### Key Implementation Details
- **Selection State Management**: The `InteractionManager` is cleared at critical points to prevent ghost selections.
- **UI State Transitions**: The reward scene remains active until the player explicitly chooses to return to the path, providing visual feedback that their choice was successful.
- **Memory Management**: All temporary reward instances are properly cleaned up after use.

7. **Loop Continuation**: After processing the reward, GameManager initiates the Path Choice & Encounter Flow (Section 5.5).

Part 6: Localization & Sequence Diagrams
6.1 Localization System
Key-Based System: All user-facing text must be stored as keys in resource files.
Central File: A central localization.csv file will be used to store the key-value pairs.
Implementation: Text will be set in UI scripts using the tr() function.

### 6.2 Complex System Interactions & Architectural Insights

This section documents the complex relationships between different systems in the game architecture, based on deep debugging experiences. Understanding these interactions is crucial for maintaining and extending the codebase.

#### 6.2.1 Window Management System Architecture

**System Components:**
- **WindowManager:** Central authority for all modal and inspection window lifecycle
- **Modal Stack:** Manages modal windows (InventoryWindow, ChoiceWindow, EndBattlePopup)
- **Inspection Group:** Manages inspection windows (UnitInspectionWindow, ItemInspectionWindow)
- **Global Input Handler:** Intercepts all mouse clicks to manage window closure

**Key Relationships:**
- **Modal vs Inspection Windows:** Modal windows can exist alongside inspection windows, but their lifecycle affects inspection windows
- **Input Event Flow:** Global input handling must account for modal window states to prevent premature inspection window closure
- **Window Anchoring:** Inspection windows are anchored to UI elements and must track their anchor's lifecycle

**Architectural Patterns:**
- **Stable vs Volatile Anchors:** Inspection windows must anchor to stable UI elements (SlotView, PanelContainer) that persist across redraws, never to volatile elements (GachaBallView) that get destroyed/recreated
- **Modal Window Classification:** Not all modal windows should trigger inspection window closure. Dialog windows (choice prompts) preserve UI state, while true modals (inventory windows) clear the UI
- **Input Guarding:** When modal windows are active, global input handling should not close inspection windows, as the user might be legitimately interacting with modals

#### 6.2.2 Signal System Architecture

**Signal Types and Flow:**
- **battle_inventory_changed:** General signal emitted for any battle inventory modification
- **unit_inventory_changed:** Specific signal emitted when a particular unit's inventory changes
- **run_data_changed:** Signal for run state modifications (out of battle)
- **selection_changed:** Signal for UI selection state changes

**Signal Emission Patterns:**
- **Move Operations:** Emit general signals (battle_inventory_changed)
- **Swap/Merge Operations:** Emit both specific (unit_inventory_changed) and general signals
- **Equip/Unequip:** Emit unit-specific signals for stat recalculation
- **Modal Interactions:** Emit selection_changed signals that can trigger window management

**Signal Reception Patterns:**
- **Inspection Windows:** Must listen to multiple signal types to handle all inventory change scenarios
- **UI Views:** Listen to instance-specific signals for targeted updates
- **WindowManager:** Listens to selection_changed to manage window lifecycle

#### 6.2.3 UI Element Lifecycle and Volatility

**UI Element Categories:**
- **Stable Elements:** SlotView, PanelContainer - persist across UI redraws, safe to anchor to
- **Volatile Elements:** GachaBallView - destroyed and recreated during UI updates, never anchor to these
- **Container Elements:** GridContainer, VBoxContainer - structural elements that persist

**Lifecycle Patterns:**
- **UI Redraws:** BattleView redraws destroy and recreate GachaBallView children but preserve container structure
- **Modal Window Creation:** Adds windows to modal stack, may affect inspection window lifecycle
- **Inspection Window Anchoring:** Must use stable anchors to prevent premature closure

**Volatility Rules:**
- **Never Anchor to GachaBallView:** These are content elements that get recreated
- **Always Anchor to Containers:** SlotView and PanelContainer provide stable reference points
- **Hierarchical Anchor Search:** If original anchor is volatile, search up the tree for stable containers

#### 6.2.4 Inventory Operation Architecture

**Operation Types and Signal Flow:**
- **Move Operations:** Simple location changes, emit general signals
- **Swap Operations:** Exchange positions, emit unit-specific signals for affected units
- **Merge Operations:** Create new instances, emit signals for all affected units
- **Equip/Unequip:** Modify unit-item relationships, emit unit-specific signals for stat updates

**Manager Responsibilities:**
- **InventoryManager:** Stateless logic controller, emits appropriate signals based on operation type
- **BattleManager/RunState:** Data owners that maintain instance dictionaries and containers
- **WindowManager:** Responds to signals to manage UI window lifecycle

**Signal Coordination:**
- **Atomic Operations:** Each inventory operation must emit all relevant signals atomically
- **Signal Granularity:** Use specific signals (unit_inventory_changed) for targeted updates, general signals (battle_inventory_changed) for broad UI refresh
- **Timing Considerations:** Signals are emitted at different points in operation flow, requiring robust handling

#### 6.2.5 Debugging System Interactions

**Systematic Debugging Approach:**
1. **Identify Operation Context:** Determine if the issue occurs during move, swap, merge, or modal interactions
2. **Trace Signal Flow:** Monitor signal emission and reception to ensure proper communication
3. **Check Window State:** Verify modal stack and inspection group states
4. **Validate Anchors:** Ensure inspection windows are anchored to stable elements
5. **Monitor Input Events:** Check if global input handling is interfering with legitimate interactions

**Common System Interaction Points:**
- **Modal Window Closure:** Can trigger inspection window closure depending on modal type
- **UI Redraws:** Can destroy volatile anchors, causing inspection window closure
- **Signal Mismatches:** Different operations emit different signals, requiring multiple listeners
- **Input Event Timing:** Global input handling must account for modal window states
- **Window Lifecycle:** Inspection windows must handle anchor destruction gracefully

**Architectural Principles:**
- **Single Responsibility:** Each system has clear boundaries and responsibilities
- **Loose Coupling:** Systems communicate through signals, not direct references
- **Stable Interfaces:** UI elements provide stable anchoring points for windows
- **Defensive Programming:** Systems must handle unexpected state changes gracefully

6.3 Sequence Diagrams
Merge Operation Flow (In-Battle)
Generated mermaid
sequenceDiagram
    participant UI
    participant InventoryManager as IM
    participant BattleManager as BM
    participant MergeManager as MM

    UI->>IM: inventory_action_requested(source_uuid, target_uuid)
    IM->>BM: Get instances by UUID
    IM->>MM: calculate_merge_result(instance_a, instance_b)
    MM-->>IM: result_definition
    IM->>BM: perform_merge_operation(source_uuid, target_uuid, recipe_id)
    BM-->>UI: instance_created(new_uuid), instance_destroyed(old_uuid), instance_location_changed(item_uuids)
    UI-->>UI: Redraw relevant views

# Part 7: Event-Driven Ability System Architecture

This section defines the complete architecture for the game's event-driven ability system. This system is data-driven, using .tres resources to define all gameplay logic, and event-driven, reacting to specific gameplay moments (Triggers) to create a dynamic and extensible combat model.

## 7.1 Core Data-Driven Components

The system is composed of three primary resource types that work in concert: AbilityDefinition, ConditionDefinition, and EffectDefinition.

### Resource: class_name AbilityDefinition
**Purpose:** The central "glue" resource that links a Trigger to one or more Effects, gated by an optional Condition. This is what is attached to a GachaBallDefinition's list of abilities.

**Properties:**
- `@export var id: StringName` - Unique identifier for the ability (e.g., "last_wish_cricket").
- `@export var trigger: StringName` - The specific gameplay event that can activate this ability (e.g., "on_death"). See Section 7.6 for the canonical list of triggers.
- `@export var condition: ConditionDefinition` - An optional resource. If present, this condition must be met for the ability to activate.
- `@export var effects: Array[EffectDefinition]` - An array of one or more effects to execute when the ability is successfully triggered.
- `@export var description_key: String` - The localization key for the ability's description text.

### Resource: class_name ConditionDefinition
**Purpose:** A reusable, self-contained check that determines if an ability is allowed to proceed.

**Properties:**
- `@export var id: StringName` - Unique identifier for the condition (e.g., "cond_team_size_less_than_enemy").
- `@export var condition_type: StringName` - The specific type of check to perform. This is interpreted by BattleManager. See Section 7.6 for the canonical list.
- `@export var parameters: Dictionary` - A flexible dictionary containing any values needed for the check. For example, a RELATIVE_HP check might use `{"comparison": "greater_than"}`.
- `@export var invert_result: bool = false` - If true, the result of the condition check is inverted. (e.g., "if NOT front slot is empty").

### Resource: class_name EffectDefinition
**Purpose:** An abstract base class for any action that can occur in the game. Concrete effects (e.g., `EffectModifyStat`, `EffectDealDamage`) must inherit from this class and implement its `execute` method.

**Properties:**
- `@export var parameters: Dictionary` - A dictionary containing the specific parameters for this effect's execution. This supports both flat values (e.g., `{"damage": 3}`) and stat-scaling values. See Section 7.7 for the stat-scaling structure.

**Abstract Methods:**
- `execute(source_uuid: String, targets: Array[String], battle_manager: BattleManager, context: Dictionary) -> void`: The core method that all concrete effect scripts must implement. It receives all necessary information to perform its action.

## 7.2 System Responsibilities & Logic Flow

The logic is orchestrated by the AbilityResolver and BattleManager singletons, which work with EffectRequest objects on the LIFO queue.

The EffectRequest resource is updated to carry the necessary data for the full system.

**Properties:**
- `source_uuid: String` - The UUID of the GachaBallInstance whose ability is being processed.
- `ability_id: StringName` - The ID of the AbilityDefinition being executed.
- `effect_definition: EffectDefinition` - A direct reference to the concrete effect to be executed.
- `resolved_targets: Array[String]` - The pre-calculated list of target UUIDs for the effect.
- `trigger_context: Dictionary` - The original context of the event that started this chain (e.g., `{"attacker_uuid": "...", "damage_taken": 5}`).

The AbilityResolver is a stateless service that acts as the central coordinator. Its primary responsibility is to translate game events into EffectRequests.

**Core Method: process_trigger(trigger: StringName, context: Dictionary)**
1. Receives a trigger and context from BattleManager.
2. Queries BattleManager for all live instances that have an ability matching the trigger.
3. For each found ability on each instance:
   a. **Check Condition:** If the AbilityDefinition has a condition, it calls `BattleManager.check_condition(ability.condition, source_uuid, context)`. If this returns false, it stops processing this ability.
   b. **Resolve Targets:** For each EffectDefinition in the ability's effects array, it calls `BattleManager.resolve_target(source_uuid, effect.target_type, context)` to get a list of target UUIDs.
   c. **Create Requests:** It creates a new EffectRequest for each effect, populating it with the source UUID, the effect definition, the resolved targets, and the original context.
   d. **Enqueue:** It pushes each new EffectRequest onto the BattleManager's LIFO effect queue.

The BattleManager is extended to become the "query engine" for the ability system.

- **Event Emitter:** Throughout its combat logic, BattleManager is responsible for calling `AbilityResolver.process_trigger()` at the correct moments (e.g., after damage calculation, after a unit's death).
- **Condition Evaluator:** Implements `check_condition(condition_def: ConditionDefinition, source_uuid: String, context: Dictionary) -> bool`. This method contains a match statement on `condition_def.condition_type` to execute the appropriate check.
- **Target Resolver:** Implements `resolve_target(source_uuid: String, target_type: StringName, context: Dictionary) -> Array[String]`. This method contains a match statement on `target_type` to query its internal data containers and return the correct list of UUIDs.

## 7.3 Combat Action Resolution & Default Attack Fallback

The standard flow for a unit's action during the Combat Phase is governed by the ability system to allow for custom attack behaviors.

1. **Action Determination:** When a unit's turn begins, the BattleManager will first check if the unit has any abilities linked to the `on_attack` trigger.
2. **Condition Pre-check:** It will iterate through these `on_attack` abilities and use AbilityResolver (or a helper function) to determine if any of their conditions are met in the current game state.
3. **Branching Logic:**
   - If a valid `on_attack` ability exists (i.e., its conditions are met): The BattleManager will call `AbilityResolver.process_trigger("on_attack", ...)` for that unit. The resulting EffectRequest(s) will be executed as the unit's turn.
   - If no valid `on_attack` ability exists (either none are defined or no conditions are met): The BattleManager will manually create and enqueue a single EffectRequest for a Default Basic Attack. This effect deals damage equal to the unit's `current_pwr` to the `FRONTMOST_ENEMY`.

This logic ensures that a unit's special attack abilities take precedence, but it will always fall back to a standard, reliable action if its special conditions are not met.

## 7.4 Example Resolution Flow: "Giant Slayer Mantis"

1. **Attack:** The "Giant Slayer Mantis" instance (`mantis_uuid`) attacks a "Stone Whelp" instance (`whelp_uuid`).
2. **Event Emission:** BattleManager's combat loop identifies it's the Mantis's turn and checks for `on_attack` abilities. It finds one.
3. **Condition Check:** The ability has a ConditionDefinition with `condition_type = TARGET_HP_GREATER_THAN_SELF_HP`. The BattleManager evaluates this. If `whelp.hp > mantis.hp`, it returns true.
4. **Action Execution:** The condition passed. The BattleManager proceeds by calling `AbilityResolver.process_trigger("on_attack", {"source_uuid": "mantis_uuid", "target_uuid": "whelp_uuid"})`.
5. **Target Resolution:** The ability's EffectDefinition has `target_type = ATTACK_TARGET`. AbilityResolver calls `BattleManager.resolve_target(...)`.
6. **Target Evaluation:** BattleManager looks at the context dictionary, finds the `target_uuid`, and returns `["whelp_uuid"]`.
7. **Enqueue:** AbilityResolver creates an EffectRequest with `source_uuid="mantis_uuid"`, `effect_definition` pointing to the "Deal +3 Damage" effect, `resolved_targets=["whelp_uuid"]`, and the original context. It pushes this request onto BattleManager's `_effect_queue`.
8. **Execution:** BattleManager's processing loop pops this request. It calls `effect_definition.execute(...)`, passing all the resolved data. The EffectDealDamage script then tells the BattleManager to reduce the HP of `whelp_uuid` by 3.

## 7.5 Canonical System Enums (StringName)

The following StringName values are the definitive list of types for the ability system.

| **Trigger** | **Fired When...** |
|-------------|-------------------|
| on_battle_start | Once for every unit at the very start of combat. |
| on_attack | The unit initiates its attack action. This is the primary trigger for a unit's turn. |
| on_hurt | The unit receives damage. |
| on_kill | The unit's attack or ability defeats another unit. |
| on_death | The unit's HP is reduced to 0 or less. |
| on_ally_death | Any allied unit on the board dies. |
| on_summon | The unit's ability successfully summons a new unit. |
| on_turn_end | After all combat actions for the turn have resolved. |
| passive | Not a trigger. Denotes a constant stat modification from an item. |

| **Target** | **Resolves To...** |
|------------|-------------------|
| SELF | The unit with the ability. |
| HOLDER | The unit equipping the item with the ability. |
| ATTACK_TARGET | The direct target of an on_attack trigger. |
| TRIGGERING_ENTITY | The external entity from the trigger's context (e.g., the attacker in an on_hurt event). |
| FRONTMOST_ENEMY | The enemy unit in the frontmost position. |
| RANDOM_ENEMY | One randomly selected enemy unit. |
| RANDOM_ALLY | One randomly selected allied unit (can include self). |
| ALLY_BEHIND | The allied unit in the slot directly behind this one. |
| ALLY_SLOT_AHEAD | The empty slot directly in front of this one (for summoning). |
| ADJACENT_ALLIES | Allies in slots directly in front of and behind this one. |
| ALL_ALLIES | All allied units currently on the board. |

| **Condition Type** | **Checks If...** |
|-------------------|------------------|
| TEAM_SIZE_LESS_THAN_ENEMY | The number of allied units is less than the number of enemy units. |
| SLOT_AHEAD_IS_EMPTY | The combat slot directly in front of the source unit is unoccupied. |
| TARGET_HP_GREATER_THAN_SELF_HP | The HP of the target (from context) is greater than the source's HP. |

## 7.7 Stat-Scaling Effects

To allow effects to scale with unit stats, the parameters dictionary within an EffectDefinition supports a structured format for values.

**Parameter Structure:** Any value (e.g., damage, hp_gain) can be a Dictionary with the following keys:
- `base_value`: int - A flat amount. Defaults to 0.
- `pwr_multiplier`: float - A multiplier for the source unit's final, calculated current_pwr. Defaults to 0.0.
- `hp_multiplier`: float - A multiplier for the source unit's final, calculated current_hp. Defaults to 0.0.
- `base_hp_multiplier`: float - A multiplier for the source unit's base_hp. Defaults to 0.0.

**Calculation:** The final value is calculated as `floor(base_value + (stat * multiplier))`. An effect's `execute()` method is responsible for parsing this structure and using the source unit's stat getters to calculate the final outcome.

## 7.8 Status Effect System

Status effects are conditions applied to units that modify their behavior or stats over time. They are tracked in the `GachaBallInstance.status_effects` dictionary.

- `EffectApplyStatus.gd`: A concrete `EffectDefinition` is required to apply these effects. Its parameters are `{"status_id": StringName, "stacks": int}`.

**Status Effect Logic:** The `BattleManager` is responsible for processing the logic for each status effect at the appropriate phase.

1. **Additive Stats (Strength, Weaken):** These are factored into the dynamic stat calculation as defined in the Order of Operations.
2. **Damage Over Time (Poison):** At the start of a unit's turn (or end of turn, TBD), `BattleManager` deals damage equal to the number of Poison stacks, then reduces the stacks by 1.
3. **Decaying Stacks:** For statuses like Strength and Weaken, `BattleManager` decrements their stack count by 1 at the end of each turn.

## 7.9 Stat Calculation Order of Operations
Note: The current implementation uses a simpler direct additive model for item bonuses. This section describes the target architecture for when status effects and multiplicative abilities are introduced.

To ensure consistent and predictable stat values, all current stats are calculated dynamically using a strict order of operations. This logic is encapsulated within getter methods in `GachaBallInstance.gd` (e.g., `get_current_pwr()`).

**The Definitive Formula:**
```
Final_Stat = floor( (Base_Stat + Sum_of_Additive_Modifiers) * Product_of_Multiplicative_Modifiers )
```

**Step-by-Step Calculation Process:**
1. **Start with the Base Stat:** Begin with the `base_hp` or `base_pwr`.
2. **Sum All Additive Modifiers:** Sum the stacks from all relevant `status_effects` (e.g., Strength - Weaken).
3. **Calculate the Final Multiplier:** Calculate the product of all values in the `temporary_multipliers` dictionary (e.g., 1.0 * 1.5 * 0.75).
4. **Apply Final Calculation:** Multiply the result from Step 2 by the result from Step 3 and apply `floor()` to get the final integer value.

## 7.10 Dynamic Stat Tooltip Architecture

To provide players with transparent feedback on complex stat interactions, the UI will display a detailed breakdown of how a stat is calculated, rather than attempting to show the contribution of each individual modifier.

**StatTooltipGenerator.gd:** This singleton service is responsible for creating the formatted breakdown.

**Core Method:** `generate_pwr_tooltip(instance: GachaBallInstance) -> String`:
1. Calls `instance.get_current_pwr()` to get the final stat value.
2. Reads the instance's `base_pwr`, `status_effects`, and `temporary_multipliers` to build a multi-line string.
3. The string lists each component separately: the base value, each additive modifier, each multiplicative modifier, and the final calculated value.

**UI Implementation:** When a player hovers over a stat display (e.g., a "PWR: 14" label), this tooltip is generated and shown, providing a clear and mathematically honest breakdown of all active effects.

**Example Tooltip Display:**
```
Power: 14
------------------
Base: 10
Strength: +3
Rage Ability: x1.5
------------------
Final: 14
```

## 7.11 Critical Window Management Fixes & Architectural Insights

This section documents critical fixes and architectural insights discovered during deep debugging of the window management system. These learnings are essential for maintaining and extending the codebase.

### 7.11.1 Modal Window Persistence Bug

**Problem:** Inspection windows stopped responding to background clicks after the first battle in subsequent battles.

**Root Cause:** Modal windows (InventoryWindow, ChoiceWindow, EndBattlePopup) were being freed but not properly removed from the `WindowManager._modal_stack`. This left invalid references that prevented the global input handler from working.

**Symptoms:**
- First battle: `Modal stack size: 0` - Background clicks work perfectly
- Subsequent battles: `Modal stack size: 1` - Background clicks ignored due to invalid modal references

**The Fix:** Implemented proactive cleanup in `_cleanup_invalid_windows()`:
```gdscript
# Remove any invalid windows from the modal stack
i = 0
while i < _modal_stack.size():
    var modal = _modal_stack[i]
    if not is_instance_valid(modal):
        print("WindowManager: Removing invalid modal from modal stack")
        _modal_stack.remove_at(i)
        # Don't increment i since we removed an element
    else:
        i += 1
```

**Key Insight:** Window management systems must proactively clean up invalid references rather than relying on perfect cleanup during window destruction, as windows can be freed through various paths (scene transitions, user actions, etc.).

### 7.11.2 Instance ID-Based Window Tracking

**Problem:** Window tracking was using object references that could become stale, leading to dangling signal connections and memory leaks.

**Root Cause:** The original system used `Control` object references as dictionary keys, but these references could become invalid when objects were freed.

**The Fix:** Refactored to use `instance_id` (int) as tracking keys:
```gdscript
# Use the window's instance ID as the key for tracking
var window_id = window_instance.get_instance_id()
_tracked_windows[window_id] = {
    "anchor": stable_anchor,
    "geom_callable": geom_callable,
    "freed_callable": freed_callable
}
```

**Benefits:**
- Robust tracking even when object references become invalid
- Proper cleanup of signal connections using instance IDs
- Prevention of memory leaks and desynchronization

### 7.11.3 Signal Ownership Correction

**Problem:** Dangling signal connections caused crashes between battles.

**Root Cause:** The transient `BattleView` script was connecting signals on persistent `Main` scene buttons, creating dangling connections when the battle scene was freed.

**The Fix:** Moved signal ownership to the correct persistent owner:
```gdscript
# In Main.gd _ready()
draw_tier1_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 1))
draw_tier2_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 2))
draw_tier3_button.pressed.connect(func(): EventBus.emit_signal("draw_gacha_requested", 3))
```

**Key Principle:** Signal connections must be owned by persistent objects that outlive the connected objects.

### 7.11.4 Contextual UI Interaction Model

**Implementation:** Added support for different interaction models based on context (player vs. enemy units).

**Technical Details:**
- `WindowManager` sets `context["is_enemy_context"] = true` for enemy units
- `UnitInspectionWindow` uses this flag to make enemy unit inspection read-only
- Single-click inspection enabled for equipped items on enemy units
- Double-click inspection required for player units (drag-and-drop containers)

**Architecture:** This demonstrates how the window management system can support nuanced UI behavior while maintaining the core inspection window rules.

### 7.11.5 Proactive Cleanup Pattern

**Pattern:** Implement proactive cleanup functions that run before critical operations to ensure data structures are in a valid state.

**Implementation:**
```gdscript
func _cleanup_invalid_windows():
    # Remove invalid inspection windows
    # Remove invalid modal windows
    # Called before every input event
```

**Benefits:**
- Prevents cascading failures from invalid references
- Makes the system robust against imperfect cleanup during object destruction
- Provides clear debugging information about cleanup operations

### 7.11.6 Window Lifecycle Management Rules

**Critical Rules Discovered:**
1. **Modal Stack Integrity:** Invalid modal windows must be proactively removed to prevent input handler blocking
2. **Instance ID Tracking:** Use instance IDs, not object references, for robust window tracking
3. **Signal Ownership:** Persistent objects must own signals connected to transient objects
4. **Proactive Cleanup:** Clean up invalid references before processing input events
5. **Contextual Behavior:** Window behavior can vary based on context while maintaining core rules

**Architectural Impact:** These fixes ensure the window management system is robust, debuggable, and extensible for future features.

## 7.6 Concrete Effect Implementation Examples

The following snippets illustrate the final implementation pattern for concrete effects.

### EffectModifyStat.gd

```gdscript
# res://scripts/effects/EffectModifyStat.gd
@tool
class_name EffectModifyStat extends EffectDefinition

func execute(source_uuid: String, targets: Array[String], battle_manager: BattleManager, context: Dictionary) -> void:
    var hp_change: int = parameters.get("hp_gain", 0)
    var pwr_change: int = parameters.get("pwr_gain", 0)
    var is_permanent: bool = parameters.get("is_permanent", false) # In-battle, "permanent" means "for the rest of combat".

    for target_uuid in targets:
        var target_instance = battle_manager.get_instance(target_uuid)
        if is_instance_valid(target_instance):
            target_instance.current_hp += hp_change
            target_instance.current_pwr += pwr_change
            # Ensure HP doesn't go below 1 from a stat mod, unless it's damage.
            if target_instance.current_hp < 1:
                target_instance.current_hp = 1
```

### EffectSummonUnit.gd

```gdscript
# res://scripts/effects/EffectSummonUnit.gd
@tool
class_name EffectSummonUnit extends EffectDefinition

func execute(source_uuid: String, targets: Array[String], battle_manager: BattleManager, context: Dictionary) -> void:
    var definition_to_summon: GachaBallDefinition = parameters.get("definition")
    var power: int = parameters.get("power", 1)
    var health: int = parameters.get("health", 1)

    if not definition_to_summon:
        push_error("EffectSummonUnit is missing a GachaBallDefinition in its parameters.")
        return

    # Assuming target is a slot index or a location to summon at
    # This part of the logic will need careful implementation in BattleManager
    battle_manager.summon_unit_to_location(definition_to_summon, power, health, targets[0]) # Assuming target is a location identifier
```

# Part 5: Game Flows
### 5.1 In-Battle Instance Lifecycle
To ensure data integrity and prevent unnecessary object creation, the following rules govern how GachaBall instances are handled during a battle after the initial setup:

**No New Copies:** After the initial `battle_copy()` creation at the start of a battle, no further copies or clones of `GachaBall` instances are made. All subsequent operations manipulate the existing battle instances.

**Movement is a State Change:** "Moving" an instance (e.g., from bench to lineup, or inventory to discard) is achieved by changing the `location_container_tag` and `location_slot_index` properties on the instance itself, and updating the relevant `DataContainer` objects. The instance's `ball_uuid` remains the same for the duration of the battle.

**Item Salvage and Inheritance:** When a unit is defeated or used as a merge ingredient, its equipped items are not copied. The exact same item instances are transferred. Their `equipped_on_uuid` and `location` properties are updated to reflect their new state (either moved to the discard pile or re-equipped on a newly merged unit).

### 5.2 Battle Setup Flow
1.  `BattleManager` receives a generated `EncounterDefinition`.
2.  It creates `battle_copy()` instances from `run_state.run_instances` for all player units and items. It stores a map of permanent-to-battle UUIDs.
3.  It iterates through the new battle copies and remaps their `equipped_item_uuids` to the new battle-specific UUIDs.
4.  The Hero is a special case; the persistent `GachaBallInstance` from `RunState` is used directly in battle without being copied.
5.  It creates new instances for all enemies and their items as defined in the `EncounterDefinition`.
6.  It places all instances into the correct `DataContainer` indices according to their original locations or the encounter definition.

### 5.3 Gacha Draw Flow
`BattleManager` receives `draw_gacha_requested(tier_tag)`.
* It queries `_battle_instances` for instances with `location_container_tag == "BATTLE_DRAW_POOL_[tier_tag]"`.
* If a draw or merge action causes a tiered battle inventory pool to become empty, it is automatically and immediately replenished with all corresponding GachaBalls from the `BATTLE_DISCARD_PILE`. When a reshuffle occurs, any GachaBall instance being moved from the `BATTLE_DISCARD_PILE` to a `BATTLE_DRAW_POOL` must have its `current_hp` and `current_pwr` stats reset to the `base_hp` and `base_pwr` values from its `GachaBallDefinition`.
* It picks a random instance and changes its location properties to an available slot in `BATTLE_PLAYER_BENCH` or `BATTLE_ITEM_INVENTORY`.
* It emits `instance_location_changed(drawn_uuid)`.

### 5.4 Merge Flow
1.  `InventoryManager` receives `inventory_action_requested` for a merge.
2.  It instructs the appropriate data owner (`RunState` or `BattleManager`) to perform the following atomic operation:
    a. Create a new `result_instance` from the merge recipe.
    b. Update the `result_instance`'s location properties to place it in the correct destination container and slot. **Rule: If the merge occurs on the battle board (`PlayerLineup`, `PlayerBench`, `ItemInventory`) or in an equipped item slot, the result is placed in the target ingredient's original slot. The tier-up-to-new-inventory-pool logic only applies when merging within the `(Run/Battle)InventoryT<n>` containers.**
    c. Add the new instance's UUID to the master instance dictionary and the destination `DataContainer` (the index).
    d. For each ingredient, remove its UUID from its `DataContainer` and the master instance dictionary.
    e. For all inherited items, update their `equipped_on_uuid` property to point to the new `result_instance`.
3.  The data owner emits the necessary state change signals (`battle_inventory_changed` or `run_data_changed`).

### 5.5 Post-Battle Reward Flow
#### Design Rationale: Instance-Based Rewards
To ensure architectural consistency and maximum feature reuse, the reward system uses real `GachaBallInstance` objects instead of temporary representations. This treats the reward choice screen as a temporary inventory, allowing all existing systems (inspection, selection, tooltips) to function without special-case logic.

#### Authoritative Flow
1. **Victory & Acknowledgement**: The flow begins after the player acknowledges a battle victory, which emits `battle_victory_acknowledged`.
2. **Reward Instance Generation**: 
   - `GameManager` receives the signal, generates the temporary reward instances, and stores them in its `_temporary_reward_master_dict`.
   - The reward instances are created with proper location information in a temporary container.
3. **Display**: 
   - `GameManager` emits `reward_scene_requested`. 
   - `Reward.tscn` is displayed. Its `GachaBallViews` and `SlotViews` are configured for a selection-only context. 
4. **Player Interaction**: The player interacts with the rewards, and `GlobalInteractionRouter` handles selection changes.
5. **Final Choice & State Change**: The player confirms their choice; `Reward.gd` emits `reward_chosen`, updates UI state, and reveals `%BackToPathButton`.
6. **State Update & Cleanup**: `GameManager` processes `reward_chosen` following the **Golden Rule**, updates `RunState`, and clears `_temporary_reward_master_dict`.
7. **Manual Scene Transition**: Clicking `%BackToPathButton` emits `path_choice_scene_requested`; `Reward.gd` immediately calls `queue_free()` on itself.

---
# Part 8: Dynamic Encounter Generation System

This section details the technical implementation of the budget-based system responsible for generating enemy teams for COMMON and ELITE battle nodes.

## 8.1 System Goals & Responsibilities

**Goal:** To programmatically generate a complete and valid enemy encounter, including units and their equipped items, based on a given "gold" budget.

**Inputs:** 
- `day: int` - The current day of the run
- `node_subtype: StringName` - Either "COMMON" or "ELITE"

**Output:** An in-memory `EncounterDefinition` resource that can be directly consumed by the `BattleManager`.

**Core Responsibility:** A new stateless service, `EncounterGenerator.gd`, will contain the generation algorithm. `GameManager` will be responsible for calculating the total budget and invoking this service when a player selects a dynamic battle node.

## 8.2 Data Schema Modifications

### GachaBallDefinition.gd
A new property is required to define the purchase cost.

```gdscript
# res://resources/gachaball/GachaBallDefinition.gd
extends Resource
class_name GachaBallDefinition

# ... existing properties ...

# The cost to purchase this GachaBall in the shop or for encounter generation
@export var cost: int = 1
```

**Rule:** The cost of a GachaBall must be explicitly set in its .tres file. While it will typically equal its tier, this explicit field allows for future design exceptions.

### PathNodeDefinition.gd
The existing `subtype` property will be used to differentiate battle difficulties.

**Usage:**
- `subtype = "COMMON"` for standard battles.
- `subtype = "ELITE"` for battles with a 1.5x budget multiplier.

## 8.3 The "Constrained Random Build" Algorithm

The core of this system is an algorithm designed to spend a budget under several constraints (max 6 units, items must fit in slots, budget must be fully spent). A simple greedy approach is insufficient as it can lead to unspent budget. The following robust, multi-pass algorithm will be implemented in `EncounterGenerator.gd`.

### Function Signature
```gdscript
# Generates a complete encounter based on the given budget
# Returns: An EncounterDefinition resource with enemy placements
func generate_encounter(budget: int) -> EncounterDefinition
```

### Algorithm Steps

#### Phase 1: Setup & Data Pooling
1. Retrieve all non-hero `GachaBallDefinition` resources from `Database.gd`.
2. Separate them into two pools: `available_units` and `available_items`.
3. Initialize:
   ```gdscript
   var purchased_units: Array[GachaBallDefinition] = []
   var purchased_items: Array[GachaBallDefinition] = []
   var spent_budget: int = 0
   ```

#### Phase 2: Mandatory Unit Spending
1. Calculate `min_unit_spend = floor(budget / 2)`.
2. Enter a loop that continues as long as `spent_budget < min_unit_spend` and `len(purchased_units) < 6`:
   - Filter `available_units` to find all units that can be afforded with the remaining budget (`budget - spent_budget`).
   - If the list of affordable units is empty, break the loop.
   - Select a random unit from the affordable list, add it to `purchased_units`, and add its cost to `spent_budget`.

#### Phase 3: Optimized Flexible Spending (Backtracking Heuristic)
This phase spends the remaining budget. To ensure the full budget is used, it will employ a limited backtracking strategy.

1. Start an outer loop with a maximum of 10 attempts. This prevents infinite loops in edge-case scenarios.
2. Inside the attempt loop:
   - Create temporary copies of `purchased_units`, `purchased_items`, and `spent_budget` from the state after Phase 2.
   - **Inner Loop:** While `temp_spent_budget < budget`:
     - Calculate current `total_item_slots` on the `temp_purchased_units`.
     - Create a `possible_purchases` list.
     - If `len(temp_purchased_units) < 6`, add all affordable units to the list.
     - If `len(temp_purchased_items) < total_item_slots`, add all affordable items to the list.
     - If `possible_purchases` is empty, the build is stuck. Break the inner loop.
     - Select a random definition from `possible_purchases`, add it to the appropriate temporary list (`_units` or `_items`), and update `temp_spent_budget`.
   - **Check for Success:** After the inner loop, if `temp_spent_budget == budget`, the build is perfect. Return the results from the temporary lists.
   - If the attempt failed (the inner loop broke and budget is unspent), discard the temporary lists and the outer loop will try again with a different random seed.

#### Phase 4: Final Assembly
1. If after 10 attempts a perfect-budget team was not found, the system will use the result from the attempt that got closest to the target budget without exceeding it.
2. Create a new `EncounterDefinition` resource in memory.
3. Iterate through the final `purchased_units` list and add them to the `encounter.enemy_placements` array at random, unoccupied positions (0-5).
4. For each item in the final `purchased_items` list, randomly assign it to an available item slot on one of the purchased units.
5. Return the completed `EncounterDefinition`.

## 8.4 Manager & System Responsibilities

### GameManager.gd
- When a BATTLE node is selected via `_on_node_selected`, it will inspect the `node_def.subtype`.
- It calculates the `total_budget = (run_state.day * 5)`. If `subtype == "ELITE"`, it applies the `total_budget *= 1.5` multiplier.
- It calls `EncounterGenerator.generate_encounter(total_budget)`.
- It passes the resulting `EncounterDefinition` to the `BattleManager` during the battle setup process.

### EncounterGenerator.gd (New Script)
- A new autoload singleton script.
- Contains the `generate_encounter` method and the logic from section 8.3. It is a stateless service.

### BattleManager.gd
- Its `_setup_enemy_lineup` function will be modified to accept an optional `EncounterDefinition`. If one is provided, it builds the enemy team from that definition instead of its old hard-coded logic. If no definition is provided, it can fall back to a default or error state.

# Part 9: Flashcard System & Resource Generation

This section details the technical architecture of the flashcard mini-game.

## 9.1 Data Schemas
The necessary schemas (`FlashcardDefinition.gd`, `FlashcardProgress.gd`) and property additions (`RunState.flashcard_progress`, `RunState.active_deck_ids`) are defined in Part 2. `BattleManager` also contains a temporary `gacha_tokens: int` property for the duration of a battle.

## 9.2 Singleton Manager: `FlashcardManager.gd`
A singleton responsible for the mini-game's lifecycle.
*   **Public API:** `start_minigame(run_state: RunState, active_deck: Array[StringName])`
*   **Signal:** `minigame_finished(results: Dictionary)` where `results` is `{"correct_answers": int, "incorrect_answers": int}`.

## 9.3 The Weighted SRS Algorithm
`FlashcardManager` selects questions using a weighted random algorithm:
1.  **Calculate Weight:** For each card, `weight = pow(6 - mastery_level, 2) + (current_day - last_review_day)`.
2.  **Select:** Perform a weighted random roll on the candidate pool.
3.  **Rule:** The same card is never shown twice in a row.

## 9.4 System Integration & Results Feedback Flow

To provide clear feedback, the result of the mini-game is displayed in a dedicated `ResultsPopup` before the game state proceeds. The flow is managed by the context-specific caller (`BattleManager` or `RestSite`).

### A. Battle Flow
1.  **Trigger:** At the start of the turn, `BattleManager` calls `FlashcardManager.start_minigame(...)`.
2.  **Connection:** `BattleManager` connects its handler function to `FlashcardManager.minigame_finished`.
3.  **Execution:** The mini-game runs.
4.  **Results Calculation:** When `minigame_finished` is emitted, the `BattleManager`'s handler receives the `results` dictionary. It calculates the rewards: `gacha_gain = 5 (base) + results.correct_answers`.
5.  **Display Popup:** `BattleManager` immediately calls `WindowManager.open_modal_window("ResultsPopup", ...)`, passing the following context:
    *   `title`: "Turn Start!"
    *   `message`: "You earned %d Gacha Tokens." % gacha_gain
    *   `button_text`: "Okay"
6.  **Acknowledgement:** The player clicks "Okay". The `ResultsPopup` emits `results_acknowledged` and closes.
7.  **State Update & Progression:** `BattleManager` listens for the `results_acknowledged` signal. Its handler then updates its internal state (`self.gacha_tokens += gacha_gain`), emits `gacha_tokens_changed`, and proceeds with the combat phase logic (`_populate_effect_queue`, etc.).

### B. Rest Site "Train" Flow
1.  **Trigger:** The player clicks a "Train" button in the `RestSite.tscn` scene. The `RestSite.gd` script calls `FlashcardManager.start_minigame(...)`.
2.  **Connection:** The `RestSite.gd` script connects its handler to `FlashcardManager.minigame_finished`.
3.  **Execution:** The mini-game runs.
4.  **Results Calculation:** The `RestSite.gd` handler receives the `results` and calculates the reward: `stat_gain = floor(results.correct_answers / 2.0)`.
5.  **Display Popup:** The script calls `WindowManager.open_modal_window("ResultsPopup", ...)`, passing the context:
    *   `title`: "Training Complete!"
    *   `message`: "Your Hero gained +%d %s." % [stat_gain, stat_type]
    *   `button_text`: "Continue"
6.  **Acknowledgement:** The player clicks "Continue". The popup emits `results_acknowledged` and closes.
7.  **State Update:** The `RestSite.gd` script listens for `results_acknowledged`. Its handler then modifies the Hero's stats in `RunState` and emits the `run_data_changed` signal. The Rest Site buttons are re-enabled.

# Part 10: Pre-Run Setup & Data Pipeline

## 10.1 Deck Data Pipeline
*   **File Location:** `res://decks/`
*   **Format:** JSON object containing `deck_id`, `display_name`, and a `cards` array with `id`, `question`, `answer`, `explanation`.
*   **Loading Authority:** `Database.gd` loads all `.json` files from this directory at startup.

## 10.2 Loadout Scene & Run Initialization Flow
1.  **UI:** `Loadout.tscn` populates its UI by calling `Database.get_hero_definitions()` and `Database.get_all_deck_metadata()`.
2.  **Signal:** On "Start Run" press, it emits `start_run_requested(hero_def_id, deck_id)`.
3.  **Initialization:** `GameManager` receives the signal and creates a new `RunState`, calling its `initialize_run(hero_def_id, deck_id)` method.
4.  **`RunState.initialize_run` Logic:**
    *   Creates the Hero instance and places it in the lineup.
    *   Iterates through the chosen deck's card list from the `Database`.
    *   For each card, creates a `FlashcardProgress` resource and stores it in `run_state.flashcard_progress`.
    *   Populates the `active_deck_ids` array with the first 10 cards.
    *   Adds any defined starter units/items to the inventory.
    *   Sets `day = 1`.
5.  **Transition:** `GameManager` transitions to the `Main.tscn` and requests the `PathChoice` content scene.

---

### 5.5 Post-Battle Reward Flow

#### Design Rationale: Instance-Based Rewards
To ensure architectural consistency and maximum feature reuse, the reward system uses real GachaBallInstance objects instead of temporary representations. This approach treats the reward choice screen as a temporary inventory, allowing all existing systems (inspection, selection, tooltips) to function without special-case logic. When a choice is made, the selected instance is simply moved to the permanent RunState, while the unchosen instances are discarded. This maintains the "single source of truth" principle and creates a more robust and extensible system.

#### Authoritative Flow
1. **Victory & Acknowledgement**: The flow begins after the player acknowledges a battle victory, which emits `battle_victory_acknowledged`.

2. **Reward Instance Generation**: 
   - `GameManager` receives the signal, generates the temporary reward instances, and stores them in its `_temporary_reward_master_dict`.
   - The reward instances are created with proper location information in a temporary container.

3. **Display**: 
   - `GameManager` emits `reward_scene_requested`. 
   - The `Reward.tscn` scene is displayed. Its `GachaBallViews` and `SlotViews` are configured for a selection-only context. 
   - Double-click to inspect remains functional.

4. **Player Interaction**: 
   - The player interacts with the rewards. The UI will provide the correct `InteractionContext` to the `GlobalInteractionRouter`, which will handle selection changes seamlessly.

5. **Final Choice & State Change**: 
   - The player clicks either the `%ConfirmSelectionButton` or `%TakeGoldButton`.
   - The `Reward.gd` script emits the `reward_chosen` signal with the appropriate payload.
   - The script then changes the UI state: it hides the `Confirm` and `Gold` buttons and makes a new `%BackToPathButton` visible. 

6. **State Update & Cleanup**: 
   - `GameManager` receives `reward_chosen` and performs the final state modification according to the **Golden Rule of State Synchronization**.
   - It clears its internal temporary reward data (`_temporary_reward_master_dict`).

7. **Manual Scene Transition**: 
   - The player is now on the reward screen with their new item added to their inventory. 
   - When the player clicks `%BackToPathButton`, the `Reward.gd` script emits `path_choice_scene_requested`.
   - Immediately after emitting the signal, the `Reward.gd` script must call `queue_free()` on itself.

---
# Part 6: Localization & Sequence Diagrams
### 6.1 Localization System
Key-Based System: All user-facing text must be stored as keys in resource files.
Central File: A central localization.csv file will be used to store the key-value pairs.
Implementation: Text will be set in UI scripts using the tr() function.
