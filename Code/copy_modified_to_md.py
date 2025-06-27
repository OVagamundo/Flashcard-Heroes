#!/usr/bin/env python3
import os
import subprocess
import argparse
from pathlib import Path

# Allowed file extensions for conversion
ALLOWED_EXTENSIONS = {'.gd', '.tscn', '.tres', '.godot'}

def get_syntax_type(file_path: Path) -> str:
    """Determine syntax highlighting type based on file extension."""
    if file_path.suffix == '.gd':
        return 'gdscript'
    if file_path.suffix in ['.tres', '.tscn', '.godot']:
        return 'ini'
    return 'text'

def get_changed_files(commit_before: str, commit_after: str) -> list[Path]:
    """Get a list of changed files between two git commits."""
    files = []
    try:
        command = ['git', 'diff', '--name-only', commit_before, commit_after]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            encoding='utf-8'
        )
        for line in result.stdout.strip().split('\n'):
            if line:
                file_path = Path(line.strip())
                # Filter by allowed extensions
                if file_path.suffix in ALLOWED_EXTENSIONS or file_path.name == 'project.godot':
                    files.append(file_path)
        return files
    except FileNotFoundError:
        print("Error: 'git' command not found. Is git installed and in your PATH?")
        return []
    except subprocess.CalledProcessError as e:
        print(f"Error executing git command: {e}")
        print(f"Are '{commit_before}' and '{commit_after}' valid commit references?")
        return []

def main():
    """Main function to convert changed files between commits to markdown."""
    parser = argparse.ArgumentParser(description="Convert changed files between git commits to markdown.")
    parser.add_argument('commit_before', help="The older commit hash or reference (e.g., HEAD~1).")
    parser.add_argument('commit_after', nargs='?', default='HEAD', help="The newer commit hash or reference (defaults to HEAD).")
    args = parser.parse_args()

    output_dir = Path("updates")
    output_dir.mkdir(exist_ok=True)

    files = get_changed_files(args.commit_before, args.commit_after)
    if not files:
        print(f"No changed files with allowed extensions found between {args.commit_before} and {args.commit_after}.")
        return

    print(f"Found {len(files)} changed files to process")

    for file_path in files:
        try:
            if not file_path.exists():
                print(f"Skipping {file_path}: File not found (it may have been deleted or renamed).")
                continue

            syntax = get_syntax_type(file_path)
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            md_content = f"<!-- Original: {file_path} -->\n\n```{syntax}\n"
            md_content += content
            md_content += "\n```"

            output_name = str(file_path).replace(os.path.sep, '_')
            output_path = output_dir / f"{output_name}.md"

            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(md_content)

            print(f"Created: {output_path}")

        except Exception as e:
            print(f"Error processing {file_path}: {e}")

    print(f"\nAll changed files have been converted to markdown format in the {output_dir} directory.")

if __name__ == "__main__":
    project_root = Path(__file__).parent.parent
    os.chdir(project_root)
    main()
