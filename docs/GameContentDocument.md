# Game Content Document: Flashcard Heroes
**(Synced with Codebase)**

## Recipe Unlock System

**Important**: Merge recipes are LOCKED by default at the start of each run. Recipes only unlock when you acquire the resulting gachaball (via shop purchase, battle reward, etc.). These unlocks are per-run only and reset when starting a new run.

- **Tier 1 units** (Apprentice, Squire) are base units with NO recipes
- **Tier 2+ units** have recipes that unlock upon acquisition
- Example: Buying a Knight from the shop unlocks its recipe (Apprentice + Squire → Knight)

### Ability Stacking Logic
When merging units, all abilities from both parent units are retained in the resulting unit. If identical abilities exist, their effects stack (e.g., two "Resilience" triggers result in two separate heals) unless otherwise specified in the unit's unique script.

## 1. Units
Units are the primary actors in battle. They have Health (HP) and Power (PWR) stats, can equip items, and possess abilities.

### Player Heroes
| ID | Name | Tier | Stats | Abilities |
|---|---|---|---|---|
| `hero_bounty_hunter` | Bounty Hunter | 0 | 10 HP / 2 PWR | **Bounty**: Gain 1 Gold on kill (originates from victim).<br>**Scavenger's Resolve** (`on_ally_death`): Gain +1 HP and +1 PWR when an ally dies.<br>**Quick Wits** (Minigame): +1.0s on correct answer, -0.5s on incorrect. |
| `hero_timekeeper` | Timekeeper | 0 | 50 HP / 2 PWR | **Time Warp**: Gains 10 tokens at start of battle and Rest Sites (Passive).<br>**Temporal Aura**: At start of each turn, grants +2 HP to units in front and +2 PWR to units behind (Passive).<br>**Time Dilation** (Minigame): +1.5s on correct answer, -0.8s on incorrect. |
| `hero_avenger` | Avenger | 0 | 6 HP / 2 PWR | **Leap Attack** (`on_ally_death`): Leap and attack the frontmost enemy. |
| `hero_bastion` | Bastion | 0 | 10 HP / 2 PWR | **Fortify** (`on_ally_death`): Gain 1 Armor and 1 Spikes. Armor does not decay at the end of the turn. |
| `hero_pyro` | Pyromancer | 0 | 8 HP / 2 PWR | **Incinerate** (`on_attack`): Instead of damage, apply Burn stacks equal to PWR. |

### Tier 1 Units (Cost: 1 * 2^(L-1))
| ID | Name | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
|---|---|---|---|---|
| `unit_t1_a` | Apprentice | 2 HP / 1 PWR | 1 Earth | **Resilience** (`on_hurt`): Heal self by PWR `[PWR / PWR+1 / PWR+2]`. |
| `unit_t1_b` | Squire | 1 HP / 2 PWR | 1 Fire | **Retaliation** (`on_hurt`): Counter-attack for PWR damage `[100% / 125% / 150%]`. `[L3: Also gains 1 Armor stack]`. |
| `unit_t1_c` | Protector | 1 HP / 1 PWR | 1 Water | **Guardian's Grace** (`on_ally_hurt`): When ally directly in front takes damage, heal them for PWR `[100% / 150% / 200%]`. |
| `unit_t1_d` | Empath | 1 HP / 1 PWR | 1 Wind | **Empathic Link** (`on_death`): On death, grant total current PWR to ally behind `[100% / 150% / 200%]`. |

### Tier 2 Units (Cost: 2 * 2^(L-1))
| ID | Name | Merge Recipe | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
|---|---|---|---|---|---|
| `unit_t2_c` | Knight | **Apprentice + Squire** | 3 HP / 3 PWR | 1 Fire, 1 Earth | **Morale Boost** (`on_ally_death`): Gain `[+1/+1, +2/+1, +2/+2]` HP/PWR. |
| `unit_t2_d` | Templar | **Squire + Empath** | 2 HP / 3 PWR | 1 Water, 1 Wind | **Gacha Power** (`passive`): PWR is equal to Gacha Tokens `[(Min 1) / (Min 2) / (Min 3)]`. PWR buffs convert to HP at `[100% / 150% / 200%]` effectiveness. |
| `unit_t2_f` | Merchant | **Apprentice + Empath** | 3 HP / 2 PWR | 1 Earth, 1 Wind | **Gold Investments** (`on_draw`, `on_battle_start`): Initial PWR equals your current Gold multiplied by `[1.0 / 1.5 / 2.0]` when drawn or spawned. |
| `unit_t2_h` | Hermit | **Protector + Empath** | 2 HP / 2 PWR | 1 Water, 1 Wind | **Solitary Strength** (`on_pre_combat`): Start of Combat (Lineup Only): Gains `[+1/+1, +2/+2, +3/+3]` HP/PWR per empty lineup slot. |
| `unit_t2_i` | Mud Wretch | **Apprentice + Protector** | 3 HP / 2 PWR | 1 Earth, 1 Water | **Mud Coating** (`on_healed`): When healed, gain `[+1/+1, +2/+1, +2/+2]` Armor/Spikes stacks. |
| `unit_t2_j` | Steam Wisp | **Squire + Protector** | 2 HP / 3 PWR | 1 Fire, 1 Water | **Scald** (`on_healed`): When healed, deal damage to the front enemy equal to `[100% / 150% / 200%]` of the heal amount. |

