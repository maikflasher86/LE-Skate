import 'package:inliner2/models/location.dart';
import 'package:inliner2/models/training_course.dart';

class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.title,
    required this.trainingName,
    required this.start,
    required this.end,
    required this.location,
    this.isIndoor = false,
    this.courses = const [],
  });

  final String id;
  final String title;
  final String trainingName;
  final DateTime start;
  final DateTime end;
  final Location location;

  /// Indoor training (e.g. sports hall): weather is irrelevant for it.
  final bool isIndoor;
  final List<TrainingCourse> courses;
}
