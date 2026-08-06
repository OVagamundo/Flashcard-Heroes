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
2.  **Encounter Selection & Resolution**: Choose between branch choices containing different encounter types (Battles, Shops, Merge Encounters, etc.). Resolving an encounter advances the run's difficulty (tracked via the "Day" counter).
3.  **Boss Milestones**: Boss battles are triggered dynamically by the player's Flashcard Mastery progression. Whenever the player unlocks a specific percentage of their flashcard deck, a Boss battle is scheduled, overriding standard encounters.
4.  **Final Encounter**: Defeating the Final Boss concludes the run.

### 2.1 Loadout Selection Scene
Before starting a run (or a testing session), the player configures their starting setup in the Loadout Scene:
- **Hero & Deck Carousels**: The screen features selection carousels for choosing a starting Hero and a starting Flashcard Deck. Both carousels display a three-item layout showing the previous item, the currently selected item (scaled up), and the next item, along with left and right navigation arrows.
- **Simultaneous Detail Panels**: Clicking a carousel item centers it and updates separate, persistent information panels for the Hero (displaying base HP/PWR, detailed descriptions, abilities, and flavor text) and the Deck (displaying card counts and descriptions).
- **Deck Ordering**: The player can configure the order in which flashcards are reviewed:
  - `REGULAR`: Reviews cards in their standard database order.
  - `INVERTED`: Reviews cards in reverse database order.
  - `RANDOM`: Shuffles cards deterministically using `RNGManager.map_rng.shuffle(...)`.
- **Deck Sorting**: Available decks are sorted dynamically to prioritize the `Katakana Main` deck at the start of the list.
- **Test Mode Starters Option**: In Test Mode, the player is presented with a dropdown utility allowing them to selectively add starting Gacha items or trinkets directly from the registry to the Hero's starting inventory for debug purposes.
- **Dynamic Localization Updates**: The scene dynamically swaps text elements and re-loads localized metadata if the system's locale is updated, preserving the player's active carousel selections.
- **Audio Integration**: Plays a matching background music track (`bgm/loadout.ogg`) upon entry.

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

## 9.3 Trinket Integration & Trigger Rules
Trinkets represent team-wide passive artifacts that register for and react to gameplay and management events. They adhere to these structural integration laws:
- **Broadcasting & Priority**: During Combat Broadcast sequences, active Trinket abilities resolve in the third priority band: **Unit -> Item -> Trinket**. This ensures unit-specific abilities and equipped items process their reactions before team-wide trinkets apply their modifications.
- **Turn-Start Processing & Suppression**: Turn-start trinkets (such as Spiked Armor, Purifying Pendant, and Awe Inspiring Totem) execute their effects during the Start of Turn phase. In accordance with first-turn suppression, these triggers are blocked on Turn 1 of any combat encounter, activating normally from Turn 2 onward.
- **Mini-Game Interceptors**: Certain trinkets (like Beginner's Charm) directly modify the Flashcard Resource Engine logic. They inspect the reviewed card's metadata (e.g., Mastery Level) and intercept the token distribution step to award bonus tokens.
- **Draw/Merge Event Registration**: Trinkets reacting to board state changes, draws, or merges (such as Trinity Charm or Hero's Catalyst) listen to GameManager or RunState signals. They track player draws from specific tier machines or merges of duplicate units across both active battle and management screens.

---

# 10. Flashcard Resource Engine (SRS)

The Spaced Repetition System (SRS) drives resource generation.

*   **Mini-Game Sprint**: A fast-paced timed session where the player answers multiple-choice questions.
*   **Accuracy Flow**:
    *   **Correct Answers**: Earn Gacha Tokens, increase the card's Mastery level, and increment the consecutive correct answer streak (triggering escalating sound pitch and visual effects).
    *   **Incorrect Answers**: Earn no tokens, decrease the card's Mastery level, and reset the streak to 0.
    *   **Skips**: Earn no tokens, decrease the card's Mastery level, but **preserve** the consecutive correct answer streak without resetting it.
*   **SRS Selection**: Cards with lower Mastery or those that have not been reviewed recently are prioritized by the card generator, ensuring targeted learning.
*   **Timer Adjustments**: Correct answers and skipped cards extend the active minigame timer, giving the player more time to answer subsequent cards.
*   **Streak & Juice Escalation**:
    *   *Audio*: Correct SFX pitch climbs by `0.05` per streak, and the minigame music track speed/pitch dynamically increases by `0.02` per streak (up to `1.2x`).
    *   *Visuals*: A border fire aura (`MinigameAuraVFX`) surrounds the minigame window edges, scaling its particle output with the streak and morphing colors (Cyan → Purple → Gold → Magenta) at specific milestones. Token pop animations also scale their physics/particle parameters with the streak tier.

---

# 11. Run Progression & Node Logic

Difficulty increases as the player resolves nodes and advances the Day counter, causing enemy lineups to generate with larger budgets and more advanced items or trinkets.

## 11.1 Standard Nodes
*   **Regular Battles**: Standard budget-based combat encounters.
*   **Shops**: Offer a random selection of GachaBalls. Players can spend Gold to reroll the shop's selection, with the cost escalating on subsequent rerolls during the same visit.
*   **Black Market**: Specialized nodes for curating deck composition. Players spend Gold to permanently **Remove** a GachaBall from their Run Inventory (with escalating costs) or **Transform** a GachaBall into a random alternative of the same tier (flat cost).
*   **Post-Battle Rewards**: Displays a lineup of random GachaBalls. The player can drag them to the **Collect** zone to add them to their Run Inventory, or to the **Sell** zone to discard them for Gold. Any uncollected rewards are automatically collected when leaving the node.

## 11.2 Standalone Encounters
*   **Unit Training Ground**: Allows players to permanently train the stats of any unit in their Run Inventory. The player selects a unit and drops it into the HP or PWR training zone, paying a Gold fee to start a study session. The Gacha Tokens earned during study are then spent to roll for permanent stat increases for that unit.
*   **Merge Encounter**: Allows players to merge GachaBalls in their Run Inventory directly. Merges here cost a flat Gold fee but bypass the usual run-level recipe unlock requirements, permanently unlocking the resulting recipe for the rest of the run.

## 11.3 Surprise Events
Surprise encounters are randomly selected from a pool of classic resource sites:
*   **Rest Site**: The Hero can study and spend Tokens to draw HP buff capsules.
*   **Gambling Den**: The Hero can study and spend Tokens to draw Gold bonus capsules.
*   **Training Grounds**: The Hero can study and spend Tokens to draw PWR buff capsules.
*   Applying drawn capsules permanently upgrades the Hero. Leaving the scene automatically applies any uncollected capsules.

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
