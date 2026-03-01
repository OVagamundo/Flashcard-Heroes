# Zero Assumption Blueprint: Physics-Based Inventory Refactor

## 1. Goal of the Refactor

The fundamental goal of this refactor is to provide a purely visual, read-only physics simulation of the inventory specifically during Battles (battle inventory). The rigid `InventoryGrid` UI will be replaced by an organic simulation of gachaballs falling into dimensional containers (Suika-game style) ONLY when in the Battle scene. Outside of battle, the existing manipulatable grid inventory remains actively used.

The new system must prioritize explicit mechanical clarity. It enforces strict 1x scaling for inventory items, prevents items from escaping their designated bounds, and precisely hooks into the 3-second physical overflow penalty. It acts as a strictly read-only view for observing items: players can hover and click to inspect items using the exact same global interaction rules natively present for standard slots, but dragging, swapping, moving, merging, and equipping are completely disabled within this specific physics inventory.

---

## 2. Definitive Mechanics and Behaviors

The following rules constitute the definitive, affirmative behavior of the physics inventory. No assumptions or deviations are permitted.

### Core Architecture & Visuals
* **Physics Framework**: The `InventoryGrid` is fully replaced by `RigidBody2D` balls operating inside physical containers bounded by thick, invisible walls.
* **1x Scale Constraint**: Gachaballs within the inventory are strictly forced to 1x scale (native size) and do not display UI overlays (stats/pwr).
* **Visual Margin Alignment**: The source texture (`gachaballcapsule.png`) is exactly 96x96 pixels (Radius 48px). The `CircleShape2D` physics collider radius is explicitly set to 50px. The 2px margin prevents visual clipping when physical bodies collide.
* **Engine Determinism Constraints**: `Physics Ticks Per Second` is forced to 120, interpolation is enabled, friction is 0.8, and bounce is 0.0 to prevent rolling "boil".

### Spawning & Drag Constraints
* **Origin Spawning**: When a ball is added to the inventory (via Shop purchases, merging, or invalid drop teleport), it must spawn at the exact top-center coordinate of its specific Tier Container.
* **Staggered Reshuffle Routine**: When a Discard Pile Reshuffle occurs, the missing gachaballs must spawn sequentially (one by one) to safely fill the container without overlapping physics bodies bursting.
* **Drawing Exhaustion**: Drawing a gachaball strictly removes it from the inventory.

### Read-Only Interaction & Inspection Windows
* **Hover-to-Inspect**: Hovering over a gachaball opens its inspection window, operating exactly identically to the standard global UI behavior.
* **Standard Select-to-Lock**: Clicking a gachaball selects it and locks the inspection window open, operating identically to the standard UI behavior since no secondary actions (like merges or swaps) are valid in this view.
* **Disabled Mechanics (Read-Only)**: The physics inventory is a purely observational tool. It completely disables all physical and logical item manipulation:
  * No Dragging or Moving
  * No Swapping
  * No Merging
  * No Equipping
* **Deselection & Window Closing Rules**: Standard global window management rules apply. Clicking a non-target or clicking outside windows closes all active windows and deselects current items.

### Animation, Context Persistence & Container Hierarchy
* **Context Exclusivity**: The physics inventory is exclusively utilized during Battle scenes, where its instantiated contents remain persistent and continue simulating even when the window is closed and hidden. Outside of battle, the game reverts back to using the standard, manipulatable `InventoryGrid` UI.
* **Separated Visual Hierarchy**: The inventory uses a persistent inner bucket (`SlidingContainer`) that holds the physics boundaries. The foreground is a static `BaseMask` that remains completely fixed, hiding the sliding container behind it when closed.
* **Per-Tier Containment Limits**: The invisible walls holding the balls in each container exclusively interact with their specific tier of gachaballs using precise Collision Layers and Masks to support the tight visual stacking without cross-tier interference.

### The Penalty Mechanic
* **The Spring Lid**: Every container features a physical lid. When balls push against it into the Overflow area, the lid physically springs up.
* **3-Second Expiration (Lid Contact)**: The "overflow state" is strictly defined as continuous physical contact with the lid body itself. If a ball maintains contact with the lid for 3 continuous seconds, an `inventory_instance_removed_penalty` signal fires and the core Data layer destroys the ball.
 Supplementary Context for AI Agents

To assist secondary AI agents in implementing this framework, a master context file containing the complete, unedited source code of all relevant systems has been automatically generated. 

**Compiled File:** `docs/PhysicsInventoryContext.md`

**Dependencies Included:**
1. `project.godot` (Physics & Layers)
2. `scenes/Main.tscn` / `scripts/Main.gd`
3. `scripts/GameManager.gd`
4. `scripts/SignalBus.gd`
5. `scripts/Constants.gd`
6. `scripts/InteractionContext.gd`
7. `scripts/GlobalInteractionRouter.gd`
8. `scripts/SlotView.gd` / `scenes/SlotView.tscn` (Legacy Drag Reference)
9. `scripts/InventoryManager.gd`
10. `scripts/MergeManager.gd`
11. `scripts/MergeRecipe.gd`
12. `scripts/BattleManager.gd`
13. `scripts/RunState.gd`
14. `scripts/VisualDataAdapter.gd`
15. `scripts/GachaBallView.gd` / `scenes/GachaBallView.tscn`
16. `scripts/InventoryWindow.gd` / `scenes/InventoryWindow.tscn` (Contains logic for legacy Tier 1-3 population)
17. `scripts/ChoiceWindow.gd` / `scenes/ChoiceWindow.tscn`
18. `scripts/WindowManager.gd`
