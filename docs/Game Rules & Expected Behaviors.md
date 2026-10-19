# Flashcard Heroes - Game Rules & Expected Behaviors

> [!IMPORTANT]
> **Authority & Scope:**
> This document is the authoritative **Single Source of Truth (SSOT)** for all player-facing gameplay rules, mechanics, interaction models, economic constraints, and expected behavioral contracts across *Flashcard Heroes*.
> 
> **Natural Language Standard (Non-Technical):**
> This document is written in clear, natural language so that game designers, QA testers, writers, and producers can easily understand every system:
> * Mechanics are described in terms of player-facing concepts, rules, triggers, constraints, visual feedback, and concrete game interactions.
> * **No code snippets, class names, function signatures, internal variable names, or technical engine jargon** are permitted in this document.
> * All code architecture, class structures, engineering patterns, and data pipelines belong strictly in dedicated technical documents: [CombatSystem.md](CombatSystem.md), [InventoryManager.md](InventoryManager.md), [EncounterSystem.md](EncounterSystem.md), [UIInteraction.md](UIInteraction.md), [FlashcardSystem.md](FlashcardSystem.md), and the [Technical Design Document](Flashcard%20Heroes%20TDD%20(Technichal%20Design%20Document)%20V9.0.md). High-level philosophy and design pillars belong in the [Game Design Document](Flashcard%20Heroes%20GDD.md).

---

# 1. Win & Loss Conditions

## 1.1 Winning a Run
A run is successfully completed when the player navigates through the path map and defeats the **Final Boss**, with the Hero's health remaining above 0.

## 1.2 Losing a Run (Permadeath)
A run is lost immediately if the **Hero's health (HP) reaches zero**.
* **Permadeath**: Upon victory or defeat, the run's save checkpoint is permanently cleared, and the run ends immediately.
* **Hero Unit Rules**:
  * The Hero participates directly on the active battle board alongside standard units and behaves as an active combatant (subject to damage, healing, buffs, and attacking).
  * **Lineup Restriction**: The Hero is permanently bound to the active team lineup and **cannot** be moved to the bench or inventory.
  * **Item Slot**: Like all other units, the Hero possesses strictly **one item slot**.

---

# 2. Run Structure & State Lifecycles

Each run follows a structured progression loop:

```
[Loadout Selection]
       │
       ▼
   [Day 1 Map] ──► [Encounter Node] ──► [Rewards / Shop / Rest / Dojo / Black Market]
       │
       ▼
   [Day 2 Map] ──► [Encounter Node] ──► ...
       │
       ▼
 [Boss Milestones] (Deck Mastery Thresholds)
       │
       ▼
  [Final Boss] ──► [Victory!]
```

## 2.1 Loadout Selection Scene
Before starting a run, the player configures their starting setup:
* **Hero & Deck Carousels**: Selection carousels allow choosing a starting Hero and Flashcard Deck using a 3-item layout (previous item, currently selected item scaled up, next item) with navigation arrows.
* **Simultaneous Detail Panels**: Selecting a carousel item updates dedicated information panels for the Hero (base HP/Power, abilities, traits, flavor text) and the Deck (card counts and descriptions).
* **Deck Ordering**:
  * `Regular`: Reviews cards in their standard catalog order.
  * `Inverted`: Reviews cards in reverse catalog order.
  * `Random`: Shuffles cards deterministically using the run's map random seed.
* **Test Mode Starters Option**: In developer Test Mode, a debug dropdown utility allows granting starting items or trinkets directly into the Hero's starting loadout.

## 2.2 State Lifecycles

