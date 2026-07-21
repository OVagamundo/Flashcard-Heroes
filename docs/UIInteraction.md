# UI Architecture & Interaction System

> [!IMPORTANT]
> **Core Principle:** Simulation and Presentation are completely independent. The TurnLog is their ONLY connection. **GIR (Global Interaction Router)** interprets all input. **WindowManager** executes commands. Views only emit `InteractionContext`.

---

## 1. Scene Hierarchy & Layout Rules

```
Main.tscn (Shell)
├── ContentArea → SubViewportContainer → SubViewport
│   └── SceneBackground (1920x1080)
│   └── VBoxContainer (Centering Layout)
│       ├── TopAreaSpacer (144px)
│       ├── SceneSlot (BattleBoard / Flow)
│       └── BottomAreaSpacer (260px)
├── HUDLayer (CanvasLayer - Layer 60)
│   ├── TopArea (Gold, Tokens, PlayerTrinketBar)
│   └── BottomArea (Gacha Machines x3, Labels)
├── BackgroundUILayer (CanvasLayer - Layer 40)
│   ├── InventoryWindow
│   └── DiscardPile
├── ModalLayer (CanvasLayer - Layer 120)
│   └── Inspection Windows, Popups, Tutorials
├── EffectsLayer (CanvasLayer - Layer 90)
├── GlobalVFXLayer (CanvasLayer - Layer 150)
└── CursorLayer (Software Overlay - Layer 1024)
```

| Element | Size | Notes |
|---------|------|-------|
| Battle slot | 192x192px | 2x scale. Opaque background (Alpha 1.0). Units positioned to stand on the floor. |
| Inventory slot | 192x192px | Glass overlay, unit 128x128 centered |
| TopArea trinket slot | 128x128px | Standard icon size |
| Gacha machines | 260px height | Fixed bottom bar |
| Top gap spacer | 144px | Defines the HUD vertical boundary |
| Title Screen Buttons | - | 50px offset towards bottom to clear logo. |

**Critical:** `BattleView._initialize_slots()` overrides scene placeholders with SlotViews.
### GachaBall Animation & Spawning
The game uses two distinct methods for GachaBall movement:
1. **Draw Animation (Machine → Bench)**: When a player spends tokens, the ball animates along a Catmull-Rom spline starting from the **specific GachaMachine's knob position** and ending at the target `SlotView`.
2. **Elite Summon (World → HUD)**: When an Elite unit summons a minion directly to the inventory, it uses the **Kinematic Projectile Standard**. The ball grows from 0.3x to 1.5x instantly at launch to maximize impact.
3. **Pool Population (Top-down Gravity)**: Inside the Physics Drawers (Battle Inventory/Discard), balls spawn at the **top-center** with a random X-stagger and fall naturally. Spawning is sequential (0.15s interval) to prevent overlap explosions.

### Kinematic Projectile Standard
For high-fidelity transitions involving screen-space movement (Gacha Draws, Elite Summons), the system uses a **Kinematic Projectile** model instead of standard Bezier curves:
- **Linear Horizontal Velocity**: $X = \text{lerp}(start, end, t)$. This ensures constant movement speed across the screen.
- **Parabolic Vertical Arc**: $Y = \text{lerp}(start, end, t) - (4.0 \cdot H \cdot t \cdot (1.0 - t))$. This simulates uniform gravitational acceleration, where $H$ is the peak arc height.
- **Visual Impact**: Transitions land with a frame-synchronous impact (machine bounce or landing squash) and matching audio hooks.

### Visual-Driven Inventory Counters
To ensure the UI presentation remains completely decoupled from the instantaneous logical model data, the Gacha Machine UI counters (`x3`, etc.) are **Visual-Driven**:
1. They are NOT tied to `run_data_changed` or `battle_inventory_changed` signals.
2. They increment or decrement *exactly* when the `GachaBallView` animations (drawing or returning) impact the machine visually, utilizing `animate_machine_inventory_change(tier, amount)`.
3. To prevent permanent desynchronization, the counters are hard-snapped to the actual model data strictly during **Screen Transitions** (entering Battle, Shop, Rewards, Map, etc.).


