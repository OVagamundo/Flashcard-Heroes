Flashcard Heroes - Technical Design Document (V5.1 - Definitive)
Part 1: Core Architecture & Principles
### 1.1 Architectural Principles
The game's logic is built upon a definitive **Hybrid Architecture** to guarantee data integrity while maintaining performance. This architecture is not optional; it is the required implementation pattern for all game state management. It consists of three pillars:

1.  **The Instance is the Source of Truth:** The `GachaBallInstance` resource is the single, undeniable source of truth for all of its own data, including its stats, status, and location (`location_container_tag`, `location_slot_index`, `equipped_on_uuid`). There are no other sources of truth. Caching this data in managers is strictly forbidden.

2.  **The Container is a Performant Index:** `DataContainer` objects (e.g., `FixedArrayContainer`) are used by managers (`RunState`, `BattleManager`) to provide fast, location-based lookups. These containers hold only UUIDs and act as a disposable index into the master instance dictionary. They are not a source of truth for any data besides the ordering of UUIDs in a location. If a container's index were to become corrupted, it could be rebuilt from the instance data, ensuring the game's state is never permanently lost.

3.  **Managers are Authoritative Operators:** Managers like `InventoryManager` contain the stateless logic (the "verbs") that operates on the data. They are responsible for correctly executing the **Golden Rule of State Synchronization**: any operation that moves an instance *must* update both the `DataContainer` (the index) and the `GachaBallInstance`'s properties (the truth) in a single, atomic operation.
1.2 Directory Structure
Generated code
res://
├── assets/
├── resources/
│   ├── units/, items/, abilities/, recipes/
├── scenes/
└── scripts/
├── localization.csv
Use code with caution.
Part 2: Data Schemas & Structures
2.1 Core Data Resources
RunState.gd: Resource, class_name RunState. The persistent state for an entire run.
Properties: gold: int, run_instances: Dictionary[String, GachaBallInstance] (The master dictionary of all permanent instances for the run.)
**GachaBallDefinition.gd:** Resource, class_name GachaBallDefinition. The immutable template for a GachaBall.
*   **Properties:** 
    - `@export var id: StringName` - Unique identifier for this definition
    - `@export var display_name_key: String` - Localization key for display name
    - `@export var description_key: String` - Localization key for description
    - `@export var icon: Texture2D` - Display icon
    - `@export var tags: Array[StringName]` - Array of tags that define special properties. Common tags include "hero" for hero units, "consumable" for one-time use items, etc.
    - `@export var item_slot_count: int` - Number of equipment slots (for units)
    - `@export var base_hp: int = 0` - Base health points
    - `@export var base_pwr: int = 0` - Base power/attack
**GachaBallInstance.gd:** Resource, class_name GachaBallInstance. A unique, mutable instance of a GachaBall. This resource is the single source of truth for all of its own data.
*   **Core Properties:** `definition_id: StringName`, `ball_uuid: String`, `origin_uuid: String`, `current_hp: int`, `current_pwr: int`
*   **Location Properties (The Single Source of Truth):** 
    - `location_container_tag: StringName` - The container tag when not equipped
    - `location_slot_index: int` - The slot index when not equipped
    - `equipped_on_uuid: String` - UUID of the unit this item is equipped on (empty if not equipped)
    - `equipped_slot_index: int` - The slot index on the unit where this item is equipped (-1 if not equipped)
    - `equipped_item_uuids: Array[String]` - For units: array of UUIDs of equipped items (empty strings for empty slots)
*   **Methods:** 
    - `initialize(def: GachaBallInstance)`
    - `add_tag(tag: StringName)`, `remove_tag(tag: StringName)`, `has_tag(tag: StringName) -> bool`
    - `recalculate_stats(all_instances_db: Dictionary)`
    - `create_battle_copy() -> GachaBallInstance`
    - `get_location() -> LocationIdentifier` - Returns a LocationIdentifier that represents the instance's current location. For equipped items, returns a location with container="equipped_item", unit_uuid set to the parent unit's UUID, and index set to the equipped slot index. For unequipped items, returns a location with the appropriate container tag and slot index.
