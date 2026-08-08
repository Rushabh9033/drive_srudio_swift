import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/feedback/drive_haptics.dart';
import '../../core/theme/drive_colors.dart';
import '../../core/theme/drive_theme.dart';
import '../widgets/native_tab_bar.dart';
import '../widgets/surfaces.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabSpec(label: 'Home', icon: CupertinoIcons.house_fill, path: '/home'),
    _TabSpec(
      label: 'Studio',
      icon: CupertinoIcons.square_grid_2x2_fill,
      path: '/studio',
    ),
    _TabSpec(label: 'Sounds', icon: CupertinoIcons.music_note_2, path: '/sounds'),
    _TabSpec(label: 'Settings', icon: CupertinoIcons.gear, path: '/settings'),
  ];

  int _indexFor(String location) {
    if (location.startsWith('/studio')) return 1;
    if (location.startsWith('/sounds')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final active = navigationShell.currentIndex >= 0
        ? navigationShell.currentIndex
        : _indexFor(location);
    final hideNav = location.startsWith('/studio/editor') ||
        location == '/intro' ||
        location == '/';

    Widget buildFlutterBottomBar() {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: DriveColors.carbon,
          border: Border(
            top: BorderSide(color: DriveColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Semantics(
            label: 'Primary',
            container: true,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _NavItem(
                          spec: _tabs[i],
                          selected: active == i,
                          onTap: () {
                            DriveHaptics.selection();
                            navigationShell.goBranch(
                              i,
                              initialLocation:
                                  i == navigationShell.currentIndex,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DriveColors.background,
      // IndexedStack lives inside StatefulNavigationShell — tab bodies stay alive.
      body: navigationShell,
      bottomNavigationBar: hideNav
          ? null
          : NativeBottomTabBar(
              selectedIndex: active,
              onTabSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              fallbackBar: buildFlutterBottomBar(),
            ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.icon, required this.path});
  final String label;
  final IconData icon;
  final String path;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DriveRadii.lg),
          splashColor: DriveColors.primary.withValues(alpha: 0.12),
          highlightColor: DriveColors.primary.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? DriveColors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(DriveRadii.lg),
              border: Border.all(
                color: selected
                    ? DriveColors.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  spec.icon,
                  size: selected ? 20 : 18,
                  color: selected
                      ? DriveColors.primary
                      : DriveColors.mutedForeground,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? DriveColors.primary
                          : DriveColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.child,
    this.bottomExtra = 0,
    this.scroll = true,
  });

  final Widget child;
  final double bottomExtra;

  /// When false, [child] owns scrolling (e.g. CustomScrollView + SliverGrid).
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final padded = ContentWidth(child: child);
    return ColoredBox(
      color: DriveColors.background,
      child: SafeArea(
        bottom: false,
        child: scroll
            ? SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 104 + bottomExtra),
                child: padded,
              )
            : padded,
      ),
    );
  }
}
