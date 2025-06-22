<!-- Original: scenes/Main.tscn -->

```ini
[gd_scene load_steps=2 format=3 uid="uid://crndwktdbp0rc"]

[ext_resource type="Script" uid="uid://d1ts0m0sqa1lk" path="res://scripts/Main.gd" id="1_cdefg"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_cdefg")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 4

[node name="ContentArea" type="SubViewportContainer" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
stretch = true

[node name="SubViewport" type="SubViewport" parent="VBoxContainer/ContentArea"]
handle_input_locally = false
size = Vector2i(2, 2)
render_target_update_mode = 4

[node name="MarginContainer" type="MarginContainer" parent="VBoxContainer/ContentArea/SubViewport"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="BottomArea" type="PanelContainer" parent="VBoxContainer"]
layout_mode = 2

[node name="HBoxContainer" type="HBoxContainer" parent="VBoxContainer/BottomArea"]
layout_mode = 2
size_flags_horizontal = 4
theme_override_constants/separation = 4

[node name="InspectInventoryButton" type="Button" parent="VBoxContainer/BottomArea/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Inspect Inventory"

[node name="DrawTier1Button" type="Button" parent="VBoxContainer/BottomArea/HBoxContainer"]
unique_name_in_owner = true
visible = false
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Draw Tier 1"

[node name="DrawTier2Button" type="Button" parent="VBoxContainer/BottomArea/HBoxContainer"]
unique_name_in_owner = true
visible = false
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Draw Tier 2"

[node name="DrawTier3Button" type="Button" parent="VBoxContainer/BottomArea/HBoxContainer"]
unique_name_in_owner = true
visible = false
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Draw Tier 3"

[node name="ModalLayer" type="CanvasLayer" parent="."]
unique_name_in_owner = true

[node name="%ModalLayer" type="CanvasLayer" parent="."]
layer = 128

```