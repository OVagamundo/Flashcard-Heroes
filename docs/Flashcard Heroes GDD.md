# Flashcard Heroes - Game Design Document (GDD)

**Flashcard Heroes** is a single-player roguelike deckbuilder and auto-battler (inspired by *Super Auto Pets* and *Slay the Spire*) that integrates an *Anki*-style spaced repetition system (SRS) as its core resource generation engine. Players build and curate a collection of **GachaBalls** (Units and Items) to solve deterministic combat encounters, navigate path choices, and defeat bosses.

---

## 1. Core Philosophy & Design Pillars

1. **Design by Synthesis:**
   Every entity in the game (Units, Items, Trinkets) is a legible synthesis of clear attributes: Tier, level, and traits. Upgrades, leveling, and merges follow deterministic, transparent rules rather than arbitrary branching.
2. **Total Information Transparency:**
   The player is never kept in the dark. All active board states, enemy abilities, upcoming actions, machine draw probabilities, remaining pool contents, status effects, and discard piles are fully inspectable at all times. Combat is a tactical puzzle to be solved, not a gamble. The player does not have to make all the math in their head to play, but they could if needed, although it might be overwhelming once too many factors and chain reactions are present.
3. **Strict Determinism:**
   Combat outcomes are the exact mathematical consequence of team composition, stats, item synergies, positioning, and reaction priorities. There are some RNG aspects like random targeting and select random events that are not directly affected by or predictable to the player, but the RNG itself is seeded and deterministic.
4. **Decoupled Truth & Visual Clarity:**
   Underlying state mutations resolve atomically and deterministically. The presentation layer needs to clearly communicate every cause, reaction, and effect through distinct visual trajectories and feedback before the next interaction can begin.

---

## 2. Win & Loss Conditions

- **Winning a Run**: A run is successfully completed when the player defeats the **Final Boss**, without letting the Hero die.
- **Losing a Run (Permadeath)**: A run is lost immediately if the **Hero's health (HP) reaches zero**.
  - **Permadeath**: Upon victory or defeat, the run's save checkpoint is permanently cleared, enforcing true roguelike stakes.
  - **Hero Combatant Rules**: The Hero participates directly on the active battle board alongside standard units, behaving as an active combatant subject to damage, healing, buffs, and attacking.
  - **Board Restriction**: The Hero is bound to the active team lineup and cannot be benched or moved to inventory.
  - **Single Item Slot**: Like all other units, the Hero possesses strictly one item slot.

---

## 3. Core Gameplay Loop

The game progresses through discrete player decisions and turn phases without an unprompted real-time background loop:

1. **Loadout Selection**: Select a Hero, a Flashcard Deck, and deck order (Random, Regular, Inverted).
2. **Path Navigation & Encounter Selection**: Choose 1 of 3 encounter choices on the map (Battles, Shops, Surprise Events, etc.).
3. **Encounter Resolution**: Resolve the selected encounter using earned resources, tactical board positioning, inventory management, or encounter-specific choices.
4. **Day Progression**: Resolving an encounter advances the **Day** counter, which scales enemy team difficulty and unlocks higher-tier content.
5. **Conclusion**: Victory (Final Boss defeated) or Defeat (Hero HP = 0).

---

## 4. Player Resources

- **Hero and Unit Stats (HP, PWR)**: Persistent health and power for the entire run. Carries over between all encounters. Reaching 0 HP for the Hero ends the run immediately. There is no maximum HP or PWR in this game, only base stats (used across all encounters for the entire run) and current stats (modified dynamically during battle and reset at encounter conclusion).
- **Gold**: Persistent run currency. Earned by winning battles, selling reward capsules, and through select abilities and encounter choices. Spent outside of combat for shop purchases, removal of unwanted GachaBalls, transformations, training sessions, and encounter-specific uses or ability scaling.
- **Gacha Tokens**: Transient encounter currency. Earned primarily through the Flashcard minigame (and select abilities). Spent during encounters to draw units and items from tiered Gacha Machines or for other encounter-specific uses. Does not carry over between encounters.

---

## 5. Flashcard Resource Engine (Spaced Repetition System)

The Spaced Repetition System (SRS) serves as the game's active resource generation engine, bridging study mechanics with roguelike strategy.

