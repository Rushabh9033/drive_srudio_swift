import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/vehicles/data/car_only_filter.dart';

/// One make from NHTSA VPIC `GetAllMakes`.
class NhtsaMake {
  const NhtsaMake({required this.id, required this.name});

  final int id;
  final String name;

  String get slug => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Offline snapshot + live model fetch for Brand→Model pickers.
class NhtsaMakesService {
  NhtsaMakesService._();
  static final NhtsaMakesService instance = NhtsaMakesService._();

  static const bundledAsset = 'assets/data/nhtsa_all_makes.json';
  static const refreshUrl =
      'https://vpic.nhtsa.dot.gov/api/vehicles/GetAllMakes?format=json';
  static const modelsUrl =
      'https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeId';

  List<NhtsaMake> _makes = const [];
  final Map<int, List<String>> _modelCache = {};
  bool _ready = false;
  Future<void>? _loading;

  bool get isReady => _ready;
  List<NhtsaMake> get makes => _makes;
  int get makeCount => _makes.length;

  Future<void> ensureLoaded() async {
    if (_ready && _makes.isNotEmpty) return;
    _loading ??= _loadOnce();
    try {
      await _loading;
    } finally {
      _loading = null;
    }
  }

  Future<void> _loadOnce() async {
    if (_ready && _makes.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(bundledAsset);
      _makes = _parseMakes(raw);
      _ready = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NHTSA bundled load failed: $e');
      }
      _makes = const [];
      _ready = true;
    }
  }

  /// Optional network refresh of the full makes list (keeps prior on failure).
  Future<bool> refreshMakes() async {
    try {
      final res = await http
          .get(Uri.parse(refreshUrl))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return false;
      final parsed = _parseMakes(res.body);
      if (parsed.isEmpty) return false;
      _makes = parsed;
      _ready = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NHTSA refresh failed: $e');
      }
      return false;
    }
  }

  List<NhtsaMake> search(String query, {int limit = 200}) {
    final q = query.trim().toLowerCase();
    Iterable<NhtsaMake> src = _makes;
    if (q.isNotEmpty) {
      src = _makes.where((m) => m.name.toLowerCase().contains(q));
    }
    final list = src.take(limit).toList(growable: false);
    return list;
  }

  NhtsaMake? byId(int id) {
    for (final m in _makes) {
      if (m.id == id) return m;
    }
    return null;
  }

  NhtsaMake? byName(String name) {
    final n = name.trim().toLowerCase();
    for (final m in _makes) {
      if (m.name.toLowerCase() == n) return m;
    }
    return null;
  }

  /// Models for a make — memory cache → prefs → network → empty.
  ///
  /// Always cars-only via [CarOnlyFilter]. Cached prefs are re-filtered so
  /// older unfiltered caches never surface excluded vehicles.
  Future<List<String>> modelsForMake(NhtsaMake make) async {
    List<String> gate(List<String> raw) =>
        CarOnlyFilter.filterModelNames(make.name, raw);

    final cached = _modelCache[make.id];
    if (cached != null) return gate(cached);

    final prefs = await SharedPreferences.getInstance();
    final key = 'nhtsa_models_${make.id}';
    final local = prefs.getStringList(key);
    if (local != null && local.isNotEmpty) {
      final filtered = gate(local);
      _modelCache[make.id] = filtered;
      // Rewrite cache so excluded rows cannot be restored later.
      await prefs.setStringList(key, filtered);
      return filtered;
    }

    try {
      final uri = Uri.parse('$modelsUrl/${make.id}?format=json');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final models = gate(_parseModels(res.body));
        if (models.isNotEmpty) {
          _modelCache[make.id] = models;
          await prefs.setStringList(key, models);
          return models;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NHTSA models fetch failed (${make.name}): $e');
      }
    }
    return const [];
  }

  static List<NhtsaMake> _parseMakes(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final results = decoded['Results'];
    if (results is! List) return const [];
    final out = <NhtsaMake>[];
    for (final row in results) {
      if (row is! Map) continue;
      final id = row['Make_ID'];
      final name = row['Make_Name'];
      if (id is! num || name is! String) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      out.add(NhtsaMake(id: id.toInt(), name: trimmed));
    }
    out.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return out;
  }

  static List<String> _parseModels(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final results = decoded['Results'];
    if (results is! List) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final row in results) {
      if (row is! Map) continue;
      final name = row['Model_Name'];
      if (name is! String) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) out.add(trimmed);
    }
    out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }
}
