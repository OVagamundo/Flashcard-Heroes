# Suggestions & Analysis: Validated Systems & Content (V8)



Temporary Stat Modification (StS style): Gaining high stats for a single turn or sigle use with a "stat decay" at on_turn_end. This is useful for high-burst puzzles, maybe through a "Strenghten" stat effect, same for "weaken".
Machine Thinning (StS style): Permanent removal of a Gachaball from a Tier pool for the rest of the battle to increase the probability of drawing specific units. maybe a unit that "Absorbs" allies to buff itself and that removes then from the battle pool.
Vulnerability/Weakness Modifiers: deterministic flat damage increases. Example: "Target takes +2 damage from all attacks this turn".
Soul Thresholds: Massive bonuses that trigger only when reaching high Soul counts (e.g., 7 or 9 Souls). bonus can be stat increases or stat effects.

II. Expanded Trinket Pool (40+ Suggestions)
These trinkets utilize the Tag System (FRONT_LINE, TANK, Merged, etc.) and deterministic resource management.
Economy & Token Management
Inheritance Tax: When a cretain tag unit dies (for instance a wind unit), refund 1 Token for the next turn.
Bulk Discount: Drawing 3 units from the same Tier machine in one turn makes the 4th draw free. or if the player draws one from each machine in the same turn gain one token on the next turn.
Investment Plan: Every turn, the Hero gains +2 HP and +2 PWR. (hero passive?)
Tag-Specific Synergies
Phalanx Shield: All FRONT_LINE units share 50% of any Armor gained by Slot 1.
Heavy Artillery: BACK_LINE units gain +3 PWR if the slot directly in front of them is empty.
Vanguard Spikes: TANK units gain +2 Spikes if they are in the frontmost slot 1.
Assassination Blade: Armor piercing item, ignore all enemy Armor.
Steady Pulse: SCALER units gain +1 HP every time an ally attacks.
Mercenary Contract: MERCENARY units grant +1 Token when drawn from a machine.
Elite Training: ELITE (Tier 2, or fire, or tank, etc) units gain +2 HP and +2 PWR when summoned or Drawn.
Performance & Flashcard Interaction
Scholar's Might: Grant +2 secs to the mini game timer.
Extra points: every 3 correct answers, gain + 1 token per mini game.
Knowledge Surge: If a card has the lowest Mastery, it grants +1 extra Token when answered correctly.
Knowledge Surge: If a card has the highest Mastery, it grants +1 extra Token when answered correctly.
Combat & Formation Triggers
Toxic Spill: on_death: Apply 3 Burn to the enemy in the mirror slot.
Static Discharge: Every time you perform a Merge (on_merge), deal 3 damage to the front or backmost enemy.
Momentum Gear: on_attack: The unit behind the attacker gains +1 PWR.
Action potion (consumable): Makes unit execute it´s "turn action" during management phase.
Voodoo Doll: All enemies start the battle with 2 Burn stacks.
Reactive Plating: Any unit with Armor reflects 1 damage back to the attacker on_hurt.

Path & Run Progression
Meditation Mat: grants +3 Tokens at the start of every battle (on_battle_start).
Broken Compass: Paths choices are hidden, the player gains +2 extra Gold per day.
Crafting Table: Unlocks all tier 3 recipes.

III. New Items & Consumables
Tier 3 Item Merges (System-Native)
Commander’s Horn (Summon Scroll + Bloodlust Blade): on_kill: Summon a Tier 1 unit in the Frontmost available empty slot.
Vitality Bell (Summon Scroll + Large Potion): on_ally_summon: Heal the summoned unit for 4 HP.
Static Cloak (Bloodlust Blade + Summon Scroll): on_draw: Deal 3 damage to a random enemy.
New Consumables (Management Phase Only)
Polishing Cloth (Tier 1): Remove all status effect (e.g., Burn, armor, etc) from a target unit.
Direct damage (Tier 2): deals 4 flat damage to the target.
Burn scroll (Tier 2): adds 4 stack of burn to the target. 
Refund (Tier 3):Removes the target unit/item to gain Tokens equal to its Tier.
X blade (tier 3):  gives 3PWR and gains +3  PWR  per  copy of this item in the battle pool.

New Stattus effects:
Plating: stat effect that decays by 1 stack per turn and maintains all armor while stacks are > than zero. 
Strenghten: stat effect that decays by 1 stack per turn and increases PWR by number of stacks. 
Weaken: stat effect that decays by 1 stack per turn and decreases PWR by number of stacks.
Frozen: prevent unit from acting, decays by 1 stack per turn and/or per hit. 

1. The Global Tagging System
To enable the new effects in the lists below, all GachaBalls (Units/Items) now carry these intrinsic attributes besides souls or tier:
Role Tags: TANK (High HP/Armor), Bruisers (damage dealer), HEALER (Sustain), Suppoert (Support).
Position Tags: FRONT_LINE (Slots 1-2), MID_LINE (Slot 3), BACK_LINE (Slots 4-5).
Origin Tags: SUMMONED (Created mid-battle), MERGED(created by merging in or outside battle)

