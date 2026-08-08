import '../models/models.dart';

String _prettySoundName(String fileStem) {
  var s = fileStem;
  s = s.replaceFirst(RegExp(r'^\d+_'), '');
  s = s.replaceFirst(RegExp(r'^(connect|disconnect)_'), '');
  return s
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

SoundCue _cue({
  required String file,
  required String folder,
  required SoundGroup group,
  required String description,
  bool premium = false,
  double freq = 660,
  int durationMs = 3200,
}) {
  final stem = file.replaceAll('.wav', '');
  return SoundCue(
    id: stem,
    name: _prettySoundName(stem),
    description: description,
    group: group,
    freq: freq,
    premium: premium,
    assetPath: 'assets/sounds/$folder/$file',
    durationMs: durationMs,
  );
}

/// Master Car App voice library (connect / disconnect / reminder).
///
/// The master pack has no separate phone-speaker vs car-speaker WAV folders —
/// routing is handled at play time via PlaybackOutput (iPhone loudspeaker
/// vs active Bluetooth / car stereo).
abstract final class SoundLibrary {
  static const connectFiles = <String>[
    '01_connect_welcome_back.wav',
    '02_connect_vehicle_connected.wav',
    '03_connect_everything_ready.wav',
    '04_connect_system_online.wav',
    '05_connect_dashboard_ready.wav',
    '06_connect_buckle_up.wav',
    '07_connect_adventure_begins.wav',
    '08_connect_welcome_aboard.wav',
    '09_connect_connection_successful.wav',
    '10_connect_drive_mode.wav',
  ];

  static const disconnectFiles = <String>[
    '03_disconnect_lock_vehicle.wav',
    '05_disconnect_safe_arrival.wav',
    '06_disconnect_goodbye.wav',
    '07_disconnect_nice_parking.wav',
    '09_disconnect_until_next_time.wav',
    '10_disconnect_vehicle_secured.wav',
  ];

  /// Disconnect-folder clips that behave as leave-car reminders.
  static const reminderFiles = <String>[
    '01_disconnect_phone_reminder.wav',
    '02_disconnect_phone_keys_wallet.wav',
    '04_disconnect_check_windows.wav',
    '08_disconnect_check_back_seat.wav',
  ];

  static const modelConnectFiles = <String>[
    '01_connect_acura_nsx.wav',
    '02_connect_alfa_romeo_giulia.wav',
    '03_connect_aston_martin_db12.wav',
    '04_connect_audi_rs7.wav',
    '05_connect_bentley_continental.wav',
    '06_connect_byd_seal.wav',
    '07_connect_cadillac_escalade.wav',
    '08_connect_chery_tiggo_8.wav',
    '09_connect_chrysler_300.wav',
    '10_connect_citroen_c5_aircross.wav',
    '11_connect_ferrari_296.wav',
    '12_connect_genesis_g80.wav',
    '13_connect_gmc_hummer_ev.wav',
    '14_connect_hyundai_ioniq_5.wav',
    '15_connect_jaguar_f_type.wav',
    '16_connect_jeep_wrangler.wav',
    '17_connect_kia_ev6.wav',
    '18_connect_lamborghini_huracan.wav',
    '19_connect_land_rover_defender.wav',
    '20_connect_lexus_lc_500.wav',
    '21_connect_lucid_air.wav',
    '22_connect_maserati_granturismo.wav',
    '23_connect_mazda_mx5.wav',
    '24_connect_mclaren_750s.wav',
    '25_connect_mini_cooper.wav',
    '26_connect_nissan_gtr.wav',
    '27_connect_peugeot_508.wav',
    '28_connect_range_rover_sport.wav',
    '29_connect_subaru_wrx.wav',
    '30_connect_volvo_xc90.wav',
    '43_brands_connect_master.wav',
  ];

  static final List<SoundCue> cues = [
    for (final f in connectFiles)
      _cue(
        file: f,
        folder: 'connect',
        group: SoundGroup.connect,
        description: 'Voice connect cue when CarPlay / Bluetooth links',
        freq: 880,
      ),
    for (final f in modelConnectFiles)
      _cue(
        file: f,
        folder: 'model_connect',
        group: SoundGroup.connect,
        description: 'Model-branded connect announcement',
        premium: true,
        freq: 720,
        durationMs: 4000,
      ),
    for (final f in disconnectFiles)
      _cue(
        file: f,
        folder: 'disconnect',
        group: SoundGroup.disconnect,
        description: 'Voice disconnect cue when the phone leaves the car',
        freq: 330,
      ),
    for (final f in reminderFiles)
      _cue(
        file: f,
        folder: 'disconnect',
        group: SoundGroup.reminder,
        description: 'Leave-car reminder (phone, keys, windows, seats)',
        freq: 550,
      ),
  ];
}
