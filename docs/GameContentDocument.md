# Game Content Document

*This document is auto-generated from the game's resource files.*


## Units (Tier 1)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `ASpeFodToy` | **ASpeFodToy** | 1 HP / 1 PWR | AIR, Specialist, Food, Toy | Deal (PWR) damage to the enemy in the mirror slot. [Ranged Attack] [Target: MIRROR_SLOT_ENEMY]<br><br>When this unit dies, grant its current PWR to the ally behind. [Target: ALLY_BEHIND]<br><br>When this unit dies, grant its current PWR to the ally behind, and half of that to the next ally. [Target: ALLY_BEHIND]<br><br>When this unit dies, grant its current PWR to the ally behind, half to the next, and half to the next. [Target: ALLY_BEHIND] |
| `ETnkPlaToy` | **ETnkPlaToy** | 2 HP / 1 PWR | EARTH, Tank, Plant, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>When hurt BY AN ATTACK, Heal this unit by 1 HP. [Target: HOLDER]<br><br>When hurt BY AN ATTACK, Heal this unit by 2 HP. [Target: HOLDER]<br><br>When hurt BY AN ATTACK, Heal this unit by 3 HP. [Target: HOLDER] |
| `FFigMecApp` | **FFigMecApp** | 1 HP / 2 PWR | FIRE, Fighter, Mecha, Appliance | Deal (PWR) damage to the enemy in the mirror slot. [Ranged Attack] [Target: MIRROR_SLOT_ENEMY]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. Triggers even if lethal. [Target: ATTACKER] [Trigger: CAUSE_ATTACK]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. The projectile then bounces to another random enemy, dealing half damage. [Target: ATTACKER] [Trigger: CAUSE_ATTACK]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. The projectile then bounces to 2 random enemies, dealing half damage per bounce. [Target: ATTACKER] [Trigger: CAUSE_ATTACK] |
| `WSupAniCos` | **WSupAniCos** | 1 HP / 1 PWR | WATER, Support, Animal, Costume | Deal (PWR) damage to the frontmost enemy.<br><br>When the ally directly in front takes damage, heal them for 1 HP. [Target: ALLY_SLOT_AHEAD]<br><br>When the ally directly in front takes damage, heal them for 2 HP. [Target: ALLY_SLOT_AHEAD]<br><br>When the ally directly in front takes damage, heal them for 3 HP. [Target: ALLY_SLOT_AHEAD] |


## Units (Tier 2)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `EASpeFodToy` | **EASpeFodToy** | 3 HP / 2 PWR | EARTH, AIR, Specialist, Food, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>Initial PWR equals your current Gold multiplied by 50% when drawn or spawned. [Target: SELF]<br><br>Initial PWR equals your current Gold multiplied by 100% when drawn or spawned. [Target: SELF]<br><br>Initial PWR equals your current Gold multiplied by 150% when drawn or spawned. [Target: SELF] |
| `EFTnkAniCos` | **EFTnkAniCos** | 3 HP / 2 PWR | EARTH, FIRE, Tank, Animal, Costume | When healed, gain 1 Armor and 1 Spikes.<br><br>When healed, gain 2 Armor and 2 Spikes.<br><br>When healed, gain 3 Armor and 3 Spikes. |
| `EWFigCosToy` | **EWFigCosToy** | 3 HP / 3 PWR | EARTH, WATER, Fighter, Costume, Toy | When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF]<br><br>When an ally is defeated, gain +2 HP and +1 PWR. [Target: SELF]<br><br>When an ally is defeated, gain +2 HP and +2 PWR. [Target: SELF] |
| `FASpeMecApp` | **FASpeMecApp** | 2 HP / 3 PWR | FIRE, AIR, Specialist, Mecha, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>Gains extra PWR equal to 100% of current Tokens, updating whenever Tokens change. [Target: SELF]<br><br>Gains extra PWR equal to 150% of current Tokens, updating whenever Tokens change. [Target: SELF]<br><br>Gains extra PWR equal to 200% of current Tokens, updating whenever Tokens change. [Target: SELF] |
| `FWSpeAppFod` | **FWSpeAppFod** | 2 HP / 3 PWR | FIRE, WATER, Specialist, Appliance, Food | Deal (PWR) damage to the frontmost enemy.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount. It bounces to 1 extra target, halving the stacks applied.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount. It bounces up to 2 extra targets, halving the stacks applied each bounce. |
| `WATnkPlaAni` | **WATnkPlaAni** | 2 HP / 2 PWR | WATER, AIR, Tank, Plant, Animal | Deal (PWR) damage to the frontmost enemy.<br><br>At start of combat, gain +1 HP and +1 PWR for each empty slot in your team. [Target: SELF]<br><br>At start of combat, gain +2 HP and +2 PWR for each empty slot in your team. [Target: SELF]<br><br>At start of combat, gain +3 HP and +3 PWR for each empty slot in your team. [Target: SELF] |


