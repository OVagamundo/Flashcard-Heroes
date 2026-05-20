# Flashcard Heroes - Gameplay Design Specification

This document defines the high-level gameplay contract for *Flashcard Heroes*. It specifies what the player can do, how resources flow, the strategic decisions the player makes, and the rules governing game flow.

---

# 1. Win & Loss Conditions

## Winning a Run
A run is successfully completed when the player defeats the Final Boss.

## Losing a Run
A run is lost immediately if the Hero's health (HP) reaches zero. 
*   **Permadeath**: Upon victory or defeat, the run's save file is deleted, and the player must start a new run.
*   **Hero Unit**: The Hero participates directly in combat alongside standard units and is subject to the same rules, except that the Hero is restricted to the active board and cannot be placed on the bench.

---

# 2. Run Structure & Progression

Each run progresses through a series of sequential choices:
1.  **Loadout Selection**: Choose a starting Hero and an initial Flashcard Deck.
2.  **Path Selection & Node Resolution**: Choose between branch paths containing different node types (Battles, Shops, Rest Sites, etc.). Resolving a node advances the run's difficulty (tracked via the "Day" counter).
3.  **Boss Milestones**: Boss battles are triggered dynamically by the player's Flashcard Mastery progression. Whenever the player unlocks a specific percentage of their flashcard deck, a Boss battle is scheduled, overriding standard nodes.
4.  **Final Encounter**: Defeating the Final Boss concludes the run.

### Run-Persistent State (Carries Over Between Nodes)
*   Hero and unit base stats (HP, PWR).
*   Gold.
*   Run Inventory (the permanent collection of units and items).
*   Equipped Trinkets.
*   Flashcard deck mastery levels and unlocked cards.

### Battle-Temporary State (Resets After Each Encounter)
*   Gacha Tokens.
*   Temporary stat buffs or modifications applied during combat.
*   Battle Inventory (draw pools).
*   Discard Pile.
*   Lineup and bench combat placement.

---

# 3. Core Resource Economy

The game operates on a dual-economy system that separates long-term strategy from tactical in-battle execution.

## 3.1 Gold (Run Economy)
*   **Purpose**: Used to purchase upgrades, manage deck composition (removing or transforming units), and initiate training or merging outside of battle.
*   **Acquisition**: Earned as rewards for winning battles or selling GachaBalls.
*   **Difficulty Role**: Player gold and collection size are used by the difficulty engine as a reference point for budgeting enemy teams.

## 3.2 Gacha Tokens (Battle Economy)
*   **Purpose**: Spent during the Management Phase of battles and reward nodes to draw units or items from the Gacha machines.
*   **Acquisition**: Generated exclusively by answering questions correctly during the Flashcard mini-game.
*   **Behavior**: Gacha Tokens are temporary. They can be banked between turns within a single battle, but reset to zero once the encounter concludes.

---

# 4. Battle Structure & Flow

Battles are resolved in a turn-based loop consisting of four phases:

1.  **Start of Turn**:
    *   **The Sprint**: The player plays a timed Flashcard mini-game to earn Gacha Tokens.
    *   **Abilities Trigger**: Start-of-turn passive abilities and trait effects resolve.
    *   **First-Turn Suppression**: To allow players to establish their lineup, all start-of-turn abilities and trait triggers are suppressed on the very first turn of a battle, resuming normally on turn two.
2.  **Management Phase**:
    *   The player makes tactical choices: drawing units/items, arranging their formation, equipping items, or merging GachaBalls on their bench or board.
3.  **Combat Phase**:
    *   Units resolve their actions automatically, sequentially, and deterministically.
4.  **End of Turn**:
    *   End-of-turn abilities, status effects (like Burn damage), and cleanup steps resolve. If neither side has won, the loop advances to the next turn.

---

# 5. Player Actions & Interaction

## 5.1 Controls & Interaction Models
*   **Mouse / Touch**: The game supports drag-and-drop actions, click/tap selection, and hover/long-press peeking.
*   **Intent Resolution**: When dropping a GachaBall onto another or onto a slot, the system resolves player intent in order of priority:
    1.  **Merge**: If the GachaBalls form a valid recipe, they combine.
    2.  **Equip**: If an item is dropped on a unit with an empty slot, it is equipped.
    3.  **Use**: If a consumable item is dropped on a unit, its effect triggers immediately.
    4.  **Swap/Move**: If slots are compatible, the units swap positions.

