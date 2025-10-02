# Input Handling: The Global Interaction Router (GIR)

**Version:** 1.0  
**Status:** Canonical

This document specifies the architecture of the Global Interaction Router (GIR), the definitive system for handling all raw user input in the game.

## ▶ Role & Principles

The GIR is the sole clearing-house for all raw input handling. Its responsibilities are strictly defined:

-   It listens for `InteractionContext` packets emitted by UI views.
-   It interprets the user's intent based on the context and current selection state.
-   It produces an **ordered Command Queue** as its only output.
-   It **never** validates gameplay rules (e.g., "Can this item be equipped here?").
-   It **never** mutates game state directly.

## ▶ The InteractionContext Packet

The `InteractionContext` is the immutable, standardized data packet sent from any interactive UI view to the GIR for every gesture. All fields are mandatory.

| Field name | Must contain |
| :--- | :--- |
| `source_id` | The stable `Control.get_instance_id()` of the originating UI node. |
| `event_type` | A `StringName` indicating the gesture: `SINGLE_CLICK`, `DOUBLE_CLICK`, `DRAG_START`, or `DRAG_DROP`. |
| `location` | A `LocationIdentifier` object that fully describes the logical location of the interaction (container tag, slot index, etc.). |
| `entity_uuid` | The unique identifier (`String`) of the clicked/dragged `GachaBallInstance` or UI element (e.g., a button ID). Can be empty for backgrounds. |
| `entity_type` | A `StringName` describing the object: `UNIT`, `ITEM`, `EQUIPPED_ITEM`, `EMPTY_SLOT`, `WINDOW_BACKGROUND`, `GLOBAL_BACKGROUND`, `UI_BUTTON`, etc. |
| `interaction_mode` | A `StringName` defining the rules for this context: `FULLY_INTERACTIVE`, `SELECTION_ONLY`, or `INSPECTION_ONLY`. |
| `window_group_id`| An `int` identifying the chain of nested inspection windows this element belongs to (0 = main scene). |
| `drag_origin_uuid`| The `entity_uuid` captured at `DRAG_START`. This field is blank for all other event types. |

## ▶ The Command Queue

The sole output of the GIR is a Command Queue: an *array* of command dictionaries. The GIR guarantees the correct ordering of commands for a single gesture.

-   **Structure:** Each command is a dictionary with the following keys: `{ id, payload, manager }`.
-   **Routing:** The `manager` key is used by a central command bus to route the command to the correct system for execution (e.g., `WindowManager`, `SelectionManager`).
-   **Execution:** The GIR stops after emitting the queue; it does not wait for or inspect the results of the command execution.

### Standard Command IDs

-   `OPEN_INSPECTION_WINDOW`
-   `CLOSE_CHILD_WINDOWS`
-   `CLOSE_ALL_INSPECTION_WINDOWS`
-   `SELECT`
-   `DESELECT`
-   `REQUEST_ACTION`
-   `EXECUTE_BUTTON_ACTION`
-   `INVALID_INTERACTION`

## ▶ Manager Contracts

The GIR routes commands to the following managers. These managers are responsible for all validation and state changes.

-   **`WindowManager`**: Executes all window-related commands (`OPEN_*`, `CLOSE_*`).
-   **`SelectionManager`**: Maintains the single active selection state. Executes `SELECT` and `DESELECT` commands.
-   **`InventoryManager`**: Executes `REQUEST_ACTION` commands, performing all gameplay validation for moves, swaps, merges, and equips. If an action is illegal, it may emit an `inventory_action_invalid` signal.

*Note: Other systems like FX, Audio, or Stats managers are not contacted directly by the GIR. They should listen for domain-specific events emitted by the primary managers (e.g., `instance_moved` from `InventoryManager`).*

## ▶ High-Level Gesture Mapping

The following are examples of how the GIR translates common gestures into command queues. This is a high-level guide and does not include all edge cases.

-   **Click on an item with no current selection:**
    -   `[ {id: "SELECT", ...} ]`
-   **Valid inspection request (e.g., double-click in an interactive context):**
    -   `[ {id: "DESELECT", ...}, {id: "OPEN_INSPECTION_WINDOW", ...} ]`
-   **Click on a valid target with a selection active:**
    -   `[ {id: "REQUEST_ACTION", ...} ]`
-   **Start dragging an item:**
    -   `[ {id: "DESELECT", ...}, {id: "SELECT", ...} ]` (The `SELECT` command payload indicates it's a drag origin).
-   **Drop a dragged item onto a valid target:**
    -   `[ {id: "DESELECT", ...}, {id: "REQUEST_ACTION", ...} ]`
-   **Click on a window's internal background:**
    -   `[ {id: "CLOSE_CHILD_WINDOWS", ...} ]`
-   **Click on the global background (outside all windows):**
    -   `[ {id: "CLOSE_ALL_INSPECTION_WINDOWS", ...} ]`
-   **An unclassified or invalid gesture (e.g., clicking an invalid target with a selection):**
    -   `[ {id: "INVALID_INTERACTION", ...} ]`