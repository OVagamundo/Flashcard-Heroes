# Game Content Document

*This document is auto-generated from the game's resource files.*


## Units (Tier 1)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `ASpeFodToy` | **ASpeFodToy**<br>_ASpeFodToy unit._ | 1 HP / 1 PWR | AIR, Specialist, Food, Toy | Deal (PWR) damage to the enemy in the mirror slot. [Ranged Attack] [Target: MIRROR_SLOT_ENEMY]<br><br>When this unit dies, grant its current PWR to the ally behind. [Target: ALLY_BEHIND]<br><br>When this unit dies, grant its current PWR to the ally behind, and half of that to the next ally. [Target: ALLY_BEHIND]<br><br>When this unit dies, grant its current PWR to the ally behind, half to the next, and half to the next. [Target: ALLY_BEHIND] |
| `ETnkPlaToy` | **ETnkPlaToy**<br>_ETnkPlaToy unit._ | 2 HP / 1 PWR | EARTH, Tank, Plant, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>When hurt BY AN ATTACK, Heal this unit by 1 HP. [Target: HOLDER]<br><br>When hurt BY AN ATTACK, Heal this unit by 2 HP. [Target: HOLDER]<br><br>When hurt BY AN ATTACK, Heal this unit by 3 HP. [Target: HOLDER] |
| `FFigMecApp` | **FFigMecApp**<br>_FFigMecApp unit._ | 1 HP / 2 PWR | FIRE, Fighter, Mecha, Appliance | Deal (PWR) damage to the enemy in the mirror slot. [Ranged Attack] [Target: MIRROR_SLOT_ENEMY]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. Triggers even if lethal. [Target: ATTACKER] [Trigger: CAUSE_ATTACK]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. The projectile then bounces to another random enemy, dealing half damage. [Target: ATTACKER] [Trigger: CAUSE_ATTACK]<br><br>When hurt BY AN ATTACK, shoot a projectile at the attacker dealing damage equal to PWR. The projectile then bounces to 2 random enemies, dealing half damage per bounce. [Target: ATTACKER] [Trigger: CAUSE_ATTACK] |
| `WSupAniCos` | **WSupAniCos**<br>_WSupAniCos unit._ | 1 HP / 1 PWR | WATER, Support, Animal, Costume | Deal (PWR) damage to the frontmost enemy.<br><br>When the ally directly in front takes damage, heal them for 1 HP. [Target: ALLY_SLOT_AHEAD]<br><br>When the ally directly in front takes damage, heal them for 2 HP. [Target: ALLY_SLOT_AHEAD]<br><br>When the ally directly in front takes damage, heal them for 3 HP. [Target: ALLY_SLOT_AHEAD] |


## Units (Tier 2)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `EASpeFodToy` | **EASpeFodToy**<br>_EASpeFodToy unit._ | 3 HP / 2 PWR | EARTH, AIR, Specialist, Food, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>Initial PWR equals your current Gold multiplied by 50% when drawn or spawned. [Target: SELF]<br><br>Initial PWR equals your current Gold multiplied by 100% when drawn or spawned. [Target: SELF]<br><br>Initial PWR equals your current Gold multiplied by 150% when drawn or spawned. [Target: SELF] |
| `EFTnkAniCos` | **EFTnkAniCos**<br>_EFTnkAniCos unit._ | 3 HP / 2 PWR | EARTH, FIRE, Tank, Animal, Costume | When healed, gain 1 Armor and 1 Spikes.<br><br>When healed, gain 2 Armor and 2 Spikes.<br><br>When healed, gain 3 Armor and 3 Spikes. |
| `EWFigCosToy` | **EWFigCosToy**<br>_EWFigCosToy unit._ | 3 HP / 3 PWR | EARTH, WATER, Fighter, Costume, Toy | When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF]<br><br>When an ally is defeated, gain +2 HP and +1 PWR. [Target: SELF]<br><br>When an ally is defeated, gain +2 HP and +2 PWR. [Target: SELF] |
| `FASpeMecApp` | **FASpeMecApp**<br>_FASpeMecApp unit._ | 2 HP / 3 PWR | FIRE, AIR, Specialist, Mecha, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>Gains extra PWR equal to 100% of current Tokens, updating whenever Tokens change. [Target: SELF]<br><br>Gains extra PWR equal to 150% of current Tokens, updating whenever Tokens change. [Target: SELF]<br><br>Gains extra PWR equal to 200% of current Tokens, updating whenever Tokens change. [Target: SELF] |
| `FWSpeAppFod` | **FWSpeAppFod**<br>_FWSpeAppFod unit._ | 2 HP / 3 PWR | FIRE, WATER, Specialist, Appliance, Food | Deal (PWR) damage to the frontmost enemy.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount. It bounces to 1 extra target, halving the stacks applied.<br><br>When this unit is healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to the heal amount. It bounces up to 2 extra targets, halving the stacks applied each bounce. |
| `WATnkPlaAni` | **WATnkPlaAni**<br>_WATnkPlaAni unit._ | 2 HP / 2 PWR | WATER, AIR, Tank, Plant, Animal | Deal (PWR) damage to the frontmost enemy.<br><br>At start of combat, gain +1 HP and +1 PWR for each empty slot in your team. [Target: SELF]<br><br>At start of combat, gain +2 HP and +2 PWR for each empty slot in your team. [Target: SELF]<br><br>At start of combat, gain +3 HP and +3 PWR for each empty slot in your team. [Target: SELF] |


