Prompt: Implement a New "Overflow" Ability for ItemTier3D
Objective: Implement a new passive ability for the Tier 3 item, ItemTier3D. This ability, called "Overflow," will cause any excess damage from a lethal attack to be dealt to the adjacent unit behind the primary target. The implementation must integrate seamlessly with the existing simulation and presentation pipeline to ensure the visual sequence of events is correct.
Ability Details:
Name: Overflow
Description: "Excess damage from lethal attacks is dealt to the adjacent unit behind the target."
Trigger: on_attack (when the holder of the item initiates an attack).
Execution Priority: This is a high-priority follow-up attack. It must execute after the basic attack but before other reactions like counter-attacks. A priority of -10 is required.
Targeting: The effect targets the unit in the slot directly behind the primary attack target. "Behind" is relative to the flow of combat (e.g., if the frontmost player unit is at slot 5, "behind" is slot 4).
Visual Presentation Sequence Example:
An attacker with 4 PWR, equipped with ItemTier3D, attacks a target with 2 HP. The unit behind the target also has 2 HP.
The attacker performs its attack animation.
The primary target takes 2 damage (plays damage animation/flash).
The adjacent unit behind the target takes the 2 overflow damage (plays damage animation/flash).
The primary target plays its death animation.
The adjacent unit plays its death animation.
Implementation Steps
Step 1: Enhance the on_attack Trigger Context
To calculate overflow damage, the effect needs to know the target's health before the main attack. This requires a safe, additive change to scripts/BattleManager.gd.
File to Modify: scripts/BattleManager.gd
Function to Modify: _enqueue_attack_for
Action: Add the target_initial_hp key to the context dictionary.
code
Gdscript
func _enqueue_attack_for(attacker: GachaBallInstance) -> void:
	var is_player = _is_player_unit(attacker)
	var target = _get_frontmost_target(is_player)
	if not is_instance_valid(target): return

	var context: Dictionary = {
		"source_uuid": attacker.ball_uuid, 
		"target_uuid": target.ball_uuid,
		"target_initial_hp": target.current_hp  # ADD THIS LINE
	}
	
	# Trigger on_attack abilities
	AbilityResolver.process_trigger(&"on_attack", context)
	
	# Always add basic attack
	var basic_attack_def = Database.get_ability_definition(&"basic_attack")
	if is_instance_valid(basic_attack_def) and not basic_attack_def.effects.is_empty():
		var basic_attack_request = EffectRequest.new(
			attacker.ball_uuid, &"basic_attack", basic_attack_def.effects[0], 
			[target.ball_uuid], context, 0
		)
		enqueue_effect_request(basic_attack_request)
Step 2: Create the New Effect Script
This script contains the core logic for calculating overflow damage and identifying the correct adjacent target. It adheres to the "Simulate, then Present" contract.
Create New File: scripts/EffectOverflowDamageAdjacent.gd
Content:
code
Gdscript
# res://scripts/EffectOverflowDamageAdjacent.gd
@tool
class_name EffectOverflowDamageAdjacent
extends EffectDefinition

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var source_instance = battle_manager.get_instance_by_uuid(source_uuid)
	var target_uuid: String = context.get("target_uuid")
	var target_instance = battle_manager.get_instance_by_uuid(target_uuid)
	var target_initial_hp: int = context.get("target_initial_hp", 0)

	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance) or target_initial_hp == 0:
		return null

	var damage_dealt = source_instance.current_pwr
	
	if damage_dealt <= target_initial_hp:
		return null
		
	var overflow_damage = damage_dealt - target_initial_hp
	if overflow_damage <= 0:
		return null
	
	var overflow_target = _find_adjacent_target(target_instance, battle_manager)
	
	if is_instance_valid(overflow_target):
		var new_hp = max(0, overflow_target.current_hp - overflow_damage)
		overflow_target.set_current_hp_silent(new_hp)
		
		battle_manager.trigger_on_hurt(overflow_target.ball_uuid, overflow_damage, source_uuid)
		
		return {
			"stat": "hp",
			"amount": -overflow_damage,
			"targets": [overflow_target.ball_uuid]
		}

	return null

func _find_adjacent_target(primary_target: GachaBallInstance, battle_manager: Node) -> GachaBallInstance:
	var loc = primary_target.get_location()
	if not is_instance_valid(loc):
		return null

	var adjacent_index = -1
	
	if loc.container == battle_manager.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP:
		adjacent_index = loc.index - 1
	elif loc.container == battle_manager.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP:
		adjacent_index = loc.index + 1
	else:
		return null
        
	if adjacent_index < 0 or adjacent_index >= 6:
		return null
    
	var adjacent_loc = LocationIdentifier.new(loc.container, adjacent_index)
	var adjacent_instance = battle_manager.get_instance_by_location(adjacent_loc)
    
	if is_instance_valid(adjacent_instance) and adjacent_instance.current_hp > 0:
		return adjacent_instance
        
	return null
Step 3: Create the New Ability Definition Resource
This resource links the trigger to the effect and sets the crucial execution priority.
Create New File: resources/abilities/ItemTier3D_OverflowAdjacent.tres
Content:
code
Ini
[gd_resource type="Resource" script_class="AbilityDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/AbilityDefinition.gd" id="1_ability"]
[ext_resource type="Script" path="res://scripts/EffectOverflowDamageAdjacent.gd" id="2_effect"]

[sub_resource type="Resource" id="EffectOverflowDamageAdjacent_1"]
script = ExtResource("2_effect")
parameters = {}
target_type = &"ATTACK_TARGET"

[resource]
script = ExtResource("1_ability")
id = &"item_tier3d_overflow_adjacent"
name_key = "ability.item_tier3d_overflow.name"
description_key = "ability.item_tier3d_overflow.desc"
trigger = &"on_attack"
priority = -10
effects = Array[Resource]([SubResource("EffectOverflowDamageAdjacent_1")])
Step 4: Update the Item Definition
Modify the ItemTier3D.tres item to include the new ability, ensuring it retains its stat bonuses.
File to Modify: resources/items/ItemTier3D.tres
New Content:
code
Ini
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/items/Tier3ItemD.png" id="2_icon"]
[ext_resource type="Resource" path="res://resources/abilities/ItemTier3D_OverflowAdjacent.tres" id="3_ability"]

[resource]
script = ExtResource("1_script")
id = &"item_t3_d"
display_name_key = "item_t3_d.name"
description_key = "item_t3_d.desc"
icon = ExtResource("2_icon")
tier = 3
cost = 3
category = &"ITEM"
item_slot_count = 0
base_hp = 0
base_pwr = 0
bonus_hp = 2
bonus_pwr = 2
ability_definitions = [ExtResource("3_ability")]
Step 5: Add Localization Text
For the ability's name and description to be displayed in the UI, add the following lines to your localization file.
File to Modify: localization/game.csv
Add these lines:
code
Csv
ability.item_tier3d_overflow.name,"Overflow"
ability.item_tier3d_overflow.desc,"Excess damage from lethal attacks is dealt to the adjacent unit behind the target."
This completes the implementation. The new ability is now fully integrated into the game's systems.