### Tier 3 Units (Gold Cost: 4 * 2^(L-1) | Draw Cost: 3 Tokens)
| ID | Name | Merge Recipe | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
|---|---|---|---|---|---|
| `unit_t3_a` | Duelist | **Merchant + Steam Wisp** | 5 HP / 5 PWR | 4 Fire | **Mirror Strike** (`on_attack`): Attacks enemy in opposite mirror slot. If empty, targets backmost enemy. Deals `[100% / 125% / 150%]` damage. |
| `unit_t3_b` | Guardian | **Knight + Hermit** | 5 HP / 5 PWR | 4 Earth | **Guardian Sacrifice** (`on_before_damage`): Leaps to intercept lethal damage on allies. Gains `[2 / 4 / 6]` temporary Armor upon interception. |
| `unit_t3_c` | Necromancer | **Merchant + Templar** | 5 HP / 5 PWR | 2 Fire, 2 Earth | **Soul Summon** (`on_death`): Summons a Tier 2 unit on death at Level `[1 / 2 / 3]`. |
| `unit_t3_d` | Warden | **Knight + Mud Wretch** | 6 HP / 5 PWR | 2 Fire, 2 Earth | **Resilient Aura** (`on_hurt`): Grants `[+1/+1, +2/+1, +2/+2]` HP/PWR to adjacent allies. |
| `unit_t3_e` | Assassin | **Knight + Merchant** | 6 HP / 5 PWR | 3 Fire, 1 Earth | **Ambush Predator** (`on_enemy_summon`): Deals damage to enemies equal to `[100% / 150% / 200%]` of PWR when they are summoned. |
| `unit_t3_f` | Summoner | **Mud Wretch + Templar** | 5 HP / 5 PWR | 1 Fire, 3 Earth | **Summon Blessing** (`on_ally_summon`): Heals allies for `[2 / 4 / 6]` HP when they are summoned. |
| `unit_t3_g` | Phantom Wayfarer | **Templar + Hermit** | 4 HP / 5 PWR | 4 Wind | **Quiet Meditation** (`on_turn_start`): If on bench, gain `[+3/+3, +4/+4, +6/+6]` HP/PWR. **[Player Exclusive]** |
| `unit_t3_h` | Fusion Warden | **Mud Wretch + Steam Wisp** | 5 HP / 5 PWR | 1 Fire, 1 Water, 2 Wind | **Convergence Surge** (`on_merge`): If on board when a merge happens, gain `[+2/+2, +3/+3, +4/+4]` HP/PWR. |
| `unit_t3_i` | Doppleganger | **Mud Wretch + Hermit** | 5 HP / 4 PWR | — | **Mirrored Might** (`passive`): `[+3 / +4 / +5]` PWR for every other Doppleganger in the Battle Pool.<br>**Clone Split** (`on_death`): Spawn `[1 / 1 / 2]` additional Dopplegangers into the Gacha Machine. **[Player Exclusive]** |
| `unit_t3_paladin` | Paladin | **Knight + Templar** | 5 HP / 6 PWR | 2 Earth | **Defensive Stance** (`on_before_damage`): Gain `[+2, +4, +6]` HP before taking damage. |
| `unit_t3_berserker` | Berserker | **Knight + Steam Wisp** | 5 HP / 6 PWR | 2 Fire | **Shockwave** (`on_attack`): Deals cascade AOE damage to front enemy and units behind for `[50% / 75% / 100%]` of PWR. |
| `unit_t3_mimic` | Mimic | **Mud Wretch + Merchant** | 6 HP / 4 PWR | 2 Water | **Mirror Transformation** (`on_turn_start`): Transforms into the enemy unit in the mirror slot. Level matches target level `[+0 / +1 / maxed out]`. |
| `unit_t3_shadow` | Shadow Cloner | **Steam Wisp + Hermit** | 4 HP / 5 PWR | 1 Wind | **Buff Echo** (`on_stat_increased`): Repeats any buff received by an adjacent ally at `[100% / 150% / 200%]` effectiveness. |
| `unit_t3_j` | Standard Bearer | **Steam Wisp + Templar** | 5 HP / 5 PWR | 1 Fire, 2 Water, 1 Wind | **Standard's Legacy** (`on_death`): On death, transfers its equipped item to the ally directly behind it. |
| `unit_t3_l` | Golden Hermit | **Hermit + Merchant** | 5 HP / 4 PWR | 1 Earth, 1 Water, 2 Wind | **Wealth Accumulation** (`on_turn_start`): At the start of each turn, gain +3 HP and +3 PWR for every 5 Gold you have. **[Player Exclusive]** |