3. Tier 3 Units

Mimic x2
Mimic Lord
4 Water
Perfect Mimicry (on_turn_start): Inherits the current HP and PWR of the mirror slot enemy.

Merchant x2 (Tycoon)
Shopping spree (on_draw): gain 1pwr per spent 1 Gacha Token.
Wretch x2 (Clay Colossus)
Hardened Shell (on_hurt): Gain +2 Armor and +2 Spikes.
Wisp x2 (Boiler Titan)
Pressure Release (on_healed): Deal 4 damage to the front enemy.
Templar x2 (High Templar)
Divine Treasury (on_turn_start): Gain +1 PWR for every 3 Tokens in bank.
Kite x2 (Solar Phoenix)
Rebirth (on_death): Summon a Tier 1 unit with +3 HP and PWR.
3.2 Hybrid Capstones (45 Units)
Paladin + Mimic: Reflective Guard (on_hurt): Gain Armor equal to the attacker's PWR.
Paladin + Cloner: Echo Knight (on_attack): Clone the Ability of the ally in front st turn start.
Paladin + Wretch: Silt Guard (on_hurt): Grant 2 Armor + 1 spike to the unit behind.
Paladin + Merchant: Iron Banker (on_turn_end): Gain +1 HP for every 5 Gold held.
Paladin + Wisp: Steam Paladin (on_healed): Gain +2 Armor.
Paladin + Kite: Solar Sentinel (on_turn_start): All Fire allies gain 2 Armor.
Paladin + Templar: Zealot (on_attack): The frontmost ally gains +2HP.
Berserker + Mimic: Blood Mirror (on_ally_hurt): Deal 1 damage to the front enemy.
Berserker + Cloner: Phantom Slayer (on_attack): If this kills the target, gain +3 PWR.
Berserker + Wretch: Magma Hulk (on_hurt): Apply 2 Burn stacks to the attacker.
Berserker + Merchant: Sellsword (on_kill): Gain 2 Gold.
Berserker + Wisp: Steam Reaver (on_turn_start): Deal 2 damage to all enemies.
Berserker + Kite: Inferno Strider (on_attack): If target has Burn, attack again.
Berserker + Templar: Inquisitor (on_attack): Remove all Armor from the target before damage.
Mimic + Cloner: Void Double (on_draw): Create a copy of this on the inventory, adds +2PWR per Copy of this unit in the battle pool.
Mimic + Knight: Swap (on_before_damage): Swap the backmost enemy unit with frontmost enemy unit.
Mimic + Wretch: Ooze Lord (on_death): Summon two Tier 1 units.
Mimic + Merchant: Counterfeiter (on_merge): Gain 1 Gold.
Mimic + Wisp: Mist Walker (on_turn_start): Front ally gains 2 stacks of "Strenghten".
Mimic + Kite: Fire Mirage (on_attack): Target gets 2 stacks of "weaken".
Mimic + Templar: Oracle (on_draw): while this unit is in the board, drawn units gain +1 PWR and 1 HP.
Cloner + Knight: Echo Warden (on_ally_death): Gain dead ally's total PWR.
Cloner + Wretch: Dust Stalker (on_turn_end): Random enemy get one stack of Frozen.
Cloner + Merchant: Broker (on_token_spent): Gain +1 HP per Tokens spent.
Cloner + Wisp: Fusion Warden (on_merge): On board, gain +2 HP/+2 PWR.
Cloner + Kite: Flash Fire (on_attack): Apply 1 Burn to all enemies.
Cloner + Templar: Spirit Link (on_stat_increased): Buff adjacent allies +1/+1.
Knight + Wretch: Clay Knight (on_draw or summon): gain 5 stacks of Plating.
Knight + Merchant: Caravan Guard (on_turn_start): Grant +2 Armor AND 1 PLATING to Frontmost unit.
Knight + Wisp: Steam Knight (on_attack): Push target to one slot after damage (swap).
Knight + Kite: Sky Knight (on_attack): Target the highest PWR enemy.
Knight + Templar: High Crusader (on_attack): Heal Hero for 2 HP.
Wretch + Merchant: Excavator (on_kill): Gain 1 Token for next turn.
Wretch + Wisp: Geyser (on_turn_end): Deal 2 damage to all enemies.
Wretch + Kite: Dust Devil (on_hurt): Attacker loses 1 PWR.
Wretch + Templar: Deep Priest (on_healed): Gain +1 PWR.
Merchant + Wisp: Trader (on_draw): draw a tier 1 gachaball.
Merchant + Kite: Black Marketeer (on_turn_start): Gain 2 Token if on the lineup and if opposing team lineup is full.
Merchant + Templar: High Broker (on_turn_end): Gain 1 Token if on lineup.
Wisp + Kite: Storm Cloud (on_attack): Deal 2 extra damage to random enemy.
Wisp + Templar: Cloud Caller (on_turn_start): Heal one ally of each tier 2HP, including the Hero but not itself.
Kite + Templar: Wind Speaker (on_attack): Steal 2 PWR from target.