MergeRecipe.gd: Resource, class_name MergeRecipe.
Properties: @export var id: StringName, @export var ingredient_a_id: StringName, @export var ingredient_b_id: StringName, @export var result_id: StringName
EffectRequest.gd: Resource, class_name EffectRequest. A request to execute an ability, placed on the effect queue.
Properties: source_uuid: String, ability_id: StringName, trigger_context: Dictionary
AbilityDefinition.gd & EffectDefinition.gd: Define abilities and their executable effects.
### 2.2 Location Container Tags (location_container_tag)

These StringName values define all possible logical locations for a GachaBallInstance.

*   **Run State Locations:** `RunInventoryT1`, `RunInventoryT2`, `RunInventoryT3`, `PlayerLineup`, `PlayerBench`, `ItemInventory`
*   **Battle State Locations:** `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`, `PlayerLineup`, `PlayerBench`, `ItemInventory`, `EnemyLineup`, `DiscardPile`
*   **Special Location:** `equipped_item` - A conceptual location indicating an item is equipped on a unit. Used in LocationIdentifier but not stored directly.

An item's location is determined by its `equipped_on_uuid` property. If this property is set, the item is considered to be located in the special "equipped_item" container on the parent unit. The `LocationIdentifier` for an equipped item will have:
- `container = "equipped_item"`
- `unit_uuid` = the UUID of the parent unit
- `index` = the slot index on the unit where the item is equipped

If `equipped_on_uuid` is empty, the item is located in the container specified by its `location_container_tag` and `location_slot_index`. The `GachaBallInstance.get_location()` helper method formalizes this logic and is the standard way to query an instance's location.

### 2.3 Data Containers
To solve the performance and complexity issues of querying scattered instance data, the architecture uses a layer of `DataContainer` objects to act as a fast, location-based index.

*   **`DataContainer.gd`:** An abstract base class defining the interface for all containers (e.g., `get_uuid(index)`, `set_uuid(index)`, `find_first_empty_slot()`).
*   **`FixedArrayContainer.gd`:** A concrete implementation for collections with a fixed, predefined size, such as the player/enemy lineups and benches.
*   **`GrowableGridContainer.gd`:** A concrete implementation for collections that can expand when full, such as the tiered battle inventories and the discard pile.
    *   **Initial Size Rule:** To ensure a consistent player experience, all tiered inventory containers (RunInventoryT* and BattleInventoryT*) must be instantiated with an initial size of 16.

Both `RunState` and `BattleManager` use an internal dictionary of these containers to manage their respective instances efficiently.
Part 3: Logic Layer & Managers
3.1 Signal Bus
Action Signals: draw_gacha_requested(tier_tag: StringName), inventory_action_requested(source_uuid: String, target_uuid: String, explicit_action: String = ""), inspection_requested(uuid: String), display_discard_pile_requested
State Change Signals: instance_data_changed(uuid: String), instance_location_changed(uuid: String), instance_created(uuid: String), instance_destroyed(uuid: String), battle_state_changed(is_in_battle: bool), gacha_tokens_changed(new_amount: int)
3.2 Singleton Managers
GameManager.gd: Holds the master run_state and the global is_in_battle flag.
InventoryManager.gd: Stateless logic controller for all inventory actions.
InteractionManager.gd: UI state machine holding the source_uuid of the selected instance.
MergeManager.gd: Stateless helper for merge calculations.
Database.gd: Loads all .tres resources on startup.
SceneManager.gd: Handles scene transitions.
AbilityResolver.gd: Takes an EffectRequest and calls the appropriate EffectDefinition.execute() method.
UUIDUtils.gd: Provides a generate_uuid() utility function.
WindowManager.gd: The sole authority for the lifecycle of all modal and inspection windows.
BattleManager.gd: The authority for a single battle's state.
State: _battle_instances, _gacha_tokens, _effect_queue: Array[EffectRequest], _is_processing_effect: bool
Responsibility: Manages the battle lifecycle, the effect queue, and provides relational query functions.
3.3 The Definitive Hybrid Architecture: The "Why"
This architecture was chosen to solve the problems of data duplication and complex state management found in traditional container-based models. The original "pure" data-centric model, where all queries directly accessed the master instance dictionaries, was inefficient for common access patterns like finding empty slots or iterating through specific locations.

