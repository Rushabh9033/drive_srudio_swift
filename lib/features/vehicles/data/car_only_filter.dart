/// Strict cars-only gate for Drive Studio brand → model catalogs.
///
/// Final authority over UI, search, persistence, cache restore, and deep-link
/// selection. Do **not** trust `classification_status` / `passenger_car` alone.
library;

/// Why a row was removed (for stats / tests).
enum CarExclusionKind {
  /// Motorcycle / scooter / ATV / powersports / bike-family rules.
  bike,

  /// Bus, chassis, trailer, tractor, golf cart, commercial, industrial, etc.
  other,
}

/// Result of evaluating one make+model (and optional metadata).
class CarFilterDecision {
  const CarFilterDecision.allow() : allowed = true, kind = null, reason = null;

  const CarFilterDecision.deny(this.kind, this.reason) : allowed = false;

  final bool allowed;
  final CarExclusionKind? kind;
  final String? reason;
}

/// Aggregate counts after filtering a catalog dump.
class CarFilterStats {
  const CarFilterStats({
    required this.rawModelCount,
    required this.validCarCount,
    required this.excludedBikeCount,
    required this.excludedOtherCount,
    required this.brandsRemaining,
  });

  final int rawModelCount;
  final int validCarCount;
  final int excludedBikeCount;
  final int excludedOtherCount;
  final int brandsRemaining;

  int get excludedTotal => excludedBikeCount + excludedOtherCount;
}

/// Single authority: cars-only filter for Drive Studio.
abstract final class CarOnlyFilter {
  /// Allowed passenger / light consumer categories (soft signal only).
  static const allowedCategories = <String>{
    'passenger_car',
    'sedan',
    'hatchback',
    'coupe',
    'convertible',
    'wagon',
    'suv',
    'crossover',
    'minivan',
    'sports_car',
    'supercar',
    'luxury_car',
    'luxury',
    'electric_passenger_vehicle',
    'ev',
    'consumer_pickup',
    'pickup',
  };

  /// Hard-denied vehicle categories when present in source data.
  static const deniedCategories = <String>{
    'motorcycle',
    'motorbike',
    'scooter',
    'atv',
    'utv',
    'powersports',
    'bus',
    'heavy_truck',
    'commercial_truck',
    'trailer',
    'tractor',
    'motorhome_chassis',
    'commercial_chassis',
    'incomplete_vehicle',
    'industrial',
    'golf_cart',
    'low_speed_vehicle',
    'lsv',
  };

  // ── Public API ──────────────────────────────────────────────────────────

  static bool isAllowedCar({
    required String make,
    required String model,
    String? category,
    String? displayName,
    String? modelFamily,
  }) => evaluate(
    make: make,
    model: model,
    category: category,
    displayName: displayName,
    modelFamily: modelFamily,
  ).allowed;

  static CarFilterDecision evaluate({
    required String make,
    required String model,
    String? category,
    String? displayName,
    String? modelFamily,
  }) {
    final makeN = make.trim();
    final modelN = model.trim();
    if (makeN.isEmpty || modelN.isEmpty) {
      return const CarFilterDecision.deny(
        CarExclusionKind.other,
        'empty make/model',
      );
    }

    final makeKey = makeN.toLowerCase();
    final modelKey = modelN.toLowerCase();
    final display = (displayName ?? '').trim().toLowerCase();
    final family = (modelFamily ?? '').trim().toLowerCase();
    final cat = (category ?? '').trim().toLowerCase().replaceAll(' ', '_');

    // Soft category deny — never the sole allow path.
    if (cat.isNotEmpty && deniedCategories.contains(cat)) {
      final bikeCats = {
        'motorcycle',
        'motorbike',
        'scooter',
        'atv',
        'utv',
        'powersports',
      };
      return CarFilterDecision.deny(
        bikeCats.contains(cat) ? CarExclusionKind.bike : CarExclusionKind.other,
        'denied category: $cat',
      );
    }

    final blob =
        '$modelKey ${display.isEmpty ? '' : display} '
        '${family.isEmpty ? '' : family}';

    // General commercial / non-car phrases (before brand rules).
    final general = _matchGeneralExclusion(blob);
    if (general != null) return general;

    // Brand-specific motorcycle / powersports families.
    if (makeKey == 'bmw') {
      final bmw = _bmwDecision(modelKey, blob);
      if (bmw != null) return bmw;
    }
    if (makeKey == 'honda') {
      final honda = _hondaDecision(modelKey, blob);
      if (honda != null) return honda;
    }
    if (makeKey == 'suzuki') {
      final suzuki = _suzukiDecision(modelKey, blob);
      if (suzuki != null) return suzuki;
    }

    // Generic bike / scooter markers that survive brand rules.
    final bike = _matchGenericBike(blob);
    if (bike != null) return bike;

    return const CarFilterDecision.allow();
  }

