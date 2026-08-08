import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/telemetry/device_telemetry.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/catalog.dart';
import '../../data/store/app_store.dart';
import '../shell/app_shell.dart';
import '../widgets/drive_ui.dart';
import '../widgets/surfaces.dart';
import '../widgets/vehicle_art.dart';
import '../widgets/preview_widget_canvas.dart';
import '../widgets/widget_canvas.dart';
import '../../features/vehicles/vehicle_uploader.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final telemetry = context.watch<DeviceTelemetry>();
    final snap = telemetry.snapshot;
    final recent = [...Catalog.templates]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final last = store.lastEditedDraftId == null
        ? null
        : store.draftById(store.lastEditedDraftId!);

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Drive ',
                        style: GoogleFonts.manrope(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: DriveColors.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const GradientWord('Studio', size: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel(
                  telemetry.isIphone
                      ? 'Live from this iPhone'
                      : (kIsWeb || !telemetry.supportsLiveHardware
                            ? 'Preview (not your iPhone)'
                            : 'Live from this phone'),
                ),
                const SizedBox(height: 8),
                Text(
                  kIsWeb || !telemetry.supportsLiveHardware
                      ? 'Web/Windows is preview only. Install on your iPhone for '
                            'real battery, charging, GPS speed, and Phone / Car link. '
                            'Home Screen widgets still need WidgetKit (Mac) - not a CarPlay dashboard.'
                      : snap.liveDataEnabled && snap.batteryKnown
                      ? 'Live data from this ${telemetry.isIphone ? 'iPhone' : 'phone'}: '
                            'battery ${snap.batteryPercent}%'
                            '${snap.isCharging ? ' · charging' : ''} · '
                            '${snap.carConnected ? 'Car link on' : 'Car link off'} · '
                            'clocks live. Home Screen widgets need a Mac WidgetKit build - not a CarPlay dashboard.'
                      : 'Clocks are live. Turn on “Use live device data” in '
                            'Settings so battery + car link bind to this device.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            hero: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                if (store.vehicle.customImage != null)
                  GestureDetector(
                    onTap: () =>
                        VehicleUploader.uploadAndProcessVehicle(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DriveRadii.lg),
                      child: Image.memory(
                        base64Decode(
                          store.vehicle.customImage!.split(',').last,
                        ),
                        height: 168,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => VehicleArt(
                          kind: store.vehicle.artwork,
                          modelId: store.vehicle.modelId,
                          height: 168,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () =>
                        VehicleUploader.uploadAndProcessVehicle(context),
                    child: Container(
                      height: 168,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: DriveColors.carbon,
                        borderRadius: BorderRadius.circular(DriveRadii.lg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.add_circled,
                            size: 42,
                            color: DriveColors.mutedForeground,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload vehicle',
                            style: GoogleFonts.manrope(
                              color: DriveColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/studio'),
                        child: const Text('Open Studio'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/studio/slots'),
                        child: const Text('Manage Slots'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const MonoLabel('Active slots'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final id = store.slots[i];
                      final draft = id == null ? null : store.draftById(id);
                      return GestureDetector(
                        onTap: () => context.push('/studio/slots'),
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: draft == null
                                  ? DashedBorderBox(
                                      child: Center(
                                        child: Text(
                                          'Empty',
                                          style: driveMonoLabel(size: 9),
                                        ),
                                      ),
                                    )
                                  : PreviewWidgetCanvas(spec: draft.spec),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              draft?.name ?? 'Slot ${i + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: DriveColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 24),
            SurfaceCard(
              onTap: () => context.push('/studio/editor/${last.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.pencil,
                    color: DriveColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MonoLabel('Continue editing'),
                        const SizedBox(height: 4),
                        Text(
                          last.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      formatWhen(last.updatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: driveMono(size: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const MonoLabel('Recently added'),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/studio'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final t = recent[i];
                return SizedBox(
                  width: 140,
                  child: GestureDetector(
                    onTap: () => context.push('/studio/templates/${t.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 160,
                                  height: 160,
                                  child: PreviewWidgetCanvas(spec: t.spec),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: driveMonoLabel(size: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SurfaceCard(
            onTap: () => context.go('/sounds'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Automation cues'),
                const SizedBox(height: 6),
                Text(
                  'Not music - short sounds for CarPlay / Bluetooth Shortcuts',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.35,
                    color: DriveColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                _SoundLine(
                  label: 'Connect',
                  hint: 'When phone links to car',
                  value:
                      Catalog.soundById(store.sounds.connect)?.name ?? 'None',
                ),
                const SizedBox(height: 10),
                _SoundLine(
                  label: 'Disconnect',
                  hint: 'When the link drops',
                  value:
                      Catalog.soundById(store.sounds.disconnect)?.name ??
                      'None',
                ),
                const SizedBox(height: 10),
                _SoundLine(
                  label: 'Reminder',
                  hint: 'Optional automation cue',
                  value:
                      Catalog.soundById(store.sounds.reminder)?.name ?? 'None',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Setup status'),
                const SizedBox(height: 12),
                _StatusRow(
                  ok: true,
                  text: kIsWeb
                      ? 'Web preview only - use your iPhone for live data'
                      : telemetry.isIphone
                      ? 'iPhone telemetry ready (battery_plus + connectivity)'
                      : telemetry.supportsLiveHardware
                      ? 'Phone telemetry ready'
                      : 'Desktop preview ready',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  ok: snap.batteryKnown && snap.liveDataEnabled,
                  text: snap.batteryKnown && snap.liveDataEnabled
                      ? 'Live battery bound to this ${telemetry.isIphone ? 'iPhone' : 'device'}'
                      : (kIsWeb || !telemetry.supportsLiveHardware
                            ? 'Battery unavailable on web/desktop - use iPhone'
                            : 'Battery unavailable - enable live data or connect iPhone'),
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  ok: telemetry.isIphone,
                  text: telemetry.isIphone
                      ? 'WidgetKit Home Screen widgets - Active'
                      : 'WidgetKit + iPhone install - needed for Home Screen widgets',
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => context.push('/setup'),
                  child: const Text('Install & live sync guide'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundLine extends StatelessWidget {
  const _SoundLine({
    required this.label,
    required this.value,
    required this.hint,
  });
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: DriveColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: driveMono(),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok
              ? CupertinoIcons.checkmark_alt_circle_fill
              : CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: ok ? DriveColors.success : DriveColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
