import os
import re
import csv

PROJECT_ROOT = "/Users/danhh/Desktop/Flashcard Heroes"
LOCALIZATION_FILE = os.path.join(PROJECT_ROOT, "localization/game.csv")
DOCS_MD_FILE = os.path.join(PROJECT_ROOT, "docs/GameContentDocument.md")
DOCS_UNITS_CSV = os.path.join(PROJECT_ROOT, "docs/units.csv")
DOCS_ITEMS_CSV = os.path.join(PROJECT_ROOT, "docs/items.csv")
DOCS_TRINKETS_CSV = os.path.join(PROJECT_ROOT, "docs/trinkets.csv")
DOCS_STATUS_CSV = os.path.join(PROJECT_ROOT, "docs/status_effects.csv")

localization = {}
def load_localization():
    if not os.path.exists(LOCALIZATION_FILE):
        return
    with open(LOCALIZATION_FILE, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader)
        try:
            en_idx = headers.index("en")
        except ValueError:
            en_idx = 1
        for row in reader:
            if len(row) > en_idx:
                localization[row[0]] = row[en_idx]

def t(key):
    return localization.get(key, key)

def t_md(key):
    return localization.get(key, key).replace("\n", "<br>")

def parse_tres(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    ext_resources = {}
    for match in re.finditer(r'\[ext_resource .* path="res://([^"]+)" id="([^"]+)"\]', content):
        ext_resources[match.group(2)] = os.path.join(PROJECT_ROOT, match.group(1))

    data = {}
    id_match = re.search(r'^id\s*=\s*&?"([^"]+)"', content, re.MULTILINE)
    data["id"] = id_match.group(1) if id_match else ""

    name_match = re.search(r'^display_name_key\s*=\s*"([^"]+)"', content, re.MULTILINE)
    if not name_match: name_match = re.search(r'^name_key\s*=\s*"([^"]+)"', content, re.MULTILINE)
    
    data["name_key"] = name_match.group(1) if name_match else ""
    data["desc_key"] = ""
    
    desc_match = re.search(r'^description_key\s*=\s*"([^"]+)"', content, re.MULTILINE)
    if desc_match: data["desc_key"] = desc_match.group(1)

    tier_match = re.search(r'^tier\s*=\s*(\d+)', content, re.MULTILINE)
    data["tier"] = int(tier_match.group(1)) if tier_match else 0

    cost_match = re.search(r'^cost\s*=\s*(\d+)', content, re.MULTILINE)
    data["cost"] = int(cost_match.group(1)) if cost_match else 0

    hp_match = re.search(r'^base_hp\s*=\s*(\d+)', content, re.MULTILINE)
    data["hp"] = hp_match.group(1) if hp_match else "0"

    pwr_match = re.search(r'^base_pwr\s*=\s*(\d+)', content, re.MULTILINE)
    data["pwr"] = pwr_match.group(1) if pwr_match else "0"
    
    tags = []
    tags_match = re.search(r'^tags\s*=\s*Array\[StringName\]\(\[([^\]]*)\]\)', content, re.MULTILINE)
    if tags_match:
        tag_strs = re.findall(r'&?"([^"]+)"', tags_match.group(1))
        tags.extend(tag_strs)
    data["tags"] = tags
    
    mechanics = []
    dmg_match = re.search(r'"damage_type"\s*:\s*(\d+)', content)
    if dmg_match:
        dmg_map = {0: "Melee", 1: "Ranged", 2: "Magic", 3: "Burn", 4: "Spike"}
        dtype = dmg_map.get(int(dmg_match.group(1)), "Unknown")
        mechanics.append(f"[{dtype} Damage]")
    
    atk_match = re.search(r'"attack_type"\s*:\s*"([^"]+)"', content)
    if atk_match:
        mechanics.append(f"[{atk_match.group(1).title()} Attack]")
        
    tgt_match = re.search(r'^target_type\s*=\s*&?"([^"]+)"', content, re.MULTILINE)
    if tgt_match:
        mechanics.append(f"[Target: {tgt_match.group(1)}]")
        
    cond_match = re.search(r'"allowed_causes"\s*:\s*Array\[StringName\]\(\[&?"([^"]+)"\]\)', content)
    if cond_match:
        mechanics.append(f"[Trigger: {cond_match.group(1)}]")
        
    data["mechanics"] = mechanics

    abilities = []
    abil_match = re.search(r'^ability_definitions\s*=\s*Array\[Resource\]\(\[([^\]]*)\]\)', content, re.MULTILINE)
    if abil_match:
        refs = re.findall(r'ExtResource\("([^"]+)"\)', abil_match.group(1))
        for ref in refs:
            if ref in ext_resources and os.path.exists(ext_resources[ref]):
                abilities.append(parse_tres(ext_resources[ref]))
    
    single_abil = re.search(r'^ability\s*=\s*ExtResource\("([^"]+)"\)', content, re.MULTILINE)
    if single_abil:
        ref = single_abil.group(1)
        if ref in ext_resources and os.path.exists(ext_resources[ref]):
            abilities.append(parse_tres(ext_resources[ref]))
    
    data["abilities"] = abilities
    return data

def build_docs():
    load_localization()
    
    md = "# Game Content Document\n\n*This document is auto-generated from the game's resource files.*\n"
    sections = [
        ("Units (Tier 1)", "resources/units", lambda d: d.get("tier", 0) == 1 and not d.get("id","").startswith("boss") and not "enemy" in d.get("id","")),
        ("Units (Tier 2)", "resources/units", lambda d: d.get("tier", 0) == 2 and not d.get("id","").startswith("boss") and not "enemy" in d.get("id","")),
        ("Units (Tier 3)", "resources/units", lambda d: d.get("tier", 0) == 3 and not d.get("id","").startswith("boss") and not "enemy" in d.get("id","")),
        ("Heroes", "resources/units", lambda d: "hero" in d.get("id","") and not "enemy" in d.get("id","")),
        ("Enemies", "resources/units", lambda d: "boss" in d.get("id","") or "enemy" in d.get("id","") or "dust" in d.get("id","")),
        ("Items", "resources/items", lambda d: True),
        ("Trinkets", "resources/trinkets", lambda d: True)
    ]
    
    all_data = {"resources/units": [], "resources/items": [], "resources/trinkets": []}
    
    for title, folder, filt in sections:
        md += f"\n\n## {title}\n"
        folder_path = os.path.join(PROJECT_ROOT, folder)
        if not os.path.exists(folder_path): continue
        
        items = []
        for f in sorted(os.listdir(folder_path)):
            if f.endswith(".tres"):
                data = parse_tres(os.path.join(folder_path, f))
                if data not in all_data[folder]:
                    all_data[folder].append(data)
                if filt(data):
                    items.append(data)
        
        if not items:
            md += "*None found.*\n"
            continue
            
        md += "| ID | Name | Stats | Tags | Abilities |\n"
        md += "|---|---|---|---|---|\n"
        for item in items:
            stats = f"{item['hp']} HP / {item['pwr']} PWR"
            tag_str = ", ".join([t.replace("SOUL_", "") for t in item["tags"]])
            
            abils = []
            for a in item["abilities"]:
                aname = f"**{t_md(a['name_key'])}**"
                adesc = t_md(a['desc_key'])
                if a['mechanics']:
                    adesc += " " + " ".join(a['mechanics'])
                if adesc: aname += f": {adesc}"
                abils.append(aname)
            
            abil_str = "<br><br>".join(abils)
            md += f"| `{item['id']}` | **{t_md(item['name_key'])}**<br>_{t_md(item['desc_key'])}_ | {stats} | {tag_str} | {abil_str} |\n"
            
    with open(DOCS_MD_FILE, "w", encoding="utf-8") as f:
        f.write(md)

    def write_csv(filepath, data_list):
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["ID", "Name", "Description", "Tier", "Cost", "Base HP", "Base PWR", "Ability 1 Name", "Ability 1 Desc", "Ability 2 Name", "Ability 2 Desc", "Ability 3 Name", "Ability 3 Desc"])
            for item in data_list:
                row = [
                    item["id"],
                    t(item["name_key"]),
                    t(item["desc_key"]),
                    item.get("tier", ""),
                    item.get("cost", ""),
                    item.get("hp", ""),
                    item.get("pwr", "")
                ]
                for i in range(3):
                    if i < len(item["abilities"]):
                        row.append(t(item["abilities"][i]["name_key"]))
                        desc = t(item["abilities"][i]["desc_key"])
                        if item["abilities"][i]["mechanics"]:
                            desc += " " + " ".join(item["abilities"][i]["mechanics"])
                        row.append(desc)
                    else:
                        row.extend(["", ""])
                writer.writerow(row)
                
    write_csv(DOCS_UNITS_CSV, all_data["resources/units"])
    write_csv(DOCS_ITEMS_CSV, all_data["resources/items"])
    write_csv(DOCS_TRINKETS_CSV, all_data["resources/trinkets"])
    
    # 3. Build Status Effects CSV
    with open(DOCS_STATUS_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Status", "Description"])
        for key, val in localization.items():
            if key.startswith("STATUS_") and key.endswith("_DESC"):
                status_name = key.replace("STATUS_", "").replace("_DESC", "").capitalize()
                writer.writerow([status_name, val.replace("\n", " ")])
                
    print("Documentation (MD and CSVs) generated successfully including Status Effects.")

if __name__ == "__main__":
    build_docs()