### 5.1 The Minigame
At the beginning of each turn (in battles) or upon entering non-combat study sites, players engage in a fast-paced, timed multiple-choice session:
- **Starting Deck**: Runs begin with 5 active starter cards. New cards are introduced over the course of the run, preceded by an informational review window.
- **SRS Weighting Algorithm**: Questions are selected dynamically based on card mastery and time elapsed since last review. Cards with lower mastery appear more frequently, while mastered cards appear less often. The same card never appears twice in a row.
- **Scoring & Resource Generation**:
  - **Correct Answer**: Awards 1 Token, increases card mastery, grants a +0.5s timer extension, and builds the correct-answer streak.
  - **Incorrect Answer**: Awards no tokens, decreases card mastery by 1, and resets the streak.
  - **Skip**: Awards no tokens, decreases card mastery by 1, grants a +0.5s timer extension, but preserves the active streak without penalty.

### 5.2 Mid-Minigame Card Unlock (3-Streak Progression)
To reward knowledgeable players and maintain engaging pacing, answering 3 questions correctly in succession triggers an immediate mid-minigame card unlock with bonus time, accelerating deck progression for players who have already mastered early study material.

### 5.3 Design Rationale: Pacing, Economics & Natural Difficulty Balancing
This mechanic addresses three core design imperatives:
1. **Pacing & Run Duration for Mastered Players**: Players who already know the deck material in prior runs should not be forced into a slow, beginner pace. A 3-streak unlock allows proficient players to advance through familiar cards twice as fast, reaching unfamiliar material in half the run time.
2. **Systemic Difficulty Economics & Snowball Mitigation**: Enemy encounter budgets scale linearly by Day, while players with high flashcard accuracy earn maximum tokens every turn. Accelerating card introductions exposes knowledgeable players to unfamiliar cards earlier, curbing runaway token generation before their lineup outpaces the difficulty curve.
3. **Natural Dynamic Difficulty Balancing (Organic Risk/Reward)**: Novice players learn at a comfortable, gradual pace with rare 3-streaks. Proficient players naturally encounter tougher cards faster. Deliberately dodging new cards would require intentionally missing or skipping questions, directly sacrificing Gacha Tokens and increasing combat tension organically.

---

## 6. GachaBalls & Collection Architecture

**GachaBalls** are the collectible entities (Units and Items) that comprise the player's lineup, bench, and inventory.

### 6.1 Entity Types
- **Units**: Combatants defined by **Health (HP)** and **Power (PWR)** stats, along with unique passive or reactive abilities. Units act front-to-back in combat.
  - **Item Slot**: Every unit (including the Hero) is restricted to strictly **one item slot**, enforcing critical strategic trade-offs.
  - **Evolutionary Levels**: Units possess Levels (1 to 3). Leveling increases base stats (+1 HP and +1 PWR per level) and enhances ability potency.
- **Items**: Equipment or consumables that provide stat buffs or abilities:
  - **Equipment**: Equippable from the bench onto a unit. Remains attached across battles until replaced or stripped.
  - **Consumables**: Single-use items (potions, scrolls) activated from the bench. Consumable stat buffs stack additively and are conserved across unit merges.
  - **Trinkets**: Unique artifacts that confer powerful, game-altering effects. Trinkets persist across all encounters within a run. They serve as strategic tools that define unique builds and synergies.

### 6.2 Inventories & Lifecycle
- **Run Inventory**: The player's persistent collection (deck) for the run, categorized into Tier 1, Tier 2, and Tier 3 containers (capacity of 39 slots per tier).
- **Battle Inventory & Machines**: At battle start, the player's Run Inventory forms the initial contents of the three tiered Gacha Machines. As units are drawn, merged, or summoned, the Battle Inventory shifts dynamically without altering the persistent Run Inventory.
- **The Discard Pile**: Defeated units, discarded items, and bench overflow are placed permanently into the Battle Discard Pile for the remainder of the battle.

---

## 7. Game Economic Theories & The Core Dual Economy

The game operates on a dual-economy system that cleanly separates long-term deck curation from in-battle tactical execution.

### 7.1 Run Economy (Gold) vs. Battle Economy (Tokens)

| Tier | Gold Cost (Shop Curation) | Token Cost (Battle Draw) | Role & Power Scale |
| :--- | :--- | :--- | :--- |
| **Tier 1** | 1 Gold * 2^(Level - 1) | 1 Token | Foundational units, swarming, cheap execution. |
| **Tier 2** | 2 Gold * 2^(Level - 1) | 2 Tokens | Hybrid synergies, concentrated slot value. |
| **Tier 3** | 4 Gold * 2^(Level - 1) | 3 Tokens | Capstone powers, multiplicative battle-turning abilities. |

