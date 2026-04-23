import os
import re

# Regex to match any theme_override_fonts/ property line, regardless of indentation
override_pattern = re.compile(r'^[ \t]*theme_override_fonts/[a-z_]+ = ExtResource\(.*\)[ \t]*$', re.MULTILINE)

# Regex to match any [ext_resource type="FontFile" ...] line
preload_pattern = re.compile(r'^\[ext_resource type="FontFile".*\]$', re.MULTILINE)

def process_file(file_path):
    # Skip the global theme itself
    if "game_theme.tres" in file_path:
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove all font overrides
    new_content = override_pattern.sub('', content)
    
    # Remove all font preloads
    new_content = preload_pattern.sub('', new_content)

    # Clean up multiple newlines that might result from stripping
    new_content = re.sub(r'\n{3,}', '\n\n', new_content)

    if content != new_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Cleaned: {file_path}")

def walk_and_process(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.tscn'):
                process_file(os.path.join(root, file))

if __name__ == "__main__":
    target_dir = "."
    walk_and_process(target_dir)
    print("Done cleaning all scenes.")