## Units (Tier 3)
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `EEFASpeFodCos` | **EEFASpeFodCos**<br>_EEFASpeFodCos unit._ | 6 HP / 4 PWR | EARTH, EARTH, FIRE, AIR, Specialist, Food, Costume | Before its turn action, transforms into the enemy unit in the mirror slot (+0 Level). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE]<br><br>Before its turn action, transforms into the enemy unit in the mirror slot (+1 Level). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE]<br><br>Before its turn action, transforms into the enemy unit in the mirror slot (Level 3 MAX). The newly transformed unit then takes its turn immediately. If there is no unit in the mirror slot, performs a regular basic attack instead. [Target: NONE] |
| `EEFWFigTnkPlaToy` | **EEFWFigTnkPlaToy**<br>_EEFWFigTnkPlaToy unit._ | 6 HP / 5 PWR | EARTH, EARTH, FIRE, WATER, Fighter, Tank, Plant, Toy | Grants +1 HP and +1 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES]<br><br>Grants +2 HP and +1 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES]<br><br>Grants +2 HP and +2 PWR to adjacent allies when hurt by an attack. [Target: ADJACENT_ALLIES] |
| `EEWAFigFodAniCos` | **EEWAFigFodAniCos**<br>_EEWAFigFodAniCos unit._ | 6 HP / 5 PWR | EARTH, EARTH, WATER, AIR, Fighter, Food, Animal, Costume | Deals damage to enemies equal to 100% of PWR when they are summoned. [Target: TRIGGERING_ENTITY]<br><br>Deals damage to enemies equal to 150% of PWR when they are summoned. [Target: TRIGGERING_ENTITY]<br><br>Deals damage to enemies equal to 200% of PWR when they are summoned. [Target: TRIGGERING_ENTITY] |
| `EFAASupToy` | **EFAASupToy**<br>_EFAASupToy unit._ | 5 HP / 5 PWR | EARTH, FIRE, AIR, AIR, Support, Toy | Summons a random Level 1 Tier 2 unit on death. [Target: NONE]<br><br>Summons a random Level 2 Tier 2 unit on death. [Target: NONE]<br><br>Summons a random Level 3 Tier 2 unit on death. [Target: NONE] |
| `EFFASupPlaToy` | **EFFASupPlaToy**<br>_EFFASupPlaToy unit._ | 5 HP / 5 PWR | EARTH, FIRE, FIRE, AIR, Support, Plant, Toy | Grants +3 HP to newly summoned allies. [Target: TRIGGERING_ENTITY]<br><br>Grants +5 HP to newly summoned allies. [Target: TRIGGERING_ENTITY]<br><br>Grants +7 HP to newly summoned allies. [Target: TRIGGERING_ENTITY] |
| `EFFWSupMecApp` | **EFFWSupMecApp**<br>_EFFWSupMecApp unit._ | 5 HP / 5 PWR | EARTH, FIRE, FIRE, WATER, Support, Mecha, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>Whenever a merge happens on the battle board, gain +2 HP and PWR. [Target: SELF]<br><br>Whenever a merge happens on the battle board, gain +3 HP and PWR. [Target: SELF]<br><br>Whenever a merge happens on the battle board, gain +4 HP and PWR. [Target: SELF] |
| `EFWAFigSpeAniMec` | **EFWAFigSpeAniMec**<br>_EFWAFigSpeAniMec unit._ | 5 HP / 5 PWR | EARTH, FIRE, WATER, AIR, Specialist, Fighter, Animal, Mecha | Attacks enemy in opposite mirror slot for 100% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN]<br><br>Attacks enemy in opposite mirror slot for 150% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN]<br><br>Attacks enemy in opposite mirror slot for 200% damage. [Target: MIRROR_SLOT_ENEMY] [Trigger: CAUSE_TURN] |
| `EFWASupFodToy` | **EFWASupFodToy**<br>_EFWASupFodToy unit._ | 5 HP / 4 PWR | EARTH, FIRE, WATER, AIR, Support, Food, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>Gains +3 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Gains +4 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Gains +5 PWR for each other Doppleganger in battle. [Target: NONE]<br><br>Summons 1 copy of itself on death into the Gacha Machine. [Target: NONE] |
| `EFWATnkCosMec` | **EFWATnkCosMec**<br>_EFWATnkCosMec unit._ | 5 HP / 6 PWR | EARTH, FIRE, WATER, AIR, Tank, Costume, Mecha | Gain +2 HP before taking damage. [Target: SELF]<br><br>Gain +4 HP before taking damage. [Target: SELF]<br><br>Gain +6 HP before taking damage. [Target: SELF] |
| `EFWWFigSpeAniFodMecCos` | **EFWWFigSpeAniFodMecCos**<br>_EFWWFigSpeAniFodMecCos unit._ | 5 HP / 6 PWR | EARTH, FIRE, WATER, WATER, Specialist, Fighter, Animal, Food, Mecha, Costume | Deals 100% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN]<br><br>Deals 150% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN]<br><br>Deals 200% cascade AOE damage to front enemy and units behind. [Target: FRONTMOST_ENEMY] [Trigger: CAUSE_TURN] |
| `EWAASpePlaApp` | **EWAASpePlaApp**<br>_EWAASpePlaApp unit._ | 5 HP / 4 PWR | EARTH, WATER, AIR, AIR, Specialist, Plant, Appliance | Deal (PWR) damage to the frontmost enemy.<br><br>At the start of each turn, permanently gain +3 HP and +3 PWR for every 5 Gold you currently have. [Target: SELF]<br><br>At the start of each turn, permanently gain +4 HP and +4 PWR for every 5 Gold you currently have. [Target: SELF]<br><br>At the start of each turn, permanently gain +5 HP and +5 PWR for every 5 Gold you currently have. [Target: SELF] |
| `EWWATnkMecApp` | **EWWATnkMecApp**<br>_EWWATnkMecApp unit._ | 5 HP / 5 PWR | intercept_lethal, EARTH, WATER, WATER, AIR, Tank, Mecha, Appliance | Leaps to intercept lethal damage on allies. [Target: SELF]<br><br>Leaps to intercept lethal damage on allies and gains 1 Armor. [Target: SELF]<br><br>Leaps to intercept lethal damage on allies and gains 2 Armor. [Target: SELF] |
| `FFWASpeSupMecAniApp` | **FFWASpeSupMecAniApp**<br>_FFWASpeSupMecAniApp unit._ | 5 HP / 5 PWR | FIRE, FIRE, WATER, AIR, Specialist, Support, Mecha, Animal, Appliance | On death, transfers its equipped item to the ally directly behind it. [Target: ALLY_BEHIND]<br><br>On death, transfers its equipped item to the ally behind and 1 copy behind them. [Target: ALLY_BEHIND]<br><br>On death, transfers its equipped item to the ally behind and 2 copies behind them. [Target: ALLY_BEHIND] |
| `FWAASupToy` | **FWAASupToy**<br>_FWAASupToy unit._ | 4 HP / 5 PWR | FIRE, WATER, AIR, AIR, Support, Toy | Deal (PWR) damage to the frontmost enemy.<br><br>If on the player bench at start of turn, gain +3 HP and PWR. [Target: SELF]<br><br>If on the player bench at start of turn, gain +5 HP and PWR. [Target: SELF]<br><br>If on the player bench at start of turn, gain +7 HP and PWR. [Target: SELF] |
| `FWWASupAniToy` | **FWWASupAniToy**<br>_FWWASupAniToy unit._ | 4 HP / 5 PWR | FIRE, WATER, WATER, AIR, Support, Animal, Toy | Grants an additional copy of any buff received by an adjacent ally at 100% effectiveness. [Target: TRIGGERING_ENTITY]<br><br>Grants an additional copy of any buff received by an adjacent ally at 150% effectiveness. [Target: TRIGGERING_ENTITY]<br><br>Grants an additional copy of any buff received by an adjacent ally at 200% effectiveness. [Target: TRIGGERING_ENTITY] |


