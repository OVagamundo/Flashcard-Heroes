# Progression Systems
The Progression Systems govern the player's advancement both within a single run and across multiple playthroughs. These systems are designed to create a scaling challenge and provide long-term replayability. They are divided into two distinct categories:
Run Progression (Difficulty Scaling): How the game's challenge increases during a single run.
Meta-Progression (Unlocks): How players permanently unlock new content for all future runs.
2. Run Progression: The "Day" & Encounter Budget
The primary mechanism for difficulty scaling within a run is the "Day" counter, which is tracked in the RunState.
Core Mechanic:
The Day counter advances by one each time the player resolves a node on the path (Battle, Shop, Rest Site, etc.).
The Day value is the primary input for the Encounter Budget System, which dynamically generates enemy teams for non-boss battles.
Encounter Budget System
This system ensures that the challenge of battle nodes scales directly with the player's progress through a run.
Budget Formula: `3 + (Day - 1)` Gold
Elite/Boss Multipliers: For ELITE or BOSS support units, the total budget is **0.85x** of the daily budget (since the Elite/Boss unit itself is free).
Scheduling: Bosses appear when the player reaches specific deck unlock thresholds (every 20%: 20%, 40%, 60%, 80%, 100%).
Generator's Role: The EncounterGenerator uses this budget to "purchase" a team of units and items from the pool of all available GachaBallDefinition resources. For more details, see docs/EncounterSystem.md.
Effect of Scaling: As the Day counter increases, the budget grows, resulting in enemy teams that are progressively more powerful. In later days, players will face enemies that have:
More numerous or higher-tier units.
Increased base stats (if defined on higher-tier units).
More or better-equipped items.
(Potentially) Powerful enemy leaders with team-wide passive abilities.
(Potentially) Enemy trinkets providing team-wide passive effects.



## Reward Reroll System
Players may spend gold to refresh the available rewards. Note: Rerolling reward screens is intended to be a feature unlocked by acquiring the **Reroll Trinket** (Future Content). It is currently enabled by default for testing purposes.
- **Cost**: Starts at **1 Gold**. Increases by **+1 Gold** for each subsequent reroll within the same session.
- **Reset**: The cost resets to 1 Gold at the start of next reward session.
- **Behavior**: Validates funds, plays `GoldCoinVFX`, clears current choices, and regenerates the pool.

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