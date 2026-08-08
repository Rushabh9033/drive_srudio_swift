import json

log_path = "/Users/radhikamac/.gemini/antigravity/brain/c7b6cd2e-e703-4acc-ad53-bbd4b9948cca/.system_generated/logs/transcript_full.jsonl"
target_file = "/Users/radhikamac/backup2/car-play-cursor/lib/data/catalog/stock_widget_templates.dart"

with open(log_path, 'r') as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get("type") == "VIEW_FILE":
                content = data.get("content", "")
                if "File Path: `file:///Users/radhikamac/backup2/car-play-cursor/lib/data/catalog/stock_widget_templates.dart`" in content:
                    print("Found original view!")
                    # Try to extract content
                    # Format is usually:
                    # Created At...
                    # Completed At...
                    # File Path...
                    # Total Lines...
                    # Total Bytes...
                    # ...
                    # 1: ...
                    
                    lines = content.split('\n')
                    output = []
                    parsing = False
                    for l in lines:
                        if l.startswith('1: '):
                            parsing = True
                        if parsing:
                            if "The above content does NOT show the entire file" in l:
                                break
                            if ': ' in l:
                                # extract the actual code
                                parts = l.split(': ', 1)
                                if parts[0].isdigit():
                                    output.append(parts[1])
                    
                    with open("extracted_stock.dart", "w") as out:
                        out.write('\n'.join(output))
                    print("Wrote to extracted_stock.dart")
                    break
        except Exception as e:
            pass

