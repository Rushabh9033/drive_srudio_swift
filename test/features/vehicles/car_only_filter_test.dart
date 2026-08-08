import 'dart:convert';

import 'package:drive_studio/data/catalog/vehicle_catalog_service.dart';
import 'package:drive_studio/features/vehicles/data/car_only_filter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CarOnlyFilter unit rules', () {
    test('BMW bikes excluded', () {
      const bikes = [
        'C Evolution',
        'C 400 X',
        'C 600 Sport',
        'C 650 GT',
        'CE 02',
        'CE 04',
        'F 650 GS',
        'F 700 GS',
        'F 750 GS',
        'F 800 R',
        'F 850 GS',
        'F 900 R',
        'G 310 R',
        'G 450 X',
        'G 650 GS',
        'HP2 Sport',
        'HP4',
        'K 1100 LT',
        'K 1100 RS',
        'K1',
        'K75',
        'K75RT',
        'K75S',
        'M 1000 RR',
        'R 100 GS',
        'R 1250 GS',
        'R 12 nineT',
        'S 1000 RR',
        'S 1000 R',
        'S 1000 XR',
      ];
      for (final m in bikes) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'BMW', model: m),
          isFalse,
          reason: 'BMW $m should be excluded',
        );
      }
    });

    test('BMW cars kept', () {
      const cars = [
        'M2',
        'M3',
        'M4',
        'M5',
        'M8',
        'X1',
        'X3',
        'X5',
        'X7',
        'XM',
        'Z3',
        'Z4',
        'Z8',
        'i3',
        'i4',
        'i5',
        'i7',
        'i8',
        'iX',
        '328i',
        '530e',
      ];
      for (final m in cars) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'BMW', model: m),
          isTrue,
          reason: 'BMW $m should be kept',
        );
      }
    });

    test('Honda bikes out, cars in', () {
      const out = [
        'Africa Twin',
        'Gold Wing',
        'Rebel 500',
        'CBR600RR',
        'CB-1',
        'CBF600',
        'CRF450R',
        'ADV150',
        'PCX125',
        'NSS300 (Forza)',
        'ATC 250',
        'TRX450',
      ];
      for (final m in out) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'Honda', model: m),
          isFalse,
          reason: 'Honda $m should be excluded',
        );
      }
      const keep = [
        'Accord',
        'Civic',
        'Civic Type R',
        'CR-V',
        'CR-Z',
        'Pilot',
        'Odyssey',
      ];
      for (final m in keep) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'Honda', model: m),
          isTrue,
          reason: 'Honda $m should be kept',
        );
      }
    });

    test('Suzuki bikes out, cars in', () {
      const out = [
        'Hayabusa',
        'GSX-R750',
        'GSX-S1000',
        'V-Strom 650',
        'Boulevard M109R',
        'Burgman 400',
        'DR650S',
        'RM250',
        'KingQuad 750',
      ];
      for (final m in out) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'Suzuki', model: m),
          isFalse,
          reason: 'Suzuki $m should be excluded',
        );
      }
      for (final m in ['Alto', 'Swift', 'Jimny', 'Vitara']) {
        expect(
          CarOnlyFilter.isAllowedCar(make: 'Suzuki', model: m),
          isTrue,
          reason: 'Suzuki $m should be kept',
        );
      }
    });

    test('Toyota / Ford / Tesla cars kept', () {
      for (final pair in [
        ('Toyota', 'Camry'),
        ('Toyota', 'RAV4'),
        ('Ford', 'Mustang'),
        ('Ford', 'F-150'),
        ('Tesla', 'Model 3'),
        ('Tesla', 'Model Y'),
      ]) {
        expect(
          CarOnlyFilter.isAllowedCar(make: pair.$1, model: pair.$2),
          isTrue,
        );
      }
    });

    test('bus / trailer / chassis / golf cart excluded', () {
      const cases = [
        ('Ford', 'Transit Bus'),
        ('Chevrolet', 'Cutaway Chassis'),
        ('Ford', 'Motorhome Chassis'),
        ('Ram', 'Chassis Cab'),
        ('GMC', 'Commercial Chassis'),
        ('Generic', 'Utility Trailer'),
        ('Generic', 'Farm Tractor'),
        ('Generic', 'Golf Cart'),
        ('Generic', 'Low Speed Vehicle'),
        ('Generic', 'Electric Bus'),
        ('Generic', 'Heavy Truck'),
      ];
      for (final c in cases) {
        expect(
          CarOnlyFilter.isAllowedCar(make: c.$1, model: c.$2),
          isFalse,
          reason: '${c.$1} ${c.$2}',
        );
      }
      // Do not kill VW Golf as golf cart.
      expect(
        CarOnlyFilter.isAllowedCar(make: 'Volkswagen', model: 'Golf'),
        isTrue,
      );
      expect(
        CarOnlyFilter.isAllowedCar(make: 'Volkswagen', model: 'Golf GTI'),
        isTrue,
      );
    });

    test('does not exclude valid cars based only on short letters/numbers', () {
      expect(CarOnlyFilter.isAllowedCar(make: 'BMW', model: 'M'), isTrue);
      expect(CarOnlyFilter.isAllowedCar(make: 'Audi', model: 'A4'), isTrue);
      expect(
        CarOnlyFilter.isAllowedCar(make: 'Mercedes-Benz', model: 'C'),
        isTrue,
      );
    });

    test('does not trust passenger_car alone for bikes', () {
      expect(
        CarOnlyFilter.isAllowedCar(
          make: 'BMW',
          model: 'R 1250 GS',
          category: 'passenger_car',
        ),
        isFalse,
      );
      expect(
        CarOnlyFilter.isAllowedCar(
          make: 'Honda',
          model: 'CBR600RR',
          category: 'passenger_car',
        ),
        isFalse,
      );
    });
  });

  group('Master catalog integration', () {
    late VehicleCatalogService catalog;

    setUp(() async {
      catalog = VehicleCatalogService.instance;
      catalog.resetForTest();
      final raw = await rootBundle.loadString(
        'assets/data/vehicle_catalog.json',
      );
      catalog.loadFromJsonString(raw);
    });

    test('filter stats and brand invariant', () {
      final stats = catalog.filterStats;
      expect(stats.rawModelCount, greaterThan(2000));
      expect(stats.validCarCount, lessThan(stats.rawModelCount));
      expect(stats.validCarCount, equals(catalog.modelCount));
      expect(stats.brandsRemaining, equals(catalog.makeCount));
      expect(
        stats.excludedBikeCount + stats.excludedOtherCount,
        equals(stats.rawModelCount - stats.validCarCount),
      );

      // Every visible brand has ≥1 model.
      for (final make in catalog.makes) {
        expect(make.models, isNotEmpty, reason: make.name);
      }
    });

    test('BMW bikes not selectable; BMW cars are', () {
      expect(catalog.isSelectable('BMW', 'R 100 GS'), isFalse);
      expect(catalog.isSelectable('BMW', 'S 1000 RR'), isFalse);
      expect(catalog.isSelectable('BMW', 'K75'), isFalse);
      expect(catalog.isSelectable('BMW', 'M3'), isTrue);
      expect(catalog.isSelectable('BMW', 'X5'), isTrue);
      expect(catalog.isSelectable('BMW', 'iX'), isTrue);
    });

    test('Honda / Suzuki / Toyota / Ford / Tesla cars selectable', () {
      expect(catalog.isSelectable('Honda', 'Civic'), isTrue);
      expect(catalog.isSelectable('Honda', 'Accord'), isTrue);
      expect(catalog.isSelectable('Honda', 'CR-V'), isTrue);
      expect(catalog.isSelectable('Honda', 'CBR600RR'), isFalse);
      expect(catalog.isSelectable('Suzuki', 'Swift'), isTrue);
      expect(catalog.isSelectable('Suzuki', 'DR650S'), isFalse);
      expect(catalog.isSelectable('Toyota', 'Camry'), isTrue);
      expect(catalog.isSelectable('Ford', 'Mustang'), isTrue);
      expect(catalog.isSelectable('Tesla', 'Model 3'), isTrue);
    });

    test('chassis / motorhome rows excluded from catalog', () {
      expect(catalog.isSelectable('Chevrolet', 'Cutaway Chassis'), isFalse);
      expect(catalog.isSelectable('Ford', 'Motorhome Chassis'), isFalse);
      expect(catalog.modelEntry('Dodge', 'Ram Chassis Cab'), isNull);
      expect(catalog.isSelectable('Ram', 'XC Chassis'), isFalse);
    });

    test(
      'VehicleCatalogService search never returns empty-model brands',
      () async {
        await catalog.ensureLoaded();
        final brands = catalog.search('');
        expect(brands, isNotEmpty);
        for (final b in brands.take(40)) {
          expect(b.models, isNotEmpty, reason: b.name);
          final models = catalog.modelsFor(name: b.name);
          expect(models, isNotEmpty, reason: b.name);
          for (final m in models) {
            expect(
              catalog.isAllowedSelection(b.name, m),
              isTrue,
              reason: '${b.name} $m',
            );
          }
        }
      },
    );

    test('excluded models cannot be restored as selection', () {
      expect(catalog.isAllowedSelection('BMW', 'R 100 GS'), isFalse);
      expect(catalog.modelEntry('BMW', 'R 100 GS'), isNull);
      expect(catalog.isAllowedSelection('BMW', 'M3'), isTrue);
      final ids = catalog.modelEntry('BMW', 'M3');
      expect(ids?.name, isNotNull);
    });

    test('stats printable snapshot', () {
      final s = catalog.filterStats;
      // ignore: avoid_print
      print(
        'STATS raw=${s.rawModelCount} valid=${s.validCarCount} '
        'bikes=${s.excludedBikeCount} other=${s.excludedOtherCount} '
        'brands=${s.brandsRemaining}',
      );
      expect(s.rawModelCount, 2333);
    });
  });

  group('vehicle_models.json path', () {
    test('brands+models combine through filter', () async {
      final brands = await rootBundle.loadString(
        'assets/data/vehicle_brands.json',
      );
      final models = await rootBundle.loadString(
        'assets/data/vehicle_models.json',
      );
      final brandList = jsonDecode(brands) as List;
      final modelList = jsonDecode(models) as List;
      expect(brandList.length, 61);
      expect(modelList.length, 2333);

      final rows = modelList.map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        return (
          make: (m['make_name'] as String?) ?? '',
          model: (m['model_name'] as String?) ?? '',
          category: m['vehicle_category'] as String?,
        );
      });
      final stats = CarOnlyFilter.computeStats(rows);
      expect(stats.rawModelCount, 2333);
      expect(stats.validCarCount, greaterThan(1500));
      expect(stats.excludedBikeCount, greaterThan(0));
      expect(stats.excludedOtherCount, greaterThan(0));
      expect(stats.brandsRemaining, lessThanOrEqualTo(61));
      expect(stats.brandsRemaining, greaterThan(40));
    });
  });
}
