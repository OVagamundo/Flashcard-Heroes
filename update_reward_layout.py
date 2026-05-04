import re

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scenes/Reward.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# Update VBoxContainer
vbox_old = '''[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 40
alignment = 1'''

vbox_new = '''[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -600.0
offset_top = 5.0
offset_right = 600.0
offset_bottom = 540.0
grow_horizontal = 2
theme_override_constants/separation = 20
alignment = 0'''

content = content.replace(vbox_old, vbox_new)

# Remove TitleLabel
title_lbl = '''[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
theme_override_colors/font_color = Color(0.98, 0.96, 0.92, 1)
theme_override_colors/font_outline_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 4
text = "Choose Your Reward"
horizontal_alignment = 1

'''
content = content.replace(title_lbl, '')

# Extract LeaveButton from VBoxContainer and place it at the end
leave_old = '''[node name="LeaveButton" type="Button" parent="VBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(300, 70)
layout_mode = 2
size_flags_horizontal = 4
theme_override_colors/font_color = Color(0.98, 0.96, 0.92, 1)
theme_override_colors/font_outline_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 3
text = "Leave"'''

leave_new = '''[node name="LeaveButton" type="Button" parent="."]
unique_name_in_owner = true
custom_minimum_size = Vector2(300, 70)
layout_mode = 1
anchors_preset = 6
anchor_left = 1.0
anchor_top = 0.5
anchor_right = 1.0
anchor_bottom = 0.5
offset_left = -320.0
offset_top = 152.0
offset_right = -20.0
offset_bottom = 222.0
grow_horizontal = 0
grow_vertical = 2
theme_override_colors/font_color = Color(0.98, 0.96, 0.92, 1)
theme_override_colors/font_outline_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 3
text = "Leave"'''

content = content.replace(leave_old, leave_new)

# Update buttons
content = content.replace('text = "1 Token"', 'text = "Tier 1 prizes\\n(1 Token)"')
content = content.replace('text = "2 Tokens"', 'text = "Tier 2 prizes\\n(2 Tokens)"')
content = content.replace('text = "3 Tokens"', 'text = "Tier 3 prizes\\n(3 Tokens)"')

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scenes/Reward.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

# Now update Reward.gd buttons text and Leave auto collect
with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Reward.gd', 'r', encoding='utf-8') as f:
    gd_content = f.read()

gd_old_text = '''\ttier1_draw_button.text = "%d Token%s" % [COST_TIER1, "" if COST_TIER1 == 1 else "s"]
\ttier2_draw_button.text = "%d Token%s" % [COST_TIER2, "" if COST_TIER2 == 1 else "s"]
\ttier3_draw_button.text = "%d Token%s" % [COST_TIER3, "" if COST_TIER3 == 1 else "s"]'''

gd_new_text = '''\ttier1_draw_button.text = "Tier 1 prizes\\n(%d Token%s)" % [COST_TIER1, "" if COST_TIER1 == 1 else "s"]
\ttier2_draw_button.text = "Tier 2 prizes\\n(%d Token%s)" % [COST_TIER2, "" if COST_TIER2 == 1 else "s"]
\ttier3_draw_button.text = "Tier 3 prizes\\n(%d Token%s)" % [COST_TIER3, "" if COST_TIER3 == 1 else "s"]'''

gd_content = gd_content.replace(gd_old_text, gd_new_text)

gd_content = gd_content.replace('title_label.text = tr("ui.choose_reward")', '')

with open('C:/Users/danhh/Desktop/Flashcard-Heroes/scripts/Reward.gd', 'w', encoding='utf-8') as f:
    f.write(gd_content)

print('Updated Reward layout and labels.')
