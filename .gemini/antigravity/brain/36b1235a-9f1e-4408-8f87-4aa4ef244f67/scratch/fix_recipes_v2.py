import os
import re

directory = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\recipes'
for filename in os.listdir(directory):
    if filename.endswith('.tres'):
        path = os.path.join(directory, filename)
        try:
            with open(path, 'r') as f:
                content = f.read()
            
            if 'is_self_merge = true' in content:
                # 1. Ensure result_id matches ingredient_a_id (Tier preservation)
                match_a = re.search(r'ingredient_a_id = &"([^"]+)"', content)
                if match_a:
                    ing_a = match_a.group(1)
                    content = re.sub(r'result_id = &"[^"]+"', f'result_id = \u0026"{ing_a}"', content)
                
                # 2. Add or update result_level to 2 (Default Level Up)
                if 'result_level' in content:
                    content = re.sub(r'result_level = \d+', 'result_level = 2', content)
                else:
                    # Insert before merge_type or at the end of resource block
                    content = content.replace('merge_type =', 'result_level = 2\nmerge_type =')
                
                with open(path, 'w') as f:
                    f.write(content)
                print(f"Updated {filename}: result_id={ing_a}, result_level=2")
        except Exception as e:
            print(f"Error processing {filename}: {e}")