## Heroes
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `hero_avenger` | **Avenger**<br>_A fierce warrior who strikes when allies fall._ | 6 HP / 2 PWR |  | When an ally dies, leap and attack the frontmost enemy. [Target: FRONTMOST_ENEMY] |
| `hero_bastion` | **Bastion**<br>_A steadfast defender who grows stronger as allies fall._ | 10 HP / 2 PWR |  | When an ally dies, gain 1 Armor and 1 Spikes. Armor does not decay at the end of the turn. [Target: SELF] |
| `hero_bounty_hunter` | **Bounty Hunter**<br>_A skilled hunter who profits from every kill and grows stronger from loss. Earns gold for each enemy slain, and gains +1 HP and +1 PWR when allies fall._ | 10 HP / 2 PWR |  | Gain 1 gold when this hero kills an enemy. [Target: SELF]<br><br>When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF] |
| `hero_pyro` | **Pyromancer**<br>_A fiery mage who incinerates enemies instead of striking them._ | 8 HP / 2 PWR |  | On attack, instead of dealing damage, apply Burn stacks equal to your Power. [Target: ATTACK_TARGET] |
| `hero_starter` | **Starter**<br>_A supportive hero who absorbs the power of fallen allies. Guarantees at least 3 tokens from every minigame. Recommended for trying a new deck._ | 10 HP / 2 PWR |  | When an ally dies, gain HP equal to their PWR. [Target: SELF] |
| `hero_timekeeper` | **Timekeeper**<br>_A scholarly mage who grants +2 HP to units in front and +2 PWR to units behind at turn start. Masters time to extend the minigame timer._ | 50 HP / 2 PWR |  | Minigame: +1s correct, -0.5s wrong. Gains 5 tokens per turn in Battle and Rest Sites.<br><br>At the start of each turn, grants +2 HP to units in front and +2 PWR to units behind. [Target: ALLIES_IN_FRONT] |


