# Flashcard Heroes: Design Philosophy & Systems Architecture

> [!NOTE]
> **Foundational Document**
> This document outlines the "Gold Standard Philosophy" and the economic/mathematical axioms that govern Flashcard Heroes. It serves as the "Design Bible" for why the game works the way it does.

---

## 1. The Gold Standard Philosophy: Axioms of Value and Balance

The foundational architecture of Flashcard Heroes is built upon a rigid, deterministic value system we designate as the **"Gold Standard."** In the chaotic landscape of auto-battlers and roguelike deck-builders, where power curves often spiral into opaque polynomial or exponential progressions that alienate players, our system enforces clarity through a strict integer progression: **1, 2, and 4**.

This tripartite value structure governs every actionable metric in the game—from unit cost and merge scaling to enemy experience budgets and removal penalties.

For the content design team, understanding the Gold Standard is not merely a matter of memorizing a cost table; it is about internalizing the philosophy of **linear cost versus geometric utility**. A Tier 3 unit costs exactly four times as much gold as a Tier 1 unit, yet its utility—derived from slot efficiency and item capacity—scales far beyond a simple quadruple multiplier. This guide dissects these mechanics to provide a blueprint for creating content that maximizes replayability, ensuring that every unit, item, and enemy acts as a distinct, solvable variable within the player's strategic calculus.

### 1.1 The Integer Hierarchy

The elegance of the Gold Standard lies in its rejection of fractional balancing. We do not tweak values by 10% or adjust costs by 0.5 gold. The tiers are absolute buckets of value:

| Tier Designation | Gold Cost | Merge Value | Item Slots | Enemy Budget (XP) | Removal Cost Scaling |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (Peasant)** | 1 | 1 | 1 | 1 | 1x |
| **Tier 2 (Knight)** | 2 | 2 | 2 | 2 | 2x |
| **Tier 3 (Hero)** | 4 | 4 | 4 | 4 | 4x |

This table serves as the immutable law of the game's economy. When designing a new unit, the first question is not "What does it do?" but "Which bucket does it fill?". The strict adherence to these integers creates a "solvability" that players find rewarding; they can calculate the exact opportunity cost of every action without hidden variables. A Tier 3 unit represents a significant commitment—not just in gold, but in the opportunity cost of the four Tier 1 units that were sacrificed or forgone to create it.

> [!NOTE]
> **Economy Disclaimer**: The 1–2–4 hierarchy applies strictly to the Gold economy (Shop and Encounter Generation). Battle draw costs follow a separate 1–2–3 Token hierarchy (Tier 1: 1, Tier 2: 2, Tier 3: 3) for battle-pacing reasons.

The **removal cost scaling (1x/2x/4x)** is particularly critical for content pacing. In many deck-builders, deck thinning is a dominant strategy, allowing players to strip their deck down to a few infinite loops. By scaling removal costs exponentially alongside unit value, we create a "soft cap" on deck manipulation. Removing a Tier 3 "curse" or a high-value card that no longer fits the build costs 4 Gold—a massive investment equivalent to purchasing a new Tier 3 Hero. This forces players to adapt to "deck bloat" rather than simply erasing it, necessitating the design of cards that function well in large, diluted decks.

### 1.2 The Cost-Power Divergence

While the cost curve is linear (1 -> 2 -> 4), the power curve is designed to be **sigmoid or geometric**, specifically driven by the interaction between **Base Stats** and **Item Slots**.

*   A Tier 1 unit has **1 Item Slot**.
*   A Tier 3 unit has **4 Item Slots**.

This is not a linear progression; it is a capability jump that allows for combinatorial explosions. A Tier 1 unit can hold a sword (+Attack). A Tier 3 unit can hold a sword, a shield, a haste potion, and a lifesteal amulet. The synergy between these four items creates a "Gestalt" effect where the whole is greater than the sum of its parts.

**For content creation, this means:**
*   **Tier 1 content** must be stat-dense but mechanically simple. They are the "raw materials."
*   **Tier 3 content** must be mechanically receptive (high synergy potential) but reliant on items to reach their ceiling. They are the "chassis."

