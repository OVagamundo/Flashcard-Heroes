import sys

def modify_main_tscn(file_path):
    with open(file_path, 'r') as f:
        lines = f.readlines()

    out_lines = []
    insert_str = """[node name="CombatControlsPanel" type="PanelContainer" parent="VBoxContainer/TopArea/HBoxContainer/RightStats"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 2
size_flags_vertical = 4

[node name="OuterVBox" type="VBoxContainer" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel"]
layout_mode = 2
alignment = 1

[node name="ControlsRow" type="HBoxContainer" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox"]
layout_mode = 2
theme_override_constants/separation = 6
alignment = 1

[node name="SpeedLabel" type="Label" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
layout_mode = 2
theme_override_colors/font_color = Color(0.7, 0.7, 0.7, 1)
theme_override_font_sizes/font_size = 24
text = "Speed:"

[node name="Speed1xBtn" type="Button" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(70, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "1x"

[node name="Speed2xBtn" type="Button" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(70, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "2x"

[node name="Speed4xBtn" type="Button" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(70, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "4x"

[node name="VSeparator" type="VSeparator" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
custom_minimum_size = Vector2(6, 0)
layout_mode = 2

[node name="StepButton" type="Button" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox/ControlsRow"]
unique_name_in_owner = true
custom_minimum_size = Vector2(160, 40)
layout_mode = 2
theme_override_font_sizes/font_size = 24
text = "Next Step ⏭"

[node name="StepDescLabel" type="Label" parent="VBoxContainer/TopArea/HBoxContainer/RightStats/CombatControlsPanel/OuterVBox"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.9, 0.85, 0.6, 1)
theme_override_font_sizes/font_size = 20
horizontal_alignment = 1

"""
    found = False
    for i, line in enumerate(lines):
        if line.startswith('[node name="PlayerTrinketBar"'):
            out_lines.append(insert_str)
            found = True
        out_lines.append(line)
        
    if not found:
        print("Could not find PlayerTrinketBar to insert before!")
        sys.exit(1)
        
    with open(file_path, 'w') as f:
        f.writelines(out_lines)
    print("Sucessfully modified Main.tscn.")

if __name__ == '__main__':
    modify_main_tscn(r'C:\Users\danhh\Desktop\Flashcard-Heroes\scenes\Main.tscn')