#### **Unit Leveling & Shop Value Scaling**
Leveling up a unit requires merging duplicate copies (2 Level 1 units form a Level 2 unit; 2 Level 2 units form a Level 3 unit). This doubles the Gold valuation per level:
- **Tier 1**: 1 Gold (Lv. 1) -> 2 Gold (Lv. 2) -> 4 Gold (Lv. 3).
- **Tier 2**: 2 Gold (Lv. 1) -> 4 Gold (Lv. 2) -> 8 Gold (Lv. 3).
- **Tier 3**: 4 Gold (Lv. 1) -> 8 Gold (Lv. 2) -> 16 Gold (Lv. 3).

#### **Deployment Efficiency via Gold**
This exponential Gold curve establishes the core deck-curation dynamic:
- **Low Draw Cost, High Power**: A Level 3 Tier 1 unit requires 4 Gold of run investment, but in battle its draw cost remains strictly **1 Token**.
- **Run Merges vs. In-Battle Merges**: Permanent merges outside combat cost Gold and provide true **Deployment Efficiency**. In-battle merges are dynamically useful to respond to threats, but offer no token efficiency (spending 2 tokens to draw two Level 1 units offsets the cost benefit of drawing a pre-leveled unit).

### 7.2 Deck Curation vs. Dilution & Power Creep
In *Flashcard Heroes*, strength is governed by the **Density of Synergy** rather than raw volume:
- **Dilution Penalty**: Adding non-synergistic units to the collection dilutes the Gacha Machine pools, making key synergy pieces harder to draw when needed.
- **Lean Deck vs. Deck Exhaustion**:
  - Keeping a deck ultra-lean maximizes draw predictability.
  - However, because defeated units and replaced items are committed permanently to the Discard Pile for the remainder of the encounter, an excessively lean deck risks complete pool exhaustion in protracted Elite or Boss battles.
  - Players must balance tactical draw predictability against the raw endurance needed to outlast multi-turn boss encounters.

### 7.3 Combinatorial Pool Economics & Hero Content Packs
Unrestricted roster expansion in merge-based deckbuilders leads to catastrophic pool bloat:
- **The Combinatorial Explosion Problem**:
  - With 4 base Tier-1 units, there are 4 choose 2 = 6 Tier-2 crossbreeds, and 6 choose 2 = 15 Tier-3 units, yielding an ideal base pool of **25 units**.
  - Unrestrictedly adding just 1 new Tier-1 unit increases Tier-2 to 10 units and Tier-3 to 45 units (60 total units). This pool explosion completely destroys shop roll consistency, making duplicate merges and leveling mathematically unviable.
- **The 11-Unit Hero Content Pack Model**:
  - To provide deep asymmetric replayability without pool bloat, each playable Hero introduces a dedicated, closed-loop 11-unit lineage pack:
    - **1 Hero Starter Unit (H1)** (Tier 1).
    - **4 Hero Crossbreeds (H2_a through H2_d)** (Tier 2): Formed exclusively by merging H1 with each of the 4 neutral base Tier-1 units.
    - **6 Hero Capstones (H3_1 through H3_6)** (Tier 3): Formed exclusively by merging pairs of Hero Tier-2 units (4 choose 2 = 6).
  - Hero Tier-2 units do not cross-merge with neutral Tier-2 units, completely walling off combinatorial explosion.
  - Similarly, each Hero introduces a unique Tier 1 item that can be merged with the 2 base Tier 1 items to form 2 possible Tier 2 items, which can in turn be merged to form a capstone Tier 3 item.
  - Select unique consumables and trinkets may also be introduced as part of the Hero pack, including a trait trinket unique to that Hero and their units.
- **The 36-Unit Active Working Pool**:
  - Every run features an active roster of:
    `Total Working Pool = 25 (Neutral Base) + 11 (Selected Hero Pack) = 36 Active Units`
  - This guarantees that shop roll probabilities, upgrade frequencies, and duplicate leveling remain perfectly balanced regardless of how many Heroes exist in the game.
- **Standalone Wildcards**:
  - Standalone units have no merge recipes and cannot be crafted from lower tiers; they appear directly in shops or elite rewards. They possess standard traits and can be leveled via duplicate self-merging, allowing trait deficit patching without cascading recipe requirements.

---

## 8. Merge System

Merging allows players to evolve units, adapt to enemy lineups, and preserve stat investments.

### 8.1 Merge Types
- **Merge to Level Up (Evolutionary)**:
  - **Requirement**: Two identical units of matching level (below Level 3).
  - **Outcome**: The unit elevates to the next level (e.g., Lv. 1 Tiger + Lv. 1 Tiger -> Lv. 2 Tiger). It retains its Tier, traits, and battle token draw cost, while gaining improved stats (+1 HP / +1 PWR) and upgraded ability scaling or features.
