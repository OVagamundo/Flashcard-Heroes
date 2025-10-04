Final, Verified Implementation Prompt
Objective: Implement a new passive ability for UnitTier3D. This ability, "Resilient Aura," activates when the unit is hurt, granting +1 HP and +1 PWR to its adjacent allies.
Ability Details:
Name: Resilient Aura
Description: "When hurt, grants +1 HP and +1 PWR to adjacent allies."
Trigger: on_hurt
Execution Priority: This is a high-priority defensive reaction. It must have a priority of 100.
Targeting: The effect targets adjacent allies (the units in slots directly to the left and right).
Implementation Steps
Step 1: Create the New Ability Definition Resource
This resource file defines the "Resilient Aura" ability. It uses two instances of the existing EffectModifyStat.gd script to grant both HP and PWR buffs in a single trigger event.
Create New File: resources/abilities/UnitTier3D_ResilientAura.tres
Content:
code
Ini
[gd_resource type="Resource" script_class="AbilityDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/AbilityDefinition.gd" id="1_ability"]
[ext_resource type="Script" path="res://scripts/EffectModifyStat.gd" id="2_effect"]

[sub_resource type="Resource" id="EffectModifyStat_BuffHP_1"]
script = ExtResource("2_effect")
parameters = { "stat": "hp", "base_value": 1 }
target_type = &"ADJACENT_ALLIES"

[sub_resource type="Resource" id="EffectModifyStat_BuffPWR_1"]
script = ExtResource("2_effect")
parameters = { "stat": "pwr", "base_value": 1 }
target_type = &"ADJACENT_ALLIES"

[resource]
script = ExtResource("1_ability")
id = &"unit_tier3d_resilient_aura"
name_key = "ability.unit_tier3d_resilient_aura.name"
description_key = "ability.unit_tier3d_resilient_aura.desc"
trigger = &"on_hurt"
priority = 100
effects = Array[Resource]([SubResource("EffectModifyStat_BuffHP_1"), SubResource("EffectModifyStat_BuffPWR_1")])
Step 2: Update the Unit Definition
Modify the UnitTier3D.tres file to include this new ability, while ensuring all its existing stats are preserved.
File to Modify: resources/units/UnitTier3D.tres
New Content:
code
Ini
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/Tier3unitD.png" id="2_icon"]
[ext_resource type="Resource" path="res://resources/abilities/UnitTier3D_ResilientAura.tres" id="3_ability"]

[resource]
script = ExtResource("1_script")
id = &"unit_t3_d"
display_name_key = "unit_t3_d.name"
description_key = "unit_t3_d.desc"
icon = ExtResource("2_icon")
tier = 3
cost = 3
category = &"UNIT"
item_slot_count = 4
base_hp = 6
base_pwr = 6
bonus_hp = 0
bonus_pwr = 0
ability_definitions = [ExtResource("3_ability")]
Step 3: Add Localization Text
For the ability's name and description to appear correctly in the UI, add the following lines to your localization file.
File to Modify: localization/game.csv
Add these lines:
code
Csv
ability.unit_tier3d_resilient_aura.name,"Resilient Aura"
ability.unit_tier3d_resilient_aura.desc,"When hurt, grants +1 HP and +1 PWR to adjacent allies."