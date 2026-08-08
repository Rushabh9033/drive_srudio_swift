import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/vehicles/data/car_only_filter.dart';

/// One model row from the bundled vehicle catalog.
class CatalogModelEntry {
  const CatalogModelEntry({
    required this.name,
    this.modelId,
    this.catalogId,
    this.category,
    this.imagePath,
    this.logoPath,
    this.angles = const [],
  });

  final String name;
  final int? modelId;

  /// Stable string id from master datasets (`model_acura_adx`).
  final String? catalogId;
  final String? category;

  /// Bundled asset path or absolute/local path remapped at load time.
  final String? imagePath;
  final String? logoPath;

  /// Angle labels or asset paths when the catalog supplies them.
  final List<String> angles;

  String? get primaryImage =>
      imagePath ?? (angles.isNotEmpty ? angles.first : null);
}

/// One make row from the bundled vehicle catalog (NHTSA-shaped + optional media).
class CatalogMakeEntry {
  const CatalogMakeEntry({
    required this.id,
    required this.name,
    this.catalogId,
    this.models = const [],
    this.logoPath,
  });

  final int id;
  final String name;

  /// Stable string id from master datasets (`brand_acura`).
  final String? catalogId;
  final List<CatalogModelEntry> models;
  final String? logoPath;

  bool get hasModels => models.isNotEmpty;

  List<String> get modelNames =>
      models.map((m) => m.name).toList(growable: false);
}

/// Bundled master vehicle catalog — primary Brand→Model source (cars only).
///
/// Prefers `assets/data/vehicle_catalog.json` (master schema). Falls back to
/// combining `vehicle_brands.json` + `vehicle_models.json`. Legacy NHTSA array
/// schema is still parsed when present.
///
/// Every ingest path runs [CarOnlyFilter] before models reach the UI.
class VehicleCatalogService {
  VehicleCatalogService._();
  static final VehicleCatalogService instance = VehicleCatalogService._();

  static const bundledCatalogAsset = 'assets/data/vehicle_catalog.json';
  static const bundledBrandsAsset = 'assets/data/vehicle_brands.json';
  static const bundledModelsAsset = 'assets/data/vehicle_models.json';

  /// @deprecated Use [bundledCatalogAsset].
  static const bundledAsset = bundledCatalogAsset;

  /// Source roots remapped into `assets/vehicles/catalog/` when copying.
  static const _remapRoots = [
    r'd:\wise-hawking\squadrush\',
    r'd:/wise-hawking/squadrush/',
    'assets/vehicles/',
    'assets/logos/',
  ];

  List<CatalogMakeEntry> _makes = const [];
  final Map<int, CatalogMakeEntry> _byId = {};
  final Map<String, CatalogMakeEntry> _byName = {};
  final Map<String, CatalogMakeEntry> _byCatalogId = {};
  final Set<String> _allowedModelKeys = {};
  bool _ready = false;
  Future<void>? _loading;

  CarFilterStats _stats = const CarFilterStats(
    rawModelCount: 0,
    validCarCount: 0,
    excludedBikeCount: 0,
    excludedOtherCount: 0,
    brandsRemaining: 0,
  );

  bool get isReady => _ready;
  List<CatalogMakeEntry> get makes => _makes;
  int get makeCount => _makes.length;
  int get modelCount => _makes.fold<int>(0, (n, m) => n + m.models.length);
  int get makesWithModelsCount => _makes.where((m) => m.hasModels).length;
  CarFilterStats get filterStats => _stats;

  int get rawModelCount => _stats.rawModelCount;
  int get validCarCount => _stats.validCarCount;
  int get excludedBikeCount => _stats.excludedBikeCount;
  int get excludedOtherCount => _stats.excludedOtherCount;

