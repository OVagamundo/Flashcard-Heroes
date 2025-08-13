# Flashcard Heroes - Technical Design Document (V9.0)
**Version:** 9.0
**Status:** Active
**Architectural Note:** This document is the definitive technical foundation for the project. It contains the canonical data schemas and high-level flows, and serves as an index to the detailed system-specific documentation.

<!-- TOC -->
Part 1: Core Architecture & Principles
Part 2: Canonical Data Schemas
Part 3: Core Managers & Systems
Part 4: Presentation Layer Architecture
Part 5: Game Lifecycle & Core Flows
Part 6: Progression & Other Systems
<!-- /TOC -->
Part 1: Core Architecture & Principles
1.1 The Definitive Hybrid Architecture
The game's logic is built upon a mandatory hybrid architecture to guarantee data integrity and performance.
The Instance is the Source of Truth: The GachaBallInstance resource is the single, undeniable source of truth for all of its own data. Caching this data in managers is strictly forbidden.
The Container is a Performant Index: DataContainer objects hold only UUIDs and act as a disposable index into the master instance dictionary, providing fast, location-based lookups.
Managers are Authoritative Operators: Managers contain the stateless logic ("verbs") that operates on the data.
1.2 The Golden Rule of State Synchronization
This rule is the fundamental contract of the hybrid architecture. To move an instance, a two-step process is mandatory:
Update the Index: The instance's UUID must be moved between the source and destination DataContainer objects.
Update the Truth: The instance's own location properties (location_container_tag, etc.) must be updated to reflect its new location.
1.3 Circular Preload Dependency Prevention
To prevent game crashes, a pattern of Inversion of Control is mandatory.
Rule: Persistent Autoload singletons (e.g., GameManager) must not query the scene tree for transient objects (e.g., BattleManager).
Pattern: Transient objects must register themselves with persistent objects when they enter the scene tree (e.g., in _ready) and unregister themselves when they exit.
1.4 Fail-Fast, No Defensive Code

The codebase must never hide or mask bugs with defensive logic. We detect issues early and fix the deterministic root cause.

- **Prohibited:** Any state-masking behavior such as auto-repair, silent rehoming, fallback writes (e.g., writing at `size()` when full), or silent index coercion.
- **Validators are read-only:** Diagnostics/validators (e.g., `scripts/BattleManager.gd::_bm_validate_state_consistency()`) must not mutate state. They must `push_error` and fail fast on violations (duplicates, mismatches, OOB indices, missing containers).
- **Atomic operations or fail:** All move/swap/equip flows must perform remove-before-add atomically. If removal fails, abort the operation and surface the exact cause rather than forcing progress.
- **Strict capacity/bounds:** Respect container capacities and index bounds. Do not resize or write out-of-bounds as a fallback; instead, error and stop.
- **Truth = Location:** Container contents and `GachaBallInstance` location must always match. Any mismatch is a bug to be fixed at the source, not auto-corrected.
- **TDD enforcement:** Write deterministic reproductions for failures, fix the root cause, and do not introduce masking code. Remove any incidental workaround once the cause is fixed.

