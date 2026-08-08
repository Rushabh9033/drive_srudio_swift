import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/audio/playback_output.dart';
import '../../core/telemetry/telemetry_snapshot.dart';
import '../catalog/catalog.dart';
import '../models/models.dart';
import 'app_group_export.dart';

const _storageKey = 'drive-studio-state-v1';
const _uuid = Uuid();

class AppStore extends ChangeNotifier {
  bool ready = false;
  bool introDone = false;
  List<Draft> drafts = [];
  List<String?> slots = [null, null, null, null];
  Vehicle vehicle = Vehicle(
    brandId: 'aurelio',
    modelId: 'aurelio-gt',
    artwork: ArtworkKind.coupe,
  );
  SoundPrefs sounds = SoundPrefs(
    connect: '01_connect_welcome_back',
    disconnect: '06_disconnect_goodbye',
  );
  int lastLocalSync = 0;
  String? lastEditedDraftId;
  bool isPremium = false;
  int corruptDraftSkips = 0;
  bool howToSeen = false;

  /// When true, widgets bind battery / car-link / network from [DeviceTelemetry].
  /// Default: ON on iPhone/Android, OFF on web/desktop preview (set in hydrate /
  /// [DeviceTelemetry.start] if the user has not chosen yet).
  bool useLiveDeviceData =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether the user (or first-run default) has set [useLiveDeviceData].
  bool liveDataPreferenceSet = false;

  /// User accepted the in-app Location pre-prompt (may still deny OS dialog).
  /// Cold-start GPS must not request OS permission until this is true.
  bool locationConsentGiven = false;

  /// Manual "Car connected" override (Phone ↔ Car link proxy).
  bool manualCarConnected = false;

  /// Play connect/disconnect cues when [carConnected] flips.
  bool playCarLinkSounds = true;

  /// Phone speakers / car Bluetooth / auto (car when linked).
  PlaybackOutput playbackOutput = PlaybackOutput.auto;

  /// Latest telemetry mirrored into App Group JSON (no UI notify on write).
  TelemetrySnapshot? lastTelemetry;

  bool canUsePremiumContent(bool requiresPremium) =>
      !requiresPremium || isPremium;