## 5.2 Management Phase Verbs
During the Management Phase, the player makes the following decisions:
*   **Draw**: Spend Gacha Tokens to pull random GachaBalls from Tier 1, 2, or 3 machines onto the bench.
*   **Place/Rearrange**: Position active units on the board (up to five active slots) or return them to the bench. Units resolve combat actions from front to back.
*   **Equip Item**: Drag items onto active units. Units are restricted to a single item slot. Equipping a new item over an existing one discards the old item to the Discard Pile.
*   **Merge**: Combine units on the board or bench to level them up or evolve them into new definitions.

---

# 6. Gacha System & Deck Curation

## 6.1 Gacha Machines & Pools
*   Draw pools are populated from the player's Run Inventory. There are three machines representing different power tiers.
*   The exact pool contents and remaining GachaBalls in each machine are transparently viewable by the player at any time.

## 6.2 The Strategic Duality: Swarming vs. Slot Power
*   **Swarming**: Tier 1 units are cheap to draw in battle (costing few Gacha Tokens) but have low base stats. Merging duplicate Tier 1 units permanently upgrades their level, which doubles their Gold cost in shops, but their Gacha Token draw cost remains low, yielding high deployment efficiency.
*   **Slot Power**: Higher-tier units (Tiers 2 and 3) cost more Gacha Tokens to draw but provide concentrated slot power and high-impact abilities.
*   **Exhaustion Risk**: Because defeated units are placed in the Discard Pile permanently for the remainder of a battle, an ultra-lean deck can run out of GachaBalls during prolonged encounters, resulting in defeat. Players must balance deck predictability (small decks) against raw endurance (larger decks).

---

# 7. Combat Resolution Contract

Combat is fully deterministic. There are no critical hits, evasion, or hidden modifiers. Damage dealt is equal to a unit's Power (PWR) minus the target's Armor.

## 7.1 Action Order
*   **Player Initiative**: The entire player team initiates its actions before the enemy team.
*   **Direction**: Both teams resolve actions from the frontmost slot (index 0) to the backmost slot.

## 7.2 Reaction Priority Bands
When abilities or actions trigger reactions, they resolve in specific priority bands:
1.  **Interceptors**: Triggers that resolve before damage is applied.
2.  **Reactionary Summons**: High-priority triggers, such as resurrection or emergency unit summons.
3.  **Standard Effects**: Healing and buff applications.
4.  **Modifiers**: Counter-attacks, status effects, and defensive adjustments.
5.  **Standard**: Default combat attacks.
6.  **Delayed**: Reinforcements and extra turns.

## 7.3 Default Attacks & Visuals
*   Units attack the enemy in the corresponding mirrored slot, falling back to the frontmost active enemy.
*   Units with zero PWR still execute their attack sequence and trigger visual impacts, even though they deal no damage, ensuring consistent visual feedback.

---

# 8. Merge System Rules

Merging is a permanent modification outside of battle (costing Gold) or a temporary modification during battle (consuming Gacha Tokens).

## 8.1 Recipe Discovery & Unlocks
*   Standard recipes are locked at the start of a run.
*   Acquiring a unit or item through rewards or events unlocks its recipe for the remainder of the run.

## 8.2 Evolutionary Merging (Leveling Up)
*   Merging two duplicate, identical units of the same level upgrades the unit to the next level (up to level three).
*   **Stat Inheritance**: The resulting upgraded unit inherits any stat surplus, active buffs, reductions, or status effects from both parent units as a persistent component.

## 8.3 Recipe Merging (Tiering Up)
*   Merging different specific GachaBalls according to an unlocked recipe combines them into a higher-tier unit.
*   The resulting unit always starts at Level 1, but its base stats inherit the stat surplus of its parent units.
*   **Item Transfer Priority**: During a merge, only one equipped item is carried over to the result. The target slot's item has priority, falling back to the source slot's item. All other items are discarded.

---

# 9. Elemental Traits & Trinkets

Units carry elemental tags (Fire, Earth, Water, Air) representing their souls. When the player acquires the corresponding elemental Trinket, team-wide passive traits are unlocked.

## 9.1 Snapshot Locking
At the start of each turn, the game takes a snapshot of the active souls on the board. Trait strength is locked for the duration of the combat turn, preventing traits from fluctuating mid-combat as units die or are summoned.

## 9.2 Trait Behaviors
*   **Fire**: Focuses on offensive pressure, applying Burn stacks to the enemy team.
*   **Earth**: Focuses on defensive sustain, granting Armor and Spikes to the player's lineup. Earth units receive double the armor bonus.
*   **Water**: Focuses on resilience, healing adjacent allies.
*   **Air**: Focuses on disruption, stealing Power (PWR) from mirrored enemy slots.
*   *Scaling*: Trait effects scale in intensity as the player accumulates more souls of that element on the board.

