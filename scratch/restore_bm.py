import json

paths = [
    "/Users/danhh/.gemini/antigravity-ide/brain/d345ffdd-46a0-4f70-8d4b-0021943be551/.system_generated/logs/transcript_full.jsonl",
    "/Users/danhh/.gemini/antigravity-ide/brain/1835e808-187b-4855-9839-c39cf8ca183d/.system_generated/logs/transcript_full.jsonl"
]

target_file = "/Users/danhh/Desktop/Flashcard Heroes/scripts/BattleManager.gd"

for path in paths:
    try:
        with open(path) as f:
            for line in f:
                data = json.loads(line)
                if data.get("type") == "PLANNER_RESPONSE":
                    for tool_call in data.get("tool_calls", []):
                        if tool_call["name"] == "replace_file_content" or tool_call["name"] == "multi_replace_file_content":
                            args = tool_call["args"]
                            if args.get("TargetFile") == target_file:
                                print(f"Applying patch from {path}")
                                with open(target_file, "r") as tf:
                                    content = tf.read()
                                
                                if "ReplacementChunks" in args:
                                    for chunk in args["ReplacementChunks"]:
                                        target = chunk["TargetContent"]
                                        repl = chunk["ReplacementContent"]
                                        content = content.replace(target, repl)
                                else:
                                    target = args["TargetContent"]
                                    repl = args["ReplacementContent"]
                                    content = content.replace(target, repl)
                                
                                with open(target_file, "w") as tf:
                                    tf.write(content)
    except Exception as e:
        print(f"Error on {path}: {e}")

