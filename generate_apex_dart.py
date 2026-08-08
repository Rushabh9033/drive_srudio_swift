import json
import xml.etree.ElementTree as ET
import glob
import os

svg_dir = '/Users/radhikamac/Downloads/Drive-Studio-Apex-Widget-System-v1/vectors'
files = glob.glob(f'{svg_dir}/*.svg')
files.sort()

colors_map = {
    '#05070A': 'DesignTokens.colors[\'bg0\']!',
    '#0A0E13': 'DesignTokens.colors[\'bg1\']!',
    '#111821': 'DesignTokens.colors[\'bg2\']!',
    '#F7F9FC': 'DesignTokens.colors[\'text\']!',
    '#95A0AD': 'DesignTokens.colors[\'muted\']!',
    '#66717E': 'DesignTokens.colors[\'faint\']!',
    '#28313B': 'DesignTokens.colors[\'line\']!',
    '#66D9FF': 'DesignTokens.colors[\'cyan\']!',
    '#A8FF60': 'DesignTokens.colors[\'volt\']!',
    '#FFB55C': 'DesignTokens.colors[\'amber\']!',
    '#BDA6FF': 'DesignTokens.colors[\'violet\']!',
    '#FF6B7A': 'DesignTokens.colors[\'red\']!'
}

def get_color(c):
    return colors_map.get(c.upper(), f"const Color(0xFF{c.strip('#').upper()})") if c.startswith('#') else 'Colors.transparent'

def p(val, base):
    return round(float(val) / base * 100, 2)

dart_code = """import 'package:flutter/material.dart';
import '../../core/models/widget_spec.dart';
import '../../core/models/template_item.dart';
import '../../core/theme/design_tokens.dart';

WidgetSpec _spec(Color from, Color to, List<WidgetLayer> layers) {
  return WidgetSpec(
    backgroundGradient: [from, to],
    layers: layers,
  );
}

List<TemplateItem> buildApexWidgetTemplates() {
  return [
"""

for i, f in enumerate(files):
    tree = ET.parse(f)
    root = tree.getroot()
    base = os.path.basename(f)
    name = base.split('-', 1)[1].replace('.svg', '').replace('-', ' ').title()
    id_name = base.split('-', 1)[1].replace('.svg', '')
    width = float(root.attrib.get('width', 360))
    height = float(root.attrib.get('height', 360))
    
    from_color = "DesignTokens.colors['bg1']!"
    to_color = "DesignTokens.colors['bg0']!"
    
    dart_code += f"    TemplateItem(\n      id: 'apex_{id_name}',\n      name: '{name}',\n      spec: _spec(\n        {from_color},\n        {to_color},\n        [\n"
    
    for elem in root.iter():
        tag = elem.tag.split('}')[-1]
        
        if tag == 'text':
            x = float(elem.attrib.get('x', 0))
            y = float(elem.attrib.get('y', 0))
            fill = elem.attrib.get('fill', '#FFFFFF')
            size = float(elem.attrib.get('font-size', 14))
            weight = int(elem.attrib.get('font-weight', 400))
            content = elem.text or ""
            align = elem.attrib.get('text-anchor', 'start')
            letter_spacing = float(elem.attrib.get('letter-spacing', 0))
            
            w_px = 100 
            h_px = size * 1.2
            
            x_p = p(x, width)
            y_p = p(y - size, height)
            
            color_str = get_color(fill)
            
            role = 'null'
            if 'speed' in content.lower() or 'km/h' in content.lower():
                role = "'telemetry:speed'"
            elif ':' in content and len(content) <= 5:
                role = "'telemetry:time'"
            elif '°' in content:
                role = "'telemetry:temperature'"
            
            dart_code += f"          baseLayer(kind: LayerKind.text, x: {x_p}, y: {y_p}, w: 20, h: {p(h_px, height)}, properties: <String, dynamic>{{'content': '{content}', 'color': {color_str}, 'fontSize': {size}, 'fontWeight': {weight}, 'letterSpacing': {letter_spacing}, 'align': '{align}', 'role': {role}}}),\n"
            
        elif tag == 'rect':
            w = elem.attrib.get('width')
            h = elem.attrib.get('height')
            if w in ['360', '760', '358', '100%']: continue
            
            x = float(elem.attrib.get('x', 0))
            y = float(elem.attrib.get('y', 0))
            w = float(w)
            h = float(h)
            fill = elem.attrib.get('fill', '#FFFFFF')
            rx = float(elem.attrib.get('rx', 0))
            
            color_str = get_color(fill)
            dart_code += f"          baseLayer(kind: LayerKind.shape, x: {p(x, width)}, y: {p(y, height)}, w: {p(w, width)}, h: {p(h, height)}, properties: <String, dynamic>{{'color': {color_str}, 'borderRadius': {rx}}}),\n"
            
        elif tag == 'circle':
            cx = float(elem.attrib.get('cx', 0))
            cy = float(elem.attrib.get('cy', 0))
            r = float(elem.attrib.get('r', 0))
            fill = elem.attrib.get('fill', '#FFFFFF')
            
            color_str = get_color(fill)
            if fill == 'none':
                stroke = elem.attrib.get('stroke', '#FFFFFF')
                color_str = get_color(stroke)
            
            dart_code += f"          baseLayer(kind: LayerKind.shape, x: {p(cx - r, width)}, y: {p(cy - r, height)}, w: {p(r*2, width)}, h: {p(r*2, height)}, properties: <String, dynamic>{{'color': {color_str}, 'shape': 'circle'}}),\n"
            
        elif tag == 'line':
            x1 = float(elem.attrib.get('x1', 0))
            y1 = float(elem.attrib.get('y1', 0))
            x2 = float(elem.attrib.get('x2', 0))
            y2 = float(elem.attrib.get('y2', 0))
            stroke = elem.attrib.get('stroke', '#FFFFFF')
            sw = float(elem.attrib.get('stroke-width', 1))
            
            color_str = get_color(stroke)
            
            dart_code += f"          baseLayer(kind: LayerKind.divider, x: {p(x1, width)}, y: {p(y1, height)}, w: {p(x2-x1, width) if x2>x1 else p(sw, width)}, h: {p(sw, height) if y2==y1 else p(y2-y1, height)}, properties: <String, dynamic>{{'color': {color_str}}}),\n"

    dart_code += "        ],\n      ),\n    ),\n"

dart_code += "  ];\n}\n"

out_dir = '/Users/radhikamac/backup2/car-play-cursor/lib/data/catalog'
os.makedirs(out_dir, exist_ok=True)
with open(f'{out_dir}/apex_templates.dart', 'w') as f:
    f.write(dart_code)
print("Dart generation done")
