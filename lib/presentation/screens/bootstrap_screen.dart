import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../../data/store/app_store.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = context.read<AppStore>();
      await store.hydrate();
      if (!mounted) return;
      final target = store.introDone ? '/home' : '/intro';
      context.go(target);
      if (!mounted) return;

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriveColors.background,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: Text('Loading Drive Studio', style: driveMonoLabel()),
        ),
      ),
    );
  }
}
