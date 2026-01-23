# Game Content Document: Flashcard Heroes
**(Synced with Codebase)**

## 1. Units
Units are the primary actors in battle. They have Health (HP) and Power (PWR) stats, can equip items, and possess abilities.

### Player Heroes
| ID | Name | Tier | Stats | Slots | Abilities |
|---|---|---|---|---|---|
| `hero_bounty_hunter` | Bounty Hunter | 0 | 10 HP / 2 PWR | 5 | **Bounty**: Gain 1 Gold on kill. |
| `hero_timekeeper` | Timekeeper | 0 | 50 HP / 2 PWR | 5 | **Time Warp**: (Passive effect pending definition). |

### Tier 1 Units (Cost: 1)
| ID | Name | Stats | Slots | Abilities |
|---|---|---|---|---|
| `unit_t1_a` | Apprentice | 1 HP / 2 PWR | 1 | **Resilience** (`on_hurt`): Heal self by (PWR). |
| `unit_t1_b` | Squire | 2 HP / 1 PWR | 1 | **Retaliation** (`on_hurt`): Counter-attack for (PWR) damage. |

### Tier 2 Units (Cost: 2)
| ID | Name | Merge Recipe | Stats | Slots | Abilities |
|---|---|---|---|---|---|
| `unit_t2_a` | Paladin | (A + ?) | 4 HP / 2 PWR | 2 | **Defensive Stance** (`on_before_damage`): Gain +2 HP before taking damage. |
| `unit_t2_b` | Berserker | (B + ?) | 2 HP / 4 PWR | 2 | **Shockwave** (`on_attack`): Deals cascade AOE damage to front enemy and units behind. |
| `unit_t2_c` | Knight | (A + B) | 3 HP / 3 PWR | 2 | **Morale Boost** (`on_ally_death`): Gain +1 HP / +1 PWR. |

### Tier 3 Units (Cost: 3)
| ID | Name | Stats | Slots | Abilities |
|---|---|---|---|---|
| `unit_t3_a` | Duelist | 4 HP / 8 PWR | 4 | **Mirror Strike** (`on_attack`): Attacks the enemy in the equivalent slot index. |
| `unit_t3_b` | Guardian | 6 HP / 4 PWR | 4 | **Guardian Sacrifice** (`passive_intercept`): Leaps to intercept lethal damage on allies. |
| `unit_t3_c` | Necromancer | 5 HP / 5 PWR | 4 | **Soul Summon** (`on_death`): Summons a Tier 2 unit on death. |
| `unit_t3_d` | (Defined?) | 6 HP / 6 PWR | 4 | **Resilient Aura** (`on_hurt`): Grants +1 HP/+1 PWR to adjacent allies. |
| `unit_t3_e` | Assassin | 5 HP / 7 PWR | 4 | **Ambush Predator** (`on_enemy_summon`): Deals damage to enemies when they are summoned. |
| `unit_t3_f` | Summoner | 7 HP / 5 PWR | 4 | **Summon Blessing** (`on_ally_summon`): Heals allies when they are summoned. |

### Enemies
| ID | Name | Stats | Type | Abilities |
|---|---|---|---|---|
| `enemy_hero` | Enemy Hero | 10 HP / 2 PWR | Boss | (None by default) |
| `boss_1` | Boss 1 | 10 HP / 10 PWR | Boss | **Summon**: Summons reinforcement minions. |
| `boss_2` | Boss 2 | (Defined in tres) | Boss | (Summon variants) |
| `boss_3` | Boss 3 | (Defined in tres) | Boss | (Summon variants) |
| `boss_4` | Boss 4 | (Defined in tres) | Boss | (Summon variants) |
| `boss_5` | Boss 5 | (Defined in tres) | Boss | (Summon variants) |

---

## 2. Items
Items are equipped on units to provide stats and new abilities.

### Tier 1 Items (Cost: 1)
| ID | Name | Stats | Ability |
|---|---|---|---|
| `item_t1_a` | Small HP Potion | +1 HP | **Restoration** (`on_turn_start`): Heal holder 2 HP. |
| `item_t1_b` | Small PWR Potion | +1 PWR | **Extra Attack** (`on_attack`): Attack again if target HP > Holder HP. |

### Tier 2 Items (Cost: 2)
| ID | Name | Stats | Ability |
|---|---|---|---|
| `item_t2_a` | Summon Scroll | +2 HP | **Summon** (`on_death`): Summons a Tier 1 unit. |
| `item_t2_b` | Bloodlust Blade | +2 PWR | **Bloodlust** (`on_kill`): Grant extra action? |
| `item_t2_c` | Large HP Potion | +1 HP / +1 PWR | **Regeneration** (`on_hurt`): Heal self 1 HP. |

### Tier 3 Items (Cost: 3)
| ID | Name | Stats | Ability |
|---|---|---|---|
| `item_t3_a` | Healing Totem | +4 HP | **Area Heal** (`on_hurt`): Heal 2 random allies. |
| `item_t3_b` | War Banner | +4 PWR | **Rally** (`on_attack`): Buff 2 random allies +2 PWR. |
| `item_t3_c` | Vampiric Dagger | +2 HP / +2 PWR | **Lifesteal** (`on_damage_dealt`): Heal holder based on damage. |
| `item_t3_d` | Retaliation Shield? | +2 HP / +2 PWR | **Retaliate Random** (`on_hurt`): Counter-attack a random enemy? |
| `item_t3_e` | Deathbomb | +3 HP / +1 PWR | **Explode** (`on_death`): Deal damage to highest HP enemy. |
| `item_t3_f` | Soul Siphon | +1 HP / +3 PWR | **Power Drain** (`on_damage_dealt`): Steal PWR from target. |

---

## 3. Trinkets
Team-wide passive artifacts obtained from bosses.

| ID | Name | Trigger | Effect |
|---|---|---|---|
| `trinket_healing_amulet` | Healing Amulet | `on_turn_start` | Heals frontmost ally for 2 HP. |
| `trinket_aegis` | Aegis | `on_hurt` | Prevents lethal damage once per battle (leaves unit at 1 HP). |
| `trinket_armor_aura` | Armor Aura | `on_turn_start` | Grants 3 **Armor** to all allies. |
| `trinket_burn_vial` | Burn Vial | `on_damage_dealt` | Dealing damage applies 1 **Burn** stack (DoT). |
| `trinket_royal_insignia` | Royal Insignia | `on_draw`, `on_summon` | Grants **+2 HP/+2 PWR** to any **Tier 1** unit entering the board. |
| `trinket_soul_echo` | Soul Echo | `on_ally_death` | Resurrects the **first** ally to die each battle (50% stats). |
| `trinket_vengeance` | Vengeance | `on_ally_death` | Grants +1 PWR to a random ally. |