- **Scaling**: All slots maintain their 192px baseline asset scale.

---

## 2. Interaction & Selection Rules

| Rule | Description |
|------|-------------|
| **S1** Singleton | Only one entity selected at a time |
| **S2** Change of Focus | Click on non-target = move selection |
| **S3** Selection-Only | Shop/Rewards: any click = change focus |
| **S4** Re-Selection | Click selected item = lock inspection window |
| **S5** Hover-to-Inspect | Hovering an entity transiently opens its inspection window (PC only) after a 1-second dwell-time delay. Hover is **disabled** during VCR playback and Combat phases to prevent conflicts; players must explicitly click to inspect during animations. |
| **S5a** Touch Peek | On touch devices, long-press temporarily opens inspection; release closes it unless the interaction is promoted by a tap/selection flow |
| **S6** Select-to-Lock | Single click selects entity. If no action is generated, the inspection window locks open. |
| **S7** Deselect on Action | Any `REQUEST_ACTION` immediately clears selection |
| **S8** Hover Boundary | When a base inventory is open, hovers outside it are blocked |
| **S9** Locked Inspection| Status effect keywords in descriptions can be clicked to "lock" their inspection window open. Clicking outside or re-toggling closes it. |
| **S10** Outcome Preview | Merge/Swap modals display a visual preview of the resulting unit/item to provide clear feedback before confirmation. |
| **S11** Source-Aware Inspection | Unit and Item inspection windows now expose the underlying component stack. Components (Stats, Abilities, Tags, Visuals) are displayed with their source (Base Definition, Equipment, Merge Inheritance, Rarity, etc.). Modules can be clicked for nested inspection. |

---

## 3. Window Management Rules

| Rule | Description |
|------|-------------|
| **W1** Hierarchical | One window chain at a time, one child per parent |
| **W2** Click-Through | Click outside windows = close all + select new target |
| **W3** Pruning | Click window background = close descendants only |
| **W4** Global Close | Click non-interactive area = close all + deselect |
| **W5** Escape | 1) Cancel drag → 2) Close windows → 3) Deselect |
| **W6** Selection Persist | Parent entity stays selected when opening child windows |
| **W7** Contextual Freeze | Locking an inspection window pauses the game state ONLY during battle contexts (normal, elite, boss) to allow VCR freeze. Outside of battle, inspecting does not freeze the game. |
| **W8** Transition Block | Interaction is completely blocked during drawer/inventory animations (Open/Close) |
| **W9** Bounce Animation | Windows open with a subtle scale overshoot (bounce) and vanish instantly on close |

### Window Categories

| Type | Examples | Blocker | Behavior |
|------|----------|---------|----------|
| **Hermetic Modals** | FlashcardMinigame, EndBattlePopup | Yes | Blocks all input, self-closing |
| **Contextual (Dynamic)** | UnitInspection, ItemInspection, TutorialOverlay | No | Positioned adjacent to anchor. Uses **"Show-before-Measure"** (alpha 0.0 for 3 frames) to ensure physical shrinking before positioning. Plays bouncy overshoot (1.0 -> 1.04 -> 1.0) and closes instantly (`queue_free`). Features standardized **32px Black Composite** fonts and `ItemSlot.png` for unit item grids. **Source-Aware**: Unit inspections show every active source of modification (StatComponents, AbilityComponents, etc.). |
| **Contextual (Fixed)** | InventoryWindow, DiscardPile, MergeModal | No | Centered, closes on outside click. Merge modals feature **Result Previews**. |

