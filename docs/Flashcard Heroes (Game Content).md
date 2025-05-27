Game Content Document - Unit Catalog (Draft v0.1)

Introduction:
This document details the units available in Flashcard Heroes: Gachamon. It focuses on their stats, traits, and abilities, designed to facilitate balance changes and future expansions. Values marked X, Y, Z, [TBD_Value] are placeholders for balancing. Base Stats (HP, PWR, SPD) and ArtAssetIDs are also placeholders.

Standard Unit Data Structure:

UnitID: Unique internal identifier.

Name: Display name.

Tier: 1, 2, or 3.

Game Content Document - Unit Catalog (Draft v0.1)

Introduction:
This document details the units available in Flashcard Heroes: Gachamon. It focuses on their stats, traits, and abilities, designed to facilitate balance changes and future expansions. Values marked X, Y, Z, [TBD_Value] are placeholders for balancing. Base Stats (HP, PWR, SPD) and ArtAssetIDs are also placeholders.

Standard Unit Data Structure:

UnitID: Unique internal identifier.

Name: Display name.

Tier: 1, 2, or 3.

ArtAssetID: (e.g., ART_ROOKIE_SPEARMAN)

BaseStats: HP, PWR

ItemSlots: 1 for T1, 2 for T2, 4 for T3

OriginTrait: (e.g., Earthen, Infernal, Celestial, Clockwork, Abyssal, Sylvan, Mystic, Nomad)

ClassTrait: (e.g., Warrior, Rogue, Mage, Priest, Ranger)

KeywordTraits: (Optional, e.g., AoE, DoT_Focus, CounterAttack, Summoner, DebuffFocus, BuffFocus, Guardian, Commander)

Abilities: List of abilities, each with:

AbilityName: Descriptive.

Type: (Passive, Action, Triggered)

Trigger: (e.g., ON_HURT, ON_ACTION_EXECUTED)

Condition(s): (Optional)

Targeting: (e.g., SELF, HIGHEST_HP_ENEMY)

Effect(s): (e.g., HEAL_HP, APPLY_STATUS, MODIFY_STAT_TEMPORARY)

Description: Player-facing text.

MergeRecipe: (For T2+ units) [UnitID_A] + [UnitID_B]

Notes: (Optional) Design intent, complex interactions.

Tier 1 Units

UnitID: T1_TANK_01

Name: Stonepelt Guard

Tier: 1

ArtAssetID: ART_T1_TANK_01

BaseStats: { HP: 60, PWR: 8, SPD: 5 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Reactive Plating

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 5 + 50% of PWR] } (Permanent for heroes, temporary for units)

Description: When this unit takes damage, it heals for X HP (scales with PWR).

UnitID: T1_SUPPORT_01

Name: Hexer Acolyte

Tier: 1

ArtAssetID: ART_T1_SUPPORT_01

BaseStats: { HP: 40, PWR: 10, SPD: 7 }

ItemSlots: 1

OriginTrait: Mystic

ClassTrait: Priest

KeywordTraits: ShadowAffinity

Abilities:

AbilityName: Enfeeble

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Weaken', Stacks: [TBD_Value, e.g., 1 + PWR/5], Duration: 2 }

Description: On attack, applies X stacks of Weaken (reduces PWR) to the highest HP enemy for 2 turns.

UnitID: T1_ATTACKER_01

Name: Swift Striker

Tier: 1

ArtAssetID: ART_T1_ATTACKER_01

BaseStats: { HP: 45, PWR: 12, SPD: 8 }

ItemSlots: 1

OriginTrait: Nomad

ClassTrait: Rogue

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Exploit Opening

Type: Action

Trigger: ON_ATTACK_EXECUTED

Condition(s): HP_BELOW_PERCENT { Target: TARGET_OF_TRIGGER, Value: 100 }

Targeting: TARGET_OF_TRIGGER

Effect(s): PERFORM_EXTRA_ATTACK { Count: 1 }

Description: Attacks twice if the target is not at full HP.

UnitID: T1_MAGE_01

Name: Ember Caster

Tier: 1

ArtAssetID: ART_T1_MAGE_01

BaseStats: { HP: 35, PWR: 14, SPD: 6 }

ItemSlots: 1

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity

Abilities:

AbilityName: Scorch

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., PWR], Duration: 3 }

Description: On attack, applies X stacks of Burning (damage over time) to the highest HP enemy for 3 turns.

Tier 2 Units

UnitID: T2_TANK_02

Name: Bastion Protector

Tier: 2

ArtAssetID: ART_T2_TANK_02

BaseStats: { HP: 130, PWR: 15, SPD: 10 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: Golem

Abilities:

AbilityName: Crowd Defense

Type: Passive

ID:** (e.g., ART_ROOKIE_SPEARMAN)

BaseStats: { HP: X, PWR: Y }

ItemSlots: 4

OriginTrait: (Fire, Water, Earth, Air)

ClassTrait: (e.g., Warrior, Rogue, Mage, Priest, Ranger)

KeywordTraits: (Optional, e.g., Golem, Undead, FireAffinity, PhysicalAffinity, Flying, AoE, CounterAttack, Assist, Guardian, Healing, BuffFocus, Reactive, Fortified, Protector, ComboEnabler, Summoner)

Abilities: List of abilities, each with:

AbilityName: Descriptive.

Type: (Passive, Action, Triggered)

Trigger: (e.g., ON_DAMAGE_TAKEN, ON_ACTION_EXECUTED)

Condition(s): (Optional)

Targeting: (e.g., SELF, HIGHEST_HP_ENEMY)

Effect(s): (e.g., HEAL_HP, APPLY_STATUS, MODIFY_STAT_TEMPORARY)

Description: Player-facing text.

MergeRecipe: (For T2+ units) [UnitID_A] + [UnitID_B]

Notes: (Optional) Design intent, complex interactions.

Tier 1 Units

UnitID: T1_TANK_01

Name: Stonepelt Guard

Tier: 1

ArtAssetID: ART_T1_TANK_01

BaseStats: { HP: 60, PWR: 8, SPD: 5 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Reactive Plating

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR * 0.5] }

Description: When this unit takes damage, it heals for X HP (scales with PWR).

UnitID: T1_SUPPORT_01

Name: Hexer Acolyte

Tier: 1

ArtAssetID: ART_T1_SUPPORT_01

BaseStats: { HP: 40, PWR: 10, SPD: 7 }

ItemSlots: 1

OriginTrait: Mystic

ClassTrait: Priest

KeywordTraits: ShadowAffinity

Abilities:

AbilityName: Enfeeble

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Weaken', Stacks: [TBD_Value, e.g., SELF_PWR / 2], Duration: 2 }

Description: On attack, applies X stacks of Weaken (reduces PWR) to the highest HP enemy for 2 turns.

UnitID: T1_ATTACKER_01

Name: Swift Striker

Tier: 1

ArtAssetID: ART_T1_ATTACKER_01

BaseStats: { HP: 45, PWR: 12, SPD: 8 }

ItemSlots: 1

OriginTrait: Nomad

ClassTrait: Rogue

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Exploit Opening

Type: Action

Trigger: ON_ATTACK_EXECUTED

Condition(s): TARGET_HP_BELOW_PERCENT { Target: TARGET_OF_TRIGGER, Value: 100 }

Targeting: TARGET_OF_TRIGGER

Effect(s): PERFORM_EXTRA_ATTACK { Count: 1 }

Description: Attacks twice if the target is not at full HP.

UnitID: T1_MAGE_01

Name: Ember Caster

Tier: 1

**ArtTrigger: ON_TURN_START

Targeting: SELF

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 10] * ENEMY_COUNT_IN_LINEUP }

Description: At the start of its turn, gains X HP for each enemy unit in the lineup.

MergeRecipe: T1_TANK_01 + T1_TANK_01

UnitID: T2_SUPPORT_02

Name: Guardian Healer

Tier: 2

ArtAssetID: ART_T2_SUPPORT_02

BaseStats: { HP: 90, PWR: 20, SPD: 14 }

ItemSlots: 1

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity

Abilities:

AbilityName: Frontline Mend

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting: SOURCE_OF_TRIGGER (The ally that took damage)

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 100% of SELF_PWR] }

Description: When an ally directly in front of this unit takes damage, heal that ally for X HP (scales with this unit's PWR).

MergeRecipe: T1_SUPPORT_01 + T1_SUPPORT_01

UnitID: T2_ATTACKER_02

Name: Challenger Duelist

Tier: 2

ArtAssetID: ART_T2_ATTACKER_02

BaseStats: { HP: 100, PWR: 25, SPD: 16 }

ItemSlots: 1

OriginTrait: Nomad

ClassTrait: Rogue

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Power Siphon

Type: Triggered

Trigger: ON_ATTACK_DECLARED

Targeting: SELF

Effect(s): MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., 50% of FRONTMOST_ENEMY_PWR], Duration: 'ThisAttackOnly' }

Description: Before attacking, gain bonus PWR equal to X% of the frontmost enemy's PWR for this attack.

MergeRecipe: T1_ATTACKER_01 + T1_ATTACKER_01

UnitID: T2_MAGE_02

Name: Pyre Sorcerer

Tier: 2

ArtAssetID: ART_T2_MAGE_02

BaseStats: { HP: 80, PWR: 30 }

ItemSlotsAssetID: ART_T1_MAGE_01

BaseStats: { HP: 35, PWR: 14, SPD: 6 }

ItemSlots: 1

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity

Abilities:

AbilityName: Scorch

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

