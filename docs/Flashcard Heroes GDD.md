Flashcard Heroes - Game Design Document (V5.1 - Definitive)
1. Game Overview
**Flashcard Heroes** is a single-player roguelike deckbuilder, auto-battler (inspired by *Super Auto Pets* and *Slay the Spire*) that integrates an *Anki*-style spaced repetition system as resource generation mechanic. Players build a collection of **GachaBalls** (Units and Items) to survive encounters and defeat bosses.

2. Core Gameplay Loop
1. **Loadout**: Select a Hero and a Flashcard Deck.
2. **Path Selection**: Choose 1 of 3 encounter choices (Battles, Shop, Events, Rest Site).
3. **Resolution**: Resolve the node and advance the **Day** (Difficulty scaling).
4. **Conclusion**: Victory (Final Boss defeated) or Permadeath (Hero HP = 0).

3. Player Resources
- **Hero Health (HP)**: Persistent unit health for the run. 0 HP = Defeat. No Max HP cap.
- **Gold**: Persistent currency for Shop nodes. Lost at end of run.
- **Gacha Tokens**: Temporary encounter currency earned via Flashcards. Resets to zero after encounter.

4. Flashcard System (SRS)
Timed mini-game that generates **Gacha Tokens** for use in the current encounter.
- **The Deck**: Starts with 10 unlocked active cards; new cards are introduced over time with an info screen before each mini-game.
- **The Mini-Game**: A timed session of multiple-choice questions. Correct answers increase card "Mastery" and earn tokens. Incorrect answers decrease mastery.
- **Spaced Repetition**: An *Anki*-style weighted algorithm ensures cards with lower Mastery and more time since last used appear more frequently. The same card will not appear twice in a row and there's a small random factor to keep it from being too predictable.

5. GachaBall System
**GachaBalls** are the collectible Units and Items that form your "deck".
- **Units**: Creatures with HP and PWR stats and abilities. HP and PWR scale up to a 99 max cap; healing additive.
- **Items**: Equipment and consumables that provide stat bonuses or effects. Consumables are single-use per encounter, some can be single use per run.
- **Attributes**: Tiers (1-3), Rarity (Common-Legendary), and Tags (Fire, Water, Earth, Air, Light, Dark, Attacker, Defender, Support, etc.) for synergies.
    - **Item Slots**: Automatically computed based on Tier: Tier 1 (1 slot), Tier 2 (2 slots), Tier 3 (4 slots), and Hero (4 slots).

6. Inventories & Drawing
- **Run Inventory**: Your persistent collection (deck) for the run.
    - **Capacity**: 39 slots per tier.
    - **Random Eviction**: Acquiring a ball when a tier is full (39 items) permanently deletes a random ball of that tier.
- **Battle Inventory & Machines**:
    - Each battle uses a temporary copy of your Run Inventory as the initial draw pool. After that units can be merged, removed, summoned, etc. so the drawn pool can be changed during the battle but these changes do not affect the Run Inventory.
    - **Gacha Machines**: Spend tokens to draw balls from Tier 1, 2, or 3.
    - **Discard & Reshuffle**: Defeated units and overflow go to a shared Discard Pile. If a tier machine is empty, its balls from the discard pile are reshuffled (resetting stats to base).
- **Physics Overflow**: Battle draws are physical. Overfilling causes balls to push against a lid; sustained pressure sends them to the Discard Pile.

### 6.2 Economy & The Core Duality
The game operates on a dual-economy system that defines encounter difficulty and player progression. It is critical to distinguish between the **Run Economy** (Curating the Deck) and the **Battle Economy** (Realizing Value).

| Tier | Gold Cost (Shop) | Draw Cost (Tokens) | Note |
| :--- | :--- | :--- | :--- |
| **Tier 1** | 1 Gold | 1 Token | Basic units/items. |
| **Tier 2** | 2 Gold | 2 Tokens | Advanced synergies. |
| **Tier 3** | 4 Gold | 3 Tokens | Elite/Boss power levels. |