### Run-Persistent State (Preserved Between Nodes)
* Hero and unit base stats (HP, Power, Level, Rarity, permanent training upgrades, and merge inheritance surpluses).
* Gold.
* Run Inventory (the player's permanent collection of units and items across Tier 1, Tier 2, and Tier 3).
* Equipped Trinkets.
* Flashcard deck mastery levels, unlock states, and review history.

### Encounter-Temporary State (Reset After Each Encounter)
* Gacha Tokens (reset to 0 at the start of every encounter).
* Temporary in-combat stat modifications and status effects (Armor, Burn, Spikes, Static).
* Battle Inventory (the active draw pools inside the tier machines).
* Battle Discard Pile (all defeated units and replaced items).
* Battle lineup and bench formation.

---

# 3. Core Resource Economy & Gacha Pools

The game operates on a dual-economy system that separates long-term collection curation from tactical combat execution:

## 3.1 Gold (Run Economy)
* **Purpose**: Spent outside of combat to purchase units/items from Shops, purge or transform units at the Black Market, buy training sessions at the Dojo, and heal/upgrade at Rest Sites.
* **Acquisition**: Earned by winning battles or selling reward capsules.
* **Difficulty Role**: Accumulated Gold and collection size inform the encounter generator's budget curve.
* **Tier Gold Costs (Shop & Encounter Generator)**:
  * **Tier 1**: Base 1 Gold * 2^(Level - 1) (Level 1: 1 Gold, Level 2: 2 Gold, Level 3: 4 Gold)
  * **Tier 2**: Base 2 Gold * 2^(Level - 1) (Level 1: 2 Gold, Level 2: 4 Gold, Level 3: 8 Gold)
  * **Tier 3**: Base 4 Gold * 2^(Level - 1) (Level 1: 4 Gold, Level 2: 8 Gold, Level 3: 16 Gold)

## 3.2 Tokens (Battle & Encounter Economy)
* **Purpose**: Spent during encounters (such as the Management Phase of battles, reward rooms, rest sites, and unit training) to draw from machines or roll for upgrades.
* **Acquisition**: Earned on a per-encounter basis primarily by answering questions correctly during the Flashcard minigame (and through select trinkets).
* **Reset**: Tokens exist strictly within the active encounter. In battles, unspent tokens carry over between turns within the same battle. Between different encounters, tokens **never** carry over; any new encounter starts with tokens reset to zero.
* **Tier Draw Costs (Tokens)**:
  * **Tier 1 Machine**: 1 Token
  * **Tier 2 Machine**: 2 Tokens
  * **Tier 3 Machine**: 3 Tokens

## 3.3 The Strategic Duality: Swarming vs. Slot Power
* **Swarming (Tier 1 Focus)**: Tier 1 units are cheap to draw in battle (costing only 1 Token) but have modest base stats. Merging duplicate Tier 1 units permanently upgrades their level, which doubles their Gold valuation in shops while their Token draw cost remains strictly 1 Token. This yields exceptional deployment efficiency.
* **Slot Power (Tier 2 & Tier 3 Focus)**: Higher-tier units cost more Tokens to draw (2 or 3 Tokens) but provide concentrated slot efficiency, higher base stat packages, and multiplicative abilities.
* **Exhaustion Risk**: Because defeated units and replaced items are committed permanently to the Discard Pile for the remainder of a battle, an ultra-lean deck can run out of GachaBalls during prolonged encounters, resulting in defeat. Players must balance deck predictability (small decks) against raw endurance (larger decks).

---

# 4. Flashcard Resource Engine (Spaced Repetition System)

The Spaced Repetition System (SRS) powers tactical resource generation:

## 4.1 In-Battle Minigame Mechanics
* **Timed Session**: A fast-paced timed minigame at the start of each combat turn.
* **Correct Answer**: Awards 1 Token, increases card mastery by 1, grants a +0.5s timer extension, increments the consecutive correct answer streak, and escalates audio pitch and edge flame VFX.
* **Incorrect Answer**: Awards no tokens, decreases card mastery by 1, resets the streak to 0, and smoothly resets audio pitch.
* **Skip**: Awards no tokens, decreases card mastery by 1, grants a +0.5s timer extension, but **preserves** the active streak and audio pitch without penalty.
* **SRS Selection Algorithm**:
  * Questions are chosen using weighted selection prioritizing three factors:
    1. *Mastery Level (High)*: Lower mastery cards appear far more frequently.
    2. *Recency (Medium)*: Cards not reviewed for several days are prioritized.
    3. *Random Factor (Low)*: Slight randomization to prevent rigid predictability.
  * The same card **never** appears twice in succession.
* **Review Popup Window (New Card Introduction)**:
  * Triggers at the start of a minigame session when a new card is introduced into the active deck.
  * Features the newly unlocked card in the main view (question, answer, audio pronunciation, and grammatical explanation).
  * Displays a bottom row of up to 6 clickable priority cards strictly representing the lowest-mastery cards currently unlocked in the deck.

## 4.2 Rest Site Flashcard Mechanics
* **Correct Answer**: Earns Tokens that can be spent at Rest Site machines for permanent Hero stat upgrades.
* **Incorrect / Skip**: Awards no tokens. Tokens exist only within the active rest site and reset upon departure.

## 4.3 Streak & Juice Escalation
* **SFX Pitch**: The correct-answer sound effect pitch increases by +0.05 per streak level, capping at 1.5x pitch at streak 10+.
* **BGM Pitch & Tempo**: The active minigame background music pitch dynamically scales upwards by +0.02 per streak level, capping at 1.2x tempo at streak 10+. Incorrect answers smoothly reset pitch to baseline 1.0x.
* **Visual Edge Fire Aura**: A dynamic fire aura frames the borders of the minigame window, scaling its flame intensity, speed, and particle brightness with the player's streak.

## 4.4 Mid-Minigame Flashcard Unlock (3-Streak Progression)
Answering 3 questions correctly in a row triggers an immediate mid-minigame card unlock:
* **Trigger Condition**: Requires consecutive correct answers without misses. (Skips preserve the streak but do not increment it).
* **Pool Requirement**: Requires locked cards remaining in the run's deck pool. If all cards are already unlocked, reaching a 3-streak triggers no unlock or timer bonus.
* **Unlocking**: The next locked card from the deck pool is unlocked and immediately queued as the very next question displayed.
* **+1.0s Timer Extension**: Awards an immediate +1.0s bonus time extension directly to the countdown timer (in addition to the standard +0.5s for a correct answer, yielding +1.5s total time gained on the triggering question).
* **Celebration Feedback**: Celebrated with multi-point fireworks, golden window flash, bright white timer bar flash with a floating `+1.0s` popup, and an animated announcement banner.
* **Single Occurrence**: Can only trigger once per minigame session.
* **Progression Accounting**: The mid-minigame unlocked card is recorded as presented. At the start of subsequent minigames, the next locked card is introduced in the review popup—never repeating cards already unlocked mid-minigame.

---

# 5. Battle Structure & Flow

Battles resolve in distinct phases:

```
[Turn Start] ──► [Flashcard Minigame] ──► [Management Phase] ──► [Combat Execution] ──► [End of Turn]
                                                 │
                                         ("Battle!" Click)
```

1. **Turn Start Phase**: Any turn-start abilities or battlefield slot effects evaluate.
2. **Flashcard Minigame**: The player answers questions to generate their Gacha Token budget for the turn.
3. **Management Phase**: The player spends tokens, draws units/items, repositions their team, merges units, equips items, uses consumables, and inspects the enemy lineup.
4. **Pre-Combat Phase**: Triggered when the player clicks "Battle!". All 15 Trait Trinkets (Elemental, Class, Visual) activate and deliver their combat-start effects.
5. **Combat Execution Phase**: Units take turns acting strictly front-to-back. Attacks, abilities, reactions, and deaths resolve automatically and deterministically.
6. **End-of-Turn Phase**: Status effects decay, end-of-turn abilities resolve, and pending deaths/summons clear. If enemies remain, a new turn begins.
7. **Battle Result**: Defeating all enemies opens Victory results leading to post-battle rewards. The Hero reaching 0 HP triggers Defeat results and ends the run.

---

# 6. Management Phase Rules & Interaction Checklist

## 6.1 Controls & Selection Models
* **Mouse (Desktop)**:
  * **Single-Click / Tap**: Selects the entity without opening inspection windows. A quick click suppresses hover re-arming on that element until the cursor exits.
  * **Hover Peek**: Hovering an inspectable entity opens a temporary inspection peek window after a `0.4s` dwell delay. The peek stays open only while hovering and closes immediately upon cursor exit. Hover peek is disabled during Combat animations.
  * **Long-Press Peek**: Holding the pointer down for `0.5s` opens a temporary inspection peek window. Releasing closes it immediately and suppresses click selection. Dragging more than 24 pixels cancels the peek.
* **Combat Click-to-Pin**: During Combat animations, normal input is blocked except for instant pause-and-inspect. Clicking any inspectable entity instantly pauses combat and locks its inspection window open. Clicking another entity switches inspection; clicking empty space or the same unit dismisses the window and resumes combat playback.

## 6.2 Drag-and-Drop Intent Priority
When an entity is dropped onto another entity, intent resolves in strict priority:
1. **Merge**: If a valid merge recipe exists between the two entities, opens the Choice Window preview (Merge vs. Swap).
2. **Equip**: If an item is dropped onto a unit, executes an Equip (or Item Replacement if the unit already holds an item).
3. **Use**: If a consumable item is dropped onto a valid unit, executes its effect immediately.
4. **Swap / Move**: If neither merge nor equip applies, checks placement legality to perform a Swap (if the target slot is occupied) or a Move (if empty).

## 6.3 Gacha Draw & Bench Overflow
* Drawn GachaBalls land in the first empty slot of the Player Bench.
* **Overflow**: If the Player Bench is completely full when a draw occurs, the drawn ball is sent directly to the **Battle Discard Pile**.

## 6.4 Dynamic Token Scaling (Templar / Token Power)
Units with token-scaling abilities scale dynamically with active resources:
* Both friendly and enemy Templars scale strictly with the **player's current Gacha Tokens**.
* All living Templars on the board (lineup and bench, player and enemy) respond in real time whenever tokens change. Stockpiling tokens makes enemy Templars stronger, creating a direct tactical trade-off.
* Permanent training stat upgrades on individual Templar instances are preserved and form the baseline onto which dynamic token scaling adds.
* When drawn, the unit lands displaying its base stats, then immediately triggers its token power ability to apply its dynamic power bonus based on remaining tokens.

## 6.5 Formation & Placement Constraints
* **Active Lineup**: Consists of up to 5 fixed slots. Units resolve attacks strictly from front (Slot 0) to back (Slot 4).
* **Player Bench**: Staging area used for holding units, staging items, and performing merges.
* **Items on Lineup**: Items cannot be placed directly into lineup slots; they can only be equipped onto units.
* **Tier Container Integrity**: Tier 1, 2, and 3 containers cannot hold entities of mismatched tiers.

## 6.6 Equipping Items
* **Bench Origin Only**: Items can **only** be equipped from the Player Bench onto a unit on the Lineup or Bench. Items cannot be equipped directly from inventory drawers (which are read-only) and cannot be equipped outside battle.
* **No Manual Unequipping**: An equipped item cannot be dragged back to the bench or moved to another unit. Aside from specific item-stripping consumables (such as *Potion of Plunder*), equipment cannot be unequipped without being replaced.
* **Bench Item Passives**: Items equipped on bench units provide their passive stat bonuses immediately, but their reactive combat abilities do not activate until the unit enters the active Lineup.
* **Single Item Capacity & Item Replacement**:
  * Every unit holds at most **one item**.
  * Equipping an item onto a unit that already has an item executes an **Item Replacement**.
  * **Discard Destination**: The displaced item is removed and sent directly to the **Battle Discard Pile**. It does **not** return to the bench.
  * **Discard Animation**: The replaced item animates along a parabolic arc into the Discard Pile button with audio impact and button bump.
  * **Net Stat Delta Evaluation**: The system evaluates the net difference between the old and new item. A net stat gain displays buff visual feedback, while a net stat loss displays floating debuff text (`-X` in red for HP, black for Power).

## 6.7 Consumable Items
* **Usage**: Consumables can only be dragged and used from the Player Bench. They can target both friendly and enemy units.
* **Consumption**: Consumables execute their effects immediately without occupying an item slot and disappear from the battle pool without entering the Discard Pile.
* **Item-Stripping Consumables (*Potion of Plunder*)**: Strips an equipped item from the target and sends it directly to the player's matching tier Gacha Machine drawer, making it available to be drawn in subsequent turns.
* **Stackable Regular Buffs**: Consumable stat modifications (healing potions, stat potions, scrolls, elixirs) are stackable buffs that become direct enhancements of the recipient unit.
* **Consolidation on Merge**: In all merges (both Evolutionary Level-ups and Recipe Tier-ups), all consumable buffs from both parent units are fully conserved and added together additively into the resulting unit's stats and merge surplus.

## 6.8 Merging GachaBalls
Merging combines two units to create a stronger unit:
* **Recipe Discovery**: Recipes are locked at run start. Acquiring a unit or item through rewards, events, or summons permanently unlocks its recipe for the remainder of that run.
* **Evolutionary Merge (Leveling Up)**:
  * Requires two identical units of matching level (Level 1 + Level 1 -> Level 2; Level 2 + Level 2 -> Level 3). Units of different levels cannot self-merge, and Level 3 units cannot merge further.
  * The leveled-up unit is considered the same continuous unit advancing in power.
  * It gains +1 HP and +1 Power per level, improves ability scaling, and inherits all accumulated extra stats (training, consumable buffs, prior merge surplus).
* **Recipe Merge (Tiering Up)**:
  * Requires two different units according to an unlocked recipe.
  * Allows **any combination of unit levels** (e.g. Level 1 + Level 3).
  * The resulting higher-tier unit always begins at **Level 1** as a brand-new entity, but inherits the summed surplus stats and elemental souls of both parents.
* **Elemental Souls Inheritance**:
  * Elemental souls are strictly cumulative. All souls from both parents add together directly onto the resulting unit (Result Souls = Parent A Souls + Parent B Souls). No souls are ever lost during a merge.
* **Item Transfer Priority**:
  * During any merge, only one equipped item carries over (the target unit's item takes priority; if empty, the source unit's item is kept). The secondary non-transferred item is discarded directly to the Battle Discard Pile.
  * The retained item's passive stats are pre-baked into the merged unit's starting stats silently, without redundant self-buff animations.
* **Contextual Merge Outlines**: Selecting or dragging an entity highlights valid targets:
  * Level-up targets highlight in Cyan.
  * Recipe tier-up targets highlight in Magenta.
  * Equip targets on friendly units highlight in White.
  * Undiscovered recipe candidates in shops and rewards highlight in Violet.

## 6.9 Physics Drawers & Overflow (Battle Only)
* During battle, the Battle Inventory drawers (Tier 1, 2, 3) and the side Discard Pile drawer are **Read-Only Visualizations**. Players cannot drag, equip, or move balls directly from these physics containers.
* **Spawning**: Balls spawn sequentially at the top-center at 0.15s intervals to prevent overlapping impulse explosions.
* **Lid Overflow Penalty**: If a drawer becomes physically overfilled and a ball maintains continuous contact with the top lid sensor for 5.0 seconds, it is penalized and moved to the **Battle Discard Pile**.
* **Permanent Discard**: Defeated units and discarded items remain in the Discard Pile permanently for the remainder of the battle. There is no automatic reshuffle.

## 6.10 Battle Pool Scoping & Dynamic Scaling Passives
Passives that scale based on duplicate copies (*Twin Charm*, *Doppleganger*, *Echoing Orb*) evaluate against the total count of matching entities across the entire team's **Battle Pool** (Lineup, Bench, Gacha Drawers, and Discard Pile):
* Drawing a unit, moving a unit between bench and lineup, or a unit dying does not change the total copies in the battle pool.
* Merging two duplicate units into a higher-level unit reduces total copies of that unit definition by 1. A Level 2 or Level 3 unit counts strictly as 1 copy.
* Stat bonuses granted by scaling passives are only active on units currently deployed on the board (lineup and bench); units inside gacha machine drawers hold 0 bonus until drawn onto the board.

## 6.11 Universal Discard Pile & Gacha Machine Arrival Rules
* **Identical Arc Animation**: All player units and items entering the Battle Discard Pile travel along a 500px parabolic capsule arc directly into the Discard Pile button, accompanied by sound and button scale bump.
* **Player Unit Death**: When a player unit reaches 0 HP, its board puppet view plays its death fade animation, followed by its GachaBall capsule flying along the arc into the Discard Pile button. Equipped items follow sequentially along the exact same arc.
* **Enemy Units Do NOT Discard**: When an enemy unit dies, it dissolves and is removed; no capsule arc spawns and the Discard Pile counter is untouched.
* **Gacha Machine Arrivals**: Units and items entering Gacha Machine drawers (such as *Echoing Orb* death duplication or *Potion of Plunder* item stripping) animate along a parabolic arc directly into the matching tier machine, updating the machine's counter badge upon impact.

---

# 7. Universal Visual Feedback & Clarity Rules

The presentation system enforces a strict Visual Clarity Contract: the player must always clearly understand which entity is granting a buff or inflicting a penalty:

```
[External Buff]    Source (Unit / Trinket) ──(Flying Projectile)──► Target Unit
[Self / Item Buff] Unit Holder ──(Parabolic Arc Projectile)──► Lands on Self
[Debuff / Loss]     Unit ──(Instant Floating Text: Red for HP, Black for Power)
```

1. **Directional Buff Projectiles (External Buffs)**:
   * When a buff originates from another unit or an equipped trinket on the HUD, a directional projectile launches from the source entity to the target unit.
   * On impact, the target unit plays impact feedback and spawns green floating text (`+X HP`) or blue floating text (`+X PWR`).
2. **Parabolic Self-Cast Projectiles (Self-Buffs & Item Buffs)**:
   * When a unit buffs itself, or when an equipped item grants stats to its holder, a projectile launches upward from the unit and arcs back down onto itself.
   * Items never hold live stats or buff themselves; an item's passive stats and abilities always target the holding unit.
3. **Debuff Visual Standards**:
   * Stat reductions (debuffs, item unequip losses, negative stat deltas) do not fire flying projectiles.
   * The unit immediately displays floating debuff text: **Red** for Health reduction (`-X HP`) and **Black** for Power reduction (`-X PWR`).

---

# 8. Combat Resolution & Simulation Rules

Combat resolves automatically once the player clicks **"Battle!"**:

## 8.1 Absolute Determinism
* Damage dealt equals the attacker's Power minus the defender's Armor (minimum 0 damage):
  `Damage = Attacker Power - Defender Armor (minimum 0)`
* Spikes damage reflects directly back to the attacker when hit by a direct melee attack, and is mitigated by the attacker's Armor.
* There are no critical hits, random dodges, or percentage-based damage rolls.

## 8.2 Action Order & Initiative
* **Player Initiative**: The player team initiates attacks before the enemy team.
* **Directional Order**: Units act strictly from front (Slot 0) to back (Slot 4).
* **Targeting**: Units attack the enemy in the mirrored slot; if that slot is empty, they target the frontmost active enemy.
* **0 Power Units**: Units with 0 Power still perform their attack animation to ensure consistent visual pacing, but deal 0 damage.

## 8.3 Reaction Priority Hierarchy
When multiple abilities trigger simultaneously, they resolve in an orderly hierarchy:
1. **Execution Priority Layers**:
   * **Interceptors (Priority 300)**: Damage redirects and shields that resolve *before* damage applies (e.g. Guardian leaps).
   * **Duplication (Priority 220)**: Post-death clone generation (*Doppleganger*).
   * **Trinket Summons / Resurrections (Priority 210)**: High-priority trinket triggers (*Soul Echo*).
   * **Unit On-Death Summons (Priority 205)**: Innate unit death spawns.
   * **Item On-Death Summons (Priority 200)**: Equipped item death spawns (*Summoning Scroll*).
   * **Standard Reactions (Priority 100–199)**: Buffs, heals, and aura distributions.
   * **Modifiers (Priority 50)**: Counter-attacks and defensive status adjustments (*Retaliate*).
   * **Default Attacks / Passives (Priority 0)**: Standard turn actions.
   * **Delayed Reinforcements (Priority < 0)**: Boss reinforcements and extra turns.
2. **Category Tie-Breaker**: When priorities are equal: **Units -> Items -> Trinkets**.
3. **Visual Direction Tie-Breaker**: Priority and category ties resolve visually Left-to-Right on screen (Player team evaluates Slot 4 down to Slot 0; Enemy team evaluates Slot 0 up to Slot 4).

## 8.4 Summon Priority & Board Space Reservation
When multiple summons occur simultaneously on unit death:
1. **Trinket Resurrections (Priority 210)** claim the original dying unit's slot first.
2. **Unit Summons (Priority 205)** search for alternative free slots in the lineup (searching Back-to-Front).
3. **Item Summons (Priority 200)** claim remaining lineup slots; if the lineup is full, summons route to the Discard Pile (for players). If no slots or discard space remain, the summon is cancelled.

## 8.5 Unit Transformation Rules (Mimic & Mirror Image)
* **Trigger Timing**: Evaluates immediately before Mimic takes its attack action when its turn arrives in initiative order.
* **Target Resolution**: Mimic targets the mirrored opposing lineup slot (Mirror Slot = 4 - Current Slot). The target must be a valid standard unit (Tier 1–3); Mimic cannot transform into Heroes or Bosses. If the mirror slot is empty or invalid, Mimic executes a standard basic attack instead.
* **Inheritance & Item Transfer**: Items equipped on Mimic transfer seamlessly to the transformed unit. Permanent training upgrades and active in-combat buffs are inherited. Conditional trinket buffs evaluate fresh upon board entry.
* **Single-Action Turn Invariant**: The transformed unit immediately continues the active turn for that slot and attacks. It is never enqueued a second time, guaranteeing that each board slot takes at most one action per round.

## 8.6 Causality & Deferred Deaths
Events resolve in strict causal order:
`Attack Damage -> When Hurt Reactions (Heal / Buff) -> Death -> On-Death Reactions (Summon / Stat Transfer)`

When a unit reaches 0 HP, pending hurt reactions resolve first. Once all pending effects clear, the unit is marked defeated, on-death abilities trigger, and the unit is removed to the Discard Pile.

## 8.7 Battlefield Slots
Special slots placed on the battlefield grid apply persistent effects:
* **Burn Slot**: Applies 1 stack of Burn to the unit standing on it at turn start. Burn stacks on units in this slot do not decay.
* **Lightning Slot**: Applies 1 stack of Static to the unit standing on it at turn start.

## 8.8 Detailed Status Effects
* **Burn**: Deals damage equal to active stacks at turn end. **Burn damage ignores armor.** Stacks decay by 50% (rounded down) at turn end (except in Burn Slots).
* **Armor**: Absorbs incoming direct attack damage (1 point of Armor blocks 1 damage point). Does not block Burn damage. Decays to 0 at turn end unless preserved by abilities or trinkets (*Polished Plate*).
* **Spikes**: Deals damage back to the attacker equal to the amount of stacks when hit by a direct attack. Loses 1 stack per activation. Mitigated by Armor.
* **Static**: When this unit dies, it deals collateral damage equal to its Static stacks to living adjacent lineup allies, mitigated by Armor. Stacks decay by 1 at the end of each turn.

## 8.9 Semantic Action Typing in the Combat Engine
Units do not have a maximum health cap; they possess base starting stats and live in-combat stats. Every stat alteration is strictly classified:

| Action Category | Affected Stats | Reaction Trigger Fired | Interaction with Armor & Spikes | Gameplay Rule & Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Healing (`HEAL`)** | Health (HP) | When Healed | None | Restorative recovery (potions, lifesteal). Strictly triggers "When Healed" reactions. **Never** counts as a stat buff and never triggers "When a Stat Increases". |
| **Stat Buffs (`BUFF`)** | Health, Power | When a Stat Increases | None | Stat empowerment, level scaling, and death bonuses. Strictly triggers "When a Stat Increases". **Never** counts as healing and never triggers "When Healed". |
| **Attack Damage (`DAMAGE`)** | Health (HP) | When Hurt by an Attack, On Damage Dealt | Mitigated by Armor; Melee triggers Spikes | Direct combat strikes. Mitigated by Armor. Melee attacks trigger counter-damage from Spikes. Triggers "When Hurt by an Attack" on victim and "On Damage Dealt" on attacker. |
| **Stat Debuffs (`DEBUFF`)** | Health, Power | When a Stat Decreases | Bypasses Armor & Spikes | Direct stat penalties. Reduces Health or Power directly, bypasses Armor, ignores Spikes, and never triggers "When Hurt by an Attack". |

### Damage Origins & Defensive Rules
* **Melee Attacks**: Mitigated by Armor; triggers Spikes counter-damage; triggers counter-attacks; triggers hurt reactions; triggers "On Damage Dealt".
* **Ranged Attacks**: Mitigated by Armor; does **not** trigger Spikes; triggers counter-attacks; triggers hurt reactions; triggers "On Damage Dealt".
* **Trinket Damage**: Mitigated by Armor; does not trigger Spikes; cannot trigger counter-attacks against the trinket; triggers hurt reactions; does not trigger "On Damage Dealt".
* **Kamikaze Damage**: Mitigated by Armor; does not trigger Spikes; cannot trigger counter-attacks (attacker is already dead); triggers hurt reactions; does not trigger "On Damage Dealt".
* **Burn & Static Damage**: Completely bypasses Armor; does not trigger Spikes; does not trigger attack-reactive abilities.

## 8.10 Buff Echo Behavior (Shadow Cloner)
* Activates whenever an adjacent ally's stat increases in combat ("When a Stat Increases").
* Copies temporary in-combat stat buffs only; permanent base upgrades (such as Dojo training) are never copied.
* When repeating Health bonuses, Buff Echo delivers them strictly as a Health Buff (never as Healing), preventing unintended healing feedback loops.

---

# 9. Traits & Trinkets

Units carry traits across three taxonomy categories:
- **Elemental Traits (4)**: Fire, Earth, Water, Air (tracked via elemental Soul counts: Tier 1 = 1, Tier 2 = 2, Tier 3 = 4).
- **Class Traits (4)**: Tank, Fighter, Support, Specialist (tracked via lineup unit count).
- **Visual Archetype Traits (7)**: Food, Mecha, Animal, Plant, Toy, Appliance, Costume (tracked via lineup unit count).

Equipping the corresponding Trait Trinket enables team-wide synergies for both player and enemy lineups.

## 9.1 Snapshot Locking
At the start of combat and each turn, active traits and souls in the lineup are snapshotted. Trait synergy strength is locked for the duration of that combat round, preventing mid-combat fluctuations as units take damage, die, or are summoned.

## 9.2 Trait Synergies & Thresholds

### Elemental Traits (Souls)
Activated when the team holds the required elemental soul count and equips that element's trait trinket. Opening effects trigger once at combat start (when the Battle button is clicked, before turns begin):
* **Fire (3 / 5 / 7 / 9 Souls)**: Applies Burn on attack. At 7+ souls, applies 2 Burn to the entire opposing team at combat start.
* **Earth (3 / 5 / 7 / 9 Souls)**: Grants Armor (3, 5, 7, 9) and Spikes (7, 9) to allies at combat start. Earth units gain double armor bonus.
* **Water (2 / 4 / 6 / 8 Souls)**: Water units heal adjacent allies 1 HP at combat start.
* **Air (2 / 4 / 6 / 8 Souls)**: Air units steal 1 Power from mirrored enemy slots at combat start.

### Class & Visual Traits (Units)
Activated when the team holds the required count of units possessing that trait in their lineup and equips that trait's trinket. All 11 Class and Visual trait trinkets trigger at the start of combat:
* **Class Traits (Tank, Fighter, Support, Specialist - 2 / 3 / 4 / 5 Units)**: Grants +1 Power (2 units), +2 Power (3 units), +3 Power (4 units), +4 Power (5 units) to matching trait units at combat start.
* **Visual Traits (Food, Mecha, Animal, Plant, Toy, Appliance, Costume - 2 / 3 / 4 / 5 Units)**: Grants +1 Power (2 units), +2 Power (3 units), +3 Power (4 units), +4 Power (5 units) to matching trait units at combat start.

## 9.3 Key Trinket Rules
* **Pre-Combat Timing**: All 15 Trait Trinkets activate strictly during the opening Pre-Combat phase when the Battle button is pressed, not during the management phase. Available to both player and enemy teams.
* **Insignia Trinkets (*Novice Insignia* & *Veteran Insignia*)**:
  * *Novice Insignia* grants +1 HP and +1 Power to any Level 1 unit entering the board.
  * *Veteran Insignia* grants +1 HP and +1 Power to any Level 2 unit entering the board or leveling up.
  * Expiration debuffs (`-1 HP`, `-1 PWR`) visibly pop when an existing unit advances to a higher level that no longer qualifies for that insignia.
* **Conditional Equipment Trinkets (*Rusty Ring*)**:
  * Grants +1 HP and +1 Power to all units holding no equipment. Equipping an item cancels this buff; losing an equipped item restores it.
* **Armor Preservation (*Polished Plate*)**: Armor does not decay at the end of the turn.
* **Death Refund (*Token Return Charm*)**: The death of the first non-Hero player unit each round refunds tokens equal to the unit's tier (Tier 1 = 1, Tier 2 = 2, Tier 3 = 3). Limited to once per round.
* **Draw Discount (*Bargain Charm*)**: Reduces the token cost of the first gacha draw of each tier per battle by 1 token (minimum 1 token cost).

---

# 10. Run Progression, Node Logic & Encounters

## 10.1 Encounter Scaling & Scheduling
* **Daily Budget Formula**: Base enemy budget scales linearly by Day:
  `Budget = 3 + (Day - 1)`
* **Elites & Bosses**: Mini-boss and Boss units are free; support units consume 85% of the daily budget. Boss reinforcements consume 33% of the daily budget.
* **Path Choice Priorities**:
  * **Regular Battles**: Dominant appearance priority (~96%–98% of 3-path choices).
  * **Elite Battles**: Paced by progress toward the upcoming Boss (guaranteed at 20%, 40%, 60%, and 80% card unlock milestones; capped at 4 elite encounters per boss tier, max 20 per run).
  * **Non-Battle Encounters**: Shop, Merge Encounter, Black Market, Surprise Events, and Unit Training Ground share equal base weights with anti-starvation weight bonuses when not offered.

## 10.2 Standard Nodes
* **Regular Battles**: Standard budget-based combat encounters.
* **Shop Node**:
  * Offers 3 random GachaBalls from the unlocked pool.
  * Undiscovered merge recipes for the current run highlight in Violet.
  * **Reroll Cost**: Starts at **1 Gold**, increases by **+1 Gold** per reroll in that visit, and resets to 1 Gold on the next visit.
* **Black Market Node**:
  * **Remove**: Permanently purges a GachaBall from the run deck (starts at 5 Gold, increases by +1 Gold per removal across the run).
  * **Transform**: Replaces a GachaBall with a random alternative of the same tier for a flat fee of **5 Gold**.
* **Post-Battle Rewards**:
  * Displays 5 reward capsules.
  * **Collect**: Adds the capsule to the Run Inventory for free.
  * **Sell**: Sells the capsule for Gold (standard items sell for tier value; Elite rewards sell for a flat **10 Gold**).
  * **Auto-Collection**: Leaving the scene with uncollected items automatically collects all remaining prizes.
  * Gacha Machines remain interactive in the reward room for spending tokens earned during Study sessions; unspent tokens clear upon leaving.

## 10.3 Standalone Encounters
* **Unit Training Ground (Dojo)**:
  * Permanently trains the stats of any unit in the Run Inventory.
  * Pay 5 Gold to start a Flashcard Study session; tokens earned during study are spent to roll for permanent stat increases for that unit.
* **Merge Encounter**:
  * Allows merging GachaBalls in the Run Inventory directly for a flat fee of **5 Gold**.
  * Bypasses standard run-level recipe unlock requirements, permanently unlocking the resulting recipe for the rest of the run.

## 10.4 Surprise Events
Randomly selects from resource sites:
* **Rest Site**: Spend tokens to draw permanent Hero HP buff capsules.
* **Gambling Den**: Spend tokens to draw Gold bonus capsules.
* **Training Grounds**: Spend tokens to draw permanent Hero Power buff capsules.
* **Reward Distribution**: Token draws follow a middle-weighted distribution (Tier 1 awards 0–2, Tier 2 awards 0–3, Tier 3 awards 0–5). Activating a study session costs a flat fee of **5 Gold**.

---

# 11. UI/UX Hierarchy, Inspection & Playback Rules

## 11.1 Inspection System
* **Display-Only Windows**: Inspection windows are display-only and do not intercept pointer clicks to underlying elements.
* **Automatic Child Layout**: Opening an inspection automatically displays all related child detail windows (keywords, status effects, equipped items) in a column arranged away from the source entity without overlapping it, clamped to the screen.
* **Peek Lifecycle (Outside Combat)**:
  * Mouse Hover opens after `0.4s` dwell; closes immediately on cursor exit.
  * Mouse / Touch Long-Press opens after `0.5s` hold; closes immediately on release.
  * Quick click/tap (< 0.5s) selects the entity only and suppresses hover peek re-arming on that element until the cursor exits.
* **Combat Click-to-Pin**: During Combat animations, clicking an inspectable entity immediately freezes combat playback and pins its inspection window open. Clicking another inspectable entity switches inspection; clicking empty space resumes playback.
* **Stat Display Cap for Readability**: HP and Power values on unit cards are visually capped at **99** to preserve clean typography and UI layout. Mathematical calculations in the combat engine continue scaling beyond this cap behind the scenes without restriction.

## 11.2 Playback Controls & Speed Scaling
* **Supported Presets**: Combat playback provides `1x`, `2x`, and `4x` speed options, alongside a `Pause` (`⏸`) toggle.
* **In-Battle Exclusivity**: Speed acceleration (2x, 4x) applies strictly inside battle encounters. Non-combat scenes, shops, rest sites, minigames, and map navigation always operate at normal 1.0x baseline speed.
* **Speed Persistence**: The selected combat speed setting persists across all battles for the entire run.
* **Multi-Stat Buff Projectile Staggering**: When an ability or trinket grants multiple stats (e.g. +1 HP and +1 Power) to the same target unit, the HP projectile launches first, followed by the Power projectile after a 0.15s delay (scaled by combat speed), ensuring numbers do not visually collide.

---

# 12. Player Choices by Game Context & Replay Contract

A deterministic replay must reproduce the same accepted gameplay choices, resulting game state, and input flow:

## 12.1 Title Screen
The player can:
* Start a new run (proceeds to Loadout).
* Continue a saved run (resumes checkpointed run state).
* Open Options (language, volume, card pronunciation settings).
* Open Replays and use spectator controls (pause, speed controls, exit).
* Exit the game.

## 12.2 Loadout Selection
The player can:
* Browse and select a Hero and a Deck.
* Choose deck order (Regular, Inverted, Random) and deck size (Full, Half).
* In test mode, add starting items or trinkets.
* Start the run.

## 12.3 Run Inventory & Inspection
Outside battle, the player can:
* Open or close the persistent Run Inventory from the machine area or room controls.
* Inspect GachaBalls, units, items, trinkets, traits, and status effects.
* Drag a GachaBall to an empty legal slot to move it, or onto another GachaBall to request a swap or a valid merge.
* Use valid consumables on eligible units when room rules permit.

## 12.4 Map Navigation
The player can select one of the currently available path nodes to transition to that encounter.

## 12.5 Non-Battle Rooms
* **Shop**: Inspect stock; buy an offered GachaBall; reroll stock for the displayed gold cost; open/close inventory; leave for the map.
* **Reward Room**: Start the study session; draw rewards by tier using tokens; collect or sell capsules; open/close inventory; leave.
* **Elite Reward**: Inspect offered trinkets; claim a selected trinket; return to the map.
* **Rest Site**: Start the study session; draw stat capsules; apply prizes to the Hero; open/close inventory; leave.
* **Merge Encounter**: Open inventory; select two eligible GachaBalls; confirm permanent merge or swap; leave.
* **Unit Training Ground**: Open inventory; select a unit and training stat (HP or Power); pay gold to start study; spend tokens to roll stat buffs; close popup; leave.
* **Black Market**: Open inventory; select a GachaBall; remove or transform it for the displayed gold fee; leave.

## 12.6 Flashcard Minigame Prompts
* Review newly introduced cards and select priority review cards when prompted.
* Submit an answer choice for the displayed question.
* Skip the displayed question.

## 12.7 Battle Phases
* **Turn-Start Flashcard**: Answer or skip questions until timer expiry or completion.
* **Management Phase**: Draw from tiered Gacha Machines using tokens; reposition units between lineup and bench; equip, replace, or use items; merge units; inspect board states, drawers, and discard piles; toggle pause or change speed; click "Battle!" to end management.
* **Combat & Resolution Phases**: Combat resolves automatically. The player can pause playback, inspect entities on screen, or change playback speed. Board editing and draws are locked.
* **Battle Results**: Acknowledge Victory (transitions to Rewards) or Defeat (returns to Title Screen).

## 12.8 Replay Fidelity Contract
Replay playback reproduces the initial seed, loadout configuration, accepted player choices, room transitions, battle outcomes, and discrete inspection states. Replay operates through the identical validated command pipeline, ensuring 100% mathematical and behavioral parity.

---

*For technical architecture, class structures, and data domain specifications, see [Flashcard Heroes TDD.md](Flashcard%20Heroes%20TDD%20(Technichal%20Design%20Document)%20V9.0.md). For dedicated complex subsystem specifications, see [CombatSystem.md](CombatSystem.md), [InventoryManager.md](InventoryManager.md), [FlashcardSystem.md](FlashcardSystem.md), [EncounterSystem.md](EncounterSystem.md), and [UIInteraction.md](UIInteraction.md).*
