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
/// Spec layers are included for rich SwiftUI rendering. Flutter asset
/// references (`assets/vehicles/coupe.png`, `assets/backgrounds/...`,
/// etc.) are resolved into `data:image/png;base64,…` URIs via
/// [rootBundle] at JSON-build time so the widget extension can decode
/// them inline without needing filesystem access to the Flutter assets.
Future<Map<String, dynamic>> buildWidgetKitSharedState({
  required List<String?> slots,
  required List<Draft> drafts,
  required Vehicle vehicle,
  required SoundPrefs sounds,
  required bool isPremium,
  TelemetrySnapshot? telemetry,
}) async {
  final byId = {for (final d in drafts) d.id: d};
  // Resolve vehicle.customImage: if it's a Flutter asset path, encode it.
  final customImageDataUri = await _resolveToDataUri(vehicle.customImage);
  return {
    'schemaVersion': appGroupSchemaVersion,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'isPremium': isPremium,
    'vehicle': {
      'brandId': vehicle.brandId,
      'modelId': vehicle.modelId,
      'artwork': vehicle.artwork.name,
      'displayName': vehicle.displayName,
      'hasCustomImage': customImageDataUri != null,
      'customImage': customImageDataUri,
    },
    'sounds': sounds.toJson(),
    if (telemetry != null && !telemetry.isSamplePreview)
      'telemetry': telemetry.toJson(),
    'slots': [
      for (var i = 0; i < 4; i++)
        await _slotPayload(i, slots.length > i ? slots[i] : null, byId),
    ],
  };
}

Future<Map<String, dynamic>> _slotPayload(
  int index,
  String? draftId,
  Map<String, Draft> byId,
) async {
  final draft = draftId == null ? null : byId[draftId];
  final spec = draft == null ? null : await _compactSpec(draft.spec);
  final summary = draft == null ? null : _slotSummary(draft.spec);
  return {
    'index': index,
    'draftId': draftId,
    'name': draft?.name,
    'updatedAt': draft?.updatedAt,
    'summary': summary,
    'spec': spec,
    if (draft?.widgetImagePath != null)
      'widgetImagePath': draft!.widgetImagePath,
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

Future<Map<String, dynamic>> _compactSpec(WidgetSpec spec) async {
  final bg = Map<String, dynamic>.from(spec.background.toJson());
  // Resolve background imageSrc: Flutter asset → data URI; otherwise leave
  // as-is so the V2 writer (native) can copy it through the App Group.
  if (bg['imageSrc'] is String && (bg['imageSrc'] as String).isNotEmpty) {
    final resolved = await _resolveToDataUri(bg['imageSrc'] as String);
    if (resolved != null) bg['imageSrc'] = resolved;
  }
  if (bg['imageSrc'] != null &&
      (bg['imageSrc'] as String).length > 256 * 1024) {
    bg.remove('imageSrc');
    bg['imageOmitted'] = true;
  }

  final layers = <Map<String, dynamic>>[];
  for (final layer in spec.layers) {
    final m = Map<String, dynamic>.from(layer.toJson());
    final src = m['src'] as String?;
    if (src != null && src.isNotEmpty) {
      final resolved = await _resolveToDataUri(src);
      if (resolved != null) m['src'] = resolved;
    }
    final finalSrc = m['src'] as String?;
    if (finalSrc != null && finalSrc.length > 256 * 1024) {
      m.remove('src');
      m['srcOmitted'] = true;
    }
    layers.add(m);
  }

  return {'background': bg, 'layers': layers};
}

/// Resolves a Flutter asset path (`assets/...`) to either:
///   - **Small assets** (≤ 200 KB raw bytes): inline as a base64 data URI.
///     Widget decodes inline. No filesystem coupling.
///   - **Large assets** (> 200 KB raw bytes): keep as `assets/...` path.
///     The native V2 writer (`AppGroupChannel.swift`) copies them through
///     the App Group container so the widget can read them from disk.
///
/// The 200 KB threshold is empirical: body-style heroes (~1 MB) and model
/// heroes (~1 MB) blow past the 256 KB cap and 2 MB total JSON cap. Keeping
/// the path lets the V2 writer handle them via App Group instead.
///
/// Returns the input unchanged for data URIs, HTTP(S) URLs, or anything
/// else the widget extension should handle itself.
Future<String?> _resolveToDataUri(String? src) async {
  if (src == null || src.isEmpty) return src;
  if (src.startsWith('data:')) return src;
  if (src.startsWith('http://') || src.startsWith('https://')) return src;
  if (!src.startsWith('assets/')) return src;
  try {
    final bytes = await rootBundle.load(src);
    final rawLen = bytes.lengthInBytes;
    // Skip encoding for large assets — the native V2 writer will copy them
    // through the App Group container. Keeps the JSON payload small.
    if (rawLen > 200 * 1024) {
      return src;
    }
    final encoded = base64Encode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return 'data:image/png;base64,$encoded';
  } catch (e) {
    if (kDebugMode) debugPrint('Failed to load Flutter asset $src: $e');
    return null;
  }
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
