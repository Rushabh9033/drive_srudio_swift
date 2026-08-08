import json
import xml.etree.ElementTree as ET
import glob
import os

svg_dir = '/Users/radhikamac/Downloads/Drive-Studio-Apex-Widget-System-v1/vectors'
files = glob.glob(f'{svg_dir}/*.svg')
files.sort()

colors_map = {
    '#05070A': "'#06080A'",
    '#0A0E13': "'#10151B'",
    '#111821': "'#111821'",
    '#F7F9FC': "'#F7F9FC'",
    '#95A0AD': "'#6D7784'",
    '#66717E': "'#35404B'",
    '#28313B': "'#202831'",
    '#66D9FF': "'#66D9FF'",
    '#A8FF60': "'#A8FF60'",
    '#FFB55C': "'#FFB55C'",
    '#BDA6FF': "'#BDA6FF'",
    '#FF6B7A': "'#FF6B7A'"
}

def get_color(c):
    if c.startswith('#'):
        c_upper = c.upper()
        if c_upper in colors_map:
            return colors_map[c_upper]
        return f"'{c_upper}'"
    return "'transparent'"

def p(val, base):
    return round(float(val) / base * 100, 2)

dart_code = """import 'package:flutter/material.dart';
import '../models/models.dart';
import 'catalog.dart';

WidgetSpec _spec(String from, String to, List<Layer> layers) {
  return WidgetSpec(
    background: WidgetBackground(type: BgType.gradient, from: from, to: to),
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
    
    from_color = "'#10151B'"
    to_color = "'#06080A'"
    
    dart_code += f"    TemplateItem(\n      id: 'apex_{id_name}',\n      name: '{name}',\n      category: 'Apex',\n      premium: false,\n      createdAt: '2026-08-08',\n      spec: _spec(\n        {from_color},\n        {to_color},\n        [\n"
    
    for elem in root.iter():
        tag = elem.tag.split('}')[-1]
        
        if tag == 'text':
            x = float(elem.attrib.get('x', 0))
            y = float(elem.attrib.get('y', 0))
            fill = elem.attrib.get('fill', '#FFFFFF')
            size = float(elem.attrib.get('font-size', 14))
            weight = int(elem.attrib.get('font-weight', 400))
            content = elem.text or ""
            align_raw = elem.attrib.get('text-anchor', 'start')
            
            align = 'left'
            if align_raw == 'middle': align = 'center'
            elif align_raw == 'end': align = 'right'
            
            w_px = 100 
            h_px = size * 1.2
            
            x_p = p(x, width)
            y_p = p(y - size, height)
            
            color_str = get_color(fill)
            
            props = [
                f"'x': {x_p}",
                f"'y': {y_p}",
                f"'w': 20",
                f"'h': {p(h_px, height)}",
                f"'text': '{content}'",
                f"'color': {color_str}",
                f"'fontSize': {size}",
                f"'weight': {weight}",
                f"'textAlign': '{align}'"
            ]
            
            role = None
            if 'speed' in content.lower() or 'km/h' in content.lower():
                role = "'telemetry:speed'"
            elif ':' in content and len(content) <= 5:
                role = "'telemetry:time'"
            elif '°' in content:
                role = "'telemetry:temperature'"
                
            if role:
                props.append(f"'role': {role}")
            
            props_str = ", ".join(props)
            dart_code += f"          baseLayer(LayerKind.text, overrides: {{{props_str}}}),\n"
            
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
            
            props = [
                f"'x': {p(x, width)}",
                f"'y': {p(y, height)}",
                f"'w': {p(w, width)}",
                f"'h': {p(h, height)}",
                f"'color': {color_str}"
            ]
            if rx > 0:
                props.append(f"'borderRadius': {rx}")
                
            props_str = ", ".join(props)
            dart_code += f"          baseLayer(LayerKind.shape, overrides: {{{props_str}}}),\n"
            
        elif tag == 'circle':
            cx = float(elem.attrib.get('cx', 0))
            cy = float(elem.attrib.get('cy', 0))
            r = float(elem.attrib.get('r', 0))
            fill = elem.attrib.get('fill', '#FFFFFF')
            
            color_str = get_color(fill)
            if fill == 'none':
                stroke = elem.attrib.get('stroke', '#FFFFFF')
                color_str = get_color(stroke)
            
            props = [
                f"'x': {p(cx - r, width)}",
                f"'y': {p(cy - r, height)}",
                f"'w': {p(r*2, width)}",
                f"'h': {p(r*2, height)}",
                f"'color': {color_str}",
                f"'shape': 'circle'"
            ]
            
            props_str = ", ".join(props)
            dart_code += f"          baseLayer(LayerKind.shape, overrides: {{{props_str}}}),\n"
            
        elif tag == 'line':
            x1 = float(elem.attrib.get('x1', 0))
            y1 = float(elem.attrib.get('y1', 0))
            x2 = float(elem.attrib.get('x2', 0))
            y2 = float(elem.attrib.get('y2', 0))
            stroke = elem.attrib.get('stroke', '#FFFFFF')
            sw = float(elem.attrib.get('stroke-width', 1))
            
            color_str = get_color(stroke)
            
            w_p = p(x2-x1, width) if x2>x1 else p(sw, width)
            h_p = p(sw, height) if y2==y1 else p(y2-y1, height)
            
            props = [
                f"'x': {p(x1, width)}",
                f"'y': {p(y1, height)}",
                f"'w': {w_p}",
                f"'h': {h_p}",
                f"'color': {color_str}"
            ]
            
            props_str = ", ".join(props)
            dart_code += f"          baseLayer(LayerKind.divider, overrides: {{{props_str}}}),\n"

    dart_code += "        ],\n      ),\n    ),\n"

dart_code += "  ];\n}\n"

out_dir = '/Users/radhikamac/backup2/car-play-cursor/lib/data/catalog'
os.makedirs(out_dir, exist_ok=True)
with open(f'{out_dir}/apex_templates.dart', 'w') as f:
    f.write(dart_code)
print("Dart generation done")
