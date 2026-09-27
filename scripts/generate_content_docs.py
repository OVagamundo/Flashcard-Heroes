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
    for match in re.finditer(r'\[ext_resource .*?path="res://([^"]+)" id="([^"]+)"\]', content):
        ext_resources[match.group(2)] = os.path.join(PROJECT_ROOT, match.group(1))

    sub_resources = {}
    for match in re.finditer(r'^\[sub_resource .*?id="([^"]+)"\]$(.*?)(?=^\[|\Z)', content, re.M | re.S):
        sub_resources[match.group(1)] = match.group(2)

    res_match = re.search(r"^\[resource\]$(.*?)(?=^\[|\Z)", content, re.M | re.S)
    res_body = res_match.group(1) if res_match else content

    data = {}
    id_match = re.search(r'^id\s*=\s*&?"([^"]+)"', res_body, re.M)
    data["id"] = id_match.group(1) if id_match else ""

    name_match = re.search(r'^display_name_key\s*=\s*"([^"]+)"', res_body, re.M)
    if not name_match:
        name_match = re.search(r'^name_key\s*=\s*"([^"]+)"', res_body, re.M)
    data["name_key"] = name_match.group(1) if name_match else ""

    desc_match = re.search(r'^description_key\s*=\s*"([^"]+)"', res_body, re.M)
    data["desc_key"] = desc_match.group(1) if desc_match else ""

    tier_match = re.search(r'^tier\s*=\s*(\d+)', res_body, re.M)
    data["tier"] = int(tier_match.group(1)) if tier_match else 0

    cost_match = re.search(r'^cost\s*=\s*(\d+)', res_body, re.M)
    data["cost"] = int(cost_match.group(1)) if cost_match else 0

    hero_match = re.search(r'^is_hero\s*=\s*(true|false)', res_body, re.M)
    data["is_hero"] = hero_match.group(1) == "true" if hero_match else False

    hp_match = re.search(r'^base_hp\s*=\s*(\d+)', res_body, re.M)
    data["hp"] = hp_match.group(1) if hp_match else "0"

    pwr_match = re.search(r'^base_pwr\s*=\s*(\d+)', res_body, re.M)
    data["pwr"] = pwr_match.group(1) if pwr_match else "0"

    b_hp_match = re.search(r'^bonus_hp\s*=\s*(\d+)', res_body, re.M)
    data["bonus_hp"] = int(b_hp_match.group(1)) if b_hp_match else 0

    b_pwr_match = re.search(r'^bonus_pwr\s*=\s*(\d+)', res_body, re.M)
    data["bonus_pwr"] = int(b_pwr_match.group(1)) if b_pwr_match else 0

    cat_match = re.search(r'^category\s*=\s*&?"([^"]+)"', res_body, re.M)
    data["category"] = cat_match.group(1) if cat_match else ""

    tags = []
    tags_match = re.search(r'^tags\s*=\s*(?:Array\[StringName\]\()?\s*\[(.*?)\](?:\))?', res_body, re.M | re.S)
    if tags_match:
        tag_strs = re.findall(r'&?"([^"]+)"', tags_match.group(1))
        tags.extend(tag_strs)
    data["tags"] = tags

    def parse_ability_block(block_text, full_context=""):
        ab_data = {}
        ab_name = re.search(r'^name_key\s*=\s*"([^"]+)"', block_text, re.M)
        ab_desc = re.search(r'^description_key\s*=\s*"([^"]+)"', block_text, re.M)
        ab_data["name_key"] = ab_name.group(1) if ab_name else ""
        ab_data["desc_key"] = ab_desc.group(1) if ab_desc else ""

        combined = block_text + "\n" + full_context
        mechanics = []
        dmg_match = re.search(r'"damage_type"\s*:\s*(\d+)', combined)
        if dmg_match:
            dmg_map = {0: "Melee", 1: "Ranged", 2: "Magic", 3: "Burn", 4: "Spike"}
            dtype = dmg_map.get(int(dmg_match.group(1)), "Unknown")
            mechanics.append(f"[{dtype} Damage]")

        atk_match = re.search(r'"attack_type"\s*:\s*"([^"]+)"', combined)
        if atk_match:
            mechanics.append(f"[{atk_match.group(1).title()} Attack]")

        tgt_match = re.search(r'^target_type\s*=\s*&?"([^"]+)"', combined, re.M)
        if tgt_match:
            mechanics.append(f"[Target: {tgt_match.group(1)}]")

        cond_match = re.search(r'"allowed_causes"\s*:\s*Array\[StringName\]\(\[&?"([^"]+)"\]\)', combined)
        if cond_match:
            mechanics.append(f"[Trigger: {cond_match.group(1)}]")

        ab_data["mechanics"] = mechanics
        return ab_data

    abilities = []
    abil_match = re.search(r'^ability_definitions\s*=\s*(?:Array\[Resource\]\()?\s*\[(.*?)\](?:\))?', res_body, re.M | re.S)
    if abil_match:
        for ref_match in re.finditer(r'(ExtResource|SubResource)\("([^"]+)"\)', abil_match.group(1)):
            rtype, rid = ref_match.group(1), ref_match.group(2)
            if rtype == "ExtResource" and rid in ext_resources and os.path.exists(ext_resources[rid]):
                ext_path = ext_resources[rid]
                with open(ext_path, "r", encoding="utf-8") as ef:
                    ec = ef.read()
                eb_m = re.search(r"^\[resource\]$(.*?)(?=^\[|\Z)", ec, re.M | re.S)
                eb = eb_m.group(1) if eb_m else ec
                abilities.append(parse_ability_block(eb, ec))
            elif rtype == "SubResource" and rid in sub_resources:
                abilities.append(parse_ability_block(sub_resources[rid], content))

    single_abil = re.search(r'^ability\s*=\s*(ExtResource|SubResource)\("([^"]+)"\)', res_body, re.M)
    if single_abil:
        rtype, rid = single_abil.group(1), single_abil.group(2)
        if rtype == "ExtResource" and rid in ext_resources and os.path.exists(ext_resources[rid]):
            ext_path = ext_resources[rid]
            with open(ext_path, "r", encoding="utf-8") as ef:
                ec = ef.read()
            eb_m = re.search(r"^\[resource\]$(.*?)(?=^\[|\Z)", ec, re.M | re.S)
            eb = eb_m.group(1) if eb_m else ec
            abilities.append(parse_ability_block(eb, ec))
        elif rtype == "SubResource" and rid in sub_resources:
            abilities.append(parse_ability_block(sub_resources[rid], content))

    data["abilities"] = abilities
    return data