### Window Layout & Sizing
To prevent persistent layout "bloat" and ensure windows correctly shrink to their content:
1. **Show-before-Measure**: `WindowManager` makes windows visible with `modulate.a = 0.0` immediately upon creation and moves them to `Vector2(-2000, -2000)`. This prevents them from intercepting mouse events for on-screen units while forcing Godot to calculate the shrunk layout size.
2. **Settling Delay**: Positioning is deferred for 3 frames to allow the window's internal layout to resolve.
3. **Immediate Pruning**: Dynamic lists (like unit item grids) must call `remove_child()` immediately followed by `queue_free()` to avoid deferred deletion delays that cause incorrect sizing measured by the parent.

### Window Rendering & Z-Order
To ensure absolute visibility of contextual information, all windows managed by `WindowManager` (Modals, Tutorials, and Inspection Windows) are assigned a **`z_index = 100`** upon instantiation.
- **Rationale**: Prevents local UI elevations—such as `GachaBallView` raising its local `z_index` to 40 during hover—from occluding the inspection window.
- **Layer**: All windows reside on the `ModalLayer` (`CanvasLayer`), which identifies them as globally prioritized UI elements (Layer index 120).

### Standardized Layering Policy
The application maintains a strict four-tier UI hierarchy to resolve all occlusion issues:
1. **BackgroundUILayer (40)**: Persistent inventory windows (Run/Battle) and Discard Pile.
2. **HUDLayer (60)**: Gacha Machine textures, count labels, and top/bottom panel buttons.
3. **GlobalVFXLayer (150)**: High-priority currency animations (Gold Gain/Spend) and global transitions. Resides above all modal UI to ensure visibility.
4. **ModalLayer (120)**: Inspection windows, pop-ups, tutorials, and minigames.
*Note: This ensures the "physical" UI (Inventory) slides out behind the Gacha Machines, while pop-ups always render on top of both, and global effects (coins) fly above everything.*

---

## 4. Animation Playback Architectures

The game uses two distinct architectures for handling visual animations depending on the phase.

### 4.1 Sequential Combat Presentation (VCR)
During Combat (`COMBAT`, `START_OF_TURN`, `END_OF_TURN`), the game uses a strict VCR pattern to preserve causal history:
1. "Battle!" Button Pressed (End Turn) → Simulation runs instantly → TurnLog generated
2. `BattleAnimator.play_turn_sequence()` plays the TurnLog sequentially.
3. Views operate in **Puppet Mode** - only react to Animator signals, waiting for each event to finish before the next begins.

### 4.2 Parallel Management Phase Animations
During the `MANAGEMENT` phase, interactions (like Drawing units from the Gacha or Merging) do NOT use the TurnLog.
1. UI triggers an action (e.g., clicking Draw).
2. Simulation generates a localized event chain (`chain_events`).
3. `BattleAnimator.play_async_chain()` is called asynchronously without blocking the UI thread.
4. **Parallel Execution:** Rapid interactions (like spam-clicking Draw) fire off concurrent chains, allowing visual animations to overlap and play in parallel instead of queuing sequentially.

### Blocking Phases
| Phase | UI Status |
|-------|-----------|
| `MANAGEMENT` | ✅ Interactive |
| `COMBAT`, `START_OF_TURN`, `END_OF_TURN` | ❌ Blocked |

> [!CAUTION]
> During blocked phases, `_redraw_board()` returns immediately to prevent destroying the `_visual_registry`. All interaction contexts are ignored, drags cannot start, and Escape actions are blocked.

### Position Data Rule
Animations must use `animator.get_snapshot_position(uuid)`, **never query `_visual_registry` for positions.**

### 4.4 Playback Controls

The `CombatControlsPanel` provides real-time interaction with the `BattleAnimator`:
- **Speed Toggles (1x, 2x, 4x)**: Updates `AnimationConstants.speed_factor`. These buttons use a "Radio Button" style (only one active at a time) and reflect the current global state upon room entry.
- **Step Button**: Immediately pauses playback and enters "Step Mode". If already in Step Mode, it advances the animator by exactly one `CombatEvent`.
- **Center Alignment**: To prevent overlap with Trait labels, these controls are anchored to the bottom-center of the screen.

---

## 5. View Internals & Rendering

