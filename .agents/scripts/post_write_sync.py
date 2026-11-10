#!/usr/bin/env python3
import sys
import json
import subprocess
from pathlib import Path

def main():
    repo_root = Path(__file__).resolve().parents[2]
    try:
        raw = sys.stdin.read()
        if raw.strip():
            data = json.loads(raw)
            tool_call = data.get("toolCall", {})
            args = tool_call.get("args", {})
            path = (
                args.get("Path") or 
                args.get("TargetFile") or 
                args.get("path") or 
                args.get("target_file") or 
                ""
            )
            has_error = bool(data.get("error"))

            if path.endswith("localization/game.csv") and not has_error:
                sync_script = repo_root / "scripts" / "utils" / "sync_translations.py"
                if sync_script.exists():
                    subprocess.run(["python3", str(sync_script)], cwd=str(repo_root), capture_output=True)
    except Exception:
        pass

    # PostToolUse contract strictly requires {}
    print("{}")

if __name__ == "__main__":
    main()
