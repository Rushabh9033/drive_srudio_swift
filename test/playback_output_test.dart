import 'package:drive_studio/core/audio/playback_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePlaybackRoute', () {
    test('phone always resolves to phone speaker', () {
      expect(
        resolvePlaybackRoute(
          preference: PlaybackOutput.phone,
          carConnected: true,
        ),
        ResolvedPlaybackRoute.phoneSpeaker,
      );
      expect(
        resolvePlaybackRoute(
          preference: PlaybackOutput.phone,
          carConnected: false,
        ),
        ResolvedPlaybackRoute.phoneSpeaker,
      );
    });

    test('car always resolves to car/system route', () {
      expect(
        resolvePlaybackRoute(
          preference: PlaybackOutput.car,
          carConnected: false,
        ),
        ResolvedPlaybackRoute.carOrSystem,
      );
    });

    test('auto follows carConnected', () {
      expect(
        resolvePlaybackRoute(
          preference: PlaybackOutput.auto,
          carConnected: true,
        ),
        ResolvedPlaybackRoute.carOrSystem,
      );
      expect(
        resolvePlaybackRoute(
          preference: PlaybackOutput.auto,
          carConnected: false,
        ),
        ResolvedPlaybackRoute.phoneSpeaker,
      );
    });
  });

  test('playbackOutput JSON round-trip defaults to auto', () {
    expect(playbackOutputFromJson(null), PlaybackOutput.auto);
    expect(playbackOutputFromJson('phone'), PlaybackOutput.phone);
    expect(
      playbackOutputFromJson(playbackOutputToJson(PlaybackOutput.car)),
      PlaybackOutput.car,
    );
  });

  test('audioContextForRoute builds without throwing', () {
    expect(
      () => audioContextForRoute(ResolvedPlaybackRoute.phoneSpeaker),
      returnsNormally,
    );
    expect(
      () => audioContextForRoute(ResolvedPlaybackRoute.carOrSystem),
      returnsNormally,
    );
  });
}
