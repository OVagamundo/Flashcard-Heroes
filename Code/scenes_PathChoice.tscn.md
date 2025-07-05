<!-- Original: scenes/PathChoice.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://jsungguqbxwp"]

[ext_resource type="Script" uid="uid://cv7wf0v0mfp2j" path="res://scripts/PathChoice.gd" id="1_defgh"]
[ext_resource type="Script" uid="uid://b6kwe3wxewufa" path="res://scripts/BackgroundClickDetector.gd" id="2_detector_script"]

[node name="PathChoice" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_defgh")

[node name="BackgroundClickDetector" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(1, 1, 1, 0)
script = ExtResource("2_detector_script")

[node name="CenterContainer" type="CenterContainer" parent="."]
layout_mode = 0
anchor_right = 1.0
anchor_bottom = 1.0

[node name="StartBattleButton" type="Button" parent="CenterContainer"]
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
text = "Start Battle"

```