This policy exists to make bugs obvious, reproducible, and quickly solvable.
1.4 Directory Structure
Generated code
res://
├── assets/
├── resources/
│   ├── units/, items/, abilities/, recipes/
├── scenes/
└── scripts/
Use code with caution.
Part 2: Canonical Data Schemas
This section is the single source of truth for all core data structures.
2.1 GachaBall & Run State Resources
GachaBallDefinition.gd: The immutable blueprint for a GachaBall.
id: StringName, display_name_key: String, description_key: String
icon: Texture2D, tags: Array[StringName], tier: int, rarity: StringName
cost: int (for Shops and encounter generation)
category: StringName ("UNIT" or "ITEM")
item_slot_count: int, base_hp: int, base_pwr: int (for UNIT)
bonus_hp: int, bonus_pwr: int (for ITEM)
ability_definitions: Array[AbilityDefinition]
GachaBallInstance.gd: A unique, mutable instance. The single source of truth for its own data.
definition_id: StringName, ball_uuid: String
current_hp: int, current_pwr: int
location_container_tag: StringName, location_slot_index: int
equipped_on_uuid: String, equipped_item_uuids: Array[String]
status_effects: Dictionary[StringName, int]
RunState.gd: The persistent state for an entire run.
gold: int, day: int
run_instances: Dictionary[String, GachaBallInstance] (Master dictionary)
flashcard_progress: Dictionary[StringName, FlashcardProgress]
active_deck_ids: Array[StringName]
MergeRecipe.gd: Defines a valid merge.
ingredient_a_id: StringName, ingredient_b_id: StringName, result_id: StringName
FlashcardDefinition.gd: In-memory resource for a flashcard.
id: StringName, question: String, answer: String, explanation: String
FlashcardProgress.gd: Tracks run-specific progress for a single flashcard.
mastery_level: int, last_review_time: int
2.2 Location & Data Containers
Location Container Tags: StringName values defining all logical locations (e.g., RunInventoryT1, PlayerLineup, BattleInventoryT2, DiscardPile).
DataContainer.gd: Abstract base class for containers.
FixedArrayContainer.gd: Fixed-size array for lineups and benches.
GrowableGridContainer.gd: Expandable container for inventories and discard piles.
Part 3: Core Managers & Systems
This section provides a high-level overview and index of the game's major systems.
GameManager: The top-level orchestrator for the entire game. It manages the RunState, scene transitions, and the overall game lifecycle from the main menu to the end of a run.
Database: An autoload singleton that loads all .tres and .json data resources on startup, providing a central, queryable source for all game definitions.
InventoryManager: A stateless logic controller that executes all GachaBall manipulation actions (move, swap, equip, merge) based on commands from the GIR.
For a detailed breakdown, see docs/InventoryManager.md.
WindowManager: The sole authority for the lifecycle of all modal and inspection windows.
For a detailed breakdown, see docs/WindowManager.md.
SelectionManager: A simple state machine that tracks the player's currently selected UI element.
For a detailed breakdown, see docs/SelectionManager.md.
BattleManager: A scene-specific manager that controls the state and flow of a single battle encounter.
AbilityResolver: A stateless service that processes ability triggers and creates EffectRequest objects for the BattleManager to execute.
EncounterGenerator: A stateless service for dynamically generating enemy encounters based on a budget.
For a detailed breakdown, see docs/EncounterSystem.md.
Part 4: Presentation Layer Architecture
The game's UI is built on a reactive, decoupled architecture.
Input Handling: All user gestures and inputs are processed through a unified, intent-based system.
Refer to docs/InputHandling(GIR).md for the canonical specification.
UI Reactivity: The UI is a "dumb" view that renders the game state. It updates reactively based on signals, never owning or polling state directly.
Refer to docs/ReactiveUI.md for mandatory implementation patterns.
Part 5: Game Lifecycle & Core Flows
5.1 Run Lifecycle
The GameManager orchestrates the entire flow of a single run.
Run Initialization:
The flow begins in the Loadout.tscn scene, where the player selects a Hero and a Flashcard Deck.
On confirmation, GameManager creates a new RunState resource, populates it with the chosen Hero, starter items, and initial flashcard deck, and sets Day = 1.
The Core Loop: The game enters a loop that continues until victory or defeat.
Path Selection: The GameManager generates a choice of three PathNodeDefinitions and displays them to the player.
Node Resolution: The player selects and resolves one node. The GameManager manages the logic for each node type.
Node Types & Logic:
Battle Node: The GameManager initiates a battle, passing control to a new BattleManager instance. See Section 5.2.
Shop Node: The GameManager manages the temporary shop inventory and handles purchase/reroll logic. For details, see docs/ShopSystem.md.
Event Node: The GameManager displays a narrative scenario and processes the player's choice, applying the risk/reward outcome directly to the RunState.
Rest Site Node: The player is presented with one of three choices:
Rest: Heal the Hero for a fixed amount or percentage of HP.
Train: Triggers the flashcard mini-game. Every two correct answers permanently increases a chosen Hero stat (HP or PWR) by 1 for the rest of the run. See docs/FlashcardSystem.md.
Gamble: A high-risk, high-reward random event.
Run Conclusion:
Victory: The run ends successfully when the player defeats the Final Boss.
Failure: The run ends in failure if the Hero's HP reaches zero at any point.
5.2 Battle Flow & Mechanics
The BattleManager controls the in-battle loop.
Battle Setup: A new BattleManager is created. It generates temporary battle_copy() instances of the player's GachaBalls and creates the enemy team from an EncounterDefinition.
Turn Structure: The battle proceeds in turns, managed by the BattleManager.
For a detailed breakdown of phases, see docs/CombatSystem.md.
Gacha Draw Mechanic:
During the Management Phase, the player can spend Gacha Tokens to activate one of three Gacha Machines (Tier 1, 2, 3).
Drawing pulls a random GachaBall instance from the corresponding temporary BattleInventoryT<n> pool and places it on the bench or in the item inventory.
Reshuffle Rule: If a tiered BattleInventory pool becomes empty, all GachaBalls of that same tier currently in the DiscardPile are moved back into the pool. When a GachaBall is reshuffled, its current_hp and current_pwr are fully restored to their base values.
Synergy System:
During combat, the BattleManager continuously checks the player's active Lineup.
It grants passive bonuses based on the number of unique units sharing specific tags (e.g., "Warrior," "Mage"). The definitions for these bonuses (e.g., 2 Warriors grant +1 PWR) are stored in the Database.
Post-Battle Rewards:
Upon victory, the GameManager generates temporary reward instances (GachaBalls or Gold).
The player is shown a reward screen where they make a selection.
The GameManager processes the choice, adding the reward to the permanent RunState and cleaning up the temporary instances.
Part 6: Progression & Other Systems
6.1 Progression Systems
The game features progression both within and between runs.
Run Progression: Difficulty scales with the "Day" counter via the Encounter Budget System.
Meta-Progression: Players permanently unlock new content (Heroes, Decks, GachaBalls) by completing Achievements.
For a detailed breakdown, see docs/ProgressionSystems.md.
6.2 Other Systems & Logics
Flashcard System: The core mechanic for generating Gacha Tokens and training Hero stats. See docs/FlashcardSystem.md.
Ability System: The data-driven, event-driven system that defines all unit behaviors in combat. See docs/AbilitySystem.md.
Merge System: The logic for combining two GachaBalls into a more powerful one. See docs/MergeSystem.md.
Localization: All user-facing text is managed via a key-based system using a central localization.csv file and Godot's tr() function.