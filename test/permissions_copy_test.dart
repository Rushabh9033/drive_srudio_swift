import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drive_studio/core/permissions/drive_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DrivePermissionKind covers photos camera location', () {
    expect(DrivePermissionKind.values.length, 3);
    expect(
      DrivePermissionKind.values,
      containsAll([
        DrivePermissionKind.photos,
        DrivePermissionKind.camera,
        DrivePermissionKind.locationWhenInUse,
      ]),
    );
  });

  test('supportsOsPermissions matches iOS/Android only', () {
    final expected =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    expect(DrivePermissions.supportsOsPermissions, expected);
  });

  test('isLocationGranted is false without plugins', () async {
    // MissingPlugin / denied — never claim a GPS grant in unit tests.
    expect(await DrivePermissions.isLocationGranted(), isFalse);
  });

  test('DrivePermissionOutcome has Settings path', () {
    expect(
      DrivePermissionOutcome.values,
      contains(DrivePermissionOutcome.permanentlyDenied),
    );
    expect(
      DrivePermissionOutcome.values,
      contains(DrivePermissionOutcome.unavailable),
    );
  });
}
