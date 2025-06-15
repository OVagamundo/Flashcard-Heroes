#!/usr/bin/env python3
import os
import os.path
from pathlib import Path

def main():
    # Ensure Code directory exists
    code_dir = Path("Code")
    code_dir.mkdir(exist_ok=True)
    
    # Get all .gd files from scripts directory
    script_files = list(Path("scripts").glob("**/*.gd"))
    print(f"Found {len(script_files)} .gd files to process")
    
    for script_path in script_files:
        # Read the original file
        try:
            with open(script_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Create markdown content
            md_content = f"<!-- Original: {script_path.name} -->\n\n```gdscript\n"
            md_content += content
            md_content += "\n```"
            
            # Write to markdown file
            output_path = code_dir / f"{script_path.name}.md"
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(md_content)
            
            print(f"Created: {output_path}")
            
        except Exception as e:
            print(f"Error processing {script_path}: {e}")
    
    print("\nAll .gd files have been converted to markdown format in the Code directory.")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")  # Change to project root
    main()
