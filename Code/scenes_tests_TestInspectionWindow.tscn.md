<!-- Original: scenes/tests/TestInspectionWindow.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://b23x8kphv5x3v"]

[ext_resource type="Script" path="res://scripts/tests/TestInspectionWindow.gd" id="1_abcde"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_12345"]
bg_color = Color(0.12, 0.12, 0.17, 0.95)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
border_color = Color(0.6, 0.6, 0.7, 1)
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_right = 5
corner_radius_bottom_left = 5

[node name="TestInspectionWindow" type="PanelContainer"]
custom_minimum_size = Vector2(250, 0)
mouse_filter = 0
theme_override_styles/panel = SubResource("StyleBoxFlat_12345")
script = ExtResource("1_abcde")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 2
theme_override_constants/margin_left = 8
theme_override_constants/margin_top = 8
theme_override_constants/margin_right = 8
theme_override_constants/margin_bottom = 8

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="NameLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 18
text = "Item Name"
hal_ign = 1

[node name="HSeparator" type="HSeparator" parent="MarginContainer/VBoxContainer"]
layout_mode = 2

[node name="DescriptionLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Item description goes here."
autowrap_mode = 3

[node name="EquippedItemsLabel" type="Label" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Child Items:"

[node name="ItemGrid" type="GridContainer" parent="MarginContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
columns = 5

```