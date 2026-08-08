import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'playback_output.dart';

/// Plays bundled cue WAVs via [AssetSource], with sine synth fallback.
///
/// Applies [PlaybackOutput] routing so cues go to iPhone speakers or the
/// active car Bluetooth / stereo route (never forced to the earpiece).
class TonePlayer {
  TonePlayer._();
  static final TonePlayer instance = TonePlayer._();

  final AudioPlayer _player = AudioPlayer();
  String? _playingId;
  VoidCallback? _onStopped;
  ResolvedPlaybackRoute? _lastRoute;

  String? get playingId => _playingId;

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _playingId = null;
    _onStopped?.call();
    _onStopped = null;
  }

  /// Apply AVAudioSession / Android audio attributes for the resolved route.
  Future<void> applyOutputRoute({
    required PlaybackOutput preference,
    required bool carConnected,
  }) async {
    final resolved = resolvePlaybackRoute(
      preference: preference,
      carConnected: carConnected,
    );
    if (_lastRoute == resolved) return;
    _lastRoute = resolved;
    final ctx = audioContextForRoute(resolved);
    try {
      await _player.setAudioContext(ctx);
      // Also set global so first play after cold start inherits the route.
      await AudioPlayer.global.setAudioContext(ctx);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TonePlayer route apply failed ($resolved): $e');
      }
    }
  }

  /// Prefer [assetPath] (e.g. `assets/sounds/connect/01_….wav`).
  /// Falls back to a synthesized sine at [freq] if the asset is missing.
  Future<void> play({
    required String id,
    required double freq,
    String? assetPath,
    int durationMs = 3200,
    VoidCallback? onStopped,
    PlaybackOutput output = PlaybackOutput.auto,
    bool carConnected = false,
  }) async {
    await stop();
    await applyOutputRoute(
      preference: output,
      carConnected: carConnected,
    );

    _playingId = id;
    _onStopped = onStopped;

    final waitMs = durationMs.clamp(400, 12000);
    var usedAsset = false;

    if (assetPath != null && assetPath.isNotEmpty) {
      try {
        final relative = assetPath.startsWith('assets/')
            ? assetPath.substring('assets/'.length)
            : assetPath;
        final done = Completer<void>();
        late final StreamSubscription<void> sub;
        sub = _player.onPlayerComplete.listen((_) {
          if (!done.isCompleted) done.complete();
        });
        await _player.play(AssetSource(relative));
        usedAsset = true;
        await done.future.timeout(
          Duration(milliseconds: waitMs + 2000),
          onTimeout: () {},
        );
        await sub.cancel();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('TonePlayer asset miss ($assetPath): $e — using synth');
        }
        usedAsset = false;
      }
    }

    if (!usedAsset) {
      // Distinct synth per cue id so missing assets never sound identical.
      final synthFreq = _distinctFallbackFreq(id: id, freq: freq);
      final wav = synthesizeToneWav(freq: synthFreq);
      try {
        await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
        await Future<void>.delayed(
          Duration(milliseconds: waitMs.clamp(400, 2000)),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('TonePlayer fallback (no audio device?): $e');
        }
        await Future<void>.delayed(
          Duration(milliseconds: waitMs.clamp(400, 2000)),
        );
      }
    }

    if (_playingId == id) {
      _playingId = null;
      _onStopped?.call();
      _onStopped = null;
    }
  }

  /// Spread fallback tones so different cue ids cannot collapse to one pitch.
  double _distinctFallbackFreq({required String id, required double freq}) {
    var hash = 0;
    for (final c in id.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    final offset = (hash % 17) * 18.0;
    return (freq + offset).clamp(220.0, 1400.0);
  }

  void dispose() {
    _player.dispose();
  }
}

/// Build a mono 16-bit PCM WAV with 3-point ADSR (fallback path).
Uint8List synthesizeToneWav({
  required double freq,
  double durationSec = 1.15,
  int sampleRate = 44100,
  double peak = 0.18,
}) {
  final n = (sampleRate * durationSec).round();
  final pcm = Int16List(n);

  const attack = 0.05;
  const releaseStart = 1.1;
  const floor = 0.0001;

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    double env;
    if (t < attack) {
      final p = (t / attack).clamp(0.0, 1.0);
      env = floor * math.pow(peak / floor, p);
    } else if (t < releaseStart) {
      env = peak;
    } else {
      final p =
          ((t - releaseStart) / (durationSec - releaseStart)).clamp(0.0, 1.0);
      env = peak * math.pow(floor / peak, p);
    }
    final sample = math.sin(2 * math.pi * freq * t) * env;
    pcm[i] = (sample * 32767).round().clamp(-32768, 32767);
  }

  return _wrapWav(pcm, sampleRate);
}

Uint8List _wrapWav(Int16List pcm, int sampleRate) {
  const channels = 1;
  const bitsPerSample = 16;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = pcm.length * 2;
  final buffer = ByteData(44 + dataSize);

  void writeString(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, channels, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, blockAlign, Endian.little);
  buffer.setUint16(34, bitsPerSample, Endian.little);
  writeString(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  var o = 44;
  for (final s in pcm) {
    buffer.setInt16(o, s, Endian.little);
    o += 2;
  }
  return buffer.buffer.asUint8List();
}