Description: On attack, applies X stacks of Burning (damage over time) to the highest HP enemy for 3 turns.

Tier 2 Units

UnitID: T2_TANK_02

Name: Bastion Protector

Tier: 2

ArtAssetID: ART_T2_TANK_02

BaseStats: { HP: 130, PWR: 15, SPD: 10 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: Golem

Abilities:

AbilityName: Crowd Defense

Type: Passive

Trigger: ON_TURN_START

Targeting: SELF

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 5] * ENEMY_COUNT_IN_LINEUP }

Description: At the start of its turn, gains X HP for each enemy unit in the lineup.

MergeRecipe: T1_TANK_01 + T1_TANK_01

UnitID: T2_SUPPORT_02

Name: Guardian Healer

Tier: 2

ArtAssetID: ART_T2_SUPPORT_02

BaseStats: { HP: 90, PWR: 20, SPD: 14 }

ItemSlots: 1

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity, Healing

Abilities:

AbilityName: Frontline Mend

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting: ALLY_IN_FRONT_OF_SELF (The one that took damage)

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR] }

Description: When an ally directly in front of this unit takes damage, heal that ally for X HP (scales with this unit's PWR).

MergeRecipe: T1_SUPPORT_01 + T1_SUPPORT_01

UnitID: T2_ATTACKER_02

Name: Challenger Duelist

Tier: 2

ArtAssetID: ART_T2_ATTACKER_02

BaseStats: { HP: 100, PWR: 25, SPD: 16 }

ItemSlots: 1

OriginTrait: Nomad

ClassTrait: Rogue

KeywordTraits: PhysicalAffinity

Abilities:

AbilityName: Power Siphon

Type: Triggered

Trigger: ON_ATTACK_DECLARED

Targeting: SELF

Effect(s): MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., FRONTMOST_ENEMY_PWR * 0.5], Duration: 1 }

Description: Before attacking, gain bonus PWR equal to X% of the frontmost enemy's PWR for this attack.

MergeRecipe: T1_ATTACKER_01 + T1_ATTACKER_01

UnitID: T2_MAGE_02

:** 1

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, AoE

Abilities:

AbilityName: Fireblast

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY (Primary), ADJACENT_ENEMIES_TO_PRIMARY (Secondary)

Effect(s):

APPLY_STATUS { Target: Primary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., PWR], Duration: 3 }

APPLY_STATUS { Target: Secondary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., PWR/2], Duration: 3 }

Description: On attack, applies X Burning stacks to the highest HP enemy and Y Burning stacks to enemies adjacent to it for 3 turns.

MergeRecipe: T1_MAGE_01 + T1_MAGE_01

UnitID: T2_SENTINEL_02

Name: Spirit Warden

Tier: 2

ArtAssetID: ART_T2_SENTINEL_02

BaseStats: { HP: 110, PWR: 18, SPD: 12 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Priest (Hybrid Warrior/Priest feel)

KeywordTraits: Guardian

Abilities:

AbilityName: Parting Gift

Type: Triggered

Trigger: ON_UNIT_DIES (When SELF dies)

Targeting: ALLY_BEHIND_SELF

Effect(s):

HEAL_HP { Amount: [TBD_Value, e.g., 150% of SELF_PWR] }

APPLY_STATUS { StatusName: 'Strength', Stacks: [TBD_Value, e.g., PWR/2], Duration: 2 }

Description: When this unit dies, grants X HP and Y stacks of Strength to the ally directly behind it for 2 turns.

MergeRecipe: T1_TANK_01 + T1_SUPPORT_01

UnitID: T2_BRUISER_02

Name: Ironclad Retaliator

Tier: 2

ArtAssetID: ART_T2_BRUISER_02

BaseStats: { HP: 120, PWR: 22, SPD: 13 }

ItemSlots: 1

OriginTrait: Clockwork

ClassTrait: Warrior

KeywordTraits: PhysicalName: Pyre Sorcerer

Tier: 2

ArtAssetID: ART_T2_MAGE_02

BaseStats: { HP: 80, PWR: 28 }

ItemSlots: 1

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, AoE

Abilities:

AbilityName: Fireblast

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: HIGHEST_HP_ENEMY (Primary), ADJACENT_ENEMIES_TO_PRIMARY (Secondary)

Effect(s):

APPLY_STATUS { Target: Primary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

APPLY_STATUS { Target: Secondary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.5], Duration: 3 }

Description: On attack, applies X Burning stacks to the highest HP enemy and Y Burning stacks to enemies adjacent to it for 3 turns.

MergeRecipe: T1_MAGE_01 + T1_MAGE_01

UnitID: T2_SENTINEL_02

Name: Spirit Warden

Tier: 2

ArtAssetID: ART_T2_SENTINEL_02

BaseStats: { HP: 110, PWR: 18, SPD: 12 }

ItemSlots: 1

OriginTrait: Earthen

ClassTrait: Priest

KeywordTraits: Guardian

Abilities:

AbilityName: Parting Gift

Type: Triggered

Trigger: ON_UNIT_DIES (Self)

Targeting: ALLY_BEHIND_SELF

Effect(s):

`HEAL_HP { Amount: [TBDAffinity, CounterAttack

Abilities:

AbilityName: Counter-Strike

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 75% of SELF_PWR], Type: 'Physical' }

Description: When this unit takes damage, it attacks the attacker for X damage (scales with PWR).

MergeRecipe: T1_ATTACKER_01 + T1_TANK_01

UnitID: T2_RANGER_02

Name: Agile Hunter

Tier: 2

ArtAssetID: ART_T2_RANGER_02

BaseStats: { HP: 95, PWR: 24 }

ItemSlots: 1

OriginTrait: Sylvan

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, Assist

Abilities:

AbilityName: Coordinated Shot

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: LOWEST_HP_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 60% of SELF_PWR], Type: 'Physical' }

Description: When an adjacent_Value, e.g., SELF_PWR * 1.5] }`

MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., SELF_PWR], Duration: 2 }

Description: When this unit dies, grants X HP and Y PWR to the ally directly behind it for 2 turns.

MergeRecipe: T1_TANK_01 + T1_SUPPORT_01

UnitID: T2_BRUISER_02

Name: Ironclad Retaliator

Tier: 2

ArtAssetID: ART_T2_BRUISER_02

BaseStats: { HP: 120, PWR: 22, SPD: 13 }

ItemSlots: 1

OriginTrait: Clockwork

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, CounterAttack

Abilities:

AbilityName: Counter-Strike

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., SELF_PWR * 0 ally attacks, this unit attacks the lowest HP enemy forX` damage (scales with PWR).

MergeRecipe: T1_ATTACKER_01 + T1_SUPPORT_01

UnitID: T2_CLERIC_02

Name: Battle Medic

Tier: 2

ArtAssetID: ART_T2_CLERIC_02

BaseStats: { HP: 100, PWR: 22 }

ItemSlots: 1

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits:.75], Type: 'Physical' }`

Description: When this unit takes damage, it attacks the attacker for X damage (scales with PWR).

MergeRecipe: T1_ATTACKER_01 + T1_TANK_01

UnitID: T2_RANGER_02

Name: Agile Hunter

Tier: 2

ArtAssetID: ART_T2_RANGER_02
HolyAffinity, Healing

Abilities:

AbilityName: Mending Aura

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF, ALLY_BEHIND_SELF

Effect(s):

HEAL_HP { Target: SELF, Amount: [TBD_* **BaseStats:** { HP:95, PWR:24 }` }

ItemSlots: 1

OriginTrait: Sylvan

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, Assist

Value, e.g., 50% of SELF_PWR] }*HEAL_HP { Target: ALLY_BEHIND_SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }`

Description: When this unit takes damage,Abilities:

AbilityName: Coordinated Shot

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Target it heals itself and the ally directly behind it forX` HP each (scales with PWR).

MergeRecipe: T1_MAGE_01 + T1_TANK_01
9ing:LOWEST_HP_ENEMY`

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., SELF_PWR * 0.6], Type. **UnitID:**T2_BUFFER_02`

Name: Morale Booster
: 'Physical' }`

Description: When an adjacent ally attacks, this unit attacks the lowest* Tier: 2

ArtAssetID: ART_T2_BUFFER_02

BaseStats: { HP: 85, PWR: 26, HP enemy for X damage (scales with PWR).

MergeRecipe: T1_...` }

ItemSlots: 1

**OriginTraitATTACKER_01 + T1_SUPPORT_01`

UnitID: `:** Mystic

ClassTrait: Priest

KeywordTraits: BuffFocus
*T2_CLERIC_02`

Name: Battle Medic

Tier: 2

ArtAssetID: ART_T2_CLERIC_02 Abilities:

AbilityName: Rallying Cry

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s):

BaseStats: { HP: 100, PWR: 20 } // SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

15` }

ItemSlots: 1

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity, Healing

**Targeting:SOURCE_OF_TRIGGER` (The ally that attacked)

`Effect(sAbilities:**

AbilityName: Mending Aura

Type: Triggered
):APPLY_STATUS { StatusName: 'Strength', Stacks: [TBD_Value, e.g., * Trigger: ON_DAMAGE_TAKEN

Targeting: SELF PWR/3], Duration: 2 }

Description: When an ally directly in front attacks, apply,ALLY_BEHIND_SELF`

Effect(s):

X stacks of Strength (increases PWR) to that ally for 2 turns.

MergeRecipe: T1_MAGE_01 + T1_SUPPORT_01
10.HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., SELF_PWR * 0.5] }
* HEAL_HP { Target: ALLY_ **UnitID:**T2_SPELLCASTER_02`

Name: VBEHIND_SELF, Amount: [TBD_Value, e.g., SELF_PWR * 0engeful Pyromancer

Tier: 2

ArtAssetID: ART_T.5] }

Description: When this unit takes damage, it heals itself and the ally2_SPELLCASTER_02`

BaseStats: { HP: 90, PWR: 28 }

ItemSlots: 1 directly behind it for X HP each (scales with PWR).

MergeRecipe: T1_MAGE_01 + T1_TANK_01

UnitID:

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, Reactive

Abilities:

AbilityName: T2_BUFFER_02

Name: Morale Booster

Tier: 2

ArtAssetID: ART_T2_BUFFER_02

BaseStats: { HP: 85, PWR: 22 } // Soulfire Burst

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: RANDOM_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value,17 }