If a Tier 3 unit is designed with base stats so high that it dominates without items, it breaks the game's economy because it bypasses the "Inventory Loop" entirely. A naked Tier 3 unit should lose to four equipped Tier 1 units. A fully equipped Tier 3 unit should destroy twenty Tier 1 units. This balance ensures that the "Cultivation" mechanic remains the primary driver of victory.

---

## 2. Unit Taxonomy and Tier Role Definition

To ensure high replayability, units across different tiers must not simply be stronger versions of one another; they must fulfill fundamentally different strategic roles defined by the constraints of the board and the economy. The distinction between "Horizontal" progression (adding more units) and "Vertical" progression (making one unit stronger) is codified in the difference between Tier 1 and Tier 3.

### 2.1 Tier 1: The Engine of Cost Efficiency
*   **Role:** Early Game Swarming, Resource Generation, Genetic Base.
*   **Constraint:** High Board Space Usage, Low Item Utility.

Tier 1 units, or "Peasants," are the most cost-efficient sources of raw stats in the game. In the early game, the player is constrained by Gold and Tokens, but has ample Board Space (slots on the battlefield). Therefore, the optimal strategy is to fill the board with cheap, efficient bodies.

**Design Guidelines for Tier 1:**
*   **Stat Efficiency:** A Tier 1 unit should provide the best "Stats per Gold" ratio in the game. If a T1 costs 1 Gold and has 10 Attack, a T3 (costing 4 Gold) should not have 40 Attack. It should have perhaps 24 Attack. This inefficiency in higher tiers forces the player to rely on T1 swarms for early survival.
*   **Simplicity:** T1 units operate without complex setup. Their abilities should be unconditional: "Deal X Damage," "Block X Damage," "Generate 1 Token."
*   **The Cultivation Canvas:** Because T1 units are cheap, they are the safest targets for risky "Cultivation" items. If a player uses a "Mutagen" potion that has a 50% chance to give +10 ATK and a 50% chance to kill the unit, they will use it on a 1-Gold T1, never on a 4-Gold T3. Content designers must create T1 units that have "High Risk/High Reward" trait slots to encourage this behavior.

**Archetype Example: The Scavenger Rat.**
*   **Stats:** Low HP, High Speed.
*   **Ability:** "Pilfer" - Generates 1 Gold on kill.
*   **Design Intent:** This unit is weak in combat but accelerates the economy. It demands to be "Cultivated" with HP buffs so it can survive long enough to trigger its gold generation.

### 2.2 Tier 2: The Transitional Bridge
*   **Role:** Trait Locking, Mid-Game Pivot, Hybrid Efficiency.
*   **Constraint:** 2 Item Slots (The "Combo" Tier).

Tier 2 represents the awkward middle adolescence of the unit. It requires merging two T1s. In the Gold Standard, it costs 2 Gold. It serves as the "Checkpoint" for the Cultivation system.

**Design Guidelines for Tier 2:**
*   **The 2-Slot Synergy:** With two slots, T2 units introduce the first layer of combinatorial depth. Designers should create T2 units that specifically bridge two disparate archetypes. A T2 "Spell-Sword" might have synergies for both Magic items and Melee weapons, encouraging the player to merge a T1 Mage and a T1 Warrior.
*   **Stat Consolidation:** T2 is used to free up board space without sacrificing too much efficiency. It effectively compresses two tiles into one.
*   **Trait Inheritance:** T2 is where temporary buffs should become "locked in." If a T1 has a temporary "Rage" token, merging it into a T2 should convert that Rage into permanent Base Attack. This makes the timing of the merge a critical decision.

**Archetype Example: The Shield-Bearer.**
*   **Stats:** High HP, Low Attack.
*   **Ability:** "Phalanx" - Grants its Armor value to the unit directly behind it.
*   **Design Intent:** This unit cares about positioning and equipment. It encourages the player to stack Armor items in its two slots, not for its own survival, but to buff the T3 carry standing behind it.

### 2.3 Tier 3: The Lords of Slot Efficiency
*   **Role:** Late Game Carry, Exodia Enabler, Stat Compression.
*   **Constraint:** Low Stat/Gold Efficiency, High Item Capacity.

Tier 3 units are the endgame. When the board is full (Unit Cap Reached), the only way to increase power is to upgrade existing units to T3. They provide the highest "Stats per Tile" density.