  Future<void> hydrate() async {
    if (ready) return;
    corruptDraftSkips = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        introDone = map['introDone'] as bool? ?? false;
        final parsed = <Draft>[];
        for (final e in (map['drafts'] as List? ?? [])) {
          try {
            if (e is! Map) {
              corruptDraftSkips++;
              continue;
            }
            parsed.add(Draft.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {
            corruptDraftSkips++;
          }
        }
        drafts = parsed;
        final slotRaw = map['slots'] as List? ?? [null, null, null, null];
        slots = List<String?>.from(slotRaw.map((e) => e as String?));
        while (slots.length < 4) {
          slots.add(null);
        }
        // Drop slot refs that point at missing/corrupt drafts.
        final ids = drafts.map((d) => d.id).toSet();
        slots = slots
            .map((s) => s != null && ids.contains(s) ? s : null)
            .toList();
        vehicle = Vehicle.fromJson(
          Map<String, dynamic>.from(map['vehicle'] as Map? ?? {}),
        );
        sounds = SoundPrefs.fromJson(
          Map<String, dynamic>.from(map['sounds'] as Map? ?? {}),
        );
        lastLocalSync =
            map['lastLocalSync'] as int? ?? map['lastRefresh'] as int? ?? 0;
        lastEditedDraftId = map['lastEditedDraftId'] as String?;
        isPremium = map['isPremium'] as bool? ?? false;
        howToSeen = map['howToSeen'] as bool? ?? false;
        liveDataPreferenceSet = map['liveDataPreferenceSet'] as bool? ?? false;
        if (liveDataPreferenceSet) {
          useLiveDeviceData = map['useLiveDeviceData'] as bool? ?? true;
        }
        locationConsentGiven = map['locationConsentGiven'] as bool? ?? false;
        manualCarConnected = map['manualCarConnected'] as bool? ?? false;
        playCarLinkSounds = map['playCarLinkSounds'] as bool? ?? true;
        playbackOutput = playbackOutputFromJson(
          map['playbackOutput'] as String?,
        );
        if (!isPremium) {
          _stripPremiumSoundAssignments();
        }
      }
    } catch (_) {
      // Full blob corrupt — start clean rather than crash.
      drafts = [];
      slots = [null, null, null, null];
    }
    ready = true;
    lastLocalSync = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'introDone': introDone,
        'drafts': drafts.map((d) => d.toJson()).toList(),
        'slots': slots,
        'vehicle': vehicle.toJson(),
        'sounds': sounds.toJson(),
        'lastLocalSync': lastLocalSync,
        'lastEditedDraftId': lastEditedDraftId,
        'isPremium': isPremium,
        'howToSeen': howToSeen,
        'useLiveDeviceData': useLiveDeviceData,
        'liveDataPreferenceSet': liveDataPreferenceSet,
        'locationConsentGiven': locationConsentGiven,
        'manualCarConnected': manualCarConnected,
        'playCarLinkSounds': playCarLinkSounds,
        'playbackOutput': playbackOutputToJson(playbackOutput),
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
      // Keep App Group mirror in sync for future WidgetKit consumers.
      await writeAppGroupMirror(await buildAppGroupPayload());
    } catch (_) {}
  }

  /// Payload contract shared with iOS WidgetKit via App Group (see README_IOS_NATIVE.md).
  Future<Map<String, dynamic>> buildAppGroupPayload() async {
    return buildWidgetKitSharedState(
      slots: slots,
      drafts: drafts,
      vehicle: vehicle,
      sounds: sounds,
      isPremium: isPremium,
      telemetry: lastTelemetry,
    );
  }

  /// Called by [DeviceTelemetry] — writes App Group only (no [notifyListeners]).
  Future<void> mirrorTelemetry(TelemetrySnapshot snap) async {
    lastTelemetry = snap;
    try {
      await writeAppGroupMirror(await buildAppGroupPayload());
    } catch (_) {}
  }

  void setUseLiveDeviceData(bool value, {bool persistOnly = false}) {
    useLiveDeviceData = value;
    liveDataPreferenceSet = true;
    if (persistOnly) {
      _persist();
      return;
    }
    _commit();
  }

  void setLocationConsentGiven(bool value, {bool persistOnly = false}) {
    locationConsentGiven = value;
    if (persistOnly) {
      _persist();
      return;
    }
    _commit();
  }

  void setManualCarConnected(bool value) {
    manualCarConnected = value;
    _commit();
  }

  void setPlayCarLinkSounds(bool value) {
    playCarLinkSounds = value;
    _commit();
  }

  void setPlaybackOutput(PlaybackOutput value) {
    playbackOutput = value;
    _commit();
  }

  /// Effective route for previews / car-link cues given current telemetry.
  ResolvedPlaybackRoute resolvedPlaybackRoute({required bool carConnected}) {
    return resolvePlaybackRoute(
      preference: playbackOutput,
      carConnected: carConnected,
    );
  }

  void _commit() {
    lastLocalSync = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _persist();
  }

  void completeIntro() {
    introDone = true;
    _commit();
  }

  void markHowToSeen() {
    howToSeen = true;
    _commit();
  }

  void resetIntro() {
    introDone = false;
    _commit();
  }

  void setPremium(bool value) {
    isPremium = value;
    if (!value) {
      _stripPremiumSoundAssignments();
    }
    _commit();
  }

  /// Clears cue slots that point at premium catalog items after lock/downgrade.
  void _stripPremiumSoundAssignments() {
    String? scrub(String? id) {
      if (id == null) return null;
      final cue = Catalog.soundById(id);
      if (cue != null && cue.premium) return null;
      return id;
    }

    sounds = SoundPrefs(
      connect: scrub(sounds.connect),
      disconnect: scrub(sounds.disconnect),
      reminder: scrub(sounds.reminder),
    );
  }

  /// Debug / non-StoreKit unlock for web & Windows testing.
  void unlockPremiumDebug() => setPremium(true);

  void lockPremiumDebug() => setPremium(false);

  /// Backup drafts + slot assignments as JSON (clipboard / file on Windows).
  String exportDraftsBackupJson() {
    return jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'drafts': drafts.map((d) => d.toJson()).toList(),
      'slots': slots,
    });
  }

  /// Restore drafts + slots from [exportDraftsBackupJson]. Returns error or null.
  String? importDraftsBackupJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['drafts'];
      if (list is! List) return 'Invalid backup: missing drafts';
      final parsed = <Draft>[];
      for (final e in list) {
        if (e is! Map) continue;
        parsed.add(Draft.fromJson(Map<String, dynamic>.from(e)));
      }
      drafts = parsed;
      final slotRaw = map['slots'] as List? ?? [null, null, null, null];
      slots = List<String?>.from(slotRaw.map((e) => e as String?));
      while (slots.length < 4) {
        slots.add(null);
      }
      final ids = drafts.map((d) => d.id).toSet();
      slots = slots
          .map((s) => s != null && ids.contains(s) ? s : null)
          .toList();
      if (lastEditedDraftId != null && !ids.contains(lastEditedDraftId)) {
        lastEditedDraftId = null;
      }
      _commit();
      return null;
    } catch (e) {
      return 'Could not import backup';
    }
  }

  String vehicleDisplayName() {
    if (vehicle.displayName.trim().isNotEmpty)
      return vehicle.displayName.trim();
    final brand = Catalog.brandById(vehicle.brandId);
    final model = Catalog.modelById(vehicle.brandId, vehicle.modelId);
    return '${brand?.name ?? 'Vehicle'} ${model?.name ?? ''}'.trim();
  }

  Draft? draftById(String id) {
    for (final d in drafts) {
      if (d.id == id) return d;
    }
    return null;
  }

  String createDraft(String name, WidgetSpec spec) {
    final id = _uuid.v4();
    drafts = [
      Draft(
        id: id,
        name: name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Fresh layer ids — Edit copy / duplicate never alias template layers.
        spec: spec.clone(remintLayerIds: true),
      ),
      ...drafts,
    ];
    lastEditedDraftId = id;
    _commit();
    return id;
  }

  /// Returns null when [template] is premium and the user is not unlocked.
  /// Always clones every template layer into the draft (never a flattened image).
  String? createDraftFromTemplate(TemplateItem template, {String? name}) {
    if (template.premium && !isPremium) return null;
    return createDraft(name ?? '${template.name} copy', template.spec);
  }

  void saveDraft(
    String id, {
    String? name,
    WidgetSpec? spec,
    String? widgetImagePath,
  }) {
    drafts = drafts.map((d) {
      if (d.id != id) return d;
      return Draft(
        id: d.id,
        name: name ?? d.name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Persist full multi-layer WidgetSpec — never bake to one image.
        spec: spec?.clone() ?? d.spec.clone(),
        // Persist the pre-rendered PNG path for the iOS widget. Live data
        // (clock/battery/analog) is NOT baked into the PNG.
        widgetImagePath: widgetImagePath ?? d.widgetImagePath,
      );
    }).toList();
    lastEditedDraftId = id;
    _commit();
  }

  /// Updates only the widgetImagePath on a draft (called by the editor
  /// after capturing the static PNG).
  void setWidgetImagePath(String id, String path) {
    drafts = drafts.map((d) {
      if (d.id != id) return d;
      return Draft(
        id: d.id,
        name: d.name,
        updatedAt: d.updatedAt,
        spec: d.spec,
        widgetImagePath: path,
      );
    }).toList();
    _commit();
  }

  void deleteDraft(String id) {
    drafts = drafts.where((d) => d.id != id).toList();
    slots = slots.map((s) => s == id ? null : s).toList();
    if (lastEditedDraftId == id) lastEditedDraftId = null;
    _commit();
  }

  String? duplicateDraft(String id) {
    final src = draftById(id);
    if (src == null) return null;
    return createDraft('${src.name} copy', src.spec);
  }

  void assignSlot(int index, String? draftId) {
    if (index < 0 || index > 3) return;
    final next = [...slots];
    next[index] = draftId;
    slots = next;
    _commit();
  }

  void updateVehicle(Vehicle Function(Vehicle v) updater) {
    vehicle = updater(vehicle.copy());
    _commit();
  }

  void resetVehicle() {
    vehicle = Vehicle(
      brandId: 'aurelio',
      modelId: 'aurelio-gt',
      artwork: ArtworkKind.coupe,
    );
    _commit();
  }

  bool trySetSound(SoundGroup group, String? id) {
    if (id != null) {
      final cue = Catalog.soundById(id);
      if (cue != null && cue.premium && !isPremium) return false;
    }
    setSound(group, id);
    return true;
  }

  void setSound(SoundGroup group, String? id) {
    switch (group) {
      case SoundGroup.connect:
        sounds.connect = id;
      case SoundGroup.disconnect:
        sounds.disconnect = id;
      case SoundGroup.reminder:
        sounds.reminder = id;
    }
    _commit();
  }

  void clearCustomImage() {
    vehicle = vehicle.copy()..customImage = null;
    _commit();
  }

  void clearDrafts() {
    drafts = [];
    slots = [null, null, null, null];
    lastEditedDraftId = null;
    _commit();
  }

  /// Honest local sync stamp — no fake network fetch.
  void markLocalSync() {
    lastLocalSync = DateTime.now().millisecondsSinceEpoch;
    _commit();
  }
}

String formatWhen(int ts) {
  if (ts <= 0) return '';
  final diff = DateTime.now().millisecondsSinceEpoch - ts;
  final m = diff ~/ 60000;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  return '${h ~/ 24}d ago';
}

Color hexColor(String hex, {double opacity = 1}) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16) ?? 0xFFF2F5FA;
  return Color(value).withValues(alpha: opacity);
}
