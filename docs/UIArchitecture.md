# UI Architecture

> [!IMPORTANT]
> **Core Principle:** Simulation and Presentation are completely independent. The TurnLog is their ONLY connection.

---

## 1. Scene Hierarchy

```
Main.tscn (Shell)
├── TopBar (Gold, Tokens, Day)
├── SubViewport → Battle.tscn (Board)
│   ├── PlayerArea (Lineup, Bench, ItemInventory)
│   └── EnemyArea (Lineup, TrinketBar)
├── BottomBar (Gacha Machines)
└── ModalLayer → FlashcardMinigame.tscn (Hermetic Modal)
```

---

## 2. Layout Rules

| Element | Size | Notes |
|---------|------|-------|
| Battle slot | 192x192px | 2x scale, units 128x128 centered |
| Inventory slot | 192x192px | Glass overlay, unit 128x128 centered |
| TopArea trinket slot | 90px height | Compact |
| Gacha machines | 260px height | Fixed bottom bar |
| Top gap spacer | 80px | Injected at runtime by BattleView |

**Critical:** `BattleView._initialize_slots()` overrides scene placeholders with SlotViews. Always set `custom_minimum_size` on slots, not `set_size_scale()`.

---

## 3. Combat Presentation (VCR)

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
> During blocked phases, `_redraw_board()` returns immediately to prevent destroying the `_visual_registry`.

### Position Data Rule
Animations must use `animator.get_snapshot_position(uuid)`, never query `_visual_registry` for positions.

---

## 4. SlotView Internals

- **Background:** `StyleBoxTexture` with `slot.png` (not a child node)
- **Reason:** Prevents cleanup scripts from destroying background
- **Tinting:** `StyleBoxTexture.modulate_color` based on container type

---

## 5. Z-Order (GachaBallView)

1. Unit Sprite (128x128 centered, inside `VBoxContainer`)
2. Equipped Items Wrapper (Left-aligned overlay)
3. Stats Overlay (HP/PWR labels, Status Effects)
4. Selection Ring (white outline shader)

---

## 6. Selection Feedback

- **Animation:** Physics-based hop (bounce + squash/stretch)
- **Highlight:** White outline shader (`outline_width=3.0`)
- **Source:** All views subscribe to `SignalBus.view_selected`
