import os

def update_paths_in_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        new_content = content.replace('"res://assets/ui/', '"res://assets/Realistic/ui/')
        new_content = new_content.replace("'res://assets/ui/", "'res://assets/Realistic/ui/")
        new_content = new_content.replace('"res://assets/sprites/', '"res://assets/Realistic/sprites/')
        new_content = new_content.replace("'res://assets/sprites/", "'res://assets/Realistic/sprites/")

        if content != new_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed broken paths in: {file_path}")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")

def main():
    root_dir = r"c:\Users\danhh\Desktop\Flashcard-Heroes"
    # Directories to skip
    skip_dirs = {'.git', '.godot', '.gemini', 'export_presets.cfg', '.windsurf', '.agent'}
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Don't go into hidden dirs
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        
        for filename in filenames:
            if filename.endswith(".tscn") or filename.endswith(".tres") or filename.endswith(".gd"):
                update_paths_in_file(os.path.join(dirpath, filename))

if __name__ == "__main__":
    main()
