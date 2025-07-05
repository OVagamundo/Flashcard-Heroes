<!-- Original: scenes/Battle.tscn -->

```ini
[gd_scene load_steps=4 format=3 uid="uid://uiilu4273ttr"]

[ext_resource type="Script" uid="uid://bwx6ux5t1drf5" path="res://scripts/BattleManager.gd" id="1_battle_manager_script"]
[ext_resource type="Script" uid="uid://dp7nlwa5djbf" path="res://scripts/Battle.gd" id="2_abcde"]
[ext_resource type="Script" uid="uid://b6kwe3wxewufa" path="res://scripts/BackgroundClickDetector.gd" id="3_detector_script"]

[node name="Battle" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("2_abcde")

[node name="BackgroundClickDetector" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(1, 1, 1, 0)
script = ExtResource("3_detector_script")

[node name="BattleManager" type="Node" parent="."]
script = ExtResource("1_battle_manager_script")

[node name="TeamAreas" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
alignment = 1

[node name="PlayerArea" type="VBoxContainer" parent="TeamAreas"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="Control" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="PlayerLineup" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot5" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="Control2" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="BenchAndInventory" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="PlayerBench" type="HBoxContainer" parent="TeamAreas/PlayerArea/BenchAndInventory"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="BenchSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="BenchSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="BenchSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemInventory" type="HBoxContainer" parent="TeamAreas/PlayerArea/BenchAndInventory"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="ItemIventorySlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemIventorySlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="ItemIventorySlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/ItemInventory"]
custom_minimum_size = Vector2(80, 80)
layout_mode = 2
mouse_filter = 1

[node name="Control3" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="Spacer" type="Control" parent="TeamAreas"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="EnemyArea" type="VBoxContainer" parent="TeamAreas"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="Control" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="EnemyLineup" type="HBoxContainer" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="LineupSlot5" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineup"]
custom_minimum_size = Vector2(100, 100)
layout_mode = 2
mouse_filter = 1

[node name="Control2" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="DiscardArea" type="HBoxContainer" parent="TeamAreas/EnemyArea"]
layout_mode = 2
mouse_filter = 2
alignment = 1

[node name="ReshuffleButton" type="Button" parent="TeamAreas/EnemyArea/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 1
text = "Reshuffle"

[node name="DiscardPileButton" type="Button" parent="TeamAreas/EnemyArea/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 1
text = "Discard Pile (0)"

[node name="Control3" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="ModalLayer" type="CanvasLayer" parent="."]
unique_name_in_owner = true
layer = 128

```