- **Merge to Tier Up (Recipe-Based)**:
  - **Requirement**: Two different constituent units of any level combined according to an unlocked recipe.
  - **Outcome**: Creates a completely new, higher-tier unit definition with a new ability, higher tier, different set of traits, and increased draw cost. The new unit always starts at Level 1, but inherits surplus stats from its parent units.

### 8.2 Stat Surplus Inheritance
Merged units conserve stat bonuses from their constituents:
- **Tier Evolution**: Parents' stats are summed together.
- **Leveling**: The unit retains its base stats, gains a flat +1 HP and +1 PWR per level, and inherits all accumulated extra stats (training, buffs, parent inheritance).

---

## 9. Combat System: The Tactical Puzzle

Battles are deterministic contests resolved in three distinct phases:

1. **Phase 1: Performance (Flashcard Minigame)**:
   Speed and accuracy determine the turn's Gacha Token budget.
2. **Phase 2: Management (The Tactical Puzzle)**:
   - **Spending Tokens**: Draw units and items from Tier 1, 2, or 3 machines.
   - **Formation & Order**: Units are deployed on the active lineup (up to 5 slots) and act **Front-to-Back**.
   - **Counter-Play**: Inspect enemy lineup positions, upcoming attacks, and equipment to optimize counter-formations, merges, item assignments, and consumable usage.
3. **Phase 3: Execution (Deterministic Combat)**:
   All attacks, abilities, status decays, and reactions resolve sequentially without player intervention. Success depends entirely on the player's preparation during the Management Phase.

---

## 10. Run Structure & Encounters

### 10.1 Encounter Node Types
- **Battles**: Common, Elite, and Boss fights. Elite and Boss victories award permanent Trinkets and greater Gold rewards.
- **Shops**: Spend Gold to buy units/items, reroll inventory, or purchase upgrades.
- **Black Market**: Specialized vendor offering unit purges (deck thinning) and transformations.
- **Unit Merge Encounter**: Special encounter that allows players to merge units and items outside of combat.
- **Unit Training Grounds (Dojo)**: Targeted stat training minigames to permanently increase individual unit stats.
- **Surprise Events & Gambling Dens**: Risk/reward encounters offering Gold or stat boosts for the Hero and other special interactions.

### 10.2 Boss & Elite Scheduling
- **Boss Scheduling**: Boss encounters are paced by **Flashcard Deck Mastery Milestones** rather than rigid day counts. In a Full Deck, a Boss is triggered every 20% of the deck introduced (up to 5 Bosses); in a Half Deck, every 33.3% (up to 3 Bosses).
- **Elite Scheduling**: Elite encounters are paced by progress toward the upcoming Boss, guaranteed at intermediate card mastery thresholds (20%, 40%, 60%, 80%) with a quota limit of 4 elite battles per boss tier.

---

## 11. Status Effects, Traits & Meta-Progression

### 11.1 Status Effects
- **Burn**: Deals damage at turn end equal to active stacks, then stacks decay by half per turn. Damages directly through Armor.
- **Armor**: Absorbs incoming damage point-for-point before Health is lost. Decays at turn end.
- **Spikes**: Deals direct retaliatory damage back to attackers upon taking attack damage equal to active stacks. Decays by 1 stack per activation and is mitigated by Armor.
- **Static**: Deals collateral damage to adjacent units upon the holder's death equal to active stacks. Decays by 1 stack per turn and is mitigated by Armor.

### 11.2 Traits & Elemental Affiliations
Units contribute elemental souls to team-wide traits based on their elemental tags:
- **Fire**: Offensive pressure (Burn application).
- **Earth**: Defense and sustain (Armor and Spikes generation).
- **Water**: Resilience and team sustain (healing).
- **Wind**: Disruption and control (Power theft and tempo advantage).

### 11.3 Meta-Progression & Persistence
- **Achievements & Unlocks**: Completing in-run milestones permanently unlocks new Heroes, Decks, GachaBalls, and Recipes for future runs.
- **The Codex**: An in-game encyclopedia cataloging all discovered units, items, and merge recipes across all runs.
- **Run Checkpointing**: Run state is saved at the start of each Day. In the event of victory or defeat, the save checkpoint is deleted to preserve roguelike tension.

---

*For detailed player-facing rules and behavioral contracts, see [Game Rules & Expected Behaviors.md](Game%20Rules%20&%20Expected%20Behaviors.md). For engineering architecture and class contracts, see [Flashcard Heroes TDD.md](Flashcard%20Heroes%20TDD%20(Technichal%20Design%20Document)%20V9.0.md).*