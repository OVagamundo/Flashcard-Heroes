# Flashcard Heroes - Game Design Document
**Flashcard Heroes** is a single-player roguelike deckbuilder, auto-battler (inspired by *Super Auto Pets* and *Slay the Spire*) that integrates an *Anki*-style spaced repetition system as resource generation mechanic. Players build a collection of **GachaBalls** (Units and Items) to survive encounters and defeat bosses.

2. Core Gameplay Loop
1. **Loadout**: Select a Hero, a Flashcard Deck, and the Deck Size ("Full" for a complete run or "Quick/Half" for a shorter, faster run).
2. **Encounter Selection**: Choose 1 of 3 encounter choices (Battles, Shop, and others).
3. **Resolution**: Resolve the encounter and advance the **Day** (Difficulty scaling).
4. **Conclusion**: Victory (Final Boss defeated) or Permadeath (Hero HP = 0).

3. Player Resources
- **Hero Health (HP)**: Persistent unit health for the run. 0 HP = Defeat. No Max HP cap.
- **Gold**: Persistent currency for Shop nodes. Lost at end of run.
- **Gacha Tokens**: Temporary encounter currency earned via Flashcards. Resets to zero after encounter.

4. Flashcard System (SRS)
Timed mini-game that generates **Gacha Tokens** for use in the current encounter.
- **The Deck**: Starts with 6 unlocked active cards; new cards are introduced over time with an info screen before each mini-game.
- **The Mini-Game**: A timed session of multiple-choice questions. Correct answers increase card "Mastery" and earn tokens. Incorrect answers decrease mastery.
- **Spaced Repetition**: An *Anki*-style weighted algorithm ensures cards with lower Mastery and more time since last used appear more frequently. The same card will not appear twice in a row and there's a small random factor to keep it from being too predictable.

5. GachaBall System
**GachaBalls** are the core collectible tokens (Units and Items) that form your collection, functioning similarly to cards in a deckbuilding game.
- **Units**: Characters with HP (Health) and PWR (Power) stats, along with unique passive or active abilities. HP and PWR scale upwards through leveling, equipment, or training.
- **Items**: Equipment or consumables that provide stat bonuses or unique abilities when placed on a unit. Consumables are single-use per encounter, while standard equipment persists across battles.
- **Attributes**: Every GachaBall is defined by its Tier (1-3), Level, and Rarity (Normal, Prismatic, etc.). Synergy Tags (Fire, Water, Earth, Air, etc.) represent elemental affiliations that contribute to powerful team-wide traits.
    - **Item Slots**: All units (including the Hero) are restricted to a single item slot, emphasizing critical choice.
    - **Evolutionary Levels**: Leveling up a unit elevates it to a more powerful tier or evolutionary state (e.g., Lv. 1 Tiger evolves into Lv. 2 Tiger), modifying its base stats and abilities while maintaining token cost (but gold cost still increases).

6. Inventories & Drawing 
- **Run Inventory**: Your persistent collection (deck) for the run.
    - **Capacity**: 39 slots per tier.
    - **Random Eviction**: Acquiring a ball when a tier is full (39 items) permanently deletes a random ball of that tier.
- **Battle Inventory & Machines**:
    - Each battle starts with your Run Inventory as the initial draw pool. After that, units can be merged, removed, summoned, buffed, etc. So the Battle Inventory can and will become very different from the Run Inventory during the battle but these changes do not affect the Run Inventory and are not saved or carry over between encounters
    - **Gacha Machines**: Spend tokens to draw balls from Tier 1, 2, or 3.
    - **Discard**: Defeated units and overflow go to Discard Pile where they remain permanently for the rest of the battle. (Some effects can retrieve items/units from the discard pile or use the number of balls in the discard pile as for effects and abilities)

### 6.2 Economy & The Core Duality
The game operates on a dual-economy system that defines encounter difficulty and player progression. It is critical to distinguish between the **Run Economy** (Curating and improving your Run Inventory (deck)) and the **Battle Economy** (Realizing Value).

