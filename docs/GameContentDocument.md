Game Content Document: Flashcard Heroes
Units
Units are the primary actors in battle. They have Health (HP) and Power (PWR) stats, can equip items, and possess abilities.
Player-Exclusive Units
ID: hero
Name: Hero
Description: The player's champion.
Stats:
Tier: 0
HP: 10
Power: 2
Item Slots: 5
Abilities: None by default.
Standard Units
ID: unit_t1_a
Name: Apprentice
Description: A novice unit.
Stats:
Tier: 1
Cost: 1
HP: 1
Power: 2
Item Slots: 1
Abilities:
Basic Attack (basic_attack):
Description: "Deal (PWR) damage to the frontmost enemy."
Effect: Deals damage equal to the unit's Power to the primary enemy target.
Resilience (unit_tier1a_passive_heal):
Description: "When hurt, Heal this unit by (PWR) HP."
Trigger: on_hurt (when this unit takes damage).
Condition: The damage taken is not lethal.
Effect: Heals this unit for HP equal to its current PWR.
ID: unit_t1_b
Name: Squire
Description: A loyal squire.
Stats:
Tier: 1
Cost: 1
HP: 2
Power: 1
Item Slots: 1
Abilities:
Basic Attack (basic_attack):
Description: "Deal (PWR) damage to the frontmost enemy."
Effect: Deals damage equal to the unit's Power to the primary enemy target.
Retaliation (unit_tier1b_counter_on_hurt):
Description: "When hurt, Counter-attack the attacker for damage equal to this unit's current PWR. Triggers on final time when the damage to this unit is lethal."
Trigger: on_hurt (when this unit takes damage).
Condition: Damage was received (triggers even on lethal hits).
Effect: Performs a basic attack against the attacker.
ID: unit_t2_c
Name: Knight
Description: A valiant knight.
Merge Recipe:
Ingredient A: unit_t1_a (Apprentice)
Ingredient B: unit_t1_b (Squire)
Stats:
Tier: 2
Cost: 2
HP: 3
Power: 3
Item Slots: 2
Abilities:
Morale Boost (unit_tier2c_ally_death_buff):
Description: "When an ally is defeated, gain +1 HP and +1 PWR."
Trigger: on_ally_death (when another allied unit is defeated).
Effect: Gains +1 HP and +1 Power for the remainder of the battle.
ID: unit_t3_d
Name: (Not defined in game.csv)
Description: (Not defined in game.csv)
Merge Recipe:
Ingredient A: unit_t2_c (Knight)
Ingredient B: unit_t2_c (Knight)
Stats:
Tier: 3
Cost: 3
HP: 6
Power: 6
Item Slots: 4
Abilities:
Resilient Aura (unit_tier3d_resilient_aura):
Description: "When hurt, grants +1 HP and +1 PWR to adjacent allies."
Trigger: on_hurt (when this unit takes damage).
Priority: 100 (High).
Effect: Grants +1 HP and +1 Power to adjacent allied units for the duration of the battle.
Enemy-Exclusive Units
ID: enemy_hero
Name: Enemy Hero
Description: The enemy's champion.
Stats:
Tier: 0
HP: 10
Power: 2
Item Slots: 5
Abilities: None by default.
Items
Items can be equipped onto Units to provide stat bonuses and grant new abilities.
ID: item_t1_a
Name: Small HP Potion
Description: Placeholder
Stats:
Tier: 1
Cost: 1
Bonus HP: +1
Bonus Power: +0
Ability:
Restoration (item_tier1a_turn_start_heal):
Description: "At the start of the turn, Heal the holder for 2 HP."
Trigger: on_turn_start.
Effect: Heals the unit holding this item for 2 HP.
ID: item_t1_b
Name: Small PWR Potion
Description: Placeholder
Stats:
Tier: 1
Cost: 1
Bonus HP: +0
Bonus Power: +1
Ability:
Extra Attack (item_tier1b_extra_attack):
Description: "When attacking, if target has more HP than holder then perform an extra attack."
Trigger: on_attack.
Priority: -100 (Low).
Condition: The attack target's current HP is greater than the attacker's current HP.
Effect: Causes the holder to perform a second basic attack against the same target.
ID: item_t2_c
Name: Large HP Potion
Description: Restores a large amount of HP and PWR.
Merge Recipe:
Ingredient A: item_t1_a (Small HP Potion)
Ingredient B: item_t1_b (Small PWR Potion)
Stats:
Tier: 2
Cost: 2
Bonus HP: +1
Bonus Power: +1
Ability:
Regeneration (item_tier2c_passive_heal):
Description: "When hurt, Heal this unit by 1 HP."
Trigger: on_hurt.
Condition: The damage taken is not lethal.
Effect: Heals the unit holding this item for 1 HP.
ID: item_t3_d
Name: (Not defined in game.csv)
Description: (Not defined in game.csv)
Merge Recipe:
Ingredient A: item_t2_c (Large HP Potion)
Ingredient B: item_t2_c (Large HP Potion)
Stats:
Tier: 3
Cost: 3
Bonus HP: +2
Bonus Power: +2
Ability:
Overflow (item_tier3d_overflow):
Description: "Excess damage from lethal attacks is dealt to the adjacent unit behind the target."
Trigger: on_attack.
Priority: -10.
Effect: If the attack is lethal, any overkill damage is dealt to an adjacent enemy.
Trinkets
Trinkets provide team-wide abilities and are not equipped on individual units.
Budget Cost: All trinkets have a default cost of 10 gold for encounter generation purposes.
Player Acquisition: Trinkets are obtained by defeating bosses.

Healing Amulet
ID: trinket_healing_amulet
Name: Healing Amulet
Description: A simple but reliable enchanted charm.
Player Exclusive: No
Ability:
Healing Aura: (Ability name not explicitly defined, derived from description)
Description: "At the start of the turn, Heals the frontmost ally unit by 2 HP."
Trigger: on_turn_start.
Effect: Heals the allied unit in the front-most position for 2 HP.
Targeting: "Front-most" is the player's right-most unit (highest slot index) or the enemy's left-most unit (lowest slot index).

Royal Insignia
ID: trinket_royal_insignia
Name: Royal Insignia
Description: "Start with morale."
Player Exclusive: No
Ability:
Description: "Whenever you Draw, Summon, or Start Battle with a Tier 1 unit, grant it +2 HP and +2 PWR."
Trigger: on_draw, on_ally_summon, on_battle_start
Target: Self (if Tier 1)
Effect: Grants +2 HP and +2 PWR.
Note: Prevents multiple applications via `buff_applied` tag.