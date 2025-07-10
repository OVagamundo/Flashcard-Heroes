<!-- Original: resources/units/EnemyHero.tres -->

```ini
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/Hero.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"enemy_hero"
display_name_key = "enemy_hero.name"
description_key = "enemy_hero.desc"
icon = ExtResource("2_icon")
tier = 0
category = &"UNIT"
item_slot_count = 5
base_hp = 10
base_pwr = 2
bonus_hp = 0
bonus_pwr = 0
ability_definitions = []

```