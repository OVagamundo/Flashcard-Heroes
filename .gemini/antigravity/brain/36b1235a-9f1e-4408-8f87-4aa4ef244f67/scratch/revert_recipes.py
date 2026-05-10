import os
import re

# Dictionary of original mappings based on filename patterns
# We can use the filename itself to determine the original result_id
# Merge_Unit_A_A_to_A2.tres -> unit_t2_a
# Recipe_Tier2E.tres -> unit_t2_e

directory = r'c:\Users\danhh\Desktop\Flashcard-Heroes\resources\recipes'
for filename in os.listdir(directory):
    if filename.endswith('.tres'):
        path = os.path.join(directory, filename)
        try:
            with open(path, 'r') as f:
                content = f.read()
            
            # Extract target ID from filename (e.g., Merge_Unit_A_A_to_A2.tres -> A2 -> unit_t2_a)
            # This is a bit heuristic but should work for the provided file list
            match_res = re.search(r'to_([A-Z0-9]+)\.tres$', filename)
            if not match_res:
                 match_res = re.search(r'Recipe_(Tier[0-9][A-Z]+)\.tres$', filename)
            
            if match_res:
                target_code = match_res.group(1).lower()
                # Simple mapping: a2 -> unit_t2_a, t3b -> unit_t3_b
                # We need to be careful with Items vs Units.
                prefix = "unit" if "Unit" in filename or "Recipe" in filename else "item"
                
                # Format code: t2e -> t2_e, a2 -> t2_a (based on previous knowledge)
                if target_code == "a2": target_code = "t2_a"
                elif target_code == "b2": target_code = "t2_b"
                elif target_code == "c02": target_code = "t1_c" # Wait, C02?
                elif target_code == "d": target_code = "t2_d"
                elif target_code.startswith("tier"): target_code = target_code.replace("tier", "t")
                
                # Ensure underscore after tier
                if len(target_code) >= 3 and target_code[0] == 't' and target_code[2] != '_':
                    target_code = target_code[:2] + "_" + target_code[2:]
                
                new_result_id = f"{prefix}_{target_code}"
                
                # Revert result_id
                content = re.sub(r'result_id = &"[^"]+"', f'result_id = \u0026"{new_result_id}"', content)
                # Remove result_level
                content = re.sub(r'result_level = \d+\n', '', content)
                
                with open(path, 'w') as f:
                    f.write(content)
                print(f"Reverted {filename} to result_id={new_result_id}")
        except Exception as e:
            print(f"Error processing {filename}: {e}")
