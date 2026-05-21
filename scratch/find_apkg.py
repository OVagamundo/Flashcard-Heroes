import os

workspace = r"c:\Users\danhh\Desktop\Flashcard-Heroes"
found = []
for root, dirs, files in os.walk(workspace):
    for file in files:
        if file.endswith(".apkg"):
            found.append(os.path.join(root, file))

if found:
    print("Found APKG files:")
    for path in found:
        print(f"  {path}")
else:
    print("No APKG files found in workspace.")
