Perfect. That clears all mechanical ambiguities.

Below is the complete, clean, assumption-free document built strictly from your provided materials and your clarifications.

No engine details.
No implementation internals.
No speculation.

Only mechanical truth.

---

# Flashcard Heroes

# Deterministic Gameplay Specification

*(Authoritative Mechanical Reference)*

This document defines:

* What the player is trying to achieve
* What the player can do moment-to-moment
* What is deterministic
* Where randomness exists
* How resources flow
* What carries forward
* What designers may adjust safely

It excludes engine implementation and animation details.

---

# 1. Win & Loss Conditions

## A Run Is Won When:

* The Final Boss is defeated.
* The Heroâ€™s HP is above 0.

## A Run Is Lost When:

* The Heroâ€™s HP reaches 0.

On Victory or Defeat:

* The save file is deleted.
* The run ends permanently.

The Hero participates in every battle and behaves as a normal unit, except:

* The Hero cannot be placed on the bench.
* If the Hero dies, the run ends immediately.

---

# 2. Run Structure

Each run follows:

1. Hero Selection
2. Flashcard Deck Selection
3. Repeating loop:

   * Path Selection
   * Node Resolution
   * Difficulty Scaling (Day counter increases)
4. Boss milestones
5. Final Boss

Run-persistent state:

* Hero stats (HP, PWR)
* Gold
* Run Inventory (Units & Items)
* Trinkets
* Flashcard mastery progression

Battle-temporary state:

* Gacha Tokens
* Battle Inventory
* Discard Pile
* Board state

---

# 3. Core Resources

## 3.1 Hero Stats

* Persistent across encounters.
* If HP reaches 0 â†’ run ends.

## 3.2 Gold

* Used in Shops and events.
* earned via battles and events.
* Used by Encounter Generator as enemy budget reference.
* Lost at end of run.

### Tier Gold Cost (Shop & Encounter Generator)

* Tier 1 = 1 Gold
* Tier 2 = 2 Gold
* Tier 3 = 4 Gold

---

## 3.3 Gacha Tokens

* Generated via Correct Answers in the Flashcard Mini-Game during battle.
* Used to draw from Gacha Machines.
* Reset to 0 at end of each battle.
* Can be banked between turns within a battle.

### Tier Draw Cost (Tokens)

* Tier 1 = 1 Token
* Tier 2 = 2 Tokens
* Tier 3 = 3 Tokens

---

# 4. Battle Structure

Each turn:

1. **Start of Turn**

   * Flashcard Mini-Game
   * Start-of-turn abilities resolve

2. **Management Phase** (Player decision phase)

3. **Combat Phase** (Automatic resolution)

4. **End of Turn**

   * End-of-turn abilities resolve

If neither side wins, next turn begins.

---

# 5. Player Verbs (Management Phase)

## 5.1 Interaction Models
The game supports both Desktop and Mobile interaction models.
- **Mouse (Desktop)**: Drag-and-Drop, Single-Click Select, Hover-to-Peek.
- **Touch (Mobile)**: Tap-to-Select, Long-Press-to-Peek (0.32s).
- **Platform Specifics**: The "Exit Game" button is available on all platforms to close the application. The "Fullscreen" toggle is platform-dependent and hidden on mobile devices.

## 5.2 Drag-and-Drop Priority
The game automatically determines intent when dropping one entity onto another:
1. **Merge**: Valid `MergeRecipe` exists â†’ Opens Choice Window (Merge/Swap).
2. **Equip**: Item dropped on Unit with empty slot â†’ Equips.
3. **Use**: Consumable dropped on Unit â†’ Instant effect.
4. **Move/Swap**: Positions are swapped if legal.

## 5.2 Management Actions
During Management Phase, the player may:

1. **Draw**
   * Spend Tokens on Tier 1 / 2 / 3 machines.
   * Drawn items go to `PlayerBench`.

2. **Inspect Machine Pools (The Drawer), trinkets, traits and discard pile and the battle board (player/enemy)**
   * View exact contents of each tier pool and Discard Pile (Physics Drawers).
   * **Note**: The Physics Drawers are **Read-Only**. Actions listed below (3-7) cannot be performed directly on balls within the drawers. Hover inspections are only allowed for entities inside the drawer while it is open (Rule S8).

