import json

log_path = "/Users/radhikamac/.gemini/antigravity/brain/c7b6cd2e-e703-4acc-ad53-bbd4b9948cca/.system_generated/logs/transcript_full.jsonl"
lines_dict = {}

with open(log_path, 'r') as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get("type") == "VIEW_FILE" or data.get("type") == "TOOL_RESPONSE":
                content = data.get("content", "")
                if "File Path: `file:///Users/radhikamac/backup2/car-play-cursor/lib/data/catalog/stock_widget_templates.dart`" in content:
                    lines = content.split('\n')
                    parsing = False
                    for l in lines:
                        if l.startswith('1: ') or (': ' in l and l.split(': ')[0].isdigit()):
                            parsing = True
                        if parsing:
                            if "The above content does NOT show the entire file" in l:
                                break
                            if ': ' in l:
                                parts = l.split(': ', 1)
                                if parts[0].isdigit():
                                    num = int(parts[0])
                                    lines_dict[num] = parts[1]
        except Exception as e:
            pass

if lines_dict:
    max_line = max(lines_dict.keys())
    with open("extracted_stock_full.dart", "w") as out:
        for i in range(1, max_line + 1):
            out.write(lines_dict.get(i, "") + "\n")
    print(f"Extracted {max_line} lines.")
else:
    print("No lines found.")