## Units (Tier 3)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `EEFASpeFodCos` | **EEFASpeFodCos** | 6 HP / 4 PWR | EARTH, EARTH, FIRE, AIR, Specialist, Food, Costume | Before its turn action, transforms into the enemy unit in the mirror slot (+0 Level). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE]<br><br>Before its turn action, transforms into the enemy unit in the mirror slot (+1 Level). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE]<br><br>Before its turn action, transforms into the enemy unit in the mirror slot (Level 3 MAX). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE] |
| `EEFWFigTnkPlaToy` | **EEFWFigTnkPlaToy** | 6 HP / 5 PWR | EARTH, EARTH, FIRE, WATER, Fighter, Tank, Plant, Toy | Grants +1 HP and +1 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES]<br><br>Grants +2 HP and +1 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES]<br><br>Grants +2 HP and +2 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES] |
| `EEWAFigFodAniCos` | **EEWAFigFodAniCos** | 6 HP / 5 PWR | EARTH, EARTH, WATER, AIR, Fighter, Food, Animal, Costume | Deals damage to enemies equal to 100% of PWR when they are summoned. [Target: TRIGGERING_ENTITY]<br><br>Deals damage to enemies equal to 150% of PWR when they are summoned. [Target: TRIGGERING_ENTITY]<br><br>Deals damage to enemies equal to 200% of PWR when they are summoned. [Target: TRIGGERING_ENTITY] |
| `EFAASupToy` | **EFAASupToy** | 5 HP / 5 PWR | EARTH, FIRE, AIR, AIR, Support, Toy | Summons a random Level 1 Tier 2 unit on death. [Target: NONE]<br><br>Summons a random Level 2 Tier 2 unit on death. [Target: NONE]<br><br>Summons a random Level 3 Tier 2 unit on death. [Target: NONE] |
| `EFFASupPlaToy` | **EFFASupPlaToy** | 5 HP / 5 PWR | EARTH, FIRE, FIRE, AIR, Support, Plant, Toy | Grants +3 HP to newly summoned allies. [Target: TRIGGERING_ENTITY]<br><br>Grants +5 HP to newly summoned allies. [Target: TRIGGERING_ENTITY]<br><br>Grants +7 HP to newly summoned allies. [Target: TRIGGERING_ENTITY] |
| `EFFWSupMecApp` | **EFFWSupMecApp** | 5 HP / 5 PWR | EARTH, FIRE, FIRE, WATER, Support, Mecha, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>Whenever a merge happens on the battle board, gain +2 HP and PWR. [Target: SELF]<br><br>Whenever a merge happens on the battle board, gain +3 HP and PWR. [Target: SELF]<br><br>Whenever a merge happens on the battle board, gain +4 HP and PWR. [Target: SELF] |
| `EFWAFigSpeAniMec` | **EFWAFigSpeAniMec** | 5 HP / 5 PWR | EARTH, FIRE, WATER, AIR, Specialist, Fighter, Animal, Mecha | Attacks enemy in opposite mirror slot for 100% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN]<br><br>Attacks enemy in opposite mirror slot for 150% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN]<br><br>Attacks enemy in opposite mirror slot for 200% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN] |
| `EFWASupFodToy` | **EFWASupFodToy**<br>_Gains +3 PWR for each other Doppleganger in battle. Summons 1 copy of itself on death into the Gacha Machine._ | 5 HP / 4 PWR | EARTH, FIRE, WATER, AIR, Support, Food, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>Gains +3 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Gains +4 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Gains +5 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Summons 1 copy of itself on death into the Gacha Machine. [Target: NONE] |
| `EFWATnkCosMec` | **EFWATnkCosMec** | 5 HP / 6 PWR | EARTH, FIRE, WATER, AIR, Tank, Costume, Mecha | Gain +2 HP before taking damage. [Target: SELF]<br><br>Gain +4 HP before taking damage. [Target: SELF]<br><br>Gain +6 HP before taking damage. [Target: SELF] |
| `EFWWFigSpeAniFodMecCos` | **EFWWFigSpeAniFodMecCos** | 5 HP / 6 PWR | EARTH, FIRE, WATER, WATER, Specialist, Fighter, Animal, Food, Mecha, Costume | Deals 100% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN]<br><br>Deals 150% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN]<br><br>Deals 200% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN] |
| `EWAASpePlaApp` | **EWAASpePlaApp** | 5 HP / 4 PWR | EARTH, WATER, AIR, AIR, Specialist, Plant, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>At the start of each turn, permanently gain +3 HP and +3 PWR for every 5 Gold you currently have. [Target: SELF]<br><br>At the start of each turn, permanently gain +4 HP and +4 PWR for every 5 Gold you currently have. [Target: SELF]<br><br>At the start of each turn, permanently gain +5 HP and +5 PWR for every 5 Gold you currently have. [Target: SELF] |
| `EWWATnkMecApp` | **EWWATnkMecApp** | 5 HP / 5 PWR | intercept_lethal, EARTH, WATER, WATER, AIR, Tank, Mecha, Appliance | Leaps to intercept lethal damage on allies. [Target: SELF]<br><br>Leaps to intercept lethal damage on allies and gains 1 Armor. [Target: SELF]<br><br>Leaps to intercept lethal damage on allies and gains 2 Armor. [Target: SELF] |
| `FFWASpeSupMecAniApp` | **FFWASpeSupMecAniApp** | 5 HP / 5 PWR | FIRE, FIRE, WATER, AIR, Specialist, Support, Mecha, Animal, Appliance | On death, transfers its equipped item to the ally directly behind it. [Target: ALLY_BEHIND]<br><br>On death, transfers its equipped item to the ally behind and 1 copy behind them. [Target: ALLY_BEHIND]<br><br>On death, transfers its equipped item to the ally behind and 2 copies behind them. [Target: ALLY_BEHIND] |
| `FWAASupToy` | **FWAASupToy** | 4 HP / 5 PWR | FIRE, WATER, AIR, AIR, Support, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>If on the player bench at start of turn, gain +3 HP and PWR. [Target: SELF]<br><br>If on the player bench at start of turn, gain +5 HP and PWR. [Target: SELF]<br><br>If on the player bench at start of turn, gain +7 HP and PWR. [Target: SELF] |
| `FWWASupAniToy` | **FWWASupAniToy** | 4 HP / 5 PWR | FIRE, WATER, WATER, AIR, Support, Animal, Toy | Grants an additional copy of any buff received by an adjacent ally at 100% effectiveness. [Target: TRIGGERING_ENTITY]<br><br>Grants an additional copy of any buff received by an adjacent ally at 150% effectiveness. [Target: TRIGGERING_ENTITY]<br><br>Grants an additional copy of any buff received by an adjacent ally at 200% effectiveness. [Target: TRIGGERING_ENTITY] |


