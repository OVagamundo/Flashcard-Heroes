import json

log_path = r"C:\Users\danhh\.gemini\antigravity\brain\7c0eadfc-142d-4147-ac0e-9115d796f829\.system_generated\logs\transcript.jsonl"
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        try:
            data = json.loads(line)
            line_str = json.dumps(data)
            if 'korean_hangul.json' in line_str:
                # print some details
                print(f"Line {i} - Type: {data.get('type')}, Status: {data.get('status')}")
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        func = tc.get('function', {})
                        print(f"  Tool: {func.get('name')}")
                        args = func.get('arguments', {})
                        # print keys in arguments
                        print(f"    Args: {list(args.keys())}")
                        if 'TargetFile' in args:
                            print(f"    TargetFile: {args['TargetFile']}")
                print("-" * 40)
        except Exception as e:
            pass