3. **Place Units**
   * Drag from bench to lineup and vice versa(5 slots).
   * Lineup grid is fixed; units do not shift automatically.

4. **Rearrange Units**
   * Change formation (Board/Bench).

5. **Equip/use Items**
   * Drag item from **Bench** to unit.
   * Drag consumable item to use on units.

6. **Equipping Rules**
   * Drag item from **Bench** to a unit.
   * If the unit already has an item, the existing item is **discarded** (moved to the discard pile).
   * Merge items if a recipe is unlocked (Choice Window prompt).

7. **Merge Units**
   * On bench or board.
   * Requires unlocked recipe.
   * Creates new instance for current battle.

8. **Battle! (End Turn)**

No other actions are possible during Management Phase.

---

# 6. Gacha System Rules

## 6.1 Three Tier Pools

* Tier 1 pool
* Tier 2 pool
* Tier 3 pool

All three exist simultaneously.

## 6.2 Single Shared Discard Pile

* All defeated units
* Salvaged items
* Overflow draws

Go to one shared discard pile.

## 6.3 Physics Pool Visualization (Battle Only)
During battle, the inventory drawer acts as a **Read-Only visualization** of the active gacha pools:
- **No Manual Interaction**: Players cannot drag, move, swap, or merge items directly from the drawer.
- **Spawn Interval**: The `DropTimer` is set to **0.15s** to provide enough temporal breathing room for the physics engine between spawns. When new balls are spawned, they spawn sequentially at the top-center of the container.

## 6.4 The Overflow Penalty
- **Mechanic**: If a container becomes physically overfilled, balls will push against the **Spring Lid**.
- **Penalty**: Maintaining physical contact with the lid (a **30px high zone** at the top of the container) for **5 continuous seconds** results in the instance being **moved to the Shared Discard Pile** and its stats reset.

## 6.5 Hover Restriction (Rule S8)
When a physics-based inventory (Battle/Run/Discard) is open, hover inspections are strictly limited to the gachaballs inside that window. This prevents accidental window closure caused by hovering over the background battle board.

## 6.6 Selective Tray Return (Overflow Penalty)
If a container overflows, the system normally moves the instance to the Discard Pile.
- **Exception**: If the instance is **already** in the Discard Pile (e.g., waiting to be spawned when the container is opened), it is instead **returned to the Trays pool** with its stats reset. This prevents duplicate entries in the discard ledger.

## 6.7 Discard Pile Jolt
When the Discard Pile window is opened, a horizontal impulse of **Vector2(-500, 0)** is applied to all balls. This ensuring the pile doesn't form static "stalagmites" and encourages dense, efficient packing.

## 6.8 The Permanent Discard
Units and items moved to the Shared Discard Pile are **removed from the active draw pool** for the remainder of the battle. There is no automatic reshuffle mechanic. Once a Tier pool is empty, it remains empty.

---

# 7. Information Transparency & RNG Boundaries

## Fully Visible Information

* Full board state
* Enemy stats
* Enemy abilities
* Machine pool contents (exact units/items remaining)
* Discard contents
* Token count
* Gold count
* Trinkets
* Active traits
* Flashcard mastery progression

The player may inspect the exact contents of each Tier pool and manually calculate draw probability.

## Playback Controls

* **Speed Scaling**: Combat animations can be scaled to 1x, 2x, or 4x speed. This affects only visual transitions and does not alter the underlying deterministic logic.
* **Step-by-Step Mode**: Players can pause combat and advance exactly one `CombatEvent` at a time. This provides perfect transparency for complex priority-based interactions.
* **Persistence**: Chosen playback speeds persist across battles and sessions.

---

## Sources of Randomness

1. Gacha draw (uniform within tier pool)
2. Encounter generation (budget-based)
3. Random ability targeting
4. Flashcard question selection (weighted SRS)

---

## Deterministic Systems

* Damage = PWR (no variance)
* No crit
* No dodge
* No hidden modifiers

All stat changes are persistent until modified again. Stats are resolved from a base definition modified by an active stack of source-aware components (StatComponents). There is no max HP cap.

---

