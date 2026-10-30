class TrainingCourse {
  const TrainingCourse({
    required this.category,
    required this.instructors,
    required this.content,
    required this.equipment,
    this.notes = const [],
  });

  factory TrainingCourse.fromJson(Map<String, dynamic> json) {
    return TrainingCourse(
      category: json['category'] as String,
      instructors: (json['instructors'] as List<dynamic>).cast<String>(),
      content: json['content'] as String,
      equipment: json['equipment'] as String,
      notes: (json['notes'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String category;
  final List<String> instructors;
  final String content;
  final String equipment;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
    'category': category,
    'instructors': instructors,
    'content': content,
    'equipment': equipment,
    'notes': notes,
  };
}
