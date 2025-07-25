<!-- Original: scenes/Reward.tscn -->

```ini
[gd_scene load_steps=3 format=3 uid="uid://dvjmlqxnk7wqd"]

[ext_resource type="Script" uid="uid://b3av4xdg8f56s" path="res://scripts/Reward.gd" id="1_reward_script"]
[ext_resource type="PackedScene" uid="uid://c5w2h4x3y100" path="res://scenes/SlotView.tscn" id="2_slot_view"]

[node name="Reward" type="VBoxContainer"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 40
alignment = 1
script = ExtResource("1_reward_script")

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 2
theme_override_font_sizes/font_size = 48
text = "Choose Your Reward"
horizontal_alignment = 1

[node name="RewardChoicesContainer" type="HBoxContainer" parent="."]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 20
alignment = 1

[node name="RewardSlot0" parent="RewardChoicesContainer" instance=ExtResource("2_slot_view")]
custom_minimum_size = Vector2(120, 150)
layout_mode = 2

[node name="RewardSlot1" parent="RewardChoicesContainer" instance=ExtResource("2_slot_view")]
custom_minimum_size = Vector2(120, 150)
layout_mode = 2

[node name="RewardSlot2" parent="RewardChoicesContainer" instance=ExtResource("2_slot_view")]
custom_minimum_size = Vector2(120, 150)
layout_mode = 2

[node name="ActionButtonsContainer" type="HBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 30
alignment = 1

[node name="ConfirmSelectionButton" type="Button" parent="ActionButtonsContainer"]
unique_name_in_owner = true
layout_mode = 2
disabled = true
text = "Confirm Selection"

[node name="TakeGoldButton" type="Button" parent="ActionButtonsContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Take Gold Instead"

[node name="BackToPathButton" type="Button" parent="ActionButtonsContainer"]
unique_name_in_owner = true
layout_mode = 2
text = "Back to the Path"
visible = false

```