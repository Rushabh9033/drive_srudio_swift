import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/core/telemetry/device_telemetry.dart';
import 'package:drive_studio/core/telemetry/telemetry_snapshot.dart';
import 'package:drive_studio/presentation/widgets/stock_layer_painters.dart';
import 'package:provider/provider.dart';

class MockCanvas extends Fake implements Canvas {
  final List<RRect> rrects = [];
  
  @override
  void drawRRect(RRect rrect, Paint paint) {
    rrects.add(rrect);
  }
  
  @override
  void drawTextBlob(dynamic textBlob, Offset offset, Paint paint) {}
  
  @override
  void drawParagraph(dynamic paragraph, Offset offset) {}
}

void main() {
  testWidgets('Phone Bars: battery-bars contract', (WidgetTester tester) async {
    final t = Catalog.templates.firstWhere((t) => t.id == 'battery-bars');
    
    final layer = t.spec.layers.firstWhere((l) => l.role == 'telemetry:phone:batt');
    expect(layer.format, 'bars');
    
    final labelLayer = t.spec.layers.firstWhere((l) => l.text == 'PHONE LEVEL');
    expect(labelLayer, isNotNull);
    
    expect(layer.w, isPositive);
    expect(layer.h, isPositive);
    
    final snapshot = TelemetrySnapshot(
      batteryPercent: 75,
      isCharging: false,
      batteryKnown: true,
      carConnected: true,
      carLinkSource: CarLinkSource.manual,
      networkOnline: true,
      liveDataEnabled: true,
      supportsLiveHardware: true,
      updatedAt: DateTime.now(),
    );
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Provider<TelemetrySnapshot>.value(
          value: snapshot,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: BatteryLayerView(
                layer: layer,
                now: DateTime.now(),
                samplePreview: false,
              ),
            ),
          ),
        ),
      ),
    ));
    
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    CustomPainter? targetPainter;
    for (final p in paints) {
      if (p.painter != null && p.painter.toString().contains('BatteryPainter')) {
        targetPainter = p.painter;
        break;
      }
    }
    expect(targetPainter, isNotNull);
    
    final mockCanvas = MockCanvas();
    targetPainter!.paint(mockCanvas, const Size(200, 200));
    
    expect(mockCanvas.rrects.length, 8);
    for (int i = 1; i < mockCanvas.rrects.length; i++) {
      expect(mockCanvas.rrects[i].left, greaterThan(mockCanvas.rrects[i-1].left));
    }
    
    final jsonStr = t.spec.toJson().toString();
    expect(jsonStr.contains('%'), isFalse);
    expect(jsonStr.contains('75'), isFalse);
  });
}
