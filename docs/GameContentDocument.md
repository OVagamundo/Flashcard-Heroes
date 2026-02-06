# Game Content Document: Flashcard Heroes
**(Synced with Codebase)**

## Recipe Unlock System

**Important**: Merge recipes are LOCKED by default at the start of each run. Recipes only unlock when you acquire the resulting gachaball (via shop purchase, battle reward, etc.). These unlocks are per-run only and reset when starting a new run.

- **Tier 1 units** (Apprentice, Squire) are base units with NO recipes
- **Tier 2+ units** have recipes that unlock upon acquisition
- Example: Buying a Knight from the shop unlocks its recipe (Apprentice + Squire → Knight)

## 1. Units
Units are the primary actors in battle. They have Health (HP) and Power (PWR) stats, can equip items, and possess abilities.

### Player Heroes
| ID | Name | Tier | Stats | Slots | Abilities |
|---|---|---|---|---|---|
| `hero_bounty_hunter` | Bounty Hunter | 0 | 10 HP / 2 PWR | 5 | **Bounty**: Gain 1 Gold on kill.<br>**Scavenger's Resolve** (`on_ally_death`): Gain +1 HP and +1 PWR when an ally dies.<br>**Quick Wits** (Minigame): +0.8s on correct answer, -0.2s on incorrect. |
| `hero_timekeeper` | Timekeeper | 0 | 50 HP / 2 PWR | 5 | **Time Warp**: Gains 5 tokens at start of battle and Rest Sites (Passive).<br>**Temporal Aura**: At start of each turn, grants +2 HP to units in front and +2 PWR to units behind (Passive).<br>**Time Dilation** (Minigame): +1.0s on correct answer, -0.5s on incorrect. |

### Tier 1 Units (Cost: 1)
| ID | Name | Stats | Slots | Souls | Abilities |
|---|---|---|---|---|---|
| `unit_t1_a` | Apprentice | 2 HP / 1 PWR | 1 | 1 Earth | **Resilience** (`on_hurt`): Heal self by (PWR). |
| `unit_t1_b` | Squire | 1 HP / 2 PWR | 1 | 1 Fire | **Retaliation** (`on_hurt`): Counter-attack for (PWR) damage. |
| `unit_t1_c` | Protector | 1 HP / 1 PWR | 1 | 1 Water | **Guardian's Grace** (`on_ally_hurt`): When ally directly in front takes damage, heal them for (PWR). |
| `unit_t1_d` | Empath | 1 HP / 1 PWR | 1 | 1 Wind | **Empathic Link** (`on_healed`): When healed, grant +1 PWR to ally behind. |

### Tier 2 Units (Cost: 2)
| ID | Name | Merge Recipe | Stats | Slots | Souls | Abilities |
|---|---|---|---|---|---|---|
| `unit_t2_a` | Paladin | **Apprentice + Apprentice** | 4 HP / 2 PWR | 2 | 2 Earth | **Defensive Stance** (`on_before_damage`): Gain +2 HP before taking damage. |
| `unit_t2_b` | Berserker | **Squire + Squire** | 2 HP / 4 PWR | 2 | 2 Fire | **Shockwave** (`on_attack`): Deals cascade AOE damage to front enemy and units behind. |
| `unit_t2_c` | Knight | **Apprentice + Squire** | 3 HP / 3 PWR | 2 | 1 Fire, 1 Earth | **Morale Boost** (`on_ally_death`): Gain +2 HP / +2 PWR. |
| `unit_t2_d` | Templar | **Protector + Empath** | 2 HP / X PWR | 2 | 1 Water, 1 Wind | **Gacha Power** (`passive`): PWR is equal to Gacha Tokens (Min 1). PWR buffs convert to HP. |
| `unit_t2_e` | Mimic | **Protector + Protector** | 2 HP / 2 PWR | 2 | 2 Water | **Mirror Transformation** (`on_turn_start`): Transforms into the base unit of the enemy in the mirror slot. |
| `unit_t2_f` | Merchant | **Apprentice + Empath** | X HP / 2 PWR | 2 | 1 Earth, 1 Wind | **Gold Investments** (`on_draw`): Sets HP equal to your current Gold when drawn. |
| `unit_t2_g` | Shadow Cloner | **Empath + Empath** | 3 HP / 3 PWR | 2 | 1 Wind | **Buff Echo** (`on_stat_increased`): Repeats any buff (HP/PWR) received by an adjacent ally. |
| `unit_t2_h` | Hermit | **Protector + Empath** | 4 HP / 2 PWR | 2 | 1 Water, 1 Wind | **Solitary Strength** (`on_pre_combat`): Start of Combat (Lineup Only): Gains +HP/+PWR equal to `Current PWR * Empty Slots`. |
| `unit_t2_i` | Mud Wretch | **Apprentice + Protector** | 2 HP / 2 PWR | 2 | 1 Earth, 1 Water | **Mud Coating** (`on_healed`): When healed, gain **+2 Armor**. |
| `unit_t2_j` | Steam Wisp | **Squire + Protector** | 1 HP / 3 PWR | 2 | 1 Fire, 1 Water | **Scald** (`on_healed`): When healed, deal equal damage to the front enemy. |

