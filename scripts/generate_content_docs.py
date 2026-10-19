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

    linked_trait_match = re.search(r'^linked_trait_id\s*=\s*&?"([^"]+)"', res_body, re.M)
    if linked_trait_match:
        data["linked_trait_id"] = linked_trait_match.group(1)

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
        if title == "Trinkets":
            md += """

### Sigils and Insignias
Sigils and Insignias have separate roles. A trait **Sigil** lists the activation thresholds and descriptions for that trait's abilities. An **Insignia** grants +1 HP and +1 PWR to a matching unit when it enters the board. Sigils use standalone trait symbols; Insignias use distinct ribboned badge icons.

| Insignia group | Items | Effect |
|---|---|---|
| Level Insignias | Novice (Level 1), Veteran (Level 2), Master (Level 3) | Grant +1 HP and +1 PWR to units of the matching level. |
| Tier Insignias | Cheap (Tier 1), Fair (Tier 2), Premium (Tier 3) | Grant +1 HP and +1 PWR to units of the matching tier, regardless of level. |
| Trait Insignias | One for each of the 15 traits listed below | Grant +1 HP and +1 PWR to units with the matching trait, regardless of level or tier. |

"""
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
            # Trait Sigils present their threshold list as the complete description.
            # Their linked trait ability summaries must not be rendered as though
            # they were Sigil effects.
            ability_entries = [] if title == "Trinkets" and item.get("linked_trait_id") else item["abilities"]
            for a in ability_entries:
                n_key = a.get('name_key', '')
                d_key = a.get('desc_key', '')
                if title == "Trinkets" and d_key and t(d_key) == t(item.get("desc_key", "")):
                    continue
                raw_name = ""
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
                    if title != "Trinkets":
                        abils.append(f"**Linked Trait**: {item['linked_trait_id']}")
                elif title == "Trinkets" and not item["abilities"] and item.get("desc_key") in localization:
                    abils.append(t_md(item["desc_key"]))

            abil_str = "<br><br>".join(abils)
            description = t_md(item["desc_key"])
            # The entity summary and its detailed ability list can describe the
            # same effects. Keep one copy in the generated reference document.
            ability_descriptions = list(dict.fromkeys(
                t(a.get("desc_key", ""))
                for a in ability_entries
                if a.get("desc_key") and t(a.get("desc_key", ""))
            ))
            raw_description = t(item["desc_key"])
            repeated_summary = bool(abils) and bool(ability_descriptions) and (
                raw_description in ability_descriptions
                or all(ability_description in raw_description for ability_description in ability_descriptions)
            )
            if repeated_summary:
                description = ""
            description_cell = f"<br>_{description}_" if description else ""
            md += f"| `{item['id']}` | **{t_md(item['name_key'])}**{description_cell} | {stats} | {tag_str} | {abil_str} |\n"

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
| `static` | **Static** | When a unit with Static dies, it deals collateral damage equal to its Static stacks to living adjacent lineup allies, mitigated by Armor. Cleared on explosion. | Decays by 1 stack at the end of each turn. |
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

    # Add Traits & Synergies section
    md += """

## Traits & Synergies
The game features 15 traits across three categories: 4 Elemental Traits (Souls: 3 to 32), 4 Class Traits (Units: 2 to 5), and 7 Visual Archetype Traits (Units: 2 to 5). Each trait has a matching Sigil that lists the activation thresholds for that trait's abilities. Trait Insignias are separate stat-bonus trinkets.

### Elemental Traits (Souls: 3, 6, 12, 20, 32)
Units carry elemental Soul tags (Fire, Earth, Water, Air). The elemental Sigils list the Soul thresholds for their abilities:
| Trait | Focus | Synergy Thresholds | Overview |
|---|---|---|---|
| **Fire** | Offensive Pressure | 3 / 6 / 12 / 20 / 32 Souls | Applies Burn on attack, spreads Burn on tick, deals bonus attack damage against burning targets, and redistributes Burn on kill. |
| **Earth** | Defensive Counter | 3 / 6 / 12 / 20 / 32 Souls | Grants Armor and Spikes across the frontline pre-combat, and Earth units deal bonus attack damage equal to their Spikes (decays 1 stack per attack). |
| **Water** | Healing & Cleanse | 3 / 6 / 12 / 20 / 32 Souls | Pre-combat healing and negative status cleansing; turn-start lowest-HP healing; consumes negative statuses to heal at turn start. |
| **Air** | Static Discharge | 3 / 6 / 12 / 20 / 32 Souls | Inflicts Static on attack, splashes Static to adjacent enemies, pre-combat team Static, and scales attack Static with unit PWR. |

### Class & Visual Archetype Traits (Units: 2, 3, 4, 5)
The Class and Visual Sigils list the unit-count thresholds for their abilities:
| Trait Category | Traits | Synergy Thresholds | Archetype Mechanic |
|---|---|---|---|
| **Class Traits** | Tank, Fighter, Support, Specialist | 2 / 3 / 4 / 5 Units | **Tank**: Frontline Armor, backward Armor passing, attack interception, Armor-to-Spikes.<br>**Fighter**: Bonus damage vs higher HP, ranged counter-attack, cleave splash, extra action on kill.<br>**Support**: Positional +HP (front) / +PWR (behind), turn-start lowest-stat buffs, Hero empowerment.<br>**Specialist**: Opening tokens, Gacha discount, gold on kill, bench combat clone, +PWR per 5 Gold. |
| **Visual Archetypes** | Food, Mecha, Animal, Plant, Toy, Appliance, Costume | 2 / 3 / 4 / 5 Units | **Food**: Feeds ally behind when hurt (+HP/+PWR), passes all PWR on death.<br>**Mecha**: Spikes & Armor, Static on attack & hit, merge laser strikes, death revenge salvos.<br>**Animal**: Random alpha +PWR, healing per attack (scaling with PWR).<br>**Plant**: Frontline Spikes, turn-start healing, team Spikes & HP, converts incoming heals to Spikes.<br>**Toy**: Melee Static reflection, death explosion detonating highest Static enemy.<br>**Appliance**: Static immunity, pre-combat Static/Burn, status reflection, converts debuffs to PWR/HP.<br>**Costume**: Pre-combat status and stat theft from mirror enemies and highest-status targets. |
"""

    with open(DOCS_MD_FILE, "w", encoding="utf-8") as f:
        f.write(md)

    def write_csv(filepath, data_list, is_unit=False):
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            headers = ["ID", "Name", "Description", "Tier", "Cost", "Base HP", "Base PWR"]
            for i in range(1, 4):
                headers.append(f"Ability {i} Description")
            writer.writerow(headers)
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
                # Sigils are fully described by their threshold text above. Do
                # not repeat the linked trait's underlying ability in the CSV.
                # Insignia ability resources often share their concise item
                # description, so omit those duplicates as well.
                named_abilities = [
                    a for a in item["abilities"]
                    if (a.get("name_key") or a.get("desc_key"))
                    and not (not is_unit and item.get("linked_trait_id"))
                    and not (
                        not is_unit
                        and a.get("desc_key")
                        and t(a.get("desc_key", "")) == t(item.get("desc_key", ""))
                    )
                ]
                seen_descs = set()
                deduped_abils = []
                for a in named_abilities:
                    signature = (a.get("name_key", ""), a.get("desc_key", ""))
                    if signature not in seen_descs:
                        seen_descs.add(signature)
                        deduped_abils.append(a)
                for i in range(3):
                    if i < len(deduped_abils):
                        d_key = deduped_abils[i].get("desc_key", "")
                        desc = t(d_key) if d_key in localization else ""
                        if deduped_abils[i]["mechanics"]:
                            desc += " " + " ".join(deduped_abils[i]["mechanics"])
                        row.append(desc)
                    else:
                        row.append("")
                writer.writerow(row)

    write_csv(DOCS_UNITS_CSV, all_data["resources/units"], is_unit=True)
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
                shutil.copy2(src, dst)
    # 5. Sync game.csv to en.po, pt_BR.po, and game.pot
    sync_po_files()

    print("Documentation (MD and CSVs) generated successfully including Status Effects, Slot Effects, and Traits.")

