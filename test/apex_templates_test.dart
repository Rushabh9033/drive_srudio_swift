import 'dart:convert';

import 'package:drive_studio/data/catalog/apex_templates.dart';
import 'package:drive_studio/data/catalog/catalog.dart';
import 'package:drive_studio/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apex executable V2 catalogue', () {
    test('contains 12 unique editable templates with a free/premium mix', () {
      final templates = buildApexWidgetTemplates();

      expect(templates, hasLength(12));
      expect(templates.map((template) => template.id).toSet(), hasLength(12));
      expect(templates.map((template) => template.name).toSet(), hasLength(12));
      expect(
        templates.every((template) => template.category == 'Apex'),
        isTrue,
      );
      expect(templates.any((template) => template.premium), isTrue);
      expect(templates.any((template) => !template.premium), isTrue);
    });

    test('is integrated without replacing the existing stock catalogue', () {
      final apexIds = buildApexWidgetTemplates()
          .map((template) => template.id)
          .toSet();
      final catalogIds = Catalog.templates
          .map((template) => template.id)
          .toSet();

      expect(Catalog.categories, contains(apexTemplateCategory));
      expect(catalogIds, containsAll(apexIds));
      expect(catalogIds, contains('battery-panel'));
      expect(catalogIds, contains('blank'));
    });

    test('uses only layer kinds implemented by both current renderers', () {
      const supported = {
        LayerKind.text,
        LayerKind.clock,
        LayerKind.date,
        LayerKind.battery,
        LayerKind.divider,
        LayerKind.shape,
      };

      for (final template in buildApexWidgetTemplates()) {
        expect(template.spec.layers, isNotEmpty, reason: template.id);
        for (final layer in template.spec.layers) {
          expect(
            supported,
            contains(layer.kind),
            reason: '${template.id}/${layer.label}',
          );
        }
      }
    });

    test('contains no unsupported or excluded runtime bindings', () {
      final forbidden = RegExp(
        r'weather|temperature|cabin|vehicle|spotify|obd|oem|telemetry:',
        caseSensitive: false,
      );

      for (final template in buildApexWidgetTemplates()) {
        expect(forbidden.hasMatch(template.id), isFalse, reason: template.id);
        expect(forbidden.hasMatch(template.name), isFalse, reason: template.id);

        for (final layer in template.spec.layers) {
          expect(layer.role, isEmpty, reason: '${template.id}/${layer.label}');
          expect(
            forbidden.hasMatch('${layer.label} ${layer.text} ${layer.format}'),
            isFalse,
            reason: '${template.id}/${layer.label}',
          );
        }
      }
    });

    test('dynamic layers never carry hard-coded runtime values', () {
      final templates = buildApexWidgetTemplates();

      for (final template in templates) {
        final dynamicLayers = template.spec.layers.where(
          (layer) =>
              layer.kind == LayerKind.clock ||
              layer.kind == LayerKind.date ||
              layer.kind == LayerKind.battery,
        );
        expect(dynamicLayers, isNotEmpty, reason: template.id);
        for (final layer in dynamicLayers) {
          expect(layer.text, isEmpty, reason: '${template.id}/${layer.label}');
          expect(
            layer.animate,
            isFalse,
            reason: '${template.id}/${layer.label}',
          );
          expect(
            layer.animStyle,
            isEmpty,
            reason: '${template.id}/${layer.label}',
          );
        }
      }
    });

    test('all geometry is positive and contained in the 0-100 canvas', () {
      for (final template in buildApexWidgetTemplates()) {
        for (final layer in template.spec.layers) {
          expect(layer.x, inInclusiveRange(0, 100), reason: template.id);
          expect(layer.y, inInclusiveRange(0, 100), reason: template.id);
          expect(layer.w, greaterThan(0), reason: template.id);
          expect(layer.h, greaterThan(0), reason: template.id);
          expect(
            layer.x + layer.w,
            lessThanOrEqualTo(100),
            reason: template.id,
          );
          expect(
            layer.y + layer.h,
            lessThanOrEqualTo(100),
            reason: template.id,
          );
        }
      }
    });

    test('template layouts are distinct', () {
      String signature(TemplateItem template) {
        final layers = template.spec.layers.map(
          (layer) => [
            layer.kind.name,
            layer.x,
            layer.y,
            layer.w,
            layer.h,
            layer.fontSize,
            layer.color,
          ].join(':'),
        );
        return layers.join('|');
      }

      final signatures = buildApexWidgetTemplates().map(signature).toList();
      expect(signatures.toSet(), hasLength(signatures.length));
    });

    test('every template survives the production JSON round trip', () {
      for (final template in buildApexWidgetTemplates()) {
        final encoded = jsonEncode(template.spec.toJson());
        final decoded = WidgetSpec.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );

        expect(decoded.layers, hasLength(template.spec.layers.length));
        expect(decoded.background.from, template.spec.background.from);
        expect(decoded.background.to, template.spec.background.to);
        expect(
          decoded.layers.map((layer) => layer.kind).toList(),
          template.spec.layers.map((layer) => layer.kind).toList(),
        );
      }
    });
  });
}
