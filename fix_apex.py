import re

with open('lib/data/catalog/apex_templates.dart', 'r') as f:
    content = f.read()

# Fix imports
content = re.sub(
    r"import '../../core/models/widget_spec.dart';\nimport '../../core/models/template_item.dart';\nimport '../../core/theme/design_tokens.dart';",
    "import '../models/models.dart';\nimport 'catalog.dart';",
    content
)

# Fix _spec signature
content = re.sub(
    r"WidgetSpec _spec\(Color from, Color to, List<WidgetLayer> layers\) {\n  return WidgetSpec\(\n    backgroundGradient: \[from, to\],\n    layers: layers,\n  \);",
    "WidgetSpec _spec(String from, String to, List<Layer> layers) {\n  return WidgetSpec(\n    background: WidgetBackground(type: BgType.gradient, from: from, to: to),\n    layers: layers,\n  );",
    content
)

# Fix DesignTokens.colors to HEX strings
color_map = {
    "DesignTokens.colors['bg1']!": "'#10151B'",
    "DesignTokens.colors['bg0']!": "'#06080A'",
    "DesignTokens.colors['cyan']!": "'#66D9FF'",
    "DesignTokens.colors['muted']!": "'#6D7784'",
    "DesignTokens.colors['faint']!": "'#35404B'",
    "DesignTokens.colors['text']!": "'#F7F9FC'",
    "DesignTokens.colors['line']!": "'#202831'",
    "DesignTokens.colors['orange']!": "'#FFB55C'",
    "DesignTokens.colors['green']!": "'#A8FF60'",
    "const Color(0xFF202831)": "'#202831'",
    "const Color(0xFF35404B)": "'#35404B'",
    "const Color(0xFF6D7784)": "'#6D7784'",
    "const Color(0xFFF7F9FC)": "'#F7F9FC'",
    "const Color(0xFF66D9FF)": "'#66D9FF'",
    "const Color(0xFF000000)": "'#000000'",
    "const Color(0xFFFFFFFF)": "'#FFFFFF'",
}

for k, v in color_map.items():
    content = content.replace(k, v)

# Fix baseLayer
# baseLayer(kind: LayerKind.shape, x: 9.17, y: 10.28, w: 2.78, h: 2.78, properties: <String, dynamic>{'color': '#66D9FF', 'shape': 'circle'})
# to
# baseLayer(LayerKind.shape, overrides: {'x': 9.17, 'y': 10.28, 'w': 2.78, 'h': 2.78, 'color': '#66D9FF', 'shape': 'circle'})

def replace_baselayer(match):
    kind = match.group(1)
    x = match.group(2)
    y = match.group(3)
    w = match.group(4)
    h = match.group(5)
    props = match.group(6)
    
    props = props.replace("<String, dynamic>", "")
    # Combine x, y, w, h into props dictionary string
    # Remove leading/trailing braces of props
    props = props.strip()
    if props.startswith("{"): props = props[1:]
    if props.endswith("}"): props = props[:-1]
    
    overrides = f"{{'x': {x}, 'y': {y}, 'w': {w}, 'h': {h}"
    if props:
        overrides += f", {props}"
    overrides += "}"
    
    return f"baseLayer({kind}, overrides: {overrides})"

content = re.sub(
    r"baseLayer\(kind: (LayerKind\.\w+), x: ([\d\.-]+), y: ([\d\.-]+), w: ([\d\.-]+), h: ([\d\.-]+), properties: (.*?)\)",
    replace_baselayer,
    content
)

with open('lib/data/catalog/apex_templates.dart', 'w') as f:
    f.write(content)