| Tier | Gold Cost (Shop) | Draw Cost (Tokens) | Note |
| :--- | :--- | :--- | :--- |
| **Tier 1** | 1 Gold × 2^(L-1) | 1 Token | Basic units/items. |
| **Tier 2** | 2 Gold × 2^(L-1) | 2 Tokens | Advanced synergies. |
| **Tier 3** | 4 Gold × 2^(L-1) | 3 Tokens | Elite/Boss power levels. |

#### **Unit Leveling & Shop Value Scaling**
Units have both **Tiers** (1 to 3) and **Levels** (1 to 3). Leveling up a unit requires merging duplicate copies (2 of the same unit at Level 1 to make a Level 2 unit, and 2 at Level 2 to make a Level 3 unit). This merging requirement directly impacts their Shop value/Gold cost, following the formula `BaseTierCost × 2^(L-1)`:
- **Tier 1**: Costs **1 Gold** at Lv. 1, **2 Gold** at Lv. 2, and **4 Gold** at Lv. 3 (Maximum Level).
- **Tier 2**: Costs **2 Gold** at Lv. 1, **4 Gold** at Lv. 2, and **8 Gold** at Lv. 3.
- **Tier 3**: Costs **4 Gold** at Lv. 1, **8 Gold** at Lv. 2, and **16 Gold** at Lv. 3.

#### **Strategic Duality & Deployment Efficiency**
This exponential Gold cost is a cornerstone of the game's economy and deck curation strategy:
- **Low Draw Cost, High Power**: A Level 3 Tier 1 unit represents a substantial **4 Gold** run investment (equivalent to a Level 1 Tier 3 unit), but when drawn in battle, its Gacha Machine token cost remains only **1 Token**.
- **Stat and Ability Scaling**: Each level brings a slight base stat buff (approximately **+1 HP and +1 PWR** per level gained) and, more importantly, significantly improved, higher-impact versions of their unique abilities.
- **Deployment Efficiency via Gold**: Permanent modifications performed outside of battle—including permanent merges, level-ups, and stat buffs—all cost **Gold**. This Gold investment is what yields true **Deployment Efficiency**, allowing a player to permanently upgrade units in their Run Inventory so they can later be drawn during battle for low token costs.
- **In-Battle Merges vs. Run Merges**: Merging and leveling up units *during* a battle on the bench/board only costs the **Tokens** required to draw the constituent parent units from Gacha Machines. While dynamically useful to increase lineup strength, in-battle merges do NOT grant deployment efficiency. For example, to level up a Tier 1 unit to Level 2 in battle, a player must spend 2 Tokens to draw the two Level 1 units needed, completely offsetting the token cost advantage of drawing a single pre-leveled unit from the deck.

- **Run Economy (Gold)**: Used in the game to modify your Run inventory (decks) like buying gachaballs, removing them, transforming, upgrading, buffing and merging them.
    - **Efficiency Penalty & Dilution**: Every non-synergistic unit added to the deck serves as a "dilution" of the draw pool, making it mathematically harder to draw specific "Engine" or "Anchor" pieces during battle.
    - **Mitigation Systems**: Shop and Event nodes provide **Remove** and **Transform** mechanics as the primary tools for maintaining a "Lean" deck and maximizing the Average Value per Token spent.
- **Battle Economy (Tokens)**: Earned via Flashcards. Used only during battle to "Realize" the value of your Run Inventory by drawing from Gacha Machines.

### 6.3 Deck Curation vs. Power Creep
In Flashcard Heroes, power is not just about having more units, but about the **Density of Synergy**. A smaller, high-synergy deck is often more powerful than a large deck of high-stat units due to the predictable nature of the draw pool. Players must constantly weigh the benefit of a new addition against the dilution of their core strategy.

