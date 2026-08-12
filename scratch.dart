import 'dart:convert';
import 'lib/data/catalog/apex_templates.dart';

void main() {
  final templates = buildApexWidgetTemplates();
  print('// AUTO-GENERATED APEX MOCKUPS');
  print('enum ApexMockups {');
  print('  static let specs: [String] = [');
  for (final t in templates) {
    final specJson = jsonEncode(t.spec.toJson());
    // Escape quotes for Swift string literal
    final escaped = specJson.replaceAll('"', '\\"');
    print('    """');
    print('    $specJson');
    print('    """,');
  }
  print('  ]');
  print('}');
}