def is_enemy_unit(d):
    uid = d.get("id", "")
    return uid.startswith("boss") or "enemy" in uid or "dust" in uid or "BOSS" in d.get("tags", [])

def is_hero_unit(d):
    uid = d.get("id", "")
    return (d.get("is_hero", False) or "hero" in uid) and not is_enemy_unit(d)

def is_player_unit(d, tier):
    return d.get("tier", 0) == tier and not is_enemy_unit(d) and not is_hero_unit(d)

def build_docs():
    load_localization()

    md = "# Game Content Document\n\n*This document is auto-generated from the game's resource files.*\n"
    sections = [
        ("Units (Tier 1)", "resources/units", lambda d: is_player_unit(d, 1)),
        ("Units (Tier 2)", "resources/units", lambda d: is_player_unit(d, 2)),
        ("Units (Tier 3)", "resources/units", lambda d: is_player_unit(d, 3)),
        ("Heroes", "resources/units", lambda d: is_hero_unit(d)),
        ("Enemies", "resources/units", lambda d: is_enemy_unit(d)),
        ("Items", "resources/items", lambda d: True),
        ("Trinkets", "resources/trinkets", lambda d: True)
    ]

    all_data = {"resources/units": [], "resources/items": [], "resources/trinkets": []}

    for title, folder, filt in sections:
        md += f"\n\n## {title}\n"
        folder_path = os.path.join(PROJECT_ROOT, folder)
        if not os.path.exists(folder_path):
            continue

        items = []
        for root, dirs, files in os.walk(folder_path):
            for f in sorted(files):
                if f.endswith(".tres"):
                    data = parse_tres(os.path.join(root, f))
                    # Avoid duplicate records in all_data
                    if not any(x.get("id") == data["id"] and x.get("id") != "" for x in all_data[folder]):
                        all_data[folder].append(data)
                    if filt(data):
                        items.append(data)

        # Sort items predictably by id
        items.sort(key=lambda x: x.get("id", ""))

        if not items:
            md += "*None found.*\n"
            continue

        md += "| ID | Name | Stats | Tags | Abilities |\n"
        md += "|---|---|---|---|---|\n"
        for item in items:
            if title == "Trinkets":
                stats = "-"
            elif title == "Items":
                bhp = item.get("bonus_hp", 0)
                bpwr = item.get("bonus_pwr", 0)
                if bhp > 0 and bpwr > 0:
                    stats = f"+{bhp} HP / +{bpwr} PWR"
                elif bhp > 0:
                    stats = f"+{bhp} HP"
                elif bpwr > 0:
                    stats = f"+{bpwr} PWR"
                else:
                    stats = "-"
            else:
                stats = f"{item['hp']} HP / {item['pwr']} PWR"

            tag_str = ", ".join([t.replace("SOUL_", "") for t in item["tags"]])

            abils = []
            for a in item["abilities"]:
                n_key = a.get('name_key', '')
                d_key = a.get('desc_key', '')
                raw_name = t_md(n_key).strip() if n_key in localization else ""
                raw_desc = t_md(d_key).strip() if d_key in localization else ""
                if not raw_name and not raw_desc:
                    continue
                aname = f"**{raw_name}**" if raw_name else ""
                if a['mechanics']:
                    raw_desc += (" " if raw_desc else "") + " ".join(a['mechanics'])
                if raw_desc:
                    if aname:
                        aname += f": {raw_desc}"
                    else:
                        aname = raw_desc
                if aname and aname not in abils:
                    abils.append(aname)

            if not abils:
                if item.get("linked_trait_id"):
                    abils.append(f"**Linked Trait**: {item['linked_trait_id']}")
                elif title == "Trinkets" and item.get("desc_key") in localization:
                    abils.append(t_md(item["desc_key"]))

            abil_str = "<br><br>".join(abils)
            md += f"| `{item['id']}` | **{t_md(item['name_key'])}**<br>_{t_md(item['desc_key'])}_ | {stats} | {tag_str} | {abil_str} |\n"

    # Add Core Stats & Combat Attributes section
    md += """

## Core Stats & Combat Attributes
| Stat / Attribute | Type | Description |
|---|---|---|
| **HP (Health)** | Core Stat | The life pool of the unit. When reduced to 0, the unit is defeated and removed from the active battlefield. |
| **PWR (Power)** | Core Stat | The damage output of the unit during attacks and the base reflection strength for Spikes. |
| **Armor** | Combat Shield | Absorbs incoming direct combat attack damage point-for-point. Decays to 0 at the end of each turn unless preserved (e.g. by Polished Plate). Does not absorb Burn or Static damage. |
| **Spikes** | Defensive Counter | Deals PWR damage back to attackers when hit by a direct melee attack. Bypassed by ranged attacks and does not decay at turn end. |
"""

    # Add Status Effects section
    md += """

## Status Effects
| ID | Status | Mechanics | Decay Mode |
|---|---|---|---|
| `burn` | **Burn** | Deals damage equal to the number of stacks at the end of each turn. Damage ignores Armor. | Halved (reduced by 50% rounded down) at the end of each turn. Stacks on units in a Burn Slot do not decay. |
| `armor` | **Armor** | Absorbs incoming direct attack damage (1 point of Armor absorbs 1 point of HP damage). Bypassed by Burn and Static. | Decays to 0 at the end of each turn unless preserved by abilities/trinkets. |
| `spikes` | **Spikes** | Deals the defending unit's PWR damage back to attackers when hit by direct melee attacks. | Does not decay. |
| `static` | **Static** | Consumed stack-by-stack whenever the unit experiences any core stat change (HP damage, healing, or power modification). Each stack consumed deals 1 armor-ignoring damage. | Does not decay. Only consumed upon stat changes. |
"""

    # Add Battlefield Slot Effects section
    md += """

## Battlefield Slot Effects
| ID | Slot Name | Trigger | Effect | Cost (Gold) |
|---|---|---|---|---|
| `burn` | **Burn Slot** | `on_turn_start` | Applies 1 stack of Burn to the unit standing on it. Burn stacks on units in this slot do not decay. | 3 |
| `lightning` | **Lightning Slot** | `on_turn_start` | Applies 1 stack of Static to the unit standing on it. | 2 |
| `death` | **Death Slot** | `on_turn_end` (Sudden Death) | Systemic sudden-death slot advancing forward from Turn 10+. Immediately reduces unit HP to 0. | - |
"""

    # Add Elemental Traits section
    md += """

## Elemental Traits & Synergies
Units carry elemental Soul tags (Fire, Earth, Water, Air). Equipping the corresponding elemental Trinket activates team-wide synergies based on active lineup souls:
| Trait | Focus | Synergy Thresholds | Effect |
|---|---|---|---|
| **Fire** | Offensive Pressure | 3 / 5 / 7 / 9 Souls | Applies Burn on attack. Higher thresholds grant more stacks; 7+ applies Burn to the entire enemy team. |
| **Earth** | Defensive Sustain | 3 / 5 / 7 / 9 Souls | Grants Armor (3, 5, 7, 9) and Spikes (7, 9) to allies at turn start. Earth units gain double armor bonus. |
| **Water** | Resilience | 2 / 4 / 6 / 8 Souls | Heals adjacent allies at turn start upon acting. |
| **Air** | Disruption | 2 / 4 / 6 / 8 Souls | Steals Power (PWR) from mirrored enemy slots. |
"""

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
                named_abilities = [a for a in item["abilities"] if a.get("name_key") or a.get("desc_key")]
                seen_descs = set()
                deduped_abils = []
                for a in named_abilities:
                    signature = (a.get("name_key", ""), a.get("desc_key", ""))
                    if signature not in seen_descs:
                        seen_descs.add(signature)
                        deduped_abils.append(a)
                if not deduped_abils and item.get("linked_trait_id"):
                    deduped_abils.append({"name_key": "", "desc_key": item.get("desc_key", ""), "mechanics": [f"[Linked Trait: {item['linked_trait_id']}]"]})
                for i in range(3):
                    if i < len(deduped_abils):
                        n_key = deduped_abils[i].get("name_key", "")
                        d_key = deduped_abils[i].get("desc_key", "")
                        row.append(t(n_key) if n_key in localization else "")
                        desc = t(d_key) if d_key in localization else ""
                        if deduped_abils[i]["mechanics"]:
                            desc += " " + " ".join(deduped_abils[i]["mechanics"])
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
        for key, val in sorted(localization.items()):
            if key.startswith("STATUS_") and key.endswith("_DESC"):
                status_name = key.replace("STATUS_", "").replace("_DESC", "").capitalize()
                writer.writerow([status_name, val.replace("\n", " ")])

    # 4. Sync to localization/docs if present
    loc_docs_dir = os.path.join(PROJECT_ROOT, "localization/docs")
    if os.path.exists(loc_docs_dir):
        import shutil
        for fname in ["GameContentDocument.md", "units.csv", "items.csv", "trinkets.csv", "status_effects.csv"]:
            src = os.path.join(PROJECT_ROOT, "docs", fname)
            dst = os.path.join(loc_docs_dir, fname)
            if os.path.exists(src):
                shutil.copyfile(src, dst)

    print("Documentation (MD and CSVs) generated successfully including Status Effects, Slot Effects, and Traits.")

if __name__ == "__main__":
    build_docs()