**Design Guidelines for Tier 3:**
*   **The Multiplicative Chassis:** T3 abilities should essentially be mathematical multipliers for items. While T1s have additive abilities ("Deal +5 Damage"), T3s should have multiplicative ones ("Deal Double Damage for each equipped Weapon"). This leverages the 4-slot inventory.
*   **The "Cultivated" Requirement:** A T3 unit merged from "fresh" (un-buffed) units should be underwhelming—perhaps even weaker than the four T1s that made it. This is a deliberate design choice to punish "lazy" merging. A T3 unit is only powerful if it inherits the cultivated stats of its ancestors. This enforces the "Cultivation" loop as the dominant strategy.
*   **Board Space Economy:** T3 units are the solution to the "Board Space" resource crisis. Designers must treat Board Space as a resource as valuable as Gold. T3s are "Space Compressors."

**Archetype Example: The Hydra.**
*   **Stats:** Moderate.
*   **Ability:** "Polycephaly" - Can equip 4 Weapons. Attacks once with EACH equipped weapon per turn.
*   **Design Intent:** This unit is useless without items. With 4 daggers, it attacks 4 times. With 4 Greatswords, it wipes the board. It justifies the T3 cost solely through its item interaction.

---

## 3. The Cultivation Engine: Merging and Inheritance Mechanics

The defining unique selling point (USP) of Flashcard Heroes is the Cultivation mechanic. Unlike standard auto-battlers where units have static stat-lines per star level (e.g., Teamfight Tactics or Dota Auto Chess), our units are dynamic containers of history. A Tier 3 unit is not just a unit; it is the genealogical sum of its ancestors.

### 3.1 The Inheritance Formula

To ensure the game remains a solvable puzzle rather than a black box of RNG, the inheritance logic must be strictly additive and deterministic.

**The Formula for Merging (Child Unit $C$ from Parents $A$ and $B$):**
$$HP_C = HP_A + HP_B$$
$$ATK_C = ATK_A + ATK_B$$

However, the "Cultivation" rule implies that $HP_A$ and $HP_B$ are not the base stats of the unit type, but the **current stats of the specific unit instance**, including permanent buffs consumed during their lifecycle.

**The "Protein Shake" Theorem:**
Imagine an item "Protein Shake" (Cost 1 Gold) that grants +5 Permanent HP.

*   **Scenario A (Late Application):** Player buys a T3 unit (Base HP 100). Applies 1 Shake. Final HP = 105. Cost = 5 Gold.
*   **Scenario B (Early Cultivation):** Player buys four T1 units (Base HP 25 each). Applies 1 Shake to each (Cost 4 Gold).
    *   T1s are now 30 HP each.
    *   Merge two T1s -> T2. HP = $30 + 30 = 60$. (Assuming TierModifier = 1 for simplicity of additive conservation).
    *   Merge two T2s -> T3. HP = $60 + 60 = 120$.
    *   **Result:** The Cultivated T3 has 120 HP vs the Fresh T3's 105 HP.

**Implication:** Early investment yields compound returns via the merge process.

**Design Constraint:** Content creators must design "Consumable" items that are inefficient if used once, but efficient if multiplied through merging. This creates a "long-term planning" reward loop.

### 3.2 Genealogical Traits

Beyond raw stats, cultivation allows for "Trait Splicing." This is a massive vector for replayability.

*   **Mechanism:** Certain T1 units have "Hereditary Passives." When merged, the Child retains the passive.
*   **Example:**
    *   Parent A (T1 Goblin): "Greed" (Gain 1 Gold on kill).
    *   Parent B (T1 Orc): "Rage" (+1 ATK when hit).
    *   Child (T2 Hybrid): Has both Greed and Rage.
*   **Replayability:** Players will spend hours discovering "Recipes." "What happens if I merge a Fire Elemental with a Water Elemental?"

**Design Rule:** T1 passives must be distinct. T3 units should have no inherent passives, or very weak ones, to encourage the player to craft a custom T3 using T1 passives. If T3s have strong native passives, players will ignore the breeding mechanic.

### 3.3 The "Snapshot" Mechanic

