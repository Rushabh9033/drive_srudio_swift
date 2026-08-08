import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class MapKitPlace {
  final String name;
  final double latitude;
  final double longitude;
  final String address;

  MapKitPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory MapKitPlace.fromMap(Map<dynamic, dynamic> map) {
    return MapKitPlace(
      name: map['name'] ?? 'Unknown Place',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      address: map['address'] ?? '',
    );
  }
}

class MapKitSearchService {
  static const MethodChannel _channel = MethodChannel(
    'drive_studio/mapkit_search',
  );

  Future<List<MapKitPlace>> searchNearby(
    String query,
    double latitude,
    double longitude,
  ) async {
    try {
      final List<dynamic>? results = await _channel.invokeMethod(
        'searchNearby',
        {'query': query, 'latitude': latitude, 'longitude': longitude},
      );
      if (results == null) return [];

      return results
          .map((r) => MapKitPlace.fromMap(r as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to search nearby places: $e');
      return [];
    }
  }
}
