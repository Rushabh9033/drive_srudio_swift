import 'dart:convert';
import 'dart:io';

void main() {
  final lines = File('test_output_proof.json').readAsLinesSync();
  int totalCount = 0;
  int passCount = 0;
  int failCount = 0;
  final countsPerFile = <String, int>{};

  for (final line in lines) {
    if (line.isEmpty) continue;
    if (line.startsWith('[')) continue; // ignore non-json lines
    try {
      final json = jsonDecode(line);
      if (json['type'] == 'testStart') {
        final testName = json['test']['name'] as String;
        if (!testName.startsWith('loading ') &&
            !testName.contains('(setUpAll)')) {
          totalCount++;
          final url = json['test']['url'] as String?;
          if (url != null) {
            final fileName = url.split('/').last;
            countsPerFile[fileName] = (countsPerFile[fileName] ?? 0) + 1;
          }
        }
      }
      if (json['type'] == 'testDone') {
        if (json['result'] == 'success')
          passCount++;
        else
          failCount++;
      }
    } catch (e) {
      // ignore
    }
  }

  print('Total valid tests: $totalCount');
  countsPerFile.forEach((k, v) => print('$k: $v'));
}
