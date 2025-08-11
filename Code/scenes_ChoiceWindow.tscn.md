<!-- Original: scenes/ChoiceWindow.tscn -->

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ChoiceWindow.gd" id="1_stuvw"]


[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_abcde"]
bg_color = Color(0.2, 0.2, 0.2, 1)

[node name="ChoiceWindow" type="PanelContainer"]
custom_minimum_size = Vector2(300, 150)
layout_mode = 0
anchors_preset = 0
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 0.0
anchor_bottom = 0.0
grow_horizontal = 0
grow_vertical = 0
script = ExtResource("1_stuvw")
mouse_filter = 1
theme_override_styles/panel = SubResource("StyleBoxFlat_abcde")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 10
alignment = 1

[node name="Label" type="Label" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "Choose Action"
horizontal_alignment = 1
vertical_alignment = 1

[node name="HBoxContainer" type="HBoxContainer" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
alignment = 1

[node name="MergeButton" type="Button" parent="VBoxContainer/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "Merge"

[node name="SwapButton" type="Button" parent="VBoxContainer/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "Swap"
```