def sync_po_files():
    en_po_path = os.path.join(PROJECT_ROOT, "localization/en.po")
    pt_po_path = os.path.join(PROJECT_ROOT, "localization/pt_BR.po")
    pot_path = os.path.join(PROJECT_ROOT, "localization/game.pot")

    def po_escape(s):
        s = s.replace('\\n', '\n').replace('\\r', '')
        s = s.replace('\r\n', '\n').replace('\r', '')
        s = s.replace('\\', '\\\\')
        s = s.replace('"', '\\"')
        return s.replace('\n', '\\n')

    if not os.path.exists(LOCALIZATION_FILE):
        return

    with open(LOCALIZATION_FILE, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = [r for r in reader if r and r[0].strip()]

    with open(en_po_path, "w", encoding="utf-8") as f:
        f.write('msgid ""\nmsgstr ""\n"Project-Id-Version: Flashcard Heroes\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n"Language: en\\n"\n\n')
        for r in rows:
            key = r[0].strip()
            val = r[1] if len(r) > 1 else ""
            f.write(f'msgid "{po_escape(key)}"\nmsgstr "{po_escape(val)}"\n\n')

    with open(pt_po_path, "w", encoding="utf-8") as f:
        f.write('msgid ""\nmsgstr ""\n"Project-Id-Version: Flashcard Heroes\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n"Language: pt_BR\\n"\n\n')
        for r in rows:
            key = r[0].strip()
            val = r[2] if len(r) > 2 else ""
            f.write(f'msgid "{po_escape(key)}"\nmsgstr "{po_escape(val)}"\n\n')

    with open(pot_path, "w", encoding="utf-8") as f:
        f.write('msgid ""\nmsgstr ""\n"Project-Id-Version: Flashcard Heroes\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n\n')
        for r in rows:
            key = r[0].strip()
            en_val = r[1] if len(r) > 1 else ""
            f.write(f'#. English: {en_val}\nmsgid "{po_escape(key)}"\nmsgstr ""\n\n')

if __name__ == "__main__":
    build_docs()
