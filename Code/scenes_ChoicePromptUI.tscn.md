<!-- Original: scenes/ChoicePromptUI.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://qt8jk8l33dys"]

[ext_resource type="Script" uid="uid://lm11etk0hd3r" path="res://scripts/ChoicePromptUI.gd" id="1_stuvw"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_abcde"]
bg_color = Color(0.2, 0.2, 0.2, 1)

[node name="ChoicePromptUI" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_stuvw")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.5)

[node name="PanelContainer" type="PanelContainer" parent="."]
custom_minimum_size = Vector2(300, 150)
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -75.0
offset_right = 150.0
offset_bottom = 75.0
grow_horizontal = 2
grow_vertical = 2
theme_override_styles/panel = SubResource("StyleBoxFlat_abcde")

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer"]
layout_mode = 2
theme_override_constants/separation = 10
alignment = 1

[node name="Label" type="Label" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "Choose Action"
horizontal_alignment = 1
vertical_alignment = 1

[node name="HBoxContainer" type="HBoxContainer" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
alignment = 1

[node name="MergeButton" type="Button" parent="PanelContainer/VBoxContainer/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "Merge"

[node name="SwapButton" type="Button" parent="PanelContainer/VBoxContainer/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
text = "Swap"

```