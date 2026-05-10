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
                # Find ingredient_a_id
                match_a = re.search(r'ingredient_a_id = &"([^"]+)"', content)
                if match_a:
                    ing_a = match_a.group(1)
                    # Replace result_id with ingredient_a_id
                    new_content = re.sub(r'result_id = &"[^"]+"', f'result_id = \u0026"{ing_a}"', content)
                    if new_content != content:
                        with open(path, 'w') as f:
                            f.write(new_content)
                        print(f"Updated {filename}: set result_id to {ing_a}")
        except Exception as e:
            print(f"Error processing {filename}: {e}")
