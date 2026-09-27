# Flashcard Heroes - Game Rules & Expected Behaviors

> [!IMPORTANT]
> **Authority & Scope:**
> This document is the authoritative **Single Source of Truth (SSOT)** for all gameplay rules, player-facing mechanics, interaction models, economic systems, and expected behavioral contracts across *Flashcard Heroes*.
> 
> **Natural Language Standard (Non-Technical):**
> This is a game rules and behavioral design document, written in clear, natural language so that non-programmers (designers, QA testers, writers, and producers) can easily read and understand every system. All AI agents and human contributors must preserve this standard:
> * Describe mechanics in terms of player-facing concepts, rules, triggers, and concrete game interactions rather than code syntax.
> * **Do NOT** include code snippets, internal class names, function signatures (e.g., `apply_stat_delta()`), variable names, or technical engine jargon in this document.
> * All technical architecture, class structures, engineering patterns, and data pipelines belong strictly in dedicated technical documents such as [CombatSystem.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/CombatSystem.md), [InventoryManager.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/InventoryManager.md), [EncounterSystem.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/EncounterSystem.md), and the [TDD V9.0](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/Flashcard%20Heroes%20TDD%20(Technichal%20Design%20Document)%20V9.0.md).


---

# 1. Core Philosophy & Design Pillars

1. **Design by Synthesis:**
   Every entity in the game (Units, Items, Trinkets) is a legible synthesis of clear attributes: Tier, Element, and Role. Upgrades and merges follow deterministic rules rather than arbitrary branching.
2. **Total Information Transparency:**
   The player is never kept in the dark. All active board states, enemy abilities, machine draw probabilities, remaining pool contents, status effects, and discard piles are fully inspectable at all times.
3. **Strict Determinism:**
   Combat resolves with zero hidden random rolls. There are no critical hits, random dodges, or percentage-based damage variance. Outcomes are the exact mathematical consequence of team composition, stats, item synergies, and reaction priorities.
4. **Decoupled Truth & Visual Clarity:**
   Underlying state mutations resolve instantly and atomically in the data layer. The presentation layer is responsible for clearly communicating every cause and effect to the player through distinct visual trajectories and feedback before the next interaction can begin.

---

# 2. Win & Loss Conditions

## 2.1 Winning a Run
A run is successfully completed when the player navigates through the map and defeats the **Final Boss**, with the Hero's health remaining above 0.

## 2.2 Losing a Run (Permadeath)
A run is lost immediately if the **Hero's health (HP) reaches zero**.
* **Permadeath**: Upon victory or defeat, the run's save state is permanently deleted, and the run ends immediately.
* **Hero Unit Rules**:
  * The Hero participates directly on the active battle board alongside standard units and behaves as a combatant (subject to damage, healing, buffs, and attacking).
  * **Board Restriction**: The Hero can only exist in the active `PlayerLineup` container and **cannot** be moved to the bench or inventory.
  * **Item Slot**: Like all other units, the Hero possesses strictly **one item slot**.
  * **Starter Hero Passive (*Soul Harvest*)**: Whenever an ally dies in battle, the Starter Hero absorbs their power to gain Health equal to half of the fallen ally's current in-combat Power rounded down, with a guaranteed minimum of at least 1 Health gained ($\text{HP Gain} = \max(1, \lfloor \text{dying\_unit.current\_pwr} / 2 \rfloor)$). This calculation queries the ally's live dynamic combat Power at the moment of death (including all active buffs, equipment bonuses, and level scaling) rather than its default base stats, and is delivered strictly as a stat Buff (`on_stat_increased`).

---

# 3. Run Structure & Progression

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
 [Boss Milestones] (Dynamic Flashcard Mastery & Day Milestones)
       │
       ▼
  [Final Boss] ──► [Victory!]
```

## 3.1 Loadout Selection Scene
Before starting a run (or a test session), the player configures their starting setup:
* **Hero & Deck Carousels**: Selection carousels allow choosing a starting Hero and Flashcard Deck. Both carousels feature a 3-item layout (previous item, currently selected item scaled up, next item) with navigation arrows.
* **Simultaneous Detail Panels**: Clicking or centering a carousel item updates dedicated, persistent information panels for the Hero (base HP/PWR, detailed descriptions, traits, flavor text) and the Deck (card counts and descriptions).
* **Deck Ordering**:
  * `REGULAR`: Reviews cards in their standard database order.
  * `INVERTED`: Reviews cards in reverse database order.
  * `RANDOM`: Shuffles cards deterministically using `RNGManager.map_rng.shuffle(...)`.
* **Deck Sorting**: Available decks prioritize the introductory deck (`Katakana Main`) at the top of the selection list.
* **Test Mode Starters Option**: In Test Mode, a debug dropdown utility allows developers to selectively grant starting Gacha items or trinkets directly from the registry into the Hero's starting loadout.
* **Dynamic Localization Updates**: Swapping system language re-translates metadata in place while preserving active carousel selections.
* **Audio Integration**: Plays the dedicated loadout background music (`bgm/loadout.ogg`) upon entry.

## 3.2 State Lifecycles

### Run-Persistent State (Preserved Between Nodes)
* Hero and unit base stats (HP, PWR, Level, Rarity, permanent stat components).
* Gold.
* Run Inventory (the player's permanent collection of units and items).
* Equipped Trinkets.
* Flashcard deck mastery levels and reviewed card history.

### Battle-Temporary State (Reset After Each Battle)
* Gacha Tokens (reset to 0 after battle).
* Temporary in-combat stat modifications and status effects.
* Battle Inventory (the active draw pools inside the tier machines).
* Battle Discard Pile (all defeated units and discarded items).
* Battle lineup and bench formation.

---

# 4. Core Resource Economy & Gacha Pools

The game operates on a dual-economy system that separates long-term strategy from tactical in-battle execution:

## 4.1 Gold (Run Economy)
* **Purpose**: Spent outside of combat to purchase units/items from Shops, purge or transform units at the Black Market, buy training rolls at the Dojo, and heal/upgrade at Rest Sites.
* **Acquisition**: Earned by winning battles or selling reward capsules.
* **Difficulty Role**: The player's accumulated Gold and inventory size inform the difficulty engine's budget when generating enemy encounters.
* **Tier Gold Costs (Shop & Encounter Generator)**:
  * **Tier 1**: $\text{Base } 1 \text{ Gold} \times 2^{(\text{Level}-1)}$
  * **Tier 2**: $\text{Base } 2 \text{ Gold} \times 2^{(\text{Level}-1)}$
  * **Tier 3**: $\text{Base } 4 \text{ Gold} \times 2^{(\text{Level}-1)}$

## 4.2 Gacha Tokens (Battle Economy)
* **Purpose**: Spent during the Management Phase of battles and reward nodes to draw GachaBalls from Tier 1, 2, or 3 machines.
* **Acquisition**: Earned exclusively by answering questions correctly during the Flashcard mini-game.
* **Banking & Reset**: Tokens can be banked between turns within the same battle, but reset to zero once the battle concludes.
* **Tier Draw Costs (Tokens)**:
  * **Tier 1 Machine**: $1 \text{ Token}$
  * **Tier 2 Machine**: $2 \text{ Tokens}$
  * **Tier 3 Machine**: $3 \text{ Tokens}$

## 4.3 The Strategic Duality: Swarming vs. Slot Power
* **Swarming (Tier 1 Focus)**: Tier 1 units are cheap to draw in battle (costing only $1 \text{ Token}$) but have modest base stats. Merging duplicate Tier 1 units permanently upgrades their level, which doubles their Gold value in shops ($1 \times 2^{\text{Level}-1}$), while their Gacha Token draw cost remains strictly $1 \text{ Token}$. This yields extraordinary deployment efficiency.
* **Slot Power (Tier 2 & Tier 3 Focus)**: Higher-tier units cost more Gacha Tokens to draw (2 or 3 Tokens) but provide concentrated slot efficiency, higher base stat packages, and multiplicative abilities.
* **Exhaustion Risk**: Because defeated units and replaced items are placed in the Discard Pile permanently for the remainder of a battle, an ultra-lean deck can run out of GachaBalls during prolonged encounters, resulting in defeat. Players must balance deck predictability (small decks) against raw endurance (larger decks).

---

# 5. Flashcard Resource Engine (Spaced Repetition System)

The Spaced Repetition System (SRS) powers tactical resource generation:

## 5.1 In-Battle Mini-Game Mechanics
* **Timed Mini-Game**: A fast-paced timed mini-game at the start of each turn.
* **Correct Answer**: Awards $+1\text{ Token}$, $+1\text{ Card Mastery}$, $+0.5\text{s Timer Extension}$, increments the consecutive correct answer streak, and triggers escalating sound pitch and visual effects.
* **Incorrect Answer**: Awards $0\text{ Tokens}$, $-1\text{ Card Mastery}$, resets the streak to $0$, and resets the BGM pitch to $1.0$.
* **Skip**: Awards $0\text{ Tokens}$, $-1\text{ Card Mastery}$, $+0.5\text{s Timer Extension}$, but **preserves** the active consecutive correct answer streak and audio pitch without penalty.
* **SRS Selection Algorithm**:
  * Questions are chosen using weighted selection based on three priorities:
    1. *Mastery Level (High)*: $\text{Weight} = (6 - \text{mastery\_level})^2$
    2. *Recency (Medium)*: $\text{Weight} = (\text{current\_day} - \text{last\_review\_day}) \times 1.0$
    3. *Randomizer (Low)*: $\text{randf}() \times 0.1$
  * Lower mastery cards are prioritized; the same card **never** appears twice in a row.

## 5.2 Rest Site Flashcard Mechanics
* **Correct Answer**: Earns Rest Site Tokens that can be spent at Rest Site machines for permanent Hero base stat increases.
* **Incorrect / Skip**: Awards $0\text{ Tokens}$. Tokens exist only within the active rest site and reset upon departure.

## 5.3 Streak & Juice Escalation

### Audio & BGM Scaling
* **SFX Pitch**: The `minigame_correct` sound effect pitch increases by `+0.05` per streak level, capping at a pitch multiplier of `1.5x` at streak 10+.
* **BGM Pitch**: The active `BGM_MINIGAME` track pitch/tempo dynamically scales upwards by `+0.02` per streak level, capping at `1.2x` at streak 10+. Incorrect answers smoothly reset BGM pitch to `1.0`.

### Visual Edge Fire Aura & Particle Scaling
* **Visual Edge Fire Aura (`MinigameAuraVFX`)**: A custom fire aura frames the outer borders of the minigame window using four edge particle emitters:
  * Particle emission count, velocity, and spread scale up linearly with each correct answer in the active streak.
  * Border fire changes colors based on the streak tier:
    * **Streak 1–2**: Cyan
    * **Streak 3–5**: Purple
    * **Streak 6–8**: Gold
    * **Streak 9+**: Magenta
  * Renders behind the parent panel (`show_behind_parent = true`) to maintain text legibility.
* **Token Pop & Spin**: Correct answer currency pop-up animations scale their particle amount, size, and spin velocity with the current streak tier.

## 5.4 Mid-Mini Game Flashcard Unlock (3-Streak Progression)

During active mini game play, consecutive correct answers can unlock additional cards from the deck pool mid-session:

* **Trigger Condition**: Achieving a **3-question consecutive correct answer streak** during an active mini game session.
  * **Session Limit**: Can trigger **strictly once per mini game session**. Subsequent 3-streaks within the same session will not trigger another unlock.
  * **Pool Requirement**: Requires locked cards remaining in the run's deck pool (`ordered_deck_pool`). If all cards in the deck are already unlocked, reaching a 3-streak triggers no unlock or timer bonus.
* **Immediate Presentation Contract**:
  * The next locked card from `ordered_deck_pool` is unlocked and appended to `active_deck_ids`.
  * The newly unlocked card is **queued immediately as the very next question displayed** in the current mini game.
* **Timer & Resource Rules**:
  * **+1.0s Timer Extension**: Awards an immediate $+1.0\text{s}$ bonus time extension directly to `session_timer` (in addition to the standard $+0.5\text{s}$ for a correct answer, yielding $+1.5\text{s}$ on the triggering question).
  * **Standard Token Yield**: Answering the triggering question awards standard tokens (no additional tokens are awarded for the unlock itself).
* **Audio-Visual Feedback**:
  * **Celebratory Fireworks (`FireworksCelebrationVFX`)**: Triggers staggered multi-point radial particle explosions with additive blending across the top, sides, and center of the mini game window.
  * **Golden Window Shimmer**: The main mini game panel flashes in radiant gold (`Color(1.8, 1.6, 0.7)`) before smoothly settling to the unlocked card's mastery color.
  * **Timer Bar Flash & White Buff Pop**: The timer bar flashes bright white (`Color.WHITE`) with a 0.4s fade, while a glowing white `+1.0s` buff popup bounces elastically over the timer label, floats upward, and the timer label pops to $1.35\times$ scale.
  * **Celebration Banner**: An animated floating banner (`★ NEW CARD UNLOCKED! ★` / `+1.0s TIME BONUS!`) pops over the main panel with elastic overshoot and floats upward without blocking gameplay input.
  * **Audio & Screen Shake**: Plays a triumphant chime (`ui_merge`) and triggers screen shake ($0.2\text{s}$).
* **Deck Synchronization Contract**:
  * The mid-mini game unlocked card is marked as already presented (`cards_presented_count` increments in sync with `active_deck_ids`).
  * At the start of subsequent mini games, the start-of-game review popup introduces the next locked card in the deck pool, resulting in up to 2 cards unlocked per mini game encounter (1 at the start review popup + 1 mid-mini game).

---

# 6. Battle Structure & Flow

Battles resolve in a structured, four-phase turn loop:

```
[Start of Turn] ──► [Management Phase] ──► [Combat Phase] ──► [End of Turn]
       ▲                                                              │
       └──────────────── Next Turn (if no victory/defeat) ─────────────┘
