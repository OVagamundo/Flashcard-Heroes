Progression Systems
Version: 1.0
Status: Active
1. Purpose & Responsibility
The Progression Systems govern the player's advancement both within a single run and across multiple playthroughs. These systems are designed to create a scaling challenge and provide long-term replayability. They are divided into two distinct categories:
Run Progression (Difficulty Scaling): How the game's challenge increases during a single run.
Meta-Progression (Unlocks): How players permanently unlock new content for all future runs.
2. Run Progression: The "Day" & Encounter Budget
The primary mechanism for difficulty scaling within a run is the "Day" counter, which is tracked in the RunState.
Core Mechanic:
The Day counter advances by one each time the player resolves a node on the path (Battle, Shop, Event, etc.).
The Day value is the primary input for the Encounter Budget System, which dynamically generates enemy teams for non-boss battles.
Encounter Budget System
This system ensures that the challenge of COMMON and ELITE battle nodes scales directly with the player's progress through a run.
Budget Calculation: The GameManager calculates the gold budget for an encounter before invoking the EncounterGenerator.
Base Budget: Day * 5 Gold
Elite Multiplier: For ELITE nodes, the total budget is multiplied by 1.5.
Generator's Role: The EncounterGenerator uses this budget to "purchase" a team of units and items from the pool of all available GachaBallDefinition resources. For more details, see docs/EncounterSystem.md.
Effect of Scaling: As the Day counter increases, the budget grows, resulting in enemy teams that are progressively more powerful. In later days, players will face enemies that have:
More numerous or higher-tier units.
Increased base stats (if defined on higher-tier units).
More or better-equipped items.
(Potentially) Powerful enemy leaders with team-wide passive abilities.
(Potentially) Enemy trinkets providing team-wide passive effects.

## Boss Rewards

After defeating a boss, the reward system differs from regular battles:

### Trinket Rewards
- Upon boss victory, the player is offered **3 random trinkets** instead of regular gacha balls.
- The player must choose **one trinket** to add to their trinket inventory for the rest of the run.
- Trinkets provide powerful team-wide passive abilities.

### Gold Alternative
- Instead of choosing a trinket, the player may opt for **10 gold**.
- This is higher than the typical gold reward due to the value of trinkets.

### Trinket Acquisition
Trinkets are exclusively obtained from boss victories. They cannot be purchased in shops or found as regular battle rewards.

3. Meta-Progression: Achievements & The Codex
Meta-progression provides long-term goals that persist between runs. This system is centered around completing in-game Achievements.
Achievements
Definition: An Achievement is a specific goal for the player to complete (e.g., "Defeat the Final Boss with the Warrior Hero," "Perform 10 unique merges in a single run").
Unlocks: Completing an Achievement permanently unlocks new content for all future runs. This content can include:
New playable Heroes.
New Flashcard Decks.
New GachaBall types (Units and Items) added to the general pool.
New Trinkets.
New MergeRecipe definitions.
Tracking: The player's completed achievements are stored in a persistent save file, separate from any in-run state.
The Codex & UI
Achievements Screen: Accessible from the main menu, this screen lists all possible achievements (both locked and unlocked). It shows the requirements for each and the specific content it unlocks upon completion.
The Codex: An in-game encyclopedia that serves as a comprehensive reference for all content the player has unlocked. It is a key part of the player's sense of long-term accomplishment. The Codex includes:
A bestiary of all encountered units.
A catalog of all seen items.
A "Recipe Book" that automatically records all MergeRecipe definitions the player has successfully used or unlocked. This allows players to reference valid merges without having to memorize them.