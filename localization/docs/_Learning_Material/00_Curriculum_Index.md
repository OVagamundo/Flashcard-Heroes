# Flashcard Heroes: Gachamon - Learning Curriculum

Welcome to the comprehensive learning curriculum for **Flashcard Heroes: Gachamon**. This curriculum is designed to provide deeply detailed, visual, and code-specific explanations of every major system in the game. It is built for the Game Designer to intimately understand the codebase, spot architectural problems, enforce coding standards, and guide the game's data flow.

## 00. Curriculum Index

### Module 1: The Godot Global Architecture
- **Focus:** How the `SignalBus`, `GameManager`, Singletons, and Resources communicate.
- **Key Concepts:** Autoloads, Event-Driven Architecture, Global State vs. Local State, Decoupling.

### Module 2: The Combat Initialization
- **Focus:** Exactly what happens, script by script, when the "Battle!" button is pressed.
- **Key Concepts:** State transition, board snapshot, passing data to the `BattleManager`, Team vs. Team scenario initialization.

### Module 3: The Simulation vs. Presentation Pipeline (The VCR Pattern)
- **Focus:** How the `CombatSimulator` calculates the math instantly, outputs a `CombatEvent` log, and how the `BattleAnimator` plays it back visually.
- **Key Concepts:** Decoupling logic from presentation, Event Logging, Tweens, and asynchronous animation queues.

### Module 4: The Trigger & Ability System
- **Focus:** How equipped items, trinkets, and unit abilities listen for triggers (e.g., `on_attack`, `on_hurt`), how the `AbilityResolver` queues them, and how priority sorting works.
- **Key Concepts:** Observer Pattern, Event Resolution, Priority Queues, Trigger Contexts.

### Module 5: Unit Lifecycle & Economy
- **Focus:** The step-by-step code execution of unit purchasing, leveling up, upgrading, and merging on each of our scenes. Explaining how our scenes work as well.
- **Key Concepts:** Scene Management, Instance Management, Data vs. View representation, Economy logic.

---

*This document serves as the roadmap for our technical tutoring sessions.*
