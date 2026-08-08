import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/telemetry/telemetry_snapshot.dart';
import '../models/models.dart';

/// SharedPreferences key used as a stand-in for App Group UserDefaults on
/// platforms where WidgetKit is unavailable (Windows/web). On iOS Wave 2,
/// native code reads the same JSON shape from the App Group container.
const appGroupMirrorKey = 'group.com.drivestudio.shared/widget_state_v1';

/// Locked App Group identifiers — keep in sync with
/// `ios/Runner/AppGroup/AppGroupContract.swift`.
const appGroupSuiteName = 'group.com.drivestudio.shared';
const appGroupStateKey = 'widget_state_v1';
const appGroupSchemaVersion = 1;

/// Soft cap so WidgetKit timelines stay lean (~2 MB).
const appGroupMaxJsonBytes = 2 * 1024 * 1024;

const _channel = MethodChannel('drive_studio/app_group');

/// Builds the exact JSON contract WidgetKit will consume.
///
/// When the Flutter app runs on the user's **iPhone**, [telemetry] carries
/// live battery / charging / car-link / network from that device so a future
/// Mac-built WidgetKit extension can render without inventing values.
///
/// Spec layers are included for rich SwiftUI rendering. Large image `src` /
/// `imageSrc` data-URLs are stripped so the payload stays under the soft cap.
Map<String, dynamic> buildWidgetKitSharedState({
  required List<String?> slots,
  required List<Draft> drafts,
  required Vehicle vehicle,
  required SoundPrefs sounds,
  required bool isPremium,
  TelemetrySnapshot? telemetry,
}) {
  final byId = {for (final d in drafts) d.id: d};
  return {
    'schemaVersion': appGroupSchemaVersion,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'isPremium': isPremium,
    'vehicle': {
      'brandId': vehicle.brandId,
      'modelId': vehicle.modelId,
      'artwork': vehicle.artwork.name,
      'displayName': vehicle.displayName,
      'hasCustomImage': vehicle.customImage != null,
      'customImage': vehicle.customImage,
    },
    'sounds': sounds.toJson(),
    if (telemetry != null && !telemetry.isSamplePreview)
      'telemetry': telemetry.toJson(),
    'slots': [
      for (var i = 0; i < 4; i++)
        _slotPayload(i, slots.length > i ? slots[i] : null, byId),
    ],
  };
}

Map<String, dynamic> _slotPayload(
  int index,
  String? draftId,
  Map<String, Draft> byId,
) {
  final draft = draftId == null ? null : byId[draftId];
  final spec = draft == null ? null : _compactSpec(draft.spec);
  final summary = draft == null ? null : _slotSummary(draft.spec);
  return {
    'index': index,
    'draftId': draftId,
    'name': draft?.name,
    'updatedAt': draft?.updatedAt,
    'summary': summary,
    'spec': spec,
  };
}

/// Lightweight fields WidgetKit can render without parsing every layer.
Map<String, dynamic> _slotSummary(WidgetSpec spec) {
  String? title;
  String? clockFormat;
  String? dateFormat;
  String? badge;
  String bgFrom = spec.background.from;
  String? bgTo = spec.background.to;

  for (final layer in spec.layers) {
    if (layer.hidden) continue;
    switch (layer.kind) {
      case LayerKind.text:
        title ??= layer.text.trim().isEmpty ? layer.label : layer.text.trim();
      case LayerKind.clock:
        clockFormat ??= 'HH:mm';
      case LayerKind.date:
        dateFormat ??= 'E, d MMM';
      case LayerKind.badge:
        badge ??= layer.text.trim().isEmpty ? 'LIVE' : layer.text.trim();
      case LayerKind.image:
      case LayerKind.divider:
      case LayerKind.shape:
      case LayerKind.draw:
        break;
      case LayerKind.battery:
        // Never mirror invented template % into WidgetKit summary.
        badge ??= 'Battery';
      case LayerKind.analog:
        clockFormat ??= 'analog';
    }
  }

  return {
    'title': title,
    'clockFormat': clockFormat,
    'dateFormat': dateFormat,
    'badge': badge,
    'bgFrom': bgFrom,
    'bgTo': bgTo,
    'bgType': spec.background.type.name,
  };
}

Map<String, dynamic> _compactSpec(WidgetSpec spec) {
  final bg = Map<String, dynamic>.from(spec.background.toJson());
  final imageSrc = bg['imageSrc'] as String?;
  if (imageSrc != null && imageSrc.length > 256 * 1024) {
    bg.remove('imageSrc');
    bg['imageOmitted'] = true;
  }

  final layers = <Map<String, dynamic>>[];
  for (final layer in spec.layers) {
    final m = Map<String, dynamic>.from(layer.toJson());
    final src = m['src'] as String?;
    if (src != null && src.length > 256 * 1024) {
      m.remove('src');
      m['srcOmitted'] = true;
    }
    layers.add(m);
  }

  return {'background': bg, 'layers': layers};
}

/// Validates required top-level keys before mirroring / bridging.
bool validateAppGroupPayload(Map<String, dynamic> payload) {
  if (payload['schemaVersion'] != appGroupSchemaVersion) return false;
  if (payload['updatedAt'] is! String) return false;
  if (payload['isPremium'] is! bool) return false;
  if (payload['vehicle'] is! Map) return false;
  if (payload['sounds'] is! Map) return false;
  final slots = payload['slots'];
  if (slots is! List || slots.length != 4) return false;
  for (final s in slots) {
    if (s is! Map) return false;
    if (s['index'] is! int && s['index'] is! num) return false;
  }
  return true;
}

String encodeAppGroupPayload(Map<String, dynamic> payload) {
  if (!validateAppGroupPayload(payload)) {
    throw const FormatException('Invalid App Group payload');
  }
  final raw = jsonEncode(payload);
  final bytes = utf8.encode(raw).length;
  if (bytes > appGroupMaxJsonBytes) {
    // Strip specs, keep summaries — still useful for WidgetKit title/clock.
    final slim = Map<String, dynamic>.from(payload);
    final slots = (slim['slots'] as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      m.remove('spec');
      return m;
    }).toList();
    slim['slots'] = slots;
    slim['trimmed'] = true;
    return jsonEncode(slim);
  }
  return raw;
}

Future<void> writeAppGroupMirror(Map<String, dynamic> payload) async {
  try {
    final encoded = encodeAppGroupPayload(payload);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appGroupMirrorKey, encoded);
    await _bridgeToNative(encoded);
  } catch (e) {
    if (kDebugMode) debugPrint('App Group mirror write failed: $e');
  }
}

/// Best-effort MethodChannel → App Group UserDefaults + WidgetCenter reload.
/// No-op when the native handler is not registered (Windows / web / unlinked).
Future<void> _bridgeToNative(String json) async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await _channel.invokeMethod<void>('syncState', {'json': json});
    await _channel.invokeMethod<void>('reloadWidgets');
  } on MissingPluginException {
    // Expected until Wave 2 wires AppDelegate.
  } on PlatformException catch (e) {
    if (kDebugMode) debugPrint('App Group bridge: ${e.message}');
  }
}
