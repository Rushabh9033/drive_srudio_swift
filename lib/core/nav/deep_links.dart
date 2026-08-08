/// Maps `drivestudio://` (and light web query aliases) onto go_router paths.
class DriveDeepLink {
  DriveDeepLink._();

  static const scheme = 'drivestudio';

  /// Known hosts / path segments → in-app routes.
  static const Map<String, String> targets = {
    'home': '/home',
    'sounds': '/sounds',
    'sound': '/sounds',
    'setup': '/setup',
    'howto': '/setup',
    'how-to': '/setup',
    'studio': '/studio',
    'garage': '/garage',
    'settings': '/settings',
    'privacy': '/privacy',
    'terms': '/terms',
  };

  /// Resolve [uri] to an in-app location, or null if not a Drive Studio deep link.
  ///
  /// Supported forms:
  /// - `drivestudio://sounds`
  /// - `drivestudio:///sounds`
  /// - `drivestudio://app/sounds`
  /// - `/deeplink/sounds` (already routed; remapped here for consistency)
  /// - `http(s)://…/?dl=sounds` or `?link=sounds` (web preview)
  static String? resolve(Uri uri) {
    if (uri.scheme == scheme) {
      final host = uri.host.trim().toLowerCase();
      final segments = uri.pathSegments
          .where((s) => s.isNotEmpty)
          .map((s) => s.toLowerCase())
          .toList();

      // drivestudio://sounds  OR  drivestudio://app/sounds
      if (host.isNotEmpty && host != 'app' && targets.containsKey(host)) {
        return targets[host];
      }
      if (segments.isNotEmpty) {
        final key = segments.first;
        if (targets.containsKey(key)) return targets[key];
      }
      if (host == 'app' || host.isEmpty) {
        return targets['home'];
      }
      return targets['home'];
    }

    // Explicit /deeplink/* aliases
    if (uri.path.startsWith('/deeplink/')) {
      final key = uri.path.substring('/deeplink/'.length).split('/').first;
      return targets[key.toLowerCase()] ?? '/home';
    }

    // Web preview: ?dl=sounds or ?link=setup
    final q = uri.queryParameters['dl'] ?? uri.queryParameters['link'];
    if (q != null && q.trim().isNotEmpty) {
      final key = q.trim().toLowerCase();
      if (targets.containsKey(key)) return targets[key];
    }

    return null;
  }

  /// True when [uri] should be intercepted by the deep-link redirect.
  static bool isDeepLink(Uri uri) {
    if (uri.scheme == scheme) return true;
    if (uri.path.startsWith('/deeplink/')) return true;
    final q = uri.queryParameters['dl'] ?? uri.queryParameters['link'];
    return q != null && q.trim().isNotEmpty;
  }
}
