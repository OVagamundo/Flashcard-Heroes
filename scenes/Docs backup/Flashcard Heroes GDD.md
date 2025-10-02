Flashcard Heroes - Game Design Document (V5.1 - Definitive)
1. Game Overview & Premise
"Flashcard Heroes" is a single-player roguelike that integrates strategic auto-battler combat with an engaging flashcard learning system. The core premise revolves around players building a collection of "GachaBalls"—which encompass both combat Units and utility Items. This collection, the Run Inventory, functions as the player's "deck" for the current run, directly influencing which GachaBalls can be drawn during tactical battles.
Resource generation is intrinsically linked to player performance in fast-paced flashcard mini-games. Success demands a blend of long-term strategic planning, tactical decision-making in battles, and consistent engagement with the learning mechanics. Each run begins with the player selecting a Hero Unit whose health represents the player's life for the run. The primary objective is to navigate a path of encounters, strengthen the Hero and GachaBall collection, and ultimately defeat a series of challenging bosses.
2. Core Gameplay Loop & Flow
2.1. Run Structure
A single "run" is a complete playthrough attempt, from start to finish.
Loadout: The player selects a Hero and a Flashcard Deck. The Run Inventory is initialized.
Path Selection: The player is presented with a choice of three nodes, each representing a potential encounter.
Node Resolution: The player selects and resolves one node (e.g., Battle, Shop, Event, Rest Site).
Progression & Iteration: After resolving a node, the game's "Day" counter advances, increasing difficulty. The player returns to Path Selection.
Boss Encounters: At specific progression milestones, mandatory boss battle nodes appear.
Run Conclusion: The run ends in Victory (defeating the Final Boss) or Failure (Hero HP reaches zero).
2.2. Scene Transitions
The game fluidly transitions between states (e.g., Path Choice ↔ Battle) while maintaining the persistent state of the current run (Hero HP, Gold, Run Inventory, etc.). Temporary battle-specific data is created for each battle and discarded afterward.
3. Player Resources
Hero Health (HP): The current health of the player's Hero Unit serves as the overall health for the entire run. If it reaches 0, the run ends. It persists between all encounters.
Gold: The primary transactional currency for a run, used at Shop nodes. It is lost at the end of a run.
Gacha Tokens: A temporary, encounter-focused currency used to activate Gacha Machines. It is primarily earned from the Flashcard Mini-Game during a battle and resets to zero after each encounter is resolved.
#### 4. Flashcard System (Updated)

This system is the core mechanic for generating Gacha Tokens and driving player progression. It is designed as a high-speed, high-reward mini-game that tests the player's recall under pressure.

**4.1. Decks and Card Progression**
*   **Main Deck:** At the start of a run, the player selects a large deck of flashcards.
*   **Active Deck:** The run begins with the first 10 cards from the Main Deck forming the initial Active Deck.
*   **Card Introduction:** Each time the flashcard mini-game is triggered (in battle or at a Rest Site), one new card is drawn in order from the Main Deck and added to the Active Deck for the remainder of the run. This new card is first presented to the player on an information screen showing its question, answer, and a brief explanation. The player must click a "Got It!" button to dismiss this screen and begin the mini-game.

**4.2. Mini-Game Mechanics**
*   **Trigger:** The mini-game is automatically triggered at the start of the player's turn during the Management Phase in battles, and when choosing to "Train" at a Rest Site.
*   **UI:** The mini-game appears as a large modal pop-up window, disabling all other game interactions until it is complete.
*   **Gameplay Flow:**
    1.  If a new card is being introduced, it is shown first.
    2.  When the player clicks "Got It!" (or immediately, if no new card is shown), a session timer of **3 seconds** begins. This timer is for the entire session, not per question. The duration can be increased by Trinkets or other bonuses.
    3.  A question is displayed with 9 multiple-choice answers. These answers are the correct answers from 9 other random cards in the Active Deck.
    4.  The player clicks an answer.
        *   **Correct:** The answer flashes white, mastery level for that card increases by 1 (clamped at 5), and the next question appears instantly.
        *   **Incorrect:** The answer flashes red, mastery level for that card decreases by 1 (clamped at 1), and the next question appears instantly. There is no other penalty.
    5.  This continues until the 3-second timer expires, at which point the mini-game window closes and reports the results.
*   **Goal:** The primary goal is to answer as many questions correctly as possible within the short time limit, averaging about one correct answer per second for a proficient player.

**4.3. Spaced Repetition System (SRS) & Card Selection**
To optimize learning, the card chosen for each question is not completely random. The system uses a weighted random selection algorithm designed to be effective but not predictable.
*   **Weighted Factors:** The probability of a card being chosen is determined by:
    1.  **Mastery Level (High Weight):** Cards with a lower mastery level (1-5) are significantly more likely to be chosen.
    2.  **Time Since Last Review (Medium Weight):** Cards that haven't been seen for a while are more likely to appear.
    3.  **Randomness (Low Weight):** A small random factor ensures any card can still appear, keeping the player engaged.
