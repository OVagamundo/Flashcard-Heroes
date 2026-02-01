# Flashcard Heroes: Content Creation Hub

> [!NOTE]
> **ENTRY POINT DOCUMENT**
> This document serves as the **High-Level Guide** and **Index** for content creation.
> It summarizes the workflow and directs you to the detailed technical references.
>
> **Do not delete the referenced guides.** They contain the critical implementation details.

---

## 📚 Technical Reference Library

| Document | Purpose | When to Read |
| :--- | :--- | :--- |
| **[AbilityImplementationGuide](AbilityImplementationGuide.md)** | **The Golden Rules.** Context keys, Triggers, and Effect scripting. | Creating new Abilities, Items, or Trinkets. |
| **[AbilityExecutionPipeline](AbilityExecutionPipeline.md)** | **The Engine Room.** Detailed tracing of the 17-step resolution logic. | Debugging why an ability blocked, looped, or didn't fire. |
| **[AnimationImplementationGuide](AnimationImplementationGuide.md)** | **The Visuals.** Animation math, curves, audio hooks, and registry. | Adding new visual effects, projectiles, or animations. |
| **[Systems Architecture](Flashcard%20Heroes%20TDD%20(Technichal%20Design%20Document)%20V9.0.md)** | **The Architecture.** Hybrid Index/Truth model and System Responsibilities. | Understanding core engine philosophy. |

---

## 🚀 Quick Start: How to Add Content

### 1. Adding a New Unit
1.  **Design**: Define Role (T1/T2/T3) and Synergies.
2.  **Abilities**:
    *   Check `AbilityImplementationGuide.md` for available Triggers (Section 2).
    *   Create `.tres` files in `resources/abilities/`.
    *   Use existing effects (`EffectModifyStat`) if possible.
3.  **Visuals**:
    *   Check `AnimationImplementationGuide.md` for standard events.
    *   If standard (Damage/Heal), no code needed.
    *   If custom (e.g., Portal), add to `AnimationRegistry`.
4.  **Documentation**:
    *   Update `GameContentDocument.md` with new unit stats and abilities.

### 2. Adding a New Trinket
1.  **Golden Rule**: Trinkets have `source_uuid = ""`.
2.  **Implementation**:
    *   Use `EffectModifyStat` with `target_type = "RANDOM_ALLY"`.
    *   **Crucial**: Ensure `team` key is used in Context (see `AbilityImplementationGuide.md` Section 7).
3.  **Documentation**:
    *   Update `GameContentDocument.md` with trinket details.

### 3. Adding a New Consumable
1.  **Effect**: Create specific effect script (e.g., `EffectItemSteal.gd`).
2.  **Return Type**: Must return `EffectResult`.
3.  **Consumption**: Logic in `InventoryManager` handles consumption based on `EffectResult` success.
4.  **Documentation**:
    *   Update `GameContentDocument.md` with consumable effects.

---

## 🔍 Common Debugging Index

| Issue | Likely Cause | Solution Reference |
| :--- | :--- | :--- |
| **Ability didn't fire** | Filter or Death Check | `AbilityExecutionPipeline.md` (Blocking Points) |
| **Visuals didn't play** | Missing payload data | `AnimationImplementationGuide.md` (Visual Contract) |
| **"Unknown Grants" in Log** | Trinket source UUID issue | `AbilityImplementationGuide.md` (Trinket Specifics) |
| **Animation out of sync** | Event ordering mismatch | `AbilityExecutionPipeline.md` (Queue Drain Points) |

---

## ⚡️ Quick Reference: Trigger Table

*For full details and context keys, see [AbilityImplementationGuide.md > Section 2](AbilityImplementationGuide.md#2-the-context-contract-what-data-is-available)*

| Trigger | Fires When | Key Context |
| :--- | :--- | :--- |
| `on_attack` | Unit attacks (before damage) | `attacker_uuid`, `target_uuid` |
| `on_before_damage` | Unit allows defense | `defender_uuid`, `amount` |
| `on_hurt` | Unit takes damage | `victim_uuid`, `damage_taken` |
| `on_kill` | Unit kills target | `attacker_uuid`, `killed_uuid` |
| `on_death` | Unit dies | `dying_uuid` |
| `on_ally_death` | Ally dies | `fainting_ally_uuid` |

---

## 🎨 Quick Reference: Animation Channels

*For full details, see [AnimationImplementationGuide.md > Section 4](AnimationImplementationGuide.md#4-composable-animation-effects)*

You can emit these signals to compose effects without writing new classes:
1.  `unit_color_flash` (Tint)
2.  `unit_deform` (Squash/Stretch)
3.  `unit_move` (Hop/Recoil)

```gdscript
# Example: Standard Hit
SignalBus.emit_signal("unit_deform", uuid, &"HIT_IMPACT")
SignalBus.emit_signal("unit_move", uuid, &"RECOIL", Vector2.LEFT)
SignalBus.emit_signal("unit_color_flash", uuid, Color.WHITE, 0.25)
```
