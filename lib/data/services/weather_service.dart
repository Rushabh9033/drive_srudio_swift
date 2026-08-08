import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class WeatherData {
  final double temperature;
  final String condition;
  final String symbolName;

  WeatherData({
    required this.temperature,
    required this.condition,
    required this.symbolName,
  });

  factory WeatherData.fromMap(Map<dynamic, dynamic> map) {
    return WeatherData(
      temperature: map['temperature'] as double? ?? 0.0,
      condition: map['condition'] as String? ?? 'Unknown',
      symbolName: map['symbolName'] as String? ?? 'cloud',
    );
  }
}

class WeatherService {
  static const MethodChannel _channel = MethodChannel('drive_studio/weather');

  Future<WeatherData?> fetchWeather(double latitude, double longitude) async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'fetchWeather',
        {'latitude': latitude, 'longitude': longitude},
      );
      if (result == null) return null;
      return WeatherData.fromMap(result);
    } catch (e) {
      debugPrint('Failed to fetch weather: $e');
      return null;
    }
  }
}
