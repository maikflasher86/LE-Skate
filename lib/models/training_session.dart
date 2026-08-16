import 'package:inliner2/models/location.dart';

class SessionSeed {
  const SessionSeed({
    required this.id,
    required this.title,
    required this.anchor,
  });

  final String id;
  final String title;
  final DateTime anchor;
}

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.title,
    required this.trainingName,
    required this.start,
    required this.end,
    required this.location,
  });

  final String id;
  final String title;
  final String trainingName;
  final DateTime start;
  final DateTime end;
  final Location location;
}
