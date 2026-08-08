import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Where connect/disconnect/reminder cues should play.
///
/// Master pack has no separate phone/car WAV folders — routing is session-based
/// (iPhone loudspeaker vs active Bluetooth / car stereo).
enum PlaybackOutput {
  /// Prefer iPhone built-in loudspeaker (not earpiece).
  phone,

  /// Prefer active system route (Bluetooth / CarPlay stereo when linked).
  car,

  /// Car route when [carConnected], otherwise phone loudspeaker.
  auto,
}

extension PlaybackOutputCopy on PlaybackOutput {
  String get label => switch (this) {
    PlaybackOutput.phone => 'Phone',
    PlaybackOutput.car => 'Car',
    PlaybackOutput.auto => 'Auto',
  };

  String get subtitle => switch (this) {
    PlaybackOutput.phone => 'iPhone speakers',
    PlaybackOutput.car => 'Car Bluetooth / stereo',
    PlaybackOutput.auto => 'Car when linked, else phone',
  };
}

/// Resolved physical target after applying [PlaybackOutput.auto].
enum ResolvedPlaybackRoute { phoneSpeaker, carOrSystem }

extension ResolvedPlaybackRouteCopy on ResolvedPlaybackRoute {
  String get shortLabel => switch (this) {
    ResolvedPlaybackRoute.phoneSpeaker => 'iPhone speakers',
    ResolvedPlaybackRoute.carOrSystem => 'Car / Bluetooth route',
  };
}

ResolvedPlaybackRoute resolvePlaybackRoute({
  required PlaybackOutput preference,
  required bool carConnected,
}) {
  return switch (preference) {
    PlaybackOutput.phone => ResolvedPlaybackRoute.phoneSpeaker,
    PlaybackOutput.car => ResolvedPlaybackRoute.carOrSystem,
    PlaybackOutput.auto =>
      carConnected
          ? ResolvedPlaybackRoute.carOrSystem
          : ResolvedPlaybackRoute.phoneSpeaker,
  };
}

PlaybackOutput playbackOutputFromJson(String? raw) {
  return switch (raw) {
    'phone' => PlaybackOutput.phone,
    'car' => PlaybackOutput.car,
    'auto' => PlaybackOutput.auto,
    _ => PlaybackOutput.auto,
  };
}

String playbackOutputToJson(PlaybackOutput value) => value.name;

/// Build an [AudioContext] that routes cues correctly on iOS/Android.
///
/// - Phone: force loudspeaker (`defaultToSpeaker` / speakerphone) — never earpiece.
/// - Car/system: `playback` category so active Bluetooth / car stereo receives audio.
AudioContext audioContextForRoute(ResolvedPlaybackRoute route) {
  final preferPhoneSpeaker = route == ResolvedPlaybackRoute.phoneSpeaker;

  // On web / desktop, AudioContextConfig.buildIOS() may return null — still OK.
  if (preferPhoneSpeaker) {
    return AudioContextConfig(
      route: AudioContextConfigRoute.speaker,
      focus: AudioContextConfigFocus.duckOthers,
      respectSilence: false,
    ).build();
  }

  // Follow the active route (Bluetooth A2DP / CarPlay when connected).
  // Explicit iOS playback category — do not force defaultToSpeaker.
  return AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: defaultTargetPlatform == TargetPlatform.iOS
        ? AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          )
        : null,
  );
}
