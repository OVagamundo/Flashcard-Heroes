#!/usr/bin/env python3
import os
import argparse
from pathlib import Path

# Allowed file extensions for conversion
ALLOWED_EXTENSIONS = {'.gd', '.tscn', '.tres', '.godot', '.md'}

def get_syntax_type(file_path: Path) -> str:
    """Determine syntax highlighting type based on file extension."""
    if file_path.suffix == '.gd':
        return 'gdscript'
    if file_path.suffix in ['.tres', '.tscn', '.godot']:
        return 'ini'
    if file_path.suffix == '.md':
        return 'markdown'
    return 'text'

def convert_file_to_md(file_path: Path, output_dir: Path):
    """Convert a single file to markdown and save it to the output directory."""
    syntax_type = get_syntax_type(file_path)
    output_file_path = output_dir / (file_path.name + ".md")

    with open(file_path, 'r', encoding='utf-8') as f_in:
        content = f_in.read()

    with open(output_file_path, 'w', encoding='utf-8') as f_out:
        f_out.write(f"# {file_path.name}\n\n")
        f_out.write(f"``` {syntax_type}\n{content}\n```\n")
    print(f"Converted {file_path} to {output_file_path}")

def main():
    """Main function to convert specified Godot files to markdown with syntax highlighting."""
    parser = argparse.ArgumentParser(description="Convert specified Godot files to markdown with syntax highlighting.")
    parser.add_argument('files', nargs='+', type=Path, help='List of file paths to convert.')
    parser.add_argument('--output_dir', type=Path, default=Path('updates'), help='The output directory for markdown files. Defaults to "updates".')
    args = parser.parse_args()

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    for file_path_str in args.files:
        file_path = Path(file_path_str)
        if not file_path.exists():
            print(f"Skipping {file_path}: File not found.")
            continue
        if file_path.suffix in ALLOWED_EXTENSIONS:
            convert_file_to_md(file_path, output_dir)
        else:
            print(f"Skipping {file_path}: Not an allowed file extension.")

if __name__ == "__main__":
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)
    main()