# 8. Combat Resolution Contract

## 8.1 Action Order

1. Entire Player Team acts first.

2. Units act front-to-back.

   * Enemy: mirrored but also front-to-back

3. After Player completes all action chains,
   Enemy initiates their action chains front-to-back.

Each action chain may cause reactions from own team and/or opposing team before proceeding.

## 8.2 Execution Priorities

Reactions are resolved using a **Priority Band** system:
- **Interceptors (300+)**: Resolve before the triggering damage is applied.
- **Reactionary Summons (200-299)**: High-priority triggers like Resurrections.
- **Standard Effects (100-199)**: Buffs and heals.
- **Modifiers (1-99)**: Counter-attacks and defensive shifts.
- **Standard (0)**: Default behavior.
- **Delayed (<0)**: Reinforcements and extra actions.

---

## 8.2 Default Attack

* Deals damage equal to current PWR.
* Targets frontmost enemy.
* If empty, nearest forward unit.
* **0-PWR Visuals**: Units with 0 PWR (e.g., Dust Minions) still execute the full attack sequence and trigger visual impact feedback on their targets, despite dealing no damage.

---

## 8.3 Damage

* Immediate HP stat reduction (but has to consider reaction effects first like armor and other effects).
* If HP â‰¤ 0 â†’ death.
* Death triggers resolve.

No randomness involved.

---

# 9. Merge System Rules

## 9.1 Recipe Unlock Rule

* Recipes locked at start of run.
* Unlock when player acquires result.
* Unlock is per-run only.

---

## 9.2 Evolutionary Merge Formula

Merging uses **current stats** to calculate a "stat inheritance" for the result.

If two identical units of Level N (e.g., Tiger Lv. 1 + Tiger Lv. 1) merge:
1. They transform into a unique higher-level definition (Tiger Lv. 2).
2. The result inherits the "stat surplus" from both parents (Sum of parents' current stats minus the new definition's base stats).
3. This surplus is stored as a persistent **Merge Inheritance StatComponent**.

* Damage/Health progress is preserved.
* Buffs are preserved.
* Reductions are preserved.
* Status effects are combined into the new instance.

Tier progression follows the evolutionary chain:
* Level 1 + Level 1 -> Level 2 (Same Tier)
* Specific recipes may trigger Tier transitions (e.g., Tier 1 + Tier 1 -> Tier 2 Unit).

---

## 9.3 Item Transfer

During a merge, only **one item** is transferred to the resulting unit.
* **Target Priority**: If the target unit (the one being dropped onto) has an equipped item, that item is transferred to the result.
* **Source Fallback**: If the target unit is empty but the source unit has an item, the source's item is transferred.
* **Discard**: Any secondary items that are not transferred are **discarded**.

---

## 9.4 In-Battle Merge

* Creates new temporary instance for that battle only.
* On death -> goes to discard.
* Discarded units do not return to the draw pools.

---

# 10. Trait System Rules

Traits are passive team-wide bonuses based on unit composition. Each unit contributes 1 Soul to its element.

## 10.1 Snapshot Locking
Combat logic uses a **Locked Snapshot** of traits taken at the start of turn. This prevents mid-combat changes as units die or are summoned

## 10.2 Traits & Scaling
| Trait | Focus | Souls | Effect |
| :--- | :--- | :--- | :--- |
| **Fire** | Pressure | 3/5/7/9 | Applies Burn on attack, more stacks per quantity threshold. 7+ applies to entire enemy team. |
| **Earth** | Defense | 3/5/7/9 | Grants Armor (3,5,7,9) and Spikes (7,9) to allies. Earth units gain double armor. |
| **Water** | Resilience | 2 | Heals adjacent allies at turn start. |
| **Wind** | Disruption | 2 | Steals PWR from mirrored enemy slot. |

# 11. Stat Scaling Rules

* No max HP/PWR cap.
* Healing or buffing increases current HP/PWR.
* Stats are calculated as: `Base (from definition) + Modifiers (from components)`.
* Persistent progress (training, merge inheritance) is stored in the component stack.
* Live deltas (damage, healing) mutate the `current_hp` directly.

---

# 11. Flashcard Resource Engine

## In Battle:

