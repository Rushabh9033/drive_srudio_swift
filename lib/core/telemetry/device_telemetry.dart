import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/catalog/catalog.dart';
import '../../data/store/app_store.dart';
import '../audio/tone_player.dart';
import 'telemetry_snapshot.dart';

export 'telemetry_snapshot.dart';

/// Single source of truth for live **iPhone** (and Android) phone signals.
///
/// **Honest scope — end user's physical iPhone is the live data source**
/// - Battery % + charging: real via `battery_plus` on iOS 15+ / Android
///   (`UIDevice` battery monitoring). Not reliable on web/Windows preview.
/// - Clock/date: system [DateTime] (owned by canvas clock tick) — always live.
/// - Car link: **manual "Car connected" toggle** is the reliable path on iPhone.
///   Android may also auto-set via `ConnectivityResult.bluetooth`.
///   `connectivity_plus` does **not** report bluetooth on iOS — we never fake
///   a CarPlay session API.
/// - Network online/offline: `connectivity_plus` wifi/cellular/etc. (iOS 15+).
/// - GPS speed: real via `geolocator` on iOS/Android when live data + location
///   permission are granted. Web/Windows preview stays "—" / Unavailable.
/// - Home Screen WidgetKit / CarPlay dashboard: Mac-gated native later; App Group
///   JSON still mirrors this telemetry from the iPhone app for that build.
class DeviceTelemetry extends ChangeNotifier {
  DeviceTelemetry({
    Battery? battery,
    Connectivity? connectivity,
    TonePlayer? tonePlayer,
  }) : _battery = battery ?? Battery(),
       _connectivity = connectivity ?? Connectivity(),
       _tonePlayerOverride = tonePlayer;

  final Battery _battery;
  final Connectivity _connectivity;
  final TonePlayer? _tonePlayerOverride;

  AppStore? _store;
  StreamSubscription<BatteryState>? _battStateSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<Position>? _posSub;
  Timer? _pollTimer;

  int _batteryPercent = 0;
  bool _isCharging = false;
  bool _batteryKnown = false;
  bool _btProxyConnected = false;
  bool _networkOnline = true;
  double? _speedKmh;
  bool _speedKnown = false;
  bool? _lastCarConnected;
  bool _started = false;
  bool _gpsStarting = false;

