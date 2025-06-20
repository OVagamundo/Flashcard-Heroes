#!/usr/bin/env python3
import os
import os.path
from pathlib import Path

def get_file_list():
    """Get list of files to process with their relative paths and syntax highlighting type."""
    files = []
    
    # GDScript files
    for path in Path("scripts").glob("**/*.gd"):
        files.append((path, "gdscript"))
    
    # Resource files
    for path in Path("resources").glob("**/*.tres"):
        files.append((path, "ini"))
    
    # Scene files
    for path in Path("scenes").glob("**/*.tscn"):
        files.append((path, "ini"))
    
    # Project file
    project_file = Path("project.godot")
    if project_file.exists():
        files.append((project_file, "ini"))
    
    return files

def main():
    # Ensure Code directory exists
    code_dir = Path("Code")
    code_dir.mkdir(exist_ok=True)
    
    # Get all files to process
    files = get_file_list()
    print(f"Found {len(files)} files to process")
    
    for file_path, syntax in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Create markdown content with appropriate syntax highlighting
            md_content = f"<!-- Original: {file_path} -->\n\n```{syntax}\n"
            md_content += content
            md_content += "\n```"
            
            # Create output filename using the file's name and parent directory
            rel_path = file_path.relative_to(Path.cwd()) if file_path.is_relative_to(Path.cwd()) else file_path
            output_name = str(rel_path).replace(os.path.sep, '_')
            output_path = code_dir / f"{output_name}.md"
            
            # Create subdirectories if they don't exist
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(md_content)
            
            print(f"Created: {output_path}")
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
    
    print("\nAll files have been converted to markdown format in the Code directory.")

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")  # Change to project root
    main()
