#!/usr/bin/env python3
import sys
import json
import subprocess
from pathlib import Path

def main():
    repo_root = Path(__file__).resolve().parents[2]
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    term_reason = data.get("terminationReason", "")
    exec_num = int(data.get("executionNum", 0))

    # Only run gate when model wants to stop and hasn't looped repeatedly
    if term_reason != "NO_TOOL_CALL" or exec_num >= 3:
        print(json.dumps({"decision": "allow"}))
        return

    # Check if any gameplay or engine assets have been modified
    try:
        status_proc = subprocess.run(
            ["git", "status", "--porcelain", "--", "scripts/", "scenes/", "resources/", "project.godot", "tests/"],
            cwd=str(repo_root),
            capture_output=True,
            text=True
        )
        if not status_proc.stdout.strip():
            # Doc-only, test-only, or pure chat turn: instant pass
            print(json.dumps({"decision": "allow"}))
            return
    except Exception:
        pass

    # Run headless fast suite
    runner = repo_root / ".agents" / "skills" / "verify-headless" / "scripts" / "run_headless.sh"
    if not runner.exists():
        print(json.dumps({"decision": "allow"}))
        return

    try:
        res = subprocess.run(
            [str(runner), "res://tests/run_fast_suite.tscn"],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
            timeout=20
        )
        if res.returncode == 0:
            print(json.dumps({"decision": "allow"}))
        else:
            output = (res.stdout + "\n" + res.stderr).strip()
            tail = "\n".join(output.splitlines()[-25:])
            reason = "Headless fast regression suite failed! Fix these errors before finishing:\n" + tail
            print(json.dumps({"decision": "continue", "reason": reason}))
    except subprocess.TimeoutExpired:
        print(json.dumps({"decision": "continue", "reason": "Headless fast regression suite timed out (>20s)!"}))
    except Exception as e:
        print(json.dumps({"decision": "continue", "reason": "Headless fast suite execution error: " + str(e)}))

if __name__ == "__main__":
    main()