### Enemies
| ID | Name | Stats | Type | Abilities |
|---|---|---|---|---|
| `enemy_hero` | Enemy Hero | 10 HP / 2 PWR | Boss | (None by default) |
| `unit_dust_t1` | Dust Minion (T1) | 1 HP / 0 PWR | Support | **Basic Attack**: Attacks for 0 damage. |
| `unit_dust_t2` | Dust Minion (T2) | 1 HP / 0 PWR | Support | **Basic Attack**: Attacks for 0 damage. |
| `unit_dust_elite_t2` | Dust Sentinel (Elite T2) | 3 HP / 1 PWR | Elite | **Dust Pulse (Death)**: Summons a Dust Minion (T2) whenever an ally dies. |
| `unit_dust_elite_t3` | Dust Overlord (Elite T3) | 3 HP / 1 PWR | Elite | **Dust Pulse (Multi)**: Summons random Dust Minions (T1/T2) on Turn Start, On Hurt, On Attack, and On Ally Death. |
| `boss_1` | The Awakened Guardian | 10 HP / 10 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Draining Presence** (`on_draw`): Gains +1 HP when player draws from gacha. |
| `boss_2` | The Shadow Warden | 15 HP / 15 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Token Hunger** (`on_token_spent`): Gains +1 HP for each token the player spends. |
| `boss_3` | The Storm Herald | 20 HP / 20 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Storm Rising** (`on_ally_death`): Gains +1 HP and +1 PWR for each ally that died this combat (Triggers on Turn Start). |
| `boss_4` | The Ancient Titan | 25 HP / 25 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots. |
| `boss_5` | The Final Arbiter | 30 HP / 30 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots. |

---

## 2. Items
Items are equipped on units to provide stats and new abilities.

### Tier 1 Items (Cost: 1)
| ID | Name | Stats | Ability |
|---|---|---|---|
| `item_t1_a` | Koi's Blessing (Small HP Potion) | +1 HP | **Restoration** (`on_turn_start`): Heal holder 2 HP. |
| `item_t1_b` | Tiger's Spirit (Small PWR Potion) | +1 PWR | **Extra Attack** (`on_attack`): When attacking, if target has more HP than holder, perform an extra attack. |

### Tier 2 Items (Cost: 2)
| ID | Name | Merge Recipe | Stats | Ability |
|---|---|---|---|---|
| `item_t2_a` | Summoning Scroll (Summon Scroll) | **Koi's Blessing + Koi's Blessing** | +2 HP | **Summon** (`on_death`): Summons a random Tier 1 unit. |
| `item_t2_b` | Bloodlust Edge (Bloodlust Blade) | **Tiger's Spirit + Tiger's Spirit** | +2 PWR | **Bloodlust** (`on_kill`): When holder defeats an enemy, act again immediately. |
| `item_t2_c` | Phoenix Elixir (Large HP Potion) | **Koi's Blessing + Tiger's Spirit** | +1 HP / +1 PWR | **Regeneration** (`on_hurt`): When hurt by an attack, heal holder 1 HP and gain +1 PWR (non-lethal only). |
| `item_t2_d` | Echoing Orb | N/A | +0 HP / +0 PWR | **Resonance** (`on_board_changed`): Gains PWR for each other Echoing Orb in battle.<br>**Echo Split** (`on_death`): Copy self to the Gacha Machine of the same tier. **[Player Exclusive]** |