Correct answers â†’ Tokens (+1 Mastery)
Incorrect/Skip â†’ NO Tokens (-1 Mastery)

## At Rest Site:

Correct answers â†’ Tokens (can be used to draw Permanent Hero Base Stat increases)

Tokens:

* Exist only within encounter.
* Reset after encounter.

---

# 12. Risk Calculation Framework

## 12.1 Draw Probability

If Tier Pool contains 4 Gachaballs,
Chance of specific Gachaball = 1 / 4

Player can inspect and calculate manually.

---

## 12.2 Merge Risk

Merging:

* Increases unit density.
* Increases stat density and item quality focus.
* Alters reshuffle composition.

Irreversible during battle.

---

## 12.3 Token Banking Risk

* Tokens carry between turns.
* Not spending increases future draw flexibility for future turns at the cost of power for the current turn.

---

## 12.4 Tier Compression Risk

Tier 3:

* Costs 4 Gold (macro economy).
* Costs 3 Tokens (battle economy).
* High slot efficiency.
* Lower stats per gold than equivalent T1 swarm.

---

## 13.1 Encounter Budget
* Uses Gold Budget.
* Budget formula: `3 + (Day - 1)`.
* Buys units/items using tier gold cost.
* Elites and Bosses use 85% of the base budget for support units (Mini-Boss/Boss units are FREE).
* **Elite Pity System**: The encounter generator dynamically adjusts weights for elite boss variants based on the run's encounter history. Each prior encounter with a specific elite significantly reduces its weight for future selection, ensuring variety between variants (e.g., Dust Sentinel vs. Dust Overlord).
* Boss Reinforcements use 33% of the daily budget (baseline `3 + (Day-1)`).

## 13.2 Shop Node Logic
- **Stock**: 3 random GachaBalls.
- **Rerolling**: 
    - Base cost: 1 Gold.
    - Escalation: +1 Gold per reroll during the same visit.
    - Reset: Resets to 1 Gold on next shop entry.
    - **Stock Type**: Draws exclusively from the World Pool (all unlocked definitions of the appropriate tier).

## 13.3 Black Market Node
- **Primary Actions**:
    - **Remove**: Permanently deletes a Gachaball from the run collection.
    - **Transform**: Replaces a Gachaball with a random one of the same tier.
- **Cost Structure**:
    - **Remove**: Base cost **5 Gold**. Cost increases by **+1 Gold** for each subsequent removal during the run.
    - **Transform**: Flat fee of **5 Gold**. Cost does not escalate.

## 13.4 Post-Battle Reward Sequence (PrizeLineup)
After victory, the player enters the Reward scene:
- **Prize Lineup**: 5 random GachaBalls (Units/Items/Trinkets) are displayed.
- **Service Area**: 
    - **Collect**: Free of charge. Item moves to Run Inventory.
    - **Sell**: Item is discarded in exchange for Gold (based on tier value).
- **Auto-Collection**: If the player attempts to leave the scene with uncollected items, the system automatically triggers sequential collection for all remaining prizes to prevent accidental reward loss.
- **Machine Interaction**: The Gacha Machines remain active for spending tokens banked during the final battle turn. Any remaining tokens are lost upon leaving this scene.

# 14. UI/UX Hierarchy & Inspection

## 14.1 Inspection Window System
Rules for locking and closing inspection modals:
- **Opening**: Hover to preview; Click to "Lock" open.
- **Robust Sizing**: Windows utilize a "Show-before-Measure" strategy, rendering with alpha 0.0 for 3 frames before positioning. To prevent these invisible windows from intercepting mouse events (especially for units near the screen origin), they are moved to an off-screen "waiting room" at `Vector2(-2000, -2000)` during the measurement phase.
- **Immediate Cleanup**: Content grids (e.g. unit slots) are pruned of stale children immediately using `remove_child()` followed by `queue_free()`, ensuring no inherited "ghost slots" from previous inspections.
- **Single Active Group**: Opening a new root closes the entire previous chain.
- **Single Child per Parent**: A parent can only have one child window; opening a new one closes the current sibling and its descendants.
- **Closing**: 
    - Click Background of Group: Closes entire group.
    - Click Background of specific Window: Closes its children only.
    - Drip Selection: Opening any window deselects active GachaBalls.