  /// Keep a brand only when at least one model survives the filter.
  static bool brandHasValidCars(
    String make,
    Iterable<String> models, {
    String? Function(String model)? categoryFor,
  }) {
    for (final m in models) {
      if (isAllowedCar(make: make, model: m, category: categoryFor?.call(m))) {
        return true;
      }
    }
    return false;
  }

  /// Filter model name list for a make.
  static List<String> filterModelNames(
    String make,
    Iterable<String> models, {
    String? Function(String model)? categoryFor,
  }) {
    return models
        .where(
          (m) => isAllowedCar(
            make: make,
            model: m,
            category: categoryFor?.call(m),
          ),
        )
        .toList(growable: false);
  }

  /// Compute stats over raw rows `{make, model, category?}`.
  static CarFilterStats computeStats(
    Iterable<({String make, String model, String? category})> rows,
  ) {
    var raw = 0;
    var valid = 0;
    var bikes = 0;
    var other = 0;
    final brandsWithCars = <String>{};

    for (final row in rows) {
      raw++;
      final d = evaluate(
        make: row.make,
        model: row.model,
        category: row.category,
      );
      if (d.allowed) {
        valid++;
        brandsWithCars.add(row.make.trim().toLowerCase());
      } else if (d.kind == CarExclusionKind.bike) {
        bikes++;
      } else {
        other++;
      }
    }

    return CarFilterStats(
      rawModelCount: raw,
      validCarCount: valid,
      excludedBikeCount: bikes,
      excludedOtherCount: other,
      brandsRemaining: brandsWithCars.length,
    );
  }

  // ── General exclusions ─────────────────────────────────────────────────

  static CarFilterDecision? _matchGeneralExclusion(String blob) {
    // Phrase / multi-word first (order matters for Golf Cart vs Golf).
    const phrases = <(String, CarExclusionKind, String)>[
      ('golf cart', CarExclusionKind.other, 'Golf Cart'),
      ('low speed vehicle', CarExclusionKind.other, 'Low Speed Vehicle'),
      ('low-speed vehicle', CarExclusionKind.other, 'Low Speed Vehicle'),
      ('electric bus', CarExclusionKind.other, 'Electric Bus'),
      ('bus chassis', CarExclusionKind.other, 'Bus Chassis'),
      ('truck chassis', CarExclusionKind.other, 'Truck Chassis'),
      ('cutaway chassis', CarExclusionKind.other, 'Cutaway Chassis'),
      ('cab chassis', CarExclusionKind.other, 'Cab Chassis'),
      ('chassis cab', CarExclusionKind.other, 'Chassis Cab'),
      ('commercial chassis', CarExclusionKind.other, 'Commercial Chassis'),
      ('motorhome chassis', CarExclusionKind.other, 'Motorhome Chassis'),
      ('motor home chassis', CarExclusionKind.other, 'Motorhome Chassis'),
      ('incomplete vehicle', CarExclusionKind.other, 'Incomplete Vehicle'),
      ('military truck', CarExclusionKind.other, 'Military Truck'),
      ('heavy truck', CarExclusionKind.other, 'Heavy Truck'),
      ('heavy commercial', CarExclusionKind.other, 'Heavy commercial truck'),
    ];
    for (final (p, kind, label) in phrases) {
      if (blob.contains(p)) {
        return CarFilterDecision.deny(kind, label);
      }
    }

    // Word-boundary terms (avoid killing short alphanumerics alone).
    final wordTerms = <(RegExp, CarExclusionKind, String)>[
      (
        RegExp(r'\bmotorbike\b', caseSensitive: false),
        CarExclusionKind.bike,
        'Motorbike',
      ),
      (
        RegExp(r'\bmotorcycle\b', caseSensitive: false),
        CarExclusionKind.bike,
        'Motorcycle',
      ),
      (
        RegExp(r'\bscooter\b', caseSensitive: false),
        CarExclusionKind.bike,
        'Scooter',
      ),
      (
        RegExp(r'\bpowersports?\b', caseSensitive: false),
        CarExclusionKind.bike,
        'Powersports',
      ),
      (RegExp(r'\batv\b', caseSensitive: false), CarExclusionKind.bike, 'ATV'),
      (RegExp(r'\butv\b', caseSensitive: false), CarExclusionKind.bike, 'UTV'),
      (RegExp(r'\bbus\b', caseSensitive: false), CarExclusionKind.other, 'Bus'),
      (
        RegExp(r'\btrailer\b', caseSensitive: false),
        CarExclusionKind.other,
        'Trailer',
      ),
      (
        RegExp(r'\btractor\b', caseSensitive: false),
        CarExclusionKind.other,
        'Tractor',
      ),
      (
        RegExp(r'\bcoachbuilder\b', caseSensitive: false),
        CarExclusionKind.other,
        'Coachbuilder',
      ),
      (
        RegExp(r'\bindustrial\b', caseSensitive: false),
        CarExclusionKind.other,
        'Industrial',
      ),
    ];
    for (final (re, kind, label) in wordTerms) {
      if (re.hasMatch(blob)) {
        return CarFilterDecision.deny(kind, label);
      }
    }

    // Any remaining "… Chassis" commercial platform (not car body styles).
    if (RegExp(r'\bchassis\b', caseSensitive: false).hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.other, 'Chassis');
    }

