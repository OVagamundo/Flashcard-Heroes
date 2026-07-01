import os
import re

def grep_process_mode(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.gd', '.tscn')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r') as f:
                        content = f.read()
                        if 'process_mode' in content:
                            print(f"Found in {filepath}:")
                            lines = content.split('\n')
                            for i, line in enumerate(lines):
                                if 'process_mode' in line:
                                    print(f"  Line {i+1}: {line.strip()}")
                except Exception as e:
                    pass

grep_process_mode('scripts')
grep_process_mode('scenes')
