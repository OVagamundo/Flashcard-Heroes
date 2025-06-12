Flashcard Heroes: Gachamon - Game Content (v1.0)
Introduction
This document details the unit GachaBallDefinition data for Flashcard Heroes. All entries are formatted to be compliant with the systems and terminology defined in the Flashcard Heroes GDD v3.0.
Standard GachaBallDefinition (Unit) Structure
id: (StringName) Unique programmatic identifier.
display_name_key: (String) Localization key for the unit's name.
description_key: (String) Localization key for the unit's flavor text/description.
icon_texture: (Resource Path) Path to the unit's icon.
tier: (Integer) The unit's power tier (1, 2, or 3).
rarity: (Enum) The unit's rarity (COMMON, UNCOMMON, RARE, LEGENDARY).
ball_category: (Enum) Set to UNIT.
base_hp: (Integer) The unit's base Health Points.
base_pwr: (Integer) The unit's base Power.
item_slot_count: (Integer) Number of equippable item slots.
tags: (Array of StringName) List of tags for synergies and targeting.
ability_definition_refs: (Array of AbilityDefinition IDs) List of abilities.
merge_recipe: (String, Optional) The formula to create this unit.
Use code with caution.
Tier 1 Units
1. Stonepelt Guard
id: unit_t1_tank_01
display_name_key: "Stonepelt Guard"
description_key: "A sturdy Earthen warrior. Its rocky hide seems to mend itself when struck."
icon_texture: res://art/units/ART_T1_TANK_01.png
tier: 1
rarity: COMMON
ball_category: UNIT
base_hp: 60
base_pwr: 8
item_slot_count: 1
tags: ["Earthen", "Warrior", "PhysicalAffinity"]
ability_definition_refs:
Ability: Reactive Plating
Trigger: ON_HURT
Targeting: SELF
Effects: [{ keyword: INCREASE_HP, params: { amount: "5 + (0.5 * SELF_PWR)" } }]
Description: "When this unit takes damage, it increases its HP by an amount based on its PWR."
2. Hexer Acolyte
id: unit_t1_support_01
display_name_key: "Hexer Acolyte"
description_key: "A practitioner of debilitating magic, weakening even the mightiest foes with a whispered curse."
icon_texture: res://art/units/ART_T1_SUPPORT_01.png
tier: 1
rarity: COMMON
ball_category: UNIT
base_hp: 40
base_pwr: 10
item_slot_count: 1
tags: ["Mystic", "Priest", "ShadowAffinity"]
ability_definition_refs:
Ability: Enfeeble
Trigger: ON_ATTACK
Targeting: RANDOM_ENEMY
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Weaken", stacks: "1 + (SELF_PWR / 5)", duration: 2 } }]
Description: "On attack, applies Weaken stacks to the target for 2 turns, reducing their PWR."
3. Swift Striker
id: unit_t1_attacker_01
display_name_key: "Swift Striker"
description_key: "A Nomad rogue who excels at exploiting any sign of weakness, striking again before the enemy can recover."
icon_texture: res://art/units/ART_T1_ATTACKER_01.png
tier: 1
rarity: COMMON
ball_category: UNIT
base_hp: 45
base_pwr: 12
item_slot_count: 1
tags: ["Nomad", "Rogue", "PhysicalAffinity"]
ability_definition_refs:
Ability: Exploit Opening
Trigger: ON_ATTACK
Conditions: [{ condition: HEALTH_BELOW_X_PERCENT, params: { target: DEFENDER, value: 100 } }]
Targeting: DEFENDER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR" } }]
Description: "Attacks an additional time if the target is not at full HP."
4. Ember Caster
id: unit_t1_mage_01
display_name_key: "Ember Caster"
description_key: "An Infernal mage who leaves behind smoldering embers that erupt into persistent, searing flames."
icon_texture: res://art/units/ART_T1_MAGE_01.png
tier: 1
rarity: COMMON
ball_category: UNIT
base_hp: 35
base_pwr: 14
item_slot_count: 1
tags: ["Infernal", "Mage", "FireAffinity"]
ability_definition_refs:
Ability: Scorch
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR", duration: 3 } }]
Description: "On attack, applies Burn stacks to the target for 3 turns."
Tier 2 Units
1. Bastion Protector
id: unit_t2_tank_02
display_name_key: "Bastion Protector"
description_key: "A hulking golem that draws strength from the number of its foes, becoming more resilient with every enemy it faces."
icon_texture: res://art/units/ART_T2_TANK_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 130
base_pwr: 15
item_slot_count: 2
tags: ["Earthen", "Warrior", "Golem"]
ability_definition_refs:
Ability: Crowd Defense
Trigger: ON_TURN_START
Targeting: SELF
Effects: [{ keyword: INCREASE_HP, params: { amount: "5 * ENEMY_COUNT_IN_LINEUP" } }]
Description: "At the start of its turn, increases its HP for each enemy unit in the lineup."
merge_recipe: unit_t1_tank_01 + unit_t1_tank_01
2. Guardian Healer
id: unit_t2_support_02
display_name_key: "Guardian Healer"
description_key: "A Celestial priest who mends the wounds of the ally fighting before them."
icon_texture: res://art/units/ART_T2_SUPPORT_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 90
base_pwr: 20
item_slot_count: 2
tags: ["Celestial", "Priest", "HolyAffinity", "Healing"]
ability_definition_refs:
Ability: Frontline Mend
Trigger: ON_HURT
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR" } }]
Description: "When an ally directly in front of this unit takes damage, heal that ally."
merge_recipe: unit_t1_support_01 + unit_t1_support_01
3. Challenger Duelist
id: unit_t2_attacker_02
display_name_key: "Challenger Duelist"
description_key: "This Nomad rogue sizes up their opponent, siphoning their strength for a single, decisive blow."
icon_texture: res://art/units/ART_T2_ATTACKER_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 100
base_pwr: 25
item_slot_count: 2
tags: ["Nomad", "Rogue", "PhysicalAffinity"]
ability_definition_refs:
Ability: Power Siphon
Trigger: ON_ATTACK
Targeting: SELF
Effects: [{ keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "FRONTMOST_ENEMY_PWR * 0.5", duration: "ThisAttackOnly" } }]
Description: "Before attacking, gain bonus PWR equal to 50% of the frontmost enemy's PWR for this attack."
merge_recipe: unit_t1_attacker_01 + unit_t1_attacker_01
4. Pyre Sorcerer
id: unit_t2_mage_02
display_name_key: "Pyre Sorcerer"
description_key: "A master of explosive magic, whose fireballs scorch not only their target but those nearby as well."
icon_texture: res://art/units/ART_T2_MAGE_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 80
base_pwr: 28
item_slot_count: 2
tags: ["Infernal", "Mage", "FireAffinity", "AoE"]
ability_definition_refs:
Ability: Fireblast
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [ { keyword: APPLY_STATUS_EFFECT, params: { target: DEFENDER, status: "Burn", stacks: "SELF_PWR", duration: 3 } }, { keyword: APPLY_STATUS_EFFECT, params: { target: ADJACENT_ENEMIES, status: "Burn", stacks: "SELF_PWR * 0.5", duration: 3 } } ]
Description: "On attack, applies Burn stacks to the target and half as many stacks to adjacent enemies."
merge_recipe: unit_t1_mage_01 + unit_t1_mage_01
5. Spirit Warden
id: unit_t2_sentinel_02
display_name_key: "Spirit Warden"
description_key: "Upon its defeat, this guardian bestows its remaining spiritual energy upon the ally behind it."
icon_texture: res://art/units/ART_T2_SENTINEL_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 110
base_pwr: 18
item_slot_count: 2
tags: ["Earthen", "Priest", "Guardian"]
ability_definition_refs:
Ability: Parting Gift
Trigger: ON_DEATH
Targeting: ALLY_BEHIND_SELF
Effects: [ { keyword: INCREASE_HP, params: { amount: "SELF_PWR * 1.5" } }, { keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "SELF_PWR", duration: 2 } } ]
Description: "When this unit dies, grants HP and PWR to the ally directly behind it for 2 turns."
merge_recipe: unit_t1_tank_01 + unit_t1_support_01
6. Ironclad Retaliator
id: unit_t2_bruiser_02
display_name_key: "Ironclad Retaliator"
description_key: "A Clockwork warrior built for one purpose: to return every blow with mechanical precision."
icon_texture: res://art/units/ART_T2_BRUISER_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 120
base_pwr: 22
item_slot_count: 2
tags: ["Clockwork", "Warrior", "PhysicalAffinity", "CounterAttack"]
ability_definition_refs:
Ability: Counter-Strike
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.75", type: "Physical" } }]
Description: "When this unit takes damage, it attacks the attacker."
merge_recipe: unit_t1_attacker_01 + unit_t1_tank_01
7. Agile Hunter
id: unit_t2_ranger_02
display_name_key: "Agile Hunter"
description_key: "This Sylvan ranger coordinates with their pack, firing a shot whenever a nearby ally makes a move."
icon_texture: res://art/units/ART_T2_RANGER_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 95
base_pwr: 24
item_slot_count: 2
tags: ["Sylvan", "Ranger", "PhysicalAffinity", "Assist"]
ability_definition_refs:
Ability: Coordinated Shot
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.6", type: "Physical" } }]
Description: "When an adjacent ally attacks, this unit attacks a random enemy."
merge_recipe: unit_t1_attacker_01 + unit_t1_support_01
8. Battle Medic
id: unit_t2_cleric_02
display_name_key: "Battle Medic"
description_key: "A Celestial priest whose healing aura soothes their own wounds and those of the ally they protect."
icon_texture: res://art/units/ART_T2_CLERIC_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 100
base_pwr: 20
item_slot_count: 2
tags: ["Celestial", "Priest", "HolyAffinity", "Healing"]
ability_definition_refs:
Ability: Mending Aura
Trigger: ON_HURT
Targeting: SELF
Effects: [ { keyword: INCREASE_HP, params: { target: SELF, amount: "SELF_PWR * 0.5" } }, { keyword: INCREASE_HP, params: { target: ALLY_BEHIND_SELF, amount: "SELF_PWR * 0.5" } } ]
Description: "When this unit takes damage, it heals itself and the ally directly behind it."
merge_recipe: unit_t1_mage_01 + unit_t1_tank_01
9. Morale Booster
id: unit_t2_buffer_02
display_name_key: "Morale Booster"
description_key: "This Mystic priest's rallying cry inspires the warrior before them to strike with greater force."
icon_texture: res://art/units/ART_T2_BUFFER_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 85
base_pwr: 22
item_slot_count: 2
tags: ["Mystic", "Priest", "BuffFocus"]
ability_definition_refs:
Ability: Rallying Cry
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: "SELF_PWR / 3", duration: 2 } }]
Description: "When an ally directly in front attacks, apply Strength stacks to that ally for 2 turns."
merge_recipe: unit_t1_mage_01 + unit_t1_support_01
10. Vengeful Pyromancer
id: unit_t2_spellcaster_02
display_name_key: "Vengeful Pyromancer"
description_key: "The loss of a comrade fuels this Infernal mage's rage, unleashing a burst of soulfire upon a random foe."
icon_texture: res://art/units/ART_T2_SPELLCASTER_02.png
tier: 2
rarity: UNCOMMON
ball_category: UNIT
base_hp: 90
base_pwr: 26
item_slot_count: 2
tags: ["Infernal", "Mage", "FireAffinity", "Reactive"]
ability_definition_refs:
Ability: Soulfire Burst
Trigger: ON_ALLY_DIES
Targeting: RANDOM_ENEMY
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 1.2", duration: 3 } }]
Description: "Whenever an allied unit dies, apply Burn stacks to a random enemy for 3 turns."
merge_recipe: unit_t1_mage_01 + unit_t1_attacker_01
Tier 3 Units
Fusions with T2_TANK_02 (Bastion Protector)
1. Colossus Bulwark
id: unit_t3_tank_03_a
display_name_key: "Colossus Bulwark"
description_key: "A living mountain of stone and earth, it constantly regenerates, shrugging off even grievous wounds."
icon_texture: res://art/units/ART_T3_COLOSSUS_BULWARK_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 300
base_pwr: 30
item_slot_count: 4
tags: ["Earthen", "Warrior", "Golem", "Fortified", "RegenFocus"]
ability_definition_refs:
Ability: Titan's Vitality
Trigger: ON_TURN_START
Targeting: SELF
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Regeneration", amount: "SELF_PWR * 0.15", duration: 1 } }]
Description: "At the start of its turn, gains Regeneration, healing for an amount based on its PWR."
merge_recipe: unit_t2_tank_02 + unit_t2_tank_02
2. Ancestral Guardian
id: unit_t3_monk_03
display_name_key: "Ancestral Guardian"
description_key: "A Celestial warrior whose spirit is bound to its duty. Upon falling, it transfers its entire life force to the ally it was protecting."
icon_texture: res://art/units/ART_T3_ANCESTRAL_GUARDIAN_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 260
base_pwr: 25
item_slot_count: 4
tags: ["Celestial", "Warrior", "Guardian", "Sacrifice"]
ability_definition_refs:
Ability: Spirit Transfer
Trigger: ON_DEATH
Targeting: ALLY_BEHIND_SELF
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_BASE_HP" } }]
Description: "When this unit dies, heals the ally directly behind it for an amount equal to this unit's base HP."
merge_recipe: unit_t2_tank_02 + unit_t2_support_02
3. Frenzied Juggernaut
id: unit_t3_berserker_03
display_name_key: "Frenzied Juggernaut"
description_key: "A relentless force of destruction that heals itself with its own fury and attacks without end until its target falls."
icon_texture: res://art/units/ART_T3_FRENZIED_JUGGERNAUT_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 240
base_pwr: 40
item_slot_count: 4
tags: ["Nomad", "Warrior", "PhysicalAffinity", "Relentless"]
ability_definition_refs:
Ability: Unstoppable Fury
Trigger: ON_TURN_START
Targeting: SELF
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR" } }]
Description: "At the start of its turn, increases its HP by an amount equal to its PWR."
Ability: Relentless Assault
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR", repeat_until: "TARGET_DIES_OR_SELF_DIES", max_repeats: 3 } }]
Description: "Continues to attack its target until the target is defeated or this unit is defeated (max 3 extra attacks per turn)."
merge_recipe: unit_t2_tank_02 + unit_t2_attacker_02
4. Gatekeeper Summoner
id: unit_t3_summoner_03
display_name_key: "Gatekeeper Summoner"
description_key: "This Infernal mage uses the souls of fallen allies as a conduit, pulling another warrior from the master pool to take their place."
icon_texture: res://art/units/ART_T3_GATEKEEPER_SUMMONER_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 220
base_pwr: 35
item_slot_count: 4
tags: ["Infernal", "Mage", "Summoner", "ArcaneConstruct"]
ability_definition_refs:
Ability: Soul Conduit
Trigger: ON_ALLY_DIES
Targeting: EMPTY_ALLY_SLOT
Effects: [{ keyword: SUMMON_UNIT, params: { pool: "MASTER_RUN_POOL_TIER_2", slot: "TARGET" } }]
Cooldown: 2
Description: "When an allied unit dies, summon a random Tier 2 Unit from your Master Run Pool into an available slot. (Has a 2-turn cooldown)."
merge_recipe: unit_t2_tank_02 + unit_t2_mage_02
5. Aegis Protector
id: unit_t3_bodyguard_03
display_name_key: "Aegis Protector"
description_key: "A true guardian, it throws itself in the way of harm meant for its neighbors, mending its own wounds in the process."
icon_texture: res://art/units/ART_T3_AEGIS_PROTECTOR_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 280
base_pwr: 30
item_slot_count: 4
tags: ["Earthen", "Warrior", "Guardian", "Protector"]
ability_definition_refs:
Ability: Intercept
Trigger: ON_HURT
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: SELF
Effects: [ { keyword: REDIRECT_DAMAGE_TO_SELF, params: { original_target: SOURCE_OF_TRIGGER, percentage: 100 } }, { keyword: INCREASE_HP, params: { target: SELF, amount: "SELF_PWR * 0.5" } } ]
Description: "When an adjacent ally takes damage, this unit takes that damage instead and heals itself."
merge_recipe: unit_t2_tank_02 + unit_t2_sentinel_02
6. Spineshield Punisher
id: unit_t3_revenger_03
display_name_key: "Spineshield Punisher"
description_key: "This Clockwork creation is covered in razor-sharp shards that reflect all incoming damage back at the attacker."
icon_texture: res://art/units/ART_T3_SPINESHIELD_PUNISHER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 250
base_pwr: 32
item_slot_count: 4
tags: ["Clockwork", "Warrior", "CounterAttack", "Thorns"]
ability_definition_refs:
Ability: Retribution Shard
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "DAMAGE_TAKEN", type: "True" } }]
Description: "When this unit takes damage, it deals True damage to the attacker equal to the damage taken."
merge_recipe: unit_t2_tank_02 + unit_t2_bruiser_02
7. Phalanx Captain
id: unit_t3_spearmen_03
display_name_key: "Phalanx Captain"
description_key: "A master of formation fighting, its attack changes based on its position in the line."
icon_texture: res://art/units/ART_T3_PHALANX_CAPTAIN_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 230
base_pwr: 38
item_slot_count: 4
tags: ["Sylvan", "Warrior", "PhysicalAffinity", "Reach"]
ability_definition_refs:
Ability: Formation Strike
Trigger: ON_ATTACK
Conditions: [{ condition: IS_NO_ALLY_IN_FRONT_OF_SELF }]
Targeting: THREE_FRONTMOST_ENEMY_UNITS
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.75", type: "Physical" } }]
Description: "If no ally is in front, attacks the 3 frontmost enemies."
Ability: Piercing Lunge
Trigger: ON_ATTACK
Conditions: [{ condition: IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: BACKMOST_ENEMY
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 1.20", type: "Physical" } }]
Description: "If an ally is in front, attacks the backmost enemy."
merge_recipe: unit_t2_tank_02 + unit_t2_ranger_02
8. Radiant Justicar
id: unit_t3_paladin_03
display_name_key: "Radiant Justicar"
description_key: "This Celestial paladin's strikes are empowered by its own vitality, dealing more damage the healthier it is."
icon_texture: res://art/units/ART_T3_RADIANT_JUSTICAR_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 270
base_pwr: 20
item_slot_count: 4
tags: ["Celestial", "Warrior", "HolyAffinity", "TankHybrid"]
ability_definition_refs:
Ability: Judgment Strike
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_CURRENT_HP * 0.2", type: "Holy" } }]
Description: "Attacks deal bonus Holy damage equal to 20% of this unit's current HP."
merge_recipe: unit_t2_tank_02 + unit_t2_cleric_02
9. War鼓 Thumper
id: unit_t3_wardrummer_03
display_name_key: "War鼓 Thumper"
description_key: "Every blow this Mystic warrior endures echoes as a beat of war, strengthening the resolve of all its allies."
icon_texture: res://art/units/ART_T3_WARDRUMMER_THUMPER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 240
base_pwr: 28
item_slot_count: 4
tags: ["Mystic", "Warrior", "BuffFocus", "Aura"]
ability_definition_refs:
Ability: Beat of War
Trigger: ON_HURT
Targeting: ALL_ALLIES
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: 1, duration: 2 } }]
Description: "When this unit takes damage, grants 1 stack of Strength to all allies for 2 turns."
merge_recipe: unit_t2_tank_02 + unit_t2_buffer_02
10. Magma Weaver
id: unit_t3_conjurer_03
display_name_key: "Magma Weaver"
description_key: "An Infernal conjurer whose very form is semi-molten. Striking it causes an immolating retort of searing flame."
icon_texture: res://art/units/ART_T3_MAGMA_WEAVER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 210
base_pwr: 38
item_slot_count: 4
tags: ["Infernal", "Mage", "FireAffinity", "CounterAttack"]
ability_definition_refs:
Ability: Immolating Retort
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR", duration: 3 } }]
Description: "When this unit takes damage, applies Burn stacks to the attacker for 3 turns."
merge_recipe: unit_t2_tank_02 + unit_t2_spellcaster_02
Fusions with T2_SUPPORT_02 (Guardian Healer)
1. Skald of Ages
id: unit_t3_bard_03
display_name_key: "Skald of Ages"
description_key: "This ancient Celestial bard sings a ballad of growth, permanently bolstering the vitality and power of its allies for the battle."
icon_texture: res://art/units/ART_T3_SKALD_OF_AGES_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 180
base_pwr: 30
item_slot_count: 4
tags: ["Celestial", "Priest", "BuffFocus", "Aura", "SupportFocus"]
ability_definition_refs:
Ability: Ballad of Growth
Trigger: ON_TURN_START
Targeting: ALL_ALLIES
Effects: [ { keyword: MODIFY_STAT_TEMPORARY, params: { stat: "HP", amount: 1, duration: "Battle" } }, { keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: 1, duration: "Battle" } } ]
Description: "At the start of its turn, permanently grants all allies +1 to HP and PWR for this battle."
merge_recipe: unit_t2_support_02 + unit_t2_support_02
2. Vigilant Sharpshooter
id: unit_t3_bowman_03
display_name_key: "Vigilant Sharpshooter"
description_key: "A Nomad ranger on constant overwatch, firing a shot at a random enemy every single time an ally acts."
icon_texture: res://art/units/ART_T3_VIGILANT_SHARPSHOOTER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 38
item_slot_count: 4
tags: ["Nomad", "Ranger", "PhysicalAffinity", "Assist"]
ability_definition_refs:
Ability: Overwatch Fire
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.5", type: "Physical" } }]
Description: "Every time an ally attacks, this unit attacks a random enemy."
merge_recipe: unit_t2_support_02 + unit_t2_attacker_02
3. Prismatic Conduit
id: unit_t3_elementalist_03
display_name_key: "Prismatic Conduit"
description_key: "A Mystic elementalist that channels raw magic, simultaneously shielding an ally and weakening a foe each turn."
icon_texture: res://art/units/ART_T3_PRISMATIC_CONDUIT_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 170
base_pwr: 40
item_slot_count: 4
tags: ["Mystic", "Mage", "MultiAffinity", "SupportFocus", "DebuffFocus"]
ability_definition_refs:
Ability: Elemental Attunement
Trigger: ON_TURN_START
Targeting: RANDOM_ALLY
Effects: [ { keyword: APPLY_STATUS_EFFECT, params: { target: RANDOM_ALLY, status: "Spellshield", duration: 1 } }, { keyword: APPLY_STATUS_EFFECT, params: { target: RANDOM_ENEMY, status: "Weaken", stacks: "SELF_PWR / 4", duration: 1 } } ]
Description: "At the start of its turn, grants a random ally Spellshield and applies Weaken stacks to a random enemy."
merge_recipe: unit_t2_support_02 + unit_t2_mage_02
4. High Vicar
id: unit_t3_priest_03
display_name_key: "High Vicar"
description_key: "The embodiment of divine grace, this Celestial priest radiates a healing aura that mends all allies at the start of each turn."
icon_texture: res://art/units/ART_T3_HIGH_VICAR_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 35
item_slot_count: 4
tags: ["Celestial", "Priest", "HolyAffinity", "Healing", "Aura"]
ability_definition_refs:
Ability: Divine Grace
Trigger: ON_TURN_START
Targeting: ALL_ALLIES
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR * 0.75" } }]
Description: "At the start of its turn, heals all allies."
merge_recipe: unit_t2_support_02 + unit_t2_sentinel_02
5. Martyr's Legacy
id: unit_t3_kamikaze_03
display_name_key: "Martyr's Legacy"
description_key: "This Clockwork zealot is designed for a final, glorious purpose: to sacrifice itself and imbue all remaining allies with its immense power."
icon_texture: res://art/units/ART_T3_MARTYRS_LEGACY_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 150
base_pwr: 50
item_slot_count: 4
tags: ["Clockwork", "Warrior", "Sacrifice", "BuffFocus"]
ability_definition_refs:
Ability: Final Surge
Trigger: ON_DEATH
Targeting: ALL_ALLIES
Effects: [{ keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "SELF_PWR", duration: 2 } }]
Description: "On death, grants all other allies PWR equal to this unit's PWR for 2 turns."
merge_recipe: unit_t2_support_02 + unit_t2_bruiser_02
6. Siege Engineer
id: unit_t3_crossbowman_03
display_name_key: "Siege Engineer"
description_key: "A Sylvan engineer who fires heavy, barbed bolts at the start of each turn, damaging and weakening a random foe."
icon_texture: res://art/units/ART_T3_SIEGE_ENGINEER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 180
base_pwr: 42
item_slot_count: 4
tags: ["Sylvan", "Ranger", "PhysicalAffinity", "DebuffFocus"]
ability_definition_refs:
Ability: Barbed Bolt
Trigger: ON_TURN_START
Targeting: RANDOM_ENEMY
Effects: [ { keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.6", type: "Physical" } }, { keyword: APPLY_STATUS_EFFECT, params: { status: "Weaken", stacks: "SELF_PWR / 3", duration: 2 } } ]
Description: "At the start of its turn, attacks a random enemy and inflicts Weaken stacks for 2 turns."
merge_recipe: unit_t2_support_02 + unit_t2_ranger_02
7. Oracle of Empowerment
id: unit_t3_oracle_03
display_name_key: "Oracle of Empowerment"
description_key: "This Celestial oracle blesses any healing with an additional surge of strength, turning recovery into an opportunity for power."
icon_texture: res://art/units/ART_T3_ORACLE_OF_EMPOWERMENT_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 32
item_slot_count: 4
tags: ["Celestial", "Priest", "HolyAffinity", "BuffFocus", "Reactive"]
ability_definition_refs:
Ability: Blessed Vigor
Trigger: ON_HEAL_APPLIED_TO_ALLY
Targeting: TARGET_OF_TRIGGER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: 1, duration: 1 } }]
Description: "When an ally is healed by any source, also apply 1 stack of Strength to that ally for 1 turn."
merge_recipe: unit_t2_support_02 + unit_t2_cleric_02
8. Maestro of Moves
id: unit_t3_sidekick_03_a
display_name_key: "Maestro of Moves"
description_key: "A Mystic conductor of combat, this unit's attack is a signal for its adjacent allies to immediately perform their own actions."
icon_texture: res://art/units/ART_T3_MAESTRO_OF_MOVES_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 175
base_pwr: 36
item_slot_count: 4
tags: ["Mystic", "Priest", "ComboEnabler", "SupportFocus"]
ability_definition_refs:
Ability: Synchronized Strike
Trigger: ON_ATTACK
Targeting: ADJACENT_ALLIES
Effects: [{ keyword: ACTIVATE_PRIMARY_ABILITY, params: { target: ADJACENT_ALLIES } }]
Cooldown: 2
Description: "On attack, causes adjacent allies to immediately perform their primary action/attack. (This ability has a 2-turn cooldown)."
merge_recipe: unit_t2_support_02 + unit_t2_buffer_02
9. Baleful Enchanter
id: unit_t3_enchanter_03
display_name_key: "Baleful Enchanter"
description_key: "The mere presence of this Infernal enchanter is enough to sap the strength from all foes at the start of each turn."
icon_texture: res://art/units/ART_T3_BALEFUL_ENCHANTER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 160
base_pwr: 44
item_slot_count: 4
tags: ["Infernal", "Mage", "ShadowAffinity", "DebuffFocus", "Aura"]
ability_definition_refs:
Ability: Withering Presence
Trigger: ON_TURN_START
Targeting: ALL_ENEMIES
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Weaken", stacks: "SELF_PWR / 5", duration: 1 } }]
Description: "At the start of its turn, applies Weaken stacks to all enemies for 1 turn."
merge_recipe: unit_t2_support_02 + unit_t2_spellcaster_02
Fusions with T2_ATTACKER_02 (Challenger Duelist)
1. Shadow Stalker
id: unit_t3_assassin_03
display_name_key: "Shadow Stalker"
description_key: "A deadly assassin that instinctively targets the weakest prey and grows stronger with every kill."
icon_texture: res://art/units/ART_T3_SHADOW_STALKER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 45
item_slot_count: 4
tags: ["Nomad", "Rogue", "PhysicalAffinity", "Execute"]
ability_definition_refs:
Ability: Cull the Weak (Passive)
Description: "This unit's primary attack always targets the lowest HP enemy."
Ability: Power Overwhelm
Trigger: ON_KILL
Targeting: SELF
Effects: [{ keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "KILLED_UNIT_BASE_PWR * 0.5", duration: "Battle" } }]
Description: "When this unit kills an enemy, it gains 50% of the killed unit's base PWR for the rest of the battle."
merge_recipe: unit_t2_attacker_02 + unit_t2_attacker_02
2. Arcane Spellsword
id: unit_t3_battlemage_03
display_name_key: "Arcane Spellsword"
description_key: "A hybrid warrior who imbues their blade with raw magic, leaving burning embers with every physical strike."
icon_texture: res://art/units/ART_T3_ARCANE_SPELLSWORD_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 42
item_slot_count: 4
tags: ["Mystic", "Mage", "FireAffinity", "HybridDamage"]
ability_definition_refs:
Ability: Imbued Strikes
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.5", duration: 2 } }]
Description: "Every attack also applies Burn stacks to the target for 2 turns."
merge_recipe: unit_t2_attacker_02 + unit_t2_mage_02
3. Legion Commander
id: unit_t3_legion_03
display_name_key: "Legion Commander"
description_key: "A vigilant commander who retaliates with force not only when they are struck, but when their adjacent comrades are as well."
icon_texture: res://art/units/ART_T3_LEGION_COMMANDER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 230
base_pwr: 40
item_slot_count: 4
tags: ["Earthen", "Warrior", "PhysicalAffinity", "CounterAttack", "Guardian"]
ability_definition_refs:
Ability: United Retaliation
Trigger: ON_HURT
Conditions: [{ condition: OR, params: { conditions: [ {condition: SELF_IS_TARGET_OF_TRIGGER}, {condition: ADJACENT_ALLY_IS_TARGET_OF_TRIGGER} ] } }]
Targeting: ATTACKER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.7", type: "Physical" } }]
Description: "When this unit or an adjacent ally takes damage, this unit attacks the source of that damage."
merge_recipe: unit_t2_attacker_02 + unit_t2_sentinel_02
4. Vengeful Berserker
id: unit_t3_paybacker_03
display_name_key: "Vengeful Berserker"
description_key: "This warrior stores fury from every wound taken, unleashing it all in a flurry of extra attacks on its turn."
icon_texture: res://art/units/ART_T3_VENGEFUL_BERSERKER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 210
base_pwr: 44
item_slot_count: 4
tags: ["Nomad", "Warrior", "PhysicalAffinity", "MultiHit", "Reactive"]
ability_definition_refs:
Ability: Stored Fury
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR", repeat_count: "HURT_COUNTER_SINCE_LAST_TURN" } }]
Description: "On its turn, attacks its target an additional time for each instance of damage this unit has taken since its last turn."
merge_recipe: unit_t2_attacker_02 + unit_t2_bruiser_02
5. Longshot Marksman
id: unit_t3_sniper_03
display_name_key: "Longshot Marksman"
description_key: "With unmatched reflexes, this Sylvan sniper fires an intercepting shot at any enemy the moment they declare an attack."
icon_texture: res://art/units/ART_T3_LONGSHOT_MARKSMAN_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 180
base_pwr: 48
item_slot_count: 4
tags: ["Sylvan", "Ranger", "PhysicalAffinity", "CounterAttack", "Reach"]
ability_definition_refs:
Ability: Intercepting Shot
Trigger: ON_ENEMY_ATTACK_DECLARED
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.8", type: "Physical" } }]
Description: "When an enemy unit declares an attack, this unit attacks that enemy."
merge_recipe: unit_t2_attacker_02 + unit_t2_ranger_02
6. Zealous Crusader
id: unit_t3_crusader_03
display_name_key: "Zealous Crusader"
description_key: "This Celestial warrior harvests the souls of its vanquished foes, healing itself and growing permanently stronger for the battle."
icon_texture: res://art/units/ART_T3_ZEALOUS_CRUSADER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 220
base_pwr: 36
item_slot_count: 4
tags: ["Celestial", "Warrior", "HolyAffinity", "Execute", "Growth"]
ability_definition_refs:
Ability: Soul Harvest
Trigger: ON_KILL
Targeting: SELF
Effects: [ { keyword: INCREASE_HP, params: { amount: "KILLED_UNIT_BASE_HP * 0.25" } }, { keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "KILLED_UNIT_BASE_PWR * 0.25", duration: "Battle" } } ]
Description: "When this unit kills an enemy, it heals for 25% of the killed unit's base HP and gains 25% of its base PWR for this battle."
merge_recipe: unit_t2_attacker_02 + unit_t2_cleric_02
7. Field Commander
id: unit_t3_commander_03
display_name_key: "Field Commander"
description_key: "A brilliant Nomad strategist whose every attack is a signal, granting strength to the entire team."
icon_texture: res://art/units/ART_T3_FIELD_COMMANDER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 40
item_slot_count: 4
tags: ["Nomad", "Warrior", "PhysicalAffinity", "BuffFocus", "Commander"]
ability_definition_refs:
Ability: Offensive Strategy
Trigger: ON_ATTACK
Targeting: ALL_ALLIES
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: 1, duration: 2 } }]
Description: "On attack, grants 1 stack of Strength to all allies for 2 turns."
merge_recipe: unit_t2_attacker_02 + unit_t2_buffer_02
8. Inferno Warmage
id: unit_t3_warmage_03
display_name_key: "Inferno Warmage"
description_key: "This Infernal warmage leads the charge, their physical assault followed by a wave of fire that burns all enemies."
icon_texture: res://art/units/ART_T3_INFERNO_WARMAGE_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 46
item_slot_count: 4
tags: ["Infernal", "Mage", "FireAffinity", "AoE", "HybridDamage"]
ability_definition_refs:
Ability: Blazing Assault
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { target: ALL_ENEMIES, status: "Burn", stacks: "SELF_PWR * 0.3", duration: 2 } }]
Description: "On attack, deals physical damage to the target and applies Burn stacks to all enemies for 2 turns."
merge_recipe: unit_t2_attacker_02 + unit_t2_spellcaster_02
Fusions with T2_MAGE_02 (Pyre Sorcerer)
1. Grand Arcanist
id: unit_t3_arcmage_03
display_name_key: "Grand Arcanist"
description_key: "The loss of an ally triggers this Mystic arcanist to unleash a calamity of raw power, burning all who stand against them."
icon_texture: res://art/units/ART_T3_GRAND_ARCANIST_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 160
base_pwr: 50
item_slot_count: 4
tags: ["Mystic", "Mage", "ArcaneAffinity", "AoE", "ControlFocus"]
ability_definition_refs:
Ability: Unleashed Calamity
Trigger: ON_ALLY_DIES
Targeting: ALL_ENEMIES
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.75", duration: 3 } }]
Description: "When an allied unit dies, apply Burn stacks to all enemies for 3 turns."
merge_recipe: unit_t2_mage_02 + unit_t2_mage_02
2. Soulfire Healer
id: unit_t3_healer_03
display_name_key: "Soulfire Healer"
description_key: "This Celestial priest channels the life essence of fallen allies into a powerful healing spell, like a phoenix rising from the ashes."
icon_texture: res://art/units/ART_T3_SOULFIRE_HEALER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 40
item_slot_count: 4
tags: ["Celestial", "Priest", "HolyAffinity", "Healing", "Reactive"]
ability_definition_refs:
Ability: Phoenix Down
Trigger: ON_ALLY_DIES
Targeting: FRONTMOST_ALLY
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR * 1.5" } }]
Description: "When an allied unit dies, heal the frontmost living ally."
merge_recipe: unit_t2_mage_02 + unit_t2_sentinel_02
3. Living Inferno
id: unit_t3_fireelemental_03
display_name_key: "Living Inferno"
description_key: "An elemental of pure fire, its immolation aura burns any who dare strike it or its adjacent allies."
icon_texture: res://art/units/ART_T3_LIVING_INFERNO_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 44
item_slot_count: 4
tags: ["Infernal", "Mage", "Golem", "FireAffinity", "Aura", "CounterAttack"]
ability_definition_refs:
Ability: Immolation Aura
Trigger: ON_HURT
Conditions: [{ condition: OR, params: { conditions: [ {condition: SELF_IS_TARGET_OF_TRIGGER}, {condition: ADJACENT_ALLY_IS_TARGET_OF_TRIGGER} ] } }]
Targeting: ATTACKER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.6", duration: 2 } }]
Description: "When this unit or an adjacent ally takes damage, apply Burn stacks to the attacker for 2 turns."
merge_recipe: unit_t2_mage_02 + unit_t2_bruiser_02
4. Focus Caster
id: unit_t3_caster_03
display_name_key: "Focus Caster"
description_key: "This Sylvan mage assists its allies' attacks, kindling flames on the enemy least affected by fire."
icon_texture: res://art/units/ART_T3_FOCUS_CASTER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 170
base_pwr: 48
item_slot_count: 4
tags: ["Sylvan", "Mage", "FireAffinity", "DoT_Focus", "Assist"]
ability_definition_refs:
Ability: Kindle
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: ENEMY_WITH_LOWEST_STATUS_STACKS(Burn)
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.7", duration: 3 } }]
Description: "When an adjacent ally attacks, apply Burn stacks to the enemy with the fewest Burning stacks for 3 turns."
merge_recipe: unit_t2_mage_02 + unit_t2_ranger_02
5. Bloodfire Sorcerer
id: unit_t3_sorcerer_03
display_name_key: "Bloodfire Sorcerer"
description_key: "A sorcerer who wields consuming flames. If their target is already burning, they siphon the heat to heal the most wounded ally."
icon_texture: res://art/units/ART_T3_BLOODFIRE_SORCERER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 180
base_pwr: 46
item_slot_count: 4
tags: ["Celestial", "Mage", "FireAffinity", "Healing", "HybridDamage"]
ability_definition_refs:
Ability: Consuming Flames
Trigger: ON_ATTACK
Targeting: DEFENDER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR", duration: 3 } }]
Description: "Primary attack applies Burn stacks to the target."
Ability: Siphoning Heat
Trigger: ON_ATTACK
Conditions: [{ condition: TARGET_HAS_STATUS_EFFECT_X, params: { target: DEFENDER, status: "Burn" } }]
Targeting: ALLY_WITH_LOWEST_HP_PERCENT
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR * 0.75" } }]
Description: "If the attacked target is Burning, also heal the ally with the lowest HP percentage."
merge_recipe: unit_t2_mage_02 + unit_t2_cleric_02
6. Primal Beastmaster
id: unit_t3_beastmaster_03
display_name_key: "Primal Beastmaster"
description_key: "This Sylvan master of beasts lets out a primal call whenever a new ally enters the fray, bolstering their strength and vitality."
icon_texture: res://art/units/ART_T3_PRIMAL_BEASTMASTER_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 190
base_pwr: 42
item_slot_count: 4
tags: ["Sylvan", "Ranger", "Summoner", "BuffFocus", "Beast"]
ability_definition_refs:
Ability: Call of the Wild
Trigger: ON_ALLY_DEPLOYED
Targeting: SOURCE_OF_TRIGGER
Effects: [ { keyword: INCREASE_HP, params: { amount: "SELF_PWR * 0.5" } }, { keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "SELF_PWR * 0.25", duration: 2 } } ]
Description: "When a new allied unit is placed or summoned, grant it HP and PWR for 2 turns."
merge_recipe: unit_t2_mage_02 + unit_t2_buffer_02
7. Cataclysmic Firemage
id: unit_t3_firemage_03
display_name_key: "Cataclysmic Firemage"
description_key: "The death of an ally starts a chain reaction, causing this Infernal mage to set a foe ablaze. If they were already burning, the fire spreads."
icon_texture: res://art/units/ART_T3_CATACLYSMIC_FIREMAGE_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 170
base_pwr: 52
item_slot_count: 4
tags: ["Infernal", "Mage", "FireAffinity", "AoE", "Reactive"]
ability_definition_refs:
Ability: Chain Reaction
Trigger: ON_ALLY_DIES
Targeting: RANDOM_ENEMY
Effects: [ { keyword: APPLY_STATUS_EFFECT, params: { target: RANDOM_ENEMY, status: "Burn", stacks: "SELF_PWR", duration: 3 } }, { keyword: APPLY_STATUS_EFFECT, params: { target: ADJACENT_ENEMIES, status: "Burn", stacks: "SELF_PWR * 0.5", duration: 3, condition: { condition: TARGET_HAS_STATUS_EFFECT_X, params: { target: RANDOM_ENEMY, status: "Burn" } } } } ]
Description: "When an ally dies, apply Burn stacks to a random enemy. If that enemy was already Burning, also apply stacks to adjacent enemies."
merge_recipe: unit_t2_mage_02 + unit_t2_spellcaster_02
Fusions with T2_BRUISER_02 (Ironclad Retaliator)
1. Grim Executioner
id: unit_t3_executioner_03
display_name_key: "Grim Executioner"
description_key: "A Clockwork executioner whose counter-attacks become brutally efficient when it is damaged."
icon_texture: res://art/units/ART_T3_GRIM_EXECUTIONER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 240
base_pwr: 42
item_slot_count: 4
tags: ["Clockwork", "Warrior", "PhysicalAffinity", "CounterAttack", "Execute"]
ability_definition_refs:
Ability: Enhanced Counter
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.75", type: "Physical" } }]
Description: "When this unit takes damage, it attacks the attacker."
Ability: Desperate Measures (Passive)
Description: "If this unit's HP is below 50%, its counter-attacks from 'Enhanced Counter' deal double damage."
merge_recipe: unit_t2_bruiser_02 + unit_t2_bruiser_02
2. Pack Leader Headhunter
id: unit_t3_headhunter_03
display_name_key: "Pack Leader Headhunter"
description_key: "This Sylvan warrior fights with the pack, retaliating against its own attackers and joining in on its neighbors' assaults."
icon_texture: res://art/units/ART_T3_PACK_LEADER_HEADHUNTER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 220
base_pwr: 40
item_slot_count: 4
tags: ["Sylvan", "Warrior", "PhysicalAffinity", "CounterAttack", "Assist", "Beast"]
ability_definition_refs:
Ability: Riposte
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.6", type: "Physical" } }]
Description: "When this unit takes damage, it attacks the attacker."
Ability: Pack Assault
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: TARGET_OF_ALLY_ATTACK
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.5", type: "Physical" } }]
Description: "If an adjacent ally attacks, this unit also attacks the same target."
merge_recipe: unit_t2_bruiser_02 + unit_t2_ranger_02
3. Bloodsworn Zealot
id: unit_t3_zealot_03
display_name_key: "Bloodsworn Zealot"
description_key: "A dark Celestial warrior whose fervent counter-attacks are imbued with holy power, healing them with every strike."
icon_texture: res://art/units/ART_T3_BLOODSWORN_ZEALOT_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 230
base_pwr: 38
item_slot_count: 4
tags: ["Celestial", "Warrior", "HolyAffinity", "CounterAttack", "Lifesteal"]
ability_definition_refs:
Ability: Fervent Retaliation
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [ { keyword: DEAL_DAMAGE, params: { target: ATTACKER, amount: "SELF_PWR * 0.7", type: "Holy" } }, { keyword: INCREASE_HP, params: { target: SELF, amount: "DAMAGE_DEALT_BY_THIS_ABILITY * 0.25" } } ]
Description: "When this unit takes damage, it attacks the attacker with Holy damage and heals for 25% of the damage dealt."
merge_recipe: unit_t2_bruiser_02 + unit_t2_cleric_02
4. Unyielding Champion
id: unit_t3_champion_03
display_name_key: "Unyielding Champion"
description_key: "A Mystic champion whose defiant stance allows it to grow stronger with every blow it endures."
icon_texture: res://art/units/ART_T3_UNYIELDING_CHAMPION_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 250
base_pwr: 36
item_slot_count: 4
tags: ["Mystic", "Warrior", "PhysicalAffinity", "CounterAttack", "Growth", "Fortified"]
ability_definition_refs:
Ability: Defiant Stance
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [ { keyword: DEAL_DAMAGE, params: { target: ATTACKER, amount: "SELF_PWR * 0.6", type: "Physical" } }, { keyword: APPLY_STATUS_EFFECT, params: { target: SELF, status: "Strength", stacks: 1, duration: "Battle" } } ]
Description: "When this unit takes damage, it attacks the attacker and gains 1 stack of Strength for the rest of the battle (max 5 stacks)."
merge_recipe: unit_t2_bruiser_02 + unit_t2_buffer_02
5. Blighted Death Knight
id: unit_t3_deathknight_03
display_name_key: "Blighted Death Knight"
description_key: "An undead knight whose necrotic rebuke damages and burns attackers. It consumes the souls of fallen allies to fuel its own power."
icon_texture: res://art/units/ART_T3_BLIGHTED_DEATHKNIGHT_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 210
base_pwr: 44
item_slot_count: 4
tags: ["Infernal", "Warrior", "ShadowAffinity", "CounterAttack", "Undead", "Growth"]
ability_definition_refs:
Ability: Necrotic Rebuke
Trigger: ON_HURT
Targeting: ATTACKER
Effects: [ { keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.65", type: "Shadow" } }, { keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.25", duration: 2 } } ]
Description: "When this unit takes damage, it attacks the attacker for Shadow damage and applies Burn stacks."
Ability: Soul Eater
Trigger: ON_ALLY_DIES
Targeting: SELF
Effects: [{ keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "SELF_BASE_HP * 0.1", duration: "Battle" } }]
Description: "If an ally dies, this unit gains PWR equal to 10% of its base HP for the rest of the battle."
merge_recipe: unit_t2_bruiser_02 + unit_t2_spellcaster_02
Fusions with T2_RANGER_02 (Agile Hunter)
1. Deadeye Sharpshooter
id: unit_t3_sharpshooter_03
display_name_key: "Deadeye Sharpshooter"
description_key: "A Sylvan marksman with a keen eye. Its coordinated shots have a chance to critically strike for devastating damage."
icon_texture: res://art/units/ART_T3_DEADEYE_SHARPSHOOTER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 180
base_pwr: 48
item_slot_count: 4
tags: ["Sylvan", "Ranger", "PhysicalAffinity", "Assist", "CritFocus"]
ability_definition_refs:
Ability: Precision Volley
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.6", type: "Physical", crit_chance: 0.25, crit_multiplier: 1.5 } }]
Description: "When an adjacent ally attacks, this unit attacks a random enemy. This attack has a 25% chance to be a critical hit, dealing 50% bonus damage."
merge_recipe: unit_t2_ranger_02 + unit_t2_ranger_02
2. Combat Field Medic
id: unit_t3_fieldmedic_03
display_name_key: "Combat Field Medic"
description_key: "A versatile Celestial ranger who provides covering fire for allies and performs battlefield triage on wounded neighbors."
icon_texture: res://art/units/ART_T3_COMBAT_FIELDMEDIC_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 40
item_slot_count: 4
tags: ["Celestial", "Ranger", "PhysicalAffinity", "Assist", "Healing"]
ability_definition_refs:
Ability: Covering Fire
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.5", type: "Physical" } }]
Description: "When an adjacent ally attacks, this unit attacks a random enemy."
Ability: Triage
Trigger: ON_HURT
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR" } }]
Description: "If an adjacent ally takes damage, heal them."
merge_recipe: unit_t2_ranger_02 + unit_t2_cleric_02
3. Swiftwing Skirmisher
id: unit_t3_skirmisher_03
display_name_key: "Swiftwing Skirmisher"
description_key: "This flying Mystic skirmisher harasses the enemy alongside its allies, granting a tailwind of haste to its attacking neighbor."
icon_texture: res://art/units/ART_T3_SWIFTWING_SKIRMISHER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 44
item_slot_count: 4
tags: ["Mystic", "Ranger", "PhysicalAffinity", "Assist", "BuffFocus", "Flying"]
ability_definition_refs:
Ability: Harassing Shot
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [ { keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.55", type: "Physical" } }, { keyword: APPLY_STATUS_EFFECT, params: { target: SOURCE_OF_TRIGGER, status: "Haste", stacks: 1, duration: 1 } } ]
Description: "When an adjacent ally attacks, this unit attacks a random enemy and grants the attacking ally Haste for 1 turn."
merge_recipe: unit_t2_ranger_02 + unit_t2_buffer_02
4. Mystweave Arcane Archer
id: unit_t3_arcane_archer_03
display_name_key: "Mystweave Arcane Archer"
description_key: "An Infernal archer whose corrupting arrows exploit enemy weaknesses, applying Burn to the weakened and Weaken to the burning."
icon_texture: res://art/units/ART_T3_MYSTWEAVE_ARCANE_ARCHER_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 170
base_pwr: 50
item_slot_count: 4
tags: ["Infernal", "Ranger", "PhysicalAffinity", "Assist", "DebuffFocus"]
ability_definition_refs:
Ability: Pinpoint Strike & Corrupting Arrow
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY }]
Targeting: RANDOM_ENEMY
Effects: [ { keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.5", type: "Physical" } }, { keyword: APPLY_STATUS_EFFECT, params: { status: "Weaken", stacks: "SELF_PWR / 5", duration: 1, condition: { condition: TARGET_HAS_STATUS_EFFECT_X, params: { target: TARGET_OF_ABILITY, status: "Burn" } } } }, { keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.3", duration: 1, condition: { condition: TARGET_HAS_STATUS_EFFECT_X, params: { target: TARGET_OF_ABILITY, status: "Weaken" } } } } ]
Description: "When an adjacent ally attacks, this unit attacks a random enemy. The attack also applies Weaken if the target is Burning, or Burning if the target is Weakened."
merge_recipe: unit_t2_ranger_02 + unit_t2_spellcaster_02
Fusions with T2_CLERIC_02 (Battle Medic)
1. Hierophant High Cleric
id: unit_t3_highcleric_03
display_name_key: "Hierophant High Cleric"
description_key: "A master of restorative arts. It not only shields itself and its ward, but also performs divine intervention to heal the most wounded ally each turn."
icon_texture: res://art/units/ART_T3_HIEROPHANT_HIGHCLERIC_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 220
base_pwr: 38
item_slot_count: 4
tags: ["Celestial", "Priest", "HolyAffinity", "Healing", "Aura", "Fortified"]
ability_definition_refs:
Ability: Protective Ward
Trigger: ON_HURT
Targeting: SELF
Effects: [ { keyword: INCREASE_HP, params: { target: SELF, amount: "SELF_PWR * 0.5" } }, { keyword: INCREASE_HP, params: { target: ALLY_BEHIND_SELF, amount: "SELF_PWR * 0.5" } } ]
Description: "When this unit takes damage, it heals itself and the ally directly behind it."
Ability: Divine Intervention
Trigger: ON_TURN_START
Targeting: ALLY_WITH_LOWEST_HP_PERCENT
Effects: [{ keyword: INCREASE_HP, params: { amount: "SELF_PWR" } }]
Description: "At the start of its turn, heal the ally with the lowest HP percentage."
merge_recipe: unit_t2_cleric_02 + unit_t2_cleric_02
2. Shielding Bishop
id: unit_t3_bishop_03
display_name_key: "Shielding Bishop"
description_key: "This Mystic bishop not only mends wounds but also bestows a protective aegis upon the ally fighting before it."
icon_texture: res://art/units/ART_T3_SHIELDING_BISHOP_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 200
base_pwr: 40
item_slot_count: 4
tags: ["Mystic", "Priest", "HolyAffinity", "Healing", "BuffFocus", "Protector"]
ability_definition_refs:
Ability: Reactive Mending
Trigger: ON_HURT
Targeting: SELF
Effects: [ { keyword: INCREASE_HP, params: { target: SELF, amount: "SELF_PWR * 0.5" } }, { keyword: INCREASE_HP, params: { target: ALLY_BEHIND_SELF, amount: "SELF_PWR * 0.5" } } ]
Description: "When this unit takes damage, it heals itself and the ally directly behind it."
Ability: Aegis Bestowal
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Barrier", amount: "SELF_PWR", duration: 1 } }]
Description: "When an ally directly in front attacks, grant that ally a Barrier that absorbs damage."
merge_recipe: unit_t2_cleric_02 + unit_t2_buffer_02
3. Purifying Inquisitor
id: unit_t3_inquisitor_03
display_name_key: "Purifying Inquisitor"
description_key: "An inquisitor who wields holy fire to cauterize wounds and pass judgment, striking any enemy afflicted with Burning by an ally."
icon_texture: res://art/units/ART_T3_PURIFYING_INQUISITOR_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 190
base_pwr: 44
item_slot_count: 4
tags: ["Infernal", "Priest", "HolyAffinity", "Healing", "ReactiveDamage"]
ability_definition_refs:
Ability: Cauterize Wounds
Trigger: ON_HURT
Targeting: SELF
Effects: [ { keyword: INCREASE_HP, params: { target: SELF, amount: "SELF_PWR * 0.5" } }, { keyword: INCREASE_HP, params: { target: ALLY_BEHIND_SELF, amount: "SELF_PWR * 0.5" } } ]
Description: "When this unit takes damage, it heals itself and the ally directly behind it."
Ability: Judgment by Fire
Trigger: ON_STATUS_EFFECT_APPLIED_TO_ENEMY
Conditions: [{ condition: STATUS_EFFECT_APPLIED_IS, params: { status: "Burn" } }]
Targeting: TARGET_OF_STATUS_EFFECT
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.75", type: "Holy" } }]
Description: "When an enemy is afflicted with Burning by an ally, this unit deals bonus Holy damage to that enemy."
merge_recipe: unit_t2_cleric_02 + unit_t2_spellcaster_02
Fusions with T2_BUFFER_02 (Morale Booster)
1. Master Tactician
id: unit_t3_tactician_03
display_name_key: "Master Tactician"
description_key: "A peerless Mystic tactician who inspires the front line and grants swiftness to the entire team."
icon_texture: res://art/units/ART_T3_MASTER_TACTICIAN_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 180
base_pwr: 42
item_slot_count: 4
tags: ["Mystic", "Priest", "BuffFocus", "Aura", "Commander"]
ability_definition_refs:
Ability: Frontline Inspiration
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: "SELF_PWR / 3", duration: 2 } }]
Description: "When an ally directly in front attacks, apply Strength stacks to that ally."
Ability: Swift Maneuvers
Trigger: ON_TURN_START
Targeting: ALL_ALLIES
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Haste", stacks: 1, duration: 1 } }]
Description: "At the start of its turn, grant all allies Haste for this turn."
merge_recipe: unit_t2_buffer_02 + unit_t2_buffer_02
2. Soulbound Ritualist
id: unit_t3_ritualist_03
display_name_key: "Soulbound Ritualist"
description_key: "This Infernal ritualist empowers its allies, and upon an ally's death, transfers their essence to empower the strongest remaining warrior."
icon_texture: res://art/units/ART_T3_SOULBOUND_RITUALIST_03.png
tier: 3
rarity: RARE
ball_category: UNIT
base_hp: 170
base_pwr: 46
item_slot_count: 4
tags: ["Infernal", "Priest", "BuffFocus", "Sacrifice", "Reactive"]
ability_definition_refs:
Ability: Empowering Chant
Trigger: ON_ATTACK
Conditions: [{ condition: SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF }]
Targeting: SOURCE_OF_TRIGGER
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Strength", stacks: "SELF_PWR / 3", duration: 2 } }]
Description: "When an ally directly in front attacks, apply Strength stacks to that ally."
Ability: Essence Transfer
Trigger: ON_ALLY_DIES
Targeting: ALLY_WITH_HIGHEST_CURRENT_PWR
Effects: [{ keyword: MODIFY_STAT_TEMPORARY, params: { stat: "PWR", amount: "SELF_PWR", duration: 2 } }]
Description: "When an ally dies, the ally with the highest current PWR gains bonus PWR for 2 turns."
merge_recipe: unit_t2_buffer_02 + unit_t2_spellcaster_02
Fusion with T2_SPELLCASTER_02 (Vengeful Pyromancer)
1. Undying Lich Lord
id: unit_t3_lich_03
display_name_key: "Undying Lich Lord"
description_key: "This undead lord harvests the soul of any unit that falls—friend or foe—to fuel its necrotic flames. If a burning enemy dies, the flames wither all other foes."
icon_texture: res://art/units/ART_T3_UNDYING_LICH_LORD_03.png
tier: 3
rarity: LEGENDARY
ball_category: UNIT
base_hp: 180
base_pwr: 55
item_slot_count: 4
tags: ["Infernal", "Mage", "ShadowAffinity", "Undead", "AoE", "DoT_Focus"]
ability_definition_refs:
Ability: Harvest Souls
Trigger: ON_ANY_UNIT_DIES
Targeting: RANDOM_ENEMY
Effects: [{ keyword: APPLY_STATUS_EFFECT, params: { status: "Burn", stacks: "SELF_PWR * 0.8", duration: 3 } }]
Description: "Whenever any unit dies, apply Burn stacks to a random enemy."
Ability: Withering Flames
Trigger: ON_ENEMY_DIES
Conditions: [{ condition: TARGET_HAS_STATUS_EFFECT_X, params: { target: SOURCE_OF_TRIGGER, status: "Burn" } }]
Targeting: ALL_ENEMIES
Effects: [{ keyword: DEAL_DAMAGE, params: { amount: "SELF_PWR * 0.5", type: "Shadow" } }]
Description: "If an enemy dies while Burning, all other enemies take Shadow damage."
merge_recipe: unit_t2_spellcaster_02 + unit_t2_spellcaster_02