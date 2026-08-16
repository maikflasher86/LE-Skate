import 'package:inliner2/models/hourly_point.dart';
import 'package:inliner2/models/training_forecast.dart';

class TrainingPeriodPoints {
  const TrainingPeriodPoints({required this.training, required this.points});

  final TrainingForecast training;
  final List<HourlyPoint> points;
}
