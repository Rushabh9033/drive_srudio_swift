/// Stock car photo catalog — intentionally empty.
///
/// Drive Studio never ships pre-installed car photos. Users add their own
/// gallery / camera images only.
class StockCarImage {
  const StockCarImage({
    required this.id,
    required this.title,
    required this.bodyClass,
    required this.angle,
    required this.assetPath,
    this.brand = '',
    this.model = '',
    this.url = '',
    this.thumb = '',
  });

  final String id;
  final String title;
  final String bodyClass;

  /// front34 | side | rear34
  final String angle;
  final String assetPath;
  final String brand;
  final String model;
  final String url;
  final String thumb;

  String get angleLabel => switch (angle) {
        'front34' => 'Front ¾',
        'side' => 'Side',
        'rear34' => 'Rear ¾',
        _ => angle,
      };

  String get displaySrc =>
      assetPath.isNotEmpty ? assetPath : (url.isNotEmpty ? url : thumb);
}

abstract final class StockCars {
  static const classes = [
    'All',
    'Sedan',
    'SUV',
    'Coupe',
    'Truck',
    'Hatch',
    'Sports',
  ];

  static const angles = ['All', 'front34', 'side', 'rear34'];

  /// No bundled car photos.
  static const items = <StockCarImage>[];

  static List<StockCarImage> filtered(String bodyClass, {String angle = 'All'}) {
    return const [];
  }

  static String inferClass(String modelOrBrand) => 'Sedan';

  static StockCarImage? forBrandModel(String brand, String model) => null;

  static StockCarImage? photoForModel(String brand, String model) => null;

  static StockCarImage? pickForModel(String model, {String brand = ''}) => null;
}
