Implementation Prompt: New Passive Ability 'Morale Boost' for UnitTier2C (Revised & Verified)
Objective: Implement a new passive ability for the UnitTier2C unit. This prompt is a complete and verified plan that corrects issues from a previous attempt.
Ability Description:
Name: Morale Boost
Trigger: When an allied unit (a unit on the same team) is defeated.
Effect: The unit with this ability gains +1 HP and +1 PWR.
Notes: There is no limit to the number of times this can activate per battle.
Critical Prerequisite: Fix the on_ally_death Trigger
The first reported bug (triggering on enemy death) is caused by a latent issue in BattleManager.gd where the on_ally_death trigger is incorrectly broadcast to all units on the battlefield instead of just the dying unit's teammates. This must be corrected before implementing the new ability.
File to Modify: scripts/BattleManager.gd
Function to Modify: _check_for_deaths
You will apply a similar fix in two places within this function.
1. Inside the loop for Player Unit Deaths:
Find this block:
code
Gdscript
// Trigger on_ally_death for all other units
var all_units = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
for ally in all_units:
    if ally.ball_uuid != unit.ball_uuid:
        var ally_death_context: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
        AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
Replace it with this corrected block:
code
Gdscript
// CORRECTED: When a player unit dies, only notify other player units.
var player_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP)
for ally in player_allies:
    if ally.ball_uuid != unit.ball_uuid:
        var ally_death_context: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
        AbilityResolver.process_trigger(&"on_ally_death", ally_death_context)
2. Inside the loop for Enemy Unit Deaths:
Find this block:
code
Gdscript
// Trigger on_ally_death for all other units
var all_units2 = get_instances_in_container(BATTLE_CONTAINER_TAGS.PLAYER_LINEUP) + get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
for ally in all_units2:
    if ally.ball_uuid != unit.ball_uuid:
        var ally_death_context2: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
        AbilityResolver.process_trigger(&"on_ally_death", ally_death_context2)
Replace it with this corrected block:
code
Gdscript
// CORRECTED: When an enemy unit dies, only notify other enemy units.
var enemy_allies = get_instances_in_container(BATTLE_CONTAINER_TAGS.ENEMY_LINEUP)
for ally in enemy_allies:
    if ally.ball_uuid != unit.ball_uuid:
        var ally_death_context2: Dictionary = {"source_uuid": ally.ball_uuid, "dead_ally_uuid": unit.ball_uuid}
        AbilityResolver.process_trigger(&"on_ally_death", ally_death_context2)
Implementation Steps
Step 1: Generalize the EffectModifyStat.gd Script
Update this script to handle PWR modification. This change is safe and makes the effect more versatile.
File to Modify: scripts/EffectModifyStat.gd
Action: Add a pwr case to the match stat: block.
code
Gdscript
# scripts/EffectModifyStat.gd
...
		match stat:
			"hp":
				var old_hp = inst.current_hp
				var new_hp = max(0, inst.current_hp + base_value)
				# Update HP silently during simulation, loudly during non-simulation
				if is_simulation and inst.has_method("set_current_hp_silent"):
					inst.set_current_hp_silent(new_hp)
				else:
					inst.set_current_hp(new_hp)
			
			# ADD THIS BLOCK TO HANDLE POWER MODIFICATION
			"pwr":
				# This is an increment, not an assignment, preventing fixed-value bugs.
				inst.current_pwr += base_value
				inst.current_pwr = max(0, inst.current_pwr) # Ensure PWR doesn't go below zero.
				
				# Emit signal outside of simulation so UI updates.
				if not is_simulation:
					SignalBus.emit_signal("unit_stats_changed", inst.ball_uuid)
			# END OF ADDED BLOCK
			
			_:
				pass
...
Step 2: Create the New Ability Resource File
Create a new AbilityDefinition resource that links the on_ally_death trigger to two separate EffectModifyStat effects.
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
Action: The entire file content should be as follows:
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
Verification Plan
After implementing the changes, perform the following tests to confirm correctness and prevent the previous bugs.
Test Case 1: Ally Death (Correct Trigger)
Start a battle with UnitTier2C (3 HP, 3 PWR) and another player unit (e.g., UnitTier1A) on the lineup.
Let the allied UnitTier1A be defeated.
Expected Result: UnitTier2C's stats should increase to 4 HP and 4 PWR.
Test Case 2: Enemy Death (Correct Filtering)
Start a battle with only UnitTier2C (3 HP, 3 PWR) on the player's lineup.
Defeat any enemy unit.
Expected Result: UnitTier2C's stats should remain unchanged at 3 HP and 3 PWR. This confirms the prerequisite fix is working.
Debugging Step (If the PWR value is incorrect):
If you observe the PWR being set to a fixed value again, temporarily add a print statement inside the pwr case in scripts/EffectModifyStat.gd to diagnose the issue:
code
Gdscript
"pwr":
    var old_pwr = inst.current_pwr
    # --- TEMPORARY DEBUG LOG ---
    print("EffectModifyStat DEBUG: Unit '", inst.get_definition().id, "' Old PWR: ", old_pwr, ", Gaining: ", base_value)
    # ---------------------------
    inst.current_pwr += base_value
    inst.current_pwr = max(0, inst.current_pwr)