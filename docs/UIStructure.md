# Scene & UI Architecture Reference

This document defines the structural relationship between the main game scenes.

## 1. Global Hierarchy

The game is composed of three distinct layers. Understanding this hierarchy is critical for correctly locating UI elements.

```mermaid
graph TD
    Main[Main.tscn (Shell)] --> Viewport[SubViewport]
    Viewport --> Battle[Battle.tscn (Board)]
    Main --> Overlay[FlashcardMinigame.tscn (Modal)]
```

### A. Main.tscn (The Shell)
**Path:** `res://scenes/Main.tscn`
**Role:** Persistent container for the run.
**Contains:**
*   **Top Bar:** Global resources (Gold, Tokens, Day).
*   **Viewport Container:** The window into the game world.
*   **Bottom Bar:** The Gacha Machines (260px fixed height).

### B. Battle.tscn (The Board)
**Path:** `res://scenes/Battle.tscn`
**Role:** The gameplay area instantiated *inside* `Main.tscn`'s viewport.
**Contains:**
*   **Unit Grids:** Player and Enemy lineups.
*   **Benches:** Unit benches and item inventories.
*   **Combat UI:** Turn buttons and discard pile interactions.

### C. FlashcardMinigame.tscn (The Overlay)
**Path:** `res://scenes/FlashcardMinigame.tscn`
**Role:** Transient modal overlay.
**Behavior:** Covers the entire screen. Pauses interaction with the underlying Battle scene.

---

## 2. Battle Board Layout (`Battle.tscn`)

The board is divided into two symmetrical columns.

### Vertical Structure (Rows)
Both columns strictly adhere to this vertical stack to ensure alignment.

| Row Layer | Height | Description |
| :--- | :--- | :--- |
| **Lineup Row** | **~250px** | Active unit slots. Expand horizontally. |
| **Spacer** | Flexible | Pushes Benches to the bottom of the playable area. |
| **Bench Row** | **250px** | **The Alignment Anchor.** Both sides must match this height. |
| **Discard Row**| **80px** | Buttons and Discard Pile interactions. |
| **Spacer** | Flexible | Bottom margin. |

### Player Area (Left Column)
*   **Structure:** Standard `VBoxContainer`.
*   **Bench Row:** Contains `PlayerBench` (3 slots) and `ItemInventory` (2 slots). Total width ratio 3:2.

### Enemy Area (Right Column)
*   **Structure:** Standard `VBoxContainer`.
*   **Bench Row:** A "Composite" container (`EnemyBenchComposite`) designed to mirror the Player Bench's physical footprint.
    *   **Height:** Enforced `custom_minimum_size` of **250px**.
    *   **Contents:**
        *   Top: `EnemyTrinketBar` (90px height slots).
        *   Mid: Vertical Spacer (Expands to fill gap).
        *   Bottom: `DiscardArea` (Buttons, 80px height).

---

## 3. Layout Configuration Rules

### Horizontal Spacing (Zero-Gap)
All horizontal slot containers (`HBoxContainer`) are configured to create continuous click zones.
*   **Separation:** `0` (Zero).
*   **Slot Behavior:** `SIZE_EXPAND_FILL` (Slots touch each other).
*   **Containers:** `PlayerLineup`, `PlayerBench`, `ItemInventory`, `EnemyLineupContainer`, `EnemyTrinketBar`.

### Script Authority
**Critical Note:** The script `BattleView.gd` manages the content of the board and takes authority over slot configuration.
*   **Instantiation:** Replaces properties of `PanelContainer` placeholders with `SlotView` instances.
*   **Sizing Override:** The script applies default minimum sizes. Special cases (like 90px Enemy Trinkets) must be explicitly handled in the script's `_initialize_slots` method, or they will be overwritten to the default 250px.

---

## 4. Inventory GachaBallView Visuals

### True 2x Scale System
The inventory uses a "True 2x Scale" system for pixel-perfect rendering:

| Element | Size | Notes |
|---------|------|-------|
| **Slot** | 192x192px | Fixed `custom_minimum_size` |
| **Unit/Item Sprite** | 128x128px | Centered inside slot |
| **Gachaball Overlay** | 192x192px | Glass capsule texture over sprite |
| **Selection Ring** | 192x192px | White circle outline when selected |

### Visual Hierarchy (Z-Order)
Bottom to top stacking in `GachaBallView`:
1. **Unit Sprite** (or Item sprite)
2. **Gachaball Overlay** (transparent glass capsule)
3. **Selection Ring** (visible when selected)
4. **Stats Overlay** (HP/PWR labels, burn/armor indicators)

### Drag Preview
When dragging a gachaball in inventory mode:
- Shows unit/item sprite + gachaball overlay + selection ring
- Centered on cursor using a container twice the preview size
- Uses `force_inventory_mode = true` for free-floating balls

### Implementation Files
- **[GachaBallView.gd](file:///Users/danhh/Desktop/Flashcard%20Heroes/scripts/GachaBallView.gd)**: `_has_overlay_heuristic()`, `_get_drag_data()`, `force_inventory_mode`
- **[InventoryWindow.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/InventoryWindow.tscn)**: 3-column grid with 192px slots

