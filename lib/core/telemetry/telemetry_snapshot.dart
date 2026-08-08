import '../../data/models/models.dart';

/// How [TelemetrySnapshot.carConnected] was decided.
enum CarLinkSource {
  /// User toggled "Car connected" in Settings.
  manual,

  /// Best-effort proxy: Bluetooth connectivity path (not a CarPlay session).
  bluetoothProxy,

  /// Live mode off or no signal.
  none,
}

/// Immutable sample of phone-side signals widgets can bind to.
///
/// On the end-user iPhone this is the live source mirrored into App Group JSON
/// for a future WidgetKit build — not a live CarPlay dashboard by itself.
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.batteryPercent,
    required this.isCharging,
    required this.batteryKnown,
    required this.carConnected,
    required this.carLinkSource,
    required this.networkOnline,
    required this.liveDataEnabled,
    required this.supportsLiveHardware,
    required this.updatedAt,
    this.liveSource = 'preview',
    this.bluetoothProxySupported = false,
    this.carLinkLabel = 'Phone ↔ Car link',
    this.speedKmh,
    this.speedKnown = false,
  });

  /// Real battery % when [batteryKnown]; otherwise unused (do not display as live).
  final int batteryPercent;
  final bool isCharging;
  final bool batteryKnown;
  final bool carConnected;
  final CarLinkSource carLinkSource;
  final bool networkOnline;
  final bool liveDataEnabled;
  final bool supportsLiveHardware;

  /// `iphone` | `android` | `web-preview` | `desktop-preview` | `sample-preview`
  final String liveSource;

  /// Whether auto car-link via connectivity bluetooth can fire (Android only).
  final bool bluetoothProxySupported;
  final DateTime updatedAt;
  final String carLinkLabel;

  /// Ground speed in km/h when [speedKnown]; otherwise unused (show "—").
  final double? speedKmh;

  /// True only when a real GPS fix supplied a usable speed (never invent).
  final bool speedKnown;

  /// True when this snapshot is catalog/grid display-only (never App Group / live).
  bool get isSamplePreview => liveSource == 'sample-preview';

  Map<String, dynamic> toJson() => {
    'batteryPercent': batteryKnown ? batteryPercent : null,
    'isCharging': batteryKnown ? isCharging : false,
    'batteryKnown': batteryKnown,
    'carConnected': carConnected,
    'carLinkSource': carLinkSource.name,
    'networkOnline': networkOnline,
    'liveDataEnabled': liveDataEnabled,
    'supportsLiveHardware': supportsLiveHardware,
    'liveSource': liveSource,
    'bluetoothProxySupported': bluetoothProxySupported,
    'carLinkLabel': carLinkLabel,
    'speedKmh': speedKnown ? speedKmh : null,
    'speedKnown': speedKnown,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// Stable display-only fill for Studio stock tiles, Home rails, and template
/// thumbs. Never mirrored into App Group JSON or used on the editor / live path.
const int kSamplePreviewBatteryPercent = 72;

/// Fixed stamp so sample previews do not drift between frames or rebuilds.
final TelemetrySnapshot samplePreviewTelemetry = TelemetrySnapshot(
  batteryPercent: kSamplePreviewBatteryPercent,
  isCharging: false,
  batteryKnown: true,
  carConnected: true,
  carLinkSource: CarLinkSource.manual,
  networkOnline: true,
  liveDataEnabled: true,
  supportsLiveHardware: true,
  liveSource: 'sample-preview',
  bluetoothProxySupported: false,
  speedKmh: kSamplePreviewSpeedKmh.toDouble(),
  speedKnown: true,
  updatedAt: DateTime.utc(2026, 1, 15, 12),
);

/// Resolve battery percent for a layer from live telemetry only.
///
/// Returns `null` when phone battery is unavailable (show "—" / Unavailable).
/// [dayprogress] uses system clock (real), not device battery.
/// Never invents a charge level — sample fill belongs in [resolveDisplayBatteryPercent].
int? resolveLiveBatteryPercent(
  Layer layer,
  TelemetrySnapshot? telemetry, [
  DateTime? now,
]) {
  if (layer.format == 'dayprogress') {
    final n = now ?? DateTime.now();
    final elapsed = n.hour * 3600 + n.minute * 60 + n.second;
    return ((elapsed / 86400) * 100).round().clamp(0, 100);
  }

  final live =
      telemetry != null &&
      telemetry.liveDataEnabled &&
      telemetry.batteryKnown &&
      !telemetry.isSamplePreview;
  if (live) {
    return telemetry.batteryPercent.clamp(0, 100);
  }
  return null;
}

/// Display-path battery %: sample fill when [samplePreview], else live-only.
///
/// [samplePreview] is for Studio / Home / template thumbnails only.
int? resolveDisplayBatteryPercent(
  Layer layer,
  TelemetrySnapshot? telemetry, {
  DateTime? now,
  bool samplePreview = false,
}) {
  if (layer.format == 'dayprogress') {
    return resolveLiveBatteryPercent(layer, telemetry, now);
  }
  if (samplePreview) {
    final snap = telemetry?.isSamplePreview == true
        ? telemetry!
        : samplePreviewTelemetry;
    return snap.batteryPercent.clamp(0, 100);
  }
  return resolveLiveBatteryPercent(layer, telemetry, now);
}

/// Status badge / pill label bound to telemetry ([Layer.format] or role).
String? telemetryStatusLabel(Layer layer, TelemetrySnapshot snap) {
  final key = layer.format.isNotEmpty
      ? layer.format
      : (layer.role.startsWith('telemetry:')
            ? layer.role.substring('telemetry:'.length)
            : '');
  switch (key) {
    case 'carlink':
    case 'car-link':
      return snap.carConnected ? 'Car link · on' : 'Car link · off';
    case 'batterylive':
    case 'battery-live':
      if (snap.liveDataEnabled && snap.batteryKnown) {
        return 'Battery ${snap.batteryPercent}%';
      }
      return 'Battery · unavailable';
    case 'charging':
      if (snap.liveDataEnabled && snap.batteryKnown) {
        return snap.isCharging ? 'Charging' : 'On battery';
      }
      return 'Charge · unavailable';
    case 'network':
      return snap.networkOnline ? 'Online' : 'Offline';
    case 'gpsspeed':
    case 'gps-speed':
    case 'speed':
      if (snap.isSamplePreview) {
        return '$kSamplePreviewSpeedKmh km/h';
      }
      if (snap.liveDataEnabled && snap.speedKnown && snap.speedKmh != null) {
        return '${snap.speedKmh!.round().clamp(0, 999)} km/h';
      }
      return 'GPS · unavailable';
    default:
      return null;
  }
}

/// Sample speed for Studio / Home thumbs only — never App Group live path.
const int kSamplePreviewSpeedKmh = 64;

/// Large speed digits for [Layer.format] `gpsspeed` text layers.
String resolveSpeedDigits(
  TelemetrySnapshot? telemetry, {
  bool samplePreview = false,
}) {
  if (samplePreview || telemetry?.isSamplePreview == true) {
    return '$kSamplePreviewSpeedKmh';
  }
  if (telemetry != null &&
      telemetry.liveDataEnabled &&
      telemetry.speedKnown &&
      telemetry.speedKmh != null) {
    return '${telemetry.speedKmh!.round().clamp(0, 999)}';
  }
  return '—';
}