4. New Items & Consumables
4.1 Tier 3 Item Merges (6 Total)
Filling the combinations of T2 items: Summon Scroll (S), Bloodlust Blade (B), Large Potion (L).
S + S: Healing Totem (on_hurt): Heal 2 random allies.
B + B: War Banner (on_attack): Buff 2 random allies +2 PWR.
L + L: Retaliation Shield (on_hurt): Counter-attack a random enemy.
S + B: Commander's Horn (on_kill): Summon a Tier 1 unit.
S + L: Vitality Bell (on_ally_summon): Heal summoned unit for 2 HP.
B + L: Vampiric Dagger (on_damage_dealt): Lifesteal based on damage.
4.2 New Consumables
Polishing Cloth (T1): Remove one Status Effect (e.g., Burn) from a unit.
Poison of Weakeness (T2): adds 3 stacks of weakness to the target.
Midas Touch (T3): Remove a unit on bench; gain Tokens equal to its Tier.

5. 20 New Strategic Trinkets
Vanguard Plate: FRONT_LINE units gain +5 HP / -2 PWR on combat start (after end turn btt is pressed).
Archer’s Scope: Deal +2 damage to a random unit on combat start.
Heavy Reinforcements: TANK units gain 2 Spikes at battle start.
Elite Contract: First Tier 3 Gacha draws of that turn cost 2 Tokens instead of 3.
Loyalty Card: Every 4th draw from a tier machine is free (0 cost).
Cram Session: The first 3 Flashcards questions of a battle grant double Tokens.
Static Discharge: Every time a Merge occurs, deal 3 damage to a random enemy.
Savings Account: Turn end: Gain 1 Armor per 2 Tokens in bank.
Recycling Bin: on_death: 20% chance units or items return to bench.
Glass Dagger: All units drawn on the first turn of every battle gain +6 PWR / Start with 1 HP on drawn or summon.
Tactical Reload: Reshuffling a Tier pool grants 3 Tokens.
Strict team: If board has only one tier units at the start of turn (hero does not count), all allies gain +2/+2.
Lead Weights: TANK units gain +2hp on draw/summon and cannot be pushed or moved by abilities.
Chain Reaction: on_kill: previous ally in turn order attacks again.
Momentum: on_attack: Ally behind gains one stack of "strenght".
Trait Echo: on_ally_death: Allies sharing a trait tag with deceased gain +1 HP.
Trait Catalyst: Reduces all Trait soul requirements by 1 (Min. 2).

6. Expanded Traits
Dark Trait (Dark Tag): 3 Souls: on_ally_death: Grant +1 PWR to BACK_LINE units; 6 Souls: on_turn_start: All allies gain 1 pwr on ally death.
light Trait (Light Tag): 3 Souls: on_turn_start: FRONT_LINE units gain 2 Armor; 6 Souls: on_healed: Healed unit gains +1 PWR.

---

## 1. Advanced Mechanics

### 1.1 Enemy Archetype: "The Polluter"
*   **Goal:** Slow down the player's scaling by filling their inventory with "garbage" (or random gachaballs that might not align with the player's strategy or even gachaballs that can hurt the player units when drawn).
*   **Mechanic:**
    *   **Ability:** "At start of turn, add 1 **Rock** (Tier 1 or 2 or 3, 1hp) to Player's Battle Inventory."
    *   **Result:** Player draws Rocks instead of units.
    *   **Counterplay:** Rush down these enemies first.

### 1.2 Boss Mechanic: "The Examiner"
*   **Goal:** Make the Mini-game matter for survival, not just tokens. maybe the boos can have it´s summon budget linked to the mini game results or maybe it´s bonus stats per turn could be linked to it.
*   **Mechanic:**
    *   **Budget System:** Boss has a "Summon Points" budget.
    *   **Interaction:** Every **Correct Answer** reduces the Boss's Summon Points by 1.
    *   **Failure:** player gets overwhelmed by the boss's units.

### 1.3 Trade-off Items (Glass Cannons)
*   **Goal:** High risk, high reward.
*   **Example:** "Cursed Blade" offers Tier 3 stats at Tier 1 cost, but applies "Vulnerable" to the holder permanently, items that give powerful abilities in exchange for stat debuffs.

Consumables

| Name | Type | Effect |
|---|---|---|
| **Chaos Orb** | Consumable | Transform target unit into a random unit of the same Tier. (Reroll). |
| **Midas Touch** | Consumable | Destroy ally unit. Gain Tokens equal to Tier. |
| **Separation Potion** | Consumable | **Unmerge**: Splits a merged unit or item back into its component parts (if space allows).
---