*   **Rule:** The same card will never be presented twice in a row during a single mini-game session.

**4.4. Reward Context**
The rewards from the mini-game are **context-sensitive and do not carry over between scenes.**
*   **In Battle:** Each correct answer awards 1 Gacha Token. These tokens are added to the player's pool for the current battle and persist between turns, but are reset to zero after the battle encounter is resolved.
*   **At Rest Sites:** When "Training," the mini-game does **not** award Gacha Tokens. Instead, every two correct answers permanently increases the Hero's chosen stat (HP or PWR) by 1 for the rest of the run.
5. GachaBall System: Units & Items
"GachaBalls" are the collectible entities that form the player's team and arsenal.
GachaBall Definition: The immutable template or blueprint for a GachaBall type (e.g., "Warrior Type A"), defining its base stats, abilities, and tags.
GachaBall Instance: A live, unique, individual GachaBall existing within the game. Players collect and manage these instances, which track their own current stats and status.
Units: The characters that fight in battles. They have Health (HP) and Power (PWR) stats and can equip Items in a set number of slots.
Items: Equipment that provides stat bonuses or special effects when equipped on a Unit, or single-use consumables.
Tiers (0-3): A measure of a GachaBall's power level and draw cost. Tier 0 is reserved for Heroes.
Rarity: A measure of a GachaBall's uniqueness and power within its tier (e.g., Common, Uncommon, Rare, Legendary).
Tags: Descriptive labels on a GachaBall's definition (e.g., "Warrior," "Mage," "Beast") used for synergy calculations and ability targeting.
6. Inventories & Gacha System
6.1. Run Inventory
The player's persistent collection of unique GachaBall Instances for the current run. It functions as the player's "deck" and is managed between encounters via the Run Inventory Window.
6.2. Battle Inventory & Gacha Machines
During the management phase of a battle, the player has access to three Gacha Machines, corresponding to Tiers 1, 2, and 3.
Battle Inventory: At the start of each battle, a temporary copy of the entire Run Inventory is created. This is the Battle Inventory, and it serves as the drawable pool for the Gacha Machines for that battle only.
Drawing: The player spends Gacha Tokens to draw a random GachaBall from the machine of the corresponding tier. The cost scales with the tier (Tier 1 costs 1 token, Tier 2 costs 2, etc.).
Inspection: The player can inspect a Gacha Machine to view the current contents of its corresponding section of the Battle Inventory. This shows a summary of the types of GachaBalls and their counts (e.g., "Warrior x2, Archer x1").
Discard Pile: A single Battle Discard Pile exists for the current battle. Defeated units, their salvaged items, and GachaBalls drawn when the bench/inventory is full are sent here.
Reshuffling: If a tier's section of the Battle Inventory becomes empty, all GachaBalls of that same tier currently in the Discard Pile are moved back into the Battle Inventory, making them available to be drawn again. When a GachaBall is reshuffled, its stats (HP and Power) are fully restored to their base values, ensuring it is drawn in a fresh state.
End of Battle Cleanup: All temporary instances created for the battle are destroyed at its conclusion. The Run Inventory remains untouched.
7. Battle System
7.1. Battle Phases & Turn Structure
Each turn in a battle proceeds through distinct phases:
Start of Turn Phase: The Flashcard Mini-Game occurs. Start-of-turn abilities resolve.
Management Phase: The player uses Gacha Tokens, deploys units from their bench to the lineup, equips items, performs merges, and arranges their formation. This phase ends when the player clicks "End Turn."
Combat Phase: All actions resolve automatically without player input.
End of Turn Phase: End-of-turn abilities resolve. If no victory/defeat condition is met, the next turn begins.
7.2. Combat & Positional Logic
Board Structure: The player has 6 slots for their active lineup and 3 for their reserve bench. The Item Inventory also has 3 slots. If the bench or item inventory is full when a GachaBall is acquired, it is sent to the Discard Pile.
Action Order: Units act one by one, from back-to-front.
Player Team (Left Side): The action order is from right to left (slot 6 acts before slot 5).
Enemy Team (Right Side): The action order is also from their back to their front, which visually is right to left.
Default Attack: A unit's basic attack deals physical damage equal to its current Power to the single frontmost enemy unit.
7.3. Item Interactions
[UPDATED] This section has been updated to reflect the new, more complex item interaction rules.

Equipping: Items are dragged from the player's Item Inventory onto a Unit on the bench or lineup. If the unit has an available item slot, the item will be equipped.

