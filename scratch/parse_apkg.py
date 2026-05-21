import os
import sqlite3
import zipfile
import shutil
import json

def main():
    apkg_candidates = [
        "c:/Users/danhh/Desktop/Flashcard-Heroes/docs/Ankidecks/Korean_Hangul__Pronunciation_Rules_by_Soi.apkg",
        "c:/Users/danhh/Desktop/Flashcard-Heroes/Korean_Hangul_&_Pronunciation_Rules.apkg",
        "c:/Users/danhh/Desktop/Flashcard-Heroes/scratch/deck.apkg",
        "c:/Users/danhh/Desktop/Flashcard-Heroes/deck.apkg"
    ]
    
    apkg_path = None
    for p in apkg_candidates:
        if os.path.exists(p):
            apkg_path = p
            break
            
    if not apkg_path:
        # Check all files in workspace root
        for file in os.listdir("c:/Users/danhh/Desktop/Flashcard-Heroes"):
            if file.endswith(".apkg"):
                apkg_path = os.path.join("c:/Users/danhh/Desktop/Flashcard-Heroes", file)
                break
                
    if not apkg_path:
        print("ERROR: No .apkg file found in workspace. Please download it from https://ankiweb.net/shared/info/2092196508 and place it in the project root.")
        return
        
    print(f"Found APKG file: {apkg_path}")
    
    # Extract
    temp_dir = "scratch/temp_extract"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)
    
    with zipfile.ZipFile(apkg_path, 'r') as z:
        z.extractall(temp_dir)
    print(f"Extracted to {temp_dir}")
    
    # Find database
    db_file = None
    for f in ["collection.anki21", "collection.anki2"]:
        p = os.path.join(temp_dir, f)
        if os.path.exists(p):
            db_file = p
            break
            
    if not db_file:
        print("ERROR: Could not find collection.anki2 or collection.anki21 in the APKG zip.")
        return
        
    print(f"Opening SQLite database: {db_file}")
    
    conn = sqlite3.connect(db_file)
    cursor = conn.cursor()
    
    # List tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [r[0] for r in cursor.fetchall()]
    print(f"Tables in db: {tables}")
    
    # Load models
    models_dict = {}
    if "col" in tables:
        cursor.execute("SELECT models FROM col")
        row = cursor.fetchone()
        if row and row[0]:
            try:
                models_data = json.loads(row[0])
                for mid_str, m in models_data.items():
                    mid = int(mid_str)
                    model_name = m.get('name', 'Unknown')
                    fields = [fld.get('name') for fld in m.get('flds', [])]
                    models_dict[mid] = {
                        'name': model_name,
                        'fields': fields
                    }
                    print(f"Model ID {mid} ({model_name}): {fields}")
            except Exception as e:
                print(f"Error parsing models JSON: {e}")
                
    # If col does not contain models (newer versions of Anki might store it differently, e.g. separate tables in sqlite or serialized),
    # let's see if there is an 'notetypes' table (Anki >= 2.1.20+ often has it or not)
    if not models_dict and "notetypes" in tables:
        # Some newer versions of Anki have a notetypes table
        cursor.execute("SELECT id, name, config FROM notetypes")
        for row in cursor.fetchall():
            mid = row[0]
            name = row[1]
            # fields are stored in another table 'fields'
            cursor.execute("SELECT name FROM fields WHERE ntid = ? ORDER BY ord", (mid,))
            fields = [r[0] for r in cursor.fetchall()]
            models_dict[mid] = {
                'name': name,
                'fields': fields
            }
            print(f"Model ID {mid} ({name}): {fields}")
            
    # Read notes
    if "notes" in tables:
        cursor.execute("SELECT id, mid, flds, tags FROM notes")
        notes_rows = cursor.fetchall()
        print(f"\nTotal notes found: {len(notes_rows)}")
        
        parsed_notes = []
        for r in notes_rows:
            note_id = r[0]
            mid = r[1]
            flds_raw = r[2]
            tags = r[3]
            
            flds = flds_raw.split('\x1f')
            
            model_info = models_dict.get(mid, {'name': 'Unknown', 'fields': []})
            fields_names = model_info['fields']
            
            # Map fields to values
            note_dict = {}
            for idx, val in enumerate(flds):
                name = fields_names[idx] if idx < len(fields_names) else f"field_{idx}"
                note_dict[name] = val
                
            parsed_notes.append({
                'id': note_id,
                'model': model_info['name'],
                'fields': note_dict,
                'tags': tags
            })
            
        # Write to JSON for inspection
        output_json = "scratch/extracted_notes.json"
        with open(output_json, "w", encoding="utf-8") as out:
            json.dump(parsed_notes, out, indent=4, ensure_ascii=False)
        print(f"Saved {len(parsed_notes)} notes to {output_json}")
        
    conn.close()
    
if __name__ == "__main__":
    main()
