import json

with open("/Users/danhh/.gemini/antigravity-ide/brain/1835e808-187b-4855-9839-c39cf8ca183d/.system_generated/logs/transcript_full.jsonl") as f:
    for line in f:
        data = json.loads(line)
        if data.get("type") == "CODE_ACTION" and "BattleManager.gd" in data.get("content", "") and "replace_file_content" in data.get("content", ""):
            print(data["content"])