The "Inventory Loop" constraint mentions a "Battle Snapshot." This creates a critical distinction between Run Inventory (The Supply Deck) and Battle Inventory (The Hand/Board).

*   **Persistence:** Cultivation is permanent. If a unit is buffed and merged in the Battle Snapshot, does it persist to the Run Inventory?
*   **Rule:** Merging Crystallizes Power.
    *   If you apply a temporary "Battle Token" buff (+10 ATK for this battle) to a unit, and then MERGE that unit during the battle, the new Merged Unit treats that +10 ATK as part of its Base Stats.
    *   This allows players to use temporary resources (Tokens) to gain permanent power (Gold Value).
*   **Balance Risk:** This is extremely powerful.
*   **Counter-Balance:** Merging costs Gold (indirectly via opportunity cost) or Board Space. Also, the prompt implies "Tokens bank," so spending Tokens to buff->merge depletes the bank for future boss fights.

---

## 4. The Inventory Machine: Loops, Digging, and Recycling

The inventory system in Flashcard Heroes deviates from the standard "Exhaust" mechanics of Slay the Spire. Instead, it adopts a "Recycle" mechanic where the discard pile is immediately shuffled back into the deck when empty. This creates an **Infinite Deck** dynamic, shifting the focus from "conserving cards" to "maximizing throughput" (Velocity).

### 4.1 The Three-Deck Architecture
1.  **Supply Deck (Run Inventory):** The master collection. All units and items owned.
2.  **Hand (Battle Buffer):** Cards drawn and ready to play.
3.  **Discard (Recycle Bin):** Cards used or discarded.

**The Machine:** "Machines recycle discards (never empty)."
This implies that the deck is a flowing river. The player's goal is to increase the current (Draw Speed) to see their best cards more often.

### 4.2 The Physics of "Digging"

"Digging" (discarding cards to draw new ones) is identified as a key mechanic. In an infinite recycle system, Digging is the primary way to manipulate RNG and find specific answers.

*   **Cost of Digging:** Because the deck never empties, Digging cannot be free, or players would loop infinitely until they found the perfect hand (Solvability -> Triviality).
*   **Token Cost:** Digging must cost Tokens.
*   **The Formula:** $Cost = Base + (N \times Scaling)$.
    *   First Dig: 1 Token.
    *   Second Dig: 2 Tokens.
    *   Third Dig: 4 Tokens. (Adhering to the Gold Standard).
*   **Strategic Implication:** Players must balance "Spending Tokens to Play Units" vs "Spending Tokens to Find Units."

### 4.3 Slot Efficiency vs. Deck Velocity

A critical tension exists between the T3 Unit (needs 4 items) and the Deck Size.

*   To fuel a T3 unit, you need 4 Item Cards in your deck.
*   Adding 4 Item Cards "dilutes" the deck, reducing the chance of drawing the T3 unit itself.

**Solution:** Tutors and Cantrips.
*   Design items that "Cycle" (Draw a card when played).
*   Design T2 units that "Fetch" items from the deck ("Battlecry: Draw a Weapon").
*   This allows the player to build the massive decks required for T3s without losing the consistency needed for T1 survival.

### 4.4 The Banking Economy

"Tokens bank between turns." This is a key tactical lever. It introduces Micro-Pacing within a battle.

*   **The Saving Throw:** Players can play "skinny" (spending few tokens) during easy turns to bank a massive reservoir of Tokens for a future turn.
*   **The Nova Turn:** On a Boss fight, the player spends 50 Tokens to dig through their deck 10 times, assembling the perfect "Exodia" T3 unit with 4 specific items.

**Content Design:** Enemies must be designed to punish both extremes.
*   **Punish Hoarding:** "Thief" enemies that steal Banked Tokens on hit.
*   **Punish Spending:** "Endurance" enemies that have multiple phases, exhausting players who blow their budget on Turn 1.

---

## 5. Combat Dynamics: The Deterministic Puzzle

Combat in Flashcard Heroes is described as "Player First (Alpha Strike)" with "No UI arrows" and "Deterministic Logic". This removes the reactive element of games like Hearthstone and replaces it with the proactive planning of a puzzle game like Into the Breach.

### 5.1 The Alpha Strike Doctrine