#### **The Strategic Trade-Off: Predictability vs. Deck Exhaustion**
With the integration of **permanent in-battle discards**, deck curation becomes a high-stakes balancing act:
- **The Case for a Lean Deck**: Keeping your deck small significantly increases the predictability of your draws. You can reliably pull key synergy tags and core engines with fewer Gacha Token spins.
- **The Threat of Exhaustion**: Since defeated units and overflow balls are placed in the Discard Pile *permanently* for the remainder of the battle, an ultra-lean deck carries a severe survival risk. In prolonged, multi-turn engagements (such as intense Elite or Boss battles), a player can fully deplete their draw pool. 
- **The Survival Threshold**: Running out of GachaBalls in the draw pool leaves the player unable to field new units, leading to rapid defeat. Consequently, players cannot simply reduce their deck to a micro-size; they must maintain a "survival threshold" of total units to last through prolonged battles, balancing perfect synergy predictability against raw endurance.

7. Battle System
7. Battle System: The Tactical Puzzle
Battles are deterministic contests where the outcome is decided during the **Management Phase**. Each turn functions as a tactical puzzle where you must counter the enemy's formation using limited resources.

- **Phase 1: Performance (Flashcards)**: Your accuracy and speed in the mini-game determine your **Gacha Token** budget for the turn.
- **Phase 2: Management (The Puzzle)**:
    - **Resource Spending**: Decide how to spend tokens across the three Tiered Gacha Machines (Tier 1/2/3), each having its own cost and unique pool of units/items.
    - **Formation & Order**: Units act **Front-to-Back**. Since combat is deterministic (no crits/misses), the specific order of units and item placement is the deciding factor between victory and defeat.
    - **Counter-Play**: Analyze the enemy's stats, upcoming actions and reactions based on their abilities and equipment, trinkets, stat effects, etc to optimize your lineup placement, bench, and item usage.
- **Phase 3: Execution (Combat)**: All actions resolve automatically and sequentially. Success depends entirely on your preparation in the Management Phase with the availble drawn "hand" and board state.

8. Merge System
Combining GachaBalls is a core tool to increase adaptability to the enemy's formation, preserve stat improvements, and evolve units into more powerful definitions.

### 8.1 Merge Types & Progression Rules
We distinguish between two distinct merging pathways:
- **Merge to Level Up (Evolutionary)**:
  - **Requirement**: Uses **identical** units (e.g., Tiger Lv. 1 + Tiger Lv. 1 $\rightarrow$ Tiger Lv. 2).
  - **Outcome**: Elevates the unit to a higher level of the same base definition. The unit retains its original Tier, tag synergies, and battle draw cost, but receives improved ability scaling and stats.
- **Merge to Tier Up (Recipe-Based)**:
  - **Requirement**: Uses **different** specific units according to active recipes (e.g., Unit A + Unit B $\rightarrow$ Unit C).
  - **Outcome**: Creates a completely new, higher-tier unit definition. This unit has a **completely different ability**, a higher tier, and consequently a higher token draw cost in battle.
  - **Level Resets but Stats Inherit**: When merging different units to tier up, if the parent units have levels, their stats are still fully added together (preserving the stat surplus inheritance). However, the **new higher-tier unit always starts at Level 1**; the levels of the parent units do not carry over.

### 8.2 In-Battle vs. Permanent Merges
- **Permanent Merges (Run Economy - Gold)**:
  - Performed in the Run Inventory outside of battle.
  - **Resource Cost**: Merging, leveling up, and applying permanent stat buffs outside battle all cost **Gold**.
  - **Strategic Value**: This is the source of **Deployment Efficiency**. Permanently leveling up a Tier 1 unit to Lv. 3 in the run deck means it can be drawn during battle for only 1 Token while enjoying Lv. 3 stats and abilities.
