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
* The Hero’s HP is above 0.

## A Run Is Lost When:

* The Hero’s HP reaches 0.

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
* If HP reaches 0 → run ends.

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
1. **Merge**: Valid `MergeRecipe` exists → Opens Choice Window (Merge/Swap).
2. **Equip**: Item dropped on Unit with empty slot → Equips.
3. **Use**: Consumable dropped on Unit → Instant effect.
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
   * Drag item from **Bench** to unit with available slot.
   * Drag consumable item to use on units.

6. **Manage Equipped Items (same unit only)**
   * Move within unit slots.
   * Swap within same unit.
   * Merge items if recipe is unlocked.

7. **Merge Units**
   * On bench or board.
   * Requires unlocked recipe.
   * Creates new instance for current battle.

8. **End Turn**

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
- **Draw removal**: When a gachaball is drawn, it is physically removed from the drawer.
- **Reshuffle Spawning**: When a pool reshuffles, new balls spawn sequentially at the top-center of the container.

## 6.4 The Overflow Penalty
- **Mechanic**: If a container becomes physically overfilled, balls will push against the **Spring Lid**.
- **Penalty**: Maintaining physical contact with the lid for **5 continuous seconds** results in the instance being **moved to the Shared Discard Pile** and its stats reset.

## 6.5 Hover Restriction (Rule S8)
When a physics-based inventory (Battle/Run/Discard) is open, hover inspections are strictly limited to the gachaballs inside that window. This prevents accidental window closure caused by hovering over the background battle board.

## 6.5 Reshuffle Rule

Reshuffle occurs only:

* During Management Phase.
* Only when a specific Tier pool becomes empty.
* Only cards of that Tier are moved from the shared Discard Pile back into that Tier pool.
* Other Tier pools remain unchanged.

When a unit is reshuffled into a Tier pool, its stats are restored to its base values.

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

All stat changes are persistent until modified again. There is no max stats, only base stats and current stats.

---

# 8. Combat Resolution Contract

## 8.1 Action Order

1. Entire Player Team acts first.

2. Units act front-to-back.

   * Enemy: mirrored but also front-to-back

3. After Player completes all action chains,
   Enemy initiates their action chains front-to-back.

Each action chain may cause reactions from own team and/or opposing team before proceeding.

---

## 8.2 Default Attack

* Deals damage equal to current PWR.
* Targets frontmost enemy.
* If empty, nearest forward unit.

---

## 8.3 Damage

* Immediate HP stat reduction (but has to consider reaction effects first like armor and other effects).
* If HP ≤ 0 → death.
* Death triggers resolve.

No randomness involved.

---

# 9. Merge System Rules

## 9.1 Recipe Unlock Rule

* Recipes locked at start of run.
* Unlock when player acquires result.
* Unlock is per-run only.

---

## 9.2 Merge Formula

Merging uses **current stats**, not base stats.

If A and B merge:

HP_result = HP_A + HP_B
PWR_result = PWR_A + PWR_B

* Damage is preserved.
* Buffs are preserved.
* Reductions are preserved.
* Status effects are combined.
* Equipped items are preserved.

  * If both have same status (e.g., Burn), stacks are added.

No multiplier exists beyond additive conservation.

Tier progression:

* Tier 1 + Tier 1 → Tier 2
* Tier 2 + Tier 2 → Tier 3

---

## 9.3 Item Transfer

All equipped items transfer to result.

---

## 9.4 In-Battle Merge

* Creates new temporary instance for that battle only.
* On death → goes to discard.
* That merged version is what reshuffles.

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
* HP can scale infinitely.
* PWR can scale infinitely.
* No stat decay unless modified.

---

# 11. Flashcard Resource Engine

## In Battle:

Correct answers → Tokens (+1 Mastery)
Incorrect/Skip → NO Tokens (-1 Mastery)

## At Rest Site:

Correct answers → Tokens (can be used to draw Permanent Hero Base Stat increases)

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

* Reduces unit count.
* Increases slot efficiency.
* Increases stat density and item slot density.
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
* Boss Reinforcements use 33% of the daily budget (baseline `3 + (Day-1)`).

## 13.2 Shop Node Logic
- **Stock**: 3 random GachaBalls.
- **Rerolling**: 
    - Base cost: 1 Gold.
    - Escalation: +1 Gold per reroll during the same visit.
    - Reset: Resets to 1 Gold on next shop entry.

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

# 15. Design Guardrails

The following must remain true for solvability:

1. Damage remains deterministic. (although crit and dogde mechanics could be added later)
2. Full information transparency during battle, perfect information gameplay.
3. Additive merge inheritance.
4. No hidden stat multipliers.
5. Tier Gold cost remains 1-2-4.
6. Tier Token draw cost remains 1-2-3.
7. Reshuffle only when tier pool empties.
8. Hero death = immediate run loss.

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

## 16.1 Infinite Scaling – Design Position

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
*   Higher mastery → Boss encounters occur earlier.
*   Lower mastery → Boss encounters delayed.

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
*   Fire & Earth scale vertically (3–5–7–9 tiers).
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
* Defines reshuffle mechanics precisely
* Provides balancing levers
* Removes engine implementation noise
# 17. Progression & Meta-Systems

## 17.1 Achievement & Unlocks
- **Unlocking**: Permanent content (Heroes, Decks, Recipes) is tied to `AchievementManager`.
- **The Codex**: A global registry displaying all unlocked `GachaBallDefinition` and discovered `MergeRecipe`.

## 17.2 Run Progression
- **Difficulty Scaling**: `Day` counter increments `EncounterGenerator` budgets.
- **Boss Tapering**: Bosses appear at deck unlock thresholds (every 20%).
