# Discard Pile: Scene & Visual Context

This document contains the full TSCN source and shader code for the visual components of the Discard Pile and its environment.

---

## 1. Scene Compositions (TSCN)

### [Battle.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/Battle.tscn)
```tscn
[gd_scene load_steps=8 format=3 uid="uid://c8qj2qj2qj2q"]

[ext_resource type="Script" path="res://scripts/BattleManager.gd" id="1_battle_manager_script"]
[ext_resource type="Script" path="res://scripts/BattleView.gd" id="3_battle_view_script"]
[ext_resource type="Script" path="res://scripts/BattleAnimator.gd" id="2_battle_animator_script"]
[ext_resource type="PackedScene" path="res://scenes/SlotView.tscn" id="5_slotview"]
[ext_resource type="Script" path="res://scripts/TestEnvironmentManager.gd" id="5_testenv"]
[ext_resource type="FontFile" path="res://assets/fonts/Press_Start_2P/PressStart2P-Regular.ttf" id="6_label_font"]
[ext_resource type="FontFile" path="res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf" id="7_stat_font"]
[ext_resource type="Texture2D" path="res://assets/ui/BGs/battle.png" id="8_bg"]

[node name="Battle" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 1
script = ExtResource("3_battle_view_script")

[node name="Background" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
texture = ExtResource("8_bg")
expand_mode = 1
stretch_mode = 6

[node name="BattleManager" type="Node" parent="."]
script = ExtResource("1_battle_manager_script")

[node name="BattleAnimator" type="Node" parent="."]
script = ExtResource("2_battle_animator_script")

[node name="TeamAreas" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 60.0
offset_top = 0.0
offset_right = -60.0
offset_bottom = 0.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_constants/separation = 40
alignment = 1

[node name="PlayerArea" type="VBoxContainer" parent="TeamAreas"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2
theme_override_constants/separation = 80
alignment = 0

[node name="PlayerLineup" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
mouse_filter = 2
theme_override_constants/separation = 0
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/PlayerArea/PlayerLineup"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="BenchAndInventory" type="HBoxContainer" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2
theme_override_constants/separation = 0
alignment = 1

[node name="PlayerBench" type="HBoxContainer" parent="TeamAreas/PlayerArea/BenchAndInventory"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2
theme_override_constants/separation = 0
alignment = 1

[node name="BenchSlot0" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="BenchSlot1" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="BenchSlot2" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="BenchSlot3" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="BenchSlot4" type="PanelContainer" parent="TeamAreas/PlayerArea/BenchAndInventory/PlayerBench"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="DummyDiscardArea" type="Control" parent="TeamAreas/PlayerArea"]
custom_minimum_size = Vector2(0, 80)
layout_mode = 2
mouse_filter = 2

[node name="Control3" type="Control" parent="TeamAreas/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2



[node name="EnemyArea" type="VBoxContainer" parent="TeamAreas"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2
theme_override_constants/separation = 80
alignment = 0

[node name="EnemyLineupContainer" type="HBoxContainer" parent="TeamAreas/EnemyArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
mouse_filter = 2
theme_override_constants/separation = 0
alignment = 1

[node name="LineupSlot0" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineupContainer"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot1" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineupContainer"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot2" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineupContainer"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot3" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineupContainer"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="LineupSlot4" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyLineupContainer"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="EnemyBenchComposite" type="VBoxContainer" parent="TeamAreas/EnemyArea"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 0
mouse_filter = 2
mouse_filter = 2
theme_override_constants/separation = 10
alignment = 0

[node name="EnemyTrinketBar" type="HBoxContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 0
alignment = 1

[node name="TrinketSlot0" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/EnemyTrinketBar"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="TrinketSlot1" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/EnemyTrinketBar"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="TrinketSlot2" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/EnemyTrinketBar"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="TrinketSlot3" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/EnemyTrinketBar"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1

[node name="TrinketSlot4" type="PanelContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/EnemyTrinketBar"]
custom_minimum_size = Vector2(192, 192)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1


[node name="ButtonMargins" type="MarginContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/margin_left = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="DiscardArea" type="HBoxContainer" parent="TeamAreas/EnemyArea/EnemyBenchComposite/ButtonMargins"]
custom_minimum_size = Vector2(0, 80)
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
mouse_filter = 2
theme_override_constants/separation = 10
alignment = 1

[node name="DiscardPileButton" type="Button" parent="TeamAreas/EnemyArea/EnemyBenchComposite/ButtonMargins/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
mouse_filter = 1
theme_override_colors/font_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 0
theme_override_fonts/font = ExtResource("6_label_font")
theme_override_font_sizes/font_size = 12
text = "Discard Pile (0)"

[node name="EndTurnButton" type="Button" parent="TeamAreas/EnemyArea/EnemyBenchComposite/ButtonMargins/DiscardArea"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.9, 0.4, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
theme_override_fonts/font = ExtResource("6_label_font")
theme_override_font_sizes/font_size = 14
text = "End Turn"



[node name="EnemyDummyDiscard" type="Control" parent="TeamAreas/EnemyArea"]
custom_minimum_size = Vector2(0, 80)
layout_mode = 2
mouse_filter = 2

[node name="Control3" type="Control" parent="TeamAreas/EnemyArea"]
layout_mode = 2
size_flags_vertical = 3
mouse_filter = 2

[node name="ModalLayer" type="CanvasLayer" parent="."]
unique_name_in_owner = true
layer = 128

[node name="TestEnvironmentManager" type="Control" parent="."]
script = ExtResource("5_testenv")
```

### [DiscardPileWindow.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/DiscardPileWindow.tscn)
```tscn
[gd_scene load_steps=2 format=3 uid="uid://c28k46w6p3h0"]

[ext_resource type="Script" path="res://scripts/DiscardPileWindow.gd" id="1_v38m6"]

[node name="DiscardPileWindow" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_v38m6")

[node name="PanelContainer" type="PanelContainer" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -500.0
offset_top = -350.0
offset_right = 500.0
offset_bottom = 350.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 1

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 15

[node name="TitleLabel" type="Label" parent="PanelContainer/VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"HeaderLabel"
theme_override_font_sizes/font_size = 28
text = "Discard Pile"
horizontal_alignment = 1

[node name="ScrollContainer" type="ScrollContainer" parent="PanelContainer/VBoxContainer"]
layout_mode = 2
mouse_filter = 2
size_flags_vertical = 3

[node name="DiscardGrid" type="GridContainer" parent="PanelContainer/VBoxContainer/ScrollContainer"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 0
theme_override_constants/v_separation = 0
columns = 5
```

### [InventoryWindow.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/InventoryWindow.tscn)
```tscn
# [Implementation Model: Shows exactly how PhysicsTierContainers are nested within PanelContainers]
```

### [PhysicsTierContainer.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/PhysicsTierContainer.tscn)
```tscn
# [Shared Component for physics simulation]
```

### [PhysicsGachaBall.tscn](file:///Users/danhh/Desktop/Flashcard%20Heroes/scenes/PhysicsGachaBall.tscn)
```tscn
# [Shared Component for gachaball rigidbodies]
```

---

## 2. Visual Effects (VFX)

### [ui_open_reveal.gdshader](file:///Users/danhh/Desktop/Flashcard%20Heroes/assets/shaders/ui_open_reveal.gdshader)
```glsl
# [Full shader source for the wipe/reveal effect]
```
