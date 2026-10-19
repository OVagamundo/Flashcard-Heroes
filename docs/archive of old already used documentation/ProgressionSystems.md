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
Scheduling: Bosses appear when the player reaches specific deck unlock thresholds. For a Full Deck, this is every 20% (maximum 5 bosses). For a Quick/Half Deck, this is every 33.3% (maximum 3 bosses).
Generator's Role: The EncounterGenerator uses this budget to "purchase" a team of units and items from the pool of all available GachaBallDefinition resources. For more details, see docs/EncounterSystem.md.
Effect of Scaling: As the Day counter increases, the budget grows, resulting in enemy teams that are progressively more powerful. In later days, players will face enemies that have:
More numerous or higher-tier units.
Increased base stats (if defined on higher-tier units).
More or better-equipped items.
(Potentially) Powerful enemy leaders with team-wide passive abilities.
(Potentially) Enemy trinkets providing team-wide passive effects.

### Non-Combat Encounters (Study Sessions)
As players progress along the path, they will encounter special "Study Session" nodes (Rest Sites, Training Grounds, Gambling Dens).
- **Cost Structure**: These encounters offer powerful, targeted benefits (healing, unit upgrades, high-risk rewards) and cost a flat fee (e.g., 5 Gold) to utilize, creating an economic choice between shopping and immediate run sustainment.

## Reward Reroll System
Players may spend gold to refresh the available rewards. Note: Rerolling reward screens is intended to be a feature unlocked by acquiring the **Reroll Trinket** (Future Content). It is currently enabled by default for testing purposes.
- **Cost**: Starts at **1 Gold**. Increases by **+1 Gold** for each subsequent reroll within the same session.
- **Reset**: The cost resets to 1 Gold at the start of next reward session.
- **Behavior**: Validates funds, executes `ShopRerollAction` via `ActionQueue`, plays `GoldCoinVFX`, clears current choices, and regenerates the pool using `RNGManager.reward_rng`.
- **Uniqueness**: The `WeightedPoolDirector` ensures that players are never offered trinkets they already own as rewards, using `reward_rng` for weighted selection.

### Recipe Unlocking (Run-Bound)
During a single run, players discover and unlock recipes dynamically. These unlocks persist only for the duration of the current run.
- **Merge Discovery**: Successfully performing a merge unlocks the recipe for future reference in that run.
- **Summon Discovery**: If a player's ability or item summons a unit whose recipe is not yet unlocked, that unit's recipe is automatically unlocked for the remainder of the run. This allows players to organically learn recipes through combat effects.

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

---

## 4. Content Expansion & Hero Content Pack Architecture

### 4.1 The Core Problem of Combinatorial Expansion
In the base roster:
- 4 Tier-1 Base Units -> (4 choose 2) = 6 Tier-2 Units.
- 6 Tier-2 Units -> (6 choose 2) = 15 Tier-3 Units.
- Total Base Playable Units: 25.

If content were added unrestrictedly across the whole roster:
- Adding 1 new Tier-1 unit yields 5 Tier-1 units.
- Tier 2 becomes (5 choose 2) = 10 units (+4 new Tier-2 units).
- Tier 3 becomes (10 choose 2) = 45 units (+30 new Tier-3 units!).
- An unrestricted 5th Tier-1 unit requires authoring 34 new merged units, bloating the active pool to 60 units. This destroys shop roll consistency, making duplicate merges and leveling unfeasible.

### 4.2 The Hero-Exclusive Content Pack Model (11 Units per Hero)
To deliver deep, asymmetric replayability without causing cross-roster combinatorial bloat, each playable Hero introduces a dedicated, self-contained 11-unit lineage pack.

When a player selects a Hero at run start, exactly 11 Hero-exclusive units are added to the neutral pool:
- 1 Hero-Exclusive Tier-1 Unit (H1)
- 4 Hero-Exclusive Tier-2 Units (H2_a, H2_b, H2_c, H2_d)
- 6 Hero-Exclusive Capstone Tier-3 Units (All pairs of Hero Tier-2 units)

Total Active Units in a Run:
  25 (Neutral Base Roster) + 11 (Selected Hero Pack) = 36 Active Units.

#### Tier-by-Tier Lineage & Rules:
1. **Tier 1 (Hero Starter)**:
   - Exactly 1 new Tier-1 unit (H1) tied to the Hero's thematic traits and element.
   - Appears in the shop alongside the 4 neutral base units (`ETnkPlaToy`, `FFigMecApp`, `WSupAniCos`, `ASpeFodToy`).
2. **Tier 2 (Hero x Neutral Hybrids)**:
   - The Hero Tier-1 unit (H1) merges exclusively with the 4 neutral Tier-1 units:
     * `H1 + ETnkPlaToy           -> Hero Tier-2 A (H2_a)`
     * `H1 + FFigMecApp  -> Hero Tier-2 B (H2_b)`
     * `H1 + WSupAniCos   -> Hero Tier-2 C (H2_c)`
     * `H1 + ASpeFodToy      -> Hero Tier-2 D (H2_d)`
   - Exactly 4 new Tier-2 units are created per Hero.
   - H1 cannot merge with itself to form a new unit (duplicates level up the unit).
3. **Tier 3 (Closed-Loop Hero Capstones)**:
   - Hero Tier-3 units are formed exclusively by merging pairs of Tier-2 units that originated from the Hero's Tier-1 unit.
   - The 4 Hero Tier-2 units yield exactly (4 choose 2) = 6 unique pairs:
     * `H2_a + H2_b -> Hero Tier-3 (H3_1)`
     * `H2_a + H2_c -> Hero Tier-3 (H3_2)`
     * `H2_a + H2_d -> Hero Tier-3 (H3_3)`
     * `H2_b + H2_c -> Hero Tier-3 (H3_4)`
     * `H2_b + H2_d -> Hero Tier-3 (H3_5)`
     * `H2_c + H2_d -> Hero Tier-3 (H3_6)`
   - Hero Tier-2 units do NOT merge with neutral Tier-2 units, completely walling off the 60-unit exponential explosion.

### 4.3 Standalone "Recipe-less" Wildcard Units
Standalone Wildcards are unique units added to the game without introducing merge recipes or parent dependencies:
- Standalone units have no merge recipe (cannot be crafted from Tier 1 or Tier 2 merges).
- They appear directly in the Gacha shop or as special reward drops (e.g., Elite battles, boss rewards, or high-tier shop slots).
- They possess standard elemental souls, class traits, and visual traits, and can be leveled up normally via duplicate merges.
- Functions: Trait Deficit Patching (filling synergy gaps without recipe cascades), Meta Tuning, and Gacha Chaser excitement.

### 4.4 Mathematical Pool & Progression Summary
Run Pool Size:
- Neutral Pool: 4 (T1) + 6 (T2) + 15 (T3) = 25 Units.
- Active Hero Pack: 1 (T1) + 4 (T2) + 6 (T3) = 11 Units.
- Optional Standalone Wildcards: Variable (e.g., 2 to 4 neutral wildcards).
- Total Active Units in a Run: Exactly 36 Units (plus any active wildcards).

This ensures complete mechanical closure: every Tier-2 crossbreed can be merged with any other Hero Tier-2 crossbreed to form a Tier-3 unit, while preserving the exact 36-unit working pool size needed for reliable shop rolls and duplicate leveling.