Flashcard Heroes - Game Content (V1.1 - System Test Set)
This document serves as the master list for all game content, specifically designed to test the full breadth of the ability system. Each ability features a unique combination of a trigger, condition, and target type.

Part 1: Trigger Types
Triggers are the specific gameplay moments that can cause an ability to activate.
StringName Identifier	Description	Context Provided
Battle Flow Triggers		
on_battle_start	Fires once for every unit at the very beginning of combat, before any turns.	{}
on_battle_end	Fires once for every surviving unit after a battle concludes (victory or defeat).	{ "is_victory": bool }
Turn Flow Triggers		
on_turn_start	Fires at the beginning of each "turn" cycle, before the first unit acts.	{ "turn_number": int }
on_turn_end	Fires at the end of each "turn" cycle, after all units have acted.	{ "turn_number": int }
Combat Action Triggers		
on_attack	Fires when the unit initiates its attack action, before damage is dealt.	{ "target_uuid": String }
on_after_attack	Fires after the unit's entire attack sequence (including triggered effects) has resolved.	{ "target_uuid": String }
on_deal_damage	Fires when this unit successfully deals damage to another unit.	{ "target_uuid": String, "damage_dealt": int }
Reactive Triggers		
on_hurt	Fires when the unit takes any form of damage.	{ "attacker_uuid": String, "damage_taken": int }
on_is_healed	Fires when the unit receives HP from a healing effect.	{ "healer_uuid": String, "hp_healed": int }
on_kill	Fires when this unit's attack or ability defeats another unit.	{ "victim_uuid": String }
Unit Lifecycle Triggers		
on_death	Fires when the unit's HP is reduced to 0 or less.	{}
on_ally_death	Fires when any allied unit on the board dies.	{ "fainting_ally_uuid": String }
on_enemy_death	Fires when any enemy unit on the board dies.	{ "fainting_enemy_uuid": String }
on_summon	Fires for the SUMMONER when its ability successfully summons a new unit.	{ "summoned_uuids": Array[String] }
on_is_summoned	Fires for the UNIT that was just summoned onto the board.	{ "summoner_uuid": String }
Meta & Passive Triggers		
passive	Not a trigger. Denotes a constant effect, typically a stat modification from an item.	{}
on_equip_item	Fires for a unit when an item is equipped onto it.	{ "item_uuid": String }
Part 2: Targeting Types
Targeting types define who or what an effect will be applied to.
StringName Identifier	Description
Self/Source Targets	
SELF	The unit that owns the ability.
HOLDER	The unit equipping the item that owns the ability.
ATTACK_TARGET	The direct target of an on_attack trigger.
Contextual Targets	
TRIGGERING_ENTITY	The other unit involved in a reactive trigger (e.g., the attacker in an on_hurt event).
FAINTING_ALLY	The specific ally whose death triggered an on_ally_death event.
Positional Targets	
FRONTMOST_ENEMY	The enemy unit in the frontmost position.
BACKMOST_ENEMY	The enemy unit in the backmost position.
ALLY_BEHIND	The allied unit in the slot directly behind this one.
ADJACENT_ALLIES	The allies directly in front of and behind this one.
ALLIES_AHEAD	All allies in front of this unit.
Attribute-Based Targets	
LOWEST_HP_ALLY	The allied unit (or one of them, randomly chosen) with the lowest current HP.
HIGHEST_PWR_ENEMY	The enemy unit (or one of them) with the highest current Power.
Group Targets	
ALL_ALLIES	All allied units currently on the board.
ALL_OTHER_ALLIES	All allied units except for SELF.
ALL_ENEMIES	All enemy units currently on the board.
ALL_UNITS	All units on the board, both allied and enemy.
Random Targets	
RANDOM_ENEMY	One randomly selected enemy unit.
RANDOM_ALLY	One randomly selected allied unit (can include SELF).
RANDOM_N_ENEMIES	A specified number of unique random enemies. Requires a parameter, e.g., {"count": 2}.
Part 3: Condition Types
Conditions are checks that must pass for an ability (or sometimes an effect) to proceed.
StringName Identifier	Description	Parameters
Self State		
SELF_IS_AT_FULL_HP	Checks if the source unit's current_hp is equal to its base_hp.	{}
SELF_HP_IS_BELOW	Checks if the source unit's HP is below a certain value.	{"value": int}
SELF_HAS_STATUS	Checks if the source unit has a specific status effect.	{"status_id": StringName}
Target State		
TARGET_HAS_TAG	Checks if the ATTACK_TARGET has a specific tag (e.g., "Beast").	{"tag": StringName}
TARGET_IS_DAMAGED	Checks if the ATTACK_TARGET's current_hp is less than its base_hp.	{}
Global State		
ALLY_COUNT_IS	Checks if the number of allies on the board matches a condition.	{"comparison": "less_than", "value": int}
TURN_NUMBER_IS	Checks if the current turn number is even, odd, or a specific number.	{"type": "even"} or {"type": "odd"}
SLOT_AHEAD_IS_EMPTY	Checks if the combat slot directly in front of the source unit is unoccupied.	{}
Contextual State		
TRIGGERING_DAMAGE_WAS_NOT_LETHAL	In an on_hurt trigger, checks if the damage taken did not defeat the unit.	{}
FAINTING_ALLY_HAS_TAG	In an on_ally_death trigger, checks if the dying ally had a specific tag.	{"tag": StringName}
VICTIM_WAS_HIGHEST_TIER_ENEMY	In an on_kill trigger, checks if the defeated unit was of the highest tier on the enemy team.	{}
Part 4: Effect Types
Effects are the "verbs" of the system—the actions that abilities perform.
A. Core Effect Definitions
StringName Identifier	Description	Example Parameters
EffectDealDamage	Deals damage to the target(s). Supports stat-scaling.	{"pwr_multiplier": 1.5, "base_value": 2}
EffectModifyStat	Modifies the current stats of the target(s).	{"hp_gain": {"pwr_multiplier": 0.5}, "pwr_gain": 2}
EffectSummonUnit	Summons a new unit onto the board at a specified location.	{"definition": "unit_bee", "power": 1, "health": 1}
EffectApplyStatus	Applies stacks of a status effect to the target(s).	{"status_id": "poison", "stacks": 3}
EffectRemoveStatus	Removes stacks of a status effect. Can target specific types.	{"status_type": "debuff", "stacks": "all"}
EffectMoveUnit	Moves a unit to a different position on the board.	{"move_type": "swap_with_ally_behind"}
EffectDestroyUnit	Instantly defeats the target(s), ignoring HP.	{}
EffectGainGachaTokens	Grants the player a number of Gacha Tokens for the current battle.	{"amount": 1}
B. Status Effect Types (for use with EffectApplyStatus)
These are the specific statuses that can be applied.
StringName Identifier	Type	Mechanic	Lifecycle
strength	Buff	Additive: Adds +1 PWR per stack to the unit's stat calculation.	Loses 1 stack at the end of its turn.
regeneration	Buff	End of Turn: Heals the unit for 1 HP per stack.	Loses 1 stack after healing.
armor	Buff	Damage Reduction: Reduces incoming attack damage by 1 per stack.	Loses 1 stack when hit by an attack.
poison	Debuff	Start of Turn: Deals 1 damage per stack to the unit.	Loses 1 stack after taking damage.
weaken	Debuff	Additive: Subtracts -1 PWR per stack from the unit's stat calculation.	Loses 1 stack at the end of its turn.
vulnerable	Debuff	Multiplicative: Increases all damage taken by 50%. Stacks do not increase the percentage, only the duration.	Loses 1 stack when it takes damage.
daze	Debuff	Unit cannot perform its on_attack action.	Loses 1 stack instead of attacking.

