import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/audio/playback_output.dart';
import '../../core/legal/legal_copy.dart';
import '../../core/permissions/drive_permissions.dart';
import '../../core/telemetry/device_telemetry.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/purchase/purchase_service.dart';
import '../../data/store/app_store.dart';
import '../shell/app_shell.dart';
import '../widgets/surfaces.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _onLiveDataToggle(AppStore store, bool enabled) async {
    if (!enabled) {
      store.setUseLiveDeviceData(false);
      return;
    }
    final outcome = await DrivePermissions.ensure(
      context,
      DrivePermissionKind.locationWhenInUse,
    );
    if (!mounted) return;
    switch (outcome) {
      case DrivePermissionOutcome.granted:
        store.setLocationConsentGiven(true);
        store.setUseLiveDeviceData(true);
      case DrivePermissionOutcome.declined:
      case DrivePermissionOutcome.denied:
        // Battery / clock still useful without GPS ? enable live, skip speed.
        store.setUseLiveDeviceData(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live data on without Location ? speedometers stay Unavailable. '
              'Toggle again and allow Location for GPS speed.',
            ),
          ),
        );
      case DrivePermissionOutcome.permanentlyDenied:
        store.setUseLiveDeviceData(true);
      case DrivePermissionOutcome.unavailable:
        store.setUseLiveDeviceData(false);
    }
  }

  Future<void> _runPurchase(
    Future<PurchaseResult> Function() action, {
    required String pendingLabel,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = result.pending
        ? pendingLabel
        : (result.message ?? (result.ok ? 'Premium unlocked' : 'Purchase failed'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final telemetry = context.watch<DeviceTelemetry>();
    final snap = telemetry.snapshot;
    final purchases = context.read<PurchaseService>();
    final synced = store.lastLocalSync == 0
        ? 'Never'
        : DateFormat('MMM d - HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(store.lastLocalSync),
          );

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(CupertinoIcons.back, size: 16),
            label: const Text('Home'),
          ),
          Text(
            'Settings',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel(
                  telemetry.isIphone
                      ? 'This iPhone'
                      : (kIsWeb || !telemetry.supportsLiveHardware
                          ? 'Preview only'
                          : 'This phone'),
                ),
                const SizedBox(height: 8),
                Text(
                  telemetry.isIphone
                      ? 'Live data comes from this iPhone: battery, clock, '
                          'charging, GPS speed, and Phone / Car link. Home Screen '
                          'widgets still need a Mac WidgetKit build - not a CarPlay UI shell.'
                      : (kIsWeb || !telemetry.supportsLiveHardware
                          ? 'Web/Windows is preview only. Install Drive Studio on '
                              'your iPhone for real battery, charging, GPS speed, and car-link.'
                          : 'Live data comes from this phone: battery, clock, '
                              'charging, GPS speed, and Phone / Car link. Not a CarPlay UI shell.'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Background removal'),
                const SizedBox(height: 8),
                Text(
                  'Remove BG runs in-app on iPhone, Android, and desktop '
                  '(image_background_remover). No helper server in the editor. '
                  'Use Gallery or Camera for your own car - no stock car photos. '
                  '${LegalCopy.ugcPrivacyNote}',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.35,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Device sync'),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Use live device data',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    snap.batteryKnown
                        ? 'From this ${telemetry.isIphone ? 'iPhone' : 'device'}: '
                            'battery ${snap.batteryPercent}%'
                            '${snap.isCharging ? ' - charging' : ''}'
                            '${snap.speedKnown && snap.speedKmh != null ? ' | ${snap.speedKmh!.round()} km/h' : ''}'
                            ' - ${snap.networkOnline ? 'online' : 'offline'}'
                        : telemetry.supportsLiveHardware
                            ? 'Binds this phone clock, battery, charging, GPS speed, and car link'
                            : 'Preview: clocks stay live; battery & GPS show Unavailable until iPhone',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                  value: telemetry.supportsLiveHardware && store.useLiveDeviceData,
                  onChanged: telemetry.supportsLiveHardware
                      ? (v) => _onLiveDataToggle(store, v)
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Car connected',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    snap.carConnected
                        ? (snap.carLinkSource == CarLinkSource.manual
                            ? 'On - you marked iPhone in the car'
                            : 'On - Bluetooth connectivity proxy (Android)')
                        : (telemetry.isIphone || !telemetry.bluetoothProxySupported
                            ? 'Turn on when this iPhone is linked to the car. '
                                'Not a CarPlay session API - reliable manual flag.'
                            : 'Manual toggle, or auto when Bluetooth connectivity '
                                'is reported (not a CarPlay session)'),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                  value: store.manualCarConnected,
                  onChanged: (v) => store.setManualCarConnected(v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Play sounds on car link',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Uses your Connect / Disconnect cues when link flips',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: DriveColors.mutedForeground,
                    ),
                  ),
                  value: store.playCarLinkSounds,
                  onChanged: (v) => store.setPlayCarLinkSounds(v),
                ),
                const SizedBox(height: 4),
                Text(
                  'Playback output',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone / Car / Auto - change on the Sounds tab. '
                  'Now: ${store.resolvedPlaybackRoute(carConnected: snap.carConnected).shortLabel}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: DriveColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final o in PlaybackOutput.values)
                      ChoiceChip(
                        label: Text(o.label),
                        selected: store.playbackOutput == o,
                        onSelected: (_) => store.setPlaybackOutput(o),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Local data'),
                const SizedBox(height: 12),
                Text(
                  'Catalog & drafts',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last local sync - $synced',
                  style: driveMono(size: 11, color: DriveColors.mutedForeground),
                ),
                if (store.corruptDraftSkips > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Skipped ${store.corruptDraftSkips} corrupt draft(s) on load.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: DriveColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'All templates and sounds ship in the app. No remote content fetch in V1.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: DriveColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Premium'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.isPremium ? 'Premium unlocked' : 'Free tier',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            purchases.supportsStoreKit
                                ? 'Non-consumable - $kPremiumProductId'
                                : 'Debug unlock for web / Windows testing.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              height: 1.3,
                              color: DriveColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      store.isPremium
                          ? CupertinoIcons.lock_open_fill
                          : CupertinoIcons.lock_fill,
                      color: store.isPremium
                          ? DriveColors.success
                          : DriveColors.mutedForeground,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (purchases.supportsStoreKit) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _runPurchase(
                                purchases.purchasePremium,
                                pendingLabel: 'Opening App Store purchase...',
                              ),
                      child: Text(_busy ? 'Working...' : 'Unlock Premium'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _runPurchase(
                                purchases.restorePurchases,
                                pendingLabel: 'Restoring purchases...',
                              ),
                      child: const Text('Restore purchases'),
                    ),
                  ),
                ] else ...[
                  // Debug unlock only on non-StoreKit platforms (web / Windows).
                  // IapPurchaseService.supportsStoreKit is true on iOS - never show here.
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Unlock Premium (debug)',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Simulates $kPremiumProductId - not a StoreKit transaction',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: DriveColors.mutedForeground,
                      ),
                    ),
                    value: store.isPremium,
                    onChanged: (v) {
                      if (v) {
                        purchases.unlockDebug();
                      } else {
                        purchases.lockDebug();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Data'),
                const SizedBox(height: 8),
                _ActionRow(
                  title: 'Export drafts to clipboard',
                  subtitle: 'JSON backup of drafts + slot assignments',
                  onTap: () async {
                    final json = store.exportDraftsBackupJson();
                    await Clipboard.setData(ClipboardData(text: json));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied ${store.drafts.length} draft'
                          '${store.drafts.length == 1 ? '' : 's'} to clipboard',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Import drafts from clipboard',
                  subtitle: 'Replaces current drafts and slots',
                  onTap: () => _importDrafts(context, store),
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Clear custom vehicle image',
                  subtitle: 'Removes garage photo from local storage',
                  onTap: () {
                    store.clearCustomImage();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom image cleared')),
                    );
                  },
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Clear drafts',
                  subtitle: 'Requires typing DELETE',
                  destructive: true,
                  onTap: () => _clearDrafts(context, store),
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Reset introduction',
                  subtitle: 'Show the 3-slide onboarding again',
                  onTap: () {
                    store.resetIntro();
                    context.go('/intro');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('About'),
                const SizedBox(height: 10),
                Text(
                  'Drive Studio',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Design Home Screen drive widgets, slots, and sounds. '
                  'Apple does not allow custom CarPlay UI shells - '
                  'use Home Screen widgets + Shortcuts (see Setup guide).',
                  style: GoogleFonts.manrope(
                    color: DriveColors.mutedForeground,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  LegalCopy.ugcPrivacyNote,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: DriveColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'v0.1.0 - iPhone sensors + GPS live; Home Screen WidgetKit needs Mac',
                  style: driveMono(size: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  'Product ID: $kPremiumProductId',
                  style: driveMono(size: 11, color: DriveColors.mutedForeground),
                ),
                const SizedBox(height: 12),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Privacy Policy',
                  subtitle: 'On-device drafts, photos, GPS speed, StoreKit - no tracking',
                  onTap: () => context.push('/privacy'),
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Terms of Use',
                  subtitle: 'Image rights and private on-device use',
                  onTap: () => context.push('/terms'),
                ),
                const Divider(color: DriveColors.border, height: 24),
                _ActionRow(
                  title: 'Setup guide',
                  subtitle: 'Home Screen widgets + Shortcuts (honest path)',
                  onTap: () => context.push('/setup'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDrafts(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all drafts?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type DELETE to confirm.',
              style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DriveColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim() == 'DELETE'),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true) {
      store.clearDrafts();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drafts cleared')),
        );
      }
    }
  }

  Future<void> _importDrafts(BuildContext context, AppStore store) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty - copy a backup JSON first'),
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import drafts?'),
        content: Text(
          'This replaces your current drafts and slot assignments.',
          style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final err = store.importDraftsBackupJson(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ??
              'Imported ${store.drafts.length} draft'
                  '${store.drafts.length == 1 ? '' : 's'}',
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: destructive
                    ? DriveColors.destructive
                    : DriveColors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: DriveColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SetupGuideScreen extends StatelessWidget {
  const SetupGuideScreen({super.key});

  static const _sections = <(String, List<(String, String)>)>[
    (
      'Install on your iPhone',
      [
        (
          'Available now',
          'From a Mac: connect the iPhone (Developer Mode + trust), then run `flutter devices` and `flutter run -d <iphone>`. Or open ios/Runner.xcworkspace in Xcode and Run on the physical device. See IPHONE_LIVE_DATA.md.',
        ),
        (
          'Available now',
          'On first launch, "Use live device data" defaults ON. Confirm Settings shows battery % from this iPhone - that means live sync is working.',
        ),
        (
          'Available now',
          'When you sit in the car, flip Settings -> Car connected ON (and OFF when you leave). iOS does not expose a reliable Bluetooth car-link flag via connectivity_plus; we do not fake CarPlay APIs.',
        ),
        (
          'Honest note',
          'Web and Windows builds are design preview only. They are not the live data source for your car.',
        ),
      ],
    ),
    (
      'What is live on this iPhone',
      [
        (
          'Available now',
          'Live data comes from this iPhone: system clock/date, battery % + charging (battery_plus), GPS speed (geolocator, when permitted), and network online/offline (connectivity_plus).',
        ),
        (
          'Available now',
          'Phone / Car link = your manual Car connected toggle (plus Android Bluetooth auto when available). Not a native CarPlay session flag.',
        ),
        (
          'Honest note',
          'GPS speed shows real km/h only with location permission + a usable fix. Otherwise the widget shows - / Unavailable (never invented). Web/Windows preview never claims live GPS. Home Screen widgets still need WidgetKit on Mac - not a CarPlay dashboard.',
        ),
        (
          'Requires Mac/Xcode',
          'Home Screen WidgetKit surfaces still need the Mac Wave 2 build. Until then, the app mirrors iPhone telemetry into App Group JSON so widgets can consume it later.',
        ),
      ],
    ),
    (
      'Home Screen widgets',
      [
        (
          'Available now',
          'Design widgets in Studio and assign them to four slots. App Group JSON includes the latest iPhone telemetry snapshot for WidgetKit.',
        ),
        (
          'Requires Mac/Xcode',
          'Compile the WidgetKit extension on a Mac, then on iPhone: long-press Home Screen -> Add Widget -> Drive Studio -> Slot 1-4.',
        ),
        (
          'Requires iPhone',
          'Use systemSmall sizes that match the canvases you designed. Each Slot widget reads App Group state for that index (after Wave 2).',
        ),
        (
          'Honest note',
          'Apple does not allow a custom CarPlay OS UI. Drive Studio uses Home Screen widgets - not a full dashboard takeover.',
        ),
      ],
    ),
    (
      'Privacy & your photos',
      [
        (
          'Available now',
          'Photos and drafts stay private on this device. You must have the rights to images you upload. Open Settings -> Privacy Policy for the full policy (also docs/legal/privacy.html).',
        ),
        (
          'Available now',
          'Optional Location is only for GPS speed while the app is open. No ads or tracking in V1. Remove BG runs on-device.',
        ),
      ],
    ),
    (
      'Shortcuts automation',
      [
        (
          'What these cues are',
          'Connect / Disconnect / Reminder are short automation sounds - not music. Wire them in Shortcuts when CarPlay or Bluetooth links. In-app "Car connected" drives studio previews and App Group telemetry.',
        ),
        (
          'Available now',
          'Open Sounds and pick one cue per slot (or None). Preview in-app; trigger on device via Shortcuts.',
        ),
        (
          'Requires iPhone',
          'Open Shortcuts -> Automation -> Create Personal Automation -> CarPlay (or Bluetooth). When "Connects" -> Next.',
        ),
        (
          'Requires iPhone',
          'Add action "Open App" -> Drive Studio, or "Play Sound" with the Connect cue you chose. Turn off Ask Before Running for hands-free use.',
        ),
        (
          'Available now',
          'Deep links: drivestudio://sounds, drivestudio://setup, drivestudio://home '
              '(Info.plist + Android intent + Flutter go_router). Web preview: ?dl=sounds. '
              'Use from Shortcuts ? Open URL.',
        ),
        (
          'Export recipe',
          'Name the automation "Drive Studio - Connect". Duplicate for Disconnect with that cue. Optionally flip Car connected in Settings when you start a drive.',
        ),
        (
          'Requires iPhone',
          'Test by connecting to your car Bluetooth / CarPlay, then disconnecting. Confirm Reminder separately if you use it.',
        ),
      ],
    ),
    (
      'What Wave 2 adds (Mac)',
      [
        (
          'Requires Mac/Xcode',
          'Compile the WidgetKit extension so Home Screen widgets render from App Group shared state (including iPhone telemetry).',
        ),
        (
          'Requires Mac/Xcode',
          'Wire StoreKit 2 for real Premium unlock (templates + sounds) via product drive_studio_premium.',
        ),
        (
          'Requires Mac/Xcode',
          'TestFlight distribution and device verification.',
        ),
      ],
    ),
  ];

  static Color _setupBadgeColor(String label) {
    if (label.contains('Available')) return DriveColors.success;
    if (label.contains('Honest') ||
        label.contains('Export') ||
        label.contains('What these') ||
        label.contains('Deep')) {
      return DriveColors.primary;
    }
    return DriveColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(CupertinoIcons.back, size: 16),
            label: const Text('Home'),
          ),
          Text(
            'Setup guide',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Home Screen widgets + Shortcuts - not a custom CarPlay OS',
            style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          for (final section in _sections) ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < section.$2.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DriveColors.graphite,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${i + 1}', style: driveMono(size: 11)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.$2[i].$1.toUpperCase(),
                                style: driveMonoLabel(
                                  size: 10,
                                  color: _setupBadgeColor(section.$2[i].$1),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                section.$2[i].$2,
                                style: GoogleFonts.manrope(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (i < section.$2.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}