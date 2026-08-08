import re

with open('ios/DriveStudioWidget/ApexViews.swift', 'r') as f:
    content = f.read()

# Remove the extension Color { init(hex: String) { ... } }
content = re.sub(r'extension Color \{\s*init\(hex: String\) \{.*?\n\}\n', '', content, flags=re.DOTALL)

# Fix Color(hex: ...) to Color(hex: ...) ?? .clear
content = re.sub(r'Color\(hex: ("#[A-Fa-f0-9]+")\)', r'Color(hex: \1) ?? .clear', content)

with open('ios/DriveStudioWidget/ApexViews.swift', 'w') as f:
    f.write(content)