Part 1: GachaBall Units
Tier 1 Units
1.1. Cricket
Definition ID: unit_cricket
Base Stats: base_hp: 1, base_pwr: 1
Abilities:
Ability 1: Desperate Lash
Ability Definition ID: ability_desperate_lash
Description Key: ability_desperate_lash_desc ("On Death: If this is your last unit, deal 2 damage to all enemies.")
Trigger: on_death
Condition:
Condition Definition ID: cond_is_last_unit_alive
Condition Type: IS_LAST_UNIT_ALIVE
Effects:
Effect 1: Area Damage
Effect Definition Type: EffectDealDamage
Target Type: ALL_ENEMIES
Parameters: {"damage": 2}
Fallback Ability: This unit uses the Default Basic Attack on its turn.
1.2. Underdog Weasel
Definition ID: unit_weasel
Base Stats: base_hp: 1, base_pwr: 2
Abilities:
Ability 1: Bolster the Weak
Ability Definition ID: ability_bolster_the_weak
Description Key: ability_bolster_the_weak_desc ("Start of Battle: If your team has fewer units than the enemy team, give your ally with the lowest HP +2/+2.")
Trigger: on_battle_start
Condition:
Condition Definition ID: cond_team_size_less_than_enemy
Condition Type: TEAM_SIZE_LESS_THAN_ENEMY
Effects:
Effect 1: Buff Lowest HP
Effect Definition Type: EffectModifyStat
Target Type: LOWEST_HP_ALLY
Parameters: {"hp_gain": 2, "pwr_gain": 2, "is_permanent": true}
Fallback Ability: Default Basic Attack.
Tier 2 Units
2.1. Spider
Definition ID: unit_spider
Base Stats: base_hp: 2, base_pwr: 2
Abilities:
Ability 1: Rearguard Support
Ability Definition ID: ability_rearguard_support
Description Key: ability_rearguard_support_desc ("End of Turn: If the slot ahead is empty, summon a Cricket in the empty slot in front of this unit.")
Trigger: on_turn_end
Condition:
Condition Definition ID: cond_slot_ahead_is_empty
Condition Type: SLOT_AHEAD_IS_EMPTY
Effects:
Effect 1: Summon Cricket
Effect Definition Type: EffectSummonUnit
Target Type: SELF
Parameters: {"definition": "unit_cricket", "power": 1, "health": 1}
Fallback Ability: Default Basic Attack.
Tier 3 Units
3.1. Beast Hunter Mantis
Definition ID: unit_mantis
Base Stats: base_hp: 3, base_pwr: 4
Abilities:
Ability 1: Hunter's Mark
Ability Definition ID: ability_hunters_mark
Description Key: ability_hunters_mark_desc ("On Attack: If the target has the 'tier_3' tag, deal 3 damage to a different random enemy.")
Trigger: on_attack
Condition:
Condition Definition ID: cond_target_has_tag_tier_3
Condition Type: TARGET_HAS_TAG
Parameters: {"tag": "tier_3"}
Effects:
Effect 1: Ricochet Shot
Effect Definition Type: EffectDealDamage
Target Type: RANDOM_ENEMY (Must be implemented to exclude the primary attack target)
Parameters: {"damage": 3}
Effect 2: Base Attack (ensures it still attacks the primary target)
Effect Definition Type: EffectDealDamage
Target Type: ATTACK_TARGET
Parameters: {"damage_from_stat": "PWR"}
Fallback Ability: If the on_attack condition is not met, the BattleManager will issue a Default Basic Attack.
Part 2: GachaBall Items
Tier 1 Items
2.1. Wooden Clock
Definition ID: item_wooden_clock
Abilities:
Ability 1: Rhythmic Heal
Ability Definition ID: ability_rhythmic_heal
Description Key: ability_rhythmic_heal_desc ("Start of Turn: If it is an even-numbered turn (2, 4, ...), holder gains (PWR) as +HP.")
Trigger: on_turn_start
Condition:
Condition Definition ID: cond_turn_is_even
Condition Type: TURN_NUMBER_IS_EVEN
Effects:
Effect 1: Heal
Effect Definition Type: EffectModifyStat
Target Type: HOLDER
Parameters: {"hp_gain": (PWR), "is_permanent": true}
2.2. Insect Totem
Definition ID: item_insect_totem
Abilities:
Ability 1: Swarm's Fury
Ability Definition ID: ability_swarms_fury
Description Key: ability_swarms_fury_desc ("When an allied 'Insect' dies, give the holder's adjacent allies (PWR) as +HP.")
Trigger: on_ally_death
Condition:
Condition Definition ID: cond_ally_died
Condition Type: ALLY_DIED
Parameters: {"tag": "all"}
Effects:
Effect 1: Buff Neighbors
Effect Definition Type: EffectModifyStat
Target Type: ADJACENT_ALLIES (of the holder)
Parameters: {"hp_gain": (PWR), "pwr_gain": (PWR), "is_permanent": true}
Tier 2 Items
2.3. Garlic Armor
Definition ID: item_garlic_armor
Abilities:
Ability 1: Sturdy Retaliation
Ability Definition ID: ability_sturdy_retaliation
Description Key: ability_sturdy_retaliation_desc ("On Hurt: If the damage was not lethal, deal (PWR) damage back to the attacker.")
Trigger: on_hurt
Condition:
Condition Definition ID: cond_damage_was_not_lethal
Condition Type: TRIGGERING_DAMAGE_WAS_NOT_LETHAL
Effects:
Effect 1: Damage Attacker
Effect Definition Type: EffectDealDamage
Target Type: TRIGGERING_ENTITY
Parameters: {"damage": (PWR)}
Tier 3 Items
2.4. Trophy Hunter's Axe
Definition ID: item_trophy_axe
Abilities:
Ability 1: Execute Order
Ability Definition ID: ability_execute_order
Description Key: ability_execute_order_desc ("On Kill: If the defeated unit was the highest tier enemy on the board, deal (PWR) damage to the frontmost enemy.")
Trigger: on_kill
Condition:
Condition Definition ID: cond_victim_was_highest_tier
Condition Type: VICTIM_WAS_HIGHEST_TIER_ENEMY
Effects:
Effect 1: Chain Shot
Effect Definition Type: EffectDealDamage
Target Type: FRONTMOST_ENEMY
Parameters: {"damage": (PWR)}