- **In-Battle Merges (Battle Economy - Tokens)**:
  - Performed on the bench or lineup during the Management Phase.
  - **Resource Cost**: Merging/leveling up in battle is free to execute but requires the **Tokens** used to draw the parent units from the Gacha Machines to the board first.
  - **No Deployment Efficiency**: While in-battle leveling is strategically useful to strengthen the lineup dynamically, it does not provide deployment token efficiency. To get a Lv. 2 Tier 1 unit on the board in-battle, the player must spend 2 Tokens to draw the two Lv. 1 Tier 1 units required, offsetting the cost benefits of drawing a pre-leveled unit.

### 8.3 Recipe Discovery
- **Recipes**: Valid combinations are defined by recipes. Recipes are **locked** until the resulting higher-tier unit is first acquired in the run.

### 8.4 Stat Inheritance
- **Stat Inheritance**: Result units inherit a "stat surplus" from their parents via a persistent **Merge Inheritance Component**:
  - **Tier Evolution**: Parents' stats are added together.
  - **Leveling**: Unit keeps its original base stats plus a flat **+1 Stat Point per level gained**, and sums only the "Extra Stats" (inheritance/buffs) from parents.

9. Core Entities & Systems
- **Hero Unit**: Your central character. HP = Run Health. restricted to the PlayerLineup.
- **Trinkets**: Non-GachaBall items providing run-wide passive bonuses.
- **Encounters**: Choices that define your run's journey and difficulty scaling, including:
    - **Battles**: Common, Elite, and Boss encounters. Elite and Boss victories award permanent Trinkets and greater Gold rewards.
    - **Shops**: Standard **Shop** (buy, reroll, or remove/transform GachaBalls) and the **Black Market** (specialized vendor with exotic or rare inventory).
    - **Standalone Encounters**: Dedicated sites for permanent improvements: **Merge Encounter** (advanced gachaball combining bypassing recipes) and **Unit Training Ground** (stat-boosting projectile training minigame).
    - **Surprise Events**: Randomly selected mini-encounters including the **Rest Site** (Hero HP boosts), **Gambling Den** (Gold boosts), and **Training Grounds** (Hero PWR boosts).
- **Ability System**: Event-driven (triggers like `ON_ATTACK`, `ON_DEATH`). Every unit an items has an ability or more besides sometimes passive stats.
- **Status Effects**: Temporary effects that stack and typically decay at turn end, per activation, etc.

| Effect | Description |
| :--- | :--- |
| **Burn** | Damage at turn end equal to stacks. |
| **Armor** | Blocks incoming damage. |
| **Spikes** | Deals damage back to attackers. |
| **Static** | Consumed stack-by-stack when the holder suffers any stat change. Deals 1 armor-ignoring damage per consumed stack. |
- **Traits**: Persistent team-wide bonuses based on the active units and emblems in your lineup. Each unit contributes 1 **Soul** to a specific element (Fire, Earth, Water, Wind).
    - **Fire**: Offensive pressure (Burn application).
    - **Earth**: Defense and sustain (Armor and Spikes).
    - **Water**: Resilience (Adjacent healing).
    - **Wind**: Disruption (PWR theft).

10. Progression & Meta-Systems
- **Difficulty Scaling**: Enemy teams grow stronger each **Day** via the Encounter Budget System (scaling Gold budget for more/better units/items/trinkets and even starting stats).
- **Achievements & Unlocks**: Completing in-game milestones permanently unlocks new Heroes, Decks, GachaBalls, and Recipes for future runs.
- **The Codex**: An in-game encyclopedia of discovered units, items, and merge recipes.

11. UI/UX Principles
- **Cross-Platform Interaction**: Optimized for Mouse (Drag-and-Drop, Click-to-Select) and Touch (Tap, Long-press Peek).
- **Intent Priority**: All interactions are resolved in the order: **Merge > Equip > Use > Swap**.
- **Transparency**: Board states, enemy stats, and all Gacha machine pools (the "Drawer") are fully visible for tactical planning.
- **Inspection System**: Hierarchical window system; clicking "locks" a hover/peek window open for detailed analysis.

*Detailed interaction priorities and window hierarchy logic are preserved in the [Mechanical Specification](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/MechanicalSpecification.md).*