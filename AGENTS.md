# Flashcard Heroes — Core Architectural Laws

## 1. Fail-Fast Law (Zero Defensive Code)
- Never write defensive masks or duck-typing guards (`if has_method(...)`, `if SignalBus.has_signal(...)`, `if is_instance_valid(self)`, `if is_instance_valid(ActionQueue)`).
- Use strict static typing (`var x: Type = ...`), typed arrays (`Array[Type]`), typed dictionaries (`Dictionary[Key, Val]`), and explicit `assert()` invariants.
- Internal broken contracts must fail immediately with an actionable stack trace so bugs are fixed at the source, never silently swallowed.

## 2. No Symptom Patching
- Never patch bugs locally with metadata flags (`set_meta`), string comparisons on localized UI text, or timer delays.
- Examine all possible theories before attempting any fix. Diagnose and resolve root structural causes.

## 3. Data ↔ Presentation Decoupling
- Simulation and Data domains (`RunState`, `BattleState`, `GachaBallInstance`, `EffectDefinition`) must never depend on Presentation or UI (`Control` nodes, `WindowManager`, `BattleAnimator`, shaders, or `Audio`).
- Presentation reacts strictly to immutable event sequences emitted by Simulation (`CombatEvent`, `GameAction`).

## 4. Mechanics & Visuals Lock
- NEVER modify game mechanics, unit abilities, trinket/item effects, stats, balance numbers, or visual aesthetics without explicit permission from the user.
- Restrict unprompted fixes strictly to code syntax, data routing, crash resolution, and architectural decoupling.

## 5. Temporary Utility Scripts & Scratch Hygiene
- When writing temporary utility scripts (Python scripts, ad-hoc parser scripts, or Godot debug scripts), ALWAYS place them in `scratch/` and delete them when no longer needed.
- Never clutter the project root directory with one-off scripts.