"Player First" means the player's units act before the enemy. This is the single most powerful mechanic in the game. It allows for **Damage Mitigation via Offense**.

*   If a player unit deals 10 Damage and the enemy has 10 HP, the enemy deals 0 Damage (because it dies before acting).
*   **Health as a Resource:** Player HP is only lost when the Alpha Strike fails.
*   **Design Consequence:** Enemy HP must be calibrated carefully.

**Breakpoint Design:** Enemies should have HP thresholds that correspond to standard Unit Attack values.
*   Tier 1 Standard: 5 Attack.
*   Tier 1 Enemy HP: Should be 5 (One-shot), 6 (Survives with 1 HP), or 10 (Two-shot).
*   An enemy with 6 HP is infinitely more dangerous than an enemy with 5 HP against a standard T1 unit. This 1 HP difference drives the need for "Cultivation" (+1 Attack Buffs).

### 5.2 Readable Unit Logic (The No-Arrow Rule)

Without UI arrows, unit behavior must be rigidly predictable. The complexity must come from arrangement, not behavior.

**Standard Targeting Matrix:**
*   **Melee:** Attacks the tile directly forward. If empty, attacks the nearest tile in the forward row.
*   **Ranged:** Attacks the lowest HP unit (Snipe) or the furthest unit.
*   **Support:** Buffs the unit Behind or Adjacent.

**Content Example:**
*   **Unit:** Pikeman (T1).
*   **Behavior:** Attacks Forward.
*   **Trait:** "Reach" - If the forward enemy dies, the Pikeman can attack a second time against the unit behind it (Excess damage trample).
*   **Readability:** The player knows exactly what will happen. "If I buff my Pikeman to 10 Attack, he kills the front Goblin (5 HP) and hits the Orc behind it (5 HP). I take no damage."

### 5.3 Single-Player Survival Loop

The prompt mentions "Single-player survival loop." This implies the player's avatar or "Health Pool" is the fail state. Defense is proactive. Since there are no "Taunt" mechanics in the traditional sense (UI arrows), "Blocking" usually means "Killing the enemy before they hit you."

*   **Armor/Shields:** These should be "Ablative."
*   **Design Preference:** Flat Reduction. "Armor 2" reduces all incoming hits by 2. This makes the unit immune to "Swarm" enemies (1 Attack) but vulnerable to "Heavy Hitters" (10 Attack). This creates clear counter-play.

---

## 6. Economy: The Dual-Currency Engine

The bifurcation of Gold (Macro/Run) and Tokens (Micro/Battle) is the gearbox of the game's pacing.

### 6.1 The Inflationary Removal (1x/2x/4x)

The cost to remove cards scales exponentially.
*   Removal 1: 1 Gold.
*   Removal 2: 2 Gold.
*   Removal 3: 4 Gold.
*   Total for 3 Removals: 7 Gold.

**Context:** A T3 Unit costs 4 Gold. Removing 3 cards costs nearly two T3 units.

**Insight for Designers:** You cannot balance the game assuming players will have thin, perfect decks. The economy actively discourages it. Therefore, you must design **"Self-Cleaning" cards**.

*   **Mechanic: Exile/Consume.**
    *   "Potion of Strength: Give +2 ATK. Consume (Remove from deck after use)."
    *   These items allow the player to thin their deck through gameplay rather than paying Gold. This rewards using items rather than hoarding them.
*   **Mechanic: Transform.**
    *   "Coal: 1 Gold. Transform into Diamond (5 Gold) after 3 battles."
    *   This changes a "bad card" into a "reward," effectively removing the bad card without using the Removal Shop.

### 6.2 The Reward Dilemma: Value vs. Flexibility

"Rewards: Choice of specific Unit (Value) vs Gold (Flexibility)."
This is a classic "Bird in hand" problem.

*   **Unit Reward:** You see a "Knight (T2)" card. Market Value = 2 Gold.
*   **Gold Reward:** You get "1 Gold."

**The Trap:** The Unit is objectively worth more (2 vs 1). However, the Unit might dilute the deck (lowering Velocity). The Gold is liquid but loses value due to inflation (Shop prices might rise, or items might be expensive).

