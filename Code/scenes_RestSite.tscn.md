<!-- Original: scenes/RestSite.tscn -->

```ini
[gd_scene load_steps=2 format=3 uid="uid://b8q7p6s5d4f3e"]

[ext_resource type="Script" path="res://scripts/RestSite.gd" id="1_script"]

[node name="RestSite" type="VBoxContainer"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 40
alignment = 1
script = ExtResource("1_script")

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 2
theme_override_font_sizes/font_size = 48
text = "Rest Site"
horizontal_alignment = 1

[node name="DescriptionLabel" type="Label" parent="."]
layout_mode = 2
text = "Choose an action to perform."
horizontal_alignment = 1

[node name="ActionButtons" type="HBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 50
alignment = 1

[node name="TrainHPButton" type="Button" parent="ActionButtons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(200, 100)
layout_mode = 2
text = "Train HP"

[node name="TrainPWRButton" type="Button" parent="ActionButtons"]
unique_name_in_owner = true
custom_minimum_size = Vector2(200, 100)
layout_mode = 2
text = "Train PWR"

[node name="LeaveButton" type="Button" parent="."]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
text = "Leave" 
```