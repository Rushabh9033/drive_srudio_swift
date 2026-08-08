import re

with open('lib/presentation/screens/editor_screen.dart', 'r') as f:
    lines = f.readlines()

# The file has a duplicate block inserted.
# We know where `Future<void> _onTextTab() async {` starts.
# Let's find the first instance of `_onTextTab`
idx_text_tab = -1
for i, line in enumerate(lines):
    if 'Future<void> _onTextTab() async {' in line:
        idx_text_tab = i
        break

# The duplicate block starts somewhere around line 569 `final layer = baseLayer(LayerKind.text, overrides: {`
idx_duplicate_start = -1
for i in range(idx_text_tab, len(lines)):
    if 'final cutting = mode != null;' in lines[i]:
        idx_duplicate_start = i
        break

# We know the duplicate block ends where the real `_onWidgetTab` starts.
idx_real_widget_tab = -1
for i in range(idx_duplicate_start, len(lines)):
    if 'Future<void> _onWidgetTab() async {' in lines[i]:
        idx_real_widget_tab = i
        break

if idx_text_tab != -1 and idx_duplicate_start != -1 and idx_real_widget_tab != -1:
    print(f"Found _onTextTab at {idx_text_tab}")
    print(f"Found duplication start at {idx_duplicate_start}")
    print(f"Found real _onWidgetTab at {idx_real_widget_tab}")
    
    # Reconstruct the missing parts of _onTextTab
    missing_part = """      'text': text,
      'x': 12.0,
      'y': 40.0,
      'fontSize': 18.0,
      'weight': result['weight'] as int? ?? 700,
      'color': result['color'] as String? ?? '#F2F5FA',
    }).copyWith(
      shadow: result['shadow'] as bool? ?? false,
      radius: (result['radius'] as num?)?.toDouble() ?? 0,
      color2: result['color2'] as String?,
      shadowColor: result['shadowColor'] as String?,
    );
    _commit(WidgetSpec(
      background: _spec.background,
      layers: [..._spec.layers, layer],
    ));
    setState(() => _selectedId = layer.id);
  }

"""
    # Write the new lines
    new_lines = lines[:idx_duplicate_start] + [missing_part] + lines[idx_real_widget_tab:]
    with open('lib/presentation/screens/editor_screen.dart', 'w') as f:
        f.writelines(new_lines)
    print("Fixed!")
else:
    print("Could not find the indices")
