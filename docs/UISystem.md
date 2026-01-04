# UI System Architecture

**Version:** 1.0
**Status:** Active

## 1. Overview
The UI System in Flashcard Heroes is built on a **Service-Based Architecture** designed to ensure strict separation of concerns, deterministic input handling, and a clear "Simulate-Then-Present" flow for combat.

### Core Components
1.  **Global Interaction Router (GIR):** The central nervous system for all user input. It is the *only* system that interprets raw clicks and drags.
2.  **Window Manager:** A stateless service that manages the lifecycle and positioning of all popup windows (Contextual and Hermetic).
3.  **Battle Animator (VCR):** The driver for combat presentation, using a "Puppet Mode" to animate views based on a pre-simulated event log.

---

## 2. Input Handling (Global Interaction Router)
*See `docs/InputHandling(GIR).md` for the definitive specification.*

- **Centralized Logic:** Individual UI elements (Views) do *not* handle logic. They simply emit an `InteractionContext` to the GIR.
- **Command Queue:** The GIR processes the context and issues a queue of commands (e.g., `SELECT`, `OPEN_INSPECTION_WINDOW`, `REQUEST_ACTION`).
- **Selection State:** The GIR is the single source of truth for what is currently selected or being dragged.

---

## 3. Window Management
*See `docs/WindowManager.md` for the definitive specification.*

- **Service-Based:** The WindowManager does not decide *when* to open a window; it executes commands from the GIR.
- **Contextual Windows:** Non-blocking popups (e.g., Unit Inspection) that allow "click-through" to the game board.
- **Hermetic Modals:** Blocking popups (e.g., Flashcard Minigame) that pause the game flow.
- **Positioning:** The WindowManager handles all dynamic positioning logic (e.g., keeping windows on-screen, anchoring to units).

---

## 4. Combat Presentation (VCR Architecture)
*Formerly `ReactiveUI.md`*

### Overview
- **Simulate-Then-Present**: Combat is simulated instantly when the end turn button is pressed and combat starts. The result is a `TurnLog` of `CombatEvent`s.
- **BattleAnimator**: Plays back the `TurnLog` sequentially.
- **Puppet Views**: During combat playback, `GachaBallView` instances operate in **Puppet Mode**. They are strictly decoupled from simulation data and only react to the Animator's instructions or `VisualData` updates.
- **Visual Registry**: The Animator maps UUIDs to Views using a `_visual_registry` populated at the start of the sequence.

### Snapshot Architecture

Combat presentation is driven by a **value-based snapshot** captured before simulation runs.

**Snapshot Structure**:
```gdscript
{
    "unit_abc123": {
        "uuid": "unit_abc123",
        "hp": 10,
        "pwr": 5,
        "poison_stacks": 0,
        "def_id": &"unit_t1_a",
        "icon": <Texture>,
        "tier": 1,
        "category": &"UNIT",
        "display_name_key": "unit_t1_a.name"
    }
}
```

**Critical Rule**: The snapshot contains **values only**, never object references. This prevents views from accidentally querying mutated simulation state.

### Phase-Based Blocking

The UI uses **phase-based blocking** to prevent interference with animations.

**Animation Phases** (UI Blocked):
- `COMBAT`: Main turn animations
- `START_OF_TURN`: Turn-start ability animations  
- `END_OF_TURN`: Poison/status effect animations

**Interaction Phase** (UI Active):
- `MANAGEMENT`: Player can interact

**Blocking Mechanisms**:
- **BattleView**: `_redraw_board()` returns immediately during animation phases
- **SlotView**: Ignores update signals during animation phases
- **Why**: Prevents UI rebuilds from destroying the Animator's `_visual_registry`

### SlotView Architecture
`SlotView` uses a specialized rendering approach to ensure robust z-ordering and persistence:
- **StyleBoxTexture**: The slot background is rendered using a `StyleBoxTexture` applied to the `PanelContainer`'s panel style, rather than a child scene.
  - **Reasoning**: This prevents the background from being accidentally destroyed by child cleanup scripts (which often clear all children to refresh content).
  - **Z-Ordering**: Ensures the background is always drawn behind the content (z-index -1 logic handled via style modulation layering).
- **Slot.png**: Uses `res://assets/ui/textures/slot.png` (96x96px) which scales to fit the container.
- **Tinting**: Backgrounds are tinted programmatically via `StyleBoxTexture.modulate_color` based on the container type (e.g., Blue for Player Lineup, Red for Enemy).


