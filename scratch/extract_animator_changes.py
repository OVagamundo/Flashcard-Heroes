import json

with open('/Users/danhh/.gemini/antigravity-ide/brain/4a4c0b7a-f5c5-4a9a-81e9-80175a53f747/.system_generated/logs/transcript_full.jsonl', 'r') as f:
    for line in f:
        try:
            data = json.loads(line)
            if 'tool_calls' in data:
                for call in data['tool_calls']:
                    if call['name'] in ['multi_replace_file_content', 'replace_file_content']:
                        if 'BattleAnimator.gd' in call['args'].get('TargetFile', ''):
                            print("--------------------------------")
                            print("Step:", data['step_index'])
                            print("Description:", call['args'].get('Description', ''))
                            if 'ReplacementChunks' in call['args']:
                                for chunk in call['args']['ReplacementChunks']:
                                    print("--- REPLACEMENT ---")
                                    print(chunk['ReplacementContent'])
        except Exception as e:
            pass
