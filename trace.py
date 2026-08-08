with open('lib/presentation/screens/editor_screen.dart', 'r') as f:
    lines = f.readlines()

text = "".join(lines[43:]) # Start at line 44 (index 43)

level = 0
in_string = False
for i, c in enumerate(text):
    if c == '{':
        level += 1
    elif c == '}':
        level -= 1
        if level == 0:
            print(f"Braces reached level 0 at offset {i}. Line: {text[:i].count(chr(10))+44}")
            break
