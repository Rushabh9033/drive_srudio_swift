import re

with open("Runner.xcodeproj/project.pbxproj", "r") as f:
    lines = f.readlines()

# Find all UUIDs for lines containing .wav
wav_uuids = set()
for line in lines:
    if ".wav" in line:
        match = re.search(r'([A-F0-9]{24})', line)
        if match:
            wav_uuids.add(match.group(1))

# Filter lines
new_lines = []
for line in lines:
    # If the line contains any of the UUIDs, skip it
    if any(uuid in line for uuid in wav_uuids):
        continue
    new_lines.append(line)

with open("Runner.xcodeproj/project.pbxproj", "w") as f:
    f.writelines(new_lines)

print(f"Removed {len(lines) - len(new_lines)} lines containing .wav UUIDs.")