The true hybrid model combines three essential pillars:
1. The "single source of truth" on the instance data
2. The "performant index" in the DataContainers
3. The "contextual understanding" in the managers' relational queries

This gives us the debuggability of the former (data is never duplicated) while providing the necessary speed for a responsive UI through the DataContainer index layer. The DataContainers act as disposable, fast-access indices that can be rebuilt from the instance data when needed, but provide O(1) access to slots and locations.

This architecture prevents data duplication while providing the necessary speed for a responsive UI, ensuring that the game remains performant while maintaining data integrity and ease of debugging.
### 3.4 The Golden Rule of State Synchronization
This rule is the fundamental contract of the hybrid architecture and must be adhered to by all game logic that modifies an instance's location.

**The Rule:** To move an instance, a two-step process is mandatory:
1.  **Update the Index:** The instance's UUID must be removed from the source `DataContainer` and added to the destination `DataContainer`.
2.  **Update the Truth:** The instance's own `location_container_tag` and `location_slot_index` properties must be updated to reflect its new location.

Failing to perform both steps will de-synchronize the game state (specifically, the performant index will not match the data truth) and is considered a critical bug. Caching location data in managers is strictly forbidden as it violates the principle of having a single source of truth.
### 3.5 Positional & Targeting Logic
This logic is implemented within BattleManager's relational query functions.

**Player Team (Left Side):** "Frontmost" corresponds to the unit with the highest location_slot_index (e.g., 5). "Backmost" is the lowest index (e.g., 0).

**Enemy Team (Right Side):** "Frontmost" corresponds to the unit with the lowest location_slot_index (e.g., 0). "Backmost" is the highest index (e.g., 5).

**Action Order:** The standard combat action order for both teams is back-to-front (index 5 down to 0).

### 3.6 The Effect Resolution Queue
This system, managed by BattleManager, governs the flow of combat. It uses a LIFO (Last-In, First-Out) stack to ensure that interruptions and reactions (like a "retaliate on hit" ability) are processed immediately after the event that caused them, creating an intuitive and predictable chain of events.
Population: When the COMBAT phase begins, BattleManager creates an EffectRequest for each unit's action and pushes it onto the _effect_queue stack.
Processing Loop: The BattleManager's _process function contains a loop that pops one request from the stack, awaits its resolution via the AbilityResolver, and then repeats until the queue is empty.
    *   The system must re-validate that the source unit is still alive (HP > 0) at the moment its action is popped from the queue. If the source is no longer alive, its action is skipped.
Chain Reactions: Any ability that triggers another effect creates a new EffectRequest and pushes it to the top of the stack, ensuring it is resolved next.
Part 4: Presentation Layer (UI)
4.1 UI Component Blueprints
GachaBallView.tscn / SlotView.tscn:
Metadata: Must store the ball_uuid: String of the instance it represents.
Behavior: Listens for instance_* signals to update its appearance and position.
DiscardPileWindow.tscn: A modal window opened by WindowManager in response to display_discard_pile_requested.
### 4.2 Window Management & UI Patterns

#### Global Input Interception for Window Closure
To ensure a consistent and responsive user experience, the `WindowManager` singleton employs a global input interception strategy. This is the authoritative pattern for closing non-modal inspection windows.

1.  **`WindowManager` as the First Responder:** The `WindowManager` uses the `_input` lifecycle method to inspect all mouse clicks *before* they are passed to any UI control's `_gui_input` method.

2.  **Out-of-Bounds Detection:** If any inspection windows are currently open, the `WindowManager` checks if the click's position is outside the global rectangle of all open inspection windows.

3.  **Closure without Consumption (The "Click-Through" Rule):** If the click is determined to be outside, the `WindowManager` calls `close_all_inspection_windows()`. Crucially, it **does not** consume the input event (`set_input_as_handled()`). This allows the event to continue propagating to the UI element that was actually clicked (e.g., another `GachaBallView` or an empty `SlotView`).

This pattern creates a seamless "click-through" feel, where a single click can both close an open window and initiate a new action, preventing any "wasted" clicks. This is a core part of the game's UX philosophy.

#### Modal Window Closure
Modal windows (e.g., `InventoryWindow`, `ChoiceWindow`) are accompanied by a `BackgroundBlocker` node. A click on this blocker is consumed and explicitly closes only the top-most modal window via the `background_clicked` signal. This provides clear, expected behavior for modal dialogs.

