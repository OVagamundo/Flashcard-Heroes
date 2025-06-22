<!-- Original: resources/units/hero.tres -->

```ini
[gd_resource type="Resource" script_class="GachaBallDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/GachaBallDefinition.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/units/hero.png" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = &"hero"
display_name_key = "Hero"
description_key = "The player's champion."
icon = ExtResource("2_icon")
tier = 0
category = &"UNIT"
item_slot_count = 1
```