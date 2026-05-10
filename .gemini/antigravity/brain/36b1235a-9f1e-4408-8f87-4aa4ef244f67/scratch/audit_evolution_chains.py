import os
import re

# Paths
units_dir = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\units'
recipes_dir = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\recipes'

def get_file_content(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file_content(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

# 1. Map Unit IDs to their Tier and Level
unit_data = {}
for filename in os.listdir(units_dir):
    if filename.endswith('.tres'):
        path = os.path.join(units_dir, filename)
        content = get_file_content(path)
        
        match_id = re.search(r'id = &"([^"]+)"', content)
        if match_id:
            unit_id = match_id.group(1)
            tier_match = re.search(r'tier = (\d+)', content)
            level_match = re.search(r'level = (\d+)', content)
            
            unit_data[unit_id] = {
                'path': path,
                'tier': int(tier_match.group(1)) if tier_match else 0,
                'level': int(level_match.group(1)) if level_match else 1
            }

# 2. Process Recipes to determine correct Tiers and Levels
# We want to iterate multiple times to handle chains (Lv1 -> Lv2 -> Lv3)
changed = True
while changed:
    changed = False
    for filename in os.listdir(recipes_dir):
        if filename.endswith('.tres'):
            path = os.path.join(recipes_dir, filename)
            content = get_file_content(path)
            
            if 'is_self_merge = true' in content:
                match_a = re.search(r'ingredient_a_id = &"([^"]+)"', content)
                match_res = re.search(r'result_id = &"([^"]+)"', content)
                
                if match_a and match_res:
                    ing_a = match_a.group(1)
                    res = match_res.group(1)
                    
                    if ing_a in unit_data and res in unit_data:
                        parent = unit_data[ing_a]
                        child = unit_data[res]
                        
                        target_tier = parent['tier']
                        target_level = parent['level'] + 1
                        
                        if child['tier'] != target_tier or child['level'] != target_level:
                            print(f"Fixing {res}: Tier {child['tier']}->{target_tier}, Level {child['level']}->{target_level} (Parent: {ing_a})")
                            child['tier'] = target_tier
                            child['level'] = target_level
                            
                            # Update the file
                            unit_content = get_file_content(child['path'])
                            unit_content = re.sub(r'tier = \d+', f'tier = {target_tier}', unit_content)
                            if 'level = ' in unit_content:
                                unit_content = re.sub(r'level = \d+', f'level = {target_level}', unit_content)
                            else:
                                unit_content = unit_content.replace(f'tier = {target_tier}', f'tier = {target_tier}\nlevel = {target_level}')
                            
                            write_file_content(child['path'], unit_content)
                            changed = True

print("Audit and update of unit tiers/levels complete.")
