# Execution Pipeline — Problem Statement & Requirements

> **Purpose:** This document defines the problem and constraints for the game's execution and presentation pipeline. It does NOT prescribe implementation patterns, specific architectures, or code-level solutions. Any solution approach must satisfy the requirements and acceptance criteria defined here.

---

## 1. The Problem

Flashcard Heroes has many interacting systems — units, items, trinkets, abilities, status effects, elemental traits — that trigger in response to game events (damage dealt, stat changes, deaths, board entries, purchases, merges, and more). These interactions create cascading chains: a unit dies, which triggers an on-death summon, which triggers a board-entry buff from a trinket, which triggers a stat-increase reaction from an adjacent ally.

As the content library grows, it becomes increasingly difficult — for both the developer designing content and the AI agents implementing it — to:

- **Predict** how effects interact when new content is introduced alongside existing content.
- **Control** the order in which simultaneous effects resolve when multiple triggers fire at once.
- **Debug** unexpected behavior caused by chains of effects resolving in an unintended sequence.
- **Present clearly** what happened, to whom, when, how, and why — both visually for the player and logically for the developer.

**The fundamental tension:** The game's richness comes from emergent interactions between content. But without a formal system for ordering, presenting, and reasoning about those interactions, every new piece of content risks creating unpredictable behavior, confusing visual sequences, or subtle bugs that only surface in rare combinations.

---

## 2. Scope

This problem applies to the **entire game**, not just combat. While combat is where the majority of cascading interactions occur (abilities, reactions, deaths, summons, status effects), chain actions also occur outside of battle — during management phases, in shops, at rest sites, and anywhere that one state change can trigger further state changes.

Any solution must cover the full lifecycle of a state-changing interaction, from the moment a trigger fires to the moment the resulting visual feedback finishes playing.

---

## 3. Requirements

The following are constraints that any solution must satisfy:

### 3.1 Deterministic Execution Order

When multiple effects trigger simultaneously in response to the same event, their resolution order must be:

- **Predictable** — Given the same game state and the same triggering event, the same effects must resolve in the exact same order every single time.
- **Controllable** — The designer must be able to define and adjust which effects resolve before others without touching unrelated code.
- **Consistent** — The ordering rules must apply uniformly across all content. The same priority rules that govern how a trinket interacts with a unit's death ability must also govern how a new trinket would interact with a new unit's death ability.

A designer should be able to reason about "what happens first" by looking at the content definition, not by reading execution code.

### 3.2 Visual Legibility

The visual presentation of game events must clearly communicate:

- **What** happened (a buff, a heal, damage, a summon, a death, etc.).
- **Who** it happened to (which unit, which item, which trinket).
- **When** it happened relative to other events (the visual order must match the causal chain).
- **How** it happened (the source of the effect — who or what caused it).
- **Why** it happened (through clear visual trajectories: a projectile from source to target, floating text on the affected unit, etc.).

The presentation order must match the logical execution order. If effect A resolved before effect B in the simulation, the player must see effect A's visual feedback before effect B's. The player should never be confused about causality.

### 3.3 Safe Extensibility

Adding a new piece of content — a new unit, item, trinket, ability, or status effect — should:

- **Slot into the existing priority system** by defining its own rules and priorities, without requiring manual auditing of every possible interaction with existing content.
- **Behave consistently** with similar content. If a new on-death summon trinket is added, it should resolve in the same relative order as existing on-death summon trinkets without special-case code.
- **Behave uniquely when needed.** If new content has a genuinely novel mechanic, the system must support defining exceptions or new priority rules without hacking around the existing ones.

The goal is that the cost of adding content grows linearly with the content's own complexity, not exponentially with the size of the existing content library.

### 3.4 Unified Pipeline

All interactions that change game state — whether in combat, management, shops, rest sites, or any other context — must flow through a single, consistent execution path.

- No state mutation may occur outside the pipeline.
- No scattered, ad-hoc mutation points that bypass the system's ordering and presentation guarantees.
- This applies to both the execution layer (state changes) and the presentation layer (visual feedback).

### 3.5 Decoupled State and Presentation

State mutations and visual presentation must be independent:

- **State resolves atomically** — the game computes the logical result of an interaction completely before any visual feedback begins.
- **Presentation plays back the result** — the visual layer receives the result and presents it legibly, matching the causal order.
- **Neither depends on the other** — state logic must never rely on visual timing, and visual playback must never alter state.

---

## 4. Acceptance Criteria

A solution satisfies these requirements when:

1. **Behavior is predictable:** Given the same inputs and game state, the same effects resolve in the same order every time, with zero ambiguity.
2. **Presentation is legible:** The player can always identify what caused an effect, who it targeted, and why — by watching the visual sequence alone.
3. **Content is scalable:** Adding a new piece of content requires defining its priority and rules within the system. It does not require auditing the entire existing content library for conflicts.
4. **No bypass:** Nothing can mutate game state outside the pipeline. All state changes are traceable, ordered, and presented.
5. **Designer legibility:** The developer or designer can reason about execution and presentation order from content definitions alone, without needing to trace through implementation code.
