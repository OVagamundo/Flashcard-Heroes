Abilities, Trinkets & Combat Systems: Definitive Technical Document (V6.0)
Document Purpose: This document serves as the canonical technical blueprint for the game's Ability System and its applications, including Trinkets. It defines the architecture, data schemas, system responsibilities, and interaction contracts. It is a guideline for implementation, not an implementation plan itself.
Part 1 of 3: Core Architecture & The Ability Vocabulary
Section A: Core Philosophy & Architecture
The game's combat and passive effects are governed by a unified, data-driven, and event-driven architecture. This ensures that all interactions are predictable, extensible, and managed through a deterministic flow, whether they originate from a Unit, an Item, or a Trinket.
Data-Driven Design: The system's behavior is defined by data Resource files (.tres) rather than being hardcoded. Abilities, conditions, effects, and the entities that own them are all defined as resources. This is the cornerstone of the system's extensibility, allowing for content creation primarily through the Godot editor. New code is only required for fundamentally new mechanics (i.e., new Effect or Condition scripts).
Event-Driven Flow: The system is reactive. Abilities do not actively poll the game state. Instead, they are designed to react to discrete gameplay events (Triggers) broadcast by the BattleManager at specific moments in the combat loop (e.g., the start of a turn, a unit taking damage).
Stateless Logic: The AbilityResolver is a stateless service. It acts as a central switchboard, receiving a trigger and a context dictionary, processing it against the current game state, and outputting EffectRequests. It retains no information between triggers, ensuring every action is deterministic based on the state at that moment.
Decoupled Execution (Simulation vs. Presentation): The system strictly separates state mutation from visual presentation. This is the Simulation & Animator Contract. The BattleManager first simulates the outcome of an action, modifying all relevant game data silently. Only after the simulation is complete is a summary of these changes (a list of CombatEvent objects) passed to the BattleAnimator. The animator is then responsible for presenting these events to the player with appropriate pacing and emitting the final UI update signals.
The flow is a strict, ordered pipeline from a gameplay event to a change in the game state, followed by its presentation to the player.
Game Event Occurs: A significant moment in battle happens (e.g., a unit's HP is reduced to 0).
Trigger Emission: The BattleManager broadcasts the corresponding trigger (e.g., on_death) along with a context dictionary containing relevant data (e.g., source_uuid of the dying unit). This broadcast is a direct call to AbilityResolver.process_trigger.
Ability Discovery: The AbilityResolver queries all potential sources for abilities that subscribe to the emitted trigger. This includes active GachaBallInstances (Units and their equipped Items), active player TrinketDefinitions, and active enemy TrinketDefinitions.
Condition Validation: For each discovered ability, the AbilityResolver asks the BattleManager to validate its ConditionDefinition against the current game state and the trigger context.
Effect Enqueueing: If the condition passes, the AbilityResolver resolves the ability's target(s) and creates an EffectRequest which is sent to the BattleManager's effect queue.
Effect Resolution (Simulation): The BattleManager processes its queue, executing each EffectRequest in a simulation context.
Event Collection & Presentation: The BattleManager captures the results of the simulation as CombatEvent objects and passes them to the BattleAnimator, which replays them with visual pacing and emits the final UI signals (battle_log_event, unit_stats_changed, etc.).
AbilityDefinition.gd (Resource): The central "ability" resource. It is the glue that holds the other components together.
id: StringName: Unique identifier (e.g., ability_desperate_lash).
name_key: String, description_key: String: Localization keys.
trigger: StringName: The specific event that can activate this ability (from the vocabulary list).
condition: ConditionDefinition: (Optional) A resource defining the check that must pass.
effects: Array[EffectDefinition]: One or more effects to execute if triggered.
ConditionDefinition.gd (Resource): A reusable check.
condition_type: StringName: The type of check to perform (from the vocabulary list).
parameters: Dictionary: Any data needed for the check (e.g., {"value": 2}).
invert_result: bool: If true, the result of the check is flipped (e.g., a "less than" check becomes "greater than or equal to").
EffectDefinition.gd (Resource): The script that performs an action. All concrete effects (e.g., EffectDealDamage.gd) must extend this class.
parameters: Dictionary: Data for the effect, which can include stat-scaling formulas (e.g., {"pwr_multiplier": 1.5}).
EffectRequest.gd (Resource): A data packet created by the AbilityResolver and processed by the BattleManager. It contains the source_uuid, the ability_id, the effect_definition to execute, the resolved target_uuids, and the original trigger context.
Section B: The Canonical Ability Vocabulary
This section defines the complete set of Triggers, Targets, Conditions, and Effects available in the system.
Trigger StringName	When Fired by BattleManager	Context Data Provided (Dictionary)
on_battle_start	Once for every unit/trinket at the very beginning of combat.	{}
on_turn_start	At the beginning of each turn cycle, before the first unit acts.	{ "turn_number": int }
on_attack	When a unit initiates its attack action, before damage is dealt.	{ "source_uuid": String, "target_uuid": String }
on_hurt	When a unit takes any form of damage.	{ "source_uuid": String (damaged unit), "attacker_uuid": String, "damage_taken": int }
on_kill	When a unit's action defeats another unit.	{ "source_uuid": String (killer), "victim_uuid": String }
on_death	When a unit's HP is reduced to 0 or less.	{ "source_uuid": String (dying unit) }
on_ally_death	For all allies when an allied unit dies.	{ "fainting_ally_uuid": String, "fainting_ally_location": LocationIdentifier }
on_turn_end	At the end of each turn cycle, after all units have acted.	{ "turn_number": int }
Target StringName	Description
Self/Source Targets	
SELF	The source of the ability (e.g., the unit that was hurt, the unit whose turn it is).
HOLDER	For Items, this is the unit equipping it. For Units or Trinkets, it is the same as SELF.
ATTACK_TARGET	The direct target of an on_attack trigger.
Contextual Targets	
TRIGGERING_ENTITY	The "other" entity in a reactive trigger (e.g., the attacker in an on_hurt event).
FAINTING_ALLY	The specific ally whose death triggered an on_ally_death event.
Positional Targets	
FRONTMOST_ALLY	The allied unit in the frontmost position (lowest index for player, highest for enemy).
FRONTMOST_ENEMY	The enemy unit in the frontmost position.
ALLY_BEHIND	The allied unit in the slot directly behind the source.
ADJACENT_ALLIES	The allies directly in front of and behind the source.
Group Targets	
ALL_ALLIES	All allied units currently on the board.
ALL_ENEMIES	All enemy units currently on the board.
Random Targets	
RANDOM_ENEMY	One randomly selected enemy unit.
Condition StringName	Description & BattleManager Logic	Parameters
TEAM_SIZE_LESS_THAN_ENEMY	Compares the count of units in the player's lineup vs. the enemy's lineup.	{}
SLOT_AHEAD_IS_EMPTY	Checks if the combat slot directly in front of the source unit is unoccupied.	{}
TARGET_HP_GREATER_THAN_SELF_HP	In an on_attack context, compares the HP of the target_uuid to the source_uuid.	{}
TRIGGERING_DAMAGE_WAS_NOT_LETHAL	In an on_hurt trigger, checks if (unit.current_hp - damage_taken) > 0.	{}
ONCE_PER_TURN	Checks a dictionary in BattleManager to see if the ability ID has already been recorded for the current turn. If not, it records it and returns true.	{}
Effect Scripts: The available actions are defined by scripts extending EffectDefinition:
BasicAttackEffect.gd
EffectDealDamage.gd
EffectModifyStat.gd
EffectSummonUnit.gd
EffectSummonRandomUnit.gd
EffectApplyStatus.gd (For Status Effects)
Stat Scaling: Effects like EffectDealDamage and EffectModifyStat support stat-scaling parameters. The parameters dictionary can contain keys like pwr_multiplier, hp_multiplier, and base_value. The formula is:
final_value = base_value + (source.current_pwr * pwr_multiplier) + (source.current_hp * hp_multiplier)

System Applications & Combat Integration
This part builds upon the foundational architecture and vocabulary defined in Part 1. It details the specific rules governing how Units, Items, and the Trinket System utilize the Ability System, and it clarifies the precise contract between abilities and the combat loop.
Section C: Specific Applications & Source Rules
This section defines the rules for how abilities are discovered and how their "source" is determined, which is critical for targeting.
Source: The GachaBallInstance of the Unit is always the source of its own abilities and the abilities of all Items it has equipped. This provides a clear, unambiguous origin point for all effects. A single GachaBallInstance is passed as the source_uuid to the AbilityResolver.
Discovery: The AbilityResolver iterates through all active GachaBallInstances on the board. For each unit, it checks both the unit's own ability_definitions and the ability_definitions of each of its equipped items.
Targeting: All targeting types are valid. Because the source is always a GachaBallInstance, it has a concrete position on the battlefield from which to resolve relative targets (like ALLY_BEHIND, ADJACENT_ALLIES, etc.).
Trinkets are a special application of the Ability System with unique rules for sourcing and targeting, representing powerful, run-wide passive effects.
Data Schema: Trinkets are defined by TrinketDefinition.gd, a separate resource from GachaBallDefinition.gd. This prevents schema bloating and keeps the systems distinct. The is_player_exclusive flag in the definition is critical for preventing certain Trinkets from being used in enemy encounter generation.
Ability Source & Targeting Rules: This is the most critical distinction for Trinkets.
Player Trinkets:
Source: The player's Hero instance is always considered the source_uuid when processing a player's Trinket ability. This is a fundamental rule that anchors all player-side passive effects to their main character, providing a stable positional reference.
Targeting: Because the Hero provides a valid source with a concrete position on the board, all targeting types are valid. SELF will target the Hero, ALLY_BEHIND will target the unit behind the Hero, ADJACENT_ALLIES will target the units next to the Hero, and so on.
Enemy Trinkets:
Source: Enemy Trinkets have no consistent positional source. The source_uuid for their abilities is derived from the trigger's context.
For reactive triggers like on_hurt, the source_uuid from the context (the unit that was hurt) becomes the source for the Trinket's effect. This allows SELF to correctly target the hurt unit for effects like Guardian's Ward.
For global triggers like on_turn_start, there is no instance source, so the source_uuid is empty.
Targeting Constraint: Due to the lack of a consistent positional source for global triggers, enemy Trinket abilities MUST NOT use targeting types that depend on a source's position (e.g., ADJACENT_ALLIES, ALLY_BEHIND) unless the trigger guarantees a source (like on_hurt). They are restricted to global, contextual, or attribute-based targets (e.g., ALL_ENEMIES, RANDOM_ENEMY, FRONTMOST_ENEMY, TRIGGERING_ENTITY).
Discovery & Integration:
AbilityResolver.process_trigger performs two additional loops after processing GachaBall instances:
It queries GameManager.run_state.active_trinkets, using the Hero's UUID as the source for each ability.
It queries BattleManager.get_enemy_trinkets(), determining the source based on the trigger context for each ability.
Section D: Combat Integration & Execution Flow
This section defines the strict contract between the Ability System and the BattleManager, ensuring predictable and visually coherent combat.
A unit's primary action during the Combat Phase is determined by its on_attack abilities. This rule ensures every unit always has a valid action.
Mechanism: In BattleManager._populate_effect_queue(), for each potential attacker, the system first calls AbilityResolver.process_trigger("on_attack", ...).
Check: After the resolver runs, the BattleManager checks if any EffectRequests were actually enqueued for that specific attacker.
Fallback: If no effects were enqueued (either because the unit has no on_attack abilities or because none of their conditions were met), the BattleManager will then manually enqueue a Default Basic Attack (BasicAttackEffect.gd) for that unit. This guarantees that every unit will perform an action on its turn.
This defines the mandatory separation of logic and presentation, which is essential for paced, animated combat.
Two-Stage Pipeline:
Simulation: The BattleManager executes an EffectRequest. The effect script mutates the game data silently (e.g., tgt.set_current_hp_silent(new_hp)). It must respect a context.is_simulation flag to suppress all direct UI signal emissions.
Presentation: The BattleManager captures the results of the simulation (damage dealt, units killed, etc.) as CombatEvent objects. It passes this list to the BattleAnimator. The animator is responsible for replaying these events with visual pacing and is the sole emitter of UI signals.
Invariants & Rules:
Effect scripts MUST NOT emit UI signals (e.g., SignalBus.battle_log_event).
Effect scripts MUST still emit gameplay triggers (e.g., battle_manager.trigger_on_hurt(...)) during the simulation phase. This is critical to allow for ability chaining and reactive effects.
The BattleAnimator is the only source for combat UI signals: battle_log_event, unit_stats_changed, and battle_inventory_changed.
Application: Status effects are applied via an EffectApplyStatus.gd script. They are stored as a dictionary on the GachaBallInstance, mapping the status ID to the number of stacks.
Mechanics: The logic for each status is handled by a dedicated system within the BattleManager that processes them at the appropriate phase of the turn (e.g., poison at start of turn, regeneration at end of turn). Each status has a defined lifecycle.
Status StringName	Type	Mechanic	Lifecycle
strength	Buff	Additive: Adds +1 PWR per stack to the unit's stat calculation.	Loses 1 stack at the end of its turn.
regeneration	Buff	End of Turn: Heals the unit for 1 HP per stack.	Loses 1 stack after healing.
armor	Buff	Damage Reduction: Reduces incoming attack damage by 1 per stack.	Loses 1 stack when hit by an attack.
poison	Debuff	Start of Turn: Deals 1 damage per stack to the unit.	Loses 1 stack after taking damage.
weaken	Debuff	Additive: Subtracts -1 PWR per stack from the unit's stat calculation.	Loses 1 stack at the end of its turn.
vulnerable	Debuff	Multiplicative: Increases all damage taken by 50%. Stacks do not increase the percentage, only the duration.	Loses 1 stack when it takes damage.
daze	Debuff	Unit cannot perform its on_attack action.	Loses 1 stack instead of attacking.

Trinket Lifecycle, Acquisition & UI Contract
This final part describes the complete game flow for how Trinkets are introduced, awarded, and managed, as well as the contract for how they are represented in the user interface.
Section E: Trinket Acquisition & Lifecycle
This section defines the mechanics that govern the player's progression through the Trinket system during a run.
Trigger Condition: A Mini-Boss encounter is triggered to appear on the path choice screen when the player's active_deck_ids count in RunState crosses a specific threshold for the first time. The formula for this check is: (active_cards - 10) % max(1, int(total_cards * 0.05)) == 0. This check is performed by PathChoice.gd upon loading, and the result is stored in RunState.miniboss_milestones_achieved to prevent re-triggering.
Path Generation: When triggered, the PathChoice scene will clear any normal nodes and present a single, mandatory "Mini-Boss Battle" node.
Encounter Generation: The Mini-Boss encounter uses the standard EncounterGenerator but with an increased budget (Day * 5 + 5 Gold). The generator can also equip the enemy team with Trinkets from its budget.
Frequency: This system is designed to result in exactly 5 Mini-Boss encounters over the course of a full run where all flashcards are eventually added to the active deck.
State Tracking: When the player selects the Mini-Boss node, a flag is_miniboss_pending is set to true in RunState.
Victory Condition: Upon winning the battle, GameManager checks the is_miniboss_pending flag. If true, it initiates the Trinket reward flow instead of the standard GachaBall reward flow.
Reward Generation: The GameManager fetches all TrinketDefinitions from the Database, shuffles them, and selects the top 3 to be presented as choices.
Reward Scene (Reward.gd):
The reward scene receives a context containing the 3 TrinketDefinitions.
It populates its slots with TrinketViews, configured in SELECTION_ONLY mode.
The "Take Gold Instead" button is made invisible, as there is no gold alternative for this special reward.
Player Choice & Equipping:
The player selects one of the three Trinkets.
Upon confirmation, a reward_chosen signal is emitted with a payload like {"type": "trinket", "trinket_id": "Trinket1A"}.
GameManager handles this signal and instructs RunState to add the chosen trinket_id to the first available empty "" slot in its active_trinkets array.
The run_data_changed signal is emitted, causing the Main.gd UI to update and display the newly equipped Trinket in the top bar.
Section F: UI Contract & Interaction Model
This section defines how Trinkets are presented to the player and the rules for interacting with them.
Location: A dedicated HBoxContainer in the TopArea of the main UI.
Structure: Contains 5 persistent SlotView children.
Population: Main.gd subscribes to the run_data_changed signal. When the signal is received, it repopulates the slots with TrinketView instances based on the contents of RunState.active_trinkets.
Interaction Contract:
The TrinketViews are configured in INSPECTION_ONLY mode.
A single click on a TrinketView opens the TrinketInspectionWindow for that Trinket, anchored to the view.
Drag-and-drop, selection, and other interactions are disabled.
Location: A dedicated HBoxContainer located below the enemy lineup in the battle scene.
Structure: Contains 5 persistent SlotView children.
Population: BattleView.gd populates this at the start of each battle based on the enemy_trinkets array from the generated EncounterDefinition.
Interaction Contract:
The TrinketViews are configured in INSPECTION_ONLY mode.
A single click on a TrinketView opens the TrinketInspectionWindow.
All other interactions are disabled.
Function: A contextual window responsible for displaying the detailed information of a TrinketDefinition.
Content: Displays the Trinket's name, icon, description, and a formatted list of its AbilityDefinition descriptions.
Lifecycle: It is managed entirely by the WindowManager and adheres to all standard contextual window rules (hierarchical grouping, pruning, global closing, etc.). It is opened via a call to WindowManager.open_trinket_inspection_window(trinket_def, anchor_view).