### 5.1 High-Performance Hybrid Cursor
The application uses a **High-Performance Hybrid Cursor** system managed by `CursorManager.gd`:
- **Implementation**: A dedicated `CanvasLayer` (Layer 1024) renders a `Sprite2D` on top of all other UI.
- **Zero-Latency Movement**: `Input.use_accumulated_input` is disabled. This allows the software sprite to track at the hardware polling rate (e.g. 1000Hz) instead of being throttled by the game's frame rate.
- **Raw Input Tracking**: Position and texture swaps are handled directly in `_input(event)` for sub-frame response, bypassing the standard `_process` frame delay.
- **Stationary Click-Fix**: Texture swaps occur immediately upon the OS-level button event, ensuring click visuals change even if the mouse is perfectly still.
- **Hardware Mode**: The physical system cursor is hidden (`MOUSE_MODE_HIDDEN`).

### SlotView
- **Background:** `StyleBoxTexture` with `slot.png` (not a child node) to prevent cleanup scripts from destroying it.
- **Tinting:** `StyleBoxTexture.modulate_color` based on container type.

### GachaBallView Z-Order
1. Unit Sprite (128x128 centered, inside `VBoxContainer`)
2. Equipped Items Wrapper (Left-aligned overlay)
3. Stats Overlay (HP/PWR labels, Status Effects)
4. Selection Ring (white outline shader)

### Physics GachaBall Visuals
- **Structure**: `RigidBody2D` with `CapsuleSprite` (outer shell) and `IconSprite` (inner unit/item icon).
- **1x Scale**: Gachaballs in the inventory are strictly forced to 1x scale and do not show stat/pwr overlays.
- **Highlighting**: On selection, both sprites scale up (1.08x) and the capsule modulates to a brighter color (1.3x).

### Physics Inventory & Discard Pile (Battle Only)
- **Persistence**: The physics simulation persists and continues running even when the drawer is closed/hidden. No "kinematic freeze" is required; standard Canvas Layer 2D Physics handles the translation of RigidBody2D nodes along with their parent Control.
- **Hierarchy & Movement**:
    - **Battle Inventory**: Slides **vertically** from below.
    - **Discard Pile**: Slides **horizontally** from the right.
- **Inescapable Boundaries**: Side walls are **5000px thick** and extend infinitely to prevent tunneling or escaping during high-velocity drawer animations.
- **Interaction Rules**:
    - **Hover-to-Inspect**: Opens temporary window (PC).
    - **Touch Inspect**: Uses long-press (`0.32s`) with drag cancellation at `24px`, shared via `InputUtils.gd`.
    - **Rule S8 (Hover Boundary)**: If an inventory window is open, hovers originating from the background battle board are blocked to prevent accidental window closure.
    - **Click-to-Select**: Locks window open.
    - **All Other Input Blocked**: No dragging, clicking, or double-clicking is permitted within physics containers.
    - **39-Item Constraint**: Spawning/Logic uses `GrowableGridContainer(24)` as a baseline but does NOT enforce a hard numerical cap. Overflow is managed entirely by physics (see lid rule).

### Staggered Grid (Run Inventory ONLY)
The Run Inventory uses the `StaggeredGridContainer` for a compact, circular-optimized layout.
- **Geometry**: A hexagonal/honeycomb pattern where even-numbered rows are offset by half a slot's width.
- **39-Slot Capacity**: Perfectly sized to display 39 slots ($4 \times 6$ and $3 \times 5$) без scrolling.
- **Separation**: `v_separation` is calculated as $SlotHeight \times 0.75$ to allow circular caps to nest perfectly.
- **Alignment**: Uses `bottom_to_top = true` to fill from the base of the container.
- **1x Scale**: Gachaballs are fixed at `1.0` scale to maximize grid density.