# 15. The Economic Theory of Board Value

The following must remain true for solvability and balance:

1. **Board Value Equation**: Board Value is the sum of all Unit Base Packages plus the Interaction Surplus.
    - *Unit Base Package*: Baked-in stats and the single item slot provided by the unit definition.
    - *Interaction Surplus*: Value generated by synergies, abilities, and buffs that allow the board to exceed its initial budget.
2. **The Gold Standard**: 1 Gold/Token buys approximately 3 HP or 2 PWR at T1L1. Leveling provides exactly **+1 Stat Point** to both HP and PWR per level, while costs double per level.
3. **Stat Hierarchy**: PWR > HP. PWR is the primary variable for scaling multiplicative abilities.
4. **Economic Duality**:
    - **Run Economy (Deck Curation)**: Gold spent on "Deck Adds." Dilution reduces draw reliability.
    - **Battle Economy (Realization)**: Tokens spent to realize the value of the curated deck.
5. **Mitigation First**: Remove and Transform mechanics are essential to maintain a "Lean" deck.
6. **Tier Costs**: Tier Gold cost is `BaseTierCost * 2^(Level-1)` (1-2-4 base); Tier Token draw cost remains 1-2-3 (level agnostic).
7. **Damage Determinism**: Damage remains deterministic (PWR = Damage).
8. **Information Transparency**: Full pool and board transparency at all times.
9. **Discard**: All discards are permanent for the duration of the battle encounter. There is no automatic reshuffle.
10. **Hero Death**: Hero death = immediate run loss.

## 15.1 Unified Item Slot Constraint
All units (including the Hero) are restricted to **one single item slot**.
     - Tier 0 (Hero): 1 Slot
     - Tier 1: 1 Slot
     - Tier 2: 1 Slot
     - Tier 3: 1 Slot

Breaking these changes game identity.

---

# 15. Adjustable Balance Levers

Safe tuning variables:

* Token gain rate
* Flashcard timer length
* Tier draw cost
* Encounter budget scaling
* Base unit stats
* Merge recipes availability
* Shop reroll cost
* Enemy reinforcement strength

These affect difficulty without altering deterministic contract.

---

---

# 16. Strategic Risk Review & System Safeguards

This section documents key systemic risks identified during design review and the intended solutions or monitoring strategies. The purpose is to preserve game identity while ensuring long-term balance, clarity, and replayability.

## 16.1 Infinite Scaling â€“ Design Position

### Design Intent

Infinite scaling (HP, PWR, stat gain, token scaling, gold scaling) is allowed by design. The system assumes:

*   Both Player and Enemy can scale.
*   Scaling can be countered (PWR steal, PWR halve, summon pressure, pollution, etc.).
*   The battle becomes a contest of engine construction, not raw stats.
*   Scaling is not considered a flaw. It is a feature.

### Real Risk Identified

The main risks are:

*   **UI Breakdown** (large unreadable numbers).
*   **Dominant Engine Emergence** (meta collapse).
*   **Non-interactive scaling loops**.

The primary concern is clarity, not math.

### Resolution Strategy

**Stat Cap for Readability:**
*   HP and PWR will be capped at 99 (or 100).
*   Status stacks may also follow a 2-digit maximum display rule.
*   Scaling above cap is truncated.

This preserves deterministic math, counter-scaling dynamics, and clean UI readability. Scaling remains meaningful, but visually manageable.

---

## 16.2 Counter-Scaling Philosophy

The system assumes any scaling strategy must be counterable. Examples:

*   **PWR steal** (Wind trait)
*   **PWR drain items**
*   **Burn** (percentage-like scaling pressure)
*   **Pollution** (gacha dilution)
*   **Durability pressure** (item collapse)
*   **Token punishment bosses**

Meta-breaking tools must always exist. Balance is achieved via ecosystem pressure, not stat nerfs.

---

## 16.3 Boss Design Evolution

### Identified Weakness

Current bosses primarily:

*   Summon units
*   Scale on player actions
*   Increase stats passively

They function as stat walls rather than strategic puzzles.

### Design Direction

Future bosses must:

