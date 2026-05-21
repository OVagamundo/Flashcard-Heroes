import os

scratch_dir = "scratch"
js_files = [f for f in os.listdir(scratch_dir) if f.endswith(".js")]

for js_file in js_files:
    path = os.path.join(scratch_dir, js_file)
    print(f"=== {js_file} ===")
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        for term in ["item-info", "download", "shared", "svc", "info"]:
            count = content.lower().count(term)
            if count > 0:
                print(f"  '{term}': {count} occurrences")