```

1. **Start of Turn**:
   * **Flashcard Mini-Game**: The player plays the timed Flashcard mini-game to earn Gacha Tokens.
   * **Turn 1 Enemy Entrance**: On Turn 1, enemy units do not appear on the battlefield until the Flashcard mini-game is finished. Once the player acknowledges their mini-game results, enemy units enter the board sequentially, starting from the backline down to the frontline. Each entering enemy unit displays its entrance animation, activates any board-entry effects (such as trinket buffs or stat scaling), and equips its items one by one before the phase transitions.
   * **DOT Application**: Burn damage ticks first, ignoring Armor (from Turn 2 onward).
   * **Slot Actions**: Turn-start slot effects resolve (Burn Slot and Lightning Slot actions).
   * **Abilities & Traits**: Turn-start passive abilities, traits, and status effects resolve.
   * **First-Turn Suppression**: To allow players to draw and establish their lineup before taking damage, all start-of-turn hostile abilities, slot actions, and trait triggers are suppressed on Turn 1, activating normally from Turn 2 onward.
2. **Management Phase**:
   * The player makes tactical choices: spending Gacha Tokens to draw units/items onto the bench, arranging formations, equipping items, using consumables, or merging units on the bench or board.
3. **Combat Phase**:
   * Units execute combat actions automatically, sequentially, and deterministically according to the priority hierarchy.
4. **End of Turn**:
   * End-of-turn abilities and cleanup steps process. If neither team has won, the loop advances to the next turn.

---

# 7. Management Phase Verbs & Interaction Rules

During the Management Phase, the player may perform the following distinct actions:

## 7.1 Interaction Models & Controls
* **Mouse (Desktop)**: Drag-and-Drop, Single-Click Select, Hover-to-Peek.
* **Touch (Mobile)**: Tap-to-Select, Long-Press-to-Peek (`0.32s`).
* **Platform Specifics**: The "Exit Game" button closes the application on desktop platforms; fullscreen toggles are platform-dependent and hidden on mobile devices.
* **Audio & Accessibility Options**: Volume sliders for Master, Music, and SFX, plus a toggle for Card Pronunciation (silencing native voice audio during flashcards when disabled).

## 7.2 Drag-and-Drop Intent Priority
When dropping an entity onto another or onto a slot, player intent is resolved in strict priority:
1. **Merge**: If a valid `MergeRecipe` exists between the two entities, opens the `ChoiceWindow` preview (Merge / Swap).
2. **Equip / Replace**: Dropping an item on a unit equips it into the unit's single item slot (if already holding an item, replaces it and sends the old item directly to the Discard Pile).
3. **Use**: Dropping a consumable on a unit triggers its effect immediately.
4. **Move / Swap**: Positions are swapped if legally allowed by container rules.

## 7.3 Draw
* Spend Gacha Tokens on Tier 1 (1 Token), Tier 2 (2 Tokens), or Tier 3 (3 Tokens) machines.
* Drawn GachaBalls land in the first empty slot of the `PlayerBench`.
* **Overflow**: If the `PlayerBench` is completely full when a draw occurs, the drawn ball is sent directly to the **Battle Discard Pile**.
* **Empty Machine Rule**: If a tier machine's pool is empty, draws from that machine fail and no tokens are deducted. There is no automatic reshuffle.

### 7.3.1 Dynamic Token Scaling & Visual Resolution Contract (Templar)
Units with token-scaling abilities (such as the Templar, `unit_t2_d`, *Token Power*) adhere to strict state-presentation decoupling, dynamic real-time scaling, and persistent stat preservation:

1. **Dynamic Real-Time Scaling**:
   * Templar's PWR bonus is not fixed upon draw; it dynamically modulates in real time based on the player's **current Gacha Token amount**.
   * Any change in the player's token count—positive (answering flashcards in the mini-game, receiving room token rewards, death token refunds) or negative (spending tokens on draws or rerolls)—immediately updates the Templar's PWR up or down via delta tracking:
     $$\text{Target Bonus} = \lfloor \text{Current Player Tokens} \times \text{Multiplier} \rfloor$$
     $$\Delta = \text{Target Bonus} - \text{Previous Token Bonus}$$
   * **Level Multipliers**:
     * **Level 1**: 100% of current Tokens ($\times 1.0$)
     * **Level 2**: 150% of current Tokens ($\times 1.5$)
     * **Level 3**: 200% of current Tokens ($\times 2.0$)
   * If tokens drop to 0, $\text{Target Bonus} = 0$, reducing the Templar's bonus PWR back to 0 without dipping below its base stats.

2. **Global Token Basis & Team Parity (Player & Enemy)**:
   * Both **player-owned Templars** and **enemy Templars** scale exclusively with the **player's current Gacha Tokens** (`battle_manager.get_gacha_tokens()`).
   * All living Templars located on the battle board (`PlayerLineup`, `PlayerBench`, `EnemyLineup`, `EnemyBench`) respond to token changes. If the player stockpiles tokens, enemy Templars grow correspondingly stronger, creating a direct tactical trade-off.

3. **Preservation of Outside-Battle Training Upgrades**:
   * If a specific Templar unit instance has had its base stats upgraded outside battle (e.g. through the Dojo / `UnitTrainingGround` via `PERMANENT_UPGRADE` components), that particular unit instance preserves its upgraded base stats.
   * The token bonus is calculated and added **on top of that instance's upgraded base stats**, rather than resetting to the default unupgraded base stats of Tier 2 Templars (2 HP / 3 PWR):
     $$\text{Instance Base PWR} = \text{Definition Base PWR} (3) + \text{Persistent Training Modifiers}$$
     $$\text{Effective Current PWR} = \text{Instance Base PWR} + \text{Target Bonus} + \text{In-Battle Modifiers}$$
   * When token bonuses fluctuate or drop to zero, the unit returns strictly to its trained base stats.

4. **Visual Arrival & Stat Resolution Pipeline**:
   * **Base Stat Snapshot**: When drawn from a tier machine, the initial visual snapshot (`CombatPayload.new_unit_snapshot`) captures strictly the unit's base stats (default 2 HP / 3 PWR, or higher if upgraded in training). The draw animation lands the unit on the board displaying these base stats.
   * **Board Entry Trigger (`on_board_enter`)**: Immediately upon placement into a slot, the ability fires, evaluates remaining tokens (after the 2-token draw cost deduction), and dispatches a self-buff reaction (`CombatEvent.Type.BUFF`). The unit plays its parabolic self-cast VFX, pops its stat label, displays floating text ($+X$ PWR), and resolves to $\text{Base PWR} + \text{Bonus PWR}$.
   * **Subsequent Fluctuations**: Whenever tokens change during battle or management, a `BUFF` event is enqueued with payload `pwr_change` reflecting the positive or negative delta ($\pm \Delta$ PWR), smoothly updating the visual counter.

## 7.4 Formation & Placement
* **Lineup Constraints**: The active team consists of up to 5 fixed slots (`PlayerLineup`). Units resolve attacks from front (Slot 0) to back (Slot 4).
* **Bench Constraints**: Used for staging units, holding items, and performing merges (`PlayerBench`).
* **Rearrange**: Dragging units between lineup and bench, or swapping slots on the board.

## 7.5 Equipping Items
* **In-Battle Bench Origin Only**: Items can **ONLY** be equipped from the `PlayerBench` onto a unit on the `PlayerLineup` or `PlayerBench`. Items **cannot** be equipped directly from the battle inventory drawer (which is read-only) and **cannot** be equipped outside of battle in the run inventory.
* **Unified Single Item Slot Constraint**: All units (including the Hero) possess strictly **one item slot**.
* **Item Replacement & Net Stat Deltas**:
  * Equipping an item onto a unit that already has an equipped item triggers an **Item Replacement**.
  * **Discard Destination**: The existing equipped item is immediately removed and sent directly to the **Battle Discard Pile** (`DiscardPile`). It does **NOT** return to the player bench or inventory.
  * **Independent Net Stat Differences**: When an equipped item is replaced, the unit's stats are evaluated independently for HP and PWR based on the net difference between the new item and the old item:
    $$\Delta\text{HP} = \text{new\_item.hp} - \text{old\_item.hp}$$
    $$\Delta\text{PWR} = \text{new\_item.pwr} - \text{old\_item.pwr}$$
  * **Semantic Action Dispatch**:
    * **Positive Delta ($\Delta > 0$)**: Handled as a **BUFF** action, triggering `on_stat_increased` abilities and launching a self-targeted projectile to the unit.
    * **Negative Delta ($\Delta < 0$)**: Handled as a **DEBUFF** action, triggering `on_stat_decreased` abilities and displaying floating debuff text (`-X` in red for HP, black for PWR).
    * **Simultaneous Buff and Debuff**: A single replacement can simultaneously buff one stat while debuffing another. For example, replacing a $+1\text{ HP} / +2\text{ PWR}$ item with a $+2\text{ HP} / +1\text{ PWR}$ item triggers a net $+1\text{ HP}$ Buff and a $-1\text{ PWR}$ Debuff at the same time.
* **Visual Equip Timing**:
  * Passive stat buffs and debuffs from equipped items only animate and play out *at the exact moment the item graphic visually appears on the unit view*.
  * **Universal Application**: This synchronization applies equally to:
    1. Player manual item equipping during the Management Phase.
    2. Enemy units entering the battlefield pre-equipped with items during entrance/summon sequences.
  * Floating numbers, stat projectiles, or debuff popups must never play before the item graphic is visibly rendered on the unit view.
  * **Sequential Animation Order**: When an item replacement occurs, the sequence resolves in strict beats:
    1. The old item capsule arcs into the Battle Discard Pile and disappears from the unit view.
    2. The new item graphic appears on the unit view with a tactile landing bounce and landing sound effect.
    3. The net stat Buff and/or Debuff animations play on the unit view.
* **Unified Ability Equip Parity (Standard Bearer)**: When an item is equipped or transferred onto a unit via an in-game ability (such as the Standard Bearer's death ability, *Standard's Legacy*), it executes through the exact same equip pipeline as manual player equipping. If the recipient ally already has an equipped item, that existing item is replaced, moved to the Discard Pile, and animated via the exact same GachaBall capsule discard animation before the transferred item lands.
* **Bench Unit Item Passives**: Items equipped on bench units provide their passive stat bonuses immediately, but their reactive combat abilities do not trigger until the unit enters the active `PlayerLineup`.

## 7.6 Consumable Items
Consumable items are one-time tactical tools that differ fundamentally from standard equipment:
* **Usage Origin**: Consumables can **only** be dragged and used from the `PlayerBench`.
* **Targeting (Allies & Enemies)**: Unlike equippable items, consumables can target **both Player units and Enemy units**.
* **Instant Consumption & No Item Swapping**:
  * Dragging a consumable onto a unit (or dropping it directly over a unit's equipped item slot) applies its effect **immediately**.
  * Consumables are **never equipped** onto target units and do **not** enter the equipment swap pipeline.
  * Dropping a consumable onto a unit holding an equipped item will **never** trigger an item swap, replace the held item, or unequip the unit's existing gear.
* **Disappearance from Battle Pool**: Once used, consumables **do NOT go to the Discard Pile**. They are permanently consumed and disappear from the active battle pool. (The engine tracks used consumables in a dedicated ledger for analytics and potential consumable-synergy traits).
* **Stackable Regular Buffs Across Merges**:
  * Consumable items grant **stackable regular buffs** (HP bonuses, PWR bonuses, restorative healing amounts, and status effects).
  * All consumable stat modifications are tagged with granular origin `source_type = &"CONSUMABLE"` (with `source_id` tracking the consumable's definition ID) and are marked `allow_stacking = true`.
  * Unlike equippable item buffs—which are unique and conditional to the unit currently holding that piece of equipment—consumable buffs become direct, permanent/tactical enhancements of the recipient unit.
  * When units merge (both Evolutionary Level-ups and Recipe Tier-ups), all consumable buffs from both parent units are fully conserved and added together into the resulting unit's stats and merge inheritance surplus (`MERGE_INHERITANCE`).
* **Item-Stripping Consumables (*Potion of Plunder*)**:
  * When *Potion of Plunder* is used on any unit (player or enemy), it removes a random equipped item from that unit without replacing it.
  * The stripped item is unequipped and sent directly to the player's **Gacha Machine** of the corresponding tier (`BattleInventoryT{tier}`), making it available to be drawn by the player in subsequent turns.
  * Animates along a parabolic arc into the player's corresponding tier Gacha Machine (`%GachaMachine{tier}`) using the full GachaBall capsule (`GachaBallView.tscn` in inventory mode, scaling from `0.3` to `1.5` over a 500px arc) with `coin_land` SFX, bouncing the target Gacha Machine and incrementing its count badge.
  * Standard unequip stat reductions apply immediately to the stripped unit upon departure.

## 7.7 Merging GachaBalls
Merging combines two units to create a stronger unit, whether through evolutionary leveling up (merging identical units) or recipe tier evolutions (merging two distinct units into a higher tier):
* **Recipe Discovery & Unlocks**: Recipes are locked at the start of a run. Acquiring a unit or item through rewards, events, or in-combat summons unlocks its recipe for the remainder of that run.

### 7.7.1 Merge Stat & Soul Inheritance Contract
When two units merge, the game categorizes all attributes, stats, and modifiers into **Stackable Stats**, **Elemental Souls**, **Status Effects**, and **Unique / Conditional Buffs**:

1. **Stackable Stats (HP & PWR)**:
   * **What counts as stackable**:
     * Inherent level-up bonuses (+1 HP and +1 PWR per level gained).
     * Permanent Dojo training gains (`PERMANENT_UPGRADE`).
     * Consumable item buffs (healing potions, stat potions, scrolls) tagged with `source_type = &"CONSUMABLE"` (all stat gains and restorative healing from consumables combine additively into merge inheritance).
     * In-combat permanent growth and reactive buffs (e.g., *Vengeance Charm*, *Convergence Surge*, and mid-battle ability buffs).
     * Rarity bonuses (e.g., Prismatic rarity).
     * Surplus stats inherited from prior merges (`MERGE_INHERITANCE`).
   * **Merge Contract**:
     * In all merges (both Evolutionary Level-ups and Recipe Tier-ups), all accumulated stackable HP and PWR bonuses from **both** parent units combine and carry over into the resulting unit's stats.
     * A unit never loses its accumulated battle buffs, consumable enhancements, or training gains simply because it leveled up or merged.

2. **Elemental Souls (Direct Additive Inheritance)**:
   * **What counts as souls**:
     * All elemental souls (Fire, Earth, Water, Air) possessed by both parent units, including innate definition souls and souls accumulated from prior merges.
   * **Merge Contract**:
     * Elemental souls are strictly cumulative and fully conserved across all merges. All souls from both parent units add together directly onto the resulting unit:
       $$\text{Result Souls} = \text{Parent A Souls} + \text{Parent B Souls}$$
     * **Evolutionary Level-Up Example**:
       * Two Level 1 units (1 Fire soul each) merge into a Level 2 unit with **2 Fire souls** ($1 + 1 = 2$).
       * Two Level 2 units (2 Fire souls each) merge into a Level 3 unit with **4 Fire souls** ($2 + 2 = 4$).
     * **Recipe Tier-Up Example**:
       * Merging a Level 3 Rocky (**4 Earth souls**) with a Level 1 Dewey (**1 Water soul**) produces a Tier 2 unit with **5 souls** (4 Earth + 1 Water).
       * Merging a Level 3 Rocky (**4 Earth souls**) with a Level 3 Sparky (**4 Fire souls**) produces a Tier 2 unit with **8 souls** (4 Earth + 4 Fire).
     * No souls are ever subtracted or lost during a merge.

3. **Status Effects (Armor, Burn, Spikes, Static, etc.)**:
   * All active status effect stacks on both parent units are stackable.
   * When two units merge, all existing stacks of Armor, Burn, Spikes, Static, and other status effects from both parents are summed together onto the resulting unit.

4. **Unique & Conditional Buffs (Non-Stackable Across Merges)**:
   * **What counts as unique / conditional**:
     * Stats granted by an equipped item (active only while holding that item; stripped/re-evaluated upon merge so only one item is inherited and its stats re-applied fresh, unlike consumable buffs which stack additively).
     * *Rusty Ring* (+1 HP / +1 PWR, active only while holding NO item).
     * *Royal Insignia* (+1 HP / +1 PWR, active only for Level 1 units).
     * *Veteran Insignia* (+1 HP / +1 PWR, active only for Level 2 units).
     * *Twin Charm* (scaled dynamically based on duplicate copy counts in the battle pool).
   * **Merge Contract**:
     * Unique and conditional buffs must **never** be baked into the inherited stats of a merged unit.
     * When two units merge:
       1. All unique/conditional buffs are cleanly stripped from the parent units so they are completely excluded from the inherited stat total.
       2. Base stats, stackable buffs, elemental souls, and status effects are combined onto the new unit.
       3. The new unit is evaluated fresh for eligible unique/conditional buffs based on its new state. If the unit inherits an equipped item, the item is equipped silently with its stats pre-baked into the unit's starting stats without emitting extra floating buff numbers or self-buff projectiles.

### 7.7.2 Level Combinations, Variations & Visual Presentation
The game distinguishes between leveling up an existing unit and synthesizing a completely new higher-tier entity:

* **Evolutionary Merge (Leveling Up)**: Merging two duplicate units of the same type upgrades the unit to the next level (up to Level 3).
  * **Level Requirement**: Strictly restricted to **matching levels** (Level 1 + Level 1 $\to$ Level 2, and Level 2 + Level 2 $\to$ Level 3). Units of different levels cannot self-merge, and Level 3 units cannot merge with other duplicate units.
  * The leveled-up unit is considered the **same continuous unit** advancing in power.
  * **Rusty Ring**: If the resulting leveled-up unit holds no item, *Rusty Ring* (+1 HP / +1 PWR) applies once and is pre-baked into the new unit's starting stats without firing an additional visual cast or projectile animation that might be perceived as a duplicate proc of the same trinket.
  * **Insignia Re-evaluation**: If two Level 1 units merge into a Level 2 unit, the Level 1 *Royal Insignia* bonus is stripped. If the player owns *Veteran Insignia*, the unit receives the Level 2 bonus fresh upon leveling up.
  * **Dynamic Scaling Passives (*Twin Charm*, *Doppleganger*)**: The leveled-up unit pre-inherits the post-merge battle pool copy bonus directly into its initial stats and tracking state. If the post-merge copy count still qualifies for a bonus, the bonus is baked into the new unit without firing an additional duplicate buff projectile if the amount of buff changes because of the merge (since the twin charm and doppleganger or echoing orb if equipped on one or both the merging units should have already triggered with the correct values in the game loop during the simulation of the merge).

* **Recipe Merge (Tiering Up)**: Merging different specific units according to an unlocked recipe evolves them into a higher-tier unit.
  * **Flexible Level Combinations**: Recipe Tier-Up merges allow **any combination of unit levels** (e.g., Level 1 + Level 1, Level 1 + Level 2, Level 1 + Level 3, Level 2 + Level 3, or Level 3 + Level 3).
  * **Always Starts at Level 1**: Regardless of the levels of the parent units, the resulting higher-tier unit is treated as a **brand-new entity** entering the board and always begins at **Level 1**.
  * **Wide Stat & Soul Variations on Level 1 Higher-Tier Units**:
    * Because parents can be any level combination with prior merge histories, the starting stats and elemental soul counts on the freshly crafted Level 1 higher-tier unit will vary significantly based on the parent units used:
      * **L1 + L1 Merge**: Inherits baseline Level 1 stats and 2 souls ($1 + 1$).
      * **L3 + L1 Merge**: Inherits the Level 3 parent's accumulated level bonuses, Dojo training, prior merge surplus, and 5 souls ($4 + 1$).
      * **L3 + L3 Merge**: Inherits immense accumulated stats from both parents and up to 8 souls ($4 + 4$).
    * **Future Level-Up Potential**: Because this newly created higher-tier unit starts at **Level 1**, it can subsequently be merged with another matching Level 1 higher-tier unit to level up to Level 2 and Level 3, compounding its inherited power and soul synergies even further.
  * **Visual Presentation**: The new higher-tier unit spawns onto the board without conditional trinket buffs pre-baked. Instead, conditional trinkets (such as *Rusty Ring* if unequipped, or *Royal Insignia* for Level 1) evaluate fresh on board entry (`on_board_enter`/`on_merge`) with full visual presentation—firing flying buff projectiles and animations from the trinket bar onto the new unit as it arrives on the board.
  * Dynamic scaling passives (*Twin Charm*) do not carry over from parents; the new unit evaluates fresh according to its new unit definition.

* **Item Transfer Priority & Pre-Baked Stats**: 
  * During any merge, only one equipped item is carried over to the result. The target unit's item takes priority; if empty, the source unit's item is transferred. Any secondary equipped item that is not transferred is sent directly to the **Battle Discard Pile** (`DiscardPile`) via the standard GachaBall capsule discard animation.
  * **Seamless Pre-Baked Equips**: The inherited item is equipped silently onto the resulting unit. Its stat bonuses (e.g., +1 HP from *Koi's Blessing* or +1 PWR from *Tiger's Spirit*) are pre-baked into the new unit's initial stats upon spawning on the board, preventing redundant self-buff animations or floating numbers from firing over the freshly merged unit.
* **Bench Item Merging**: Dragging an item onto another item on the bench checks for item recipes and opens a confirmation preview.

## 7.8 Physics Inventory & Discard Drawers (Battle Only)
During battle, the drawer-based inventory (Battle Inventory) and side-drawer discard pile are **Read-Only Physics Visualizations**:
* **Three Tier Pools**: The Battle Inventory physically separates GachaBalls into three distinct tier containers populated from the player's Run Inventory.
* **Single Shared Discard Pile**: All defeated units and discarded/replaced items share one physical discard drawer.
* **Read-Only Interaction**: Players cannot drag, equip, move, or swap balls directly from these physics drawers.
* **Sequential Spawning**: Balls spawn sequentially at the top-center at **0.15s intervals** with random horizontal stagger to prevent overlapping physics explosions.
* **Continuous Collision Detection (CCD)**: Enabled on all balls with a 12-sided dodecagon collision shape to prevent tunneling during high-velocity drawer animations.
* **Spring Lid Overflow Penalty**: If a container becomes physically overfilled and a ball maintains continuous physical contact with the top lid (a 30px high zone) for **5.0 seconds**, it emits a penalty signal and is moved to the **Battle Discard Pile**.
* **Selective Tray Return**: If a ball being spawned into the Discard Pile is already registered in the discard ledger, it is returned to the Trays pool with stats reset to prevent duplicate entries.
* **Discard Pile Jolt**: Opening the Discard Pile drawer applies a horizontal impulse of `Vector2(-500, 0)` to ensure dense, efficient packing.
* **Rule S8 (Hover Boundary)**: While an inventory drawer is open, hovers originating from the background battle board are blocked to prevent accidental window closures.
* **The Permanent Discard**: Defeated units and discarded items remain in the Discard Pile permanently for the remainder of the battle. There is no automatic reshuffle.

## 7.9 Battle Pool Scoping & Dynamic Scaling Passives
Passives that scale based on duplicate copies (*Twin Charm*, *Doppleganger*, *Echoing Orb*) evaluate against the total count of matching entities across the entire team's **Battle Pool**, not just the active battle board.

### 7.9.1 Battle Pool Definition & Invariants
* **Pool Containers**: A team's Battle Pool includes entities residing in:
  1. `PlayerLineup` / `EnemyLineup` (Active battle board)
  2. `PlayerBench` / `EnemyBench` (Bench slots)
  3. `BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3` (Gacha machine trays)
  4. `DiscardPile` (Defeated units and discarded items)
* **Invariant Pool Size**:
  * Drawing a unit from the gacha machine to the board does **not** change the total copies in the battle pool (it simply moves container).
  * Moving a unit between the bench and lineup does **not** change the total copies in the battle pool.
  * A unit dying and entering the discard pile does **not** reduce the total copies in the battle pool.
* **Count Mutations**:
  * **Summons**: In-combat summons increase the total copies in the battle pool.
  * **Level-Up Merges**: Merging two duplicate units into a higher-level unit reduces the total copies of that unit definition in the battle pool by 1 ($N \to N - 1$). A Level 2 or Level 3 unit counts strictly as **1 unit**.
  * **Tier Evolutions**: Merging two different units reduces the pool count of each parent definition by 1, and increases the pool count of the new result definition by 1.
* **Board-Only Stat Holding**:
  * While copy counts are evaluated across the entire battle pool, stat bonuses granted by scaling passives (*Twin Charm*, *Doppleganger*, *Echoing Orb*) are only held and applied to active units on the board (`PlayerLineup`, `PlayerBench`, `EnemyLineup`, `EnemyBench`). Units resting inside gacha machine trays hold 0 bonus until they enter the board.

## 7.10 Universal Discard Pile & Gacha Machine Visual Arrival Rules
All entities that leave the board or inventories to enter the Discard Pile or Gacha Machines are governed by universal presentation rules to guarantee clear physical feedback and maintain state decoupling:

### 7.10.1 Universal Discard Pile Arrival Rule
* **Identical Arc Animation**: All units and items entering the **Battle Discard Pile** (`DiscardPile`) travel there using the exact same GachaBall capsule arc animation (`GachaBallView.tscn` in inventory mode, scaling from `0.3` to `1.5` over a 500px parabolic arc, with `coin_land` SFX and button scale bump `1.0` $\to$ `1.15` $\to$ `1.0` on `%DiscardPileButton`).
* **Player Unit Death Departure**:
  1. When a player unit reaches 0 HP, its board puppet view plays the standard `death_fade` animation and is freed.
  2. The unit's GachaBall capsule animates from the death position along the 500px arc directly into the Discard Pile button.
  3. At the exact moment the capsule lands, `coin_land` SFX plays, the Discard Pile button plays its scale bump, and the counter label updates (+1).
  4. If the unit was holding equipped items, each item's GachaBall capsule follows along the exact same arc **strictly sequentially** (one item after another). Each item's landing plays `coin_land` SFX, bumps the button, and increments the counter (+1).
* **Enemy Units Do NOT Discard**: Only player units and player-held items enter the discard pile. When an enemy unit dies, it dissolves via `death_fade` and is removed; no capsule arc is spawned and the Discard Pile button counter is untouched.
* **Manual and Triggered Item Discards**: Equipping an item onto a unit that already has an item (whether manually by player drag-and-drop or triggered automatically via Standard Bearer's *Hold the Line* or merge overflow) unbinds the replaced item to `DiscardPile` using this exact same capsule arc, incrementing the counter on landing.
* **Full-Bench Gacha Draws**: Drawing a ball when the bench is full routes the ball into `DiscardPile` using this arc, bumping the button and updating the counter on landing.
* **Decoupled Real-Time Counting**: The Discard Pile button counter label NEVER queries live end-of-turn data during playback. It initializes from the pre-combat / pre-animation snapshot and increments (+1) exclusively at the arrival moment of each individual capsule.

### 7.10.2 Universal Gacha Machine Arrival Rule
* **Identical Arc Animation**: All units and items entering Gacha Machine drawers (`BattleInventoryT1`, `BattleInventoryT2`, `BattleInventoryT3`)—such as Echoing Orb duplication (*Echo Split*) or *Potion of Plunder* item stripping—animate along a 500px parabolic arc directly into the corresponding Gacha Machine (`%GachaMachine{tier}`).
* **Exact Landing Synchronization**: The target Gacha Machine's tier counter badge and its visual bounce/flash reaction execute *strictly at the moment of capsule impact/landing*, updating `_visual_machine_counts[tier]` by +1.

---

# 8. Universal Visual Feedback & Clarity Rules

The presentation system enforces a strict **Visual Clarity Contract**: the player must always clearly identify what entity is granting a buff or inflicting a debuff.

```
[External Buff]   Source (Unit / Trinket) ──(Flying Projectile)──► Target Unit
[Self / Item Buff] Unit Holder ──(Parabolic Arc Projectile)──► Lands on Self
[Debuff / Loss]    Unit ──(Instant Floating Text: Red for HP, Black for PWR)
```

1. **Directional Buff Projectiles (External Buffs - Unit-to-Unit & Trinket-to-Unit):**
   * Whenever a buff originates from an external entity (another unit or an equipped trinket), a projectile spawns at the source entity's screen coordinates (source unit node or HUD TopArea trinket icon) and travels to the target unit.
   * On impact, the target unit plays the impact VFX, punches its stat label, and spawns positive floating text (`+X` green for HP, blue for PWR).
   * **Trinket Buff Delivery (e.g., *Twin Charm*)**: *Twin Charm* evaluates unit copy thresholds across the battle pool. When board entry, draws, or summons break the threshold, the trinket activates on the HUD, firing directional buff projectiles from the trinket bar directly to each eligible unit on the board (including clones like *Doppleganger*).

2. **Parabolic Self-Cast Projectiles (Self-Buffs & Item Equipped Buffs):**
   * When an entity buffs itself, or when an item grants passive or triggered stats to its holder, the buff operates as a **Self-Buff targeting the unit holder**.
   * A **parabolic self-cast projectile** launches upward from the unit and arcs back down onto itself.
   * Items never hold live stats or buff themselves; an item's passive stats and abilities always target the holding unit.
   * **Self-Buffing Units (e.g., *Doppleganger*)**: *Mirrored Might* grants power based on duplicate copies in battle and launches a parabolic self-cast projectile onto the Doppleganger itself.
   * **Passive Scaling Items (e.g., *Echoing Orb*)**: *Echoing Orb* has 0 base stats and grants +2 PWR to its holder for each Echoing Orb in the battle pool (counting itself, so 1 orb = +2 PWR, 2 orbs = +4 PWR, etc.). Applying or updating this buff fires a parabolic self-cast projectile onto the holder unit.

3. **Debuff Visual Standards:**
   * Stat reductions (debuffs, item unequip losses, negative stat deltas) do not fire flying projectiles.
   * The unit immediately displays floating stat debuff text (`-X`), strictly color-coded:
     * **Red (`Color(1.0, 0.0, 0.0)`)**: Health reduction (`-X HP`).
     * **Black (`Color(0.0, 0.0, 0.0)`)**: Power reduction (`-X PWR`).

---

# 9. Combat Resolution & Simulation Rules

Combat resolves automatically once the player clicks **"Battle!"** (ending the Management Phase).

## 9.1 Absolute Determinism
* Damage dealt equals the attacker's Power (PWR) minus the defender's Armor:
  $$\text{Damage} = \max(0, \text{Attacker PWR} - \text{Defender Armor})$$
* Spikes damage reflects directly back to the attacker when hit by a direct attack, bypassing Armor.
* There are no critical hits, random dodges, or percentage-based damage rolls.

## 9.2 Action Order & Initiative
* **Player Initiative**: The entire player team initiates its attacks before the enemy team.
* **Directional Order**: Units act strictly from front (Slot 0) to back (Slot 4).
* **Targeting**: Units attack the enemy in the mirrored slot; if that slot is empty, they target the frontmost active enemy.
* **0 PWR Units**: Units with 0 PWR (e.g., Dust Minions) still perform their full attack animation to ensure consistent visual pacing, but deal 0 damage.

## 9.3 Reaction Priority Hierarchy
When multiple abilities trigger simultaneously, the simulation sorts them using a strict 3-layer hierarchy:
1. **Layer 1: Execution Priority (Descending Integer Priority)**: Higher priority integers resolve first:
   * `300` - **Interceptors**: Shields and damage redirects that resolve *before* triggering damage is applied (e.g. *Guardian Sentinel*).
   * `220` - **Duplication**: Post-death clone mechanics (*Doppleganger*).
   * `210` - **Trinket Summons / Resurrections**: High-priority trinket triggers (*Soul Echo*).
   * `205` - **Unit On-Death Summons**: Innate unit death spawns (*Soul Caller*, *Sakura Spirit*).
   * `200` - **Item On-Death Summons**: Equipped item death spawns (*Summoning Scroll*, *Last Wish*).
   * `100–199` - **Standard Reactions**: Buffs, heals, and aura distributions (*Resilient Aura*).
   * `50` - **Modifiers**: Counter-attacks, defensive adjustments, and status applications (*Retaliate*).
   * `0` - **Default Attacks / Passives**: Standard abilities.
   * `<0` - **Delayed**: Boss reinforcements (`-50`) and extra turns (`-100`).
2. **Layer 2: Category Tie-Breaker (When Priorities Are Equal)**:
   * Units (Rank 1) $\rightarrow$ Items (Rank 2) $\rightarrow$ Trinkets (Rank 3).
3. **Layer 3: Visual Direction (The Mirror Rule)**: Priority and category ties resolve Left-to-Right visually on screen:
   * **Player Team**: Evaluated Left-to-Right (Slot 4 down to Slot 0).
   * **Enemy Team**: Evaluated Right-to-Left visually (Slot 0 up to Slot 4).
   * Because units hold strictly 1 item, intra-unit item ties do not occur.

### 9.3.1 Summon Priority & Board Space Slot Reservation
When multiple summons occur simultaneously on the death of a unit (e.g. a unit with an innate on-death summon ability, holding a summoning item, while *Soul Echo* is equipped):

| Priority | Source | Claims Slot | Description |
|---|---|---|---|
| **210** (`PRIORITY_TRINKET_SUMMON`) | **Trinket** (*Soul Echo*) | **1st** | Resurrects the original dying unit into its original slot before any spawns occur. |
| **205** (`PRIORITY_UNIT_SUMMON`) | **Unit Ability** (*Soul Caller*) | **2nd** | Spawns a unit; because the original slot was claimed by the resurrection, it searches for an alternative available slot. |
| **200** (`PRIORITY_ITEM_SUMMON`) | **Item** (*Summoning Scroll*, *Last Wish*) | **3rd** | Spawns a unit; searches for the next available alternative slot or Discard Pile. |

**Slot Search Order for Displaced Summons**:
1. Original Slot (claimed by Priority 210 Trinket Summon).
2. Alternative Available Slots in Lineup (searching Back-to-Front).
3. Discard Pile (Player only; if Lineup is full). If Discard Pile is full or enemy team has no free slots, the summon is cancelled.

### 9.3.2 Unit Transformation Rules (Mimic & Mirror Image)
The Mimic (*Mirror Image*) possesses a unique pre-action transformation mechanic that operates under strict determinism and single-action turn rules:

1. **Trigger Timing**:
   * Mimic triggers its ability on `on_before_turn_action` with **Priority 500**.
   * This evaluates immediately before its attack when its turn arrives in the standard initiative sequence (Player: Slot 4 down to Slot 0; Enemy: Slot 0 up to Slot 4).
2. **Mirror Slot Target Resolution**:
   * Mimic targets the mirrored opposing lineup slot ($\text{Mirror Slot Index} = 4 - \text{Current Slot Index}$).
   * The opposing entity must be an active, valid standard unit (Tier 1–3). It cannot transform into Heroes or Bosses.
   * **Empty or Ineligible Slot Fallback**: If the mirrored enemy slot is empty or contains an ineligible target, the transformation does not occur. Mimic retains its form and executes a standard basic attack instead.
3. **Item Transfer & State Mutation**:
   * Any items equipped on Mimic are preserved and immediately re-equipped onto the newly spawned unit instance in their exact equipment slots, inheriting all passive item stat bonuses seamlessly.
   * Mimic is removed from the board, and the new unit is spawned directly into the exact lineup slot Mimic occupied, initialized at the appropriate level (based on Mimic's ability level / delta).
4. **Single-Action Turn Invariant (One Action Per Slot)**:
   * The newly transformed unit immediately continues the active turn for that slot, replacing Mimic as the acting unit and performing its attack (including any innate `on_attack` abilities or equipped item effects).
   * **No Duplicate Turn**: The transformed unit is **never** re-enqueued into the battle's remaining actor queue. It acts **exactly once** during the turn, preserving the core invariant that each board slot takes at most one action per round.
5. **Visual Sequence**:
   * Visually, Mimic executes a `TRANSFORM` hop-and-vanish animation (golden death fade), immediately followed by a `SUMMON` entrance (yellow flash VFX) of the transformed unit, which then performs its attack animation.

## 9.4 Causality & Deferred Deaths
* Events resolve in strict causal order:
  $$\text{DAMAGE} \longrightarrow \text{on\_hurt HEAL/BUFF} \longrightarrow \text{DEATH} \longrightarrow \text{on\_death SUMMON}$$
* When a unit reaches 0 HP, pending `on_hurt` reactions are drained first. The `DEATH` event is recorded, reactive death abilities trigger, and game state cleanup removes the unit to the Discard Pile.

## 9.5 Battlefield Slots Detail
Special slots placed on the battlefield grid apply persistent or turn-start effects to units standing on them:
| ID | Name | Trigger | Effect | Cost (Gold) |
|---|---|---|---|---|
| `burn` | Burn Slot | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 |
| `lightning` | Lightning Slot | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 |

## 9.6 Detailed Status Effects
| ID | Name | Mechanics | Decay Mode |
|---|---|---|---|
| `burn` | Burn | Deals damage equal to the number of stacks at the end of each turn. **Burn damage ignores armor.** | Halved (reduced by 50% rounded down) at the end of each turn. Burn stacks on units in a Burn Slot do not decay. |
| `armor` | Armor | Absorbs incoming direct HP damage (1 point of Armor blocks 1 point of HP damage). Does not block Burn or Static damage. | Decays to 0 at the end of each turn unless preserved by specific abilities or trinkets (e.g. Polished Plate). |
| `spikes` | Spikes | Deals PWR damage back to attackers when hit by a direct attack. | Does not decay. |
| `static` | Static | Consumed stack-by-stack whenever the unit suffers any core stat change (HP damage, healing, or power modification). Consuming a stack deals 1 armor-ignoring damage to the unit. Damage dealt by Static itself does not trigger further Static consumption. | Does not decay. Stacks are only consumed by stat changes. |

## 9.7 Semantic Action Typing in the Combat & Stat Engine

In *Flashcard Heroes*, units do not have a maximum stat cap; they have their starting base stats and their current in-combat stats. Every stat alteration is classified by its gameplay intent so that reactive abilities and defensive systems trigger strictly when appropriate without unintended cross-firing:

### 9.7.1 Core Action Categories & Behavioral Rules

| Action Category | Affected Stats | Reactive Trigger Fired | Interaction with Armor & Spikes | Gameplay Rule & Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Healing (`HEAL`)** | Health (HP) | When Healed (`on_healed`) | Does not interact with Armor or Spikes | Restorative recovery (such as drinking potions, lifesteal recovery, or regenerative passives). Strictly triggers "When Healed" reaction abilities (like Mud Wretch's *Mud Coating* or Steam Wisp's *Scald*). **Never** counts as a stat buff and never triggers "When a Stat Increases". |
| **Stat Buffs (`BUFF`)** | Health (HP), Power (PWR) | When a Stat Increases (`on_stat_increased`) | Does not interact with Armor or Spikes | Stat empowerment, level scaling, and conditional enhancements (such as ally death bonuses, merge stat increases, or aura growth). Strictly triggers "When a Stat Increases". **Never** counts as healing and never triggers "When Healed". |
| **Attack Damage (`DAMAGE`)** | Health (HP) | When Hurt by an Attack (`on_hurt`), On Damage Dealt (`on_damage_dealt`) | Mitigated by Armor; Melee triggers Spikes | Direct combat strikes dealt by an attacker. Mitigated by the defender's Armor. Melee attacks trigger counter-damage from Spikes. Direct attacks trigger both "When Hurt by an Attack" on the victim and "On Damage Dealt" on the attacker. |
| **Stat Debuffs (`DEBUFF`)** | Health (HP), Power (PWR) | When a Stat Decreases (`on_stat_decreased`) | Completely bypasses Armor and Spikes | Direct stat penalties. Directly reduces Health or Power, completely bypasses Armor, ignores Spikes, and **never** triggers "When Hurt by an Attack" or "On Damage Dealt". |

### 9.7.2 Damage Origins & Defensive Rules

Direct combat attacks and non-attack damage sources interact differently with defensive attributes:

| Damage Source | Mitigated by Armor? | Triggers Spikes Counter? | Triggers Counter-Attacks? | Triggers Self/Ally Hurt Reactions? | Triggers "On Damage Dealt"? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Melee Attacks** | **Yes** (1 Armor blocks 1 damage) | **Yes** (deals defender's PWR back to attacker) | **Yes** | **Yes** | **Yes** |
| **Ranged Attacks** | **Yes** (1 Armor blocks 1 damage) | **No** | **Yes** | **Yes** | **Yes** |
| **Trinket Damage** | **Yes** (1 Armor blocks 1 damage) | **No** | **No** (Trinkets cannot be attacked) | **Yes** (Self/ally heals on taking damage) | **No** |
| **Kamikaze Damage** | **Yes** (1 Armor blocks 1 damage) | **No** | **No** (Attacker is deceased; no retaliation) | **Yes** (Self/ally heals on taking damage) | **No** |
| **Burn Damage** | **No** (Bypasses Armor completely) | **No** | **No** | **No** | **No** |
| **Static Discharge** | **No** (Bypasses Armor completely) | **No** | **No** | **No** | **No** |
| **Spikes Reflection** | **Yes** (1 Armor blocks 1 damage) | **No** (Cannot reflect off Spikes) | **No** | **No** | **No** |
| **Health Debuffs (`DEBUFF`)** | **No** (Bypasses Armor completely) | **No** | **No** | **No** | **No** |

> [!NOTE]
> **Damage Classification & Reactions**:
> * Direct combat attacks by units are classified as **Melee** (targeting frontmost positions, triggering Spikes) or **Ranged** (targeting arbitrary enemy slots, bypassing Spikes).
> * **Trinket Damage** (e.g. *Fusion Spark*) originates systemically from equipped trinkets rather than a unit strike. It is mitigated by Armor and can be intercepted by Guardian Sentinel leaps, but cannot trigger counter-attacks against the trinket or Spikes reflection. It still triggers self-sustain or ally-protection abilities that react to suffering damage.
> * **Kamikaze Damage** (e.g. *Death's Bargain*) is an attack where the attacking unit perishes upon executing the attack. It is mitigated by Armor and can be intercepted by Guardian Sentinel leaps, but does not allow targeted retaliation since the attacker has already died.
> * Non-attack environmental damage sources (Burn decay, Static discharge, and Spikes reflection) do not count as attacks and do not trigger attack-reactive abilities.

### 9.7.3 Trigger Separation Guarantees

The game guarantees complete separation between triggers:
1. **Healing vs. Health Buffs**:
   - Restoring Health (`HEAL`) only triggers healing-reactive abilities (e.g. Mud Wretch's *Mud Coating*).
   - Increasing Health through a buff (`BUFF`) only triggers stat-growth abilities. Healing reactions will completely ignore Health buffs.
2. **Direct Damage vs. Health Debuffs**:
   - Direct attacks deal damage through the combat system, reduce Armor, and trigger "When Hurt by an Attack" reactions.
   - Health debuffs (`DEBUFF`) directly lower Health without touching Armor or Spikes, triggering only "When a Stat Decreases".
3. **Power Modifications**:
   - Power gains count as stat buffs and trigger "When a Stat Increases".
   - Power reductions count as stat debuffs and trigger "When a Stat Decreases".

### 9.7.4 Buff Echo Behavior (Shadow Cloner)

* **Ability Owner**: Belongs to the **Shadow Cloner** unit (*Buff Echo* ability).
* **Trigger**: Activates whenever an adjacent ally's stat increases in combat ("When a Stat Increases").
* **Temporary Buffs Only**: Buff Echo only copies temporary, stackable in-combat stat buffs. Permanent base upgrades (such as Dojo training or permanent base stat rewards) are never copied.
* **Buff Delivery**: When repeating Health bonuses, Buff Echo delivers them strictly as a Health Buff (never as Healing). This ensures that copied Health bonuses never trigger healing-reactive abilities or create infinite feedback loops.

### 9.7.5 Starter Hero Soul Harvest (Ally Death Stat Absorption)

* **Ability Owner**: Belongs to the **Starter Hero** (*Soul Harvest* ability).
* **Trigger**: Activates whenever any allied unit falls in combat ("When an Ally Dies" / `on_ally_death`).
* **Dynamic In-Combat Power Evaluation**: The health gained by the Starter Hero is calculated from the fallen ally's **current in-combat Power** at the moment of death. This fully accounts for all active combat buffs, permanent upgrades, level stat bonuses, and equipped item stats, rather than relying on the unit's static template definition base Power.
* **Calculation Formula**:
  $$\text{HP Gain} = \max\left(1, \left\lfloor \frac{\text{dying\_unit.current\_pwr}}{2} \right\rfloor\right)$$
  The Starter Hero gains Health equal to half of the fallen ally's current combat Power rounded down, with a strict guarantee of at least 1 Health gained. Even if the fallen ally possessed 0 or 1 Power, the Starter Hero still gains 1 Health.
* **Action Type & Event Classification**:
  * The health increase is applied as a permanent stat increase and dispatched strictly as a **BUFF** (`on_stat_increased`).
  * Because it is classified as a stat Buff rather than Healing, it interacts exclusively with stat-increase reactions and never triggers healing-reactive abilities.

---

# 10. Elemental Traits & Trinkets

Units possess elemental soul tags (Fire, Earth, Water, Air). Equipping the corresponding elemental Trinket unlocks team-wide synergies:

## 10.1 Snapshot Locking
At the start of each combat turn, the game takes a snapshot of active souls in the lineup. Trait strength is locked for the duration of that combat round, preventing mid-turn fluctuations as units die or are summoned.

## 10.2 Trait Synergies & Thresholds
| Trait | Focus | Thresholds (Souls) | Effect |
| :--- | :--- | :--- | :--- |
| **Fire** | Offensive Pressure | 3 / 5 / 7 / 9 | Applies Burn on attack. Higher thresholds grant more stacks; 7+ applies Burn to the entire enemy team. |
| **Earth** | Defensive Sustain | 3 / 5 / 7 / 9 | Grants Armor (3, 5, 7, 9) and Spikes (7, 9) to allies. Earth units gain double armor bonus. |
| **Water** | Resilience | 2 / 4 / 6 / 8 | Heals adjacent allies at turn start upon acting. |
| **Air** | Disruption | 2 / 4 / 6 / 8 | Steals Power (PWR) from mirrored enemy slots. |

## 10.3 Trinket Integration Rules
* **Reaction Priority**: When abilities react during combat, they resolve in an orderly hierarchy: Units act first, followed by Items, followed by Trinkets.
* **Turn-Start Trinkets**: Resolved during the Start of Turn phase, subject to First-Turn Suppression on Turn 1.
* **Mini-Game Interceptors**: Trinkets like *Beginner's Charm* inspect reviewed card mastery to award bonus tokens.
* **Board-Entry Insignia Trinkets (*Royal Insignia* & *Veteran Insignia*)**:
  * **Royal Insignia**: Grants +1 HP and +1 PWR to any Level 1 unit entering the board (drawn from the gacha machine, summoned by abilities, merged via tier evolution, or present at battle start). Operates strictly on unit level and ignores unit tier completely. The Hero has no level or tier and is strictly unaffected.
  * **Veteran Insignia**: Applies strictly to Level 2 units. Grants +1 HP and +1 PWR to any Level 2 unit entering the board or advancing to Level 2 via merge, regardless of tier. The Hero is strictly unaffected.
  * **Merge Contract**: Both insignia bonuses are conditional upon unit level and are strictly non-stackable across merges. When units merge, parent insignia buffs are cleanly stripped and never baked into inherited stats. When two Level 1 units merge into a Level 2 unit, the Level 1 *Royal Insignia* bonus is stripped, and the resulting unit qualifies for and receives the *Veteran Insignia* bonus fresh if owned by the player.
* **Conditional Equipment Trinkets (*Rusty Ring*)**:
  * Grants +1 HP and +1 PWR to all units with no equipment.
  * Equipping an item immediately cancels this buff; if the unit loses its equipped item (such as via *Potion of Plunder*), the buff is restored.
  * **Merge Contract**: The ring's bonus is strictly non-stackable across merges and is never baked into inherited stats. When units merge:
    * For an **Evolutionary Level-Up**, if the resulting unit holds no item, the bonus is applied once pre-baked into its stats without triggering an extraneous visual cast (since it is considered the same continuous unit).
    * For a **Recipe Tier Evolution**, the higher-tier unit enters the board as a brand-new entity without pre-baked trinket stats, receiving the *Rusty Ring* buff fresh on board arrival with the complete visual projectile and animation.
* **Death-Reactive Stat Trinkets (*Vengeance Charm*)**:
  * When an ally dies, grants +1 HP and +1 PWR to a random surviving ally.
* **Armor Preservation (*Polished Plate*)**:
  * Armor does not decay at the end of the turn.
* **Elemental Trait Trinkets (*Fire, Earth, Water, Air Trait Trinkets*)**:
  * Activates elemental traits when the team holds the required elemental soul count. Can appear on both player and enemy loadouts.
* **Trinket Buff Delivery (*Twin Charm*)**:
  * Evaluates unit copy thresholds across the team's entire Battle Pool (+1 PWR for every 2 duplicate copies of that unit).
  * When a threshold is reached (via draw, summon, or board entry), the trinket activates on the HUD, firing directional buff projectiles from the trinket bar directly to each eligible unit on the board.
  * During level-up merges, the new unit incorporates its post-merge bonus directly into its baseline stats, preventing duplicate buff animations.
* **Death-Reactive Trinkets (*Token Return Charm*)**:
  * Triggers on the death of the first non-Hero player unit each round.
  * Refunds battle tokens equal to the deceased unit's tier (Tier 1 = 1 token, Tier 2 = 2 tokens, Tier 3 = 3 tokens).
  * Plays an animation of tokens bursting from the fallen unit and flying into the token counter.
  * Strictly limited to once per round.
* **Draw Discount Trinkets (*Bargain Charm*)**:
  * Reduces the token cost of the first gacha draw of each tier per battle by 1 token (minimum 1 token cost).
  * The trinket highlights on the HUD when the discount is applied.

---

# 11. Run Progression, Node Logic & Encounters

Difficulty scales as the player resolves nodes and advances the Day counter, causing enemy teams to generate with larger budgets and more advanced items or trinkets.

## 11.1 Encounter Budget & Difficulty Scaling
* **Daily Budget Formula**: Base budget for encounters is:
  $$\text{Budget} = 3 + (\text{Day} - 1)$$
* **Enemy Purchasing**: The encounter generator purchases enemy units and items using their standard tier gold costs.
* **Elites & Bosses**: Mini-boss and Boss units are free; support units consume **85%** of the daily budget.
* **Boss Reinforcements**: Reinforcements during boss battles consume **33%** of the daily budget.
* **Elite Pity System**: The encounter generator tracks prior elite encounters, reducing weights for recently faced elite variants to guarantee encounter diversity.

## 11.2 Standard Nodes
* **Regular Battles**: Standard budget-based combat encounters.
* **Shop Node**:
  * **Stock**: 3 random GachaBalls drawn exclusively from the World Pool of unlocked definitions.
  * **Reroll Cost**:
    * Base cost: **1 Gold**.
    * Escalation: **+1 Gold** for each subsequent reroll during the same visit.
    * Reset: Resets back to 1 Gold on the next shop visit.
* **Black Market Node**:
  * **Remove**: Permanently purges a GachaBall from the run collection.
    * Base cost: **5 Gold**.
    * Escalation: **+1 Gold** for each subsequent removal during the run.
  * **Transform**: Replaces a GachaBall with a random alternative of the same tier.
    * Flat fee: **5 Gold** (does not escalate).
* **Post-Battle Reward Sequence (`PrizeLineup`)**:
  * **Lineup**: 5 random reward capsules are presented.
  * **Collect Drop Zone**: Free; adds the capsule to the Run Inventory.
  * **Sell Drop Zone**: Sells the capsule for Gold (standard items sell for tier value; Elite rewards grant a flat **10 Gold**).
  * **Auto-Collection**: Leaving the scene with uncollected items triggers automatic sequential collection of all remaining prizes.
  * **Gacha Machines**: Machines remain active in the reward room for spending banked combat tokens. Any unspent tokens are lost upon exiting.

## 11.3 Standalone Encounters
* **Unit Training Ground (Dojo)**:
  * Allows players to permanently train the stats of any unit in their Run Inventory.
  * The player selects a unit and drops it into the HP or PWR training zone, paying a 5 Gold fee to start a study session (Flashcard Minigame).
  * The Gacha Tokens earned during study are spent to roll for permanent stat increases for that unit.
* **Merge Encounter**:
  * Allows players to merge GachaBalls in their Run Inventory directly.
  * Merges here cost a flat fee of **5 Gold** but bypass the usual run-level recipe unlock requirements, permanently unlocking the resulting recipe for the rest of the run.

## 11.4 Surprise Events Pool
Surprise encounters randomly select from a pool of classic resource sites:
* **Rest Site**: The Hero can study and spend Tokens to draw HP buff capsules.
* **Gambling Den**: The Hero can study and spend Tokens to draw Gold bonus capsules.
* **Training Grounds**: The Hero can study and spend Tokens to draw PWR buff capsules.
* Applying drawn capsules permanently upgrades the Hero. Leaving the scene automatically applies any uncollected capsules.

### Training & Resource Site Reward Distributions
Both Hero Training (Rest Site HP, Training Grounds PWR, Gambling Den Gold) and Unit Training Ground (Unit HP/PWR) share a unified, middle-weighted bell curve distribution with rare 0s and rare top prizes:
* **Tier 1 (1 Token)**: Range 0–2
  * `0`: 10% (rare miss)
  * `1`: 80% (middle)
  * `2`: 10% (jackpot)
* **Tier 2 (2 Tokens)**: Range 0–3
  * `0`: 10% (rare miss)
  * `1`: 40% (middle)
  * `2`: 40% (middle)
  * `3`: 10% (jackpot)
* **Tier 3 (3 Tokens)**: Range 0–5
  * `0`: 5% (rare miss)
  * `1`: 15%
  * `2`: 30% (middle)
  * `3`: 30% (middle)
  * `4`: 15%
  * `5`: 5% (jackpot)

### Study Session Activation Rules
* Activating a study session at non-combat nodes requires exactly **5 Gold**.
* Spending gold triggers a visual VFX of gold coins transferring from the player's gold bank to the study button.
* Available strictly once per encounter visit.

---

# 12. UI/UX Hierarchy & Inspection System

## 12.1 Inspection Window Rules
* **Show-before-Measure**: To prevent layout bloat, windows render at alpha `0.0` for 3 frames at an off-screen position (`Vector2(-2000, -2000)`) while Godot resolves internal layout sizing, preventing accidental mouse interception.
* **Immediate Child Pruning**: Dynamic slot grids call `remove_child()` followed by `queue_free()` to eliminate inherited "ghost slots."
* **Hierarchical Chains**:
  * One window chain at a time; one child window per parent.
  * Clicking the background of a group closes the entire chain.
  * Clicking the background of a specific window closes its children only.
  * Opening a new root inspection closes any existing chain.
  * Deselection on action: opening any window deselects active GachaBalls.

## 12.2 Playback Controls & Speed Scaling
* **Supported Speed Presets**: Combat playback provides `1x` (baseline), `2x`, and `4x` playback speed options, along with a `Pause` (`⏸`) toggle.
* **Run-Wide Combat Speed Persistence**:
  * The selected combat speed setting (`1x`, `2x`, `4x`) persists across battles and encounters for the entire run.
  * Setting combat speed to `4x` in a battle preserves that setting when the battle concludes. Progressing through non-combat encounters (Reward, Shop, Rest Site, Minigame, Path Choice) and subsequently entering another Battle or Elite Battle automatically maintains and applies the `4x` speed setting.
* **In-Battle Acceleration Exclusivity**:
  * Speed acceleration (`2x`, `4x`) strictly applies while inside battle encounters (`GameManager.is_in_battle == true`).
  * Outside of combat encounters, `AnimationConstants.is_in_battle` is `false`, ensuring that all non-combat scenes, reward claiming, shop purchases, rest site choices, minigames, and navigation operate at normal `1.0x` baseline speed for optimal readability and natural pacing.
* **Comprehensive Battle Animation Scope**:
  * All visual animations, UI events, and presentation pacing occurring within combat are scaled by the combat speed multiplier:
    * **Unit Combat Animations**: Melee lunges, guardian leaps, bump attacks, death levitation/fade-out, and hurt recoils.
    * **Gacha Machine Animations**: Wheel spins, capsule draws, unit reveal pops, and tray drops.
    * **Elite Enemy Spawns**: Elite capsule launches and arc trajectories to gacha machines.
    * **Resource & Currency VFX**: Gacha token pop, gacha token spend, and gold coin arc/toss physics.
    * **Combat Feedback**: Floating damage numbers, stat modification popups, heal/buff hops, and item status popups.
    * **Inter-Event Pacing**: Elimination of artificial pauses between sequential events—attacks, buffs, and trinket activations chain smoothly as soon as the previous animation finishes, with inter-event delays scaled proportionally.
* **UI Radio-Button State Restoration**:
  * Upon entering any combat scene, `BattleView` reads `AnimationConstants.speed_factor` and styles the speed button group (`⏸`, `1x`, `2x`, `4x`).
  * The button corresponding to the active preserved speed displays the active highlight (blue background and border) while other buttons display the inactive dark style.
* **Battle Entry Pause State Reset**:
  * The pause state is transient to the specific combat encounter. When a battle concludes or a new battle begins, the pause state resets to unpaused (`_is_paused = false`).
  * Combat in the new battle begins running continuously at the preserved speed setting without requiring the player to manually unpause.
* **Pause Toggle Control**:
  * Clicking `⏸` immediately freezes combat playback. Clicking `⏸` again resumes continuous playback at the active speed setting.
  * Clicking any speed button (`1x`, `2x`, `4x`) unpauses combat and applies that speed.
  * Step-by-step debug advance controls and on-screen event description text have been completely removed.
* **Multi-Stat Buff Projectile Staggering**:
  * When an ability or trinket (such as Rusty Ring or Royal/Veteran Insignia) grants multiple stats (e.g. +1 HP and +1 PWR) to the same target unit, the HP projectile launches first, followed by the PWR projectile after a 0.15s delay (scaled by the active combat speed).
  * Upon arrival, HP and PWR deltas apply consecutively upon their respective projectile impacts, ensuring that distinct numbers and arcs are clearly legible without visual collision or overlap.
* **Replay & Spectator Speed Compounding**:
  * In-game combat speed changes are recorded as meta-actions (`SetCombatSpeedAction`, `PauseRunAction`).
  * In replay playback, recorded in-game speed settings compound multiplicatively with spectator speed controls:
    $$\text{Effective Speed} = \text{Base Combat Speed} \times \text{Replay Speed Multiplier}$$

---

# 13. Risk Calculation Framework

The game's tactical depth is governed by transparent, calculable risk vectors:

## 13.1 Draw Probability
* If a Tier Pool contains $N$ Gachaballs:
  $$\text{Chance of specific Gachaball} = \frac{1}{N}$$
* Because all pool contents and quantities are transparently visible, the player can inspect machines and calculate exact draw probabilities manually at any time.

## 13.2 Merge Risk
* Merging increases unit density, stat density, and item quality focus.
* Merges are **irreversible** during battle. Sacrificing multiple board bodies for a single concentrated unit risks vulnerability to single-target debuffs or spikes damage.

## 13.3 Token Banking Risk
* Gacha Tokens carry over between turns within a single battle.
* Banking tokens increases future draw flexibility on subsequent turns at the cost of field presence and combat power for the current turn.

## 13.4 Tier Compression Risk
* Tier 3 GachaBalls:
  * Cost **4 Gold** in the macro economy.
  * Cost **3 Tokens** in the battle economy.
  * Provide high slot efficiency and high stat ceilings, but lower raw base stats per gold than an equivalent Tier 1 swarm.

---

# 14. The Economic Theory of Board Value

To preserve game balance and strategic solvability, the following principles govern the game's economy:

1. **The Board Value Equation**:
   $$\text{Board Value} = \sum \text{Unit Base Packages} + \text{Interaction Surplus}$$
   * *Unit Base Package*: The baked-in base stats and single item slot provided by the unit definition.
   * *Interaction Surplus*: Value created through synergies, abilities, and buffs that allows the team to exceed its raw stat budget.
2. **The Gold Standard**: $1 \text{ Gold or Token} \approx 3 \text{ HP or } 2 \text{ PWR}$.
   * *Leveling*: Adds exactly **+1 Stat Point** to both HP and PWR per level.
3. **Stat Hierarchy**: $\text{PWR} > \text{HP}$. PWR is the primary variable scaling multiplicative combat actions.
4. **Economic Duality**:
   * *Run Economy (Deck Curation)*: Gold is invested into deck curation. Dilution reduces draw reliability.
   * *Battle Economy (Realization)*: Tokens are invested during combat to realize the potential of the curated deck.
5. **Mitigation First**: Remove and Transform mechanics at the Black Market are essential tools to maintain a lean, high-consistency deck.
6. **Unified Single Item Slot Constraint**:
   All units (including the Hero) are strictly restricted to **one single item slot**:
   * Tier 0 (Hero): 1 Slot
   * Tier 1: 1 Slot
   * Tier 2: 1 Slot
   * Tier 3: 1 Slot

---

# 15. Adjustable Balance Levers

The following variables serve as safe tuning levers that affect game difficulty without altering the deterministic combat contract:
* **Token gain rate** (flashcard rewards)
* **Flashcard timer length** (mini-game duration)
* **Tier draw costs** (1, 2, 3 token baseline)
* **Encounter budget scaling** (daily budget formula)
* **Base unit stats** (HP and PWR per tier/definition)
* **Merge recipes availability** (discovery requirements)
* **Shop reroll cost** (base fee and escalation)
* **Enemy reinforcement strength** (summon budgets)

---

# 16. Strategic Risk Review & System Safeguards

This section documents systemic risks identified during architectural review and the intended solutions or monitoring strategies to preserve game identity while ensuring long-term balance, clarity, and replayability.

## 16.1 Infinite Scaling – Design Position

### Design Intent
Infinite scaling (HP, PWR, stat gain, token scaling, gold scaling) is allowed by design. The system assumes:
* Both Player and Enemy teams can scale.
* Scaling can be countered (PWR steal, PWR halve, summon pressure, pollution, item stripping).
* The battle becomes a contest of engine construction, not raw stats.
* Scaling is not considered a flaw; it is a fundamental feature.

### Real Risk Identified
The main risks are:
* **UI Breakdown** (large unreadable numbers).
* **Dominant Engine Emergence** (meta collapse).
* **Non-interactive scaling loops**.
The primary concern is visual clarity, not mathematical overflow.

### Resolution Strategy (Stat Cap for Readability)
* **HP and PWR on-card displays are visually capped at 99 (or 100)**.
* Status stacks follow a 2-digit maximum display rule.
* Scaling above the cap is truncated visually while deterministic mathematical calculations continue behind the scenes. This preserves deterministic math, counter-scaling dynamics, and clean UI readability.

---

## 16.2 Counter-Scaling Philosophy
The system assumes any scaling strategy must be counterable. Examples:
* **PWR steal** (Air trait)
* **PWR drain items**
* **Burn** (percentage-like scaling pressure ignoring armor)
* **Pollution** (gacha dilution)
* **Durability pressure & Item Stripping** (*Potion of Plunder*)
* **Token punishment bosses**

Meta-breaking tools must always exist. Balance is achieved via ecosystem pressure, not arbitrary stat nerfs.

---

## 16.3 Boss Design Evolution

### Identified Weakness
Legacy bosses functioned primarily as stat walls by summoning units and increasing stats passively.

### Design Direction
Bosses must function as strategic puzzles that:
* Create board-state puzzles.
* Force build adaptation.
* Punish narrow scaling engines.
* Interact directly with minigame performance.

**Archetype Directions:**
* *Pollution Boss*: Floods player draw pools with low-tier clutter.
* *Scaling Inversion Boss*: Converts high player PWR into vulnerability.
* *Examiner Boss*: Minigame accuracy directly modifies the boss's action budget.
* *Durability Breaker Boss*: Targets and strips equipped items.

---

## 16.4 Flashcard-Based Pacing System
Boss appearance timing scales with Flashcard Mastery progression:
* **Rule**: Higher mastery $\rightarrow$ Boss encounters occur earlier; Lower mastery $\rightarrow$ Boss encounters are delayed.
* **Rationale**: Skilled players get accelerated challenge; struggling players receive extended preparation time. Flashcard performance directly modulates run tempo.

---

## 16.5 Run Failure Philosophy
Runs are fast, deterministic, and recoverable through learning. Even failed runs provide:
* Flashcard practice.
* Knowledge retention.
* Improved minigame performance next run.

No run is wasted time. Out-of-game knowledge mastery replaces permanent in-game power creep.

---

## 16.6 RNG Mitigation & Player Agency
Although gacha draws are random within tier pools, player agency exists through:
* Full pool visibility.
* Exact probability calculation.
* Tier selection and token banking.
* Reroll mechanics.
* Merge planning and recipe tracking.
* Trait commitment and trinket adaptation.

Failure due to RNG is acceptable only if runs are fast, recovery potential exists, and player skill can compensate long-term.

---

## 16.7 Trait System Expansion Requirement
Trait balance symmetry must be intentional:
* Fire & Earth scale vertically (3–5–7–9 tiers).
* Water & Air provide defined utility and disruption (2–4–6–8 tiers).

---

## 16.8 Enemy Template Diversity
To prevent single-build dominance, encounters incorporate diverse archetype templates:
* Summon-heavy boards.
* Anti-scaling boards.
* Pollution boards.
* Durability destruction boards.
* Token punishment boards.
* Trait-disruption boards.

---

## 16.9 Long-Term Replayability Strategy
Replayability stems from:
* New flashcard decks (real-world learning progression).
* New units and merge trees.
* New traits and trinkets.
* Achievement-based challenge runs (e.g., Win using only Tier 1 units, Win without merging, Win with 0 Fire Souls).

Replayability focuses on mastery variation, not permanent stat inflation.

---

## 16.10 Clarity as a Core Design Constraint
All abilities must:
* Clearly state their trigger.
* Clearly state their target and effect.
* Avoid ambiguous phrasing or hidden modifiers.

Clarity is a non-negotiable design pillar.

---

## Final Strategic Position
*Flashcard Heroes* is designed as a deterministic scaling auto-battler where knowledge mastery fuels tactical resource generation and build construction is a contest of engine design under full information.

---

# 17. Progression & Meta-Systems

## 17.1 Achievement & Unlocks
* **Unlocking**: Permanent content (Heroes, Decks, Recipes) is unlocked by completing milestones managed by `AchievementManager`.
* **The Codex**: A global registry displaying all unlocked `GachaBallDefinition`s, items, and discovered `MergeRecipe`s, accessible from the main menu.

## 17.2 Run Progression
* **Difficulty Scaling**: The `Day` counter increments `EncounterGenerator` budgets following $3 + (\text{Day}-1)$.
* **Boss Milestones**: Boss battles trigger dynamically at deck unlock thresholds (every 20% for full decks, every 33.3% for half decks).

---

# 18. Game Actions & Input Gating (Player Contract)

The game follows a strict **Command Pattern** (modeled after *Slay the Spire 2*):

## 18.1 The Single Pipeline Rule
Every player input that alters game state, advances game flow, dismisses a gating modal, or progresses a room **MUST** instantiate a validated `GameAction` and submit it to `ActionQueue.request(action)`:
* **Battle Actions**: `DrawGachaAction`, `MoveInventoryAction`, `ConfirmMergeAction`, `ConfirmSwapAction`, `EndTurnAction`.
* **Flow & Modals**: `AcknowledgeBattleResultsAction`, `AcknowledgeFlashcardIntroAction`, `DismissTutorialAction`, `PauseRunAction`, `SetCombatSpeedAction`.
* **Room Transactions**: `BuyShopAction`, `RerollShopAction`, `CollectRewardAction`, `SellRewardAction`, `TrainUnitStatAction`, `RemoveBlackMarketAction`, `TransformBlackMarketAction`, `LeaveShopAction`, `LeaveRewardAction`, `LeaveTrainingAction`, `LeaveRestSiteAction`, `LeaveBlackMarketAction`.

## 18.2 Presentation-Only Inputs
Inputs that do **NOT** alter game data or gate progress are presentation-only and bypass `ActionQueue`:
* Passive mouse movement and hover highlights.
* Hover peeking to inspect unit/item tooltips (`WindowManager.open_inspection_window`).
* Toggling gacha machine inventory previews.
* Audio volume slider adjustments in settings.

## 18.3 Input Gating
While `ActionQueue` is processing an action and its visual animations (`is_busy() == true`), all player input is physically blocked. This guarantees zero race conditions, prevents duplicate item glitches, and enables flawless deterministic session replays and headless QA bot testing.