  /// True when the platform can deliver real battery / connectivity / GPS plugins.
  /// iPhone and Android only — web/Windows/desktop are design preview.
  bool get supportsLiveHardware =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// True on the end-user iPhone (not web, not Android, not desktop).
  bool get isIphone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// `connectivity_plus` reports [ConnectivityResult.bluetooth] on Android
  /// (and Linux), **not** on iOS. iPhone car-link relies on the manual toggle.
  bool get bluetoothProxySupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Stable label for App Group / Settings copy.
  String get liveSourceLabel {
    if (kIsWeb) return 'web-preview';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iphone';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'desktop-preview';
    }
  }

  TelemetrySnapshot get snapshot {
    final store = _store;
    // Live phone sensors only on iOS/Android — never pretend on web/desktop.
    final live =
        supportsLiveHardware &&
        (store?.useLiveDeviceData ?? supportsLiveHardware);
    final manual = store?.manualCarConnected ?? false;

    var car = false;
    var source = CarLinkSource.none;
    // Manual wins — reliable on every platform, especially iPhone.
    if (manual) {
      car = true;
      source = CarLinkSource.manual;
    } else if (live && bluetoothProxySupported && _btProxyConnected) {
      // Android-only auto path. Never pretend BT connectivity works on iOS.
      car = true;
      source = CarLinkSource.bluetoothProxy;
    }

    final useRealBattery = live && _batteryKnown;
    final useRealSpeed = live && _speedKnown && _speedKmh != null;
    return TelemetrySnapshot(
      batteryPercent: useRealBattery ? _batteryPercent.clamp(0, 100) : 0,
      isCharging: useRealBattery ? _isCharging : false,
      batteryKnown: useRealBattery,
      carConnected: car,
      carLinkSource: source,
      networkOnline: _networkOnline,
      liveDataEnabled: live,
      supportsLiveHardware: supportsLiveHardware,
      liveSource: liveSourceLabel,
      bluetoothProxySupported: bluetoothProxySupported,
      speedKmh: useRealSpeed ? _speedKmh : null,
      speedKnown: useRealSpeed,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> start(AppStore store) async {
    if (_started) return;
    _started = true;
    _store = store;
    store.addListener(_onStoreChanged);

    // Defaults: live ON on iPhone/Android, OFF on web / desktop preview.
    if (!store.liveDataPreferenceSet) {
      store.setUseLiveDeviceData(supportsLiveHardware, persistOnly: true);
    } else if (!supportsLiveHardware && store.useLiveDeviceData) {
      // Never keep a stale "live on" preference on preview platforms.
      store.setUseLiveDeviceData(false, persistOnly: true);
    }

    // Plugin reads only where hardware telemetry is supported.
    if (supportsLiveHardware) {
      await _refreshAll();
      try {
        _battStateSub = _battery.onBatteryStateChanged.listen((state) {
          _applyBatteryState(state);
          _emit();
        });
      } catch (e) {
        if (kDebugMode) debugPrint('DeviceTelemetry batt stream: $e');
      }
      try {
        _connSub = _connectivity.onConnectivityChanged.listen((results) {
          _applyConnectivity(results);
          _emit();
        });
      } catch (e) {
        if (kDebugMode) debugPrint('DeviceTelemetry conn stream: $e');
      }
      // iPhone battery % can change without a state event — poll while foreground.
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(_pollBattery());
      });
      if (store.useLiveDeviceData) {
        unawaited(_ensureGpsStream());
      }
    }
    _emit();
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _battStateSub?.cancel();
    await _connSub?.cancel();
    await _stopGpsStream();
    _battStateSub = null;
    _connSub = null;
    _store?.removeListener(_onStoreChanged);
    _started = false;
  }

  void _onStoreChanged() {
    // Prefs toggles (live data / car link / sounds) — rebuild consumers.
    notifyListeners();
    final store = _store;
    if (store != null && store.ready) {
      unawaited(store.mirrorTelemetry(snapshot));
      if (supportsLiveHardware && store.useLiveDeviceData) {
        unawaited(_ensureGpsStream());
      } else {
        unawaited(_stopGpsStream());
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshBatteryLevel(),
      _refreshBatteryState(),
      _refreshConnectivity(),
    ]);
  }

  Future<void> _pollBattery() async {
    await _refreshBatteryLevel();
    _emit();
  }

  Future<void> _refreshBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level >= 0 && level <= 100) {
        _batteryPercent = level;
        _batteryKnown = true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DeviceTelemetry batteryLevel: $e');
    }
  }

  Future<void> _refreshBatteryState() async {
    try {
      final state = await _battery.batteryState;
      _applyBatteryState(state);
    } catch (e) {
      if (kDebugMode) debugPrint('DeviceTelemetry batteryState: $e');
    }
  }

  void _applyBatteryState(BatteryState state) {
    _isCharging = state == BatteryState.charging || state == BatteryState.full;
  }

  Future<void> _refreshConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyConnectivity(results);
    } catch (e) {
      if (kDebugMode) debugPrint('DeviceTelemetry connectivity: $e');
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    // On iOS this stays false forever (plugin never emits bluetooth) — expected.
    _btProxyConnected =
        bluetoothProxySupported &&
        results.contains(ConnectivityResult.bluetooth);
    _networkOnline = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.other,
    );
  }

  /// Start GPS speed stream when permission allows. Never invents speed.
  /// Does not show OS permission dialogs on cold start — that requires
  /// [AppStore.locationConsentGiven] after the in-app Location pre-prompt.
  Future<void> _ensureGpsStream() async {
    if (!supportsLiveHardware || _posSub != null || _gpsStarting) return;
    _gpsStarting = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _clearSpeed();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Only request after explicit in-app consent (Settings live-data toggle).
        if (_store?.locationConsentGiven != true) {
          _clearSpeed();
          return;
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _clearSpeed();
        return;
      }

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        _applyPosition,
        onError: (Object e) {
          if (kDebugMode) debugPrint('DeviceTelemetry GPS stream: $e');
          _clearSpeed();
          _emit();
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('DeviceTelemetry GPS start: $e');
      _clearSpeed();
    } finally {
      _gpsStarting = false;
    }
  }

  Future<void> _stopGpsStream() async {
    await _posSub?.cancel();
    _posSub = null;
    _clearSpeed();
  }

  void _clearSpeed() {
    _speedKmh = null;
    _speedKnown = false;
  }

  void _applyPosition(Position pos) {
    // Geolocator reports speed in m/s. Negative / NaN = unknown — stay honest.
    final mps = pos.speed;
    if (mps.isNaN || mps < 0) {
      _clearSpeed();
      _emit();
      return;
    }
    // Discard wildly inaccurate readings when the platform reports accuracy.
    final acc = pos.speedAccuracy;
    if (!acc.isNaN && acc > 0 && acc > 8) {
      // Keep last known if we had one; otherwise stay unavailable.
      if (!_speedKnown) {
        _emit();
        return;
      }
    }
    _speedKmh = mps * 3.6;
    _speedKnown = true;
    _emit();
  }

  void _emit() {
    final snap = snapshot;
    _maybePlayCarLinkSounds(snap.carConnected);
    notifyListeners();
    final store = _store;
    if (store != null && store.ready) {
      unawaited(store.mirrorTelemetry(snap));
    }
  }

  void _maybePlayCarLinkSounds(bool carConnected) {
    final store = _store;
    if (store == null || !store.playCarLinkSounds) {
      _lastCarConnected = carConnected;
      return;
    }
    final prev = _lastCarConnected;
    _lastCarConnected = carConnected;
    if (prev == null || prev == carConnected) return;

    final id = carConnected ? store.sounds.connect : store.sounds.disconnect;
    if (id == null) return;
    final cue = Catalog.soundById(id);
    if (cue == null) return;
    // Lazy: avoid constructing AudioPlayer during tests / headless start.
    final player = _tonePlayerOverride ?? TonePlayer.instance;
    unawaited(
      player.play(
        id: cue.id,
        freq: cue.freq,
        assetPath: cue.assetPathOrDefault,
        durationMs: cue.durationMs,
        output: store.playbackOutput,
        // Connect cue: car just linked → prefer car route in Auto.
        // Disconnect cue: link just dropped → prefer phone speakers in Auto.
        carConnected: carConnected,
      ),
    );
  }

  /// Test override: inject a battery reading without plugins.
  @visibleForTesting
  void debugSetBattery({required int percent, required bool charging}) {
    _batteryPercent = percent.clamp(0, 100);
    _isCharging = charging;
    _batteryKnown = true;
    _emit();
  }

  @visibleForTesting
  void debugSetConnectivity({required bool bluetooth, required bool online}) {
    _btProxyConnected = bluetooth;
    _networkOnline = online;
    _emit();
  }

  /// Test override: inject GPS speed (km/h) without plugins.
  @visibleForTesting
  void debugSetSpeedKmh(double? kmh) {
    if (kmh == null || kmh.isNaN || kmh < 0) {
      _clearSpeed();
    } else {
      _speedKmh = kmh;
      _speedKnown = true;
    }
    _emit();
  }
}