- **Run Economy (Gold)**: Used in Shops to perform "Deck Adds." Buying a GachaBall with Gold adds it to your Run Inventory. 
    - **Efficiency Penalty & Dilution**: Every non-synergistic unit added to the deck serves as a "dilution" of the draw pool, making it mathematically harder to draw specific "Engine" or "Anchor" pieces during battle.
    - **Mitigation Systems**: Shop and Event nodes provide **Remove** and **Transform** mechanics as the primary tools for maintaining a "Lean" deck and maximizing the Average Value per Token spent.
- **Battle Economy (Tokens)**: Earned via Flashcards. Used only during battle to "Realize" the value of your Run Inventory by drawing from Gacha Machines.

### 6.3 Deck Curation vs. Power Creep
In Flashcard Heroes, power is not just about having more units, but about the **Density of Synergy**. A smaller, high-synergy deck is often more powerful than a large deck of high-stat units due to the predictable nature of the draw pool. Players must constantly weigh the benefit of a new addition against the dilution of their core strategy.

7. Battle System
7. Battle System: The Tactical Puzzle
Battles are deterministic contests where the outcome is decided during the **Management Phase**. Each turn functions as a tactical puzzle where you must counter the enemy's formation using limited resources.

- **Phase 1: Performance (Flashcards)**: Your accuracy and speed in the mini-game determine your **Gacha Token** budget for the turn.
- **Phase 2: Management (The Puzzle)**:
    - **Resource Spending**: Decide how to spend tokens across the three Tiered Gacha Machines (Tier 1/2/3), each having its own cost and unique pool of units/items.
    - **Formation & Order**: Units act **Front-to-Back**. Since combat is deterministic (no crits/misses), the specific order of units and item placement is the deciding factor between victory and defeat.
    - **Counter-Play**: Analyze the enemy's stats, upcoming actions and reactions based on their abilities and equipment, trinkets, stat effects, etc to optimize your lineup placement, bench, and item usage.
- **Phase 3: Execution (Combat)**: All actions resolve automatically and sequentially. Success depends entirely on your preparation in the Management Phase with the availble drawn "hand" and board state.

*Note: Technical details on the event-driven ability system (triggers like `ON_ATTACK`, `ON_HURT`) and the O(N) resolution pipeline are documented in the [TDD](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Flashcard%20Heroes%20TDD%20%28Technichal%20Design%20Document%29%20V9.0.md).*
8. Merge System
Combining GachaBalls is a tool that can be used to increase adaptibilty to the enemy's formation by creating new units and items with specific abilities and to manipulate the probabilities of drawing specific units and items in the next turns since merging changes the pool of available gachaballs in each tier pool.
- **Recipes**: Valid combinations are defined by recipes. Recipes are **locked** until the result is first acquired in the run.
- **In-Battle Merge**: Done in the bench or lineup. Consumes two temporary balls to create a Tiered version for the current battle only. Result units inherit all equipped items. changes in the pool via merge only affect the current battle pool.
- **Permanent Merge**: Done in the Run Inventory; permanently consumes two balls to create an upgraded one.
- **Rules**: Merging combines current stats and status effects (e.g., Burn stacks).

9. Core Entities & Systems
- **Hero Unit**: Your central character. HP = Run Health. restricted to the PlayerLineup.
- **Trinkets**: Non-GachaBall items providing run-wide passive bonuses.
- **Nodes**: Path encounters including Battles (Common/Elite/Boss), Shops (acquire balls/reroll/remove/transform), and Rest Sites (Hero training for permanent HP/PWR boosts).
- **Ability System**: Event-driven (triggers like `ON_ATTACK`, `ON_DEATH`). Every unit an items has an ability or more besides sometimes passive stats.
- **Status Effects**: Temporary effects that stack and typically decay at turn end, per activation, etc.

| Effect | Description |
| :--- | :--- |
| **Burn** | Damage at turn end equal to stacks. |
| **Armor** | Blocks incoming damage. |
| **Spikes** | Deals damage back to attackers. |
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