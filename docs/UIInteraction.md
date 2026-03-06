# UI Architecture & Interaction System

> [!IMPORTANT]
> **Core Principle:** Simulation and Presentation are completely independent. The TurnLog is their ONLY connection. **GIR (Global Interaction Router)** interprets all input. **WindowManager** executes commands. Views only emit `InteractionContext`.

---

## 1. Scene Hierarchy & Layout Rules

```
Main.tscn (Shell)
├── VBoxContainer
│   ├── TopArea (Gold, Tokens, Day, PlayerTrinketBar)
│   ├── ContentArea → SubViewport → Battle.tscn (Board)
│   │   ├── PlayerArea (Lineup, Bench)
│   │   └── EnemyArea (Lineup, Traits)
│   └── BottomArea (Physics Gacha Machines 1-3)
├── EffectsLayer (VFX)
└── ModalLayer (Managed by WindowManager)
```

| Element | Size | Notes |
|---------|------|-------|
| Battle slot | 192x192px | 2x scale, units 128x128 centered |
| Inventory slot | 192x192px | Glass overlay, unit 128x128 centered |
| TopArea trinket slot | 128x128px | Standard icon size |
| Gacha machines | 260px height | Fixed bottom bar |
| Top gap spacer | 80px | Injected at runtime by BattleView |

**Critical:** `BattleView._initialize_slots()` overrides scene placeholders with SlotViews. Always set `custom_minimum_size` on slots, not `set_size_scale()`.

---

## 2. Interaction & Selection Rules

| Rule | Description |
|------|-------------|
| **S1** Singleton | Only one entity selected at a time |
| **S2** Change of Focus | Click on non-target = move selection |
| **S3** Selection-Only | Shop/Rewards: any click = change focus |
| **S4** Re-Selection | Click selected item = lock inspection window |
| **S5** Hover-to-Inspect | Hovering an entity transiently opens its inspection window (PC only) |
| **S6** Select-to-Lock | Single click selects entity. If no action is generated, the inspection window locks open. |
| **S7** Deselect on Action | Any `REQUEST_ACTION` immediately clears selection |
| **S8** Hover Boundary | When a base inventory is open, hovers outside it are blocked |

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

### Window Categories

| Type | Examples | Blocker | Behavior |
|------|----------|---------|----------|
| **Hermetic Modals** | FlashcardMinigame, EndBattlePopup | Yes | Blocks all input, self-closing |
| **Contextual (Dynamic)** | UnitInspection, ItemInspection | No | Positioned adjacent to anchor |
| **Contextual (Fixed)** | InventoryWindow, DiscardPile | No | Centered, closes on outside click |

---

## 4. Combat Presentation (VCR)

### Flow
1. End Turn → Simulation runs instantly → TurnLog generated
2. BattleAnimator plays TurnLog sequentially
3. Views operate in **Puppet Mode** - only react to Animator signals

### Blocking Phases
| Phase | UI Status |
|-------|-----------|
| `MANAGEMENT` | ✅ Interactive |
| `COMBAT`, `START_OF_TURN`, `END_OF_TURN` | ❌ Blocked |

> [!CAUTION]
> During blocked phases, `_redraw_board()` returns immediately to prevent destroying the `_visual_registry`. All interaction contexts are ignored, drags cannot start, and Escape actions are blocked.

### Position Data Rule
Animations must use `animator.get_snapshot_position(uuid)`, **never query `_visual_registry` for positions.**

---

## 5. View Internals & Rendering

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
- **Inescapable Boundaries**: Side walls are ~2000px thick and extend infinitely to prevent tunneling or escaping during high-velocity drawer animations.
- **Interaction Rules**:
    - **Hover-to-Inspect**: Opens temporary window (PC).
    - **Rule S8 (Hover Boundary)**: If an inventory window is open, hovers originating from the background battle board are blocked to prevent accidental window closure.
    - **Click-to-Select**: Locks window open.
    - **All Other Input Blocked**: No dragging, clicking, or double-clicking is permitted within physics containers.

### Determinism & Performance
- **Physics Ticks**: Forced to **120 TPS** for collision stability.
- **Determinism**: Interpolation enabled; friction (0.8) and bounce (0.0) are tuned to prevent "boiling" (jittering while at rest).

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

