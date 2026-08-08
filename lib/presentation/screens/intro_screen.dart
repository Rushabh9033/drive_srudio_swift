import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/drive_colors.dart';
import '../../data/store/app_store.dart';
import '../widgets/vehicle_art.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      title: 'Build your drive view',
      body:
          'Start from a curated template or open the custom editor and place text, clocks, badges and artwork exactly where you want them.',
      variant: 1,
    ),
    (
      title: 'Keep the useful parts close',
      body:
          'Save unlimited local drafts and promote your favourites into four dashboard slots you can rearrange at any time.',
      variant: 2,
    ),
    (
      title: 'Live data from your iPhone',
      body:
          'Battery, clock, charging, GPS speed, and Phone / Car link come from the physical iPhone. Web/Windows is preview only. Home Screen widgets still need a Mac WidgetKit build - not a fake CarPlay dashboard. Photos you add stay private on-device; only use images you have rights to.',
      variant: 3,
    ),
  ];

  void _finish() {
    context.read<AppStore>().completeIntro();
    context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -1),
            radius: 1.4,
            colors: [Color(0x554D9EFF), DriveColors.obsidian],
            stops: [0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: OnboardArt(variant: s.variant),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Text(
                                    s.title,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: DriveColors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s.body,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: DriveColors.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: active ? 24 : 8,
                    decoration: BoxDecoration(
                      color: active ? DriveColors.primary : DriveColors.graphite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_page < _slides.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _finish();
                      }
                    },
                    child: Text(
                      _page < _slides.length - 1 ? 'Continue' : 'Enter Drive Studio',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
