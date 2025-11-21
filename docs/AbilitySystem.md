Abilities, Trinkets & Combat Systems: Definitive Technical Document (V7.0)
Document Purpose: This document serves as the canonical technical blueprint for the game's Ability System and its applications, including Trinkets. It defines the architecture, data schemas, system responsibilities, and interaction contracts.
Global Note: Items and Trinkets are passive/reactive only. They have no direct activation mechanic and only respond to emitted triggers.
Part 1 of 3: Core Architecture & The Ability Vocabulary
Section A: Core Philosophy & Architecture
The game's combat and passive effects are governed by a unified, data-driven, and event-driven architecture. This ensures all interactions are predictable, extensible, and managed through a deterministic flow.
Data-Driven Design: The system's behavior is defined by data Resource files (.tres). Abilities, conditions, and effects are all resources, allowing content creation primarily through the Godot editor.
Event-Driven Flow: The system is reactive. Abilities respond to discrete gameplay events (Triggers) broadcast by the BattleManager (e.g., on_hurt). Certain reactive abilities (e.g., counter-attacks) may trigger even when the damage received is lethal; death processing is selectively deferred until those abilities complete.
Priority-Driven Execution: The system uses a priority queue to manage ability resolution. Each AbilityDefinition has a priority value (higher numbers execute first). When an event triggers multiple abilities, the BattleManager repeatedly sorts the queue of pending EffectRequests and executes the highest-priority action, ensuring a deterministic and intentional order of operations.
Stateless Logic: The AbilityResolver is a stateless service. It acts as a switchboard, receiving a trigger, querying the game state, and outputting EffectRequests. It retains no information between triggers.
Decoupled Execution (Simulate Full Turn, Then Present): The system strictly separates state mutation from visual presentation. This is the Simulation & Animator Contract. The BattleManager first simulates the entire outcome of a combat turn silently, then passes a summary of these changes (a list of CombatEvent objects) to the BattleAnimator for paced, visual presentation.
The Combat Pipeline:
Game Event Occurs: A significant moment in battle happens (e.g., a unit initiates an attack).
Trigger Emission: The BattleManager calls AbilityResolver.process_trigger with the corresponding trigger (e.g., on_attack) and a context dictionary.
Ability Discovery: The AbilityResolver queries all active Units, their equipped Items, and Trinkets for abilities that subscribe to the emitted trigger.
Condition Validation: For each discovered ability, its ConditionDefinition is validated against the current game state and trigger context.
Effect Enqueueing: If the condition passes, the AbilityResolver creates an EffectRequest (which includes the ability's priority) and sends it to the BattleManager's _pending_reactions queue.
Full Turn Simulation: The BattleManager begins its _resolve_combat_phase. It loops through each acting unit, simulating their actions and all subsequent reactions in a priority-sorted loop. All outcomes are collected as CombatEvent objects.
Presentation: After the simulation is complete, the BattleManager hands the complete list of events to the BattleAnimator, which replays them sequentially with visual pacing.
Data Schemas:
AbilityDefinition.gd (Resource): The central "ability" resource.
id: StringName - Unique identifier.
name_key, description_key: String - Localization keys.
trigger: StringName - The event that can activate this ability.
condition: ConditionDefinition - (Optional) The check that must pass.
effects: Array[EffectDefinition] - One or more effects to execute.
priority: int - Execution order. Higher numbers resolve first. (Default: 0).
ConditionDefinition.gd (Resource): A reusable check.
condition_type: StringName - The type of check to perform.
parameters: Dictionary - Data needed for the check.
invert_result: bool - If true, flips the result of the check.
EffectDefinition.gd (Resource): The base class for a script that performs an action.
parameters: Dictionary - Data for the effect, including stat-scaling formulas.
Execution Contract: The `execute` method must handle two modes based on `context.is_simulation`:
- **Simulation Mode (`is_simulation = true`)**: MUST NOT mutate game state. MUST return a Dictionary containing structured data (stat, amount, targets) for `CombatEvent` creation.
- **Execution Mode (`is_simulation = false`)**: MUST mutate game state (apply damage/healing) directly. Returns the numeric amount applied (legacy).
EffectRequest.gd (Resource): A data packet containing all information needed to execute one effect, including its priority.
Section B: The Canonical Ability Vocabulary
This section defines the complete set of Triggers, Targets, Conditions, and Effects available.
Trigger StringName	When Fired by BattleManager	Context Data Provided (Dictionary)
on_battle_start	Once for every unit/trinket at the very beginning of combat.	{}
on_turn_start	At the beginning of each turn cycle, before the first unit acts.	{ "turn_number": int }
on_attack	When a unit initiates its attack action.	{ "source_uuid": String, "target_uuid": String }
on_hurt	When a unit takes any form of damage.	{ "source_uuid": String (damaged unit), "attacker_uuid": String, "damage_taken": int }
on_kill	When a unit's action defeats another unit.	{ "source_uuid": String (killer), "victim_uuid": String }
on_death	When a unit's HP is reduced to 0 or less.	{ "source_uuid": String (dying unit) }
on_ally_death	For all allies when an allied unit dies.	{ "fainting_ally_uuid": String, "fainting_ally_location": LocationIdentifier }
on_turn_end	At the end of each turn cycle, after all units have acted.	{ "turn_number": int }
Target StringName	Description
Self/Source	
SELF	The source of the ability (the unit that was hurt, the unit whose turn it is, etc.).
HOLDER	For Items, this is the unit equipping it. For Units or Trinkets, it is the same as SELF.
ATTACK_TARGET	The direct target of an on_attack trigger.
Contextual	
ATTACKER	The attacker_uuid from an on_hurt trigger context. Used for counter-attacks.
Positional	
FRONTMOST_ALLY	The allied unit in the frontmost position (highest index for player, lowest for enemy).
FRONTMOST_ENEMY	The enemy unit in the frontmost position.
ALLY_BEHIND	The allied unit in the slot directly behind the source.
ADJACENT_ALLIES	The allies directly in front of and behind the source.
Group/Random	
ALL_ALLIES / ALL_ENEMIES	All allied/enemy units currently on the board.
RANDOM_ENEMY	One randomly selected enemy unit.
Condition StringName	Description & BattleManager Logic
TEAM_SIZE_LESS_THAN_ENEMY	Compares the count of units in the player's lineup vs. the enemy's.
TARGET_HP_GREATER_THAN_SELF_HP	In an on_attack context, compares the HP of the target_uuid to the source_uuid.
DAMAGE_WAS_NON_LETHAL	In an on_hurt trigger, checks if the damaged unit's current_hp > 0 after damage is applied.
DAMAGE_WAS_RECEIVED	In an on_hurt trigger, always returns true. This allows abilities like counter-attacks to trigger even on lethal damage.
Part 2 of 3: System Applications & Combat Integration
Section C: Specific Applications & Source Rules
This section defines the rules for how abilities are discovered and sourced.
Source: The GachaBallInstance of a Unit is always the source of its own abilities and the abilities of all Items it has equipped.
Discovery & Deterministic Order: The AbilityResolver uses a single-pass O(N) optimization to categorize all active instances into buckets. It then processes them in a specific order to ensure deterministic behavior:
1.  Units (category UNIT).
2.  Equipped Items (category ITEM), sorted by `equipped_slot_index` for stable stacking.
3.  Trinkets (category TRINKET).
on_hurt Filtering: For the on_hurt trigger, discovery is strictly filtered:
Only the damaged unit (whose UUID matches the trigger context) may process its own on_hurt abilities.
Only items equipped on that specific damaged unit may process their on_hurt abilities.
Lethal Counters: Abilities using the DAMAGE_WAS_RECEIVED condition can trigger even if the incoming damage was lethal. The BattleManager defers the DEATH event for that unit until after its reactive abilities (e.g., a counter-attack) have been fully simulated.
Loop Prevention (Per-Attacker Limit): To prevent infinite counter-attacks, a unit may counter each distinct attacker at most once per turn. The BattleManager tracks this via has_counter_attacked() and mark_counter_attack().
Trinket Rules:
Player Trinkets:
Source: The player's Hero instance is always the source_uuid when processing a player's Trinket ability. This provides a stable positional reference for targeting.
Targeting: All targeting types are valid.
Enemy Trinkets:
Source: The source_uuid is derived from the trigger's context (e.g., the damaged unit in an on_hurt event). For global triggers like on_turn_start, the source is empty.
Targeting Constraint: Due to the lack of a consistent positional source, enemy Trinkets must not use relative targeting types (e.g., ALLY_BEHIND) unless the trigger guarantees a source.
Section D: Combat Integration & Execution Flow
This section defines the contract between the Ability System and the BattleManager.
Action & Default Attack Rule: A unit's primary action is determined by its on_attack abilities. In _enqueue_attack_for, the BattleManager first calls the AbilityResolver to process any on_attack abilities. Then, it always manually enqueues a Default Basic Attack with priority = 0. This is an additive process, not a fallback, ensuring every unit performs at least a basic attack.
Simulation & Animator Contract (Simulate Full Turn, Then Present):
Simulation Phase: The BattleManager's _resolve_combat_phase function simulates the entire turn silently. All EffectRequests are processed in the priority reaction loop. Effect scripts must use silent data setters (e.g., set_current_hp_silent()) and must not emit any UI signals. However, they must still call gameplay triggers (e.g., battle_manager.trigger_on_hurt()) to allow for ability chaining during the simulation. The outcome of every action is collected into a single list of CombatEvent objects.
Presentation Phase: Once the simulation is complete, the BattleAnimator receives the list of events. Before playing, the animator uses a pre-turn health snapshot to reset the UI, allowing it to display damage and healing incrementally. It is solely responsible for replaying these events with animation-driven pacing, emitting all combat UI signals (battle_log_event, unit_stats_changed, etc.) as it processes each event in the list.
Part 3 of 3: Trinket System Details
Section E: Trinket Schema and Exclusivity
Schema:
TrinketDefinition.gd: A separate Resource from GachaBallDefinition.gd.
category: Must be TRINKET.
is_player_exclusive: bool. Authoritative flag to prevent enemy assignment.
Enforcement Rules:
Player Side: No exclusivity filtering is required. Player-only trinkets are valid for player rewards and equipping.
Enemy Side: EncounterGenerator and BattleManager must exclude any trinket where is_player_exclusive is true.
Code Integration Hooks:
AbilityResolver: Iterates GameManager.run_state.player_trinkets for player trinkets and BattleManager.get_enemy_trinkets() for enemy trinkets.
RunState: Routes TRINKET-category instances to the dedicated player_trinkets container (5 slots).

Part 4 of 4: Status Effects System
Section F: Status Effects Architecture
Status effects are stackable, persistent debuffs/buffs stored on GachaBallInstance and displayed in the UI.

Storage:
Each GachaBallInstance has a status_effects Dictionary: { StringName (effect_id): int (stack_count) }
Stacks are managed via three methods:
- add_status_effect(effect_id, amount): Adds/removes stacks (positive = add, negative = remove). Automatically cleans up when stacks ≤ 0.
- get_status_effect_amount(effect_id): Returns current stack count (0 if not present).
- clear_status_effect(effect_id): Removes all stacks of the effect.

Application:
Poison is applied via the Poison Vial trinket (trinket_poison_vial).
When a team has the Poison Vial equipped, all damage dealt by that team applies 1 poison stack to the target.
This is handled in BattleManager._resolve_single_effect_request:
1. When creating a DAMAGE event, it checks if the source team has a Poison Vial via _has_team_trinket().
2. If true, sets apply_poison: true flag on the CombatEvent.
3. BattleAnimator applies the poison stack when animating damage via _apply_poison_stack().

Processing & Decay:
Poison is processed at the END of each turn in BattleManager._trigger_turn_end_abilities:
1. For each poisoned unit, deal damage equal to poison_stacks.
2. Create DAMAGE events (with skip_bump: true to avoid visual bump).
3. After damage, reduce stacks by half (rounded down): new_stacks = floor(poison_stacks / 2).
4. If new_stacks = 0, clear the status effect entirely.

Lifecycle:
Poison persists across turns until it decays to 0.
Status effects are cleared when a unit returns to the discard pile via reset_battle_stats().

UI Display:
GachaBallView displays poison stacks as a purple label overlaying the unit icon.
Updated automatically via SignalBus.unit_stats_changed when stacks change.