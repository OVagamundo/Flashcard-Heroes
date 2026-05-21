import json

log_path = r"C:\Users\danhh\.gemini\antigravity\brain\7c0eadfc-142d-4147-ac0e-9115d796f829\.system_generated\logs\transcript.jsonl"
with open(log_path, 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        try:
            data = json.loads(line)
            # dump the entire step to a string and look for 'korean_hangul.json'
            dumped = json.dumps(data)
            if 'korean_hangul.json' in dumped and ('write_to_file' in dumped or 'write_file' in dumped or 'replace_file' in dumped):
                print(f"Line {i}: Type: {data.get('type')}, Source: {data.get('source')}, Status: {data.get('status')}")
                # Print tool calls
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        func = tc.get('function', {})
                        print(f"  Tool: {func.get('name')}")
                        args = func.get('arguments', {})
                        print(f"    TargetFile: {args.get('TargetFile')}")
                        # if there is CodeContent or similar, print its length
                        if 'CodeContent' in args:
                            print(f"    CodeContent len: {len(args['CodeContent'])}")
                        if 'ReplacementContent' in args:
                            print(f"    ReplacementContent len: {len(args['ReplacementContent'])}")
                print("-" * 50)
        except Exception as e:
            pass