    return null;
  }

  static CarFilterDecision? _matchGenericBike(String blob) {
    if (RegExp(
      r'\b(dirt\s*bike|sportbike|naked\s*bike|adventure\s*bike)\b',
      caseSensitive: false,
    ).hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'bike term');
    }
    return null;
  }

  // ── BMW ────────────────────────────────────────────────────────────────

  /// BMW cars to keep even if a short pattern might look bike-like.
  static final _bmwKeep = RegExp(
    r'^(?:'
    r'm[2-8]\b|' // M2–M8 cars
    r'x[1-7]\b|xm\b|' // X1–X7, XM
    r'z[348]\b|' // Z3/Z4/Z8
    r'i[34578]\b|ix\b|' // i3/i4/i5/i7/i8, iX
    r'i[0-9]{2,3}[a-z]?\b' // iX1, iX3, etc. still cars
    r')',
    caseSensitive: false,
  );

  static CarFilterDecision? _bmwDecision(String modelKey, String blob) {
    if (_bmwKeep.hasMatch(modelKey)) {
      // Still drop explicit bike M 1000 family if somehow labeled oddly.
      if (RegExp(r'\bm\s*1000\b').hasMatch(blob)) {
        return const CarFilterDecision.deny(
          CarExclusionKind.bike,
          'BMW M 1000',
        );
      }
      return null; // allowed (caller continues; no deny)
    }

    // C Evolution scooter / maxi-scooters.
    if (blob.contains('c evolution') ||
        RegExp(r'\bc\s*evolution\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW C Evolution',
      );
    }

    // C 400 / C 600 / C 650 scooter line.
    if (RegExp(r'\bc\s*(400|600|650)\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW C scooter',
      );
    }

    // CE 02 / CE 04.
    if (RegExp(r'\bce\s*0[24]\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'BMW CE');
    }

    // F-series motorcycles.
    if (RegExp(r'\bf\s*(650|700|750|800|850|900)\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW F series',
      );
    }

    // G-series motorcycles.
    if (RegExp(r'\bg\s*(310|450|650)\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW G series',
      );
    }

    // HP2 / HP4.
    if (RegExp(r'\bhp\s*[24]\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'BMW HP');
    }

    // K motorcycle series (K1, K75…, K 1100…, K 1200…, K 1300…, K 1600…).
    if (RegExp(
      r'^(?:k1|k75\w*)\b|\bk\s*(?:75\w*|1(?:100|200|300|600)\w*)\b',
    ).hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW K series',
      );
    }

    // M 1000 R / RR / XR.
    if (RegExp(r'\bm\s*1000\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'BMW M 1000');
    }

    // R motorcycle series (R 100…, R 12, R nineT, etc.).
    if (RegExp(
      r'\br\s*(?:'
      r'ninet\b|'
      r'12\b|'
      r'(?:65|80|90|100|1100|1150|1200|1250|1300|850|900)\b'
      r')',
    ).hasMatch(blob)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'BMW R series',
      );
    }

    // S 1000 R / RR / XR.
    if (RegExp(r'\bs\s*1000\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'BMW S 1000');
    }

    return null;
  }

  // ── Honda ──────────────────────────────────────────────────────────────

  static CarFilterDecision? _hondaDecision(String modelKey, String blob) {
    // Keep Civic / CR-V / CR-Z explicitly before CB / CR dirt-bike rules.
    if (RegExp(
      r'^(?:civic|accord|cr-?v\b|cr-?z\b|hr-?v\b|pilot|odyssey|ridgeline|'
      r'passport|insight|clarity|element|crosstour|fit|jazz|city|brio|'
      r'amaze|elevate|integra|prelude|s2000|nsx|e\b|ev\s*plus)',
    ).hasMatch(modelKey)) {
      return null;
    }

    const phrases = <String>['africa twin', 'gold wing', 'goldwing'];
    for (final p in phrases) {
      if (blob.contains(p)) {
        return CarFilterDecision.deny(CarExclusionKind.bike, 'Honda $p');
      }
    }

    if (RegExp(r'\brebel\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda Rebel');
    }
    if (RegExp(r'\bcbr\b|\bcbr\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda CBR');
    }
    // CB bike family — must not match Civic.
    if (RegExp(
      r'\bcb(?:f|x|r)?[\s-]?\d|\bcb-\d|\bcb\s*\d|\bcbx\b|\bcbf\b|\bcbf\d',
    ).hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda CB');
    }
    if (RegExp(r'\bcrf\b|\bcrf\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda CRF');
    }
    // ADV scooters / motorcycles (not "Advantage" cars — none named ADV alone).
    if (RegExp(r'\badv(?:\s*\d+|\b)').hasMatch(modelKey) ||
        RegExp(r'\badv\s*\d+|\badv\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda ADV');
    }
    if (RegExp(r'\bpcx\b|\bpcx\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda PCX');
    }
    if (RegExp(r'\bforza\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda Forza');
    }
    if (RegExp(r'\batc\b|\batc\s*\d|\batc\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda ATC');
    }
    if (RegExp(r'\btrx\b|\btrx\d').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Honda TRX');
    }

    // Additional obvious Honda powersports naming in this dataset.
    if (RegExp(
      r'^(?:ctx|cm\d|cx\d|cr\d|elite|dax|dn-?01|big\s*red|nss|cbf|cbx)\b',
    ).hasMatch(modelKey)) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Honda powersports',
      );
    }

    return null;
  }

  // ── Suzuki ─────────────────────────────────────────────────────────────

  static CarFilterDecision? _suzukiDecision(String modelKey, String blob) {
    // Keep common cars first.
    if (RegExp(
      r'^(?:alto|swift|jimny|vitara|sx4|baleno|ciaz|ertiga|wagon\s*r|'
      r'grand\s*vitara|kizashi|s-?cross|ignis|celerio|dzire|samurai|'
      r'sidekick|x-?90|equator|xl7|aerio|foroza|liana|splash)',
    ).hasMatch(modelKey)) {
      return null;
    }

    if (blob.contains('hayabusa')) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Suzuki Hayabusa',
      );
    }
    if (RegExp(r'\bgsx(?:-?r)?\b').hasMatch(blob)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Suzuki GSX');
    }
    if (blob.contains('v-strom') || blob.contains('vstrom')) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Suzuki V-Strom',
      );
    }
    if (blob.contains('boulevard')) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Suzuki Boulevard',
      );
    }
    if (blob.contains('burgman')) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Suzuki Burgman',
      );
    }
    if (blob.contains('kingquad') || blob.contains('king quad')) {
      return const CarFilterDecision.deny(
        CarExclusionKind.bike,
        'Suzuki KingQuad',
      );
    }
    // DR / RM dirt & dual-sport families.
    if (RegExp(r'\bdr\s*\d|\bdr\d').hasMatch(blob) ||
        RegExp(r'^dr\d').hasMatch(modelKey)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Suzuki DR');
    }
    if (RegExp(r'\brm(?:x)?\s*\d|\brm(?:x)?\d').hasMatch(blob) ||
        RegExp(r'^rm(?:x)?\d').hasMatch(modelKey)) {
      return const CarFilterDecision.deny(CarExclusionKind.bike, 'Suzuki RM');
    }

    return null;
  }
}
