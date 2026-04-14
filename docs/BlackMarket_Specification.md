# Technical Specification: Black Market Encounter (V2.0 - Active Overlay)

This document defines the architecture, UI layout, and mechanical behavior of the Black Market encounter using the unified interaction overlay system.

## 1. Encounter Mechanics
- **Node Type**: `BLACK_MARKET` / `ui.black_market_node`.
- **Primary Actions**:
    - **Remove**: Permanently deletes a Gachaball from the run collection.
    - **Transform**: Replaces a Gachaball with a random one of the same tier.
- **Cost Structure**:
    - **Remove**: Base cost **5 Gold**. Cost increases by **+1 Gold** for each subsequent removal during the run.
    - **Transform**: Flat fee of **5 Gold**. Cost does not escalate.
- **Inventory Access**:
    - A center button labeled "REMOVE OR TRANSFORM" (`ui.black_market_open_inventory`) opens the Run Inventory.
    - Accessing the inventory in this scene triggers the **Black Market Contextual Overlay**.

## 2. Dynamic Interaction Model
The Black Market uses a two-stage interactive overlay system managed by `Main.gd` and driven by `BlackMarket.gd`.

### Stage 1: Instruction Mode
- **Trigger**: Inventory is opened while in the Black Market scene.
- **Visual**: A semi-transparent black rectangle (`Color(0, 0, 0, 0.7)`) covers the bottom HUD area (the machine bases).
- **Text**: `ui.bm_instruction` ("Move the gacha ball here to: Transform or Remove. Click anywhere to close the inventory.")
- **Behavior**: The overlay uses `MOUSE_FILTER_IGNORE` to allow clicks to pass through to the background machine bases, enabling standard "click outside to close" behavior.

### Stage 2: Action Mode (Active Selection/Drag)
- **Trigger**: A Gachaball from the `RunInventoryT*` containers is selected or started to be dragged.
- **Visual**: The instruction overlay vanishes, and **two split zones** appear side-by-side:
    - **Transform Zone** (Left): Blue-tinted warm white (`#EDF5FA`).
    - **Remove Zone** (Right): Red-tinted warm white (`#FAF5F5`).
- **Interaction**:
    - **Click-to-Action**: Clicking a zone while a gachaball is selected triggers the action.
    - **Drag-and-Drop**: Dropping a gachaball onto a zone triggers the action.
- **Rollback**: If the selection is cleared or the drag ends outside the zones, the split zones vanish and the instruction overlay returns.

---

## 3. Signal Architecture
- **Signals** (`SignalBus.gd`):
    - `black_market_remove_zone_activated`: Emitted by `Main.gd` when the remove zone is triggered.
    - `black_market_transform_zone_activated`: Emitted by `Main.gd` when the transform zone is triggered.
- **Validation**: `BlackMarket.gd` validates that the current `GlobalInteractionRouter` selection originates from a valid inventory container before executing the logic.

---

## 4. Visual Feedback & Animations
- **Rejection**: If gold is insufficient, the specific zone panel (Transform or Remove) performs a horizontal shake animation (Rejection Feedback).
- **Success (Remove)**: Unit is deleted; inventory state updates.
- **Success (Transform)**:
    - Old unit is deleted.
    - New unit is spawned.
    - **Arc Animation**: The new gachaball performs a parabolic jump starting from the **center of the Transform zone** and ending at the inventory slot of the original unit.

---

## 5. UI Copy & Localization
| Key | English | Brazilian Portuguese |
|-----|---------|-----------------------|
| `ui.black_market_title` | Black Market | Mercado Negro |
| `ui.drop_zone_remove` | Remove | Remover |
| `ui.drop_zone_transform` | Transform | Transformar |
| `ui.bm_instruction` | Move the gacha ball here... | Mova a gacha ball para cá... |

---

## 6. Implementation Notes (Legacy Failures Resolved)
The V2.0 architecture was implemented specifically to resolve several critical failures discovered in the legacy slot-based system:
- **Z-Order Occlusion**: By using programmatic overlays in `Main.gd`, elements are guaranteed to render in front of machine bases.
- **Input Passthrough**: Zones capture input explicitly during active interaction, preventing machine interactions from firing.
- **Window Synchronization**: The overlay visibility is strictly tied to `WindowManager.is_run_inventory_window_open()`.
- **Context Integrity**: Removing the hardcoded `&"BlackMarket"` container context from the routing logic restored the standard high-performance drag-and-drop flow.


