import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/audio/playback_output.dart';
import '../../core/audio/tone_player.dart';
import '../../core/telemetry/device_telemetry.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/models.dart';
import '../../data/store/app_store.dart';
import '../shell/app_shell.dart';
import '../widgets/drive_ui.dart';
import '../widgets/surfaces.dart';

class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  String? _playing;
  SoundGroup _group = SoundGroup.connect;

  @override
  void dispose() {
    TonePlayer.instance.stop();
    super.dispose();
  }

  Future<void> _preview(SoundCue sound) async {
    final store = context.read<AppStore>();
    final carConnected = context.read<DeviceTelemetry>().snapshot.carConnected;
    await HapticFeedback.selectionClick();
    setState(() => _playing = sound.id);
    await TonePlayer.instance.play(
      id: sound.id,
      freq: sound.freq,
      assetPath: sound.assetPathOrDefault,
      durationMs: sound.durationMs,
      output: store.playbackOutput,
      carConnected: carConnected,
      onStopped: () {
        if (mounted && _playing == sound.id) {
          setState(() => _playing = null);
        }
      },
    );
    if (mounted && _playing == sound.id) {
      setState(() => _playing = null);
    }
  }

  String? _selectedFor(AppStore store) => switch (_group) {
    SoundGroup.connect => store.sounds.connect,
    SoundGroup.disconnect => store.sounds.disconnect,
    SoundGroup.reminder => store.sounds.reminder,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final telemetry = context.watch<DeviceTelemetry>();
    final carConnected = telemetry.snapshot.carConnected;
    final resolved = store.resolvedPlaybackRoute(carConnected: carConnected);
    final cues = Catalog.sounds.where((s) => s.group == _group).toList();

    return AppScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sounds',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Short automation cues for CarPlay / Bluetooth — not music tracks',
            style: GoogleFonts.manrope(color: DriveColors.mutedForeground),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('Playback output'),
                const SizedBox(height: 6),
                Text(
                  'Cues play through iPhone speakers or the car stereo, '
                  'depending on Bluetooth / Car link and this preference.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: DriveColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: DriveColors.carbon,
                    borderRadius: BorderRadius.circular(DriveRadii.lg),
                    border: Border.all(color: DriveColors.border),
                  ),
                  child: Row(
                    children: [
                      for (final o in PlaybackOutput.values)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => store.setPlaybackOutput(o),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: store.playbackOutput == o
                                    ? DriveColors.graphite
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  DriveRadii.md,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  o.label,
                                  maxLines: 1,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    height: 1.1,
                                    color: store.playbackOutput == o
                                        ? DriveColors.foreground
                                        : DriveColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${store.playbackOutput.subtitle} · now → ${resolved.shortLabel}'
                  '${carConnected ? ' · car link on' : ' · car link off'}',
                  style: driveMono(
                    size: 11,
                    color: DriveColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: DriveColors.carbon,
              borderRadius: BorderRadius.circular(DriveRadii.lg),
              border: Border.all(color: DriveColors.border),
            ),
            child: Row(
              children: [
                for (final g in SoundGroup.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _group = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _group == g
                              ? DriveColors.graphite
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(DriveRadii.md),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            g.monoLabel,
                            maxLines: 1,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.1,
                              color: _group == g
                                  ? DriveColors.foreground
                                  : DriveColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel(_group.monoLabel),
                const SizedBox(height: 6),
                Text(
                  _group.oneLiner,
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
            onTap: () => store.setSound(_group, null),
            glow: _selectedFor(store) == null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'None',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_selectedFor(store) == null)
                  const Icon(
                    CupertinoIcons.checkmark_alt,
                    color: DriveColors.primary,
                    size: 18,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final s in cues) ...[
            SurfaceCard(
              glow: _selectedFor(store) == s.id,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!store.trySetSound(_group, s.id)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Premium sound — unlock in Settings',
                              ),
                            ),
                          );
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.name,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (s.premium) ...[
                                const SizedBox(width: 8),
                                const TierBadge(premium: true),
                              ],
                            ],
                          ),
                          if (s.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              s.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                height: 1.35,
                                color: DriveColors.mutedForeground,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              WaveformBars(active: _playing == s.id),
                              const SizedBox(width: 10),
                              Text(
                                'CUE · ${s.durationLabel}',
                                style: driveMono(
                                  size: 11,
                                  color: DriveColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _playing == s.id
                        ? 'Playing ${s.name}'
                        : 'Preview ${s.name}',
                    onPressed: () => _preview(s),
                    icon: Icon(
                      _playing == s.id
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: DriveColors.primary,
                    ),
                  ),
                  if (_selectedFor(store) == s.id)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.checkmark_alt,
                        color: DriveColors.primary,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Preview uses the Playback output above (Phone / Car / Auto). '
            'On a linked iPhone, Auto sends connect cues to car Bluetooth when '
            'Car link is on, and disconnect / reminder cues to iPhone speakers '
            'when the link drops. Wire Shortcuts for background automations — '
            'see the setup guide.',
            style: GoogleFonts.manrope(
              color: DriveColors.mutedForeground,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