ItemSlots: 1

OriginTrait: Mystic

ClassTrait: Priest

KeywordTraits: BuffFocus

Abilities:

AbilityName: Rallying Cry

Type: Triggered
e.g., 120% of SELF_PWR], Duration: 3 }`

Description: Whenever an allied unit dies, apply X stacks of Burning to a random enemy for 3 turns.

*** Trigger: ON_ATTACK_EXECUTED

Condition(s):MergeRecipe:** T1_MAGE_01 + T1_ATTACKER_01

SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting:ALLY_IN_FRONT_OF_SELF*Effect(s):APPLYPART 2 of X

Tier 3 Units

Fusions with T2_TANK_STATUS { StatusName: 'Strength', Stacks: [TBD_Value, e.g., SELF_PWR /_02 (Bastion Protector):

UnitID: T3_TANK_0 3], Duration: 2 }
* Description: When an ally directly in front attacks, apply X stacks of Strength (increases PWR) to that ally for 2 turns.

**Merge3_A` (Original Tank 3)

Name: Colossus Bulwark

TierRecipe: T1_MAGE_01 + T1_SUPPORT_01
10.:** 3

ArtAssetID: ART_T3_COLOSSUS_BULWARK_0 **UnitID:**T2_SPELLCASTER_02`

Name: V3`

BaseStats: { HP: 300, PWR: 30,engeful Pyromancer

Tier: 2

ArtAssetID: ART_T...` }

ItemSlots: 2

**OriginTrait2_SPELLCASTER_02`

BaseStats: { HP: `90:** Earthen

ClassTrait: Warrior

KeywordTraits: Golem, Fort, PWR:26 }

ItemSlots: 1ified, RegenFocus

Abilities:

AbilityName: Titan's Vitality

Type: Passive

Trigger: ON_TURN_START

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, Reactive

Abilities:

AbilityName: Soulfire Burst

Type: Triggered

Trigger: ON_ALLY_ *Targeting:SELF`

Effect(s): APPLY_STATUS { StatusName: 'Regeneration', Amount: [TBD_Value, e.g., 10% of SELF_PWR], Duration: 1 }

Description: AtDIES`

Targeting: RANDOM_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value], the start of its turn, gains Regeneration, healingX` HP (scales with its PWR).

MergeRecipe: T2_TANK_02 + T2_TANK_02
e.g., SELF_PWR * 1.2], Duration: 3 }`

2. **UnitID:**T3_MONK_03`

**Name:**Description: Whenever an allied unit dies, applyX` stacks of Burning to a random enemy for 3 turns. Ancestral Guardian (Monk 3)

Tier: 3

**Art

MergeRecipe: T1_MAGE_01 + T1_ATTACKERAssetID:**ART_T3_ANCESTRAL_GUARDIAN_03`