### Tier 3 Units (Cost: 3)
| ID | Name | Merge Recipe | Stats | Slots | Souls | Abilities |
|---|---|---|---|---|---|---|
| `unit_t3_a` | Duelist | **Berserker + Berserker** | 4 HP / 8 PWR | 4 | 4 Fire | **Mirror Strike** (`on_attack`): Attacks enemy in the opposite mirror slot. If empty, targets the backmost enemy. |
| `unit_t3_b` | Guardian | **Paladin + Paladin** | 6 HP / 4 PWR | 4 | 4 Earth | **Guardian Sacrifice** (`passive_intercept`): Leaps to intercept lethal damage on allies. |
| `unit_t3_c` | Necromancer | **Paladin + Berserker** | 5 HP / 5 PWR | 4 | 2 Fire, 2 Earth | **Soul Summon** (`on_death`): Summons a Tier 2 unit on death. |
| `unit_t3_d` | Warden | **Knight + Knight** | 6 HP / 6 PWR | 4 | 2 Fire, 2 Earth | **Resilient Aura** (`on_hurt`): Grants +1 HP/+1 PWR to adjacent allies. |
| `unit_t3_e` | Assassin | **Berserker + Knight** | 5 HP / 7 PWR | 4 | 3 Fire, 1 Earth | **Ambush Predator** (`on_enemy_summon`): Deals damage to enemies when they are summoned. |
| `unit_t3_f` | Summoner | **Paladin + Knight** | 7 HP / 5 PWR | 4 | 1 Fire, 3 Earth | **Summon Blessing** (`on_ally_summon`): Heals allies when they are summoned. |
| `unit_t3_g` | Phantom Wayfarer | **Shadow Cloner + Shadow Cloner** | 6 HP / 6 PWR | 4 | 4 Wind | **Quiet Meditation** (`on_turn_start`): If on bench, gain +3 HP/+3 PWR. **[Player Exclusive]** |

### Enemies
| ID | Name | Stats | Type | Abilities |
|---|---|---|---|---|
| `enemy_hero` | Enemy Hero | 10 HP / 2 PWR | Boss | (None by default) |
| `boss_1` | The Awakened Guardian | 10 HP / 10 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Draining Presence** (`on_draw`): Gains +1 HP when player draws from gacha. |
| `boss_2` | The Shadow Warden | 15 HP / 15 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Token Hunger** (`on_token_spent`): Gains +1 HP for each token the player spends. |
| `boss_3` | The Storm Herald | 20 HP / 20 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots.<br>**Vengeance Growth** (`on_ally_death`): Gains +3 HP and +2 PWR when an ally is defeated. |
| `boss_4` | The Ancient Titan | 25 HP / 25 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots. |
| `boss_5` | The Final Arbiter | 30 HP / 30 PWR | Boss | **Call Reinforcements** (`on_turn_end`): Summons units to fill empty slots. |

---

## 2. Items
Items are equipped on units to provide stats and new abilities.

### Tier 1 Items (Cost: 1)
| ID | Name | Stats | Ability |
|---|---|---|---|
| `item_t1_a` | Small HP Potion | +1 HP | **Restoration** (`on_turn_start`): Heal holder 2 HP. |
| `item_t1_b` | Small PWR Potion | +1 PWR | **Extra Attack** (`on_attack`): Attack again if target HP > Holder HP. |

### Tier 2 Items (Cost: 2)
| ID | Name | Merge Recipe | Stats | Ability |
|---|---|---|---|---|
| `item_t2_a` | Summon Scroll | **Small HP + Small HP** | +2 HP | **Summon** (`on_death`): Summons a Tier 1 unit. |
| `item_t2_b` | Bloodlust Blade | **Small PWR + Small PWR** | +2 PWR | **Bloodlust** (`on_kill`): Grant extra action. |
| `item_t2_c` | Large HP Potion | **Small HP + Small PWR** | +1 HP / +1 PWR | **Regeneration** (`on_hurt`): Heal self 1 HP. |

