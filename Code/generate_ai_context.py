import os
import re
from pathlib import Path

def generate_tree(dir_path, prefix=""):
    """Generates a text representation of the directory tree."""
    tree_str = ""
    path = Path(dir_path)
    if not path.exists():
        return ""
        
    entries = sorted(list(path.iterdir()), key=lambda x: (not x.is_dir(), x.name))
    for i, entry in enumerate(entries):
        connector = "├── " if i < len(entries) - 1 else "└── "
        tree_str += prefix + connector + entry.name + "\n"
        if entry.is_dir():
            extension = "│   " if i < len(entries) - 1 else "    "
            tree_str += generate_tree(entry, prefix + extension)
    return tree_str

def get_autoloads():
    """Extracts autoloads from project.godot"""
    autoloads = []
    project_path = Path("project.godot")
    if not project_path.exists():
        return autoloads
        
    in_autoload = False
    with open(project_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('[autoload]'):
                in_autoload = True
                continue
            if in_autoload and line.startswith('['):
                break
            if in_autoload and "=" in line:
                autoloads.append(line)
    return autoloads

def extract_scene_scripts():
    """Parses .tscn files to map scripts to nodes."""
    scene_mappings = []
    
    node_re = re.compile(r'\[node name="([^"]+)"')
    script_assign_re = re.compile(r'script\s*=\s*ExtResource\("([^"]+)"\)')
    
    for scene_path in Path("scenes").rglob("*.tscn"):
        rel_path = str(scene_path)
        resources = {}
        current_node = "Root"
        node_scripts = []
        
        with open(scene_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                
                # Check for ext_resource
                if line.startswith("[ext_resource"):
                    path_match = re.search(r'path="res://([^"]+)"', line)
                    id_match = re.search(r'id="([^"]+)"', line)
                    if path_match and id_match:
                        path_val = path_match.group(1)
                        if path_val.endswith(".gd"):
                            resources[id_match.group(1)] = path_val
                    continue
                
                # Check for node
                node_match = node_re.match(line)
                if node_match:
                    current_node = node_match.group(1)
                    continue
                
                # Check for script assignment
                script_match = script_assign_re.match(line)
                if script_match:
                    res_id = script_match.group(1)
                    if res_id in resources:
                        node_scripts.append(f"  - Node `{current_node}` -> `{resources[res_id]}`")
        
        if node_scripts:
            scene_mappings.append(f"### {rel_path}\n" + "\n".join(node_scripts))
            
    return scene_mappings

def main():
    # Change to project root (parent of the Code directory)
    os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")
    
    code_dir = Path("Code")
    code_dir.mkdir(exist_ok=True)
    output_path = code_dir / "ai_project_context.md"
    
    with open(output_path, 'w', encoding='utf-8') as out:
        out.write("# Flashcard Heroes - AI Project Context\n\n")
        out.write("This file is an auto-generated context summary designed to give an AI a comprehensive understanding of the game's architecture, file structure, and source code.\n\n")
        
        # 1. Autoloads
        out.write("## 1. Global Singletons (Autoloads)\n\n")
        out.write("These are the global singletons defined in `project.godot`. They manage global state and systems.\n\n")
        out.write("```ini\n")
        for al in get_autoloads():
            out.write(al + "\n")
        out.write("```\n\n")
        
        # 2. Directory Tree
        out.write("## 2. Directory Structure\n\n")
        out.write("### `scripts/`\n")
        out.write("```text\n")
        out.write("scripts/\n")
        out.write(generate_tree("scripts"))
        out.write("```\n\n")
        
        out.write("### `scenes/`\n")
        out.write("```text\n")
        out.write("scenes/\n")
        out.write(generate_tree("scenes"))
        out.write("```\n\n")
        
        # 3. Scene-Script Mapping
        out.write("## 3. Scene-to-Script Linkage\n\n")
        out.write("This section shows which `.gd` scripts are attached to nodes in the `.tscn` scenes. This avoids dumping noisy visual data while preserving structural logic.\n\n")
        scene_mappings = extract_scene_scripts()
        if scene_mappings:
            for sm in scene_mappings:
                out.write(sm + "\n\n")
        else:
            out.write("*No script attachments found or scenes folder missing.*\n\n")
            
        # 4. Source Code
        out.write("## 4. Source Code (`.gd` files)\n\n")
        out.write("All GDScript source code files are included below.\n\n")
        
        all_gd_files = []
        for p in Path.cwd().rglob("*.gd"):
            if "addons" in p.parts or ".godot" in p.parts or "brain" in p.parts or "scratch" in p.parts or "tools_and_archive" in p.parts:
                continue
            all_gd_files.append(p)
            
        all_gd_files.sort(key=lambda x: str(x).lower())
        
        for p in all_gd_files:
            try:
                rel_path = p.relative_to(Path.cwd())
                with open(p, 'r', encoding='utf-8') as f:
                    content = f.read()
                out.write(f"### File: `{rel_path}`\n")
                out.write("```gdscript\n")
                out.write(content)
                if not content.endswith("\n"):
                    out.write("\n")
                out.write("```\n\n")
            except Exception as e:
                print(f"Error reading {p}: {e}")
                
    print(f"Generated AI context successfully at {output_path.absolute()}")

if __name__ == "__main__":
    main()