### Touch Input Adapter
- **Single Gate**: [InputUtils.gd](../scripts/InputUtils.gd) is the only approved touch/mouse routing helper.
- **Desktop Parity Rule**: Mobile fixes must stay behind `prefers_touch_input()` and must not alter the desktop mouse path unless the behavior is intended for both platforms.
- **Consumption Rule**: Touch presses on windows/background blockers must explicitly consume the event to avoid the same tap falling through into global-close handlers.

### Determinism & Performance
- **Physics Ticks**: Forced to **120 TPS** for collision stability.
- **Determinism**: Interpolation enabled; friction (0.05) and bounce (0.15) are tuned to ensure stability while maintaining life in the gachapon balls.

### Drawer Animation Physics
The inventory drawer movements are synchronized with physical jolts:
- **Upward Slam (Battle Inventory)**: Triggered at the end of the "Open" animation.
- **Downward Drop (Battle Inventory)**: Triggered at the start of the "Close" animation.
- **Horizontal Movement (Discard Pile)**: The drawer persists state and populates *before* opening to match Battle Inventory behavior.
- **Implementation**: `WindowManager` calls `apply_jolt(base_impulse)` on the `PhysicsTierContainer` nodes.
- **State Query**: `WindowManager.is_any_inventory_window_open()` is used by GIR to enforce interaction boundaries.

### Selection Feedback
- **Animation:** Physics-based hop (bounce + squash/stretch)
- **Highlight:** White outline shader (`outline_width=3.0`)
- **Source:** All views subscribe to `SignalBus.view_selected`

### 5.5 Interactive Overlays
To streamline interactions in Reward, Shop, and Black Market scenes, the game uses **Interactive Overlays** instead of modal choice windows.
- **Implementation**: Managed programmatically by `Main.gd` and synchronized with inventory window states.
- **Mode 1: Get or Sell Drop Zones**: Both standard Reward and Elite Reward scenes implement a split action layout consisting of a **Collect ("Get")** zone and a **Sell** zone.
  - **Standard Rewards**: Items can be collected or sold for their base tier value.
  - **Elite Rewards**: Selling grants a flat premium of **10 Gold**.
  - **Auto-Collection**: Trying to leave the scene with rewards still on board automatically triggers sequential collection of all remaining items to prevent player loss.
- **Mode 2: Split Action Zones**: Two side-by-side zones used for the Black Market ("Transform" / "Remove").
- **Native Drag-Drop**: All overlays use `DropZone.gd` to integrate with Godot's built-in drag-and-drop system. This prevents "snap-back" glitches by reporting successful drops to the engine.
- **VFX Proxy Pipeline**: To ensure fluid visuals during gold-spending animations, a static "proxy" view of the gachaball is spawned at the drop point until the financial transaction completes and the final movement animation begins.
- **UI Context**: Overlays are anchored to the `BottomArea` and render on the `HUDLayer` (Z-index 5) to ensure they are always accessible above machine bases.
- **Input Flow**: Supports both **click-to-click** (click item -> click zone) and **drag-and-drop** (drag item -> drop on zone) interchangeably.

---

## 6. Functional Groups & APIs

```gdscript
# Container → Group mapping (GlobalInteractionRouter.get_context_group)
PlayerLineup, PlayerBench → BattleBoard
RunInventoryT*, BattleInventoryT* → InventoryGrid
equipped_item → EquippedGrid
Rewards, Shop → SelectionOnly
EnemyLineup, DiscardPile, PlayerTrinkets → InspectionOnly
```

### Suppression Windows
For Swap/Merge via ChoiceWindow:
1. Resolve anchor view from target location
2. Find ancestor window via `find_ancestor_window_for_view()`
3. Call `GIR.activate_close_suppression_for_window_id(id, duration)`
4. Duration: 420ms for unit-context, 320ms otherwise

### Key APIs
| API | Purpose |
|-----|---------|
| `WindowManager.open_child_contextual_window()` | Open anchored child window |
| `WindowManager.handle_inspection_background_click()` | Local prune (W3) |
| `WindowManager.find_ancestor_window_for_view()` | Resolve owning window |
| `GIR.get_context_group()` | Get functional group for container |