### Tier 3 Items (Gold Cost: 4 | Draw Cost: 3 Tokens)
| ID | Name | Merge Recipe | Stats | Ability |
|---|---|---|---|---|
| `item_t3_a` | Heart Stone (Healing Totem) | **Summoning Scroll + Summoning Scroll** | +4 HP | **Vital Link** (`on_hurt`): When holder is hurt by an attack, heal two random allies for 2 HP each. |
| `item_t3_b` | Power Amulet (War Banner) | **Bloodlust Edge + Bloodlust Edge** | +4 PWR | **Battle Cry** (`on_attack`): When holder attacks, grant +2 PWR to two random allies. |
| `item_t3_c` | Lifesteal Ring (Vampiric Dagger) | **Bloodlust Edge + Summoning Scroll** | +2 HP / +2 PWR | **Vampiric Strike** (`on_damage_dealt`): On dealing damage, heal holder for 20% of damage dealt (min 1 HP). |
| `item_t3_d` | Vengeful Thorn (Retaliation Shield) | **Phoenix Elixir + Phoenix Elixir** | +2 HP / +2 PWR | **Retaliation** (`on_hurt`): When hurt by an attack, deal half of the holder's PWR as damage to a random enemy. |
| `item_t3_e` | Death's Bargain (Deathbomb) | **Summoning Scroll + Phoenix Elixir** | +3 HP / +1 PWR | **Final Strike** (`on_death`): When holder dies, deal damage equal to half of the highest HP enemy's HP to that enemy. |
| `item_t3_f` | Soul Siphon | **Bloodlust Edge + Phoenix Elixir** | +1 HP / +3 PWR | **Power Drain** (`on_damage_dealt`): After dealing damage, steal half of target's PWR (min 1). |
| `item_emblem_fire` | Fire Emblem | Obtained from boss/rewards | +2 PWR | **Fire Soul** (`passive`): Counts as a Fire unit and grants the Fire trait. |
| `item_emblem_earth` | Earth Emblem | Obtained from boss/rewards | +4 HP | **Earth Soul** (`passive`): Counts as an Earth unit and grants the Earth trait. |
| `item_emblem_water` | Water Emblem | Obtained from boss/rewards | +2 HP / +1 PWR | **Water Soul** (`passive`): Counts as a Water unit and grants the Water trait. |
| `item_emblem_air` | Air Emblem (Wind Emblem) | Obtained from boss/rewards | +2 HP / +1 PWR | **Air Soul** (`passive`): Counts as an Air unit and grants the Air trait. |

---

### Consumables
Consumables are one-time use items during the Management Phase. Their Gold cost is equal to their Tier.
| ID | Name | Tier | Effect |
|---|---|---|---|
| `item_potion_t1` | Minor Healing Potion | 1 | **Heal**: Restores **4 HP** to a target unit. |
| `item_potion_spikes` | Thorn Potion | 2 | **Status**: Grants **4 Spikes** stacks to the target unit. |
| `item_potion_heroism` | Heroism Potion | 2 | **Buff**: Grants **+3 HP**, **+3 PWR**, and **3 Armor** stacks to the target unit. |
| `consumable_potion_plunder` | Potion of Plunder | 3 | **Steal**: Steals a random equipped item from an enemy unit. |

---

## 3. Trinkets
Team-wide passive artifacts obtained from bosses.

| ID | Name | Trigger | Effect |
|---|---|---|---|
| `trinket_polished_plate` | Polished Plate | `passive` | Armor does not decay at the end of the turn. |
| `trinket_aegis` | Aegis Charm (Aegis) | `on_hurt` | Prevents lethal damage once per battle (leaves unit at 1 HP). |
| `trinket_armor_aura` | Armor Aura | `on_turn_start` | Grants 3 **Armor** to all allies. |
| `trinket_burn_vial` | Burn Vial | `on_damage_dealt` | Dealing damage applies 1 **Burn** stack (DoT). |
| `trinket_royal_insignia` | Royal Insignia | `on_draw`, `on_summon` | Grants **+1 HP/+1 PWR** to any **Tier 1** unit entering the board. |
| `trinket_soul_echo` | Soul Echo | `on_ally_death` | Resurrects the **first** non-hero ally to die each turn. |
| `trinket_vengeance` | Vengeance Charm (Vengeance) | `on_ally_death` | Grants **+1 HP** and **+1 PWR** to a random ally. |
| `trinket_trait_fire` | Fire Trait | `passive` | Enables the Fire synergy whenever your team has enough Fire souls. |
| `trinket_trait_earth` | Earth Trait | `passive` | Enables the Earth synergy whenever your team has enough Earth souls. |
| `trinket_trait_water` | Water Trait | `passive` | Enables the Water synergy whenever your team has enough Water souls. |
| `trinket_trait_air` | Air Trait | `passive` | Enables the Air synergy whenever your team has enough Air souls. |
| *N/A* | Cloning Idol | *N/A* | *Historical / Deprecated (Not present in active game files).* |

