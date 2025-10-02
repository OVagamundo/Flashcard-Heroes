Implementation Prompt: New Passive Ability 'Morale Boost' for UnitTier2C
Objective: Implement a new passive ability for the UnitTier2C unit.
Ability Description:
Name: Morale Boost
Trigger: When an allied unit is defeated.
Effect: The unit with this ability gains +1 HP and +1 PWR.
Notes: There is no limit to the number of times this can activate per battle.
Implementation Steps:
The existing system architecture fully supports this ability with one minor script modification and the addition of data resources. No changes to BattleManager or AbilityResolver are required.
Step 1: Generalize the EffectModifyStat.gd Script
Our current EffectModifyStat.gd script only handles the "hp" stat. It must be updated to also handle "pwr" to make it a generic stat modification tool.
File to Modify: scripts/EffectModifyStat.gd
Action: Add a pwr case to the match statement.
code
Gdscript
# scripts/EffectModifyStat.gd

...
		match stat:
			"hp":
				var old_hp = inst.current_hp
				var new_hp = max(0, inst.current_hp + base_value)
				if is_simulation and inst.has_method("set_current_hp_silent"):
					inst.set_current_hp_silent(new_hp)
				else:
					inst.set_current_hp(new_hp)
			
+			# ADD THIS BLOCK
+			"pwr":
+				var old_pwr = inst.current_pwr
+				inst.current_pwr = max(0, inst.current_pwr + base_value)
+				if not is_simulation:
+					SignalBus.emit_signal("unit_stats_changed", inst.ball_uuid)
+			# END ADDED BLOCK
			
			_:
				pass
...
Step 2: Create the New Ability Resource File
Create a new AbilityDefinition resource that links the on_ally_death trigger to two separate EffectModifyStat effects (one for HP, one for PWR).
Create New File: resources/abilities/UnitTier2C_AllyDeathBuff.tres
Content:
code
Ini
[gd_resource type="Resource" script_class="AbilityDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/AbilityDefinition.gd" id="1_ability"]
[ext_resource type="Script" path="res://scripts/EffectModifyStat.gd" id="2_effect"]

[sub_resource type="Resource" id="EffectModifyStat_GainHP_1"]
script = ExtResource("2_effect")
parameters = { "stat": "hp", "base_value": 1 }
target_type = &"SELF"

[sub_resource type="Resource" id="EffectModifyStat_GainPWR_1"]
script = ExtResource("2_effect")
parameters = { "stat": "pwr", "base_value": 1 }
target_type = &"SELF"

[resource]
script = ExtResource("1_ability")
id = &"unit_tier2c_ally_death_buff"
name_key = "ability.unit_tier2c_ally_death_buff.name"
description_key = "ability.unit_tier2c_ally_death_buff.desc"
trigger = &"on_ally_death"
effects = Array[Resource]([SubResource("EffectModifyStat_GainHP_1"), SubResource("EffectModifyStat_GainPWR_1")])
Step 3: Attach the Ability to UnitTier2C
Modify the unit's resource file to include the new ability.
File to Modify: resources/units/UnitTier2C.tres
Action: Add the new ability to its ability_definitions array. The entire file content should be as follows:
code
Ini
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/Tier2unitC.png" id="2_icon"]
[ext_resource type="Resource" path="res://resources/abilities/UnitTier2C_AllyDeathBuff.tres" id="3_ability"]

[resource]
script = ExtResource("1_script")
id = &"unit_t2_c"
display_name_key = "unit_t2_c.name"
description_key = "unit_t2_c.desc"
icon = ExtResource("2_icon")
tier = 2
cost = 2
category = &"UNIT"
item_slot_count = 2
base_hp = 3
base_pwr = 3
bonus_hp = 0
bonus_pwr = 0
ability_definitions = [ExtResource("3_ability")]
Step 4: Add Localization Text
Add the UI text for the ability's name and description.
File to Modify: localization/game.csv
Action: Append the following lines to the end of the file.
code
Csv
ability.unit_tier2c_ally_death_buff.name,"Morale Boost"
ability.unit_tier2c_ally_death_buff.desc,"When an ally is defeated, gain +1 HP and +1 PWR."
Notes for the Developer:
This is primarily a data-driven change, confirming the health of the ability system architecture.
Visual Feedback: Due to the current implementation of CombatEvent, the +1 HP gain will trigger a green "heal" flash on the unit. The +1 PWR gain will be correctly applied to the unit's data and its UI label will update, but there will be no distinct animation for the PWR gain itself. This is expected behavior.