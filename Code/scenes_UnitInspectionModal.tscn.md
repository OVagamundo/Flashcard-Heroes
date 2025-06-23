<!-- Original: scenes/UnitInspectionModal.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://c5w2d2h7s7x8y"]

[ext_resource type="Script" path="res://scripts/UnitInspectionModal.gd" id="1_abcde"]
[ext_resource type="Script" path="res://scripts/ModalBackground.gd" id="2_fghij"]

[node name="UnitInspectionModal" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_abcde")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.5)
script = ExtResource("2_fghij")

[node name="PanelContainer" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -300.0
offset_top = -250.0
offset_right = 300.0
offset_bottom = 250.0
grow_horizontal = 2
grow_vertical = 2

[node name="MarginContainer" type="MarginContainer" parent="PanelContainer"]
layout_mode = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer/MarginContainer"]
layout_mode = 2
theme_override_constants/separation = 15

[node name="UnitInfoContainer" type="HBoxContainer" parent="PanelContainer/MarginContainer/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="UnitView" type="PanelContainer" parent="PanelContainer/MarginContainer/VBoxContainer/UnitInfoContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(128, 128)
layout_mode = 2

[node name="UnitDetails" type="VBoxContainer" parent="PanelContainer/MarginContainer/VBoxContainer/UnitInfoContainer"]
layout_mode = 2
size_flags_horizontal = 3

[node name="NameLabel" type="Label" parent="PanelContainer/MarginContainer/VBoxContainer/UnitInfoContainer/UnitDetails"]
unique_name_in_owner = true
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Unit Name"
autowrap_mode = 2

[node name="DescriptionLabel" type="Label" parent="PanelContainer/MarginContainer/VBoxContainer/UnitInfoContainer/UnitDetails"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
text = "Unit description goes here. It can be quite long and will need to wrap to multiple lines."
autowrap_mode = 2

[node name="HSeparator" type="HSeparator" parent="PanelContainer/MarginContainer/VBoxContainer"]
layout_mode = 2

[node name="ItemsLabel" type="Label" parent="PanelContainer/MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Equipped Items"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="PanelContainer/MarginContainer/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
horizontal_scroll_mode = 0

[node name="ItemGrid" type="GridContainer" parent="PanelContainer/MarginContainer/VBoxContainer/ScrollContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/h_separation = 5
theme_override_constants/v_separation = 5
columns = 5

```