### Tier 3 Items (Cost: 3)
| ID | Name | Merge Recipe | Stats | Ability |
|---|---|---|---|---|
| `item_t3_a` | Healing Totem | **Summon Scroll + Summon Scroll** | +4 HP | **Area Heal** (`on_hurt`): Heal 2 random allies. |
| `item_t3_b` | War Banner | **Bloodlust Blade + Bloodlust Blade** | +4 PWR | **Rally** (`on_attack`): Buff 2 random allies +2 PWR. |
| `item_t3_c` | Vampiric Dagger | **Bloodlust Blade + Large Potion** | +2 HP / +2 PWR | **Lifesteal** (`on_damage_dealt`): Heal holder based on damage. |
| `item_t3_d` | Retaliation Shield | **Large Potion + Large Potion** | +2 HP / +2 PWR | **Retaliate Random** (`on_hurt`): Counter-attack a random enemy. |
| `item_t3_e` | Deathbomb | **Summon Scroll + Large Potion** | +3 HP / +1 PWR | **Explode** (`on_death`): Deal damage to highest HP enemy. |
| `item_t3_f` | Soul Siphon | **Bloodlust Blade + Large Potion** | +1 HP / +3 PWR | **Power Drain** (`on_damage_dealt`): Steal PWR from target. |
| `item_emblem_fire` | Fire Emblem | (Defined in tres) | +2 PWR | **Fire Soul** (`passive`): Counts as a Fire unit. |
| `item_emblem_earth` | Earth Emblem | (Defined in tres) | +4 HP | **Earth Soul** (`passive`): Counts as an Earth unit. |
| `item_emblem_water` | Water Emblem | (Defined in tres) | +2 HP / +1 PWR | **Water Soul** (`passive`): Counts as a Water unit. |
| `item_emblem_wind` | Wind Emblem | (Defined in tres) | +1 PWR / +2 HP | **Wind Soul** (`passive`): Counts as a Wind unit. |

---
### Consumables (Cost: 1)
| ID | Name | Stats | Effect |
|---|---|---|---|
| `consumable_potion_healing_minor` | Minor Healing Potion | (None) | **Heal**: Restores 5 HP to the target unit (Ally or Enemy). Consumed on use. |
| `item_potion_spikes` | Thorn Potion | (None) | **Status**: Grants **4 Spikes** stacks to the target unit. |
| `item_potion_heroism` | Heroism Potion | (None) | **Buff**: Grants **+3 HP**, **+3 PWR**, and **3 Armor** stacks to the target unit. |
| `consumable_potion_plunder` | Potion of Plunder | (None) | **Steal**: Steals a random equipped item from the target. Returns if invalid. |

---

## 3. Trinkets
Team-wide passive artifacts obtained from bosses.

| ID | Name | Trigger | Effect |
|---|---|---|---|
| `trinket_polished_plate` | Polished Plate | `passive` | Armor does not decay at the end of the turn. |
| `trinket_aegis` | Aegis | `on_hurt` | Prevents lethal damage once per battle (leaves unit at 1 HP). |
| `trinket_armor_aura` | Armor Aura | `on_turn_start` | Grants 3 **Armor** to all allies. |
| `trinket_burn_vial` | Burn Vial | `on_damage_dealt` | Dealing damage applies 1 **Burn** stack (DoT). |
| `trinket_royal_insignia` | Royal Insignia | `on_draw`, `on_summon` | Grants **+2 HP/+2 PWR** to any **Tier 1** unit entering the board. |
| `trinket_soul_echo` | Soul Echo | `on_ally_death` | Resurrects the **first** ally to die each turn. |
| `trinket_vengeance` | Vengeance | `on_ally_death` | Grants **+1 HP** and **+1 PWR** to a random ally. |

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
| **3** | All Allies gain **1 Armor + 1 Spikes**; Earth units gain **2 Armor**. |
| **5** | All Allies gain **2 Armor + 2 Spikes**; Earth units gain **4 Armor**. |
| **7** | All Allies gain **3 Armor + 3 Spikes**; Earth units gain **6 Armor**. |
| **9** | **Fortress**: All Allies gain **4 Armor + 4 Spikes**; Earth units gain **8 Armor**. |

### Water Trait (`SOUL_WATER`)
*Focus: Adjacent Healing & Resilience*

| Souls | Effect |
|---|---|
| **2** | At Turn Start: Water units **heal adjacent allies** for 1 HP. |

### Wind Trait (`SOUL_WIND`)
*Focus: Power Theft & Disruption*

| Souls | Effect |
|---|---|
| **2** | At Turn Start: Wind units **steal 1 PWR** from the opposite enemy (Mirror slot or backmost enemy; floor: 1 PWR). |

---

## 5. Encounter & Budget Systems

### Daily Budget Formula
The game allocates a precise amount of gold for enemy recruitment every day. The system ensures the entire budget is spent, prioritizing units, then items, and finally trinkets.

- **Regular Battle**: `5 + 3 * (Day - 1)` (e.g., Day 1: 5, Day 2: 8, Day 3: 11).
- **Elite Battle**: `Daily Budget * 1.3`. Elite nodes contain boss-tier units and grant **Trinket Rewards**.
- **Boss Battle**: `Daily Budget`.
    - **Boss Unit**: Free (does not consume budget).
    - **Boss Summons**: Use half of the daily budget. Summons can spawn with randomly equipped items.

### Progression Scaling
- **Elite battles** occur randomly on the path.
- **Boss battles** occur every **10 days**.