  int get imageCount {
    var n = 0;
    for (final make in _makes) {
      if (make.logoPath != null && make.logoPath!.isNotEmpty) n++;
      for (final model in make.models) {
        if (model.imagePath != null && model.imagePath!.isNotEmpty) n++;
        if (model.logoPath != null && model.logoPath!.isNotEmpty) n++;
        n += model.angles.length;
      }
    }
    return n;
  }

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
      final catalogRaw = await rootBundle.loadString(bundledCatalogAsset);
      var parsed = _parseAny(catalogRaw);
      if (parsed.isEmpty || !parsed.any((m) => m.hasModels)) {
        parsed = await _loadFromBrandsAndModels();
      }
      _ingest(parsed);
      _ready = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Vehicle catalog load failed: $e');
      }
      try {
        final parsed = await _loadFromBrandsAndModels();
        _ingest(parsed);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('Vehicle brands/models load failed: $e2');
        }
        _makes = const [];
        _byId.clear();
        _byName.clear();
        _byCatalogId.clear();
        _allowedModelKeys.clear();
      }
      _ready = true;
    }
  }

  /// Test / tooling: ingest already-decoded JSON without Flutter assets.
  @visibleForTesting
  void loadFromJsonString(String raw) {
    _ingest(_parseAny(raw));
    _ready = true;
  }

  @visibleForTesting
  void loadFromParsedMakes(List<CatalogMakeEntry> unfiltered) {
    _ingest(unfiltered);
    _ready = true;
  }

  @visibleForTesting
  void resetForTest() {
    _makes = const [];
    _byId.clear();
    _byName.clear();
    _byCatalogId.clear();
    _allowedModelKeys.clear();
    _ready = false;
    _stats = const CarFilterStats(
      rawModelCount: 0,
      validCarCount: 0,
      excludedBikeCount: 0,
      excludedOtherCount: 0,
      brandsRemaining: 0,
    );
  }

  Future<List<CatalogMakeEntry>> _loadFromBrandsAndModels() async {
    final brandsRaw = await rootBundle.loadString(bundledBrandsAsset);
    final modelsRaw = await rootBundle.loadString(bundledModelsAsset);
    return _parseBrandsAndModels(brandsRaw, modelsRaw);
  }

  List<CatalogMakeEntry> search(String query, {int limit = 200}) {
    final q = query.trim().toLowerCase();
    Iterable<CatalogMakeEntry> src = _makes;
    if (q.isNotEmpty) {
      src = _makes.where((m) => m.name.toLowerCase().contains(q));
    }
    final list = src.toList()
      ..sort((a, b) {
        final am = a.hasModels ? 0 : 1;
        final bm = b.hasModels ? 0 : 1;
        if (am != bm) return am - bm;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list.take(limit).toList(growable: false);
  }

  CatalogMakeEntry? byId(int id) => _byId[id];

  CatalogMakeEntry? byName(String name) => _byName[name.trim().toLowerCase()];

  CatalogMakeEntry? byCatalogId(String id) => _byCatalogId[id.trim()];

  /// Offline model names when the catalog has them; otherwise empty.
  List<String> modelsFor({int? makeId, String? name}) {
    CatalogMakeEntry? entry;
    if (makeId != null) entry = _byId[makeId];
    entry ??= name != null ? byName(name) : null;
    if (entry == null || !entry.hasModels) return const [];
    return entry.modelNames;
  }

  CatalogModelEntry? modelEntry(String brand, String model) {
    final make = byName(brand);
    if (make == null) return null;
    final key = model.trim().toLowerCase();
    for (final m in make.models) {
      if (m.name.toLowerCase() == key) return m;
    }
    return null;
  }

  /// True when make+model is present in the filtered catalog.
  bool isSelectable(String brand, String model) {
    final b = brand.trim();
    final m = model.trim();
    if (b.isEmpty || m.isEmpty) return false;
    return _allowedModelKeys.contains('${b.toLowerCase()}|${m.toLowerCase()}');
  }

  /// True when [CarOnlyFilter] allows the pair (even if not in catalog).
  bool isAllowedSelection(String brand, String model) =>
      CarOnlyFilter.isAllowedCar(make: brand, model: model);

  String? logoFor(String brand) {
    final make = byName(brand);
    final path = make?.logoPath;
    if (path != null && path.isNotEmpty) return path;
    return null;
  }

  String? photoFor(String brand, String model) {
    final entry = modelEntry(brand, model);
    return entry?.primaryImage;
  }

  String? angleFor(String brand, String model) {
    final entry = modelEntry(brand, model);
    if (entry == null || entry.angles.isEmpty) return null;
    for (final a in entry.angles) {
      if (!a.contains('/') && !a.contains('\\') && !a.startsWith('http')) {
        return a;
      }
    }
    return null;
  }

  void _ingest(List<CatalogMakeEntry> parsed) {
    final rows = <({String make, String model, String? category})>[];
    for (final make in parsed) {
      for (final model in make.models) {
        rows.add((
          make: make.name,
          model: model.name,
          category: model.category,
        ));
      }
    }
    _stats = CarOnlyFilter.computeStats(rows);

    final filtered = <CatalogMakeEntry>[];
    _allowedModelKeys.clear();

    for (final make in parsed) {
      final keptModels = <CatalogModelEntry>[];
      for (final model in make.models) {
        if (!CarOnlyFilter.isAllowedCar(
          make: make.name,
          model: model.name,
          category: model.category,
          displayName: model.name,
        )) {
          continue;
        }
        keptModels.add(model);
        _allowedModelKeys.add(
          '${make.name.toLowerCase()}|${model.name.toLowerCase()}',
        );
      }
      if (keptModels.isEmpty) continue;
      filtered.add(
        CatalogMakeEntry(
          id: make.id,
          name: make.name,
          catalogId: make.catalogId,
          models: List.unmodifiable(keptModels),
          logoPath: make.logoPath,
        ),
      );
    }

    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    _makes = List.unmodifiable(filtered);
    _byId
      ..clear()
      ..addEntries(filtered.map((m) => MapEntry(m.id, m)));
    _byName
      ..clear()
      ..addEntries(filtered.map((m) => MapEntry(m.name.toLowerCase(), m)));
    _byCatalogId
      ..clear()
      ..addEntries(
        filtered
            .where((m) => m.catalogId != null && m.catalogId!.isNotEmpty)
            .map((m) => MapEntry(m.catalogId!, m)),
      );
  }

  static List<CatalogMakeEntry> _parseAny(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      if (map['brands'] is List) {
        return _parseMasterCatalog(map);
      }
    }
    if (decoded is List) {
      return _parseLegacyArray(decoded);
    }
    return const [];
  }

  /// Master `vehicle_catalog.json` object schema.
  static List<CatalogMakeEntry> _parseMasterCatalog(Map<String, dynamic> root) {
    final brands = root['brands'];
    if (brands is! List) return const [];
    final out = <CatalogMakeEntry>[];
    for (final row in brands) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final catalogId = _asString(map['id']);
      final name =
          _asString(map['display_name']) ??
          _asString(map['name']) ??
          _asString(map['make_name']);
      if (name == null || name.isEmpty) continue;
      final models = _parseMasterModels(map['models']);
      final logo = _firstString(map, const [
        'logo',
        'logo_path',
        'logo_url',
        'logoPath',
        'logoUrl',
      ]);
      out.add(
        CatalogMakeEntry(
          id: _stableId(catalogId ?? name),
          name: name,
          catalogId: catalogId,
          models: models,
          logoPath: _remapMediaPath(logo),
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static List<CatalogModelEntry> _parseMasterModels(dynamic raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final out = <CatalogModelEntry>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final name =
          _asString(map['name']) ??
          _asString(map['model_name']) ??
          _asString(map['Model_Name']);
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      final catalogId = _asString(map['id']);
      final category =
          _asString(map['category']) ?? _asString(map['vehicle_category']);
      final mid = map['model_id'] ?? map['Model_ID'];
      final image = _firstString(map, const [
        'image',
        'image_path',
        'image_url',
        'imagePath',
        'imageUrl',
        'photo',
        'photo_path',
        'photo_url',
        'asset',
        'asset_path',
      ]);
      final logo = _firstString(map, const [
        'logo',
        'logo_path',
        'logo_url',
        'logoPath',
        'logoUrl',
      ]);
      final angles = _parseAngles(
        map['angles'] ?? map['photos'] ?? map['images'],
      );
      out.add(
        CatalogModelEntry(
          name: name,
          modelId: mid is num ? mid.toInt() : null,
          catalogId: catalogId,
          category: category,
          imagePath: _remapMediaPath(image),
          logoPath: _remapMediaPath(logo),
          angles: angles,
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static List<CatalogMakeEntry> _parseBrandsAndModels(
    String brandsRaw,
    String modelsRaw,
  ) {
    final brandsDecoded = jsonDecode(brandsRaw);
    final modelsDecoded = jsonDecode(modelsRaw);
    if (brandsDecoded is! List || modelsDecoded is! List) return const [];

    final brandNames = <String, String>{}; // id -> name
    for (final row in brandsDecoded) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final id = _asString(map['id']);
      final name = _asString(map['display_name']) ?? _asString(map['name']);
      if (id == null || name == null) continue;
      brandNames[id] = name;
    }

    final byBrand = <String, List<CatalogModelEntry>>{};
    for (final row in modelsDecoded) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final brandId = _asString(map['brand_id']);
      final makeName =
          _asString(map['make_name']) ??
          (brandId != null ? brandNames[brandId] : null);
      final modelName = _asString(map['model_name']) ?? _asString(map['name']);
      if (makeName == null || modelName == null) continue;
      final key = brandId ?? makeName.toLowerCase();
      final list = byBrand.putIfAbsent(key, () => <CatalogModelEntry>[]);
      final already = list.any(
        (m) => m.name.toLowerCase() == modelName.toLowerCase(),
      );
      if (already) continue;

      int? sourceModelId;
      final records = map['source_records'];
      if (records is List && records.isNotEmpty && records.first is Map) {
        final sr = Map<String, dynamic>.from(records.first as Map);
        final mid = sr['source_model_id'];
        if (mid is num) sourceModelId = mid.toInt();
      }

      list.add(
        CatalogModelEntry(
          name: modelName,
          modelId: sourceModelId,
          catalogId: _asString(map['id']),
          category:
              _asString(map['vehicle_category']) ?? _asString(map['category']),
          imagePath: _remapMediaPath(_asString(map['image'])),
          logoPath: _remapMediaPath(_asString(map['logo'])),
        ),
      );
    }

    final out = <CatalogMakeEntry>[];
    for (final entry in brandNames.entries) {
      final models = byBrand[entry.key] ?? const <CatalogModelEntry>[];
      final sorted = [...models]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      out.add(
        CatalogMakeEntry(
          id: _stableId(entry.key),
          name: entry.value,
          catalogId: entry.key,
          models: sorted,
        ),
      );
    }
    // Orphan makes present only in models file.
    for (final entry in byBrand.entries) {
      if (brandNames.containsKey(entry.key)) continue;
      final name = entry.value.isNotEmpty
          ? (brandNames[entry.key] ?? entry.key)
          : entry.key;
      // Prefer make_name from first model via catalog — already used as key.
      out.add(
        CatalogMakeEntry(
          id: _stableId(entry.key),
          name: name,
          catalogId: entry.key.startsWith('brand_') ? entry.key : null,
          models: entry.value,
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static List<CatalogMakeEntry> _parseLegacyArray(List<dynamic> decoded) {
    final out = <CatalogMakeEntry>[];
    for (final row in decoded) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final id = map['make_id'] ?? map['Make_ID'] ?? map['id'];
      final name = map['make_name'] ?? map['Make_Name'] ?? map['name'];
      if (name is! String) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final models = _parseLegacyModels(map['models']);
      final logo = _firstString(map, const [
        'logo',
        'logo_path',
        'logo_url',
        'logoPath',
        'logoUrl',
      ]);
      final makeId = id is num ? id.toInt() : _stableId(trimmed);
      out.add(
        CatalogMakeEntry(
          id: makeId,
          name: trimmed,
          models: models,
          logoPath: _remapMediaPath(logo),
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static List<CatalogModelEntry> _parseLegacyModels(dynamic raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final out = <CatalogModelEntry>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final name = map['model_name'] ?? map['Model_Name'] ?? map['name'];
      if (name is! String) continue;
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      final mid = map['model_id'] ?? map['Model_ID'] ?? map['id'];
      final image = _firstString(map, const [
        'image',
        'image_path',
        'image_url',
        'imagePath',
        'imageUrl',
        'photo',
        'photo_path',
        'photo_url',
        'asset',
        'asset_path',
      ]);
      final logo = _firstString(map, const [
        'logo',
        'logo_path',
        'logo_url',
        'logoPath',
        'logoUrl',
      ]);
      final angles = _parseAngles(
        map['angles'] ?? map['photos'] ?? map['images'],
      );
      out.add(
        CatalogModelEntry(
          name: trimmed,
          modelId: mid is num ? mid.toInt() : null,
          category:
              _asString(map['category']) ?? _asString(map['vehicle_category']),
          imagePath: _remapMediaPath(image),
          logoPath: _remapMediaPath(logo),
          angles: angles,
        ),
      );
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static List<String> _parseAngles(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String) {
      final remapped = _remapMediaPath(raw);
      return remapped == null ? const [] : [remapped];
    }
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        final remapped = _remapMediaPath(item) ?? item.trim();
        if (remapped.isNotEmpty) out.add(remapped);
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final label = _firstString(map, const ['label', 'angle', 'name']);
        final path = _firstString(map, const [
          'path',
          'image',
          'image_path',
          'url',
          'asset',
        ]);
        if (label != null && label.isNotEmpty) {
          out.add(label);
        } else if (path != null) {
          final remapped = _remapMediaPath(path) ?? path;
          if (remapped.isNotEmpty) out.add(remapped);
        }
      }
    }
    return out;
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? _asString(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  static int _stableId(String key) {
    // Stable positive 31-bit id from catalog string key.
    var hash = 0x811C9DC5;
    for (final c in key.toLowerCase().codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  /// Remap absolute squadrush / relative media paths into Flutter asset paths.
  static String? _remapMediaPath(String? path) {
    if (path == null) return null;
    var p = path.trim();
    if (p.isEmpty) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('assets/')) return p.replaceAll('\\', '/');

    final lower = p.toLowerCase();
    for (final root in _remapRoots) {
      if (lower.startsWith(root.toLowerCase())) {
        final rest = p.substring(root.length).replaceAll('\\', '/');
        if (rest.contains('logo') || root.contains('logos')) {
          final file = rest.split('/').last;
          return 'assets/logos/$file';
        }
        return 'assets/vehicles/catalog/$rest';
      }
    }

    if (!p.contains(':') &&
        (p.endsWith('.png') ||
            p.endsWith('.jpg') ||
            p.endsWith('.jpeg') ||
            p.endsWith('.webp'))) {
      return 'assets/vehicles/catalog/${p.replaceAll('\\', '/')}';
    }
    return p.replaceAll('\\', '/');
  }
}
