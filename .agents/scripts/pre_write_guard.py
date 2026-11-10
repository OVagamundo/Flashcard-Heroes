#!/usr/bin/env python3
import sys
import json
from pathlib import Path

def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            print(json.dumps({"decision": "allow"}))
            return
        data = json.loads(raw)
    except Exception:
        print(json.dumps({"decision": "allow"}))
        return

    tool_call = data.get("toolCall", {})
    tool_name = tool_call.get("name", "")
    args = tool_call.get("args", {})

    path = (
        args.get("Path") or 
        args.get("TargetFile") or 
        args.get("path") or 
        args.get("target_file") or 
        ""
    )

    if not path.endswith(".gd") or "/tests/" in path:
        print(json.dumps({"decision": "allow"}))
        return

    # Extract newly added lines
    added_lines = []
    if "ReplacementChunks" in args and isinstance(args["ReplacementChunks"], list):
        for chunk in args["ReplacementChunks"]:
            rep = chunk.get("ReplacementContent", "")
            tgt = chunk.get("TargetContent", "")
            tgt_set = set(tgt.splitlines())
            for line in rep.splitlines():
                if line not in tgt_set:
                    added_lines.append(line)
    elif "Replacement" in args or "ReplacementContent" in args:
        rep = args.get("Replacement") or args.get("ReplacementContent") or ""
        tgt = args.get("Target") or args.get("TargetContent") or ""
        tgt_set = set(tgt.splitlines())
        for line in rep.splitlines():
            if line not in tgt_set:
                added_lines.append(line)
    else:
        content = args.get("Content") or args.get("CodeContent") or ""
        added_lines = content.splitlines()

    # Rule checks
    for line in added_lines:
        stripped = line.strip()
        if stripped.startswith("#"):
            continue

        if ".has_method(" in line:
            print(json.dumps({"decision": "deny", "reason": "Banned defensive anti-pattern: .has_method() is forbidden. Use static types or assert invariants."}))
            return
        if ".has_signal(" in line:
            print(json.dumps({"decision": "deny", "reason": "Banned defensive anti-pattern: .has_signal() is forbidden. Use static types or assert invariants."}))
            return
        if "is_instance_valid(self)" in line:
            print(json.dumps({"decision": "deny", "reason": "Banned defensive anti-pattern: is_instance_valid(self) is redundant and forbidden."}))
            return
        if "is_instance_valid(ActionQueue)" in line:
            print(json.dumps({"decision": "deny", "reason": "Banned defensive anti-pattern: is_instance_valid(ActionQueue) is forbidden."}))
            return

        if "/scripts/battle/" in path:
            if "SignalBus." in line:
                print(json.dumps({"decision": "deny", "reason": "Simulation decoupling violation: SignalBus is forbidden in scripts/battle/. Emit CombatEvents instead."}))
                return
            if "WindowManager." in line:
                print(json.dumps({"decision": "deny", "reason": "Simulation decoupling violation: WindowManager is forbidden in scripts/battle/."}))
                return
            if "Audio." in line:
                print(json.dumps({"decision": "deny", "reason": "Simulation decoupling violation: Audio is forbidden in scripts/battle/."}))
                return
            if "get_tree()" in line:
                print(json.dumps({"decision": "deny", "reason": "Simulation decoupling violation: SceneTree lookups (get_tree()) are forbidden in scripts/battle/."}))
                return
            if "await " in line:
                print(json.dumps({"decision": "deny", "reason": "Simulation decoupling violation: await/async suspension is forbidden in scripts/battle/."}))
                return

        if "/scripts/engine/actions/" in path:
            if "get_instance_id(" in line or "instance_from_id(" in line:
                print(json.dumps({"decision": "deny", "reason": "Replay violation: Runtime Object IDs (get_instance_id/instance_from_id) are forbidden in GameAction."}))
                return

    print(json.dumps({"decision": "allow"}))

if __name__ == "__main__":
    main()
