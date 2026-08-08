import re

with open('lib/data/catalog/apex_templates.dart', 'r') as f:
    content = f.read()

# Fix const Color(0xFF....) -> '#....'
def replace_color(match):
    hex_val = match.group(1)
    if len(hex_val) == 8 and hex_val.startswith("FF"):
        return f"'#{hex_val[2:]}'"
    return f"'#{hex_val}'"
    
content = re.sub(r"const Color\(0x([0-9A-Fa-f]+)[^\)]*\)", replace_color, content)

# Remove extra } that might have been added in string literals or overrides
# The previous script might have left some malformed strings. Let's just fix them.
content = content.replace("})", "}")
content = content.replace("}'", "'")
content = content.replace("'}", "'")
content = content.replace("}}", "}")

# Fix missing named arguments in TemplateItem
content = re.sub(r"TemplateItem\(\s*id: '([^']+)',\s*name: '([^']+)',\s*spec:", r"TemplateItem(id: '\1', name: '\2', category: 'Apex', premium: false, createdAt: '2026-08-08', spec:", content)

# Fix overrides: {'x': ... } to make sure it's valid dart map
# Check for any remaining syntax errors.
with open('lib/data/catalog/apex_templates.dart', 'w') as f:
    f.write(content)