## Enemies
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `boss_1` | **The Awakened Guardian**<br>_A powerful guardian that summons allies and grows stronger as you draw from the gacha machines._ | 6 HP / 6 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Every time you draw a gachaball, this boss gains +1 HP. [Target: SELF] |
| `boss_2` | **The Shadow Warden**<br>_Drains power from every token you spend. Calls upon shadow creatures to fight alongside it._ | 8 HP / 8 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Every time you spend a token, this boss gains +1 HP. [Target: SELF] |
| `boss_3` | **The Storm Herald**<br>_Grows stronger as allies fall around it. Commands reinforcements to join its ranks._ | 10 HP / 10 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>When an ally is defeated, gain +1 HP and +1 PWR. [Target: SELF] |
| `boss_4` | **The Ancient Titan**<br>_An ancient being that summons warriors from ages past._ | 12 HP / 12 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF] |
| `boss_5` | **The Final Arbiter**<br>_The ultimate challenge. Defeat it to complete your run._ | 15 HP / 15 PWR | BOSS | At end of turn, summon units to fill empty team slots. [Target: SELF] |
| `enemy_hero` | **Enemy Hero**<br>_The enemy's champion._ | 10 HP / 2 PWR |  |  |
| `unit_dust_elite_t1` | **Dust Guard (T1)**<br>_A guard. Spawns a Dust unit (T1) on Turn Start, Attack, or Ally Death. Gains HP and PWR based on the tier of any dying Dust unit._ | 3 HP / 3 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a T1 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF]<br><br>Spawns a Dust unit at Turn Start. [Target: TRIGGERING_ENTITY]<br><br>Spawns a Dust unit when Attacking. [Target: TRIGGERING_ENTITY] |
| `unit_dust_elite_t2` | **Dust Sentinel (T2)**<br>_A sentinel. Spawns random T1 or T2 Dust units on Ally Death or when Hurt. Gains HP and PWR based on the tier of any dying Dust unit._ | 4 HP / 4 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a random T1 or T2 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF]<br><br>Spawns a Dust unit in the player's inventory. [Target: TRIGGERING_ENTITY] |
| `unit_dust_elite_t3` | **Dust Overlord (T3)**<br>_An overlord. Spawns random T1, T2, or T3 Dust units on Ally Death. Gains HP and PWR based on the tier of any dying Dust unit._ | 5 HP / 5 PWR | BOSS, HIDDEN | At end of turn, summon units to fill empty team slots. [Target: SELF]<br><br>Spawns a random T1, T2 or T3 Dust unit when an Ally dies. [Target: TRIGGERING_ENTITY]<br><br>Gains HP and PWR based on the tier of any dying Dust unit (e.g., +1/+1 for T1, +2/+2 for T2). [Target: SELF] |
| `unit_dust_t1` | **Dust Minion (T1)**<br>_A fragile construct. Stays in the fight._ | 1 HP / 1 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |
| `unit_dust_t2` | **Dust Minion (T2)**<br>_A construct. Stays in the fight._ | 2 HP / 2 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |
| `unit_dust_t3` | **Dust Minion (T3)**<br>_A heavy construct. Stays in the fight._ | 3 HP / 3 PWR | HIDDEN | Deal (PWR) damage to the frontmost enemy. |