Intra-Unit Management: Once an item is equipped on a unit, it can be freely managed on that same unit. The player can:
- Move: Drag an item to an empty slot on the same unit.
- Swap: Drag an item onto another equipped item on the same unit to swap their positions.
- Merge: Drag two identical, same-tier items together on the same unit to perform a merge. The resulting upgraded item will appear in the target slot.

Unequipping and Restrictions:
- Equipped items cannot be manually moved back to the Item Inventory or to a different unit.
- An item is only unequipped from a unit if the unit is used as a merge ingredient or is defeated in combat. In these cases, the salvaged item is sent to the Discard Pile.
8. Merge System
Merge Recipes: All valid merge combinations are defined by recipes.

Temporary Merge (In-Battle): Consumes two temporary GachaBalls and creates a new temporary GachaBall for the current battle only.
- Placement: If merged on the board, the result replaces the target. If two items are merged on a unit, the result replaces the target item. If merged in the Battle Inventory, the result is placed in the first available slot of the appropriate tier.
- Item Inheritance: All items equipped on the two ingredient units are automatically transferred to the newly merged unit, filling its available slots.

Permanent Merge (Out-of-Battle): Performed in the Run Inventory window. Permanently consumes two GachaBalls from the Run Inventory and adds the new, resulting GachaBall back into it.

Merge Choice: If a player attempts an action that could be either a Merge or a Swap, a ChoiceWindow will appear, allowing the player to confirm their intent.
9. Core Entities & Systems
9.1. Hero Unit
The player's central character. Its health is the run's health. It participates in every battle. The Hero unit is restricted and may only be placed in the main PlayerLineup; it cannot be moved to the bench or any inventory.
9.2. Trinkets
Special non-GachaBall items that provide powerful, run-wide passive bonuses. Players can have up to 5 active Trinkets. They are typically awarded for defeating Mini-Bosses.
9.3. Node Types & Logic

**Battle Node:** Standard combat encounters. Includes Common, Elite, and Boss variants.

**Encounter Budget System:**
To ensure varied and scaling challenges, COMMON and ELITE battle nodes do not use pre-defined enemy formations. Instead, they dynamically generate an enemy team using a budget-based system.
- **Daily Budget:** At the start of each new "Day," the encounter budget increases. The base budget is calculated as Day * 5 Gold.
- **Budget Allocation:** The system uses its gold budget to "purchase" a team of up to 6 units and a corresponding set of items from a pool of all available GachaBalls. The algorithm is designed to spend at least half of its budget on units first, ensuring a solid team composition, before spending the remainder on additional units or items.
- **Optimization:** The generation algorithm is optimized to spend its entire budget, ensuring that the challenge level is as close as possible to the day's intended difficulty. It will attempt to construct a full team that uses every last point of gold.
- **Elite Encounters:** ELITE battle nodes use the same dynamic generation system but with a significant advantage: their total gold budget is multiplied by 1.5, resulting in much tougher opponents with higher-tier units and more items.

**Shop Node:** An economic hub where players can spend Gold to acquire new GachaBalls.
- **Stock:** Presents 3 randomly generated GachaBalls for purchase when the node is entered
- **Purchasing:** 
  - Players can purchase any GachaBall if they have sufficient Gold
  - Cost is displayed clearly for each GachaBall
  - Purchased GachaBalls are added to the player's Run Inventory
  - Empty slots remain for the duration of the shop visit
- **Rerolling:**
  - Players can pay to refresh the shop's stock
  - Base reroll cost starts at 1 Gold
  - Cost increases by 1 Gold per reroll during the same shop visit
  - Reroll cost resets when entering a new Shop Node
- **Leaving:** Players can exit the shop at any time to return to Path Selection
Shop Node: An economic hub for spending Gold to purchase new GachaBalls for the Run Inventory or pay for services like rerolling the shop stock, removing a GachaBall, or transforming one.
Event Node: Narrative scenarios with choices that have risk/reward outcomes.
Rest Site Node: A recovery node where the player chooses one action: Rest (heal Hero), Train (triggers the flashcard mini-game where every two correct answers permanently increases a chosen stat by 1), or Gamble.
9.4. Event-Driven Ability System
Abilities are the core of tactical combat, defining how units behave beyond their basic stats. The system is designed to be event-driven, meaning abilities activate in response to specific moments in battle. Each ability is defined by a combination of components:

**Triggers**: The specific gameplay moments when an ability can activate. Examples include ON_DEATH (when the unit is defeated), ON_ATTACK (when the unit initiates an attack), or ON_HURT (when the unit takes damage).

**Conditions (Optional)**: A set of rules that must be true for the ability to activate. This allows for more strategic depth. For example, an ability might only trigger if "the enemy team has more units" or if "the slot in front is empty."

**Effects**: The actual outcomes of the abilities. These are the "verbs" of the system, such as DEAL_DAMAGE, MODIFY_STAT (to heal or buff), or SUMMON_UNIT.

