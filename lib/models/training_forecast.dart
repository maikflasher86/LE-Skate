import 'package:inliner2/models/dwd_hourly_point.dart';
import 'package:inliner2/models/precipitation_15m_point.dart';
import 'package:inliner2/models/training_course.dart';
import 'package:inliner2/models/weather_metrics.dart';

class TrainingForecast {
  TrainingForecast({
    required this.id,
    required this.title,
    required this.trainingName,
    required this.start,
    required this.end,
    required this.llmScore,
    required this.verdict,
    required this.reason,
    this.recommendation,
    required this.weather,
    this.dwdPoints = const [],
    this.precipitation15mPoints = const [],
    this.isIndoor = false,
    this.locationLabel,
    this.courses = const [],
  });

  factory TrainingForecast.fromJson(Map<String, dynamic> json) {
    return TrainingForecast(
      id: json['id'] as String,
      title: json['title'] as String,
      trainingName:
          (json['training_name'] as String?) ?? (json['title'] as String),
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
      llmScore: (json['llm_score'] as num?)?.toInt(),
      verdict: json['verdict'] as String,
      reason: json['reason'] as String,
      recommendation: json['recommendation'] as String?,
      weather: json['weather'] == null
          ? null
          : WeatherMetrics.fromJson(json['weather'] as Map<String, dynamic>),
      dwdPoints: (json['dwd_points'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(DwdHourlyPoint.fromJson)
          .toList(),
      precipitation15mPoints:
          (json['precipitation_15m'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .map(Precipitation15mPoint.fromJson)
              .toList(),
      isIndoor: json['is_indoor'] as bool? ?? false,
      locationLabel:
          json['location_label'] as String? ??
          (json['location'] as Map<String, dynamic>?)?['label'] as String?,
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TrainingCourse.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String trainingName;
  final DateTime start;
  final DateTime end;
  final int? llmScore;
  final String verdict;
  final String reason;
  final String? recommendation;
  final WeatherMetrics? weather;

  /// DWD precipitation data for the training time window including 4 hours before.
  final List<DwdHourlyPoint> dwdPoints;

  /// Open-Meteo precipitation in 15-minute resolution around training time.
  final List<Precipitation15mPoint> precipitation15mPoints;

  /// Indoor training has no weather evaluation, but course details can still
  /// be shown.
  final bool isIndoor;

  final String? locationLabel;

  final List<TrainingCourse> courses;
}
