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
- Use existing checks that can run without approval. Skip optional temporary verification workflows that have previously triggered approval prompts, including creating and running a temporary Godot scene followed by shell cleanup.
- Place any necessary temporary utility scripts in `scratch/`. Clean them up only when that can be done without prompting. If cleanup is interrupted by an approval prompt, leave the files in `scratch/`.
- Never clutter the project root directory with one-off scripts.

## 6. Sandbox Approval Prompts
- Never ask the user to approve running a command outside the Codex sandbox. This includes Git commands that need to write to a read-only `.git` directory.
- Avoid optional commands that previously surfaced a permission prompt in this workspace, even with default sandbox permissions. This includes shell deletion of temporary verification files. If a prompt interrupts a command, do not retry it.
- Use an authorized alternative when available. If an essential operation remains blocked, name the exact operation and the access it requires.