#### Dynamic Mouse Filter Pattern
For RichTextLabels with clickable links (like the "EFFECTS" link), the `mouse_filter` must be dynamically changed from `PASS` to `STOP` on `meta_hover_started` and back to `PASS` on `meta_hover_ended`. This ensures that the link is clickable while still allowing clicks on the rest of the label's area to fall through to the window's background for closure logic.
4.3 Player Interaction Scenarios
Design Rationale: Interaction rules are separated for "In-Battle" and "Out-of-Battle" states because their consequences are fundamentally different. In-battle actions modify temporary _battle_instances, while out-of-battle actions modify the permanent run_instances. This separation is critical to the game's core loop.
Table 4.3.1: In-Battle Interactions (is_in_battle == true)
Player Action	Conditions	Resulting Logic Flow
Drop Unit on Unit	Merge recipe exists.	InventoryManager shows ChoiceWindow. Player choice re-sends inventory_action_requested with explicit_action: "MERGE" or "SWAP".
Drop Unit on Unit	No merge recipe.	Swap their location_slot_index properties.
Drop Item on Unit	Unit has empty item slot.	Change item's equipped_on_uuid and equipped_slot_index. Emit unit_inventory_changed(unit_uuid) to trigger stat recalculation.
Drag Item off Unit	Target is empty Item Inv. slot.	Unequip: Change item's location_container_tag to BATTLE_ITEM_INVENTORY and clear equipped_on_uuid.
Table 4.3.2: Out-of-Battle Interactions (is_in_battle == false)
Player Action	Conditions	Resulting Logic Flow
Drop Instance on Instance	Merge recipe exists.	InventoryManager shows ChoiceWindow. The chosen action is routed to RunState to modify the permanent instances.
Drop Instance on Instance	No merge recipe.	Swap their location_slot_index within the same RUN_INVENTORY_T* container.
### 4.4 Inspection Window System: Rules and Behavior

This section defines the precise, authoritative rules for how all inspection windows (Unit, Item, Effects) must behave. These rules ensure a consistent, intuitive, and robust user experience.

**1. Core Principles:**

*   **Global Click-to-Close:** Clicking anywhere on the screen that is *not* part of the active inspection window group will immediately close the entire group. This is handled globally by the `WindowManager`'s input interception logic.
*   **Single Active Group:** There can only be one active inspection window "group" (a chain of parent-child windows) on the screen at any time. Opening a new root-level window (e.g., inspecting a different unit on the board) must close the entire previous group.
*   **Single Child Per Parent:** A parent window can only have one direct child window open at a time. Requesting a new child window must first close any existing child and its descendants.
*   **Hierarchical Click-to-Close:** Clicking on the background of any window in a group (e.g., the panel of a `UnitInspectionWindow`) closes all of its children, but not itself.
*   **Deselection on Open:** The action of opening any inspection window must immediately deselect any currently selected `GachaBallView`.
*   **Empty Slot Interaction:** An empty `SlotView` cannot be the source of an interaction. A click on an empty slot, with nothing else selected, must result in clearing the current selection state in the `InteractionManager`. This prevents the system from entering an invalid state where "emptiness" is selected.

**2. Contextual Interaction:**

The method for opening an inspection window is context-dependent:

*   **Double-Click:** Required to open an inspection window from any container where **drag-and-drop is the primary interaction**. This includes:
    *   The Battle Board (`PlayerLineup`, `PlayerBench`).
    *   The main Run Inventory and Battle Inventory windows.
*   **Single-Click:** Required to open an inspection window from any container that is **static and does not support drag-and-drop**. This includes:
    *   The item grid within a `UnitInspectionWindow`.
    *   The "EFFECTS" button/link within any inspection window.

**3. Positioning:**

*   **No Overlap:** A child window must never overlap the UI element of its direct parent. 
    *   A root window's anchor is the `SlotView` containing the `GachaBallView`, and the window should appear adjacent to it.
    *   A child window's anchor is its parent window, and it should be positioned adjacent to its parent.
*   **Dynamic Tracking:** All windows must dynamically track their anchor's position. If the anchor moves (e.g., a unit is moved on the board), the window must move with it.

