# UI Interaction System

> [!IMPORTANT]
> **GIR (Global Interaction Router)** interprets all input. **WindowManager** executes commands. Views only emit `InteractionContext`.

---

## 1. Selection Rules

| Rule | Description |
|------|-------------|
| **S1** Singleton | Only one entity selected at a time |
| **S2** Change of Focus | Click on non-target = move selection |
| **S3** Selection-Only | Shop/Rewards: any click = change focus |
| **S4** Re-Selection | Click selected item = inspect it |
| **S5** Double-Click | Opens inspection window |
| **S6** Deselect on Action | Any `REQUEST_ACTION` immediately clears selection |

---

## 2. Window Rules

| Rule | Description |
|------|-------------|
| **W1** Hierarchical | One window chain at a time, one child per parent |
| **W2** Click-Through | Click outside windows = close all + select new target |
| **W3** Pruning | Click window background = close descendants only |
| **W4** Global Close | Click non-interactive area = close all + deselect |
| **W5** Escape | 1) Cancel drag → 2) Close windows → 3) Deselect |
| **W6** Selection Persist | Parent entity stays selected when opening child windows |

---

## 3. Window Categories

| Type | Examples | Blocker | Behavior |
|------|----------|---------|----------|
| **Hermetic Modals** | FlashcardMinigame, EndBattlePopup | Yes | Blocks all input, self-closing |
| **Contextual (Dynamic)** | UnitInspection, ItemInspection | No | Positioned adjacent to anchor |
| **Contextual (Fixed)** | InventoryWindow, DiscardPile | No | Centered, closes on outside click |

---

## 4. Combat Phase Lock

During `COMBAT` phase:
- All interaction contexts ignored
- No drags can start
- No commands generated
- Background/Escape ignored

---

## 5. Functional Groups (GIR)

```gdscript
# Container → Group mapping (GlobalInteractionRouter.get_context_group)
PlayerLineup, PlayerBench → BattleBoard
RunInventoryT*, BattleInventoryT*, ItemInventory → InventoryGrid
equipped_item → EquippedGrid
Rewards, Shop → SelectionOnly
EnemyLineup, DiscardPile, PlayerTrinkets → InspectionOnly
```

---

## 6. Suppression Windows

For Swap/Merge via ChoiceWindow:
1. Resolve anchor view from target location
2. Find ancestor window via `find_ancestor_window_for_view()`
3. Call `GIR.activate_close_suppression_for_window_id(id, duration)`
4. Duration: 420ms for unit-context, 320ms otherwise

---

## 7. Key APIs

| API | Purpose |
|-----|---------|
| `WindowManager.open_child_contextual_window()` | Open anchored child window |
| `WindowManager.handle_inspection_background_click()` | Local prune (W3) |
| `WindowManager.find_ancestor_window_for_view()` | Resolve owning window |
| `GIR.get_context_group()` | Get functional group for container |
