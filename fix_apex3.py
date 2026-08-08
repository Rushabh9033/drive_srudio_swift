import re

with open('lib/data/catalog/apex_templates.dart', 'r') as f:
    content = f.read()

# I corrupted the `})` at the end of baseLayer calls.
# I'll just append `)` to any line that ends with `},` but wait, it might be in the middle of list.
# Let's just fix `overrides: { ... }` that doesn't have `)` at the end of the line.

# Wait, `baseLayer(..., overrides: {...}` is missing `)`! So if a line contains `baseLayer(` but doesn't end with `),`, it's broken.
def fix_missing_paren(line):
    if 'baseLayer(' in line and not line.rstrip().endswith('),'):
        return line.rstrip() + '),\n'
    return line

lines = content.split('\n')
fixed_lines = [fix_missing_paren(line) for line in lines]
content = '\n'.join(fixed_lines)

# Also fix `}'` to `'}` maybe? I did `content.replace("}'", "'")` which removed `}`!
# Let me just check what the lines actually look like now.
