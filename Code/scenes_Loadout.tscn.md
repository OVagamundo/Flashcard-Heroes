<!-- Original: scenes/Loadout.tscn -->

```ini
[gd_scene load_steps=2 format=3 uid="uid://dsgh5wwasg7xe"]

[ext_resource type="Script" uid="uid://bfplyre8ei412" path="res://scripts/Loadout.gd" id="1_bcdef"]

[node name="Loadout" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_bcdef")

[node name="CenterContainer" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="BeginButton" type="Button" parent="CenterContainer"]
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Begin"

```