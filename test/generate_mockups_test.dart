import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/data/catalog/apex_templates.dart';

void main() {
  test('generate mockups', () {
    final templates = buildApexWidgetTemplates();
    print('// AUTO-GENERATED APEX MOCKUPS');
    print('enum ApexMockups {');
    print('  static let specs: [String] = [');
    for (final t in templates) {
      final specJson = jsonEncode(t.spec.toJson());
      final escaped = specJson.replaceAll('"', '\\"');
      print('    """');
      print('    $escaped');
      print('    """,');
    }
    print('  ]');
    print('}');
  });
}