---

# 10. Flashcard Resource Engine (SRS)

The Spaced Repetition System (SRS) drives resource generation.

*   **Mini-Game Sprint**: A fast-paced timed session where the player answers multiple-choice questions.
*   **Accuracy Flow**:
    *   **Correct Answers**: Earn Gacha Tokens and increase the card's Mastery level.
    *   **Skips & Incorrect Answers**: Earn no tokens and decrease the card's Mastery level.
*   **SRS Selection**: Cards with lower Mastery or those that have not been reviewed recently are prioritized by the card generator, ensuring targeted learning.
*   **Timer Adjustments**: Correct answers and skipped cards extend the active minigame timer, giving the player more time to answer subsequent cards.

---

# 11. Run Progression & Node Logic

Difficulty increases as the player resolves nodes and advances the Day counter, causing enemy lineups to generate with larger budgets and more advanced items or trinkets.

## 11.1 Standard Nodes
*   **Regular Battles**: Standard budget-based combat encounters.
*   **Shops**: Offer a random selection of GachaBalls. Players can spend Gold to reroll the shop's selection, with the cost escalating on subsequent rerolls during the same visit.
*   **Black Market**: Specialized nodes for curating deck composition. Players spend Gold to permanently **Remove** a GachaBall from their Run Inventory (with escalating costs) or **Transform** a GachaBall into a random alternative of the same tier (flat cost).
*   **Post-Battle Rewards**: Displays a lineup of random GachaBalls. The player can drag them to the **Collect** zone to add them to their Run Inventory, or to the **Sell** zone to discard them for Gold. Any uncollected rewards are automatically collected when leaving the node.

## 11.2 Training Sites (Rest Site / Dojo / Gambling Den)
*   **Purpose**: Dedicated nodes for permanently buffing the Hero.
*   **Flow**: The Hero is placed in the prize lineup. The player can Study once to play the Flashcard minigame and earn Gacha Tokens.
*   **Spending**: Gacha Tokens are spent on tiered machines to draw capsules containing HP, PWR, or Gold buffs.
*   **Application**: Applying drawn capsules permanently upgrades the Hero's base HP (Rest Site), base PWR (Dojo), or grants Gold (Gambling Den). Leaving the scene automatically applies any uncollected capsules.

## 11.3 Surprise Events
Surprise encounters are randomly selected node events:
*   **Unit Training Ground**: Allows players to permanently train the stats of any unit in their Run Inventory. The player selects a unit and drops it into the HP or PWR training zone, paying a Gold fee to start a study session. The Gacha Tokens earned during study are then spent to roll for permanent stat increases for that unit.
*   **Merge Encounter**: Allows players to merge GachaBalls in their Run Inventory directly. Merges here cost a flat Gold fee but bypass the usual run-level recipe unlock requirements, permanently unlocking the resulting recipe for the rest of the run.

---

# 12. UI/UX & Information Visibility

*   **Full Information Transparency**: Players can inspect all board states, remaining machine draw probabilities, active traits, status effects, and discard piles.
*   **Playback Speed**: Players can adjust combat resolution speed (1x, 2x, 3x) or pause combat to step through triggers one event at a time.
*   **Inspection Hierarchy**: Hovering over an element previews its details. Clicking locks the inspection window open. Opening a new inspection closes sibling or descendant windows to maintain a clean layout.
*   **Readability Cap**: To prevent visual clutter and ensure text fits within the UI, unit stats (HP, PWR) and status stacks utilize a maximum double-digit display cap. Deterministic math continues to calculate higher values behind the scenes, but values are truncated visually.

---

# 13. Economic Theory of Board Value

To maintain strategic depth and balance, the game adheres to these economic principles:
*   **Board Value Equation**: Board Value equals the sum of Unit Base Packages (stats and item slots) plus the Interaction Surplus (synergies, abilities, and buffs). Success relies on maximizing the Interaction Surplus.
*   **PWR vs. HP Hierarchy**: PWR is valued higher than HP because PWR scales active, multiplicative abilities, while HP represents a flat survival buffer.
*   **Economic Duality**:
    *   *Run Economy (Gold)*: Curating and maintaining a lean deck.
    *   *Battle Economy (Tokens)*: Spinning Gacha machines to draw and field the curated deck.
