Flashcard Heroes: Gachamon - Game Design Document
Version: 3.0 (Comprehensive Revision - Based on GDD v2.0 & Chat)
Date: [Current Date]
Table of Contents (Part 1)
Game Overview
Core Gameplay Loop & Flow
2.1. Run Structure
2.2. Node Progression
2.3. Scene Transitions (Conceptual)
Resources
3.1. Hero Health Points (HP)
3.2. Gold
3.3. Gacha Tokens
Flashcard System
4.1. Flashcard Decks
4.2. Flashcard Mini-Game Mechanics
4.3. Progression Link
GachaBall System: Definitions, Entities, & Core Behaviors
5.1. Core Terminology
5.2. GachaBallData (Templates/Definitions)
5.3. GachaBallInstance (Live Entities)
5.4. Unit GachaBalls
5.5. Item GachaBalls
5.6. Core Enums & States
5.7. Tier & Rarity System
1. Game Overview
"Flashcard Heroes: Gachamon" (hereafter "Flashcard Heroes") is a single-player, turn-based roguelike that integrates strategic auto-battler combat with an engaging flashcard learning system. The core premise revolves around players building and curating a collection of unique entities called GachaBalls – which encompass both combat Units and utility Items. This collection, known as the Master Run Gacha Pool, functions as the player's "deck" for the current run, directly influencing the GachaBalls available to be drawn from Gacha Machines during tactical battles.
Resource generation, particularly for activating Gacha Machines, is intrinsically linked to player performance in flashcard mini-games focusing on Japanese characters and vocabulary. Success in Flashcard Heroes demands a blend of long-term strategic planning in building the Master Run Gacha Pool, tactical decision-making in battles, and consistent engagement with the flashcard learning mechanics.
Each run begins with the player selecting a Hero Unit and a specific Flashcard Deck. The Hero Unit is a special, persistent character whose Health Points (HP) represent the player's overall life for the run. If the Hero Unit's HP is depleted to zero, the run ends in failure (Game Over). The primary objective is to navigate a procedurally generated path of encounters, strengthen the Hero and GachaBall collection, and ultimately defeat a series of challenging bosses. The final boss of the run only becomes accessible once the player has unlocked all flashcards within their chosen Flashcard Deck for that run.
Meta-progression allows players to unlock new Heroes, Flashcard Decks, GachaBall types, and other game-enhancing elements, providing replayability and expanding strategic options for subsequent runs.
2. Core Gameplay Loop & Flow
2.1. Run Structure
A single "run" in Flashcard Heroes is a complete playthrough attempt, from starting with a chosen Hero and Flashcard Deck to either achieving victory by defeating the Final Boss or succumbing to failure if the Hero's HP reaches zero.
The Core Gameplay Loop is as follows:
Run Start (Loadout): The player selects a Hero Unit and a Flashcard Deck. The Master Run Gacha Pool is initialized with a starting set of GachaBallInstances based on the chosen Hero.
Path Selection (Node Choice): The player is presented with a choice of three procedurally generated nodes on a map. Each node represents a different type of encounter or opportunity (e.g., Battle, Shop, Event, Rest Site).
Node Resolution: The player selects and resolves one node. This involves engaging with the node's specific mechanics.
Progression & Iteration: After resolving a node, the game's "Day" counter typically advances, often increasing the difficulty of subsequent encounters. The player then returns to Step 2 (Path Selection) to choose their next node, continuing this cycle.
Boss Encounters: At specific milestones related to Flashcard Deck progression (e.g., every 20% of cards unlocked for mini-bosses, 100% unlocked for the final boss), mandatory boss battle nodes will appear.
Run Conclusion: The run ends either in Victory (defeating the Final Boss) or Failure (Hero HP reaches zero). Meta-progression may be updated based on achievements and performance during the run.
2.2. Node Progression
Players always choose one out of three presented node options to advance.
The types of nodes offered are determined by procedural generation rules, which may incorporate factors like the current "Day," player progression, and specific event flags to ensure variety and a balanced challenge.
There is no guarantee of specific node types (like Shop or Rest Site) appearing at fixed intervals, encouraging adaptive strategy.
Successfully completing a node typically leads to rewards (Gold, new GachaBallInstances for the Master Run Gacha Pool, Trinkets, etc.) and then a transition back to the Path Selection screen.
2.3. Scene Transitions (Conceptual)
The game will transition smoothly between different game states and scenes:
Title Screen → Loadout Scene (Hero/Deck Selection) → Initial Path Choice Scene.
Path Choice Scene ↔ Selected Node Scene (Battle, Shop, Event, Rest Site).
Battle Node → Battle Reward Sequence (if victorious) → Path Choice Scene.
Battle Node → Game Over Screen (if Hero HP reaches zero) → Title Screen.
Shop/Event/Rest Site Node → Interaction Resolution → Path Choice Scene.
All transitions must ensure the persistent state of the current run (Hero HP, Gold, Master Run Gacha Pool contents, Day counter, active Trinkets, Flashcard Deck progress) is correctly maintained and carried forward. Temporary battle-specific states (like Current Battle Gacha Pools and Battle Discard Piles) are initialized anew for each battle.
3. Resources
Players manage several key resources that are crucial for progression and strategic decision-making within a run.
3.1. Hero Health Points (HP)
Behavioral Role: The current_hp of the player's chosen Hero Unit serves as the overall health for the entire run. It is the primary resource determining run survival.
base_hp: Each Hero Unit type has a defined base_hp. This value can be permanently increased for the current run through specific upgrades (e.g., at Rest Sites or via certain events).
current_hp: Represents the Hero Unit's actual Health Points at any given moment.
It is reduced by damage the Hero Unit takes directly in battle (if it is targeted after other defending units are defeated or by abilities that bypass normal targeting) or through negative outcomes in Event Nodes.
It can be restored through healing abilities, consumable Item GachaBalls, or specific actions at Rest Sites.
current_hp can be healed above its current base_hp due to in-battle healing effects or temporary buffs.
If current_hp reaches 0, the run ends immediately in failure.
Persistence: The Hero Unit's current_hp (and its current base_hp) persists between all nodes and encounters within a run and is part of the saved run data.
3.2. Gold
Behavioral Role: The primary transactional currency used for most economic interactions within a single run.
Acquisition:
Awarded for winning Battle Nodes (the amount may scale with battle difficulty or Day).
Obtained as a result of favorable outcomes in Event Nodes or specific choices made by the player.
Can be won through "Gamble" actions at Rest Site Nodes.
Expenditure:
Used to purchase GachaBallInstances or services (e.g., Reroll Shop Inventory, Remove GachaBallInstance from Master Run Gacha Pool, Transform GachaBallInstance) at Shop Nodes.
May be required as a cost for certain choices in Event Nodes.
Used for "Gamble" actions at Rest Site Nodes.
Persistence: Gold is accumulated and persists throughout the entirety of a single run. It is saved and loaded with the run data. All Gold is lost if the run ends in failure and does not carry over to new runs by default (unless specific meta-progression unlocks provide a small starting bonus).
3.3. Gacha Tokens
Behavioral Role: A temporary, node-focused currency used exclusively to activate Gacha Machines and draw GachaBallInstances.
Acquisition:
Primary: Earned by correctly answering questions during Flashcard Mini-Games. Each correct answer grants one Gacha Token.
Secondary: May be granted by specific Unit GachaBall abilities or Trinket effects during a battle or at certain nodes.
Passive Coin generation is also possible at the start of the turn Phase via passive effects.
Expenditure:
Spent to activate Gacha Machines during the Battle Management Phase. The cost in Gacha Tokens typically scales with the tier of the Gacha Machine (e.g., Tier 1 Machine costs 1 Token, Tier 2 costs 2 Tokens, Tier 3 costs 3 Tokens).
Also used for Gacha machines at Rest Sites (e.g., Healing Gacha, Training Gacha) and other nodes.
Persistence & Reset Behavior:
Gacha Tokens earned during a battle can be accumulated and spent across multiple turns within that same battle node.
However, Gacha Tokens are reset to zero at the start of each new node (i.e., after a battle is won and rewards are given, or after a Shop/Event/Rest Site interaction is completed and the player moves to the Path Choice screen). They are a "use them or lose them" resource for the current encounter/node.
4. Flashcard System
The Flashcard System is the core mechanic for resource generation and is tied to player progression through the game's content.
4.1. Flashcard Decks
Main Deck: At the start of a run, the player selects a Main Deck. This is a large, predefined collection of flashcards (e.g., ~110 cards) focused on a specific subject, such as Japanese characters (Hiragana, Katakana, Kanji) or vocabulary.
Active Deck: This is a smaller, dynamic subset of cards drawn from the Main Deck that are currently in rotation for the flashcard mini-games.
Initialization: At the start of a run, the Active Deck is initialized with a small number of cards (e.g., 10) from the Main Deck.
Growth: New cards are progressively introduced from the Main Deck into the Active Deck as the player engages with the mini-game (e.g., one new card added to the Active Deck at the start of each mini-game instance until all cards from the Main Deck have been introduced).
Card Content: Flashcards present a question (e.g., a character or word to identify/translate) and offer multiple-choice answers.
4.2. Flashcard Mini-Game Mechanics
Trigger Points:
Automatically at the start of the player's turn during the Management Phase in Battle Nodes.
As part of specific actions at Rest Site Nodes (e.g., for Healing, Training, or Gambling Gachas).
Potentially triggered by certain Event Node choices or Trinket effects.
Gameplay Flow:
When a new card is being added to the Active Deck, it is shown and explained before the mini-game starts, and the mini game only starts when the player presses "Got it!".
When the mini-game session starts, a short overall session timer begins counting down (e.g., initially 3 seconds). This timer is for the entire session and does not reset between individual questions.

