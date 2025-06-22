<!-- Original: scenes/GachaBallView.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://l5mhu3dnclc4"]

[ext_resource type="Script" uid="uid://dj471v4u5j0dv" path="res://scripts/GachaBallView.gd" id="1_cm7jq"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_5h8t7"]
bg_color = Color(0.2, 0.2, 0.2, 0.7)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.376471, 0.376471, 0.376471, 1)

[node name="GachaBallView" type="PanelContainer"]
mouse_filter = 1
theme_override_styles/panel = SubResource("StyleBoxFlat_5h8t7")
script = ExtResource("1_cm7jq")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 4

[node name="Icon" type="TextureRect" parent="VBoxContainer"]
texture_filter = 3
layout_mode = 2
size_flags_vertical = 3

[node name="ItemGrid" type="GridContainer" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/h_separation = 2
theme_override_constants/v_separation = 2
columns = 2

```