import json

log_path = r"C:\Users\danhh\.gemini\antigravity\brain\7c0eadfc-142d-4147-ac0e-9115d796f829\.system_generated\logs\transcript.jsonl"
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 55 <= i <= 61:
            data = json.loads(line)
            # print only key fields to keep it brief
            keys = list(data.keys())
            print(f"Line {i}: Type: {data.get('type')}, Source: {data.get('source')}, Keys: {keys}")
            if 'tool_calls' in data:
                print("  Tool calls in data:", [tc.get('function', {}).get('name') for tc in data['tool_calls']])
            if 'content' in data:
                c = data['content']
                print(f"  Content snippet: {c[:120]}...")
            print("-" * 50)