## Heroes
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `hero_avenger` | **Avenger** | 6 HP / 2 PWR |  | When an ally dies, leap and attack the frontmost enemy. [Target: FRONTMOST_ENEMY] |
| `hero_bastion` | **Bastion** | 10 HP / 2 PWR |  | When an ally dies, gain 1 Armor and 1 Spikes. Armor does not decay at the end of the turn. [Target: SELF] |
| `hero_bounty_hunter` | **Bounty Hunter** | 10 HP / 2 PWR |  | Gain 1 gold when this hero kills an enemy. [Target: SELF]<br><br>When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF] |
| `hero_pyro` | **Pyromancer** | 8 HP / 2 PWR |  | On attack, instead of dealing damage, apply Burn stacks equal to your Power. [Target: ATTACK_TARGET] |
| `hero_starter` | **Starter**<br>_Gain at least 3 Tokens from each minigame._ | 10 HP / 2 PWR |  | When an ally dies, gain HP equal to their PWR. [Target: SELF] |
| `hero_timekeeper` | **Timekeeper** | 50 HP / 2 PWR |  | Minigame: +1s correct, -0.5s wrong. Gains 5 tokens per turn in Battle and Rest Sites.<br><br>At the start of each turn, grants +2 HP to units in front and +2 PWR to units behind. [Target: ALLIES_IN_FRONT] |