**Targeting**: Rules that define who is affected by the effect, such as SELF, RANDOM_ENEMY, ADJACENT_ALLIES, or the specific TRIGGERING_ENTITY (e.g., the unit that just attacked this one).

**Default Attack Fallback Rule:**
A unit's primary action during the Combat Phase is determined by its ON_ATTACK abilities. If a unit has one or more abilities tied to the ON_ATTACK trigger, the game will check their conditions. If any condition is met, that ability will execute as the unit's action. However, if a unit has no ON_ATTACK abilities, or if none of their conditions are met, the unit will perform a Default Basic Attack. This standard attack deals damage equal to the unit's current PWR to the single frontmost enemy unit. This ensures every unit always has a valid action to take on its turn.
9.5. Status Effects
Temporary conditions applied to units during battle that have positive or negative effects, such as "Burn" (damage over time) or "Weaken" (reduced Power).
9.6. Synergy System
Passive bonuses are activated based on the number of unique units sharing specific tags (e.g., "Warrior," "Mage") currently in the player's Lineup.
10. Progression Systems
10.1. Difficulty Scaling (Run Progression)
The game's difficulty scales with the "Day" counter. This is managed by an Encounter Budget System. In later Days, the budget is higher, resulting in enemy teams that are constructed from better templates and can afford:
More numerous or higher-tier units.
Increased base stats.
More or better-equipped items.
Powerful Enemy Leaders and passive team-wide Trinkets.
10.2. Meta-Progression
By completing in-game Achievements, players can permanently unlock new content for all future runs, including new Heroes, Flashcard Decks, GachaBall types, Trinkets, and Merge Recipes.
Achievements Screen: Accessible from the main menu, this screen lists all achievements and the requirements to unlock new content.
The Codex: An in-game encyclopedia that serves as a reference for all unlocked content, including a "Recipe Book" for discovered merges.
11. UI/UX Philosophy & Core Interactions
11.1. UI Structure
The interface is built around a persistent view with three main areas:
TopArea: Always visible. Displays Hero HP, Gold, Day counter, and Trinkets.
BottomArea: Always visible. Houses the three Gacha Machines.
ContentArea: The large central portion of the screen that changes to show the battleground, shop, map, etc.
11.2. Core Interaction Rules

**Drag-and-Drop Intent:** The game automatically determines the player's intent when dropping one entity onto another. The logic is resolved in the following priority:
1. **Merge:** If a valid MergeRecipe exists for the two entities, a Choice Window appears (Merge/Swap). This applies to units on the board, items in inventory, and items equipped on the same unit.
2. **Equip:** If an Item from the ItemInventory is dropped on a Unit with an empty slot, it will Equip.
3. **Move/Swap:** If none of the above conditions are met, the game will attempt to Swap the positions of the two entities. This is only valid if both entities can legally occupy the other's starting position (e.g., a Hero cannot be swapped into the bench).

**Inspection Window System:**
The system for inspecting units, items, and their effects follows a strict set of hierarchical rules to ensure clarity and prevent UI clutter. These rules apply globally.

**Contextual Opening:** The method for opening an inspection window depends on the interaction model of its container:
- **Double-Click:** Required in interactive contexts where single-clicking is for selection and dragging (e.g., the battle board, the main inventory window). This prevents accidental openings.
- **Single-Click:** Used in contexts that are primarily for viewing (e.g., inspecting an item that is already equipped on a unit inside its inspection window, or viewing the discard pile).

**Hierarchical Behavior:**
- **Single Active Group:** There can only be one active inspection window "group" (a chain of parent-child windows) on screen at a time. Opening a new root-level window (e.g., inspecting a different unit on the board) closes the entire previous group.
- **Single Child Per Parent:** A parent window can only have one direct child window open. Requesting a new child (e.g., inspecting a second item on the same unit) will first close the existing child and any of its descendants.
- **Hierarchical Closing:** Clicking on the background of any window in a group closes all of its children, but not itself.

**System Interactions:**
- **Deselection on Open:** The action of opening any inspection window immediately deselects any currently selected GachaBall.
- **Dynamic Positioning:** Inspection windows are anchored to the UI element of the entity being inspected. They will dynamically track this anchor, repositioning themselves if the entity moves on the board.
- **Global Closing:** Clicking anywhere on the screen that is not part of an active inspection window will close the entire inspection window group.
11.3. Scene-Specific UI
Title Screen: Main menu with New Game, Continue, Achievements, Options, Quit.
Loadout Scene: Carousels for selecting a Hero and a Flashcard Deck.
Path Choice Scene: A screen displaying three selectable nodes for the next encounter.
Shop Scene: A grid displaying items for sale and panels for services.
Event Scene: A central panel for narrative text with choice buttons below.
Rest Site Scene: Displays the three distinct action choices as large buttons.