## Items
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `consumable_potion_plunder` | **Potion of Plunder**<br>_Steals a random item from the target and sends it to your Gacha Machine of the matching tier._ | - |  | Steals a random item from the target and sends it to your Gacha Machine of the matching tier. |
| `item_emblem_air` | **Air Emblem**<br>_When equipped, grants +2 HP, +1 PWR, and the [b]Air[/b] soul, allowing the unit to benefit from Air trait synergies._ | +2 HP / +1 PWR | ITEM, AIR |  |
| `item_emblem_earth` | **Earth Emblem**<br>_When equipped, grants +4 HP and the [b]Earth[/b] soul, allowing the unit to benefit from Earth trait synergies._ | +4 HP | ITEM, EARTH |  |
| `item_emblem_fire` | **Fire Emblem**<br>_When equipped, grants +2 PWR and the [b]Fire[/b] soul, allowing the unit to benefit from Fire trait synergies._ | +2 PWR | ITEM, FIRE |  |
| `item_emblem_water` | **Water Emblem**<br>_When equipped, grants +2 HP, +1 PWR, and the [b]Water[/b] soul, allowing the unit to benefit from Water trait synergies._ | +2 HP / +1 PWR | ITEM, WATER |  |
| `item_potion_heroism` | **Heroism Potion**<br>_A potion that inspires heroism._ | - | TIER_2, POTION | **Heroism**: Grants +3 HP, +3 PWR, and 3 Armor stacks. |
| `item_potion_spikes` | **Thorn Potion**<br>_Grants 4 Spikes to target. Spikes damage attackers then lose a stack._ | - | TIER_2, POTION | **Thorn Skin**: Grants 4 Spikes stacks |
| `item_potion_t1` | **Minor Healing Potion**<br>_Restores 4 HP to a target unit._ | - | TIER_1, POTION | **Drink**: Restores 4 HP. |
| `item_t1_a` | **Koi's Blessing**<br>_A gentle remedy infused with the spirit of koi._ | +1 HP |  | **Restoration**: At the start of the turn, Heal the holder for 2 HP. [Target: HOLDER] |
| `item_t1_b` | **Tiger's Spirit**<br>_A fierce elixir that awakens inner strength._ | +1 PWR |  | **Extra Attack**: When attacking, if target has more HP than holder then perform an extra attack. [Target: ATTACK_TARGET] [Trigger: CAUSE_TURN] |
| `item_t2_a` | **Summoning Scroll**<br>_A scroll containing a summoning spell._ | +2 HP |  | **Summon**: A scroll containing a summoning spell. |
| `item_t2_b` | **Bloodlust Edge**<br>_A blade thirsty for blood._ | +2 PWR |  | **Bloodlust**: When the holder defeats an enemy, they act again immediately. [Target: HOLDER] |
| `item_t2_c` | **Phoenix Elixir**<br>_A restorative brew that renews body and spirit._ | +1 HP / +1 PWR |  | **Regeneration**: When hurt BY AN ATTACK, Heal this unit by 1 HP and gain 1 PWR. [Target: HOLDER] |
| `item_t2_d` | **Echoing Orb**<br>_A resonant orb that amplifies the power of its bearer._ | - |  | **Resonance**: Grants the holder +2 PWR for each Echoing Orb in battle.<br><br>**Echo Split**: Spawns an Echoing Orb into the Tier 2 Gacha Machine on death. |
| `item_t3_a` | **Heart Stone**<br>_A stone pulsating with life._ | +4 HP |  | **Vital Link**: When the holder is hurt BY AN ATTACK, heal two random allies for 2 HP each. [Target: RANDOM_ALLY] |
| `item_t3_b` | **Power Amulet**<br>_An ancient amulet of power._ | +4 PWR |  | **Battle Cry**: When the holder attacks, grant +2 PWR to two random allies. [Target: NONE] |
| `item_t3_c` | **Lifesteal Ring**<br>_A ring that feeds on the living._ | +2 HP / +2 PWR |  | **Vampiric Strike**: On attack, heal the holder for 20% of damage dealt (min 1 HP). [Target: HOLDER] |
| `item_t3_d` | **Vengeful Thorn**<br>_A thorny charm that strikes back at those who harm its bearer._ | +2 HP / +2 PWR |  | **Retaliation**: When hurt BY AN ATTACK, deal half of the holder's PWR as damage to a random enemy. [Target: RANDOM_ENEMY] [Trigger: CAUSE_ATTACK] |
| `item_t3_e` | **Death's Bargain**<br>_A cursed bargain with death._ | +3 HP / +1 PWR |  | **Final Strike**: When the holder dies deal damage equal to half of the highest HP enemy's HP to that enemy. |
| `item_t3_f` | **Soul Siphon**<br>_A dark siphon of souls._ | +1 HP / +3 PWR |  | **Power Drain**: After dealing damage steal half of target's PWR (min 1). [Target: DEFENDER] |
| `item_t3_g` | **Sniper Aim**<br>_A scope for precise targeting._ | +1 PWR |  |  |