## Enemies
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `boss_1` | **The Awakened Guardian** | 6 HP / 6 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Every time you draw a gachaball, this boss gains +1 HP. [Target: SELF] |
| `boss_2` | **The Shadow Warden** | 8 HP / 8 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Every time you spend a token, this boss gains +1 HP. [Target: SELF] |
| `boss_3` | **The Storm Herald** | 10 HP / 10 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF] |
| `boss_4` | **The Ancient Titan** | 12 HP / 12 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF] |
| `boss_5` | **The Final Arbiter** | 15 HP / 15 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF] |
| `enemy_hero` | **Enemy Hero**<br>_Deal (PWR) damage to the frontmost enemy._ | 10 HP / 2 PWR |  |  |
| `unit_dust_elite_t1` | **Dust Guard (T1)** | 3 HP / 3 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a T1 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF]<br><br>Spawns a Dust unit at Turn Start. [Target: TRIGGERING_ENTITY]<br><br>Spawns a Dust unit when Attacking. [Target: TRIGGERING_ENTITY] |
| `unit_dust_elite_t2` | **Dust Sentinel (T2)** | 4 HP / 4 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a random T1 or T2 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF]<br><br>Spawns a Dust unit in the player's inventory. [Target: TRIGGERING_ENTITY] |
| `unit_dust_elite_t3` | **Dust Overlord (T3)** | 5 HP / 5 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a random T1, T2 or T3 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF] |
| `unit_dust_t1` | **Dust Minion (T1)** | 1 HP / 1 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |
| `unit_dust_t2` | **Dust Minion (T2)** | 2 HP / 2 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |
| `unit_dust_t3` | **Dust Minion (T3)** | 3 HP / 3 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |


## Items
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `consumable_potion_plunder` | **Potion of Plunder** | - |  | Steals a random item from the target and sends it to your Gacha Machine of the matching tier. |
| `item_emblem_air` | **Air Emblem**<br>_When equipped, grants +2 HP, +1 PWR, and the [b]Air[/b] soul, allowing the unit to benefit from Air trait synergies._ | +2 HP / +1 PWR | ITEM, AIR |  |
| `item_emblem_earth` | **Earth Emblem**<br>_When equipped, grants +4 HP and the [b]Earth[/b] soul, allowing the unit to benefit from Earth trait synergies._ | +4 HP | ITEM, EARTH |  |
| `item_emblem_fire` | **Fire Emblem**<br>_When equipped, grants +2 PWR and the [b]Fire[/b] soul, allowing the unit to benefit from Fire trait synergies._ | +2 PWR | ITEM, FIRE |  |
| `item_emblem_water` | **Water Emblem**<br>_When equipped, grants +2 HP, +1 PWR, and the [b]Water[/b] soul, allowing the unit to benefit from Water trait synergies._ | +2 HP / +1 PWR | ITEM, WATER |  |
| `item_potion_heroism` | **Heroism Potion** | - | TIER_2, POTION | Grants +3 HP, +3 PWR, and 3 Armor stacks. |
| `item_potion_spikes` | **Thorn Potion** | - | TIER_2, POTION | Grants 4 Spikes stacks |
| `item_potion_t1` | **Minor Healing Potion** | - | TIER_1, POTION | Restores 4 HP. |
| `item_t1_a` | **Koi's Blessing** | +1 HP |  | At the start of the turn, Heal the holder for 2 HP. [Target: HOLDER] |
| `item_t1_b` | **Tiger's Spirit** | +1 PWR |  | When attacking, if target has more HP than holder then perform an extra attack. [Target: ATTACK_TARGET] [Trigger: CAUSE_TURN] |
| `item_t2_a` | **Summoning Scroll** | +2 HP |  | When the holder dies, summon a Tier 1 unit. |
| `item_t2_b` | **Bloodlust Edge** | +2 PWR |  | When the holder defeats an enemy, they act again immediately (once per turn). [Target: HOLDER] |
| `item_t2_c` | **Phoenix Elixir** | +1 HP / +1 PWR |  | When hurt BY AN ATTACK, Heal this unit by 1 HP and gain 1 PWR. [Target: HOLDER] |
| `item_t2_d` | **Echoing Orb** | - |  | Grants the holder +2 PWR for each Echoing Orb in battle.<br><br>Spawns an Echoing Orb into the Tier 2 Gacha Machine on death. |
| `item_t3_a` | **Heart Stone** | +4 HP |  | When the holder is hurt BY AN ATTACK, heal two random allies for 2 HP each. [Target: RANDOM_ALLY] |
| `item_t3_b` | **Power Amulet** | +4 PWR |  | When the holder attacks, grant +2 PWR to two random allies. [Target: NONE] |
| `item_t3_c` | **Lifesteal Ring** | +2 HP / +2 PWR |  | On attack, heal the holder for 20% of damage dealt (min 1 HP). [Target: HOLDER] |
| `item_t3_d` | **Vengeful Thorn** | +2 HP / +2 PWR |  | When hurt BY AN ATTACK, deal half of the holder's PWR as damage to a random enemy. [Target: RANDOM_ENEMY] [Trigger: CAUSE_ATTACK] |
| `item_t3_e` | **Death's Bargain** | +3 HP / +1 PWR |  | When the holder dies deal damage equal to half of the highest HP enemy's HP to that enemy. |
| `item_t3_f` | **Soul Siphon** | +1 HP / +3 PWR |  | After dealing damage steal half of target's PWR (min 1). [Target: DEFENDER] |
| `item_t3_g` | **Sniper Aim**<br>_Basic attacks target the enemy in the mirror slot._ | +1 PWR |  |  |


## Trinkets


### Sigils and Insignias
Sigils and Insignias have separate roles. A trait **Sigil** lists the activation thresholds and descriptions for that trait's abilities. An **Insignia** grants +1 HP and +1 PWR to a matching unit when it enters the board. Sigils use standalone trait symbols; Insignias use distinct ribboned badge icons.

| Insignia group | Items | Effect |
|---|---|---|
| Level Insignias | Novice (Level 1), Veteran (Level 2), Master (Level 3) | Grant +1 HP and +1 PWR to units of the matching level. |
| Tier Insignias | Cheap (Tier 1), Fair (Tier 2), Premium (Tier 3) | Grant +1 HP and +1 PWR to units of the matching tier, regardless of level. |
| Trait Insignias | One for each of the 15 traits listed below | Grant +1 HP and +1 PWR to units with the matching trait, regardless of level or tier. |

| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `trinket_aegis` | **Aegis Charm**<br>_Once per turn: When an ally would die, they survive with 1 HP instead._ | - |  |  |
| `trinket_air_insignia` | **Air Insignia**<br>_When a unit with the Air trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_animal_insignia` | **Animal Insignia**<br>_When a unit with the Animal trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_appliance_insignia` | **Appliance Insignia**<br>_When a unit with the Appliance trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_armor_aura` | **Armor Aura**<br>_At turn start, all allies gain 3 Armor._ | - |  |  |
| `trinket_awe_inspiring_totem` | **Awe Inspiring Totem**<br>_At turn start, if there is a Tier 3 or Level 3 unit in the lineup, grants +1 HP and +1 PWR to all other lower tier and level units._ | - |  |  |
| `trinket_bargain_charm` | **Bargain Charm**<br>_Gacha draws cost 1 token less (minimum 1) once per machine, per turn. Valid for battles only. Player exclusive._ | - |  |  |
| `trinket_beginners_charm` | **Beginner's Charm**<br>_Minigames: Gain 1 extra token if the mastery level of the answered flashcard is 1 (Very Hard)._ | - |  |  |
| `trinket_burn_vial` | **Burn Vial**<br>_Attacks apply 1 Burn stack._ | - |  |  |
| `trinket_costume_insignia` | **Costume Insignia**<br>_When a unit with the Costume trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_earth_insignia` | **Earth Insignia**<br>_When a unit with the Earth trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_fighter_insignia` | **Fighter Insignia**<br>_When a unit with the Fighter trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_fire_insignia` | **Fire Insignia**<br>_When a unit with the Fire trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_food_insignia` | **Food Insignia**<br>_When a unit with the Food trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_hero_catalyst` | **Hero's Catalyst**<br>_Grants the Hero +1 HP and +1 PWR on any merge._ | - |  |  |
| `trinket_level3_insignia` | **Master Insignia**<br>_When a Level 3 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_mecha_insignia` | **Mecha Insignia**<br>_When a unit with the Mecha trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_merge_damage_charm` | **Fusion Spark**<br>_Whenever a merge is performed on the battle board, deal 3 damage to a random enemy unit._ | - |  |  |
| `trinket_plant_insignia` | **Plant Insignia**<br>_When a unit with the Plant trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_polished_plate` | **Polished Plate**<br>_Armor does not decay at turn end._ | - |  | Armor does not decay at turn end. |
| `trinket_purifying_pendant` | **Purifying Pendant**<br>_When an ally takes damage from a negative status effect, removes all remaining stacks of that effect._ | - |  |  |
| `trinket_royal_insignia` | **Novice Insignia**<br>_When a Level 1 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_rusty_ring` | **Rusty Ring**<br>_Grants +1 HP and +1 PWR to all units with no equipment. Equipping an item cancels this buff._ | - |  |  |
| `trinket_soul_echo` | **Soul Echo**<br>_When an ally dies, resurrect the first non-hero unit that died this turn._ | - |  |  |
| `trinket_specialist_insignia` | **Specialist Insignia**<br>_When a unit with the Specialist trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_spiked_armor` | **Spiked Armor**<br>_At turn start, the frontmost unit gains 2 Armor and 2 [color=#44CC44]Spikes[/color]._ | - |  |  |
| `trinket_support_insignia` | **Support Insignia**<br>_When a unit with the Support trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_tank_insignia` | **Tank Insignia**<br>_When a unit with the Tank trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_tier1_insignia` | **Cheap Insignia**<br>_When a Tier 1 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_tier2_insignia` | **Fair Insignia**<br>_When a Tier 2 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_tier3_insignia` | **Premium Insignia**<br>_When a Tier 3 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_time_sprint_charm` | **Sprint Charm**<br>_Minigame timer gets a flat 2-second increase in battle._ | - |  |  |
| `trinket_token_return_charm` | **Token Return Charm**<br>_When the first unit dies each round, return Tokens equal to its Tier._ | - |  | The first unit to die each round returns tokens equivalent to its tier. |
| `trinket_toy_insignia` | **Toy Insignia**<br>_When a unit with the Toy trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_trait_air` | **Air Sigil**<br>_Air trait effects activate at 3, 6, 12, 20, and 32 units._ | - |  |  |
| `trinket_trait_animal` | **Animal Sigil**<br>_Animal trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_appliance` | **Appliance Sigil**<br>_Appliance trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_costume` | **Costume Sigil**<br>_Costume trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_earth` | **Earth Sigil**<br>_Earth trait effects activate at 3, 6, 12, 20, and 32 units._ | - |  |  |
| `trinket_trait_fighter` | **Fighter Sigil**<br>_Fighter trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_fire` | **Fire Sigil**<br>_Fire trait effects activate at 3, 6, 12, 20, and 32 units._ | - |  |  |
| `trinket_trait_food` | **Food Sigil**<br>_Food trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_mecha` | **Mecha Sigil**<br>_Mecha trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_plant` | **Plant Sigil**<br>_Plant trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_specialist` | **Specialist Sigil**<br>_Specialist trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_support` | **Support Sigil**<br>_Support trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_tank` | **Tank Sigil**<br>_Tank trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_toy` | **Toy Sigil**<br>_Toy trait effects activate at 2, 3, 4, and 5 units._ | - |  |  |
| `trinket_trait_water` | **Water Sigil**<br>_Water trait effects activate at 3, 6, 12, 20, and 32 units._ | - |  |  |
| `trinket_trinity_charm` | **Trinity Charm**<br>_If you draw at least once from each tier machine (1, 2, and 3) in a turn or encounter, gain 1 Token._ | - |  |  |
| `trinket_twin_charm` | **Twin Charm**<br>_Your units gain +1 PWR for every 2 copies of that same unit in your battle pool._ | - |  |  |
| `trinket_underdog_emblem` | **Underdog Emblem**<br>_Pre-Combat: If your team has fewer units than the enemy, all allies gain 2 Armor for each unit difference._ | - |  |  |
| `trinket_vengeance` | **Vengeance Charm**<br>_When an ally dies, grant +1 HP and +1 PWR to a random ally._ | - |  |  |
| `trinket_veteran_insignia` | **Veteran Insignia**<br>_When a Level 2 unit enters the board, it gains +1 HP and +1 PWR._ | - |  |  |
| `trinket_water_insignia` | **Water Insignia**<br>_When a unit with the Water trait enters the board, it gains +1 HP and +1 PWR._ | - |  |  |


## Core Stats & Combat Attributes
| Stat / Attribute | Type | Description |
|---|---|---|
| **HP (Health)** | Core Stat | The life pool of the unit. When reduced to 0, the unit is defeated and removed from the active battlefield. |
| **PWR (Power)** | Core Stat | The damage output of the unit during attacks and the base reflection strength for Spikes. |
| **Armor** | Combat Shield | Absorbs incoming direct combat attack damage point-for-point. Decays to 0 at the end of each turn unless preserved (e.g. by Polished Plate). Does not absorb Burn or Static damage. |
| **Spikes** | Defensive Counter | Deals PWR damage back to attackers when hit by a direct melee attack. Bypassed by ranged attacks and does not decay at turn end. |


## Status Effects
| ID | Status | Mechanics | Decay Mode |
|---|---|---|---|
| `burn` | **Burn** | Deals damage equal to the number of stacks at the end of each turn. Damage ignores Armor. | Halved (reduced by 50% rounded down) at the end of each turn. Stacks on units in a Burn Slot do not decay. |
| `armor` | **Armor** | Absorbs incoming direct attack damage (1 point of Armor absorbs 1 point of HP damage). Bypassed by Burn and Static. | Decays to 0 at the end of each turn unless preserved by abilities/trinkets. |
| `spikes` | **Spikes** | Deals the defending unit's PWR damage back to attackers when hit by direct melee attacks. | Does not decay. |
| `static` | **Static** | When a unit with Static dies, it deals collateral damage equal to its Static stacks to living adjacent lineup allies, mitigated by Armor. Cleared on explosion. | Decays by 1 stack at the end of each turn. |


## Battlefield Slot Effects
| ID | Slot Name | Trigger | Effect | Cost (Gold) |
|---|---|---|---|---|
| `burn` | **Burn Slot** | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 |
| `lightning` | **Lightning Slot** | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 |
| `death` | **Death Slot** | `on_turn_end` (Sudden Death) | Systemic sudden-death slot advancing forward from Turn 10+. Immediately reduces unit HP to 0. | - |


## Traits & Synergies
The game features 15 traits across three categories: 4 Elemental Traits (Souls: 3 to 32), 4 Class Traits (Units: 2 to 5), and 7 Visual Archetype Traits (Units: 2 to 5). Each trait has a matching Sigil that lists the activation thresholds for that trait's abilities. Trait Insignias are separate stat-bonus trinkets.

### Elemental Traits (Souls: 3, 6, 12, 20, 32)
Units carry elemental Soul tags (Fire, Earth, Water, Air). The elemental Sigils list the Soul thresholds for their abilities:
| Trait | Focus | Synergy Thresholds | Overview |
|---|---|---|---|
| **Fire** | Offensive Pressure | 3 / 6 / 12 / 20 / 32 Souls | Applies Burn on attack, spreads Burn on tick, deals bonus attack damage against burning targets, and redistributes Burn on kill. |
| **Earth** | Defensive Counter | 3 / 6 / 12 / 20 / 32 Souls | Grants Armor and Spikes across the frontline pre-combat, and Earth units deal bonus attack damage equal to their Spikes (decays 1 stack per attack). |
| **Water** | Healing & Cleanse | 3 / 6 / 12 / 20 / 32 Souls | Pre-combat healing and negative status cleansing; turn-start lowest-HP healing; consumes negative statuses to heal at turn start. |
| **Air** | Static Discharge | 3 / 6 / 12 / 20 / 32 Souls | Inflicts Static on attack, splashes Static to adjacent enemies, pre-combat team Static, and scales attack Static with unit PWR. |

### Class & Visual Archetype Traits (Units: 2, 3, 4, 5)
The Class and Visual Sigils list the unit-count thresholds for their abilities:
| Trait Category | Traits | Synergy Thresholds | Archetype Mechanic |
|---|---|---|---|
| **Class Traits** | Tank, Fighter, Support, Specialist | 2 / 3 / 4 / 5 Units | **Tank**: Frontline Armor, backward Armor passing, attack interception, Armor-to-Spikes.<br>**Fighter**: Bonus damage vs higher HP, ranged counter-attack, cleave splash, extra action on kill.<br>**Support**: Positional +HP (front) / +PWR (behind), turn-start lowest-stat buffs, Hero empowerment.<br>**Specialist**: Opening tokens, Gacha discount, gold on kill, bench combat clone, +PWR per 5 Gold. |
| **Visual Archetypes** | Food, Mecha, Animal, Plant, Toy, Appliance, Costume | 2 / 3 / 4 / 5 Units | **Food**: Feeds ally behind when hurt (+HP/+PWR), passes all PWR on death.<br>**Mecha**: Spikes & Armor, Static on attack & hit, merge laser strikes, death revenge salvos.<br>**Animal**: Random alpha +PWR, healing per attack (scaling with PWR).<br>**Plant**: Frontline Spikes, turn-start healing, team Spikes & HP, converts incoming heals to Spikes.<br>**Toy**: Melee Static reflection, death explosion detonating highest Static enemy.<br>**Appliance**: Static immunity, pre-combat Static/Burn, status reflection, converts debuffs to PWR/HP.<br>**Costume**: Pre-combat status and stat theft from mirror enemies and highest-status targets. |