### Visual Data Adapter Pattern
- **Strict Decoupling**: `GachaBallView` no longer accepts `GachaBallInstance` objects. It only accepts a `GachaBallVisualData` dictionary.
- **VisualDataAdapter**: A static helper class that converts `GachaBallInstance` (or `TrinketDefinition`) into a `GachaBallVisualData` dictionary.
- **SlotView Controller**: `SlotView` acts as a controller. It listens to simulation signals, uses `VisualDataAdapter` to create data, and updates its child `GachaBallView`.

### Simulation Phase (The Black Box)
- **No UI Signals**: The simulation phase (`BattleManager._resolve_combat_phase`) is strictly data-only. It **must not** emit UI signals or manipulate the SceneTree.
- **Unified Stat Modification**: All stat changes use `BattleManager.apply_stat_delta()`. This updates the data model and returns the absolute values needed for the `CombatEvent` payload.

### Strict Decoupling Principle

> [!CAUTION]
> **The Most Important Rule:**
> Simulation and Presentation are completely independent systems connected ONLY by the TurnLog.
> - Simulation: Mutates data, generates events, manages game state
> - Presentation: Plays events in order, animates views, never queries game state

**Simulation Rules:**
- Effects receive ALL data via `context` parameter
- Effects NEVER call `get_instance()` or query containers
- Game state cleanup can be deferred for reaction mechanics
- This is invisible to presentation

**Presentation Rules:**
- Animator plays events sequentially from TurnLog
- Views are "puppets" - they only know what events tell them
- NEVER query `BattleManager` or `GachaBallInstance` during playback

> [!CAUTION]
> **UUID Lookup Ban (Position Data):**
> Animations must NEVER query `_visual_registry` to get view positions. All positional data must come from `animator.get_snapshot_position(uuid)`, which returns positions captured at animation sequence start. This ensures animations work correctly even when views are replaced (e.g., SUMMON replacing a dying unit's slot).
- Event ordering in TurnLog is the ONLY truth

### Presentation Phase (The Playback)
- **Driven by Events**: The Animator reads `CombatEvent` objects.
- **Visual Payloads**: The `visual_payload` dictionary in the event is the **sole source of truth** for the View during playback (e.g., `targets_new_hp`, `targets_new_poison`).
- **Signals**: The Animator emits signals (e.g., `unit_bump_attack`, `unit_flash_effect`) to trigger specific one-shot animations on the Views.

### View Guidance
- **One-Shot Animations**: Views subscribe to signals like `unit_bump_attack` and play a tween.
- **Completion Signals**: Views **must** emit a completion signal (e.g., `unit_bump_finished`) when the animation ends so the Animator can proceed.
- **Stacked Effects**: The Animator replays events sequentially. Views should render each update distinctly (e.g., two small heals instead of one big jump).

### Debug Logging Standards
> [!NOTE]
> **Log Separation Rule**: Debug logs should only show the **presentation layer**, not simulation internals.

- **Event Queue Log**: Shows what WILL be presented (printed before animations)
- **Animator Logs**: Show what IS being presented (e.g., "Processing DEATH event")
- **Simulation Logs**: Should be commented out or conditional (they pollute the presentation log)

**Example**:
```gdscript
# ❌ BAD: Simulation log
print("[BattleManager] Unit takes damage")  # Pollutes log

# ✅ GOOD: Presentation log
print("[BattleAnimator] Processing DAMAGE event")  # Shows what user sees
```

### Animation Durations (Canonical)
| Animation Type | Duration | Description |
|---|---|---|
| **Bump Attack** | 0.16s | Forward-and-back tween |
| **Flash Effect** | 0.30s | Color modulation (damage/heal) |
| **Death Fade** | 0.28s | Alpha fade to 0 |

---

## 5. Inventory & UI Actions
*See `docs/InventoryManager.md` for logic details.*

- **Stateless Actions:** The UI does not modify data directly. It requests actions via the GIR (`REQUEST_ACTION`).
- **InventoryManager:** Validates the action (Move, Swap, Merge, Equip) and updates the data model.
- **Reactive Updates:** Views listen for signals (e.g., `battle_inventory_changed`) to rebuild or refresh their content.

---

## 6. Visual Feedback Standards

To ensure a "premium" feel (as per golden rule), all interactive elements must provide immediate, juicy feedback.

### Selection & Hover
- **Selection**:
    - **Animation**: Physics-based "Hop" (bounce up/down with squash/stretch).
    - **Highlight**: Thick white outline (Shader parameter `outline_enabled=true`, `outline_width=3.0`).
- **Consistency**: This feedback applies to **ALL** GachaBalls, whether in Shop, Reward, Inventory, or Battle/Equipped slots.
- **Mechanism**: Views subscribe to `SignalBus.view_selected` (Global) rather than handling local input, ensuring feedback matches the GIR's truth.