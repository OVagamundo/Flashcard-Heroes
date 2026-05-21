import json

log_path = r"C:\Users\danhh\.gemini\antigravity\brain\7c0eadfc-142d-4147-ac0e-9115d796f829\.system_generated\logs\transcript.jsonl"
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        try:
            data = json.loads(line)
            dumped = json.dumps(data)
            if 'invoke_subagent' in dumped or 'subagent' in dumped:
                print(f"Line {i}: Type: {data.get('type')}, Source: {data.get('source')}")
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        print(f"  Tool: {tc.get('function', {}).get('name')}")
                        print(f"  Args: {tc.get('function', {}).get('arguments')}")
                print("-" * 50)
        except Exception as e:
            pass