**Design Goal:** Ensure the "Unit" rewards are enticing. They should often be slightly pre-cultivated.
*   **Example:** "Knight with +1 HP." This makes the Unit reward strictly better than buying a Knight from the shop, tilting the decision away from raw Gold.

---

## 7. Emergent Replayability: Systemic Interaction

Replayability in Flashcard Heroes does not come from random events, but from the Combinatorial Genealogy of the units.

### 7.1 The "Perfect Specimen" Goal

Players will set their own goals: "Can I build a unit with 1000 Attack?"
This requires understanding the Merge Math. It creates a "Clicker Game" loop inside the strategy game. "I need to farm 10 more Tokens to buy 2 more Whetstones to merge my T1s..."

### 7.2 The "Infinite" Turn

With "Banking Tokens" and "Digging," players can achieve "Infinite Turns" where they draw their whole deck.

**Design Warning:** Designers must put a "Soft Cap" on this to prevent turns taking 1 hour.
**Solution:** Escalating Dig Costs (as mentioned in 4.2). The friction eventually becomes too high.

---

## 8. Content Creation Guidelines (Practical Implementation)

This section provides the specific data structures and rules for the design team to implement the JSON/Database entries for Flashcard Heroes.

### 8.1 Unit Data Structure

Every unit must have the following tags defined:

| Field | Type | Constraint | Description |
| :--- | :--- | :--- | :--- |
| **Tier** | Int | {1, 2, 4} | Determines Cost, Merge Value, XP, Slots. |
| **BaseHP** | Int | >0 | Health Pool. |
| **BaseATK** | Int | >0 | Damage per hit. |
| **Slots** | Int | =Tier | Number of item slots. Hard-coded to Tier. |
| **Family** | Enum | {Martial, Magic, Bestial} | Determines valid "Mutations" or Merge compatibilities. |
| **MergeBehavior** | Script | Logic | What happens on merge? (Default: Add stats. Override: "Keep Highest HP"). |

### 8.2 Enemy Design Matrix

Enemies must be designed to challenge specific player strategies (Cultivation vs. Swarm).

| Enemy Archetype | Threat | Counter-Strategy |
| :--- | :--- | :--- |
| **The Wall** | High Armor, Low ATK. | Cultivated T3 (High single-hit damage to pierce armor). |
| **The Swarm** | Low HP, High Unit Count. | Cleave/Area Damage (T2/T3 with AoE items). |
| **The Assassin** | High ATK, Low HP, Targets Backline. | Defensive T1 Swarm (Body blocking) or Taunt. |
| **The Corruptor** | Adds "Curse" cards to Deck. | Digging/Velocity (Cycle past the curses) or Removal. |

### 8.3 Item Design Heuristics

*   **Cultivation Items (Cost 1):** Must provide permanent stats. Effect is "On Play."
    *   *Example:* "Iron Rations: +2 Max HP."
*   **Equipment Items (Cost 2-4):** Must provide "While Equipped" passive effects.
    *   *Example:* "Heavy Plate: -2 Damage taken."
*   **Runes/Mutators (Cost 4):** Changes the rules of the unit.
    *   *Example:* "Vampiric Rune: Unit heals for 100% of damage dealt." (Only fits on T3 due to cost/slot pressure).

---

## 9. Conclusion

Flashcard Heroes is a game of rigorous economic discipline disguised as a fantasy battler. By adhering to the **Gold Standard (1/2/4)**, we create a transparent, fair, and solvable system that respects the player's intelligence. The **Cultivation** mechanic provides the depth, turning every T1 unit into a potential "Chosen One" through careful investment and merging.

The interaction between the **Inventory Machine (Recycling/Digging)** and the **Battle Snapshot** creates a dynamic pacing where players alternate between "Hoarding/Farming" phases and "Explosive/Boss" phases. This rhythm, dictated by the banking of Tokens and the inflation of Removal costs, ensures that no two runs feel identical, as the pressure of the economy forces players to improvise with the tools they have cultivated.

**For the design team, the mandate is clear:** Trust the Integers. Do not deviate from the 1/2/4 value system. Build the complexity inside the slots, not in the base numbers. If we hold to this standard, Flashcard Heroes will offer a depth of replayability that rivals the giants of the genre.
