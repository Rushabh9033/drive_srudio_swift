import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/bootstrap_screen.dart';
import '../../presentation/screens/editor_screen.dart';

import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/intro_screen.dart';
import '../../presentation/screens/legal_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/sounds_screen.dart';
import '../../presentation/screens/studio_extra_screens.dart';
import '../../presentation/screens/studio_screen.dart';
import '../../presentation/shell/app_shell.dart';
import '../nav/deep_links.dart';

/// Instant tab / shell swaps — no route fade to fight with heavy first paint.
Page<void> _plainPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    // drivestudio://sounds|setup|home (+ web ?dl=) → in-app paths.
    redirect: (context, state) {
      final mapped = DriveDeepLink.resolve(state.uri);
      if (mapped == null) return null;
      if (mapped == state.uri.path || mapped == state.matchedLocation) {
        return null;
      }
      return mapped;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const BootstrapScreen()),
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/deeplink/sounds', redirect: (_, __) => '/sounds'),
      GoRoute(path: '/deeplink/setup', redirect: (_, __) => '/setup'),
      GoRoute(path: '/deeplink/home', redirect: (_, __) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    _plainPage(state, const HomeScreen()),
              ),
              GoRoute(
                path: '/setup',
                pageBuilder: (context, state) =>
                    _plainPage(state, const SetupGuideScreen()),
              ),
              GoRoute(
                path: '/privacy',
                pageBuilder: (context, state) => _plainPage(
                  state,
                  const LegalScreen(document: LegalDocument.privacy),
                ),
              ),
              GoRoute(
                path: '/terms',
                pageBuilder: (context, state) => _plainPage(
                  state,
                  const LegalScreen(document: LegalDocument.terms),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/studio',
                pageBuilder: (context, state) =>
                    _plainPage(state, const StudioScreen()),
                routes: [
                  GoRoute(
                    path: 'my-widgets',
                    pageBuilder: (context, state) =>
                        _plainPage(state, const MyWidgetsScreen()),
                  ),
                  GoRoute(
                    path: 'slots',
                    pageBuilder: (context, state) =>
                        _plainPage(state, const SlotsScreen()),
                  ),
                  GoRoute(
                    path: 'templates/:id',
                    pageBuilder: (context, state) => _plainPage(
                      state,
                      TemplateDetailScreen(id: state.pathParameters['id']!),
                    ),
                  ),
                  GoRoute(
                    path: 'editor/:id',
                    pageBuilder: (context, state) => _plainPage(
                      state,
                      EditorScreen(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sounds',
                pageBuilder: (context, state) =>
                    _plainPage(state, const SoundsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    _plainPage(state, const SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF14151C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 40,
                  color: Color(0xFF9A9BA8),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Page not found',
                  style: TextStyle(
                    color: Color(0xFFF2F3F7),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.uri.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9A9BA8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => GoRouter.of(context).go('/home'),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