## Trinkets
| ID | Name | Stats | Tags | Abilities |
|---|---|---|---|---|
| `trinket_aegis` | **Aegis Charm**<br>_A protective charm that shields allies from fatal blows._ | - |  | Once per turn: When an ally would die, they survive with 1 HP instead. [Target: NONE] |
| `trinket_armor_aura` | **Armor Aura**<br>_An aura that hardens the resolve of allies._ | - |  | **Armor Aura**: At turn start, all allies gain 3 Armor. |
| `trinket_awe_inspiring_totem` | **Awe Inspiring Totem**<br>_At turn start, if there is a Tier 3 or Level 3 unit in the lineup, grants +1 HP and +1 PWR to all other lower tier and level units._ | - |  | At turn start, if there is a Tier 3 or Level 3 unit in the lineup, grants +1 HP and +1 PWR to all other lower tier and level units. |
| `trinket_bargain_charm` | **Bargain Charm**<br>_A charm that haggles for a better price._ | - |  | **Bargain Charm**: Gacha draws cost 1 token less (minimum 1) once per machine, per turn. Valid for battles only. Player exclusive. |
| `trinket_beginners_charm` | **Beginner's Charm**<br>_Minigames: Gain 1 extra token if the mastery level of the answered flashcard is 1 (Very Hard)._ | - |  | Minigames: Gain 1 extra token if the mastery level of the answered flashcard is 1 (Very Hard). |
| `trinket_burn_vial` | **Burn Vial**<br>_A vial of eternal flame._ | - |  | A vial of eternal flame. |
| `trinket_hero_catalyst` | **Hero's Catalyst**<br>_Whenever an ally merges, grants +1 HP and +1 PWR to your Hero._ | - |  | **Hero's Catalyst**: Grants the Hero +1 HP and +1 PWR on any merge. |
| `trinket_merge_damage_charm` | **Fusion Spark**<br>_A charm that weaponizes fusion._ | - |  | **Fusion Spark**: Whenever a merge is performed on the battle board, deal 3 damage to a random enemy unit. |
| `trinket_polished_plate` | **Polished Plate**<br>_A perfectly polished piece of armor._ | - |  | A perfectly polished piece of armor. |
| `trinket_purifying_pendant` | **Purifying Pendant**<br>_When an ally takes damage from a negative status effect, removes all remaining stacks of that effect._ | - |  | When an ally takes damage from a negative status effect, removes all remaining stacks of that effect. |
| `trinket_royal_insignia` | **Royal Insignia**<br>_A medal signifying royal favor._ | - |  | **Royal Blessing**: When a Level 1 unit enters the board, grant it +1 HP and +1 PWR. |
| `trinket_rusty_ring` | **Rusty Ring**<br>_Grants +1 HP and +1 PWR to all units with no equipment. Equipping an item cancels this buff._ | - |  | **Rusty Ring**: Grants +1 HP and +1 PWR to all units with no equipment. Equipping an item cancels this buff. |
| `trinket_soul_echo` | **Soul Echo**<br>_A mystical gem that echoes the souls of the fallen._ | - |  | **Soul Echo**: When an ally dies, resurrect the first non-hero unit that died this turn. |
| `trinket_spiked_armor` | **Spiked Armor**<br>_At turn start, the frontmost unit gains 2 Armor and 2 [color=#44CC44]Spikes[/color]._ | - |  | **Spiked Armor**: At turn start, the frontmost unit gains 2 Armor and 2 [color=#44CC44]Spikes[/color]. |
| `trinket_time_sprint_charm` | **Sprint Charm**<br>_A charm that bends time._ | - |  | **Time Sprint**: Minigame timer gets a flat 2-second increase in battle. |
| `trinket_token_return_charm` | **Token Return Charm**<br>_A charm that reclaims spent potential._ | - |  | **Token Return**: The first unit to die each round returns tokens equivalent to its tier. |
| `trinket_trait_air` | **Air Trait**<br>_Enables the Air trait whenever your team has enough Air souls._ | - |  | **Gale Siphon**: At combat start, Air units steal 1 PWR from mirrored enemies if 2+ Air souls. [Target: NONE] |
| `trinket_trait_animal` | **Animal Trait**<br>_Enables the Animal trait whenever your team has enough Animal units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_appliance` | **Appliance Trait**<br>_Enables the Appliance trait whenever your team has enough Appliance units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_costume` | **Costume Trait**<br>_Enables the Costume trait whenever your team has enough Costume units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_earth` | **Earth Trait**<br>_Enables the Earth trait whenever your team has enough Earth souls._ | - |  | **Earth Ward**: At combat start, grants Armor and Spikes to allies based on Earth souls (Earth units gain double Armor). [Target: NONE] |
| `trinket_trait_fighter` | **Fighter Trait**<br>_Enables the Fighter trait whenever your team has enough Fighter units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_fire` | **Fire Trait**<br>_Enables the Fire trait whenever your team has enough Fire souls._ | - |  | **Fire Nova**: At combat start, applies 2 Burn to the opposing team if 7+ Fire souls. [Target: NONE] |
| `trinket_trait_food` | **Food Trait**<br>_Enables the Food trait whenever your team has enough Food units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_mecha` | **Mecha Trait**<br>_Enables the Mecha trait whenever your team has enough Mecha units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_plant` | **Plant Trait**<br>_Enables the Plant trait whenever your team has enough Plant units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_specialist` | **Specialist Trait**<br>_Enables the Specialist trait whenever your team has enough Specialist units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_support` | **Support Trait**<br>_Enables the Support trait whenever your team has enough Support units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_tank` | **Tank Trait**<br>_Enables the Tank trait whenever your team has enough Tank units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_toy` | **Toy Trait**<br>_Enables the Toy trait whenever your team has enough Toy units._ | - |  | **Trait Surge**: At combat start, grants +1 to +4 PWR to matching trait units based on synergy count. [Target: NONE] |
| `trinket_trait_water` | **Water Trait**<br>_Enables the Water trait whenever your team has enough Water souls._ | - |  | **Soothing Stream**: At combat start, Water units heal adjacent allies 1 HP if 2+ Water souls. [Target: NONE] |
| `trinket_trinity_charm` | **Trinity Charm**<br>_If you draw at least once from each tier machine (1, 2, and 3) in a turn or encounter, gain 1 Token._ | - |  | **Trinity Charm**: If you draw at least once from each tier machine (1, 2, and 3) in a turn or encounter, gain 1 Token. |
| `trinket_twin_charm` | **Twin Charm**<br>_A mirrored charm that reflects its surroundings._ | - |  | **Shared Reflection**: Your units gain +1 PWR for every 2 copies of that same unit in your battle pool. |
| `trinket_underdog_emblem` | **Underdog Emblem**<br>_An emblem that protects the outnumbered._ | - |  | **Outnumbered Bulwark**: At turn start, if your team has fewer units than the enemy, all allies gain 2 Armor for each unit difference. |
| `trinket_vengeance` | **Vengeance Charm**<br>_Channel the fury of fallen allies._ | - |  | When an ally dies, grant +1 HP and +1 PWR to a random ally. [Target: RANDOM_ALLY] |
| `trinket_veteran_insignia` | **Veteran Insignia**<br>_A badge of honor for seasoned warriors._ | - |  | **Veteran Blessing**: When a Level 2 unit enters the board, grant it +1 HP and +1 PWR. |


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
| `static` | **Static** | Consumed stack-by-stack whenever the unit experiences any core stat change (HP damage, healing, or power modification). Each stack consumed deals 1 armor-ignoring damage. | Does not decay. Only consumed upon stat changes. |


## Battlefield Slot Effects
| ID | Slot Name | Trigger | Effect | Cost (Gold) |
|---|---|---|---|---|
| `burn` | **Burn Slot** | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 |
| `lightning` | **Lightning Slot** | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 |
| `death` | **Death Slot** | `on_turn_end` (Sudden Death) | Systemic sudden-death slot advancing forward from Turn 10+. Immediately reduces unit HP to 0. | - |


## Traits & Synergies
The game features 15 traits across three categories: 4 Elemental Traits, 4 Class Traits, and 7 Visual Archetype Traits. Equipping the corresponding Trait Trinket enables team-wide combat synergies.

### Elemental Traits (Souls)
Units carry elemental Soul tags (Fire, Earth, Water, Air). Equipping the corresponding elemental Trinket activates synergies at combat start (`on_pre_combat`) based on active lineup souls:
| Trait | Focus | Synergy Thresholds | Effect |
|---|---|---|---|
| **Fire** | Offensive Pressure | 3 / 5 / 7 / 9 Souls | Applies Burn on attack. At 7+ souls, applies 2 Burn to the entire enemy team at combat start. |
| **Earth** | Defensive Sustain | 3 / 5 / 7 / 9 Souls | Grants Armor (3, 5, 7, 9) and Spikes (7, 9) to allies at combat start. Earth units gain double armor bonus. |
| **Water** | Resilience | 2 / 4 / 6 / 8 Souls | Water units heal adjacent allies 1 HP at combat start. |
| **Air** | Disruption | 2 / 4 / 6 / 8 Souls | Air units steal 1 Power (PWR) from mirrored enemy slots at combat start. |

### Class & Visual Archetype Traits (Units)
Class and Visual traits are enabled when the team equips that trait's trinket. At the start of combat (`on_pre_combat`, when the Battle button is pressed, before turn actions begin), the trinket grants a scaling Power buff to all units of that trait in the lineup:
| Trait Category | Traits | Synergy Thresholds | Effect (Trait Surge) |
|---|---|---|---|
| **Class Traits** | Tank, Fighter, Support, Specialist | 2 / 3 / 4 / 5 Units | Grants +1 PWR (2 units), +2 PWR (3 units), +3 PWR (4 units), +4 PWR (5 units) to matching trait units at combat start. |
| **Visual Archetypes** | Food, Mecha, Animal, Plant, Toy, Appliance, Costume | 2 / 3 / 4 / 5 Units | Grants +1 PWR (2 units), +2 PWR (3 units), +3 PWR (4 units), +4 PWR (5 units) to matching trait units at combat start. |
