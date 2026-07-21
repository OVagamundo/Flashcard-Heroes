import re
import glob
import os

files = glob.glob("/Users/danhh/Desktop/Flashcard Heroes/resources/abilities/UnitTier1B_CounterOnHurt*.tres")

for file_path in files:
    with open(file_path, "r") as f:
        content = f.read()

    # 1. Add ContextCauseCondition script
    if 'path="res://scripts/conditions/ContextCauseCondition.gd"' not in content:
        content = content.replace(
            '[ext_resource type="Script" path="res://scripts/ConditionDefinition.gd" id="3_condition"]',
            '[ext_resource type="Script" path="res://scripts/ConditionDefinition.gd" id="3_condition"]\n[ext_resource type="Script" path="res://scripts/conditions/ContextCauseCondition.gd" id="3_cause_condition"]'
        )

    # 2. Change BasicAttackEffect to EffectModifyStat
    content = content.replace(
        '[ext_resource type="Script" path="res://scripts/BasicAttackEffect.gd" id="2_effect"]',
        '[ext_resource type="Script" path="res://scripts/EffectModifyStat.gd" id="2_effect"]'
    )
    
    # Remove EffectApplyStatus if present
    content = re.sub(r'\[ext_resource type="Script" path="res://scripts/EffectApplyStatus.gd" id="4_effect_status"\]\n?', '', content)

    # 3. Replace the condition
    condition_repl = """[sub_resource type="Resource" id="ConditionDefinition_DamageReceived_1"]
script = ExtResource("3_cause_condition")
id = &"cond_cause_attack"
condition_type = &"TRIGGER_CAUSE_MATCH"
parameters = { "allowed_causes": Array[StringName]([&"CAUSE_ATTACK"]) }
allowed_causes = Array[StringName]([&"CAUSE_ATTACK"])
invert_result = false"""
    content = re.sub(r'\[sub_resource type="Resource" id="ConditionDefinition_DamageReceived_1"\].*?invert_result = false', condition_repl, content, flags=re.DOTALL)

    # 4. Replace effects
    level = 1
    if "_L2" in file_path:
        level = 2
    elif "_L3" in file_path:
        level = 3

    effect_repl = f"""[sub_resource type="Resource" id="EffectModifyStat_Counter_1"]
script = ExtResource("2_effect")
target_type = &"ATTACKER"
parameters = {{ "stat": "burn_stacks", "base_value": {level} }}"""
    
    # Remove all existing effect blocks
    content = re.sub(r'\[sub_resource type="Resource" id="BasicAttackEffect_Counter_1"\].*?parameters = .*?\n', '', content, flags=re.DOTALL)
    content = re.sub(r'\[sub_resource type="Resource" id="EffectApplyStatus_Burn.*?\n\n', '', content, flags=re.DOTALL)
    
    # Insert new effect block before [resource]
    content = content.replace('[resource]', effect_repl + '\n\n[resource]')

    # Update effects array
    content = re.sub(r'effects = Array\[Resource\]\(\[.*?\]\)', 'effects = Array[Resource]([SubResource("EffectModifyStat_Counter_1")])', content)

    with open(file_path, "w") as f:
        f.write(content)

print("Migration completed.")
