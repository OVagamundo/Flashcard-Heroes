# Architecture & System Specification: Linear Event Queue & VCR Playback
Project: Flashcard Heroes: Gachamon
Focus: Global Event Queue, Simulation Execution, VCR Playback, and Input Lock

> **Status:** IMPLEMENTED & VERIFIED

---

## 1. Executive Summary
This document specifies the game's event execution and visual playback architecture. The system transitions combat and management-phase event execution from an overlapping, asynchronous parallel system to a **strict, linear Command Queue**. All game logic evaluates instantly in the background during the Simulation Phase, generating an ordered, one-dimensional list of events (`Array[CombatEvent]`). The `BattleAnimator` (the VCR) plays back this list strictly sequentially—one event at a time—without live state queries or defensive workarounds.

---

## 2. Core Architecture: The Input-Simulation-Playback Loop

The game loop strictly adheres to a three-phase decoupled architecture:

### Phase 1: Player Input & Trigger Gating
The UI is locked during active animations. VCR playback chains are initiated ONLY by specific committing actions:
- **Pressing End Turn / Battle Button**: Initiates `CombatSimulator` turn simulation loop.
- **Gacha Machine Activation**: Spending tokens to draw units or items.
- **Merging Units**: Dropping a unit onto a duplicate.
- **Equipping an Item**: Dropping an item onto a unit.
- **Consumables / Minigames**: Committing resource transactions.

> **Passive Board Movement**: Moving or swapping units on the board does NOT initiate a VCR animation chain; it merely updates passive stats in memory and triggers UI refreshes without blocking.

### Phase 2: Instant Background Simulation
`AbilityResolver` and `CombatSimulator` instantly compute all cascading consequences of the action. The output is a definitive `Array[CombatEvent]` payload snapshotting the initial and final states.

### Phase 3: Linear VCR Playback
`BattleAnimator.play_turn_sequence()` processes the `Array[CombatEvent]` strictly one index at a time. It awaits the full visual resolution of `CombatEvent[N]` before advancing to `CombatEvent[N+1]`.

---

## 3. Event Sorting and Execution Order (The 3-Layer Hierarchy)

When triggers occur simultaneously during simulation, reaction requests are sorted using a strict 3-layer hierarchy implemented in `CombatSimulator._compare_reactions`:

1. **Layer 1: The Category Pass (`AbilityResolver.gd`)**
   - **Units** (Rank 1)
   - **Items** (Rank 2 - evaluated by `equipped_slot_index`)
   - **Trinkets** (Rank 3)

2. **Layer 2: Execution Priority (`AbilityDefinition.gd`)**
   - Reactions sort by descending integer priority (e.g. Intercepts at 300, Summons at 210, Standard at 0).

3. **Layer 3: Visual Direction (The Mirror Rule)**
   - Priority ties resolve Left-to-Right visually on screen:
     - **Player Team**: Left-to-Right (Slot 4 down to Slot 0).
     - **Enemy Team**: Right-to-Left visually (Slot 0 up to Slot 4).

---

## 4. Source-Based Consolidation & Multi-Target Batching

The VCR never branches into parallel execution paths. Multi-target status applications, trait effects, and multi-instance scaling events are systemically consolidated:
1. **Systemic VCR Event Consolidation (`_consolidate_consecutive_events`)**:
   Consecutive visual stat/status events are automatically merged into a single multi-target event before playback if they:
   - Share `source_uuid` (one entity buffing multiple targets), OR
   - Share `ability_id` (e.g. `&"doppleganger_scaling"`, `&"echoing_orb_scaling"`, `&"twin_charm_scaling"` across multiple units), OR
   - Are passive self-buffs with empty `source_uuid`s within the same reaction step.
2. **In-Place Net Payload Consolidation (`_merge_event_payloads`)**:
   When multiple events target the same unit in a single reaction step, the VCR performs in-place net payload accumulation. `targets_old_pwr`/`hp` retains the initial state before the step, while `targets_new_pwr`/`hp` is updated to the final accumulated state. This prevents intermediate stat drops, out-of-order updates, or array length mismatches.
3. **Simultaneous Multi-Stat & Dual Projectiles**:
   When an event contains both HP and PWR stat changes (or when HP and PWR events are merged), green HP projectiles and blue PWR projectiles are launched simultaneously in the exact same frame to all targets.
4. **Duration-Synchronous Projectile Physics**:
   Horizontal and vertical velocities ($v_x, v_y$) are dynamically derived from target distance divided by target flight duration ($T = \text{AnimationConstants.scaled}(0.6)$). All projectiles launched in parallel hit their targets on the exact same frame regardless of screen distance.
5. **Consolidated Trait Start-of-Turn Events**:
   Earth (Armor & Spikes), Fire (Burn), Water (Heal), and Air (PWR steal) traits batch all affected target UUIDs into single consolidated multi-target events instead of looping per unit.

---

## 5. Playback Speeds, Stepping, & Speed Control

- **Two Speed Settings (1x & 3x)**: Supported speeds are Normal (1.0) and Fast (3.0), managed via `AnimationConstants.speed_factor`. Legacy 2x speed settings have been removed.
- **Queue Stepping**: Stepping while paused unpauses the queue, sets playback speed to guaranteed 1.0x (`set_combat_speed(1.0)`), processes exactly one `CombatEvent`, awaits full visual resolution, and re-pauses automatically (`request_step()`).

---

## 6. Gacha Draw Input Block & Waiting Cursor System

To provide feedback when drawing or spending tokens while animations play:
- **Systemic VCR Lock (`BattleManager.is_animations_playing()`)**:
  Combines `_is_processing_effect`, `_is_animating_management_queue`, and `_animator.is_playing_sequence()`.
- **Input Gating (`Main.gd`)**:
  - `_is_drawing_token`: Set to `true` on knob button press until coin toss and VCR animation complete.
  - `_is_mouse_over_draw_mechanic()`: Dynamically evaluates mouse position against gacha machines and knob buttons each frame.
- **Waiting Cursor Animation (`CursorManager.gd`)**:
  - `_waiting_control` is added to CanvasLayer 1024 *after* `_cursor_sprite`, ensuring dots render on top of the cursor sprite in Z-order.
  - Displays a looping 3-step sequence of white circles with a black outline (`.` $\rightarrow$ `..` $\rightarrow$ `...`) positioned at vertical offset `Vector2(12 + i * 11, 52)` below the hand cursor icon.
  - Automatically activates when hovering over draw mechanics during active animations and deactivates the frame VCR playback finishes.

---

## 7. Technical Class Mappings

| System Layer | Class File | Responsibility |
|--------------|------------|----------------|
| Simulation & Sorting | `scripts/battle/CombatSimulator.gd` | 3-Layer sorting, actor queues, reaction loops |
| Simulation Resolution | `scripts/AbilityResolver.gd` | Category assignment, event generation, trigger evaluation |
| Management Serialization | `scripts/BattleManager.gd` | `_management_animation_queue`, `is_animations_playing()` |
| VCR Playback Engine | `scripts/BattleAnimator.gd` | Sequential `play_turn_sequence()`, snapshot puppet rendering |
| Draw Lock & Bounds | `scripts/Main.gd` | `_is_drawing_token`, `_is_mouse_over_draw_mechanic()` |
| Software Cursor Overlay | `scripts/CursorManager.gd` | Software cursor mouse tracking, `_waiting_control` dots |