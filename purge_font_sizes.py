import os
import re

# Regex to match theme_override_font_sizes/font_size = X
size_pattern = re.compile(r'^[ \t]*theme_override_font_sizes/(normal_)?font_size = \d+$', re.MULTILINE)

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = size_pattern.sub('', content)

    # Clean up multi-newlines
    new_content = re.sub(r'\n{3,}', '\n\n', new_content)

    if content != new_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Purged sizes in: {file_path}")

def walk_and_process(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.tscn'):
                process_file(os.path.join(root, file))

if __name__ == "__main__":
    walk_and_process(".")
    print("Purge complete.")