---

## 4. Traits
Traits are active bonuses based on the composition of your team. Each unit contributes 1 Soul to its corresponding Trait. Equipped **Emblem** items also contribute 1 Soul and allow the equipped unit to benefit from Trait effects.

### Fire Trait (`SOUL_FIRE`)
*Focus: Offensive Pressure & Damage Over Time*

| Souls | Effect |
|---|---|
| **3** | Fire units apply **1 Burn** stack on attack. |
| **5** | Fire units apply **+1 Extra Burn** stack (Total 2 on hit). |
| **7** | Start of Turn: Apply **2 Burn** stacks to the **entire opposing team**. |
| **9** | **Traitor's Flame**: Attacks deal **bonus damage** equal to the target's current Burn stacks. |

### Earth Trait (`SOUL_EARTH`)
*Focus: Defensive Mitigation, Sustain & Damage Reflection*

| Souls | Effect |
|---|---|
| **3** | All Allies gain **1 Armor**; Earth units gain **2 Armor**. |
| **5** | All Allies gain **2 Armor**; Earth units gain **4 Armor**. |
| **7** | All Allies gain **2 Armor + 1 Spike**; Earth units gain **4 Armor**. |
| **9** | **Fortress**: All Allies gain **2 Armor + 2 Spikes**; Earth units gain **4 Armor**. |

### Water Trait (`SOUL_WATER`)
*Focus: Adjacent Healing & Resilience*

| Souls | Effect |
|---|---|
| **2** | At Turn Start: Water units **heal adjacent allies** for 1 HP. |

### Air Trait (`SOUL_AIR`)
*Focus: Power Theft & Disruption*

| Souls | Effect |
|---|---|
| **2** | At Turn Start: Wind units **steal 1 PWR** from the opposite enemy (Mirror slot or backmost enemy; floor: 1 PWR). |

---

## 5. Battlefield Slots
Special slots placed on the battlefield grid that apply persistent or turn-start effects to the units standing on them.

| ID | Name | Trigger | Effect | Cost (Gold) |
|---|---|---|---|---|
| `burn` | Burn Slot | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 |
| `lightning` | Lightning Slot | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 |

---

## 6. Status Effects
Status effects are active modifiers applied to units during combat. They can be applied by unit abilities, traits, items, or battlefield slots.

| ID | Name | Mechanics | Decay Mode |
|---|---|---|---|
| `burn` | Burn | Deals damage equal to the number of stacks at the end of each turn. **Burn damage ignores armor.** | Halved (reduced by 50% rounded down) at the end of each turn. Burn stacks applied by a Burn Slot do not decay. |
| `armor` | Armor | Absorbs incoming direct HP damage (1 point of Armor blocks 1 point of HP damage). Does not block Burn or Static damage. | Decays to 0 at the end of each turn unless preserved by specific abilities (e.g. Bastion's Fortify) or trinkets (e.g. Polished Plate). |
| `spikes` | Spikes | Deals PWR damage back to attackers when hit by a direct attack. | Does not decay. |
| `static` | Static | Consumed stack-by-stack when the holder suffers any form of stat change (HP damage, healing, or power modification). Consuming a stack deals 1 armor-ignoring damage to the unit. | Does not decay. Stacks are only consumed by stat changes. |

---

## 7. Encounter & Budget Systems

### Daily Budget Formula
The game allocates a precise amount of gold for enemy recruitment every day. The system ensures the entire budget is spent, prioritizing units, then items, and finally trinkets.

- **Regular Battle**: `3 + (Day - 1)` (e.g., Day 1: 3, Day 2: 4, Day 3: 5).
- **Elite Battle**: `Daily Budget`. Elite nodes contain boss-tier units and grant **Trinket Rewards**.
- **Boss Battle**: `Daily Budget`.
    - **Boss Unit**: Free (does not consume budget).
    - **Boss Summons**: Use one-third (33%) of the daily budget. Summons can spawn with randomly equipped items.

### Progression Scaling
- **Elite battles** occur randomly on the path.
- **Boss battles** occur every time **20% of the Flashcard deck** is unlocked (20%, 40%, 60%, 80%, 100%).