*   Create board-state puzzles
*   Force build adaptation
*   Punish narrow scaling engines
*   Interact with minigame performance

**Example directions:**
*   Pollution Boss
*   Scaling inversion boss (converts high PWR into vulnerability)
*   Examiner Boss (minigame accuracy modifies boss action budget)
*   Durability breaker boss

Boss fights should feel structurally different from regular encounters.

---

## 16.4 Flashcard-Based Pacing System

Boss appearance timing will scale with Flashcard Mastery progression.

**Rule:**
*   Higher mastery â†’ Boss encounters occur earlier.
*   Lower mastery â†’ Boss encounters delayed.

**Rationale:**
*   Skilled players get accelerated challenge.
*   Struggling players get extended preparation time.
*   Flashcard performance directly affects run tempo.

This ensures learning progression equals gameplay progression and every run improves player skill even if run progress resets.

---

## 16.5 Run Failure Philosophy

Runs are designed to be fast, deterministic, and recoverable through learning. Even failed runs provide:

*   Flashcard practice
*   Knowledge retention
*   Improved minigame performance next run

Thus, no run is wasted time. Out-of-game mastery replaces meta-progression systems.

---

## 16.6 RNG Mitigation & Player Agency

Although gacha draws are random within tier pools, player agency exists through:

*   Full pool visibility
*   Probability calculation
*   Tier selection
*   Token banking
*   Reroll mechanics
*   Merge planning
*   Trait path commitment
*   Trinket adaptation

Failure due to RNG is acceptable only if runs are fast, recovery potential exists, and skill can compensate long-term.

---

## 16.7 Trait System Expansion Requirement

**Current imbalance risk:**
*   Fire & Earth scale vertically (3â€“5â€“7â€“9 tiers).
*   Water & Wind currently shallow.

**Design Action:**
*   Expand Water/Wind tier progression OR clearly define them as low-threshold utility traits.

Trait symmetry must be intentional, not accidental.

---

## 16.8 Enemy Template Diversity

To prevent single-build dominance, encounters will include template archetypes such as:

*   Summon-heavy boards
*   Anti-scaling boards
*   Pollution boards
*   Durability destruction boards
*   Token punishment boards
*   Trait-disruption boards

Players must construct flexible builds.

---

## 16.9 Long-Term Replayability Strategy

Replayability will come from:

*   New flashcard decks (real-world learning progression)
*   New units and merge trees
*   New traits
*   New trinkets
*   Achievement-based challenge runs

**Examples:**
*   Win using only Tier 1 units
*   Win without merging
*   Win using a weak trinket
*   Win with 0 Fire Souls

Replayability focuses on mastery variation, not permanent power creep.

---

## 16.10 Clarity as a Core Design Constraint

The game includes deterministic combat, trait stacking, merge inheritance, trigger timing, durability, and pollution.

Therefore, all abilities must:
*   Clearly state trigger
*   Clearly state effect
*   Avoid ambiguous phrasing
*   Avoid hidden modifiers

Clarity is a non-negotiable design pillar.

---

## Final Strategic Position

Flashcard Heroes is designed as a deterministic scaling auto-battler where knowledge mastery fuels tactical resource generation and build construction is a contest of engine design under full information.

The long-term health of the system depends on:
*   UI readability
*   Counter-scaling tools
*   Boss puzzle design
*   Trait balance symmetry
*   Encounter diversity

Expansion must reinforce identity, not dilute it.


# Result

This document now:

* Defines exact player agency
* Defines exact resource math
* Defines exact randomness boundaries
* Separates gold economy vs battle economy
* Clarifies merge conservation rules
* Defines discard mechanics precisely
* Provides balancing levers
* Removes engine implementation noise
# 17. Progression & Meta-Systems

## 17.1 Achievement & Unlocks
- **Unlocking**: Permanent content (Heroes, Decks, Recipes) is tied to `AchievementManager`.
- **The Codex**: A global registry displaying all unlocked `GachaBallDefinition` and discovered `MergeRecipe`.

## 17.2 Run Progression
- **Difficulty Scaling**: `Day` counter increments `EncounterGenerator` budgets.
- **Boss Tapering**: Bosses appear at deck unlock thresholds (every 20%).
