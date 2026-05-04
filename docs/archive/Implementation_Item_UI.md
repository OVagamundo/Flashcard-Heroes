# Implementation: Item & UI

## 1. Equipment Logic
Units are restricted to one item slot.

### 1.1 Replacement Logic
- **Action:** Dragging an item onto an occupied unit slot.
- **Result:**
  1. The new item is equipped.
  2. The old item is moved to the `Shared Discard Pile`.
- **Cleanup:** Remove internal slot-swapping and multi-slot management code.

### 1.2 Merge Inheritance
- **Rule:** Target unit (already on board) has priority.
- **Result:**
  1. If Target has an item, it is kept. Source item is moved to `Shared Discard Pile`.
  2. If Target is empty, it takes Source's item.

## 2. UI Layout
Standardized layout for all unit instances.

### 2.1 Component Positions
- **Top-Left:** `TextureRect` for the equipped item icon.
- **Top-Right:** `Label` for the level display (e.g., "LV. 1").

### 2.2 Scene Cleanup
- Remove `ItemGrid` and `EquippedItemsContainer` nodes.
- Replace with anchored icon and level nodes.
- Update `populate()` to hide the item icon if null.
