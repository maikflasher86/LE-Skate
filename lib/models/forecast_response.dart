import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_forecast.dart';

class LastRainEvent {
  const LastRainEvent({required this.time, required this.rainMm});

  final DateTime time;
  final double rainMm;
}

class ForecastResponse {
  ForecastResponse({
    required this.location,
    required this.fetchedAt,
    required this.trainings,
    this.rawApiJson = '',
    this.lastRainEvent,
    this.nextRainEvent,
  });

  factory ForecastResponse.fromJson(Map<String, dynamic> json) {
    LastRainEvent? parseEvent(Map<String, dynamic>? raw) {
      if (raw == null) return null;
      return LastRainEvent(
        time: DateTime.parse(raw['time'] as String).toLocal(),
        rainMm: (raw['rain_mm'] as num).toDouble(),
      );
    }

    return ForecastResponse(
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      fetchedAt: DateTime.parse(json['fetched_at'] as String).toLocal(),
      trainings: (json['trainings'] as List<dynamic>)
          .map(
            (item) => TrainingForecast.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      rawApiJson: json['raw_api_json'] as String? ?? '',
      lastRainEvent: parseEvent(
        json['last_rain_event'] as Map<String, dynamic>?,
      ),
      nextRainEvent: parseEvent(
        json['next_rain_event'] as Map<String, dynamic>?,
      ),
    );
  }

  final Location location;
  final DateTime fetchedAt;
  final List<TrainingForecast> trainings;
  final String rawApiJson;
  final LastRainEvent? lastRainEvent;
  final LastRainEvent? nextRainEvent;
}