**Base_01`

Tier 3 Units

Fusions with T2_TANK_02 (Bastion Protector):

UnitID: T3_TANK_03_A (Original Tank 3)

Name: Colossus Bulwark

Tier: 3

ArtAssetID: ART_T3_COLOSSUS_BULWARK_03

BaseStats: { HP: 300, PWR: 30 }

ItemSlots: 2

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: Golem, Fortified, RegenFocus

Abilities:

AbilityName: Titan's Vitality

Type: Passive

Trigger: ON_TURN_START

Targeting: SELF

Effect(s): APPLY_STATUS { StatusName: 'Regeneration', Amount: [TBD_Value, e.g., SELF_PWR * 0.15], Duration: 1 }

Description: At the start of its turn, gains Regeneration, healing X HP (scales with its PWR).

MergeRecipe: T2_TANK_02 + T2_TANK_02

UnitID: T3_MONK_03

Name: Ancestral Guardian (Monk 3)

Tier: 3

ArtAssetID: ART_T3_ANCESTRAL_GUARDIAN_03

BaseStats: { HP: 260, PWR: 25 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Warrior

KeywordTraits: Guardian, Sacrifice

Abilities:

AbilityName: Spirit Transfer

Type: Triggered

Trigger: ON_UNIT_DIES (Self)

Targeting: ALLY_BEHIND_SELF

Effect(s): HEAL_HP { Target: ALLY_BEHIND_SELF, Amount: [TBD_Value, e.g., 100% of SELF_MaxHP] } (Clarification: Heals for this unit's Max HP, not transfers Max HP stat itself as that's much harder to balance).

Description: When this unit dies, heals the ally directly behind it for an amount equal to this unit's maximum HP.

MergeRecipe: T2_TANK_02 + T2_SUPPORT_02

UnitID: T3_BERSERKER_03 (Original Beserker 3)

Name: Frenzied Juggernaut (Beserker 3)

Tier: 3

ArtAssetID: ART_T3_FRENZIED_JUGGERNAUT_03

BaseStats: { HP: 240, PWR: 40 }

ItemSlots: 2

OriginTrait: Nomad

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, Relentless

Abilities:

AbilityName: Unstoppable Fury

Type: Passive

Trigger: ON_TURN_START

Targeting: SELF

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR] }

Description: At the start of its turn, gains HP equal to its PWR.

AbilityName: Relentless Assault

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s): PERFORM_EXTRA_ATTACK { Count: 'UntilTargetDiesOrSelfDies' }

Description: Continues to attack its current target until either the target is defeated or this unit is defeated. Each extra attack is a separate action instance. (Limit to X extra attacks per turn for balance).

MergeRecipe: T2_TANK_02 + T2_ATTACKER_02

Notes: "UntilTargetDiesOrSelfDies" needs a cap, e.g., max 3-4 extra attacks per turn, or it can lock the game.

UnitID: T3_SUMMONER_03

Name: Gatekeeper Summoner

Tier: 3

ArtAssetID: ART_T3_GATEKEEPER_SUMMONER_03

BaseStats: { HP: 220, PWR: 35 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: Summoner, ArcaneConstruct

Abilities:

AbilityName: Soul Conduit

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: EMPTY_ALLY_SLOT (Preferably where ally died, or random)

Effect(s): SUMMON_UNIT { UnitPool: 'RANDOM_MASTER_POOL_T2_UNIT', Slot: TARGET }

Description: When an allied unit dies, summon a random Tier 2 Unit from your Master Run Pool into an available slot. (Limited once per X turns for balance).

MergeRecipe: T2_TANK_02 + T2_MAGE_02

UnitID: T3_BODYGUARD_03

Name: Aegis Protector (Bodyguard 3)

Tier: 3

ArtAssetID: ART_T3_AEGIS_PROTECTOR_03

BaseStats: { HP: 280, PWR: 30 }

ItemSlots: 2

OriginTrait: Earthen

ClassTrait: Warrior

KeywordTraits: Guardian, Protector

Abilities:

AbilityName: Intercept

Type: Triggered

Trigger: ON_DAMAGE_DEALT_TO_ALLY

Condition(s): TARGET_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: SELF (for taking damage)

Effect(s):

REDIRECT_DAMAGE_TO_SELF { OriginalTarget: TARGET_OF_TRIGGER, AmountPercentage: 100 }

HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., SELF_PWR * 0.5] }

Description: When an adjacent ally takes damage, this unit takes that damage instead and heals itself for X HP (scales with PWR). (Can trigger once per turn per adjacent ally).

MergeRecipe: T2_TANK_02 + T2_SENTINEL_02

UnitID: T3_REVENGER_03

Name: Spineshield Punisher (Revenger 3)

Tier: 3

ArtAssetID: ART_T3_SPINESHIELD_PUNISHER_03

BaseStats: { HP: 250, PWR: 32 }

ItemSlots: 2

OriginTrait: Clockwork

ClassTrait: Warrior

KeywordTraits: CounterAttack, Thorns

Abilities:

AbilityName: Retribution Shard

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 100% of DamageTaken], Type: 'True' }

Description: When this unit takes damage, it deals True damage to the attacker equal to the damage taken.

MergeRecipe: T2_TANK_02 + T2_BRUISER_02

UnitID: T3_SPEARMEN_03 (Original Spearmen 3)

Name: Phalanx Captain (Spearmen 3)

Tier: 3

ArtAssetID: ART_T3_PHALANX_CAPTAIN_03

BaseStats: { HP: 230, PWR: 38 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, Reach

Abilities:

AbilityName: Formation Strike

Type: Action

Trigger: ON_ATTACK_EXECUTED

Condition(s): IS_NO_ALLY_IN_FRONT_OF_SELF

Targeting: THREE_FRONTMOST_ENEMY_UNITS

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 75% of SELF_PWR], Type: 'Physical' }

Description: If no ally is in front, attacks the 3 frontmost enemies.

AbilityName: Piercing Lunge

Type: Action

Trigger: ON_ATTACK_EXECUTED

Condition(s): IS_ALLY_IN_FRONT_OF_SELF

Targeting: BACKMOST_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 120% of SELF_PWR], Type: 'Physical' }

Description: If an ally is in front, attacks the backmost enemy.

MergeRecipe: T2_TANK_02 + T2_RANGER_02

UnitID: T3_PALADIN_03

Name: Radiant Justicar (Paladin 3)

Tier: 3

ArtAssetID: ART_T3_RADIANT_JUSTICAR_03

BaseStats: { HP: 270, PWR: 20 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Warrior

KeywordTraits: HolyAffinity, TankHybrid

Abilities:

AbilityName: Judgment Strike

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., SELF_CURRENT_HP * 0.2], Type: 'Holy' }

Description: Attacks deal bonus Holy damage equal to X% of this unit's current HP.

MergeRecipe: T2_TANK_02 + T2_CLERIC_02

UnitID: T3_WARDRUMMER_03

Name: War鼓 Thumper (WarDrummer 3)

Tier: 3

ArtAssetID: ART_T3_WARDRUMMER_THUMPER_03

BaseStats: { HP: 240, PWR: 28 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Warrior

KeywordTraits: BuffFocus, Aura

Abilities:

AbilityName: Beat of War

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: ALL_ALLIES

Effect(s): APPLY_STATUS { StatusName: 'Strength', Stacks: 1, Duration: 2 }

Description: When this unit takes damage, grants 1 stack of Strength to all allies for 2 turns.

MergeRecipe: T2_TANK_02 + T2_BUFFER_02

UnitID: T3_CONJURER_03

Name: Magma Weaver (Conjurer 3)

Tier: 3

ArtAssetID: ART_T3_MAGMA_WEAVER_03

BaseStats: { HP: 210, PWR: 38 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, CounterAttack

Abilities:

AbilityName: Immolating Retort

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

Description: When this unit takes damage, applies X stacks of Burning to the attacker for 3 turns.

MergeRecipe: T2_TANK_02 + T2_SPELLCASTER_02


Fusions with T2_SUPPORT_02 (Guardian Healer):

UnitID: T3_BARD_03

Name: Skald of Ages (Bard 3)

Tier: 3

ArtAssetID: ART_T3_SKALD_OF_AGES_03

BaseStats: { HP: 180, PWR: 30 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: BuffFocus, Aura, SupportFocus

Abilities:

AbilityName: Ballad of Growth

Type: Passive

Trigger: ON_TURN_START

Targeting: ALL_ALLIES

Effect(s):

MODIFY_STAT_PERMANENT { Stat: 'MaxHP', Amount: [TBD_Value, e.g., 1] }

MODIFY_STAT_PERMANENT { Stat: 'PWR', Amount: [TBD_Value, e.g., 1] }

// SPD stat removed - turn order is now based on team and position

Description: At the start of its turn, permanently grants all allies +1 to Max HP and PWR for this battle. (Max stacks or cap recommended for balance).

MergeRecipe: T2_SUPPORT_02 + T2_SUPPORT_02

UnitID: T3_BOWMAN_03

Name: Vigilant Sharpshooter (Bowman 3)

Tier: 3

ArtAssetID: ART_T3_VIGILANT_SHARPSHOOTER_03

BaseStats: { HP: 190, PWR: 38 }

ItemSlots: 2

OriginTrait: Nomad

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, Assist

Abilities:

AbilityName: Overwatch Fire

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY

Targeting: RANDOM_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 50% of SELF_PWR], Type: 'Physical' }

Description: Every time an ally attacks, this unit attacks a random enemy for X damage (scales with PWR).

MergeRecipe: T2_SUPPORT_02 + T2_ATTACKER_02

UnitID: T3_ELEMENTALIST_03

Name: Prismatic Conduit (Elementalist 3)

Tier: 3

ArtAssetID: ART_T3_PRISMATIC_CONDUIT_03

BaseStats: { HP: 170, PWR: 40 }

ItemSlots: 2

OriginTrait: Mystic (Can be aspected to Celestial/Infernal based on visual)

ClassTrait: Mage

KeywordTraits: MultiAffinity, SupportFocus, DebuffFocus

Abilities:

AbilityName: Elemental Attunement

Type: Passive

Trigger: ON_TURN_START

Targeting: RANDOM_ALLY, RANDOM_ENEMY

Effect(s):

APPLY_STATUS { Target: RANDOM_ALLY, StatusName: 'Spellshield', Duration: 1 } (Blocks one hostile spell/ability)

APPLY_STATUS { Target: RANDOM_ENEMY, StatusName: 'Weaken', Stacks: [TBD_Value, e.g., PWR/4], Duration: 1 }

Description: At the start of its turn, grants a random ally Spellshield (blocks 1 ability) and applies X Weaken stacks to a random enemy.

MergeRecipe: T2_SUPPORT_02 + T2_MAGE_02

UnitID: T3_PRIEST_03

Name: High Vicar (Priest 3)

Tier: 3

ArtAssetID: ART_T3_HIGH_VICAR_03

BaseStats: { HP: 200, PWR: 35, SPD: 25 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity, Healing, Aura

Abilities:

AbilityName: Divine Grace

Type: Passive

Trigger: ON_TURN_START

Targeting: ALL_ALLIES

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 75% of SELF_PWR] }

Description: At the start of its turn, heals all allies for X HP (scales with this unit's PWR).

MergeRecipe: T2_SUPPORT_02 + T2_SENTINEL_02

UnitID: T3_KAMIKAZE_03

Name: Martyr's Legacy (Kamikaze 3)

Tier: 3

ArtAssetID: ART_T3_MARTYRS_LEGACY_03

BaseStats: { HP: 150, PWR: 50, SPD: 30 }

ItemSlots: 2

OriginTrait: Clockwork (Could also be Infernal)

ClassTrait: Warrior (Or Rogue)

KeywordTraits: Sacrifice, BuffFocus

Abilities:

AbilityName: Final Surge

Type: Triggered

Trigger: ON_UNIT_DIES (Self)

Targeting: ALL_OTHER_ALLIES

Effect(s): MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., 100% of SELF_PWR], Duration: 2 }

Description: On death, grants all other allies PWR equal to this unit's PWR for 2 turns.

MergeRecipe: T2_SUPPORT_02 + T2_BRUISER_02

UnitID: T3_CROSSBOWMAN_03

Name: Siege Engineer (Crossbowman 3)

Tier: 3

ArtAssetID: ART_T3_SIEGE_ENGINEER_03

BaseStats: { HP: 180, PWR: 42, SPD: 26 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, DebuffFocus

Abilities:

AbilityName: Barbed Bolt

Type: Passive

Trigger: ON_TURN_START

Targeting: RANDOM_ENEMY

Effect(s):

DEAL_DAMAGE { Amount: [TBD_Value, e.g., 60% of SELF_PWR], Type: 'Physical' }

APPLY_STATUS { StatusName: 'Weaken', Stacks: [TBD_Value, e.g., PWR/3], Duration: 2 }

Description: At the start of its turn, attacks a random enemy for X damage and inflicts Y Weaken stacks for 2 turns.

MergeRecipe: T2_SUPPORT_02 + T2_RANGER_02

UnitID: T3_ORACLE_03

Name: Oracle of Empowerment (Oracle 3)

Tier: 3

ArtAssetID: ART_T3_ORACLE_OF_EMPOWERMENT_03

BaseStats: { HP: 190, PWR: 32, SPD: 28 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity, BuffFocus, Reactive

Abilities:

AbilityName: Blessed Vigor

Type: Triggered

Trigger: ON_HEAL_APPLIED_TO_ALLY (By any source)

Targeting: TARGET_OF_TRIGGER (The healed ally)

Effect(s): APPLY_STATUS { StatusName: 'Strength', Stacks: 1, Duration: 1 }

Description: When an ally is healed by any source, also apply 1 stack of Strength to that ally for 1 turn.

MergeRecipe: T2_SUPPORT_02 + T2_CLERIC_02

UnitID: T3_SIDEKICK_03_A (Original Sidekick 3, renamed for clarity)

Name: Maestro of Moves (Sidekick 3)

Tier: 3

ArtAssetID: ART_T3_MAESTRO_OF_MOVES_03

BaseStats: { HP: 175, PWR: 36, SPD: 35 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Priest

KeywordTraits: ComboEnabler, SupportFocus

Abilities:

AbilityName: Synchronized Strike

Type: Action

Trigger: ON_ATTACK_EXECUTED (Self)

Targeting: ADJACENT_ALLIES

Effect(s): ACTIVATE_PRIMARY_ABILITY { TargetUnits: ADJACENT_ALLIES }

Description: On attack, causes adjacent allies to immediately perform their primary action/attack. (This ability has a 2-turn cooldown).

MergeRecipe: T2_SUPPORT_02 + T2_BUFFER_02

Notes: Cooldown added for balance.

UnitID: T3_ENCHANTER_03

Name: Baleful Enchanter (Enchanter 3)

Tier: 3

ArtAssetID: ART_T3_BALEFUL_ENCHANTER_03

BaseStats: { HP: 160, PWR: 44, SPD: 27 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: ShadowAffinity, DebuffFocus, Aura

Abilities:

AbilityName: Withering Presence

Type: Passive

Trigger: ON_TURN_START

Targeting: ALL_ENEMIES

Effect(s): APPLY_STATUS { StatusName: 'Weaken', Stacks: [TBD_Value, e.g., SELF_PWR / 5], Duration: 1 }

Description: At the start of its turn, applies X Weaken stacks to all enemies for 1 turn.

MergeRecipe: T2_SUPPORT_02 + T2_SPELLCASTER_02

Fusions with T2_ATTACKER_02 (Challenger Duelist):

UnitID: T3_ASSASSIN_03

Name: Shadow Stalker (Assassin 3)

Tier: 3

ArtAssetID: ART_T3_SHADOW_STALKER_03

BaseStats: { HP: 190, PWR: 45, SPD: 38 }

ItemSlots: 2

OriginTrait: Nomad

ClassTrait: Rogue

KeywordTraits: PhysicalAffinity, Execute, StealthFocus (if stealth is added later)

Abilities:

AbilityName: Cull the Weak

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: LOWEST_HP_ENEMY (Implicit in primary attack target selection)

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 110% of SELF_PWR], Type: 'Physical' }

Description: Primary attack targets the lowest HP enemy.

AbilityName: Power Overwhelm

Type: Triggered

Trigger: ON_UNIT_KILLED_BY_SELF

Targeting: SELF

Effect(s): MODIFY_STAT_PERMANENT { Stat: PWR, Amount: [TBD_Value, e.g., 50% of KILLED_UNIT_BASE_PWR] }

Description: Permanent stat modifications are only valid for the hero and apply outside of battle nodes. When applied to units, the modifications are temporary and last only for the current battle. If this unit kills an enemy, it permanently gains X% of the killed unit's base PWR for this battle.

MergeRecipe: T2_ATTACKER_02 + T2_ATTACKER_02

UnitID: T3_BATTLEMAGE_03

Name: Arcane Spellsword (Battlemage 3)

Tier: 3

ArtAssetID: ART_T3_ARCANE_SPELLSWORD_03

BaseStats: { HP: 200, PWR: 42, SPD: 30 }

ItemSlots: 2

OriginTrait: Mystic (Or Infernal if focused on FireAffinity)

ClassTrait: Mage (Hybrid Rogue/Mage feel)

KeywordTraits: FireAffinity (if Burn), ArcaneAffinity, HybridDamage

Abilities:

AbilityName: Imbued Strikes

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s):

DEAL_DAMAGE { Amount: [TBD_Value, e.g., 100% of SELF_PWR], Type: 'Physical' }

APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.5], Duration: 2 }

Description: Every attack also applies X stacks of Burning to the target for 2 turns.

MergeRecipe: T2_ATTACKER_02 + T2_MAGE_02

UnitID: T3_LEGION_03

Name: Legion Commander (Legion 3)

Tier: 3

ArtAssetID: ART_T3_LEGION_COMMANDER_03

BaseStats: { HP: 230, PWR: 40, SPD: 28 }

ItemSlots: 2

OriginTrait: Earthen (Or Clockwork)

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, CounterAttack, Guardian

Abilities:

AbilityName: United Retaliation

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): OR { SELF_IS_TARGET_OF_TRIGGER, ADJACENT_ALLY_IS_TARGET_OF_TRIGGER }

Targeting: SOURCE_OF_TRIGGER (The original attacker)

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 70% of SELF_PWR], Type: 'Physical' }

Description: When this unit or an adjacent ally takes damage, this unit attacks the source of that damage.

MergeRecipe: T2_ATTACKER_02 + T2_SENTINEL_02

UnitID: T3_PAYBACKER_03

Name: Vengeful Berserker (Paybacker 3)

Tier: 3

ArtAssetID: ART_T3_VENGEFUL_BERSERKER_03

BaseStats: { HP: 210, PWR: 44, SPD: 33 }

ItemSlots: 2

OriginTrait: Nomad

ClassTrait: Warrior (Hybrid Rogue/Warrior feel)

KeywordTraits: PhysicalAffinity, MultiHit, Reactive

Abilities:

AbilityName: Stored Fury

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s): PERFORM_EXTRA_ATTACK { Count: [TBD_Value, e.g., NumberOfTimesHurtSinceLastOwnTurn] }

Description: On its turn to attack, attacks its target an additional time for each instance of damage this unit has taken since its last turn. (Resets count after attacking).

MergeRecipe: T2_ATTACKER_02 + T2_BRUISER_02

UnitID: T3_SNIPER_03

Name: Longshot Marksman (Sniper 3)

Tier: 3

ArtAssetID: ART_T3_LONGSHOT_MARKSMAN_03

BaseStats: { HP: 180, PWR: 48, SPD: 35 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, CounterAttack, Reach

Abilities:

AbilityName: Intercepting Shot

Type: Triggered

Trigger: ON_ATTACK_DECLARED

Condition(s): SOURCE_OF_TRIGGER_IS_ENEMY_UNIT

Targeting: SOURCE_OF_TRIGGER (The enemy unit declaring an attack)

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 80% of SELF_PWR], Type: 'Physical' }

Description: When an enemy unit declares an attack, this unit attacks that enemy.

MergeRecipe: T2_ATTACKER_02 + T2_RANGER_02

UnitID: T3_CRUSADER_03

Name: Zealous Crusader (Crusader 3)

Tier: 3

ArtAssetID: ART_T3_ZEALOUS_CRUSADER_03

BaseStats: { HP: 220, PWR: 36, SPD: 29 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Warrior

KeywordTraits: HolyAffinity, Execute, Growth

Abilities:

AbilityName: Soul Harvest

Type: Triggered

Trigger: ON_UNIT_KILLED_BY_SELF

Targeting: SELF

Effect(s):

HEAL_HP { Amount: [TBD_Value, e.g., 25% of KILLED_UNIT_MAX_HP] }

MODIFY_STAT_PERMANENT { Stat: 'PWR', Amount: [TBD_Value, e.g., 25% of KILLED_UNIT_BASE_PWR] }

Description: When this unit kills an enemy, it heals for X% of the killed unit's Max HP and permanently gains Y% of its base PWR for this battle.

MergeRecipe: T2_ATTACKER_02 + T2_CLERIC_02

UnitID: T3_COMMANDER_03

Name: Field Commander (Commander 3)

Tier: 3

ArtAssetID: ART_T3_FIELD_COMMANDER_03

BaseStats: { HP: 200, PWR: 40, SPD: 34 }

ItemSlots: 2

OriginTrait: Nomad

ClassTrait: Warrior (Hybrid Support/Warrior)

KeywordTraits: PhysicalAffinity, BuffFocus, Commander

Abilities:

AbilityName: Offensive Strategy

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: ALL_ALLIES

Effect(s): APPLY_STATUS { StatusName: 'Strength', Stacks: 1, Duration: 2 }

Description: On attack, grants 1 stack of Strength to all allies for 2 turns.

MergeRecipe: T2_ATTACKER_02 + T2_BUFFER_02

UnitID: T3_WARMAGE_03

Name: Inferno Warmage (Warmage 3)

Tier: 3

ArtAssetID: ART_T3_INFERNO_WARMAGE_03

BaseStats: { HP: 190, PWR: 46 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, AoE, HybridDamage

Abilities:

AbilityName: Blazing Assault

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER (Primary), ALL_ENEMIES (Secondary for Burn)

Effect(s):

DEAL_DAMAGE { Target: Primary, Amount: [TBD_Value, e.g., 100% of SELF_PWR], Type: 'Physical' }

APPLY_STATUS { Target: ALL_ENEMIES, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.3], Duration: 2 }

Description: On attack, deals physical damage to the target and applies X stacks of Burning to all enemies for 2 turns.

MergeRecipe: T2_ATTACKER_02 + T2_SPELLCASTER_02


Fusions with T2_MAGE_02 (Pyre Sorcerer):

UnitID: T3_ARCMAGE_03

Name: Grand Arcanist (Arcmage 3)

Tier: 3

ArtAssetID: ART_T3_GRAND_ARCANIST_03

BaseStats: { HP: 160, PWR: 50, SPD: 28 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Mage

KeywordTraits: ArcaneAffinity (or MultiAffinity), AoE, ControlFocus

Abilities:

AbilityName: Unleashed Calamity

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: ALL_ENEMIES

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.75], Duration: 3 } (Can be changed to a different status like 'Chill' or 'Vulnerable' for Arcane theme)

Description: When an allied unit dies, apply X stacks of Burning to all enemies for 3 turns.

MergeRecipe: T2_MAGE_02 + T2_MAGE_02

UnitID: T3_HEALER_03

Name: Soulfire Healer (Healer 3)

Tier: 3

ArtAssetID: ART_T3_SOULFIRE_HEALER_03

BaseStats: { HP: 190, PWR: 40, SPD: 26 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: FireAffinity (if using Burn for flavor), HolyAffinity, Healing, Reactive

Abilities:

AbilityName: Phoenix Down

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: FRONTMOST_ALLY_ALIVE (or LOWEST_HP_PERCENT_ALLY)

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 150% of SELF_PWR] }

Description: When an allied unit dies, heal the frontmost living ally for X HP (scales with this unit's PWR).

MergeRecipe: T2_MAGE_02 + T2_SENTINEL_02

UnitID: T3_FIREELEMENTAL_03

Name: Living Inferno (Fire Elemental 3)

Tier: 3

ArtAssetID: ART_T3_LIVING_INFERNO_03

BaseStats: { HP: 200, PWR: 44, SPD: 29 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage (Hybrid Warrior/Mage feel)

KeywordTraits: FireAffinity, Golem (Elemental as construct), Aura, CounterAttack

Abilities:

AbilityName: Immolation Aura

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): OR { SELF_IS_TARGET_OF_TRIGGER, ADJACENT_ALLY_IS_TARGET_OF_TRIGGER }

Targeting: SOURCE_OF_TRIGGER (The original attacker)

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.6], Duration: 2 }

Description: When this unit or an adjacent ally takes damage, apply X stacks of Burning to the attacker for 2 turns.

MergeRecipe: T2_MAGE_02 + T2_BRUISER_02

UnitID: T3_CASTER_03

Name: Focus Caster (Caster 3)

Tier: 3

ArtAssetID: ART_T3_FOCUS_CASTER_03

BaseStats: { HP: 170, PWR: 48, SPD: 33 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Mage

KeywordTraits: FireAffinity (if Burn), DoT_Focus, Assist

Abilities:

AbilityName: Kindle

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: ENEMY_WITH_LOWEST_BURNING_STACKS (or ENEMY_WITHOUT_STATUS {StatusName: 'Burning'} if none are burning)

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.7], Duration: 3 }

Description: When an adjacent ally attacks, apply X stacks of Burning to the enemy with the fewest Burning stacks for 3 turns.

MergeRecipe: T2_MAGE_02 + T2_RANGER_02

UnitID: T3_SORCERER_03

Name: Bloodfire Sorcerer (Sorcerer 3)

Tier: 3

ArtAssetID: ART_T3_BLOODFIRE_SORCERER_03

BaseStats: { HP: 180, PWR: 46, SPD: 27 }

ItemSlots: 2

OriginTrait: Celestial (Dark Celestial/Infernal hybrid)

ClassTrait: Mage

KeywordTraits: FireAffinity, Healing, HybridDamage

Abilities:

AbilityName: Consuming Flames

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

Description: Primary attack applies X stacks of Burning to the target.

AbilityName: Siphoning Heat

Type: Triggered (Follows up the action)

Trigger: ON_ATTACK_EXECUTED (Self)

Condition(s): TARGET_OF_TRIGGER_HAS_STATUS {StatusName: 'Burning'}

Targeting: LOWEST_HP_PERCENT_ALLY

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR * 0.75] }

Description: If the attacked target is Burning, also heal the ally with the lowest HP percentage for Y HP.

MergeRecipe: T2_MAGE_02 + T2_CLERIC_02

UnitID: T3_BEASTMASTER_03

Name: Primal Beastmaster (Beast Master 3)

Tier: 3

ArtAssetID: ART_T3_PRIMAL_BEASTMASTER_03

BaseStats: { HP: 190, PWR: 42, SPD: 31 }

ItemSlots: 2

OriginTrait: Sylvan (Or Mystic if summons are magical)

ClassTrait: Ranger (Hybrid Mage/Ranger)

KeywordTraits: Summoner, BuffFocus, Beast (if summons are beasts)

Abilities:

AbilityName: Call of the Wild

Type: Triggered

Trigger: ON_UNIT_DEPLOYED (Ally, includes summoned units)

Targeting: SOURCE_OF_TRIGGER (The deployed/summoned unit)

Effect(s):

HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR * 0.5] } (Or MODIFY_STAT_TEMPORARY {Stat: MaxHP})

MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., SELF_PWR * 0.25], Duration: 2 }

Description: When a new allied unit is placed or summoned into the lineup, grant it X HP and Y PWR for 2 turns (scales with this unit's PWR).

MergeRecipe: T2_MAGE_02 + T2_BUFFER_02

UnitID: T3_FIREMAGE_03

Name: Cataclysmic Firemage (Firemage 3)

Tier: 3

ArtAssetID: ART_T3_CATACLYSMIC_FIREMAGE_03

BaseStats: { HP: 170, PWR: 52, SPD: 29 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, AoE, Reactive

Abilities:

AbilityName: Chain Reaction

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: RANDOM_ENEMY (Primary), ADJACENT_ENEMIES_TO_PRIMARY (Secondary)

Effect(s):

APPLY_STATUS { Target: Primary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

APPLY_STATUS { Target: Secondary (If Primary already had Burning), StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.5], Duration: 3 }

Description: When an allied unit dies, apply X Burning stacks to a random enemy. If that enemy was already Burning, also apply Y Burning stacks to enemies adjacent to it.

MergeRecipe: T2_MAGE_02 + T2_SPELLCASTER_02

Fusions with T2_MAGE_02 (Pyre Sorcerer):

UnitID: T3_ARCMAGE_03

Name: Grand Arcanist (Arcmage 3)

Tier: 3

ArtAssetID: ART_T3_GRAND_ARCANIST_03

BaseStats: { HP: 160, PWR: 50, SPD: 28 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Mage

KeywordTraits: ArcaneAffinity (or MultiAffinity), AoE, ControlFocus

Abilities:

AbilityName: Unleashed Calamity

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: ALL_ENEMIES

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.75], Duration: 3 } (Can be changed to a different status like 'Chill' or 'Vulnerable' for Arcane theme)

Description: When an allied unit dies, apply X stacks of Burning to all enemies for 3 turns.

MergeRecipe: T2_MAGE_02 + T2_MAGE_02

UnitID: T3_HEALER_03

Name: Soulfire Healer (Healer 3)

Tier: 3

ArtAssetID: ART_T3_SOULFIRE_HEALER_03

BaseStats: { HP: 190, PWR: 40, SPD: 26 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: FireAffinity (if using Burn for flavor), HolyAffinity, Healing, Reactive

Abilities:

AbilityName: Phoenix Down

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: FRONTMOST_ALLY_ALIVE (or LOWEST_HP_PERCENT_ALLY)

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 150% of SELF_PWR] }

Description: When an allied unit dies, heal the frontmost living ally for X HP (scales with this unit's PWR).

MergeRecipe: T2_MAGE_02 + T2_SENTINEL_02

UnitID: T3_FIREELEMENTAL_03

Name: Living Inferno (Fire Elemental 3)

Tier: 3

ArtAssetID: ART_T3_LIVING_INFERNO_03

BaseStats: { HP: 200, PWR: 44, SPD: 29 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage (Hybrid Warrior/Mage feel)

KeywordTraits: FireAffinity, Golem (Elemental as construct), Aura, CounterAttack

Abilities:

AbilityName: Immolation Aura

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): OR { SELF_IS_TARGET_OF_TRIGGER, ADJACENT_ALLY_IS_TARGET_OF_TRIGGER }

Targeting: SOURCE_OF_TRIGGER (The original attacker)

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.6], Duration: 2 }

Description: When this unit or an adjacent ally takes damage, apply X stacks of Burning to the attacker for 2 turns.

MergeRecipe: T2_MAGE_02 + T2_BRUISER_02

UnitID: T3_CASTER_03

Name: Focus Caster (Caster 3)

Tier: 3

ArtAssetID: ART_T3_FOCUS_CASTER_03

BaseStats: { HP: 170, PWR: 48, SPD: 33 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Mage

KeywordTraits: FireAffinity (if Burn), DoT_Focus, Assist

Abilities:

AbilityName: Kindle

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: ENEMY_WITH_LOWEST_BURNING_STACKS (or ENEMY_WITHOUT_STATUS {StatusName: 'Burning'} if none are burning)

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.7], Duration: 3 }

Description: When an adjacent ally attacks, apply X stacks of Burning to the enemy with the fewest Burning stacks for 3 turns.

MergeRecipe: T2_MAGE_02 + T2_RANGER_02

UnitID: T3_SORCERER_03

Name: Bloodfire Sorcerer (Sorcerer 3)

Tier: 3

ArtAssetID: ART_T3_BLOODFIRE_SORCERER_03

BaseStats: { HP: 180, PWR: 46, SPD: 27 }

ItemSlots: 2

OriginTrait: Celestial (Dark Celestial/Infernal hybrid)

ClassTrait: Mage

KeywordTraits: FireAffinity, Healing, HybridDamage

Abilities:

AbilityName: Consuming Flames

Type: Action

Trigger: ON_ATTACK_EXECUTED

Targeting: TARGET_OF_TRIGGER

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

Description: Primary attack applies X stacks of Burning to the target.

AbilityName: Siphoning Heat

Type: Triggered (Follows up the action)

Trigger: ON_ATTACK_EXECUTED (Self)

Condition(s): TARGET_OF_TRIGGER_HAS_STATUS {StatusName: 'Burning'}

Targeting: LOWEST_HP_PERCENT_ALLY

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR * 0.75] }

Description: If the attacked target is Burning, also heal the ally with the lowest HP percentage for Y HP.

MergeRecipe: T2_MAGE_02 + T2_CLERIC_02

UnitID: T3_BEASTMASTER_03

Name: Primal Beastmaster (Beast Master 3)

Tier: 3

ArtAssetID: ART_T3_PRIMAL_BEASTMASTER_03

BaseStats: { HP: 190, PWR: 42, SPD: 31 }

ItemSlots: 2

OriginTrait: Sylvan (Or Mystic if summons are magical)

ClassTrait: Ranger (Hybrid Mage/Ranger)

KeywordTraits: Summoner, BuffFocus, Beast (if summons are beasts)

Abilities:

AbilityName: Call of the Wild

Type: Triggered

Trigger: ON_UNIT_DEPLOYED (Ally, includes summoned units)

Targeting: SOURCE_OF_TRIGGER (The deployed/summoned unit)

Effect(s):

HEAL_HP { Amount: [TBD_Value, e.g., SELF_PWR * 0.5] } (Or MODIFY_STAT_TEMPORARY {Stat: MaxHP})

MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., SELF_PWR * 0.25], Duration: 2 }

Description: When a new allied unit is placed or summoned into the lineup, grant it X HP and Y PWR for 2 turns (scales with this unit's PWR).

MergeRecipe: T2_MAGE_02 + T2_BUFFER_02

UnitID: T3_FIREMAGE_03

Name: Cataclysmic Firemage (Firemage 3)

Tier: 3

ArtAssetID: ART_T3_CATACLYSMIC_FIREMAGE_03

BaseStats: { HP: 170, PWR: 52, SPD: 29 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: FireAffinity, AoE, Reactive

Abilities:

AbilityName: Chain Reaction

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: RANDOM_ENEMY (Primary), ADJACENT_ENEMIES_TO_PRIMARY (Secondary)

Effect(s):

APPLY_STATUS { Target: Primary, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR], Duration: 3 }

APPLY_STATUS { Target: Secondary (If Primary already had Burning), StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.5], Duration: 3 }

Description: When an allied unit dies, apply X Burning stacks to a random enemy. If that enemy was already Burning, also apply Y Burning stacks to enemies adjacent to it.

MergeRecipe: T2_MAGE_02 + T2_SPELLCASTER_02


Fusions with T2_BRUISER_02 (Ironclad Retaliator):

UnitID: T3_EXECUTIONER_03

Name: Grim Executioner (Executioner 3)

Tier: 3

ArtAssetID: ART_T3_GRIM_EXECUTIONER_03

BaseStats: { HP: 240, PWR: 42, SPD: 25 }

ItemSlots: 2

OriginTrait: Clockwork

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, CounterAttack, Execute

Abilities:

AbilityName: Enhanced Counter

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 75% of SELF_PWR], Type: 'Physical' }

Description: When this unit takes damage, it attacks the attacker for X damage.

AbilityName: Desperate Measures

Type: Passive (Modifies Counter-Strike)

Condition(s): SELF_HP_BELOW_PERCENT { Value: 50 }

Effect(s): (Modifies the DEAL_DAMAGE effect of Enhanced Counter to double its Amount)

Description: If this unit's HP is below 50%, its counter-attacks deal double damage.

MergeRecipe: T2_BRUISER_02 + T2_BRUISER_02

UnitID: T3_HEADHUNTER_03

Name: Pack Leader Headhunter (Headhunter 3)

Tier: 3

ArtAssetID: ART_T3_PACK_LEADER_HEADHUNTER_03

BaseStats: { HP: 220, PWR: 40, SPD: 30 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Warrior (Hybrid Ranger/Warrior)

KeywordTraits: PhysicalAffinity, CounterAttack, Assist, Beast (if visuals fit)

Abilities:

AbilityName: Riposte

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 60% of SELF_PWR], Type: 'Physical' }

Description: When this unit takes damage, it attacks the attacker for X damage.

AbilityName: Pack Assault

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: TARGET_OF_ALLY_ATTACK

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 50% of SELF_PWR], Type: 'Physical' }

Description: If an adjacent ally attacks, this unit also attacks the same target for Y damage.

MergeRecipe: T2_BRUISER_02 + T2_RANGER_02

UnitID: T3_ZEALOT_03

Name: Bloodsworn Zealot (Zealot 3)

Tier: 3

ArtAssetID: ART_T3_BLOODSWORN_ZEALOT_03

BaseStats: { HP: 230, PWR: 38, SPD: 26 }

ItemSlots: 2

OriginTrait: Celestial (Dark Celestial)

ClassTrait: Warrior

KeywordTraits: HolyAffinity (Twisted), CounterAttack, Lifesteal

Abilities:

AbilityName: Fervent Retaliation

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER (For damage), SELF (For heal)

Effect(s):

DEAL_DAMAGE { Target: SOURCE_OF_TRIGGER, Amount: [TBD_Value, e.g., 70% of SELF_PWR], Type: 'Holy' }

HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., 25% of DamageDealtByThisAbility] }

Description: When this unit takes damage, it attacks the attacker dealing X Holy damage and heals itself for 25% of the damage dealt by this counter-attack.

MergeRecipe: T2_BRUISER_02 + T2_CLERIC_02

UnitID: T3_CHAMPION_03

Name: Unyielding Champion (Champion 3)

Tier: 3

ArtAssetID: ART_T3_UNYIELDING_CHAMPION_03

BaseStats: { HP: 250, PWR: 36, SPD: 28 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Warrior

KeywordTraits: PhysicalAffinity, CounterAttack, Growth, Fortified

Abilities:

AbilityName: Defiant Stance

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER (For damage), SELF (For Strength)

Effect(s):

DEAL_DAMAGE { Target: SOURCE_OF_TRIGGER, Amount: [TBD_Value, e.g., 60% of SELF_PWR], Type: 'Physical' }

APPLY_STATUS { Target: SELF, StatusName: 'Strength', Stacks: 1, Duration: 'Battle' } (Stack cap, e.g., max 5)

Description: When this unit takes damage, it attacks the attacker for X damage and gains 1 stack of Strength (max 5 stacks for this battle).

MergeRecipe: T2_BRUISER_02 + T2_BUFFER_02

UnitID: T3_DEATHKNIGHT_03

Name: Blighted Death Knight (Death Knight 3)

Tier: 3

ArtAssetID: ART_T3_BLIGHTED_DEATHKNIGHT_03

BaseStats: { HP: 210, PWR: 44, SPD: 24 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Warrior

KeywordTraits: ShadowAffinity, CounterAttack, FireAffinity (for Burn), Undead, Growth

Abilities:

AbilityName: Necrotic Rebuke

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SOURCE_OF_TRIGGER

Effect(s):

DEAL_DAMAGE { Amount: [TBD_Value, e.g., 65% of SELF_PWR], Type: 'Shadow' }

APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.25], Duration: 2 }

Description: When this unit takes damage, it attacks the attacker for X Shadow damage and applies Y Burning stacks.

AbilityName: Soul Eater

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: SELF

Effect(s): MODIFY_STAT_PERMANENT { Stat: 'PWR', Amount: [TBD_Value, e.g., 10% of SELF_MAX_HP] }

Description: If an ally dies, this unit permanently gains PWR equal to 10% of its Max HP for this battle.

MergeRecipe: T2_BRUISER_02 + T2_SPELLCASTER_02

Fusions with T2_RANGER_02 (Agile Hunter):

UnitID: T3_SHARPSHOOTER_03

Name: Deadeye Sharpshooter (Sharpshooter 3)

Tier: 3

ArtAssetID: ART_T3_DEADEYE_SHARPSHOOTER_03

BaseStats: { HP: 180, PWR: 48, SPD: 38 }

ItemSlots: 2

OriginTrait: Sylvan

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, Assist, CritFocus

Abilities:

AbilityName: Precision Volley

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: LOWEST_HP_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 60% of SELF_PWR], Type: 'Physical', CriticalHitChance: [TBD_Value, e.g., 25%] }

Description: When an adjacent ally attacks, this unit attacks the lowest HP enemy. This attack has a 25% chance to be a critical hit (deals bonus damage).

AbilityName: Keen Eye (Passive, modifies Precision Volley)

Type: Passive

Effect(s): (If CriticalHitChance on Precision Volley is successful, increase damage by +50%)

Description: Critical hits from Precision Volley deal +50% damage.

MergeRecipe: T2_RANGER_02 + T2_RANGER_02

UnitID: T3_FIELDMEDIC_03

Name: Combat Field Medic (Field Medic 3)

Tier: 3

ArtAssetID: ART_T3_COMBAT_FIELDMEDIC_03

BaseStats: { HP: 200, PWR: 40, SPD: 32 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Ranger (Hybrid Priest/Ranger)

KeywordTraits: PhysicalAffinity, Assist, Healing

Abilities:

AbilityName: Covering Fire

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: LOWEST_HP_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 50% of SELF_PWR], Type: 'Physical' }

Description: When an adjacent ally attacks, this unit attacks the lowest HP enemy.

AbilityName: Triage

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: SOURCE_OF_TRIGGER (The damaged adjacent ally)

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 100% of SELF_PWR] }

Description: If an adjacent ally takes damage, heal them for X HP (scales with this unit's PWR). (Limit once per turn per ally).

MergeRecipe: T2_RANGER_02 + T2_CLERIC_02

UnitID: T3_SKIRMISHER_03

Name: Swiftwing Skirmisher (Skirmisher 3)

Tier: 3

ArtAssetID: ART_T3_SWIFTWING_SKIRMISHER_03

BaseStats: { HP: 190, PWR: 44, SPD: 40 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Ranger

KeywordTraits: PhysicalAffinity, Assist, BuffFocus, Flying (optional visual)

Abilities:

AbilityName: Harassing Shot

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: LOWEST_HP_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 55% of SELF_PWR], Type: 'Physical' }

Description: When an adjacent ally attacks, this unit attacks the lowest HP enemy.

AbilityName: Tailwind

Type: Triggered (Follows Harassing Shot logic, or part of its effect block)

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: SOURCE_OF_TRIGGER (The attacking adjacent ally)

Effect(s): APPLY_STATUS { StatusName: 'Haste', Stacks: 1, Amount: [TBD_Value, e.g., SELF_PWR / 5, for SPD buff %], Duration: 1 }

Description: Also grants the attacking adjacent ally Haste (bonus SPD) for their next turn.

MergeRecipe: T2_RANGER_02 + T2_BUFFER_02

UnitID: T3_ARCANE ARCHER_03

Name: Mystweave Arcane Archer (Arcane Archer 3)

Tier: 3

ArtAssetID: ART_T3_MYSTWEAVE_ARCANE_ARCHER_03

BaseStats: { HP: 170, PWR: 50, SPD: 36 }

ItemSlots: 2

OriginTrait: Infernal (Or Mystic)

ClassTrait: Ranger (Hybrid Mage/Ranger)

KeywordTraits: PhysicalAffinity, Assist, DebuffFocus, ArcaneAffinity (for flavor)

Abilities:

AbilityName: Pinpoint Strike

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ADJACENT_ALLY

Targeting: LOWEST_HP_ENEMY

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 50% of SELF_PWR], Type: 'Physical' }

Description: When an adjacent ally attacks, this unit attacks the lowest HP enemy.

AbilityName: Corrupting Arrow

Type: Triggered (Modifies Pinpoint Strike)

Effect(s): (Applied on hit of Pinpoint Strike)

IF TARGET_HAS_STATUS { StatusName: 'Burning' } THEN APPLY_STATUS { Target: TARGET_OF_PINPOINT_STRIKE, StatusName: 'Weaken', Stacks: [TBD_Value, e.g., SELF_PWR / 5], Duration: 1 }

IF TARGET_HAS_STATUS { StatusName: 'Weaken' } THEN APPLY_STATUS { Target: TARGET_OF_PINPOINT_STRIKE, StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.3], Duration: 1 }

Description: This unit's attacks also apply Weaken if the target is Burning, or Burning if the target is Weakened.

MergeRecipe: T2_RANGER_02 + T2_SPELLCASTER_02


Fusions with T2_CLERIC_02 (Battle Medic):

UnitID: T3_HIGHCLERIC_03

Name: Hierophant High Cleric (High Cleric 3)

Tier: 3

ArtAssetID: ART_T3_HIEROPHANT_HIGHCLERIC_03

BaseStats: { HP: 220, PWR: 38, SPD: 28 }

ItemSlots: 2

OriginTrait: Celestial

ClassTrait: Priest

KeywordTraits: HolyAffinity, Healing, Aura, Fortified

Abilities:

AbilityName: Protective Ward

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF, ALLY_BEHIND_SELF

Effect(s):

HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

HEAL_HP { Target: ALLY_BEHIND_SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

Description: When this unit takes damage, it heals itself and the ally directly behind it.

AbilityName: Divine Intervention

Type: Passive

Trigger: ON_TURN_START

Targeting: LOWEST_HP_PERCENT_ALLY

Effect(s): HEAL_HP { Amount: [TBD_Value, e.g., 100% of SELF_PWR] }

Description: At the start of its turn, heal the ally with the lowest HP percentage for X HP (scales with this unit's PWR).

MergeRecipe: T2_CLERIC_02 + T2_CLERIC_02

UnitID: T3_BISHOP_03

Name: Shielding Bishop (Bishop 3)

Tier: 3

ArtAssetID: ART_T3_SHIELDING_BISHOP_03

BaseStats: { HP: 200, PWR: 40, SPD: 30 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Priest

KeywordTraits: HolyAffinity, Healing, BuffFocus, Protector

Abilities:

AbilityName: Reactive Mending

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF, ALLY_BEHIND_SELF

Effect(s): (Same as High Cleric's Protective Ward)

HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

HEAL_HP { Target: ALLY_BEHIND_SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

Description: When this unit takes damage, it heals itself and the ally directly behind it.

AbilityName: Aegis Bestowal

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting: SOURCE_OF_TRIGGER (The ally that attacked)

Effect(s): APPLY_STATUS { StatusName: 'Barrier', Amount: [TBD_Value, e.g., 100% of SELF_PWR], Duration: 1 } (Barrier: Absorbs X damage, consumed on hit or expires)

Description: When an ally directly in front attacks, grant that ally a Barrier absorbing X damage for 1 hit/turn (scales with this unit's PWR).

MergeRecipe: T2_CLERIC_02 + T2_BUFFER_02

UnitID: T3_INQUISITOR_03

Name: Purifying Inquisitor (Inquisitor 3)

Tier: 3

ArtAssetID: ART_T3_PURIFYING_INQUISITOR_03

BaseStats: { HP: 190, PWR: 44, SPD: 26 }

ItemSlots: 2

OriginTrait: Infernal (Anti-Infernal, uses Holy fire)

ClassTrait: Priest (Hybrid Mage/Priest)

KeywordTraits: HolyAffinity, FireAffinity (flavor), Healing, ReactiveDamage

Abilities:

AbilityName: Cauterize Wounds

Type: Triggered

Trigger: ON_DAMAGE_TAKEN

Targeting: SELF, ALLY_BEHIND_SELF

Effect(s): (Same as High Cleric's Protective Ward)

HEAL_HP { Target: SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

HEAL_HP { Target: ALLY_BEHIND_SELF, Amount: [TBD_Value, e.g., 50% of SELF_PWR] }

Description: When this unit takes damage, it heals itself and the ally directly behind it.

AbilityName: Judgment by Fire

Type: Triggered

Trigger: ON_STATUS_EFFECT_APPLIED_TO_ENEMY (By an ally)

Condition(s): STATUS_EFFECT_APPLIED_IS { StatusName: 'Burning' }

Targeting: TARGET_OF_STATUS_EFFECT (The enemy that received Burning)

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., 75% of SELF_PWR], Type: 'Holy' }

Description: When an enemy is afflicted with Burning by an ally, this unit deals X bonus Holy damage to that enemy.

MergeRecipe: T2_CLERIC_02 + T2_SPELLCASTER_02

Fusions with T2_BUFFER_02 (Morale Booster):

UnitID: T3_TACTICIAN_03

Name: Master Tactician (Tactician 3)

Tier: 3

ArtAssetID: ART_T3_MASTER_TACTICIAN_03

BaseStats: { HP: 180, PWR: 42, SPD: 36 }

ItemSlots: 2

OriginTrait: Mystic

ClassTrait: Priest (Hybrid Ranger/Priest for SPD focus)

KeywordTraits: BuffFocus, Aura, Commander

Abilities:

AbilityName: Frontline Inspiration

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting: SOURCE_OF_TRIGGER (The ally that attacked)

Effect(s): APPLY_STATUS { StatusName: 'Strength', Stacks: [TBD_Value, e.g., SELF_PWR / 3], Duration: 2 }

Description: When an ally directly in front attacks, apply X stacks of Strength to that ally.

AbilityName: Swift Maneuvers

Type: Passive

Trigger: ON_TURN_START

Targeting: ALL_ALLIES

Effect(s): APPLY_STATUS { StatusName: 'Haste', Stacks: 1, Amount: [TBD_Value, e.g., SELF_PWR / 5 for SPD%], Duration: 1 }

Description: At the start of its turn, grant all allies Haste (bonus SPD) for this turn.

MergeRecipe: T2_BUFFER_02 + T2_BUFFER_02

UnitID: T3_RITUALIST_03

Name: Soulbound Ritualist (Ritualist 3)

Tier: 3

ArtAssetID: ART_T3_SOULBOUND_RITUALIST_03

BaseStats: { HP: 170, PWR: 46, SPD: 30 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Priest (Hybrid Mage/Priest)

KeywordTraits: BuffFocus, Sacrifice, Reactive

Abilities:

AbilityName: Empowering Chant

Type: Triggered

Trigger: ON_ATTACK_EXECUTED

Condition(s): SOURCE_OF_TRIGGER_IS_ALLY_IN_FRONT_OF_SELF

Targeting: SOURCE_OF_TRIGGER (The ally that attacked)

Effect(s): APPLY_STATUS { StatusName: 'Strength', Stacks: [TBD_Value, e.g., SELF_PWR / 3], Duration: 2 }

Description: When an ally directly in front attacks, apply X stacks of Strength to that ally.

AbilityName: Essence Transfer

Type: Triggered

Trigger: ON_ALLY_DIES

Targeting: ALLY_WITH_HIGHEST_CURRENT_PWR

Effect(s): MODIFY_STAT_TEMPORARY { Stat: 'PWR', Amount: [TBD_Value, e.g., SELF_PWR], Duration: 2 }

Description: When an ally dies, the ally with the highest current PWR gains bonus PWR equal to this unit's PWR for 2 turns.

MergeRecipe: T2_BUFFER_02 + T2_SPELLCASTER_02

Fusion with T2_SPELLCASTER_02 (Vengeful Pyromancer):

UnitID: T3_LICH_03

Name: Undying Lich Lord (Lich 3)

Tier: 3

ArtAssetID: ART_T3_UNDYING_LICH_LORD_03

BaseStats: { HP: 180, PWR: 55, SPD: 25 }

ItemSlots: 2

OriginTrait: Infernal

ClassTrait: Mage

KeywordTraits: ShadowAffinity (or FireAffinity), Undead, AoE, ReactiveDamage, DoT_Focus

Abilities:

AbilityName: Harvest Souls

Type: Triggered

Trigger: ON_ANY_UNIT_DIES (Ally or Enemy)

Targeting: RANDOM_ENEMY

Effect(s): APPLY_STATUS { StatusName: 'Burning', Stacks: [TBD_Value, e.g., SELF_PWR * 0.8], Duration: 3 }

Description: Whenever any unit dies, apply X stacks of Burning to a random enemy.

AbilityName: Withering Flames

Type: Triggered

Trigger: ON_ENEMY_DIES

Condition(s): TARGET_OF_TRIGGER_HAS_STATUS { StatusName: 'Burning' }

Targeting: ALL_OTHER_ENEMIES

Effect(s): DEAL_DAMAGE { Amount: [TBD_Value, e.g., SELF_PWR * 0.5], Type: 'Shadow' }

Description: If an enemy dies while Burning, all other enemies take X Shadow damage.

MergeRecipe: T2_SPELLCASTER_02 + T2_SPELLCASTER_02
