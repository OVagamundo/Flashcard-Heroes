Flashcard Heroes - Technical Design Document (V5.1 - Definitive)
Part 1: Core Architecture & Principles
1.1 Architectural Principles
The Hybrid Architecture: Game logic is built on two pillars:
The Tag System: An object's identity, status, and location are defined by properties and tags on its GachaBallInstance resource. This defines what a thing is.
Relational Queries: Managers provide helper functions that understand game rules and context to answer complex questions about the relationships between objects. This defines how things relate to each other.
Data is the Source of Truth: The state of any game object is defined by the properties within its own data resource. Managers and UI are disposable reflections of this data.
The Effect Resolution Queue: All combat actions are processed through a LIFO (Last-In, First-Out) stack in BattleManager to ensure causality and interruptions are handled correctly and intuitively.
Separation of Run vs. Battle State: Persistent RunState data is never directly modified in a battle. Instead, temporary battle_copy() instances are created at the start of a battle and destroyed at the end. This is a critical firewall to protect permanent player progress.
Reactive UI: The UI listens for granular state change signals (e.g., instance_location_changed) and updates only the specific components affected.
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
GachaBallDefinition.gd: Resource, class_name GachaBallDefinition. The immutable template for a GachaBall.
Properties: @export var id: StringName, @export var display_name_key: String, @export var description_key: String, @export var icon: Texture2D, @export var tags: Array[StringName], @export var item_slot_count: int, @export var base_hp: int = 0, @export var base_pwr: int = 0
GachaBallInstance.gd: Resource, class_name GachaBallInstance. A unique, mutable instance of a GachaBall.
Properties: definition_id: StringName, ball_uuid: String, origin_uuid: String, static_tags: Array[StringName], dynamic_tags: Array[StringName], current_hp: int, current_pwr: int, location_container_tag: StringName, location_slot_index: int, equipped_on_uuid: String, equipped_slot_index: int
Methods: initialize(def: GachaBallDefinition), add_tag(tag: StringName), remove_tag(tag: StringName), has_tag(tag: StringName) -> bool, recalculate_stats(all_instances_db: Dictionary), create_battle_copy() -> GachaBallInstance
MergeRecipe.gd: Resource, class_name MergeRecipe.
Properties: @export var id: StringName, @export var ingredient_a_id: StringName, @export var ingredient_b_id: StringName, @export var result_id: StringName
EffectRequest.gd: Resource, class_name EffectRequest. A request to execute an ability, placed on the effect queue.
Properties: source_uuid: String, ability_id: StringName, trigger_context: Dictionary
AbilityDefinition.gd & EffectDefinition.gd: Define abilities and their executable effects.
2.2 Location Container Tags (location_container_tag)
These StringName values define all possible logical locations for a GachaBallInstance.
Run State Locations: RUN_INVENTORY_T1, RUN_INVENTORY_T2, RUN_INVENTORY_T3
Battle State Locations: BATTLE_DRAW_POOL_T1, BATTLE_DRAW_POOL_T2, BATTLE_DRAW_POOL_T3, BATTLE_PLAYER_LINEUP, BATTLE_PLAYER_BENCH, BATTLE_ITEM_INVENTORY, BATTLE_ENEMY_LINEUP, BATTLE_DISCARD_PILE
Special Location: An item is considered "located" if its equipped_on_uuid property is set, which overrides any container tag.
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
This architecture was chosen to solve the problems of data duplication and complex state management found in traditional container-based models. By making each instance the source of its own truth, we eliminate entire classes of bugs and create a more scalable and debuggable system. The combination of stateful tags and contextual queries provides the best of both worlds: simplicity and power.
3.4 Positional & Targeting Logic
This logic is implemented within BattleManager's relational query functions.
Player Team (Left Side): "Frontmost" corresponds to the unit with the highest location_slot_index (e.g., 5). "Backmost" is the lowest index (e.g., 0).
Enemy Team (Right Side): "Frontmost" corresponds to the unit with the lowest location_slot_index (e.g., 0). "Backmost" is the highest index (e.g., 5).
Action Order: The standard combat action order for both teams is back-to-front (index 5 down to 0).
3.5 The Effect Resolution Queue
This system, managed by BattleManager, governs the flow of combat. It uses a LIFO (Last-In, First-Out) stack to ensure that interruptions and reactions (like a "retaliate on hit" ability) are processed immediately after the event that caused them, creating an intuitive and predictable chain of events.
Population: When the COMBAT phase begins, BattleManager creates an EffectRequest for each unit's action and pushes it onto the _effect_queue stack.
Processing Loop: The BattleManager's _process function contains a loop that pops one request from the stack, awaits its resolution via the AbilityResolver, and then repeats until the queue is empty.
Chain Reactions: Any ability that triggers another effect creates a new EffectRequest and pushes it to the top of the stack, ensuring it is resolved next.
Part 4: Presentation Layer (UI)
4.1 UI Component Blueprints
GachaBallView.tscn / SlotView.tscn:
Metadata: Must store the ball_uuid: String of the instance it represents.
Behavior: Listens for instance_* signals to update its appearance and position.
DiscardPileWindow.tscn: A modal window opened by WindowManager in response to display_discard_pile_requested.
4.2 Window Management & UI Patterns
Hierarchical Closure: Clicking on a window's background closes only the windows stacked on top of it, not the window itself.
Click-Through on Closure: The click that closes a window is not consumed. This creates a seamless, responsive feel where no click is "wasted," which is a core part of the game's UX philosophy. WindowManager is responsible for this two-step (close, then re-process input) behavior.
Dynamic Mouse Filter Pattern: For RichTextLabels with clickable links, the mouse_filter must be dynamically changed from PASS to STOP on meta_hover_started and back on meta_hover_ended.
4.3 Player Interaction Scenarios
Design Rationale: Interaction rules are separated for "In-Battle" and "Out-of-Battle" states because their consequences are fundamentally different. In-battle actions modify temporary _battle_instances, while out-of-battle actions modify the permanent run_instances. This separation is critical to the game's core loop.
Table 4.3.1: In-Battle Interactions (is_in_battle == true)
Player Action	Conditions	Resulting Logic Flow
Drop Unit on Unit	Merge recipe exists.	InventoryManager shows ChoiceWindow. Player choice re-sends inventory_action_requested with explicit_action: "MERGE" or "SWAP".
Drop Unit on Unit	No merge recipe.	Swap their location_slot_index properties.
Drop Item on Unit	Unit has empty item slot.	Change item's equipped_on_uuid and equipped_slot_index.
Drag Item off Unit	Target is empty Item Inv. slot.	Unequip: Change item's location_container_tag to BATTLE_ITEM_INVENTORY and clear equipped_on_uuid.
Table 4.3.2: Out-of-Battle Interactions (is_in_battle == false)
Player Action	Conditions	Resulting Logic Flow
Drop Instance on Instance	Merge recipe exists.	InventoryManager shows ChoiceWindow. The chosen action is routed to RunState to modify the permanent instances.
Drop Instance on Instance	No merge recipe.	Swap their location_slot_index within the same RUN_INVENTORY_T* container.
### 4.4 Inspection Window System: Rules and Behavior

