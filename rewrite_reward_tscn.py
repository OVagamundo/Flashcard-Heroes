import re

rest_site_path = 'C:/Users/danhh/Desktop/Flashcard-Heroes/scenes/RestSite.tscn'
reward_path = 'C:/Users/danhh/Desktop/Flashcard-Heroes/scenes/Reward.tscn'

with open(rest_site_path, 'r', encoding='utf-8') as f:
    rest_site_content = f.read()

with open(reward_path, 'r', encoding='utf-8') as f:
    reward_content = f.read()

machines_match = re.search(r'(\[node name="MachinesArea".*?)(?=\[node name="SlotsRow")', rest_site_content, re.DOTALL)
if not machines_match:
    print('MachinesArea not found')

machines_str = machines_match.group(1)

machines_str = machines_str.replace('text = "HP"', 'text = "Tier 1"')
machines_str = machines_str.replace('text = "PWR"', 'text = "Tier 2"')
machines_str = machines_str.replace('text = "HP+PWR"', 'text = "Tier 3"')

slots_row_match = re.search(r'(\[node name="SlotsRow".*?)(?=\[node name="LeaveButton")', rest_site_content, re.DOTALL)
slots_row_str = slots_row_match.group(1)
slots_row_str = re.sub(r'\[node name="HeroSlot".*?\]\n.*?\n.*?\n', '', slots_row_str, flags=re.DOTALL)
slots_row_str = slots_row_str + '''[node name="PrizeSlot4" parent="SlotsRow/PrizeLineup" instance=ExtResource("2_slot_view")]
custom_minimum_size = Vector2(192, 192)

'''

slots_row_str = slots_row_str.replace('ExtResource("4_slotview")', 'ExtResource("2_slot_view")')

leave_btn_str = '''[node name="LeaveButton" type="Button" parent="VBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(300, 70)
layout_mode = 2
size_flags_horizontal = 4
theme_override_colors/font_color = Color(0.98, 0.96, 0.92, 1)
theme_override_colors/font_outline_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 3
text = "Leave"

[node name="EffectsLayer" type="CanvasLayer" parent="." groups=["effects_layer"]]
layer = 90
'''

vbox_content = '''[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
theme_override_colors/font_color = Color(0.98, 0.96, 0.92, 1)
theme_override_colors/font_outline_color = Color(0.15, 0.17, 0.22, 1)
theme_override_constants/outline_size = 4
text = "Choose Your Reward"
horizontal_alignment = 1

''' + machines_str + slots_row_str + leave_btn_str

new_reward_content = re.sub(r'\[node name="TitleLabel".*', vbox_content, reward_content, flags=re.DOTALL)

styles_match = re.search(r'(\[sub_resource type="StyleBoxFlat".*?\]\n.*?)(?=\[node)', rest_site_content, re.DOTALL)
if styles_match:
    styles_str = styles_match.group(1)
    first_node_idx = new_reward_content.find('[node')
    new_reward_content = new_reward_content[:first_node_idx] + styles_str + new_reward_content[first_node_idx:]

with open(reward_path, 'w', encoding='utf-8') as f:
    f.write(new_reward_content)

print('Reward.tscn updated successfully.')
