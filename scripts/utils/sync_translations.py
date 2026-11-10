#!/usr/bin/env python3
import os
import csv
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
LOCALIZATION_FILE = PROJECT_ROOT / "localization" / "game.csv"

def sync_po_files():
    en_po_path = PROJECT_ROOT / "localization" / "en.po"
    pt_po_path = PROJECT_ROOT / "localization" / "pt_BR.po"
    pot_path = PROJECT_ROOT / "localization" / "game.pot"

    def po_escape(s):
        s = s.replace('\\n', '\n').replace('\\r', '')
        s = s.replace('\r\n', '\n').replace('\r', '')
        s = s.replace('\\', '\\\\')
        s = s.replace('"', '\\"')
        return s.replace('\n', '\\n')

    if not LOCALIZATION_FILE.exists():
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
    sync_po_files()