Regarding the Spaced Repetition System (SRS) for selecting the next card: the selection prioritizes cards with lower mastery values and those not presented recently. A small element of randomization is included to ensure variety and prevent predictability.
A flashcard from the Active Deck is displayed, presenting a question. The selection of which card to show next from the Active Deck is governed by a Spaced Repetition System (SRS) algorithm, prioritizing cards based on the player's past performance with them. Performance is measured using a mastery value for each flashcard, they start at mastery value 1 and increase by 1 for each correct answer and decrease by 1 for each incorrect answer (e.g., lower mastery value and/or less recently answered are shown more frequently).
A grid of answer choices is presented (e.g., a 3x3 grid).
The player selects an answer.
Immediate feedback on correctness is provided.
A new flashcard is then drawn from the Active Deck (via SRS logic). This rapid cycle of question-answer-feedback repeats until the session timer expires. The player aims to answer as many questions correctly as possible within this brief period. Initially, with a 3-second timer, players are expected to answer approximately 2-4 questions, yielding a similar number of Gacha Tokens. This quick, reflex-based system is designed to provide a small, consistent resource inflow. While the session timer might be slightly extendable through game progression (potentially allowing for an average of 4-5 tokens, up to a maximum of around 9 per session), it will remain relatively short to maintain overall game balance.
Outcomes:
Correct Answer: The player earns 1 Gacha Token per correct answer in real time.
Incorrect Answer: No Gacha Tokens are earned for that specific question.
4.3. Progression Link
Unlocking Cards: Each activation of the flashcard mini-game adds a new card from the Main Deck to the Active Deck for the run.
Boss Encounters:
Mini-boss encounters are gated by reaching certain milestones of added cards from the Main Deck (e.g., every 20% of the deck added).
The Final Boss encounter for the run only becomes available once 100% of the cards in the chosen Main Deck have been added.
5. GachaBall System: Definitions, Entities, & Core Behaviors
This section defines the fundamental collectible entities in Flashcard Heroes: GachaBalls. It outlines their static definitions (GachaBallDefinition), their live in-game representations (GachaBallInstance), and the core properties and behaviors associated with them.
5.1. Core Terminology
GachaBallDefinition: Refers to the static, predefined template or blueprint for a specific type of GachaBall (e.g., "Warrior Type A," "Healing Potion Type B"). These are stored as game resources (.tres files in Godot) and define all inherent characteristics of that GachaBall type.
GachaBallInstance: Refers to a live, unique, individual GachaBall existing within the game during a run. Each GachaBallInstance is created based on a GachaBallDefinition template but possesses its own unique identifier (ball_uuid using a unique string generator) and can have dynamic state (like current HP and PWR, equipped items on inventory, status effects, current location slot). Players collect and manage GachaBallInstances.
GachaBall: The general, player-facing term for these collectible entities, encompassing both Units and Items.
5.2. GachaBallDefinition (Templates/Definitions)
Each type of GachaBall in the game is defined by a GachaBallDefinition entry. This data is immutable during gameplay and serves as the blueprint for creating GachaBallInstances.
Common Attributes for all GachaBallDefinition:
id: (StringName) A unique programmatic identifier for this GachaBall type (e.g., "unit_warrior_t1", "item_sword_common").
display_name_key: (String) A localization key for the player-facing name (e.g., "Warrior," "Common Sword").
description_key: (String) A localization key for the player-facing description, including flavor text and a summary of its function or abilities.
icon_texture: (Texture2D Resource Path) The visual icon used to represent this GachaBall type in UI elements.
tier: (Integer, typically 0-3) Indicates its general power level, rarity grouping, and the Gacha Machine tier it primarily belongs to.
Tier 0: Typically reserved for Hero Units.
Tier 1: Common GachaBalls.
Tier 2: Uncommon GachaBalls.
Tier 3: Rare and Legendary GachaBalls.
rarity: (Enum: RarityLevel) Specifies its rarity (COMMON, UNCOMMON, RARE, LEGENDARY). This influences acquisition chances and often correlates with power.
ball_category: (Enum: GachaBallCategory) Defines whether the GachaBall is a UNIT or an ITEM.
5.3. GachaBallInstance (Live Entities)
A GachaBallInstance is a specific, unique occurrence of a GachaBall within the game world during a run. Players interact with and manage these instances.
Common Attributes for all GachaBallInstances:
definition_id: (StringName) Stores the id of the GachaBallData this instance is based on, allowing lookup of its base properties.
ball_uuid: (String) A universally unique identifier (UUID) generated when the instance is created, distinguishing it from all other instances, even those of the same type. This is crucial for tracking individual GachaBalls.
current_location_state: (Enum: LocationState) Tracks the current logical position or status of this instance within the game (e.g., in the Master Run Gacha Pool tier 1 inventory slot 13, on the player's Bench slot 2, equipped on another Unit slot 1, in a Gacha Machine's drawable pool tier 2 inventory slot 6, etc.).
instance_specific_modifiers: (Data Structure, e.g., Dictionary or Array) Stores any temporary or permanent modifications applied directly to this instance that deviate from its base GachaBallDefinition (e.g., persistent stat increases from certain events, current status effect applications).
5.4. Unit GachaBalls
Unit GachaBalls represent the characters that players deploy in battles.
Specific GachaBallDefinition Attributes for Units:
base_hp: (Integer) The fundamental Health Points value for this Unit type.
base_pwr: (Integer) The fundamental Power value for this Unit type, often influencing attack damage or ability effectiveness.
ability_definition_refs: (Array of AbilityData Resource Paths or IDs) A list of abilities inherent to this Unit type.
item_slot_count: (Integer) Defines the number of generic item slots this Unit type possesses (e.g., Tier 1 Units = 1 slot, Tier 2 = 2 slots, Tier 3 = 4 slots, Hero Unit = 5 slots). These slots are generic and can hold any equippable Item GachaBall.
tags: (Array of StringName) A list of descriptive tags associated with this Unit type (e.g., "Warrior," "Mage," "Beast," "Elemental") used for synergy calculations and ability targeting.
Specific GachaBallInstance Attributes for Units:
current_hp: (Integer) The Unit instance's current Health Points. This value is initialized from its definition_id's base_hp (plus any persistent instance modifiers) and changes due to damage and "healing" (there's no real healing since there's no max health so healing in this game means HP increase) during a battle.
current_pwr: (Integer) The Unit instance's current Power. Initialized similarly to current_hp and can be affected by temporary or permanent modifiers.
equipped_item_uuids: (Array of ball_uuid Strings) Stores the ball_uuids of any Item GachaBallInstances currently equipped in this Unit instance's item slots. The array index can correspond to the slot number.
active_status_effects: (Array or Dictionary) Tracks any status effects currently active on this Unit instance, including their type and remaining stacks (stacks determine duration and sometimes potency).
5.5. Item GachaBalls
Item GachaBalls represent equipment, consumables, and other utility objects that can be used or equipped on Unit GachaBalls.
Specific GachaBallData Attributes for Items:
effect_definition_refs: (Array of EffectData Resource Paths or IDs) A list of effects this Item provides when equipped or consumed.
is_equippable: (Boolean) True if this Item type can be equipped into a Unit GachaBall's generic item slot.
is_consumable: (Boolean) True if this Item type is consumed (removed from play or its current location) after its primary effect is triggered once.
target_type_restriction: (Enum or StringName, Optional) May define limitations on what types of Units can equip or use this item, or under what conditions (e.g., "HERO_ONLY", "WARRIOR_TAG_ONLY"). This is distinct from unit item slots being generic; it's an item-side restriction. If no such restrictions exist for most items, this can be omitted or default to "ANY_UNIT".
Specific GachaBallInstance Attributes for Items:
(Typically fewer instance-specific dynamic attributes compared to Units, unless an item tracks charges, durability, or a unique cooldown state).
5.6. Core Enums & States
To manage GachaBalls effectively, the following enumerations are essential:
GachaBallCategory:
UNIT
ITEM
RarityLevel:
COMMON
UNCOMMON
RARE
LEGENDARY
HERO (A special rarity designation for Hero Units, signifying unique acquisition and role)
GachaBallTier (Primarily for Gacha Machine organization and merge rules):
TIER_0 (Typically for Hero Units)
TIER_1
TIER_2
TIER_3
LocationState (for GachaBallInstances):
IN_MASTER_RUN_POOL_TIER_1, IN_MASTER_RUN_POOL_TIER_2, IN_MASTER_RUN_POOL_TIER_3 (Indicates availability in the respective tier's inventory within the Master Run Gacha Pool)
IN_BATTLE_GACHA_POOL_TIER_1, IN_BATTLE_GACHA_POOL_TIER_2, IN_BATTLE_GACHA_POOL_TIER_3 (Currently in the drawable inventory of the respective Gacha Machine for the battle)
IN_PLAYER_BENCH (Unit instance in the player's reserve bench slots during battle)
IN_PLAYER_LINEUP (Unit instance in an active combat slot in the player's lineup)
IN_ENEMY_LINEUP (Unit instance in an enemy's combat slot)
IN_BATTLE_INVENTORY (Item instance in the player's temporary item inventory during battle, not yet equipped)
EQUIPPED_ON_UNIT (Item instance equipped on a Unit instance; the Unit instance would store the item's ball_uuid)
IN_BATTLE_DISCARD_PILE (Instance is in the discard pile for the current battle)
5.7. Tier & Rarity System
Tier: Primarily dictates the Gacha Machine a GachaBall is compatible with and merge compatibility.
Tier 0: Hero Units.
Tier 1: Base level GachaBalls.
Tier 2: Mid-level GachaBalls, results of merging Tier 1s.
Tier 3: High-level GachaBalls, results of merging Tier 2s, or found as rare rewards (legendary).
Rarity: Influences the probability of obtaining a GachaBall type on rewards or shop options and often correlates with its unique utility or power within its tier.
Tier 1 GachaBalls are COMMON Rarity.
Tier 2 GachaBalls are UNCOMMON Rarity.
Tier 3 GachaBalls can be RARE or LEGENDARY Rarity.
Hero Units have no rarity, since they are unique and can't be obtained after the run starts.

7. Master Run Gacha Pool
The Master Run Gacha Pool is the player's persistent collection of unique GachaBallInstances (Units and Items) for the current run. It functions as the player's "deck," directly influencing the GachaBalls available to be drawn from Gacha Machines during battles and forming the basis for strategic team building throughout the run.
### 7.1. Nature and Structure

*   **Persistence**: The Master Run Gacha Pool and its contents (specific `GachaBallInstance`s) exist for the duration of the current run. It is initialized at the start of a new run based on the chosen Hero Unit's starting set of `GachaBall`s.
*   **Content**: Composed of individual `GachaBallInstance`s, each with a unique `ball_uuid` and its own `current_location_state` (refer to Section 4.5 for `LocationState` enum definitions).
*   **Structure & Organization**: The Master Run Gacha Pool is logically organized into three distinct inventories, one for each `GachaBallTier` (refer to Section 4.5 for `GachaBallTier` enum definitions):
    *   **Tier 1 Master Inventory**: Holds all Tier 1 `GachaBallInstance`s.
    *   **Tier 2 Master Inventory**: Holds all Tier 2 `GachaBallInstance`s.
    *   **Tier 3 Master Inventory**: Holds all Tier 3 `GachaBallInstance`s.
    This tiered organization facilitates populating the corresponding Gacha Machines at the start of each battle. It also allows players to inspect the contents of their Master Run Gacha Pool by tier outside of battle (e.g., for planning Permanent Merges or shop interactions).
*   **Capacity**: There is no hard limit on the number of `GachaBallInstance`s the Master Run Gacha Pool can hold.
*   **Instance Uniqueness**: Each `GachaBallInstance` within the Master Run Gacha Pool is unique, identified by its `ball_uuid`.
*   **Primary Interface**: The player's primary interface for viewing and managing the Master Run Gacha Pool outside of battle is through the three persistent Gacha Machines displayed in the UI. By inspecting a Gacha Machine (e.g., the Tier 1 machine), the player is directly viewing the contents of the Tier 1 Master Inventory.

### 7.2. Initial Population

At the start of a new run, after the player selects their Flashcard Deck and Hero Unit, the Master Run Gacha Pool is initialized.
This involves creating new `GachaBallInstance`s based on the chosen Hero Unit's predefined starting `GachaBallInstance`s (as defined in its `GachaBallDefinition`). These new instances are added to the appropriate tier's inventory within the Master Run Gacha Pool, and their `current_location_state` is set accordingly (e.g., `IN_MASTER_RUN_POOL_TIER_1`).

### 7.3. Modification During a Run

The Master Run Gacha Pool is dynamic and changes throughout a run:

*   **Expansion**:
    *   New `GachaBallInstance`s are acquired as battle rewards, from shop purchases, or through event outcomes.
    *   These new instances are added to the appropriate tier's inventory within the Master Run Gacha Pool, and their `current_location_state` is updated (e.g., `IN_MASTER_RUN_POOL_TIER_1`, `IN_MASTER_RUN_POOL_TIER_2`, etc.).
    *   `GachaBallInstance`s resulting from Permanent Merges (see Section 9.4) are also added to the Master Run Gacha Pool. The `GachaBallInstance`s used as ingredients for these merges are removed (see Reduction below).
*   **Reduction**:
    *   `GachaBallInstance`s can be permanently removed from the Master Run Gacha Pool via specific shop services (e.g., "Remove Ball"). These instances are effectively destroyed and cease to be tracked within the game's state systems.
    *   `GachaBallInstance`s used as ingredients in Permanent Merges (Section 9.4) are similarly consumed. They are removed from the Master Run Gacha Pool and all tracking, effectively being destroyed.

## 8. Gacha System (In-Battle)

This system governs how players acquire `GachaBallInstance`s from Gacha Machines during the Battle Management Phase (see Section 10.1), using Gacha Tokens (see Section 5.3). It relies on temporary "Current Battle Gacha Pools" populated from the Master Run Gacha Pool at the start of each battle.

### 8.1. Gacha Machines

*   **Availability**: During the Battle Management Phase, players have access to three Gacha Machines, corresponding to `GachaBallTier`s 1, 2, and 3.
*   **Cost to Draw**: Activating a Gacha Machine to draw a `GachaBallInstance` costs Gacha Tokens. The cost scales with the machine's tier:
    *   Tier 1 Gacha Machine: Costs 1 Gacha Token per draw.
    *   Tier 2 Gacha Machine: Costs 2 Gacha Tokens per draw.
    *   Tier 3 Gacha Machine: Costs 3 Gacha Tokens per draw.
*   **Interaction**:
    *   Players can interact with a Gacha Machine to initiate a draw if they have sufficient Gacha Tokens (typically by clicking/tapping a draw button associated with the machine).
    *   During the Battle Management Phase, players can inspect each Gacha Machine (e.g., by clicking/tapping its body) to view the `GachaBallInstance`s currently available in its "Current Battle Gacha Pool," including counts if multiple identical types are present.

### 8.2. Battle Initialization: Populating Gacha Machine Pools

At the very start of each battle (e.g., during a `BATTLE_SETUP_PHASE`):

1.  For each `GachaBallTier` (1, 2, and 3):
    *   A temporary **"Current Battle Gacha Pool"** is created. This pool will serve as the drawable inventory for that tier's Gacha Machine for the duration of the current battle.
    *   A single, temporary **"Battle Discard Pile"** is created for the battle.
2.  To populate these Current Battle Gacha Pools:
    *   A deep copy of each GachaBallInstance from the Master Run Gacha Pool is created and placed into the corresponding Current Battle Gacha Pool of the same tier.
    *   These temporary instances are assigned a `current_location_state` of `IN_BATTLE_GACHA_POOL_TIER_X` (e.g., `IN_BATTLE_GACHA_POOL_TIER_1` for temporary instances in the Tier 1 Battle Pool).
    *   Crucially, the original `GachaBallInstance`s within the Master Run Gacha Pool **do not change their state** or "move"; they remain in their `IN_MASTER_RUN_POOL_TIER_X` state. This ensures the Master Run Gacha Pool is preserved. The temporary instances created for the battle are the ones drawn from Gacha Machines.

### 8.3. Drawing from a Gacha Machine

During the Battle Management Phase, when a player activates a Gacha Machine:

1.  The required Gacha Tokens are deducted from the player's current Gacha Token count.
2.  A `GachaBallInstance` is randomly selected from that Gacha Machine's Current Battle Gacha Pool.
3.  The selected `GachaBallInstance`'s `current_location_state` is updated:
    *   If it's a Unit GachaBall (`category == GachaBallCategory.UNIT` as defined in Section 4.5), its state changes to `IN_PLAYER_BENCH` and spawn in the player's bench.
    *   If it's an Item GachaBall (`category == GachaBallCategory.ITEM` as defined in Section 4.5), its state changes to `IN_BATTLE_INVENTORY` and spawn in the player's inventory.
4.  The drawn `GachaBallInstance` is removed from that Gacha Machine's Current Battle Gacha Pool (it cannot be drawn again from that machine in the current battle unless it is reshuffled from the discard pile).

### 8.4. Battle Discard Piles

A single **Battle Discard Pile** is used for the current battle.
This pile temporarily stores `GachaBallInstance`s that were removed from active play (e.g., from Gacha Machine pools, the player's bench/lineup, or battle inventory). `GachaBallInstance`s sent to this pile retain their original `GachaBallTier` property, which is relevant for processes like Reshuffling.
Defeated GachaBallInstances and their equipped items are sent to the Battle Discard Pile.

### 8.5. Reshuffling
If a Gacha Machine's Current Battle Gacha Pool becomes empty during a battle (i.e., all GachaBallInstances initially moved into it have been drawn):
All `GachaBallInstance`s in the Battle Discard Pile that possess the same `GachaBallTier` as this Gacha Machine are moved back into this Gacha Machine's Current Battle Gacha Pool.
Their `current_location_state` is updated from `IN_BATTLE_DISCARD_PILE` to the corresponding `IN_BATTLE_GACHA_POOL_TIER_X` (e.g., `IN_BATTLE_GACHA_POOL_TIER_1` if it's a Tier 1 instance).
These specific instances are removed from the Battle Discard Pile.
These reshuffled instances are now available to be drawn again.
8.6. End of Battle Cleanup
At the conclusion of a battle (after victory rewards or before transitioning from a loss):
All temporary `GachaBallInstance`s that were created for and used during the battle (i.e., those that had `current_location_state`s such as `IN_BATTLE_GACHA_POOL_TIER_X`, `IN_BATTLE_DISCARD_PILE`, `IN_PLAYER_BENCH`, `IN_PLAYER_LINEUP` (excluding the persistent Hero Unit), `IN_BATTLE_INVENTORY`, or `EQUIPPED_ON_UNIT` for items on non-Hero units) cease to exist.
The Master Run Gacha Pool itself remains as it was at the start of the battle, with its `GachaBallInstance`s still in their `IN_MASTER_RUN_POOL_TIER_X` states. The Master Pool is only modified by events that explicitly target its contents for permanent change (e.g., consumption of an instance for a Permanent Merge, or acquisition of new instances from battle rewards which are added directly to the Master Pool).
Only the Hero Unit's current_hp is maintained.
The player's Gacha Tokens are reset to zero (as they are node/battle-specific).
9. Merge System
Merging allows players to combine two GachaBallInstances to create a new, typically more powerful and higher-tier GachaBallInstance. Merges follow predefined recipes.
9.1. Core Merge Behavior
Inputs: Merging always consumes the two input GachaBallInstances.
Consumption: The two input GachaBallInstances are permanently consumed and removed from the run or from the battle depending where they were merged (in battle or outside of battle).
Result: A single, new GachaBallInstance of the recipe's defined result type is created (with a new unique ball_uuid).
Result Stats: The base stats (e.g., Base HP, Base PWR) for this new GachaBallInstance are taken directly from its corresponding GachaBallData definition (i.e., the template for that GachaBall type).
9.2. Merge Recipes
The game maintains a system of Merge Recipes that define all valid combinations of GachaBallInstances (based on their GachaBallData types and tiers) and the resulting GachaBallData type.
Example Recipe: 2x "Warrior Tier 1" GachaBallData type → 1x "Knight Tier 2" GachaBallData type.
Recipes may need to be discovered or unlocked by the player through meta-progression or in-run events before they can be used.
The Merge System validates any merge attempt against the available and unlocked recipes.
9.3. Temporary Merges (In-Battle)
Context: Occur during the Battle Management Phase.
Inputs: Involve two Unit GachaBallInstances of the same tier, selected from the player's Bench or Lineup. Item GachaBallInstances can also be merged from the Battle Inventory. 
Outcome: The resulting merged GachaBallInstance is created and placed into the player's control for the current battle at the location of the last instance used in the merge.
Persistence: This resulting merged GachaBallInstance exists only for the current battle. It is NOT added to the Master Run Gacha Pool after the battle and its input components are consumed for the battle but that does not affect the Master Run Gacha Pool.
9.4. Permanent Merges (Master Run Gacha Pool)
Context: Permanent Merges can be performed at any time outside of the Combat Phase. The player initiates a Permanent Merge by inspecting one of the Gacha Machines, selecting two compatible GachaBallInstances from within that machine's inventory, and confirming the action. This is the sole method for performing Permanent Merges.
9.5. Item Handling During Unit Merges
When two Unit GachaBallInstances are merged (either temporarily or permanently), any Item GachaBallInstances they had equipped are handled as follows:
All equipped Item GachaBallInstances from both input units are equipped to the newly merged Unit GachaBallInstance, this only happens on temporary merges since equipped items are not saved to the Master Run Gacha Pool.
10. Battle System
The Battle System governs combat encounters between the player's team of GachaBalls and enemy's team of GachaBalls and Hero Units.
### 10.1. Battle Phases & Turn Structure

At the start of battle, only the player's Hero Unit is automatically placed in the lineup. All other player units must be deployed from the bench.
The Player Bench has a fixed capacity of 3 slots. The battle inventory also has a fixed capacity of 3 slots. If there is no space on the Player Bench when a new Unit GachaBallInstance is acquired during battle, it will be placed in the next available slot in the player's Lineup. If both the Bench and Lineup are full, the Unit is sent directly to the Battle Discard Pile. Similarly, if the Battle Inventory is full when an Item GachaBallInstance is acquired, the Item is sent directly to the Battle Discard Pile.
Targeting is dynamic. When a unit is due to perform its action, it determines its target based on the current state of the battlefield at that exact moment.
Each turn in a battle node proceeds through distinct phases:
Start of Turn Phase (START_OF_TURN_PHASE):
The Flashcard Mini-Game is automatically initiated for the player, allowing them to earn Gacha Tokens.
Any passive Gacha Token generation effects (e.g., from Trinkets) occur.
Abilities and status effects that trigger ON_TURN_START resolve for all active GachaBalls.
Stacks of active status effects on all GachaBalls decay/tick down by their decay rate per turn.
Management Phase (BATTLE_MANAGEMENT_PHASE):
The player uses their obtained Gacha Tokens to draw GachaBallInstances from the Gacha Machines.
Player can perform strategic actions:
Deploy Unit GachaBallInstances from their Bench to their Lineup.
Rearrange Unit GachaBallInstances within the Lineup or between Lineup and Bench.
Perform Temporary Merges of compatible Unit GachaBallInstances (or Item GachaBallInstances).
Equip Item GachaBallInstances from their Battle Inventory onto Unit GachaBallInstances in the Lineup or Bench.
Use consumable Item GachaBallInstances.
This phase ends when the player clicks an "End Turn" button.
Combat Phase (COMBAT_PHASE):
Combat resolves automatically based on the current state of the Lineups. No direct player input is possible during this phase, though inspection of GachaBalls, pausing the game, or adjusting combat speed is available.
Team Action Order: Unit Action Order (within each team starting by the player's team): GachaBalls act one by one, from the backmost position to the frontmost position. Same order for the enemy team. Positions are numbered 1-6 from left (front) to right (back) for the player team. The enemy lineup is a direct mirror. The enemy's frontmost position (Position 1) is on their far left (from the player's perspective of the enemy's side), and their backmost position (Position 6) is on their far right. The enemy action order is also 6-1 (backmost to frontmost). 
This is the standard action order for the game but units can act out of order if their abilities specify otherwise or passively, triggered by abilities or items (e.g., retaliation attack when damaged). 

Actions: Each active Unit GachaBallInstance performs its action(s) as determined by its abilities.
Damage and effects are applied. Defeated Unit GachaBallInstances are removed from the Lineup and their current_location_state is updated to the discard pile.
The phase ends when all eligible GachaBalls on both teams have taken their actions for the turn.
End of Turn Phase (END_OF_TURN_PHASE):
Abilities and status effects that trigger ON_TURN_END resolve for all active GachaBalls like effects activations, ticks, stacks decay, etc.
Victory/defeat conditions are checked in real time and the battle ends immediately if any of them are met in any phase.
Victory: All enemy Unit GachaBallInstances are defeated or the Enemy Team's Hero leader Unit's dies. The battle ends, and the player proceeds to rewards.
Defeat: If the Hero Unit's HP is 0, the run ends.
If neither condition is met, the game proceeds to the next turn, returning to the Start of Turn Phase.
10.2. Combat Resolution Overview

The Default Attack deals physical damage equal to the unit's current_pwr to the single frontmost enemy unit.
Automatic: Once the Combat Phase begins, it resolves without further player input for that turn's actions.
Ability-Driven: Unit actions are primarily determined by their defined abilities, which specify targeting, effects, and conditions. A default attack action may exist if no other abilities are triggered or usable.
State Changes: Combat involves continuous updates to GachaBallInstance states (current_hp, status effects, location if defeated).
10.3. Item Equipping & Usage (only possible in Battle Management Phase)
Context: Occurs during the Battle Management Phase.
Source: Item GachaBallInstances are drawn from Gacha Machines into the Battle Inventory.
Equipping Process:
Player selects an equippable Item GachaBallInstance from their Battle Inventory.
Player selects a target Unit GachaBallInstance (on Bench or Lineup).
The system checks if the target Unit has an available generic item slot (based on its item_slot_count and currently equipped items).
If a slot is available, the Item GachaBallInstance is equipped: its current_location_state changes to EQUIPPED_ON_UNIT, and its ball_uuid is associated with the Unit GachaBallInstance. The item is removed from the Battle Inventory. Any ON_EQUIP effects of the item trigger.
If no empty slots are available, the action fails.
Consuming Process:
Player selects a consumable Item GachaBallInstance from Battle Inventory.
Player may select a target if the item requires one.
The item's effects are applied. if the item does not require a target, it is activated if used on any player unit.
If the item is consumed, the item ceases to exist in the Battle pool of GachaBalls.
Unequipping: Equipped items cannot be manually unequipped.
10.4. Positional Logic
Ability Interaction: Some abilities may specifically target or be affected by unit position (e.g., "affect adjacent allies," "deal more damage if behind a unit" "target backmost enemy").
Player Control: Players can arrange their Unit GachaBallInstances within their lineup slots during the Battle Management Phase.
10.5. Synergy System
Unit Tags: Each Unit GachaBallData includes a list of tags (e.g., "Warrior," "Mage," "Fire" "Undead").
Activation: Synergies are activated based on the number of unique Unit GachaBallInstances sharing specific tags currently active in the player's Lineup.
Synergy Tiers: Most synergies have multiple tiers of effectiveness, requiring more units with the relevant tag to activate stronger bonuses.
Example:
(2) Warriors: All "Warrior" tagged units gain 1 PWR.
(4) Warriors: All "Warrior" tagged units gain 2 PWR and 1 HP.
Bonus Effects: Synergy bonuses are typically passive stat boosts or modifications to abilities for the qualifying units or the entire team. These effects are defined using the same underlying logic as abilities (triggers, conditions, effects).
Dynamic Evaluation: Synergy bonuses are constantly evaluated and applied/removed whenever the composition of the player's Lineup changes (e.g., a unit is deployed, defeated, or moved).
11. Hero Unit
The Hero Unit is the player's central character and a special, persistent GachaBallInstance for the duration of a run.
Selection & Uniqueness: The player selects one Hero Unit at the start of a run from their unlocked pool of Heroes. Each Hero type has unique GachaBallData defining its:
Distinct starting base_hp and base_pwr.
One or more unique passive abilities or core mechanics that significantly influence playstyle.
A specific item_slot_count (e.g., 5 generic item slots).
A predefined starting set of GachaBallInstances that populate the initial Master Run Gacha Pool.
Persistence in Battle: The Hero Unit automatically participates in every battle of the run, starting in a designated position in the player's Lineup (e.g., backmost available slot).
Run Lifeline: The Hero Unit's current_hp is the player's overall health for the run. If the Hero's current_hp reaches 0 (either in battle or due to events), the run ends.
Restrictions:
While the Hero Unit cannot be moved to the bench, it can be freely rearranged between slots within the Player Lineup during the Management Phase.
Cannot be used as an ingredient in Merge operations.
Cannot be sold or removed from the run via Shop services.
Progression: The Hero Unit's base_hp or other base stats can be permanently upgraded for the current run through actions at Rest Sites ("Train & Enhance") or specific event outcomes.
12. Trinkets
Trinkets are special non-GachaBall entities that provide powerful, run-wide passive bonuses or modify core game mechanics. They are not Units or standard Items equipped in slots but rather global modifiers.
Nature: Global passive effects active for the duration of the run once acquired.
Acquisition:
Typically awarded for defeating Mini-Bosses.
Can be obtained as outcomes from special Event Nodes.
May be available as rare purchases in Shops or rewards from high-risk Rest Site gambles.
New Trinket types are unlocked for future runs via Meta-Progression.
Limitations:
A player can have a maximum of 5 active Trinkets at any one time.
If a 6th Trinket is acquired, the player must choose one of their current 5 Trinkets to replace (the replaced Trinket is lost for the current run).
Trinkets cannot be sold or directly removed by the player, only replaced.
Effects: Trinket effects are diverse and can impact any aspect of the game:
Resource generation (e.g., "Gain +1 Gacha Token per turn," "25% chance of getting an extra token per correct answer in the Flashcard Mini-Game").
GachaBall stats or abilities (e.g., "All Warrior GachaBalls gain +1 PWR," "Merged GachaBalls start gain +2 HP").
Gacha System (e.g., "25% chance to draw an extra GachaBall on every draw").
Flashcard Mini-Game (e.g., "+2 seconds on Flashcard Mini-Game timer").
Battle mechanics (e.g., "Player team's first unit to act,  acts twice in a row in Combat Phase").
Rarity/Power: Trinkets can have different rarities (Common, Uncommon, Rare, Legendary), influencing the magnitude or uniqueness of their effects.
UI Display: Active Trinkets are displayed in the Fixed Top Bar of the UI. Players can inspect them to see their effects.

13. Node Types & Logic
This section details the specific behaviors and interactions within each type of node the player can encounter on the path.
13.1. Battle Node
Behavioral Role: The primary source of combat encounters, GachaBall acquisition, and Gold.
Sub-Types:
Common Battle: Standard enemy encounters.
Elite Battle: More difficult encounters with stronger enemies and better rewards.
Mini-Boss Battle: Mandatory encounters at progression milestones, featuring unique mechanics and rewarding Trinkets.
Final Boss Battle: The ultimate encounter of the run, unlocked after all Flashcards in the Main Deck have been introduced.
Resolution: The node is resolved upon victory (leading to rewards) or defeat (leading to Game Over).
13.2. Shop Node
Behavioral Role: An economic hub for spending Gold to strategically improve the Master Run Gacha Pool.
Player Actions:
Purchase GachaBallInstance: Buy specific GachaBallInstances from a randomly generated stock to add them to the Master Run Gacha Pool.
Reroll Shop Inventory: Pay Gold to generate a new set of GachaBallInstances for purchase.
Remove GachaBallInstance: Pay Gold to permanently remove a chosen GachaBallInstance from the Master Run Gacha Pool.
Transform GachaBallInstance: Pay Gold to replace a chosen GachaBallInstance with another random GachaBallInstance of the same tier.
Resolution: The node is resolved when the player chooses to leave the shop.
13.3. Event Node
Behavioral Role: Presents narrative scenarios with choices that have risk/reward outcomes.
Interaction: The player is presented with a text-based scenario and a set of choices usually involving a flashcard mini-game and gacha machines for the rewards.
Potential Outcomes:
Gain or lose resources (Gold, Hero HP).
Acquire or lose a GachaBallInstance.
Acquire a Trinket.
Initiate a special battle or challenge.
Resolution: The node is resolved after the player makes a choice and its outcome is applied.
13.4. Rest Site Node
Behavioral Role: A node for recovery and enhancement between battles. The player may only choose one action per visit.
Player Actions:
Rest & Recover: Initiates a Flashcard Mini-Game. Earned Gacha Tokens are used on a "Healing Gacha" to draw healing-effect GachaBallInstances that restore the Hero's HP.
Train & Enhance: Initiates a Flashcard Mini-Game. Earned Gacha Tokens are used on a "Training Gacha" to draw GachaBallInstances that grant permanent stat upgrades to the Hero Unit for the current run.
Gamble: The player pays Gold to initiate a Flashcard Mini-Game. Earned Gacha Tokens are used on a "Gambling Gacha" to draw prizes in gold gachaballs or negative outcomes like gold loss or useless or even harmful gachaballs.
Resolution: The node is resolved after the player completes their chosen action.
13.5. Path Generation Logic
Structure: The player is always presented with a choice of three nodes to advance.
Procedural Generation: The types of nodes offered are determined by procedural rules. These rules weigh node types based on the current Day counter and player progression to ensure variety and a scaling challenge.
Milestones:
Mini-Boss nodes are guaranteed to appear upon reaching specific Flashcard Deck unlock milestones (e.g., every 20% of the Main Deck unlocked).
The Final Boss node is guaranteed to appear only when 100% of the Main Deck has been unlocked.
14. Status Effects
Status Effects are temporary conditions applied to Unit GachaBallInstances during battle that have effects on them.
Core Attributes:
Name: The identifier for the effect (e.g., "Burn", "Weaken").
Effect Logic: The mechanical function of the effect (e.g., deals damage equal to amount of stacks, reduces PWR by 50% while stacks last).
Duration: The number of turns the effect lasts. Duration typically decays at the start or end of a turn. Some effects may last until a condition is met (e.g., Affected Unit is damaged).
Stacks: Some effects can be applied multiple times, with stacks influencing potency and/or duration.
Visual Indicator: A unique icon displayed on the affected Unit to communicate its state to the player with amount of stacks next to it.
Example Status Effects:
Burn: At the start of its turn, the affected unit takes damage equal to the amount of stacks.
Weaken: The affected unit's PWR is reduced by 50% while the effect lasts (stacks above 0).
15. Progression Systems
15.1. Difficulty Scaling (Run Progression)
Difficulty scales primarily with the Day counter, which increases as the player resolves nodes.
Encounter Budget System: Each Day is associated with a budget that funds enemy team strength. As the Day counter increases, so does the budget, resulting in:
Increased base stats (HP, PWR) for enemy units.
More numerous or higher-tier enemy units in encounters.
More or higher-tier items equipped on enemy units.
Enemy Team Composition: Enemy teams are built from predefined templates that increase in complexity and strategic threat in later Days.
Enemy Leaders: Special enemy-only Hero units with powerful, unique abilities designed to disrupt player strategies. The frequency and power of Enemy Leaders increase with the Day counter or Node Battle type, Elite Battles have a guaranteed Enemy Leaders that are only found in Elite Battles.
Enemy Team Trinkets: Enemy teams may have passive effects similar to player Trinkets, increasing the challenge of the encounter and making every battle feel unique. Enemy teams can have up to 3 active Trinkets, displayed beneath their lineup. These Trinkets and their effects can be inspected by the player in the same manner as their own.
15.2. Meta-Progression
Meta-progression involves permanent unlocks that persist between runs, expanding the player's strategic options over time.
Unlockable Content: Players can permanently unlock:
New Hero Units.
New Flashcard Decks.
New GachaBallDefinitions (Units and Items) to be added to the potential pool of rewards and shop offerings in future runs.
New Trinkets.
New Merge Recipes.
Unlock Mechanism & Achievements:
Meta-progression is tied to an in-game Achievement system. The "Achievements" screen, accessible from the Title Screen, lists all possible achievements. It will display both completed achievements and the specific requirements for any uncompleted achievements. This is the primary location where players can track what they need to do to unlock new Hero Units, Flashcard Decks, GachaBall Definitions, Trinkets, and Merge Recipes.

The Codex (Reference Guide):
The Codex, accessible from the in-game UI, serves as the player's reference guide to all content they have successfully unlocked. Its purpose is to help with strategic planning by allowing the player to review the details of known content. For example, it will function as a "Recipe Book," showing the specific ingredient-and-result combinations for all unlocked Merge Recipes. It does not display information on how to unlock new content.
16. UI/UX Philosophy & Core Components
16.1. Design Philosophy
Target Platform: Designed for a 16:9 landscape aspect ratio, with controls and UI elements suitable for both PC (mouse) and mobile (touch).
Interaction Model: Primary interaction is click/tap. Drag-and-drop will be implemented post-MVP.
Feedback: All player actions must have clear and immediate visual and audio feedback.
Consistency: Interaction patterns (e.g., selection, confirmation, inspection) should be uniform across all game scenes.
16.2 UI Structure: The Persistent View
The game's interface is built around a persistent view to provide the player with constant access to core information and actions.
Fixed Top Bar: Always visible, this bar displays the player's Hero HP, current Gold, the Day counter, and active Trinkets. It also provides access to the game Menu.
Fixed Bottom Bar: Always visible, this bar houses the three Gacha Machines (Tier 1, 2, and 3). These machines are the player's constant interaction point for drawing and managing their GachaBall collections.
Dynamic Contextual Area: This is the large central portion of the screen. Its content changes based on the player's current location or node. It fluidly transitions to show the battleground, the shop interface, the node selection map, or event narratives without ever leaving the main game screen. This creates a seamless, unified experience.
Overlays: Modal windows that appear on top of the entire interface for focused tasks, such as inspecting a Gacha Machine's inventory or confirming a merge. These modal windows do not feature explicit 'close' buttons; they are designed to automatically dismiss if the player clicks anywhere on the screen outside the bounds of the modal window itself or any sub-windows spawned from it.
16.3 Core Interaction Model
Single Click/Tap: The primary method for selecting an entity (Unit, Item) or activating a button but also used for tooltips on or even inspection windows for elements that can't be selected like Gacha machines, keywords, Status Effects icons, etc.
Double click / clicking on the same selected element again / Right-Click / Long Press: Used to open inspection windows for an entity without performing an action.
16.4 Tooltip & Inspection System
Tooltips: Brief, context-sensitive information appears on hover (PC) to explain UI elements or keywords.
Inspection Windows: Modal pop-ups that display more information and inventories of GachaBallInstances, Gacha Machines, etc.
16.5. Accessibility
The UI will be designed with accessibility in mind.
Visual: Made easy to navigate and understand.
Audio: Separate volume sliders for music and effects.
16.6. Resource Display Conventions
All player-facing resources (HP, Gold, PWR) will be displayed as rounded integers. Numbers exceeding 999 will be abbreviated (e.g., 1200 becomes 1.2k).

17. Scene-Specific UI/UX
17.1. Title Screen: Presents main menu options: New Game, Continue, Achievements (displays all completed and uncompleted achievements and the requirements to unlock new content), Options, Quit.
17.2. Loadout Scene:
Hero Selection: A visual carousel to select a Hero, displaying their stats, abilities, and starting GachaBall set.
Deck Selection: A visual carousel to select a Flashcard Deck, displaying its subject and description.
17.3. Path Choice Scene: Displays the map with three selectable nodes. Each node icon clearly indicates its type (Battle, Shop, etc.) and may show a difficulty indicator (e.g., for Elite battles).
17.4. Shop Scene:
Shop Inventory Grid: Displays GachaBallInstances for sale with their Gold cost.
Services Panel: Buttons for Reroll, Remove, and Transform services.
17.5. Event Scene: A central panel displays background art and narrative text. Buttons below present the player's choices.
17.6. Rest Site Scene: Displays the three distinct action choices (Rest, Train, Gamble) as large, clear buttons.
## 18. Event-Driven Ability System
Abilities and effects in the game are driven by a structured, event-based system. An ability is defined by a combination of a Trigger, optional Conditions, and one or more Effects.
18.1. Triggers (Events)
These are the specific moments or conditions in the game when an ability can activate.
Examples:
ON_BATTLE_START: When a battle begins.
ON_TURN_START: At the start of any turn.
ON_TURN_END: At the end of any turn.
ON_ATTACK: When the unit initiates an attack.
ON_HURT: When the unit takes any damage.
ON_DEATH: When the unit's HP is reduced to 0.
ON_MERGE: When the unit is the result of a merge.
ON_FLASHCARD_CORRECT: When the player answers a flashcard correctly.
And many others states.
Besides states there's also passive triggers that are always listening for conditions to be met. Once the right conditions are met the trigger will activate. (e.g., if a unit has a specific tag and its HP is below a threshold, it will activate the trigger)
18.2. Conditions
These are optional checks that must be true for an ability to activate after its trigger occurs or passively for the trigger to activate.
Examples:
HEALTH_BELOW_X_PERCENT: Checks if a unit's HP is below a threshold.
HAS_STATUS_EFFECT_X: Checks if a unit has a specific status effect.
ATTACKER_HAS_TAG_X: Checks if the unit triggering an ON_HURT event has a specific tag.
RANDOM_CHANCE_X: Activates with a specified probability.
SYNERGY_TIER_X_ACTIVE: Checks if a specific synergy tier is active for the team.
18.3. Effects (Keywords)
These are the actual outcomes of the abilities, passives of units, items, trinkets, trait synegies, and other events.
Examples:
DEAL_DAMAGE: Deals damage.
INCREASE_HP: Increases HP.
APPLY_STATUS_EFFECT: Applies a status effect.
MODIFY_STAT_TEMPORARY: Changes a stat for the duration of the battle.
MODIFY_STAT_PERMANENT: Changes a base stat for the remainder of the run (rare, typically from events or training).
GAIN_GACHA_TOKENS: Grants the player Gacha Tokens.
DRAW_GACHABALL_TIER_X: Grants the player a random GachaBall from a specific tier.
18.4. Targeting Rules
These define who or what is affected by the effect.
SELF: The unit with the ability.
ATTACKER: The unit that initiated the current attack.
DEFENDER: The unit that was targeted by the current attack.
RANDOM_ENEMY: A random enemy unit.
RANDOM_ALLY: A random allied unit (excluding self).
ALL_ENEMIES: All enemy units.
ALL_ALLIES: All allied units.
ADJACENT_ALLIES: Units in positions next to the source unit.
ALLIES_WITH_TAG_X: All allied units that share a specific tag.

### 18.5. Effect Resolution Queue (The Stack)
When multiple effects are triggered by the same event, they are added to a resolution queue. The effects in the queue are then resolved one by one in the following priority order: 1. Active player's effects, 2. Enemy effects. Within each team, effects are resolved in lineup order from front-to-back (Position 1 to 6).

## 19. Save System
This section defines the data that must be persisted to allow players to quit and resume their progress. The system must handle two distinct types of save data.
19.1. Run-in-Progress Data
This data captures the complete state of a single, active run. It is created when a run begins and is deleted upon run completion (Victory or Failure). It must be saved automatically at the end of each resolved node.
Core Run State:
Current Day counter.
Chosen Hero Unit's definition_id.
Chosen Flashcard Deck's definition_id.
Player State:
Current Gold amount.
Hero Unit's current_hp and current base_hp (including any in-run upgrades).
Collection State:
A complete list of all GachaBallInstances in the Master Run Gacha Pool inventories (tier 1, 2, 3), including their definition_id, unique ball_uuid, and any instance_specific_modifiers.
A list of all active Trinkets.
Progression State:
The complete list of flashcards in the run's Active Deck.
The mastery value for each flashcard in the Active Deck.
The current state of the procedurally generated path options (save states are only done in the path choice scene and it's automatically done when the player enters the path choice scene).
The continue button in the title screen is only enabled if there is a run-in-progress data.
19.2. Meta-Progression Data
This data is persistent across all runs and stores the player's overall account progress. It is updated whenever a new unlock is achieved.
Unlocked Content:
List of all unlocked Hero Units.
List of all unlocked Flashcard Decks.
List of all unlocked GachaBallDefinitions.
List of all unlocked Trinket types.
List of all unlocked Merge Recipes.
Achievements:
A record of all completed achievements.
Player Settings:
Game settings such as audio volume, display options, and accessibility preferences.
## 20. Localization Support
The game must be designed to support multiple languages. This requires a system that separates user-facing text and assets from the core game logic.
Text Handling:
All user-facing text (UI elements, GachaBall names and descriptions, event narratives, etc.) must be retrieved from external language-specific files using localization keys (e.g., display_name_key, description_key).
The system must support dynamic resizing of text containers to accommodate varying string lengths between languages.
Asset Handling:
The system must be able to load language-specific versions of assets that contain text, such as tutorial images or certain UI graphics.
Formatting:
The system should be capable of handling different number and date formats as required by various cultures.