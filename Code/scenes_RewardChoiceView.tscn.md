<!-- Original: scenes/RewardChoiceView.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://ctqwj8k7ro5ib"]

[ext_resource type="PackedScene" uid="uid://l5mhu3dnclc4" path="res://scenes/GachaBallView.tscn" id="1"]
[ext_resource type="Script" path="res://scripts/RewardChoiceView.gd" id="2"]

[node name="RewardChoiceView" type="PanelContainer"]
script = ExtResource("2")

[node name="GachaBallView" parent="." instance=ExtResource("1")]
layout_mode = 2

```