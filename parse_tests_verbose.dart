import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('test_output_proof.json');
  final lines = file.readAsLinesSync();
  
  Map<int, String> testNames = {};
  Map<int, String> testUrls = {};
  int passed = 0;
  
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line);
      if (json['type'] == 'testStart') {
        final t = json['test'];
        testNames[t['id']] = t['name'];
        if (t['root_url'] != null) {
          testUrls[t['id']] = t['root_url'];
        } else if (t['url'] != null) {
          testUrls[t['id']] = t['url'];
        }
      } else if (json['type'] == 'testDone') {
        if (json['result'] == 'success') {
          final tId = json['testID'];
          if (testNames[tId] != null && !testNames[tId]!.startsWith('loading ')) {
            passed++;
          }
        }
      }
    } catch (_) {}
  }
  
  print('Total tests passed: $passed');
  print('Exact names:');
  
  // Group by URL
  Map<String, List<String>> byFile = {};
  for (final id in testNames.keys) {
    final name = testNames[id]!;
    if (name.startsWith('loading ')) continue;
    final url = testUrls[id] ?? 'unknown';
    byFile.putIfAbsent(url, () => []).add(name);
  }
  
  for (final url in byFile.keys) {
    print('\n$url (${byFile[url]!.length} tests):');
    for (final name in byFile[url]!) {
      print('  - $name');
    }
  }
}
