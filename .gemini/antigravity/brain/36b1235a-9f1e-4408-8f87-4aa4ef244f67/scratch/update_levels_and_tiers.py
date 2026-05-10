import os
import re

# Paths to the directories
units_dir = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\units'
recipes_dir = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\recipes'

# 1. Identify all self-merge results
self_merge_results = set()

for filename in os.listdir(recipes_dir):
    if filename.endswith('.tres'):
        path = os.path.join(recipes_dir, filename)
        with open(path, 'r') as f:
            content = f.read()
        
        # Check if it's a self-merge
        if 'is_self_merge = true' in content:
            match = re.search(r'result_id = &"([^"]+)"', content)
            if match:
                self_merge_results.add(match.group(1))

print(f"Found {len(self_merge_results)} self-merge results: {self_merge_results}")

# 2. Update the unit definitions for these results
for filename in os.listdir(units_dir):
    if filename.endswith('.tres'):
        path = os.path.join(units_dir, filename)
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if the ID of this unit is in our self-merge results
        match_id = re.search(r'id = &"([^"]+)"', content)
        if match_id and match_id.group(1) in self_merge_results:
            print(f"Updating {filename} (id: {match_id.group(1)})...")
            
            # Set tier to 1
            content = re.sub(r'tier = \d+', 'tier = 1', content)
            
            # Set level to 2 (or add it if missing)
            if 'level = ' in content:
                content = re.sub(r'level = \d+', 'level = 2', content)
            else:
                # Insert level after tier
                content = content.replace('tier = 1', 'tier = 1\nlevel = 2')
            
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Successfully updated {filename}.")

print("Unit definitions update complete.")
