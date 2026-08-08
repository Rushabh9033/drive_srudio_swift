import 'package:drive_studio/data/catalog/catalog.dart';
void main() {
  final t = Catalog.templates.firstWhere((t) => t.id == 'battery-bars');
  for (var l in t.spec.layers) {
    print('layer: format=${l.format}, role=${l.role}, text=${l.text}');
  }
}
