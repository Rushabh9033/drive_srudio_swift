import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/telemetry/device_telemetry.dart';
import 'core/theme/drive_colors.dart';
import 'core/theme/drive_theme.dart';

import 'data/purchase/purchase_service.dart';
import 'data/store/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: DriveColors.carbon,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final store = AppStore();
  await store.hydrate();
  final telemetry = DeviceTelemetry();
  await telemetry.start(store);
  final purchases = createPurchaseService(store);
  await purchases.init();
  runApp(
    DriveStudioApp(
      store: store,
      purchases: purchases,
      telemetry: telemetry,
    ),
  );
}

class DriveStudioApp extends StatelessWidget {
  const DriveStudioApp({
    super.key,
    required this.store,
    required this.purchases,
    required this.telemetry,
  });

  final AppStore store;
  final PurchaseService purchases;
  final DeviceTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final router = createRouter();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: telemetry),
        Provider<PurchaseService>.value(value: purchases),
      ],
      child: MaterialApp.router(
        title: 'Drive Studio',
        debugShowCheckedModeBanner: false,
        theme: buildDriveTheme(),
        routerConfig: router,
      ),
    );
  }
}