**4. Example Flow (Equipped Item Inspection):**

1.  User double-clicks a Unit on the battle board. The `UnitInspectionWindow` opens.
2.  User single-clicks an equipped item inside the `UnitInspectionWindow`. The `ItemInspectionWindow` opens as a child.
3.  User single-clicks the "EFFECTS" link inside the `ItemInspectionWindow`. The `EffectInspectionWindow` opens as a child of the item window.
4.  At this point, the group is: `Unit -> Item -> Effect`.
5.  User now single-clicks the "EFFECTS" link on the original `UnitInspectionWindow`. 
    *   The `ItemInspectionWindow` and its child `EffectInspectionWindow` are closed.
    *   A new `EffectInspectionWindow` opens as a direct child of the `UnitInspectionWindow`.
    *   The group is now: `Unit -> Effect`.

### 4.5 UI Population Pattern: Persistent Slots

To ensure a stable, performant, and bug-free UI, views that display collections of items in a grid (such as `InventoryWindow` or `DiscardPileWindow`) must adhere to the "Persistent Slots" pattern.

#### The Problem to Avoid:
Constantly destroying (`queue_free()`) and recreating UI nodes for every data change is inefficient and leads to visual bugs, such as `GridContainer` reflowing, loss of state, and desynchronization between the view and the data model.

#### The Correct Pattern:
1. **One-Time Initialization**: When the window is first created, it should programmatically instantiate and add the required number of "slot" nodes (e.g., `SlotView.tscn`) to its `GridContainer`. These slot nodes are now persistent for the lifetime of the window.

2. **Content Update on Refresh**: When a UI refresh is required (e.g., after an inventory action), the window must not destroy the persistent slot nodes. Instead, it should:
   a. Iterate through its existing slot nodes.
   b. For each slot, clear any old content (e.g., a `GachaBallView` child).
   c. Look up the corresponding data for that slot's index in the data model.
   d. If the data slot contains an item, instantiate a new content view (e.g., `GachaBallView`) and add it as a child to the persistent slot node.

This pattern ensures that the UI's structure remains stable, preventing visual glitches and correctly reflecting the underlying data state at all times.

Part 5: Game Flows
### 5.1 In-Battle Instance Lifecycle
To ensure data integrity and prevent unnecessary object creation, the following rules govern how GachaBall instances are handled during a battle after the initial setup:

**No New Copies:** After the initial `battle_copy()` creation at the start of a battle, no further copies or clones of `GachaBall` instances are made. All subsequent operations manipulate the existing battle instances.

**Movement is a State Change:** "Moving" an instance (e.g., from bench to lineup, or inventory to discard) is achieved by changing the `location_container_tag` and `location_slot_index` properties on the instance itself, and updating the relevant `DataContainer` objects. The instance's `ball_uuid` remains the same for the duration of the battle.

**Item Salvage and Inheritance:** When a unit is defeated or used as a merge ingredient, its equipped items are not copied. The exact same item instances are transferred. Their `equipped_on_uuid` and `location` properties are updated to reflect their new state (either moved to the discard pile or re-equipped on a newly merged unit).

### 5.2 Battle Setup Flow
BattleManager creates battle_copy() instances from GameManager.run_state.run_instances and adds them to its _battle_instances dictionary.
It sets the initial location properties on each new copy (e.g., location_container_tag = "BATTLE_DRAW_POOL_T1").
For each new instance, it emits instance_created(new_uuid).
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
    b. Update the `result_instance`'s location properties to place it in the correct destination container and slot.
    c. Add the new instance's UUID to the master instance dictionary and the destination `DataContainer` (the index).
    d. For each ingredient, remove its UUID from its `DataContainer` and the master instance dictionary.
    e. For all inherited items, update their `equipped_on_uuid` property to point to the new `result_instance`.
3.  The data owner emits the necessary state change signals (`battle_inventory_changed` or `run_data_changed`).
Part 6: Localization & Sequence Diagrams
6.1 Localization System
Key-Based System: All user-facing text must be stored as keys in resource files.
Central File: A central localization.csv file will be used to store the key-value pairs.
Implementation: Text will be set in UI scripts using the tr() function.
6.2 Sequence Diagrams
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