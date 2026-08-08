import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String location;
  final DateTime startDate;
  final DateTime endDate;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.startDate,
    required this.endDate,
  });

  factory CalendarEvent.fromMap(Map<dynamic, dynamic> map) {
    return CalendarEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Event',
      location: map['location'] ?? '',
      startDate: DateTime.fromMillisecondsSinceEpoch(
        (map['startDate'] as double? ?? 0).toInt() * 1000,
      ),
      endDate: DateTime.fromMillisecondsSinceEpoch(
        (map['endDate'] as double? ?? 0).toInt() * 1000,
      ),
    );
  }
}

class CalendarService {
  static const MethodChannel _channel = MethodChannel('drive_studio/calendar');

  Future<bool> requestAccess() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestAccess');
      return granted ?? false;
    } catch (e) {
      debugPrint('Failed to request calendar access: $e');
      return false;
    }
  }

  Future<List<CalendarEvent>> fetchUpcomingEvents() async {
    try {
      final List<dynamic>? results = await _channel.invokeMethod(
        'fetchUpcomingEvents',
      );
      if (results == null) return [];

      return results
          .map((r) => CalendarEvent.fromMap(r as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch calendar events: $e');
      return [];
    }
  }
}