This section defines the precise, authoritative rules for how all inspection windows (Unit, Item, Effects) must behave. These rules ensure a consistent, intuitive, and robust user experience.

**1. Core Principles:**

*   **Single Active Group:** There can only be one active inspection window "group" (a chain of parent-child windows) on the screen at any time. Opening a new root-level window (e.g., inspecting a different unit on the board) must close the entire previous group.
*   **Single Child Per Parent:** A parent window can only have one direct child window open at a time. Requesting a new child window must first close any existing child and its descendants.
*   **Hierarchical Closing:** Clicking on any window in a group closes all of its children. For example, clicking the background of a `UnitInspectionWindow` must close its child `ItemInspectionWindow` and that window's child `EffectInspectionWindow`.
*   **Deselection on Open:** The action of opening any inspection window must immediately deselect any currently selected `GachaBallView`.

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

Part 5: Game Flows
5.1 Battle Setup Flow
BattleManager creates battle_copy() instances from GameManager.run_state.run_instances and adds them to its _battle_instances dictionary.
It sets the initial location properties on each new copy (e.g., location_container_tag = "BATTLE_DRAW_POOL_T1").
For each new instance, it emits instance_created(new_uuid).
5.2 Gacha Draw Flow
BattleManager receives draw_gacha_requested(tier_tag).
It queries _battle_instances for instances with location_container_tag == "BATTLE_DRAW_POOL_[tier_tag]".
If the pool is empty, it reshuffles by finding instances in the BATTLE_DISCARD_PILE and changing their location properties back to the draw pool.
It picks a random instance and changes its location properties to an available slot in BATTLE_PLAYER_BENCH or BATTLE_ITEM_INVENTORY.
It emits instance_location_changed(drawn_uuid).
5.3 Merge Flow
InventoryManager receives inventory_action_requested for a merge.
It instructs the appropriate data owner (RunState or BattleManager) to:
Create a new result_instance.
Item Handling (In-Battle Only): Re-assign equipped items from ingredients to the new result_instance.
Set the location properties on the new instance.
Destroy the two ingredient instances.
It emits instance_created(result_uuid) and instance_destroyed(uuid) for both ingredients.
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
    IM->>BM: Create new instance from definition
    IM->>BM: Re-assign equipped items to new instance
    IM->>BM: Destroy old instances from _battle_instances
    IM->>BM: Set location properties on new instance
    BM-->>UI: instance_created(new_uuid), instance_destroyed(old_uuid), instance_location_changed(item_uuids)
    UI-->>UI: Redraw relevant views