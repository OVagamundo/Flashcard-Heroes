import json

log_path = r"C:\Users\danhh\.gemini\antigravity\brain\7c0eadfc-142d-4147-ac0e-9115d796f829\.system_generated\logs\transcript.jsonl"
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if i == 150:
            data = json.loads(line)
            print(json.dumps(data, indent=2))
            break
